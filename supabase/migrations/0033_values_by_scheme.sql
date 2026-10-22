-- =====================================================================================
-- 0033 · Valor de mercado por sistema de puntuación. Cada ciclista tiene un valor en cada sistema (Cyclonomy con el
--        WT dividido o junto, y UCI), calculado con sus puntos de la temporada base (2026) en ese sistema; cada liga
--        ve y usa el de su sistema. Los puntos se normalizan: en todos los sistemas el pelotón suma los mismos
--        puntos (los de Cyclonomy), así el presupuesto rinde igual en cualquier liga.
--        También los puntos de temporada (rider_season_points) pasan a ser por sistema.
-- =====================================================================================

alter table public.value_params add column if not exists base_season smallint not null default 2026;

-- puntos de cada ciclista en la temporada base, por sistema (fijos: se calculan una vez)
create table if not exists public.rider_base_points (
  rider_id  bigint not null references public.rider(id) on delete cascade,
  scheme    text not null,
  points    numeric not null,
  primary key (rider_id, scheme)
);
-- factor de normalización de cada sistema (puntos de Cyclonomy / puntos del sistema, en todo el pelotón)
create table if not exists public.scheme_factor (
  scheme  text primary key,
  factor  numeric not null
);
-- valor actual de cada ciclista en cada sistema
create table if not exists public.rider_value (
  rider_id  bigint not null references public.rider(id) on delete cascade,
  scheme    text not null,
  value     bigint not null check (value >= 0),
  primary key (rider_id, scheme)
);
alter table public.rider_base_points enable row level security;
alter table public.scheme_factor enable row level security;
alter table public.rider_value enable row level security;
create policy read_all on public.rider_value for select to authenticated using (true);

alter table public.rider_value_history add column if not exists scheme text not null default 'cyc';
alter table public.rider_value_history drop constraint if exists rider_value_history_pkey;
alter table public.rider_value_history add primary key (rider_id, scheme, day);

create or replace function public.rider_value(p_rider bigint, p_scheme text) returns bigint
language sql stable as $fn$
  select coalesce((select v.value from public.rider_value v where v.rider_id = p_rider and v.scheme = p_scheme),
                  (select r.market_value from public.rider r where r.id = p_rider))
$fn$;

-- puntos de temporada, por sistema
create or replace view public.rider_season_points with (security_invoker = true) as
  select rs.rider_id, extract(year from s.date)::smallint as season, sum(rs.points)::integer as points, rs.scheme
  from public.rider_score rs join public.stage s on s.id = rs.stage_id
  group by rs.rider_id, extract(year from s.date), rs.scheme;

-- Puntos de la temporada base por sistema: historial (resultados de PCS) y carreras del juego de esa temporada
create or replace function public.compute_base_points() returns integer
language plpgsql as $fn$
declare
  vp public.value_params;
  n integer;
begin
  select * into vp from public.value_params;
  delete from public.rider_base_points;
  insert into public.rider_base_points (rider_id, scheme, points)
  select x.rider_id, x.scheme, sum(x.points)
  from (
    select h.rider_id, sch.scheme, sp.points
    from public.rider_history_result h
    cross join (values ('cyc'), ('cyc_wt'), ('uci')) sch(scheme)
    join public.scoring_points sp on sp.scheme = sch.scheme
         and sp.grp = public.scoring_group(sch.scheme, h.category, h.race_slug) and sp.position = h.position
         and sp.kind = case h.kind when 'stage' then (case when h.is_stage_race then 'stage' else 'oneday' end)
                                   when 'gc' then 'gc' when 'points' then 'points_final' else 'kom_final' end
    where h.season = vp.base_season and h.rider_id is not null
      and not public.is_excluded_race(h.race_slug, h.race_name, h.uci_class)
      and not exists (select 1 from public.race g where g.pcs_slug = h.race_slug and g.season = h.season)
    union all
    select rs.rider_id, rs.scheme, rs.points
    from public.rider_score rs join public.stage s on s.id = rs.stage_id join public.race rc on rc.id = s.race_id
    where rc.season = vp.base_season
  ) x
  group by x.rider_id, x.scheme;
  get diagnostics n = row_count;

  delete from public.scheme_factor;
  insert into public.scheme_factor (scheme, factor)
  select b.scheme, (select sum(points) from public.rider_base_points where scheme = 'cyc') / nullif(sum(b.points), 0)
  from public.rider_base_points b group by b.scheme;
  return n;
end $fn$;

-- Valores iniciales de cada sistema con los puntos normalizados de la temporada base. La curva se calibra para que
-- el ancla (Pogačar) valga el valor de referencia en Cyclonomy.
create or replace function public.seed_values_by_scheme() returns integer
language plpgsql as $fn$
declare
  vp public.value_params;
  p_anchor numeric;
  n integer;
  today date := (public.app_now() at time zone 'Europe/Madrid')::date;
begin
  select * into vp from public.value_params;
  select b.points into p_anchor from public.rider_base_points b join public.rider r on r.id = b.rider_id
  where r.pcs_slug = vp.anchor_slug and b.scheme = 'cyc';
  if p_anchor is null or p_anchor <= vp.floor_points then
    select max(points) into p_anchor from public.rider_base_points where scheme = 'cyc';
  end if;
  update public.value_params set exponent = ln(vp.anchor_value::numeric / vp.floor_value) / ln(p_anchor / vp.floor_points);

  delete from public.rider_value;
  insert into public.rider_value (rider_id, scheme, value)
  select r.id, f.scheme,
         public.value_from_points(coalesce(b.points, 0) * f.factor, public.age_at(r.birthdate, today))
  from public.rider r
  cross join public.scheme_factor f
  left join public.rider_base_points b on b.rider_id = r.id and b.scheme = f.scheme;
  get diagnostics n = row_count;

  update public.rider r set market_value = v.value, updated_at = now()
  from public.rider_value v where v.rider_id = r.id and v.scheme = 'cyc';

  delete from public.rider_value_history;
  insert into public.rider_value_history (rider_id, scheme, day, value)
  select rider_id, scheme, today, value from public.rider_value;
  return n;
end $fn$;

-- Actualización diaria, en cada sistema: hacia el valor de sus puntos (los de la temporada base, que pesan menos
-- a medida que avanza el juego, más los del juego de temporadas posteriores), con el efecto de los fichajes
create or replace function public.update_rider_values() returns integer
language plpgsql as $fn$
declare
  vp public.value_params;
  today date := (public.app_now() at time zone 'Europe/Madrid')::date;
  base_w numeric;
  n_leagues integer;
  n integer;
begin
  select * into vp from public.value_params;
  -- peso de los puntos de la temporada base: 1 antes de empezar el juego, baja a 0 en 365 días
  base_w := greatest(0, 1 - greatest(0, today - vp.game_start)::numeric / 365);
  select greatest(count(*), 1) into n_leagues from public.league;
  -- ciclistas nuevos (fichajes de la temporada): empiezan en cada sistema con su valor inicial
  insert into public.rider_value (rider_id, scheme, value)
  select r.id, f.scheme, r.market_value from public.rider r cross join public.scheme_factor f where r.active
  on conflict (rider_id, scheme) do nothing;

  with pts as (
    select rs.rider_id, rs.scheme, sum(rs.points) as p
    from public.rider_score rs join public.stage s on s.id = rs.stage_id join public.race rc on rc.id = s.race_id
    where s.date > today - 365 and s.date <= today and rc.season > vp.base_season
    group by rs.rider_id, rs.scheme
  ), hype as (
    select l.rider_id,
           sum(case l.kind when 'market_buy' then 1 when 'clause_paid' then 2 when 'sale_game' then -1 end)::numeric as h
    from public.ledger l
    where l.created_at > public.app_now() - interval '7 days'
      and l.kind in ('market_buy', 'clause_paid', 'sale_game') and l.rider_id is not null
    group by l.rider_id
  ), calc as (
    select v.rider_id, v.scheme, v.value::numeric as v,
           public.value_from_points((coalesce(pts.p, 0) + coalesce(b.points, 0) * base_w) * f.factor,
                                    public.age_at(r.birthdate, today), vp.daily_round)::numeric as target,
           greatest(-vp.hype_cap, least(vp.hype_cap, coalesce(hype.h, 0) / n_leagues * vp.hype_scale)) as hype_pct
    from public.rider_value v
    join public.rider r on r.id = v.rider_id and r.active
    join public.scheme_factor f on f.scheme = v.scheme
    left join public.rider_base_points b on b.rider_id = v.rider_id and b.scheme = v.scheme
    left join pts on pts.rider_id = v.rider_id and pts.scheme = v.scheme
    left join hype on hype.rider_id = v.rider_id
  )
  update public.rider_value rv
     set value = greatest(vp.floor_value,
           round((c.v + greatest(-vp.daily_cap * c.v,
                                 least(vp.daily_cap * c.v, vp.reversion * (c.target - c.v) + c.hype_pct * c.v)))
                 / vp.daily_round) * vp.daily_round)::bigint
  from calc c where c.rider_id = rv.rider_id and c.scheme = rv.scheme;
  get diagnostics n = row_count;

  update public.rider r set market_value = v.value, updated_at = now()
  from public.rider_value v where v.rider_id = r.id and v.scheme = 'cyc';

  insert into public.rider_value_history (rider_id, scheme, day, value)
  select v.rider_id, v.scheme, today, v.value from public.rider_value v join public.rider r on r.id = v.rider_id
  where r.active
  on conflict (rider_id, scheme, day) do update set value = excluded.value;
  insert into public.job_state (key, last_day) values ('rider_values', today)
  on conflict (key) do update set last_day = excluded.last_day, updated_at = now();
  return n;
end $fn$;

create or replace function public.get_roster(p_league uuid, p_member uuid default null)
returns table (ownership_id bigint, rider_id bigint, rider_name text, pro_team text, nationality text, age integer,
               market_value bigint, price_paid bigint, clause bigint, next_clause bigint, next_clause_cost bigint,
               season_points integer, league_points integer, status text, available_from timestamptz,
               for_sale boolean, game_offer_id bigint, game_offer_amount bigint, game_offer_expires timestamptz,
               transferable boolean, photo_url text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_scheme text := public.league_scheme(p_league);
  me public.league_member := public.my_member(p_league);
  v_target uuid := coalesce(p_member, me.id);
  v_mine boolean := coalesce(p_member, me.id) = me.id;
  v_now timestamptz := public.app_now();
  v_season integer := extract(year from public.app_now() at time zone 'Europe/Madrid');
begin
  if not exists (select 1 from public.league_member where id = v_target and league_id = p_league) then
    raise exception 'Ese jugador no está en esta liga';
  end if;
  return query
  select o.id, r.id, r.name, t.name, r.nationality, public.age_at(r.birthdate)::int,
         public.rider_value(r.id, v_scheme), o.price_paid, o.clause,
         greatest(o.clause, least(round(o.clause * 1.5)::bigint, o.price_paid * 3)),
         ceil((greatest(o.clause, least(round(o.clause * 1.5)::bigint, o.price_paid * 3)) - o.clause) / 2.0)::bigint,
         coalesce(sp.points, 0),
         coalesce((select sum(ms.points)::int from public.member_score ms
                   where ms.member_id = v_target and ms.rider_id = r.id), 0),
         case when o.pending_member_id = v_target then 'incoming'
              when o.pending_member_id is not null then 'leaving'
              when o.eligible_from > v_now then 'incoming'
              else 'ok' end,
         coalesce(o.transfer_at, case when o.eligible_from > v_now then o.eligible_from end),
         case when v_mine then o.for_sale else false end,
         g.id, g.amount, g.expires_at,
         o.member_id = v_target and o.pending_member_id is null,   -- se puede ofertar o pagar su cláusula
         r.photo_url
  from public.ownership o
  join public.rider r on r.id = o.rider_id
  left join public.team t on t.id = r.team_id
  left join public.rider_season_points sp on sp.rider_id = r.id and sp.season = v_season and sp.scheme = v_scheme
  left join lateral (select go.id, go.amount, go.expires_at from public.game_offer go
                     where v_mine and go.ownership_id = o.id and go.status = 'open' and go.expires_at > v_now
                     order by go.created_at desc limit 1) g on true
  where o.league_id = p_league and (o.member_id = v_target or o.pending_member_id = v_target)
  order by public.rider_value(r.id, v_scheme) desc;
end $$;

create or replace function public.get_market(p_league uuid)
returns table (listing_id bigint, rider_id bigint, rider_name text, pro_team text, nationality text, age integer,
               base_value bigint, market_value bigint, season_points integer, closes_at timestamptz,
               bid_count integer, my_bid bigint, photo_url text, seller_member_id uuid, seller_team text,
               is_mine boolean, seller_ownership_id bigint, game_offer_id bigint, game_offer_amount bigint,
               game_offer_expires timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare
  v_scheme text := public.league_scheme(p_league);
  me public.league_member := public.my_member(p_league);
  v_season integer := extract(year from public.app_now() at time zone 'Europe/Madrid');
begin
  return query
  select l.id, r.id, r.name, t.name, r.nationality, public.age_at(r.birthdate)::int, l.base_value, public.rider_value(r.id, v_scheme),
         coalesce(sp.points, 0), l.closes_at,
         (select count(*)::int from public.bid b where b.listing_id = l.id),
         (select b.amount from public.bid b where b.listing_id = l.id and b.member_id = me.id),
         r.photo_url, l.seller_member_id, sm.team_name, coalesce(l.seller_member_id = me.id, false),
         case when l.seller_member_id = me.id then l.seller_ownership_id end,
         g.id, g.amount, g.expires_at
  from public.market_listing l
  join public.rider r on r.id = l.rider_id
  left join public.team t on t.id = r.team_id
  left join public.rider_season_points sp on sp.rider_id = r.id and sp.season = v_season and sp.scheme = v_scheme
  left join public.league_member sm on sm.id = l.seller_member_id
  left join public.ownership o on o.id = l.seller_ownership_id
  left join lateral (select go.id, go.amount, go.expires_at from public.game_offer go
                     where l.seller_member_id = me.id and go.ownership_id = l.seller_ownership_id
                       and go.status = 'open' and go.expires_at > public.app_now()
                     order by go.created_at desc limit 1) g on true
  where l.league_id = p_league and not l.resolved
    and (l.seller_ownership_id is null or (o.for_sale and o.pending_member_id is null))
  order by l.closes_at, l.base_value desc;
end $$;

create or replace function public.get_entry(p_league uuid, p_race bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_scheme text := public.league_scheme(p_league);
  me public.league_member := public.my_member(p_league);
  rc public.race;
  cat public.race_category;
  v_season integer;
  v_entry bigint;
begin
  select * into rc from public.race where id = p_race;
  if not found then raise exception 'La carrera no existe'; end if;
  select * into cat from public.race_category where code = rc.category;
  v_season := extract(year from rc.start_date);
  select id into v_entry from public.race_entry where race_id = p_race and member_id = me.id;
  return jsonb_build_object(
    'race', jsonb_build_object('id', rc.id, 'name', rc.name, 'category', rc.category, 'category_name', cat.name,
                               'start_date', rc.start_date, 'end_date', rc.end_date, 'country', rc.country,
                               'entries_close_at', rc.entries_close_at),
    'max_entries', cat.max_entries,
    'open', public.app_now() < rc.entries_close_at,
    'auto', coalesce((select auto from public.race_entry where id = v_entry), false),
    'entered', coalesce((select jsonb_agg(rider_id) from public.race_entry_rider where entry_id = v_entry), '[]'::jsonb),
    'has_startlist', exists (select 1 from public.startlist where race_id = p_race),
    'riders', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rider_id', r.id, 'name', r.name, 'pro_team', t.name, 'market_value', public.rider_value(r.id, v_scheme),
               'season_points', coalesce(sp.points, 0),
               'on_startlist', exists (select 1 from public.startlist sl where sl.race_id = p_race and sl.rider_id = r.id),
               'available', o.member_id = me.id and o.pending_member_id is null and o.eligible_from <= public.app_now(),
               'status', case when o.pending_member_id = me.id or (o.pending_member_id is null and o.eligible_from > public.app_now())
                              then 'incoming' when o.pending_member_id is not null then 'leaving' else 'ok' end)
             order by coalesce(sp.points, 0) desc, public.rider_value(r.id, v_scheme) desc)
      from public.ownership o
      join public.rider r on r.id = o.rider_id
      left join public.team t on t.id = r.team_id
      left join public.rider_season_points sp on sp.rider_id = r.id and sp.season = v_season and sp.scheme = v_scheme
      where o.league_id = p_league and (o.member_id = me.id or o.pending_member_id = me.id)), '[]'::jsonb));
end $$;

create or replace function public.get_ranking(p_league uuid, p_limit integer default null)
returns table (rider_id bigint, name text, pro_team text, nationality text, age integer, market_value bigint,
               season_points integer, owner_member_id uuid, owner_team text, is_mine boolean, photo_url text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_scheme text := public.league_scheme(p_league);
  me public.league_member := public.my_member(p_league);
  v_season integer := extract(year from public.app_now() at time zone 'Europe/Madrid');
begin
  return query
  select r.id, r.name, t.name, r.nationality, public.age_at(r.birthdate)::int, public.rider_value(r.id, v_scheme),
         coalesce(sp.points, 0), m.id, m.team_name, coalesce(m.id = me.id, false), r.photo_url
  from public.rider r
  left join public.team t on t.id = r.team_id
  left join public.rider_season_points sp on sp.rider_id = r.id and sp.season = v_season and sp.scheme = v_scheme
  left join public.ownership o on o.league_id = p_league and o.rider_id = r.id
  left join public.league_member m on m.id = o.member_id
  where r.active
  order by coalesce(sp.points, 0) desc, public.rider_value(r.id, v_scheme) desc, r.name
  limit p_limit;
end $$;

create or replace function public.get_race_entries(p_league uuid, p_stage bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_scheme text := public.league_scheme(p_league);
  me public.league_member := public.my_member(p_league);
  rc public.race;
  v_visible boolean;
begin
  select r.* into rc from public.stage s join public.race r on r.id = s.race_id where s.id = p_stage;
  if not found then raise exception 'La etapa no existe'; end if;
  v_visible := public.app_now() >= rc.entries_close_at;
  return jsonb_build_object(
    'race_id', rc.id,
    'visible', v_visible,
    'entries_close_at', rc.entries_close_at,
    'max_entries', (select max_entries from public.race_category where code = rc.category),
    'teams', coalesce((
      select jsonb_agg(jsonb_build_object(
               'member_id', m.id, 'team_name', m.team_name, 'is_mine', m.id = me.id, 'country', m.country,
               'hidden', not v_visible and m.id <> me.id,
               'entered', e.id is not null, 'auto', coalesce(e.auto, false),
               'riders', case when not v_visible and m.id <> me.id then '[]'::jsonb else coalesce((
                 select jsonb_agg(jsonb_build_object('rider_id', r.id, 'name', r.name, 'pro_team', t.name,
                                                     'nationality', r.nationality, 'photo_url', r.photo_url)
                                  order by public.rider_value(r.id, v_scheme) desc)
                 from public.race_entry_rider er join public.rider r on r.id = er.rider_id
                 left join public.team t on t.id = r.team_id
                 where er.entry_id = e.id), '[]'::jsonb) end)
             order by (m.id = me.id) desc, m.team_name)
      from public.league_member m
      left join public.race_entry e on e.race_id = rc.id and e.member_id = m.id
      where m.league_id = p_league), '[]'::jsonb),
    'startlist', coalesce((
      select jsonb_agg(jsonb_build_object('team_name', g.team_name, 'riders', g.riders) order by g.first_bib nulls last, g.team_name)
      from (
        select sr.team_name, min(sr.bib) first_bib,
               jsonb_agg(jsonb_build_object(
                 'rider_id', sr.rider_id, 'name', coalesce(r.name, sr.rider_name), 'nationality', coalesce(r.nationality, sr.nationality),
                 'bib', sr.bib, 'photo_url', r.photo_url,
                 'teams', coalesce((
                   select jsonb_agg(m.team_name order by m.team_name)
                   from public.race_entry e
                   join public.league_member m on m.id = e.member_id
                   join public.race_entry_rider er on er.entry_id = e.id
                   where e.race_id = rc.id and e.league_id = p_league and er.rider_id = sr.rider_id
                     and (v_visible or e.member_id = me.id)), '[]'::jsonb))
                 order by sr.bib nulls last, sr.rider_name) riders
        from public.startlist_rider sr
        left join public.rider r on r.id = sr.rider_id
        where sr.race_id = rc.id
        group by sr.team_name) g), '[]'::jsonb));
end $$;

create or replace function public.get_stage_scores(p_league uuid, p_stage bigint, p_part text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
  v_scheme text := public.league_scheme(p_league);
  -- 'stage': lo de la propia etapa; 'final': las clasificaciones finales (general, regularidad, montaña); null: todo
  v_kinds text[] := case p_part when 'stage' then array['stage', 'oneday', 'kom_jersey', 'points_jersey', 'leader']
                                when 'final' then array['gc', 'points_final', 'kom_final']
                                else array['stage', 'oneday', 'kom_jersey', 'points_jersey', 'leader', 'gc', 'points_final', 'kom_final'] end;
begin
  return jsonb_build_object(
    'stage', (select jsonb_build_object('id', s.id, 'number', s.number, 'date', s.date, 'status', s.status,
                                        'race_id', rc.id, 'race_name', rc.name, 'is_stage_race', rc.is_stage_race,
                                        'country', rc.country)
              from public.stage s join public.race rc on rc.id = s.race_id where s.id = p_stage),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('member_id', m.id, 'team_name', m.team_name, 'points', x.pts,
                                          'is_mine', m.id = me.id, 'country', m.country,
                                          -- sus ciclistas inscritos en la carrera y lo que ha puntuado cada uno
                                          -- (las inscripciones de los demás solo se ven al cerrar la inscripción)
                                          'riders', coalesce((
                                            select jsonb_agg(jsonb_build_object('rider_id', r.id, 'name', r.name,
                                                                                'points', rp.pts)
                                                             order by rp.pts desc, public.rider_value(r.id, v_scheme) desc)
                                            from public.stage s
                                            join public.race rc on rc.id = s.race_id
                                            join public.race_entry e on e.race_id = rc.id and e.member_id = m.id
                                            join public.race_entry_rider er on er.entry_id = e.id
                                            join public.rider r on r.id = er.rider_id
                                            left join public.member_score ms on ms.stage_id = p_stage
                                                 and ms.member_id = m.id and ms.rider_id = r.id
                                            -- lo que puntuó para el jugador (solo si le contaba: hay member_score)
                                            cross join lateral (
                                              select coalesce(sum(rs.points), 0)::int pts from public.rider_score rs
                                              where ms.member_id is not null and rs.stage_id = p_stage
                                                and rs.rider_id = r.id and rs.kind = any(v_kinds) and rs.scheme = v_scheme) rp
                                            where s.id = p_stage
                                              and (m.id = me.id or public.app_now() >= rc.entries_close_at)), '[]'::jsonb))
                       order by x.pts desc, m.team_name)
      from public.league_member m
      cross join lateral (select coalesce(sum(rs.points), 0)::int pts from public.member_score ms
                          join public.rider_score rs on rs.stage_id = ms.stage_id and rs.rider_id = ms.rider_id
                          where ms.stage_id = p_stage and ms.member_id = m.id and rs.kind = any(v_kinds)
                            and rs.scheme = v_scheme) x
      where m.league_id = p_league), '[]'::jsonb),
    'riders', coalesce((
      select jsonb_agg(jsonb_build_object('rider_id', r.id, 'name', r.name, 'points', x.pts, 'owner', own.team_name,
                                          'pro_team', t.name, 'nationality', r.nationality, 'photo_url', r.photo_url,
                                          'entered_by', coalesce((
                                            select jsonb_agg(lm.team_name order by lm.team_name)
                                            from public.member_score ms2 join public.league_member lm on lm.id = ms2.member_id
                                            where ms2.stage_id = p_stage and ms2.league_id = p_league
                                              and ms2.rider_id = r.id), '[]'::jsonb),
                                          'entered_by_me', exists (
                                            select 1 from public.member_score ms2
                                            where ms2.stage_id = p_stage and ms2.member_id = me.id
                                              and ms2.rider_id = r.id))
                       order by x.pts desc)
      from (select rs.rider_id, sum(rs.points)::int pts from public.rider_score rs
            where rs.stage_id = p_stage and rs.kind = any(v_kinds) and rs.scheme = v_scheme
            group by rs.rider_id) x
      join public.rider r on r.id = x.rider_id
      left join public.team t on t.id = r.team_id
      left join lateral (select lm.team_name from public.ownership o join public.league_member lm on lm.id = o.member_id
                         where o.league_id = p_league and o.rider_id = r.id) own on true), '[]'::jsonb));
end $$;

create or replace function public.get_rider(p_league uuid, p_rider bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
  v_scheme text := public.league_scheme(p_league);
  v_season integer := extract(year from public.app_now() at time zone 'Europe/Madrid');
  v_today date := (public.app_now() at time zone 'Europe/Madrid')::date;
begin
  if not exists (select 1 from public.rider where id = p_rider) then
    raise exception 'El ciclista no existe';
  end if;
  return jsonb_build_object(
    'rider', (select jsonb_build_object(
                'id', r.id, 'name', r.name, 'pro_team', t.name, 'nationality', r.nationality,
                'age', public.age_at(r.birthdate)::int, 'market_value', public.rider_value(r.id, v_scheme),
                'season_points', coalesce((select sp.points from public.rider_season_points sp
                                           where sp.rider_id = r.id and sp.season = v_season and sp.scheme = v_scheme), 0),
                'photo', case when r.photo_url is null then null else jsonb_build_object(
                           'url', r.photo_url, 'author', r.photo_author, 'license', r.photo_license,
                           'license_url', r.photo_license_url, 'page_url', r.photo_page_url) end)
              from public.rider r left join public.team t on t.id = r.team_id where r.id = p_rider),
    'owner', (select jsonb_build_object('member_id', m.id, 'team_name', m.team_name, 'is_mine', m.id = me.id,
                                        'clause', o.clause)
              from public.ownership o join public.league_member m on m.id = o.member_id
              where o.league_id = p_league and o.rider_id = p_rider),
    'values', coalesce((
      select jsonb_agg(jsonb_build_object('day', h.day, 'value', h.value) order by h.day)
      from public.rider_value_history h
      where h.rider_id = p_rider and h.scheme = v_scheme and h.day > v_today - 365 and h.day <= v_today), '[]'::jsonb),
    'results', coalesce((
      select jsonb_agg(jsonb_build_object(
               'stage_id', x.stage_id, 'race_key', x.race_key, 'race_start', x.race_start, 'race_end', x.race_end,
               'race_name', x.race_name, 'country', x.country, 'category', x.category,
               'is_stage_race', x.is_stage_race, 'number', x.number, 'date', x.date, 'kind', x.kind,
               'position', x.position, 'points', x.points)
             order by x.date desc, x.kind_order)
      from (
        -- resultados del juego
        (select s.id stage_id, 'g' || rc.id race_key, rc.start_date race_start, rc.end_date race_end, rc.name race_name, rc.country, rc.category, rc.is_stage_race, s.number, s.date,
                res.kind, res.position,
                case res.kind when 'stage' then 0 when 'gc' then 1 when 'points' then 2 else 3 end kind_order,
                coalesce((select sum(rs.points)::int from public.rider_score rs
                          where rs.stage_id = s.id and rs.rider_id = p_rider and rs.scheme = v_scheme
                            and rs.kind = case res.kind when 'stage' then (case when rc.is_stage_race then 'stage' else 'oneday' end)
                                                        when 'gc' then 'gc' when 'points' then 'points_final'
                                                        else 'kom_final' end), 0) points
         from public.result res
         join public.stage s on s.id = res.stage_id
         join public.race rc on rc.id = s.race_id
         where res.rider_id = p_rider
           and (res.kind = 'stage'
                or (rc.is_stage_race and res.kind in ('gc', 'points', 'kom')
                    and s.number = (select max(s2.number) from public.stage s2 where s2.race_id = rc.id))))
        union all
        -- historial: los puntos son los que daría la tabla de puntuación de la liga
        (select null::bigint, 'h' || h.season || '-' || h.race_slug,
                min(h.date) over (partition by h.season, h.race_slug), max(h.date) over (partition by h.season, h.race_slug),
                h.race_name, h.country, h.category, h.is_stage_race, h.number, h.date, h.kind, h.position,
                case h.kind when 'stage' then 0 when 'gc' then 1 when 'points' then 2 else 3 end,
                coalesce((select sr.points from public.scoring_points sr
                          where sr.scheme = v_scheme and sr.grp = public.scoring_group(v_scheme, h.category, h.race_slug)
                            and sr.position = h.position
                            and sr.kind = case h.kind when 'stage' then (case when h.is_stage_race then 'stage' else 'oneday' end)
                                                      when 'gc' then 'gc' when 'points' then 'points_final'
                                                      else 'kom_final' end), 0)
         from public.rider_history_result h
         where h.rider_id = p_rider
           -- si la carrera también está en el calendario del juego, valen sus resultados (no se repiten)
           and not exists (select 1 from public.race g where g.pcs_slug = h.race_slug and g.season = h.season))
        order by 10 desc
        limit 600) x), '[]'::jsonb));
end $$;

create or replace function public.auto_lineup(p_race bigint) returns integer
language plpgsql as $$
declare
  rc public.race;
  cat public.race_category;
  m record;
  v_entry bigint;
  v_season integer;
  n integer := 0;
begin
  select * into rc from public.race where id = p_race for update;
  select * into cat from public.race_category where code = rc.category;
  v_season := extract(year from rc.start_date);

  for m in
    select lm.id as member_id, lm.league_id
    from public.league_member lm join public.league lg on lg.id = lm.league_id
    where cat.depth_level <= lg.calendar_depth
      and not exists (select 1 from public.race_entry e where e.race_id = p_race and e.member_id = lm.id)
  loop
    insert into public.race_entry (league_id, race_id, member_id, auto, updated_at)
    values (m.league_id, p_race, m.member_id, true, public.app_now())
    returning id into v_entry;

    insert into public.race_entry_rider (entry_id, rider_id)
    select v_entry, q.rider_id from (
      select o.rider_id
      from public.ownership o
      join public.startlist sl on sl.race_id = p_race and sl.rider_id = o.rider_id
      join public.rider r on r.id = o.rider_id
      left join public.rider_season_points sp on sp.rider_id = o.rider_id and sp.season = v_season and sp.scheme = public.league_scheme(o.league_id)
      where o.league_id = m.league_id and o.member_id = m.member_id
        and o.pending_member_id is null and o.eligible_from <= public.app_now()
      order by coalesce(sp.points, 0) desc, r.market_value desc, random()
      limit cat.max_entries
    ) q;
    n := n + 1;
  end loop;

  update public.race set auto_lineup_done = true where id = p_race;
  return n;
end $$;

create or replace function public.team_value(p_member uuid) returns bigint
language sql stable as $$
  select coalesce(sum(public.rider_value(r.id, public.league_scheme(o.league_id))), 0)::bigint
  from public.ownership o join public.rider r on r.id = o.rider_id
  where (o.member_id = p_member and o.pending_member_id is null) or o.pending_member_id = p_member
$$;

create or replace function public.free_riders(p_league uuid)
returns table (id bigint, market_value bigint) language sql stable as $$
  select r.id, public.rider_value(r.id, public.league_scheme(p_league)) from public.rider r
  where r.active and r.team_id is not null
    and not exists (select 1 from public.ownership o where o.league_id = p_league and o.rider_id = r.id)
    and not exists (select 1 from public.market_listing l
                    where l.league_id = p_league and l.rider_id = r.id and not l.resolved)
$$;

create or replace function public.assign_initial_team(p_member uuid, p_count int default 16,
    p_target bigint default 4000000, p_tol bigint default 100000, p_cap bigint default 1500000)
returns void language plpgsql as $$
declare
  v_league uuid;
  v_scheme text;
  picked bigint[];
  s bigint; x bigint; xv bigint; y bigint; yv bigint; desired bigint;
begin
  select league_id into v_league from public.league_member where id = p_member;
  v_scheme := public.league_scheme(v_league);
  select array_agg(f.id) into picked
  from (select f.id from public.free_riders(v_league) f where f.market_value <= p_cap order by random() limit p_count) f;
  if picked is null then return; end if;

  for i in 1..400 loop
    select sum(public.rider_value(id, v_scheme)) into s from public.rider where id = any (picked);
    exit when abs(s - p_target) <= p_tol;
    x := picked[1 + floor(random() * array_length(picked, 1))::int];
    xv := public.rider_value(x, v_scheme);
    desired := xv + (p_target - s);
    select c.id, c.market_value into y, yv
    from (select f.id, f.market_value from public.free_riders(v_league) f
          where f.market_value <= p_cap and not (f.id = any (picked))
          order by abs(f.market_value - desired) limit 5) c
    order by random() limit 1;
    if y is not null and abs(s - xv + yv - p_target) < abs(s - p_target) then
      picked := array_replace(picked, x, y);
    end if;
  end loop;

  insert into public.ownership (league_id, rider_id, member_id, price_paid, clause, acquired_at, eligible_from)
  select v_league, r.id, p_member, public.rider_value(r.id, v_scheme), round(public.rider_value(r.id, v_scheme) * 1.5),
         public.app_now(), public.app_now()
  from public.rider r where r.id = any (picked);
end $$;

create or replace function public.open_sale_listing(p_ownership bigint) returns bigint
language plpgsql as $$
declare
  o public.ownership;
  v_id bigint;
begin
  select * into o from public.ownership where id = p_ownership;
  select id into v_id from public.market_listing where seller_ownership_id = o.id and not resolved;
  if v_id is not null then return v_id; end if;
  insert into public.market_listing (league_id, rider_id, base_value, opened_at, closes_at,
                                     seller_member_id, seller_ownership_id)
  select o.league_id, o.rider_id, public.rider_value(r.id, public.league_scheme(o.league_id)), public.app_now(), public.app_now() + interval '48 hours',
         o.member_id, o.id
  from public.rider r where r.id = o.rider_id
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.make_sale_game_offers() returns integer
language plpgsql as $$
declare n integer;
begin
  insert into public.game_offer (ownership_id, member_id, rider_id, amount, created_at, expires_at)
  select o.id, o.member_id, o.rider_id, (round(public.rider_value(r.id, public.league_scheme(o.league_id)) * (0.9 + random() * 0.2) / 1000) * 1000)::bigint,
         public.app_now(), l.closes_at
  from public.market_listing l
  join public.ownership o on o.id = l.seller_ownership_id
  join public.rider r on r.id = o.rider_id
  where not l.resolved and l.closes_at > public.app_now()
    and l.closes_at - interval '12 hours' <= public.app_now()
    and o.for_sale and o.pending_member_id is null
    and not exists (select 1 from public.game_offer g where g.ownership_id = o.id and g.created_at >= l.opened_at);
  get diagnostics n = row_count;
  return n;
end $$;
