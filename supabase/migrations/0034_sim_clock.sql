-- =====================================================================================
-- 0034 · Reloj del juego desplazable, para probar con temporadas ya corridas. app_now() = ahora + offset_days
--        (días enteros: la hora del día es la real). Afecta a todo el juego (mercado, inscripciones, semanas) y a
--        la ingesta (planificación y tareas). Con offset_days = 0, la fecha real.
--        set_game_date('2026-03-01') pone hoy el juego en esa fecha; a partir de ahí el tiempo avanza normal.
-- =====================================================================================

create table if not exists public.app_clock (
  id           boolean primary key default true check (id),
  offset_days  integer not null default 0
);
alter table public.app_clock enable row level security;
insert into public.app_clock (id, offset_days) values (true, 0) on conflict (id) do nothing;

create or replace function public.app_now() returns timestamptz
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(current_setting('app.now', true), '')::timestamptz,
                  now() + make_interval(days => coalesce((select c.offset_days from public.app_clock c), 0)))
$$;

-- Pone el juego en esa fecha hoy (solo desde el editor SQL o la ingesta: no se expone a la app)
create or replace function public.set_game_date(p_date date) returns timestamptz
language plpgsql security definer set search_path = public as $$
begin
  update public.app_clock set offset_days = p_date - (now() at time zone 'Europe/Madrid')::date;
  return public.app_now();
end $$;
revoke all on function public.set_game_date(date) from public, anon, authenticated;

-- las tareas de la ingesta tocan según la hora del juego
create or replace function public.dispatch_due_ingest() returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.ingest_task where status = 'pending' and due_at <= public.app_now()) then
    return;
  end if;
  if exists (select 1 from public.job_state where key = 'ingest_dispatch' and updated_at > now() - interval '4 minutes') then
    return;
  end if;
  insert into public.job_state (key, updated_at) values ('ingest_dispatch', now())
  on conflict (key) do update set updated_at = now();
  perform public.dispatch_ingest('tick');
end $$;

-- La hora del juego, para que la app cuente «hoy» y las cuentas atrás con ella (y no con el reloj del móvil)
create or replace function public.get_game_now() returns timestamptz
language sql stable security definer set search_path = public as $$ select public.app_now() $$;
grant execute on function public.get_game_now() to anon, authenticated;
