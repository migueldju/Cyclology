-- PASO 2 de 2 · Fotos de perfil (Storage) y tareas programadas (pg_cron).
-- Ejecútalo después del paso 1, en otra consulta del SQL Editor.

-- =====================================================================================
-- 0006 · Piezas propias de Supabase: fotos de perfil (Storage) y tareas programadas (pg_cron).
-- (Los tests locales no ejecutan este archivo.)
-- =====================================================================================

-- Fotos de perfil: bucket público de lectura; cada usuario escribe solo en su carpeta <user_id>/
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars: subir la mía" on storage.objects;
drop policy if exists "avatars: cambiar la mía" on storage.objects;
drop policy if exists "avatars: borrar la mía" on storage.objects;
create policy "avatars: subir la mía" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars: cambiar la mía" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars: borrar la mía" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Tareas: cada minuto se comprueba qué toca (mercados, cambio de semana, ofertas, valores).
-- Toda la lógica de horarios está en run_due_jobs(), en hora de Madrid.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('fantasy-run-due-jobs', '* * * * *', $$select public.run_due_jobs()$$);

-- ============================================================ migrations/0025_ingest_dispatch.sql
-- =====================================================================================
-- 0025 · La ingesta la dispara Supabase: los horarios de GitHub Actions se retrasan horas o se saltan en repositorios
--        con poca actividad; pg_cron llama a la API de GitHub (workflow_dispatch), que ejecuta al momento.
--        Necesita un token de GitHub en Vault con el nombre 'github_ingest_token' (permiso Actions: lectura y
--        escritura en el repositorio). Sin token, los trabajos no hacen nada.
-- =====================================================================================

create extension if not exists pg_net with schema extensions;

create or replace function public.dispatch_ingest(p_cmd text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_token text;
begin
  select decrypted_secret into v_token from vault.decrypted_secrets where name = 'github_ingest_token' limit 1;
  if v_token is null then
    return;
  end if;
  perform net.http_post(
    url := 'https://api.github.com/repos/migueldju/Cyclonomy/actions/workflows/ingesta.yml/dispatches',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_token,
      'Accept', 'application/vnd.github+json',
      'X-GitHub-Api-Version', '2022-11-28',
      'User-Agent', 'cyclonomy-ingesta'),
    body := jsonb_build_object('ref', 'main', 'inputs', jsonb_build_object('cmd', p_cmd)));
end $$;

revoke all on function public.dispatch_ingest(text) from public, anon, authenticated;

-- horarios en UTC: tareas cada 5 min; plan a medianoche de Madrid (22:05 en verano, 23:05 en invierno) y repaso a
-- las 05:05; equipos y calendario los lunes
select cron.unschedule(jobname) from cron.job
where jobname in ('ingesta-tick', 'ingesta-plan', 'ingesta-teams', 'ingesta-calendar');
select cron.schedule('ingesta-tick', '*/5 * * * *', $$select public.dispatch_ingest('tick')$$);
select cron.schedule('ingesta-plan', '5 22,23,5 * * *', $$select public.dispatch_ingest('plan')$$);
select cron.schedule('ingesta-teams', '0 2 * * 1', $$select public.dispatch_ingest('teams')$$);
select cron.schedule('ingesta-calendar', '30 2 * * 1', $$select public.dispatch_ingest('calendar')$$);
