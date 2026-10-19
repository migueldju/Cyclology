-- =====================================================================================
-- 0036 · Cyclonomy: puntos para los compañeros de equipo de los ganadores. En cada etapa (o clásica), cada compañero
--        del ganador que la termina recibe el 10 % de los puntos del ganador; en la general final, el 10 % de los del
--        ganador y, en Tour, Giro y Vuelta, el 10 %, 7 % y 5 % de los del podio. No se aplica al sistema UCI.
--        Además: los puntos de la temporada base usan todo el historial (antes se perdían las carreras de esa
--        temporada que luego se cargaron en el calendario del juego) y se enlazan los resultados de ciclistas que
--        entraron en el juego después de correr.
-- =====================================================================================

-- resultados de ciclistas que entraron en el juego después (fichajes): se enlazan con su ficha
create or replace function public.relink_results() returns integer
language plpgsql as $fn$
declare n integer;
begin
  update public.result_full f set rider_id = r.id from public.rider r where f.rider_id is null and r.pcs_slug = f.rider_slug;
  get diagnostics n = row_count;
  insert into public.result (stage_id, kind, rider_id, position)
  select f.stage_id, f.kind, f.rider_id, f.position from public.result_full f
  where f.rider_id is not null on conflict do nothing;
  update public.startlist_rider sl set rider_id = r.id from public.rider r where sl.rider_id is null and r.pcs_slug = sl.rider_slug;
  return n;
end $fn$;

create or replace function public.score_stage(p_stage bigint) returns integer
language plpgsql as $$
declare
  s public.stage;
  rc public.race;
  is_last boolean;
  n integer;
begin
  select * into s from public.stage where id = p_stage;
  if not found then raise exception 'Etapa % no existe', p_stage; end if;
  select * into rc from public.race where id = s.race_id;
  is_last := s.number = (select max(number) from public.stage where race_id = s.race_id);

  delete from public.member_score where stage_id = p_stage;
  delete from public.rider_score where stage_id = p_stage;

  -- puntos de cada ciclista en cada sistema: Cyclonomy ('cyc', WT en A y B; 'cyc_wt', WT junto) y UCI ('uci')
  insert into public.rider_score (stage_id, rider_id, scheme, kind, points)
  select p_stage, r.rider_id, sch.scheme, x.score_kind, sum(sp.points)
  from public.result r
  cross join (values ('cyc'), ('cyc_wt'), ('uci')) as sch(scheme)
  join (values
          -- resultado, puntuación, solo en la última etapa, en vueltas (true) o en clásicas (false)
          ('stage', 'oneday', false, false), ('stage', 'stage', false, true),
          ('kom_leader', 'kom_jersey', false, true), ('gc', 'leader', false, true),
          ('points', 'points_jersey', false, true),
          ('gc', 'gc', true, true), ('points', 'points_final', true, true), ('kom', 'kom_final', true, true))
       as x(result_kind, score_kind, only_last, stage_race) on x.result_kind = r.kind and x.stage_race = rc.is_stage_race
  join public.scoring_points sp on sp.scheme = sch.scheme
                                and sp.grp = public.scoring_group(sch.scheme, rc.category, rc.pcs_slug)
                                and sp.kind = x.score_kind and sp.position = r.position
  where r.stage_id = p_stage and (not x.only_last or is_last)
  group by r.rider_id, sch.scheme, x.score_kind;
  get diagnostics n = row_count;

  -- Cyclonomy: los compañeros de equipo (los de la lista de salida que terminan) del ganador de la etapa o la clásica
  -- se llevan el 10 % de sus puntos; en la general final, el 10 % de los del ganador y, en Tour, Giro y Vuelta, el
  -- 10 %, 7 % y 5 % de los del 1.º, 2.º y 3.º. Sobre los puntos del puesto, aunque el ganador no esté en el juego.
  insert into public.rider_score (stage_id, rider_id, scheme, kind, points)
  select p_stage, mate.rider_id, sch.scheme, w.bonus_kind, round(sum(sp.points * w.pct))::int
  from (
    select c.result_kind, c.position, c.rider_slug,
           case when c.result_kind = 'stage' then 'team_stage' else 'team_gc' end as bonus_kind,
           case when c.result_kind = 'stage' or c.position = 1 then 0.10 when c.position = 2 then 0.07 else 0.05 end as pct,
           case when c.result_kind = 'gc' then 'gc' when rc.is_stage_race then 'stage' else 'oneday' end as score_kind
    from (
      select f.kind as result_kind, f.position, f.rider_slug from public.result_full f
      where f.stage_id = p_stage and f.kind in ('stage', 'gc') and f.position <= 3
      union
      select r.kind, r.position, rd.pcs_slug from public.result r join public.rider rd on rd.id = r.rider_id
      where r.stage_id = p_stage and r.kind in ('stage', 'gc') and r.position <= 3
        and not exists (select 1 from public.result_full f where f.stage_id = p_stage)
    ) c
    where (c.result_kind = 'stage' and c.position = 1)
       or (c.result_kind = 'gc' and rc.is_stage_race and is_last
           and c.position <= case when rc.category in ('TDF', 'GT') then 3 else 1 end)
  ) w
  join public.startlist_rider ws on ws.race_id = rc.id and ws.rider_slug = w.rider_slug
  join public.startlist_rider mate on mate.race_id = rc.id and mate.team_name = ws.team_name
                                  and mate.rider_slug <> w.rider_slug and mate.rider_id is not null
  cross join (values ('cyc'), ('cyc_wt')) as sch(scheme)
  join public.scoring_points sp on sp.scheme = sch.scheme
                                and sp.grp = public.scoring_group(sch.scheme, rc.category, rc.pcs_slug)
                                and sp.kind = w.score_kind and sp.position = w.position
  where exists (select 1 from public.result_full f where f.stage_id = p_stage and f.kind = w.result_kind
                and f.rider_slug = mate.rider_slug)
     or exists (select 1 from public.result r where r.stage_id = p_stage and r.kind = w.result_kind
                and r.rider_id = mate.rider_id)
  group by mate.rider_id, sch.scheme, w.bonus_kind
  having round(sum(sp.points * w.pct)) > 0;

  -- Puntos de cada jugador, con el sistema de su liga: ciclistas inscritos, ligas cuya profundidad incluye la
  -- carrera, y solo si el jugador no está sancionado por deuda esa semana
  insert into public.member_score (league_id, member_id, stage_id, rider_id, points)
  select e.league_id, e.member_id, p_stage, rs.rider_id, sum(rs.points)
  from public.race_entry e
  join public.league lg on lg.id = e.league_id
  join public.race_category c on c.code = rc.category and c.depth_level <= lg.calendar_depth
  join public.race_entry_rider er on er.entry_id = e.id
  join public.rider_score rs on rs.rider_id = er.rider_id and rs.stage_id = p_stage
                            and rs.scheme = public.league_scheme_of(lg)
  left join public.member_week mw on mw.member_id = e.member_id
                                 and mw.week_start = date_trunc('week', s.date)::date
  where e.race_id = rc.id and coalesce(mw.eligible, true)
  group by e.league_id, e.member_id, rs.rider_id;

  update public.stage set status = 'scored', scored_at = public.app_now() where id = p_stage;
  return n;
end $$;

create or replace function public.get_stage_scores(p_league uuid, p_stage bigint, p_part text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
  v_scheme text := public.league_scheme(p_league);
  -- 'stage': lo de la propia etapa; 'final': las clasificaciones finales (general, regularidad, montaña); null: todo
  v_kinds text[] := case p_part when 'stage' then array['stage', 'oneday', 'kom_jersey', 'points_jersey', 'leader', 'team_stage']
                                when 'final' then array['gc', 'points_final', 'kom_final', 'team_gc']
                                else array['stage', 'oneday', 'kom_jersey', 'points_jersey', 'leader', 'team_stage', 'gc', 'points_final',
                                     'kom_final', 'team_gc'] end;
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

create or replace function public.get_race_detail(p_league uuid, p_race bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
  v_scheme text := public.league_scheme(p_league);
  rc public.race;
  v_last bigint;
  v_kind text;
begin
  select * into rc from public.race where id = p_race;
  select s.id into v_last from public.stage s where s.race_id = p_race and s.status = 'scored'
  order by s.number desc limit 1;
  v_kind := case when rc.is_stage_race then 'gc' else 'stage' end;

  return jsonb_build_object(
    'stages', coalesce((
      select jsonb_agg(jsonb_build_object(
               'stage_id', s.id, 'number', s.number, 'date', s.date, 'status', s.status,
               'distance_km', s.distance_km, 'vertical_m', s.vertical_m,
               'my_points', (select coalesce(sum(points), 0) from public.member_score
                             where stage_id = s.id and member_id = me.id),
               'my_final_points', (select coalesce(sum(rs.points), 0) from public.member_score ms
                                   join public.rider_score rs on rs.stage_id = ms.stage_id and rs.rider_id = ms.rider_id
                                                              and rs.scheme = v_scheme
                                   where ms.stage_id = s.id and ms.member_id = me.id
                                     and rs.kind in ('gc', 'points_final', 'kom_final', 'team_gc')),
               'top_member', (select jsonb_build_object('team_name', m.team_name, 'points', sum(ms.points))
                              from public.member_score ms join public.league_member m on m.id = ms.member_id
                              where ms.stage_id = s.id and ms.league_id = p_league
                              group by m.id, m.team_name order by sum(ms.points) desc limit 1),
               -- ganador: de la clasificación completa si existe; si no (carreras antiguas), de los del juego
               'winner', coalesce(
                 (select jsonb_build_object(
                           'name', coalesce(rd.name, sl.rider_name, initcap(replace(f.rider_slug, '-', ' '))),
                           'nationality', coalesce(rd.nationality, sl.nationality),
                           'team', coalesce(sl.team_name, tm.name))
                  from public.result_full f
                  left join public.rider rd on rd.id = f.rider_id
                  left join public.team tm on tm.id = rd.team_id
                  left join public.startlist_rider sl on sl.race_id = p_race and sl.rider_slug = f.rider_slug
                  where f.stage_id = s.id and f.kind = 'stage' and f.position = 1 limit 1),
                 (select jsonb_build_object('name', rd.name, 'nationality', rd.nationality,
                                            'team', coalesce(sl.team_name, tm.name))
                  from public.result r join public.rider rd on rd.id = r.rider_id
                  left join public.team tm on tm.id = rd.team_id
                  left join public.startlist_rider sl on sl.race_id = p_race and sl.rider_id = rd.id
                  where r.stage_id = s.id and r.kind = 'stage' and r.position = 1 limit 1)))
             order by s.number)
      from public.stage s where s.race_id = p_race), '[]'::jsonb),
    'league_total', coalesce((
      select jsonb_agg(jsonb_build_object('member_id', x.member_id, 'team_name', m.team_name, 'points', x.pts,
                                          'country', m.country)
                       order by x.pts desc)
      from (select ms.member_id, sum(ms.points)::int pts from public.member_score ms
            join public.stage s on s.id = ms.stage_id
            where s.race_id = p_race and ms.league_id = p_league group by ms.member_id) x
      join public.league_member m on m.id = x.member_id), '[]'::jsonb),
    'gc', coalesce((
      select jsonb_agg(jsonb_build_object(
               'position', g.position, 'rider_id', g.rider_id, 'name', g.name, 'nationality', g.nationality,
               'team', g.team,
               'in_game', g.rider_id is not null,
               'scored_for', coalesce((
                 select jsonb_agg(x.team_name order by x.team_name)
                 from (select distinct lm.team_name from public.member_score ms
                       join public.stage s2 on s2.id = ms.stage_id
                       join public.league_member lm on lm.id = ms.member_id
                       where s2.race_id = p_race and ms.league_id = p_league
                         and ms.rider_id = g.rider_id and ms.points > 0) x), '[]'::jsonb))
             order by g.position)
      from (
        -- clasificación completa si existe; si no (carreras antiguas), solo los del juego
        select f.position, f.rider_id,
               coalesce(rd.name, sl.rider_name, initcap(replace(f.rider_slug, '-', ' '))) as name,
               coalesce(rd.nationality, sl.nationality) as nationality,
               coalesce(sl.team_name, tm.name) as team
        from public.result_full f
        left join public.rider rd on rd.id = f.rider_id
        left join public.team tm on tm.id = rd.team_id
        left join public.startlist_rider sl on sl.race_id = p_race and sl.rider_slug = f.rider_slug
        where f.stage_id = v_last and f.kind = v_kind and f.position <= 10
        union all
        select r.position, rd.id, rd.name, rd.nationality, tm.name
        from public.result r join public.rider rd on rd.id = r.rider_id
        left join public.team tm on tm.id = rd.team_id
        where r.stage_id = v_last and r.kind = v_kind and r.position <= 10
          and not exists (select 1 from public.result_full f where f.stage_id = v_last)
      ) g), '[]'::jsonb));
end $$;

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
    union all
    -- carreras del juego de esa temporada que no están en el historial (las que se corrieron después de cargarlo).
    -- Sin los puntos de compañeros de equipo, que el historial no tiene
    select rs.rider_id, rs.scheme, rs.points
    from public.rider_score rs join public.stage s on s.id = rs.stage_id join public.race rc on rc.id = s.race_id
    where rc.season = vp.base_season and rs.kind not in ('team_stage', 'team_gc')
      and not exists (select 1 from public.rider_history_result h where h.race_slug = rc.pcs_slug and h.season = rc.season)
  ) x
  group by x.rider_id, x.scheme;
  get diagnostics n = row_count;

  delete from public.scheme_factor;
  insert into public.scheme_factor (scheme, factor)
  select b.scheme, (select sum(points) from public.rider_base_points where scheme = 'cyc') / nullif(sum(b.points), 0)
  from public.rider_base_points b group by b.scheme;
  return n;
end $fn$;
