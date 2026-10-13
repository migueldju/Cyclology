-- =====================================================================================
-- 0026 · La ingesta se lanza solo cuando hay algo que hacer: cada minuto se mira si alguna tarea ya toca
--        (inscripciones a la salida, puntos 30 min tras la llegada, relectura 2 h después) y, si es así, se dispara
--        el workflow de GitHub. Como mucho una vez cada 4 minutos, para no apilar ejecuciones mientras corre una.
-- =====================================================================================

create or replace function public.dispatch_due_ingest() returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.ingest_task where status = 'pending' and due_at <= now()) then
    return;
  end if;
  if exists (select 1 from public.job_state where key = 'ingest_dispatch' and updated_at > now() - interval '4 minutes') then
    return;
  end if;
  insert into public.job_state (key, updated_at) values ('ingest_dispatch', now())
  on conflict (key) do update set updated_at = now();
  perform public.dispatch_ingest('tick');
end $$;

revoke all on function public.dispatch_due_ingest() from public, anon, authenticated;

-- fuera el disparo cada 5 minutos: ahora, cada minuto, solo si hay tareas que tocan
select cron.unschedule(jobname) from cron.job where jobname in ('ingesta-tick', 'ingesta-due');
select cron.schedule('ingesta-due', '* * * * *', $$select public.dispatch_due_ingest()$$);
