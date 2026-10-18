-- =====================================================================================
-- 0030 · Detalle de carrera: el equipo del ganador de cada etapa y de cada ciclista de la general, y de los puntos
--        del jugador en cada etapa, cuántos son de las clasificaciones finales (para separar la última etapa y la
--        general)
-- =====================================================================================

create or replace function public.get_race_detail(p_league uuid, p_race bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
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
               'my_points', (select coalesce(sum(points), 0) from public.member_score
                             where stage_id = s.id and member_id = me.id),
               'my_final_points', (select coalesce(sum(rs.points), 0) from public.member_score ms
                                   join public.rider_score rs on rs.stage_id = ms.stage_id and rs.rider_id = ms.rider_id
                                   where ms.stage_id = s.id and ms.member_id = me.id
                                     and rs.kind in ('gc', 'points_final', 'kom_final')),
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
