-- =====================================================================================
-- 0032 · Puntuación de Cyclonomy propuesta (Excel «Mi puntuación»): nuevas tablas por categoría, con puntos por
--        liderar la general cada día y, en Tour, Giro y Vuelta, por llevar los maillots de puntos y montaña. Máximo
--        de inscritos por categoría. Fuera del juego los campeonatos nacionales (los continentales, solo Europa).
-- =====================================================================================

alter table public.scoring_rule drop constraint if exists scoring_rule_kind_check;
alter table public.scoring_rule add constraint scoring_rule_kind_check
  check (kind in ('oneday', 'gc', 'stage', 'points_final', 'kom_final', 'kom_jersey', 'points_jersey', 'leader'));

delete from public.scoring_rule where category in ('C1', 'CC', 'CC_ITT', 'GT', 'MON', 'MWT', 'PRO', 'SWT', 'TDF', 'WC', 'WC_ITT', 'WT', 'NC', 'NC_ITT');
insert into public.scoring_rule (category, kind, position, points) values
('TDF','gc',1,1400),
('TDF','gc',2,1000),
('TDF','gc',3,800),
('TDF','gc',4,675),
('TDF','gc',5,600),
('TDF','gc',6,500),
('TDF','gc',7,425),
('TDF','gc',8,375),
('TDF','gc',9,325),
('TDF','gc',10,275),
('TDF','gc',11,225),
('TDF','gc',12,175),
('TDF','gc',13,150),
('TDF','gc',14,125),
('TDF','gc',15,100),
('TDF','gc',16,85),
('TDF','gc',17,70),
('TDF','gc',18,60),
('TDF','gc',19,50),
('TDF','gc',20,40),
('TDF','gc',21,30),
('TDF','gc',22,20),
('TDF','gc',23,15),
('TDF','gc',24,10),
('TDF','gc',25,5),
('TDF','stage',1,250),
('TDF','stage',2,150),
('TDF','stage',3,100),
('TDF','stage',4,80),
('TDF','stage',5,60),
('TDF','stage',6,50),
('TDF','stage',7,40),
('TDF','stage',8,30),
('TDF','stage',9,20),
('TDF','stage',10,10),
('TDF','points_final',1,300),
('TDF','points_final',2,100),
('TDF','points_final',3,50),
('TDF','kom_final',1,300),
('TDF','kom_final',2,100),
('TDF','kom_final',3,50),
('TDF','leader',1,40),
('TDF','points_jersey',1,20),
('TDF','kom_jersey',1,20),
('GT','gc',1,1000),
('GT','gc',2,750),
('GT','gc',3,600),
('GT','gc',4,500),
('GT','gc',5,400),
('GT','gc',6,350),
('GT','gc',7,300),
('GT','gc',8,250),
('GT','gc',9,200),
('GT','gc',10,150),
('GT','gc',11,125),
('GT','gc',12,100),
('GT','gc',13,85),
('GT','gc',14,70),
('GT','gc',15,55),
('GT','gc',16,40),
('GT','gc',17,30),
('GT','gc',18,20),
('GT','gc',19,10),
('GT','gc',20,5),
('GT','stage',1,150),
('GT','stage',2,100),
('GT','stage',3,75),
('GT','stage',4,60),
('GT','stage',5,50),
('GT','stage',6,40),
('GT','stage',7,30),
('GT','stage',8,20),
('GT','stage',9,10),
('GT','stage',10,5),
('GT','points_final',1,180),
('GT','points_final',2,70),
('GT','points_final',3,40),
('GT','kom_final',1,180),
('GT','kom_final',2,70),
('GT','kom_final',3,40),
('GT','leader',1,30),
('GT','points_jersey',1,15),
('GT','kom_jersey',1,15),
('MON','oneday',1,750),
('MON','oneday',2,500),
('MON','oneday',3,375),
('MON','oneday',4,300),
('MON','oneday',5,250),
('MON','oneday',6,225),
('MON','oneday',7,200),
('MON','oneday',8,175),
('MON','oneday',9,150),
('MON','oneday',10,120),
('MON','oneday',11,90),
('MON','oneday',12,80),
('MON','oneday',13,70),
('MON','oneday',14,60),
('MON','oneday',15,50),
('MON','oneday',16,40),
('MON','oneday',17,30),
('MON','oneday',18,20),
('MON','oneday',19,10),
('MON','oneday',20,5),
('MWT','oneday',1,500),
('MWT','oneday',2,350),
('MWT','oneday',3,275),
('MWT','oneday',4,215),
('MWT','oneday',5,175),
('MWT','oneday',6,150),
('MWT','oneday',7,130),
('MWT','oneday',8,110),
('MWT','oneday',9,100),
('MWT','oneday',10,90),
('MWT','oneday',11,75),
('MWT','oneday',12,60),
('MWT','oneday',13,50),
('MWT','oneday',14,40),
('MWT','oneday',15,30),
('MWT','oneday',16,25),
('MWT','oneday',17,20),
('MWT','oneday',18,15),
('MWT','oneday',19,10),
('MWT','oneday',20,5),
('MWT','gc',1,500),
('MWT','gc',2,350),
('MWT','gc',3,275),
('MWT','gc',4,215),
('MWT','gc',5,175),
('MWT','gc',6,150),
('MWT','gc',7,130),
('MWT','gc',8,110),
('MWT','gc',9,100),
('MWT','gc',10,90),
('MWT','gc',11,75),
('MWT','gc',12,60),
('MWT','gc',13,50),
('MWT','gc',14,40),
('MWT','gc',15,30),
('MWT','gc',16,25),
('MWT','gc',17,20),
('MWT','gc',18,15),
('MWT','gc',19,10),
('MWT','gc',20,5),
('MWT','stage',1,100),
('MWT','stage',2,75),
('MWT','stage',3,60),
('MWT','stage',4,50),
('MWT','stage',5,40),
('MWT','stage',6,30),
('MWT','stage',7,20),
('MWT','stage',8,15),
('MWT','stage',9,10),
('MWT','stage',10,5),
('MWT','leader',1,20),
('MWT','points_final',1,60),
('MWT','kom_final',1,60),
('SWT','oneday',1,370),
('SWT','oneday',2,280),
('SWT','oneday',3,225),
('SWT','oneday',4,180),
('SWT','oneday',5,145),
('SWT','oneday',6,120),
('SWT','oneday',7,100),
('SWT','oneday',8,90),
('SWT','oneday',9,80),
('SWT','oneday',10,70),
('SWT','oneday',11,60),
('SWT','oneday',12,50),
('SWT','oneday',13,40),
('SWT','oneday',14,30),
('SWT','oneday',15,25),
('SWT','oneday',16,20),
('SWT','oneday',17,15),
('SWT','oneday',18,10),
('SWT','oneday',19,5),
('SWT','oneday',20,5),
('SWT','gc',1,370),
('SWT','gc',2,280),
('SWT','gc',3,225),
('SWT','gc',4,180),
('SWT','gc',5,145),
('SWT','gc',6,120),
('SWT','gc',7,100),
('SWT','gc',8,90),
('SWT','gc',9,80),
('SWT','gc',10,70),
('SWT','gc',11,60),
('SWT','gc',12,50),
('SWT','gc',13,40),
('SWT','gc',14,30),
('SWT','gc',15,25),
('SWT','gc',16,20),
('SWT','gc',17,15),
('SWT','gc',18,10),
('SWT','gc',19,5),
('SWT','gc',20,5),
('SWT','stage',1,75),
('SWT','stage',2,60),
('SWT','stage',3,50),
('SWT','stage',4,40),
('SWT','stage',5,30),
('SWT','stage',6,25),
('SWT','stage',7,20),
('SWT','stage',8,15),
('SWT','stage',9,10),
('SWT','stage',10,5),
('SWT','leader',1,15),
('SWT','points_final',1,50),
('SWT','kom_final',1,50),
('WT','oneday',1,500),
('WT','oneday',2,350),
('WT','oneday',3,275),
('WT','oneday',4,215),
('WT','oneday',5,175),
('WT','oneday',6,150),
('WT','oneday',7,130),
('WT','oneday',8,110),
('WT','oneday',9,100),
('WT','oneday',10,90),
('WT','oneday',11,75),
('WT','oneday',12,60),
('WT','oneday',13,50),
('WT','oneday',14,40),
('WT','oneday',15,30),
('WT','oneday',16,25),
('WT','oneday',17,20),
('WT','oneday',18,15),
('WT','oneday',19,10),
('WT','oneday',20,5),
('WT','gc',1,500),
('WT','gc',2,350),
('WT','gc',3,275),
('WT','gc',4,215),
('WT','gc',5,175),
('WT','gc',6,150),
('WT','gc',7,130),
('WT','gc',8,110),
('WT','gc',9,100),
('WT','gc',10,90),
('WT','gc',11,75),
('WT','gc',12,60),
('WT','gc',13,50),
('WT','gc',14,40),
('WT','gc',15,30),
('WT','gc',16,25),
('WT','gc',17,20),
('WT','gc',18,15),
('WT','gc',19,10),
('WT','gc',20,5),
('WT','stage',1,100),
('WT','stage',2,75),
('WT','stage',3,60),
('WT','stage',4,50),
('WT','stage',5,40),
('WT','stage',6,30),
('WT','stage',7,20),
('WT','stage',8,15),
('WT','stage',9,10),
('WT','stage',10,5),
('WT','leader',1,20),
('WT','points_final',1,60),
('WT','kom_final',1,60),
('PRO','oneday',1,225),
('PRO','oneday',2,175),
('PRO','oneday',3,125),
('PRO','oneday',4,100),
('PRO','oneday',5,85),
('PRO','oneday',6,70),
('PRO','oneday',7,60),
('PRO','oneday',8,50),
('PRO','oneday',9,40),
('PRO','oneday',10,30),
('PRO','oneday',11,25),
('PRO','oneday',12,20),
('PRO','oneday',13,15),
('PRO','oneday',14,10),
('PRO','oneday',15,5),
('PRO','gc',1,225),
('PRO','gc',2,175),
('PRO','gc',3,125),
('PRO','gc',4,100),
('PRO','gc',5,85),
('PRO','gc',6,70),
('PRO','gc',7,60),
('PRO','gc',8,50),
('PRO','gc',9,40),
('PRO','gc',10,30),
('PRO','gc',11,25),
('PRO','gc',12,20),
('PRO','gc',13,15),
('PRO','gc',14,10),
('PRO','gc',15,5),
('PRO','stage',1,70),
('PRO','stage',2,50),
('PRO','stage',3,40),
('PRO','stage',4,35),
('PRO','stage',5,30),
('PRO','stage',6,25),
('PRO','stage',7,20),
('PRO','stage',8,15),
('PRO','stage',9,10),
('PRO','stage',10,5),
('PRO','leader',1,10),
('PRO','points_final',1,30),
('PRO','kom_final',1,30),
('C1','oneday',1,150),
('C1','oneday',2,115),
('C1','oneday',3,95),
('C1','oneday',4,80),
('C1','oneday',5,60),
('C1','oneday',6,50),
('C1','oneday',7,40),
('C1','oneday',8,30),
('C1','oneday',9,20),
('C1','oneday',10,10),
('C1','gc',1,150),
('C1','gc',2,115),
('C1','gc',3,95),
('C1','gc',4,80),
('C1','gc',5,60),
('C1','gc',6,50),
('C1','gc',7,40),
('C1','gc',8,30),
('C1','gc',9,20),
('C1','gc',10,10),
('C1','stage',1,50),
('C1','stage',2,35),
('C1','stage',3,25),
('C1','stage',4,20),
('C1','stage',5,15),
('C1','stage',6,10),
('C1','stage',7,5),
('C1','stage',8,5),
('C1','leader',1,10),
('C1','points_final',1,20),
('C1','kom_final',1,20),
('WC','oneday',1,1000),
('WC','oneday',2,750),
('WC','oneday',3,600),
('WC','oneday',4,500),
('WC','oneday',5,425),
('WC','oneday',6,375),
('WC','oneday',7,325),
('WC','oneday',8,275),
('WC','oneday',9,225),
('WC','oneday',10,200),
('WC','oneday',11,175),
('WC','oneday',12,150),
('WC','oneday',13,130),
('WC','oneday',14,110),
('WC','oneday',15,100),
('WC','oneday',16,90),
('WC','oneday',17,80),
('WC','oneday',18,70),
('WC','oneday',19,60),
('WC','oneday',20,50),
('WC','oneday',21,45),
('WC','oneday',22,40),
('WC','oneday',23,35),
('WC','oneday',24,30),
('WC','oneday',25,25),
('WC','oneday',26,25),
('WC','oneday',27,25),
('WC','oneday',28,25),
('WC','oneday',29,25),
('WC','oneday',30,25),
('WC','oneday',31,20),
('WC','oneday',32,20),
('WC','oneday',33,20),
('WC','oneday',34,20),
('WC','oneday',35,20),
('WC','oneday',36,15),
('WC','oneday',37,15),
('WC','oneday',38,15),
('WC','oneday',39,15),
('WC','oneday',40,15),
('WC','oneday',41,10),
('WC','oneday',42,10),
('WC','oneday',43,10),
('WC','oneday',44,10),
('WC','oneday',45,10),
('WC','oneday',46,5),
('WC','oneday',47,5),
('WC','oneday',48,5),
('WC','oneday',49,5),
('WC','oneday',50,5),
('WC_ITT','oneday',1,500),
('WC_ITT','oneday',2,350),
('WC_ITT','oneday',3,275),
('WC_ITT','oneday',4,215),
('WC_ITT','oneday',5,175),
('WC_ITT','oneday',6,150),
('WC_ITT','oneday',7,125),
('WC_ITT','oneday',8,100),
('WC_ITT','oneday',9,80),
('WC_ITT','oneday',10,60),
('WC_ITT','oneday',11,40),
('WC_ITT','oneday',12,25),
('WC_ITT','oneday',13,15),
('WC_ITT','oneday',14,10),
('WC_ITT','oneday',15,5),
('CC','oneday',1,300),
('CC','oneday',2,200),
('CC','oneday',3,140),
('CC','oneday',4,120),
('CC','oneday',5,100),
('CC','oneday',6,80),
('CC','oneday',7,60),
('CC','oneday',8,50),
('CC','oneday',9,40),
('CC','oneday',10,30),
('CC','oneday',11,25),
('CC','oneday',12,20),
('CC','oneday',13,15),
('CC','oneday',14,10),
('CC','oneday',15,5),
('CC_ITT','oneday',1,180),
('CC_ITT','oneday',2,130),
('CC_ITT','oneday',3,90),
('CC_ITT','oneday',4,70),
('CC_ITT','oneday',5,50),
('CC_ITT','oneday',6,40),
('CC_ITT','oneday',7,30),
('CC_ITT','oneday',8,20),
('CC_ITT','oneday',9,10),
('CC_ITT','oneday',10,5);
update public.race_category set max_entries = 6 where code = 'C1';
update public.race_category set max_entries = 7 where code = 'CC';
update public.race_category set max_entries = 3 where code = 'CC_ITT';
update public.race_category set max_entries = 8 where code = 'GT';
update public.race_category set max_entries = 7 where code = 'MON';
update public.race_category set max_entries = 7 where code = 'MWT';
update public.race_category set max_entries = 6 where code = 'PRO';
update public.race_category set max_entries = 7 where code = 'SWT';
update public.race_category set max_entries = 8 where code = 'TDF';
update public.race_category set max_entries = 8 where code = 'WC';
update public.race_category set max_entries = 3 where code = 'WC_ITT';
update public.race_category set max_entries = 7 where code = 'WT';

-- campeonatos nacionales: fuera del juego (los continentales ya eran solo los de Europa)
create or replace function public.is_excluded_race(p_slug text, p_name text, p_uci_class text) returns boolean
language sql immutable as $fn$
  select (lower(p_slug) || ' ' || lower(p_name)) ~ '(mixed|relay|relevo|staffetta)'
      or (upper(p_uci_class) = 'CC' and (lower(p_slug) || ' ' || lower(p_name)) !~ '(europe|uec)')
      or upper(p_uci_class) = 'NC'
$fn$;
delete from public.race where public.is_excluded_race(pcs_slug, name, uci_class);

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
                                                             order by rp.pts desc, r.market_value desc)
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
