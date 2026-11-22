-- =====================================================================
--  IronLog · Esquema de Supabase
--  Pega TODO este archivo en Supabase → SQL Editor → New query → Run.
--  Se puede ejecutar varias veces sin romper nada.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Registros de la app (ejercicios, días, sesiones, series, peso…)
--    Cada fila es un "registro" con su JSON. Nunca se borra de verdad:
--    se marca con deleted_at (borrado lógico).
-- ---------------------------------------------------------------------
create table if not exists public.gym_records (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  id         text        not null,
  kind       text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists gym_records_user_synced_idx on public.gym_records (user_id, synced_at);
create index if not exists gym_records_user_kind_idx   on public.gym_records (user_id, kind);

-- Guardián: jamás sobrescribir un dato más nuevo con uno más viejo.
-- Si llega una versión con updated_at <= la guardada, se ignora.
create or replace function public.gym_records_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at <= old.updated_at then
      return null;               -- se descarta la escritura antigua
    end if;
    new.user_id := old.user_id;  -- nadie puede "mover" un registro a otro usuario
  end if;
  new.synced_at := now();        -- marca de servidor para la descarga incremental
  return new;
end;
$$;

drop trigger if exists gym_records_guard on public.gym_records;
create trigger gym_records_guard
  before insert or update on public.gym_records
  for each row execute function public.gym_records_guard();

-- Seguridad a nivel de fila: solo TU usuario lee y escribe lo tuyo.
alter table public.gym_records enable row level security;

drop policy if exists "gym_records_select_own" on public.gym_records;
create policy "gym_records_select_own" on public.gym_records
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_records_insert_own" on public.gym_records;
create policy "gym_records_insert_own" on public.gym_records
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_records_update_own" on public.gym_records;
create policy "gym_records_update_own" on public.gym_records
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- A propósito NO hay política de DELETE: desde la app es imposible borrar
-- filas de verdad. Todo borrado es lógico (deleted_at) y recuperable.

grant select, insert, update on public.gym_records to authenticated;
-- Supabase concede por defecto permisos amplios: los recortamos.
revoke delete, truncate on public.gym_records from authenticated;
revoke all on public.gym_records from anon;

-- ---------------------------------------------------------------------
-- 2) Copias de seguridad diarias (instantánea completa en JSON).
--    Se conservan automáticamente las 30 más recientes.
-- ---------------------------------------------------------------------
create table if not exists public.gym_backups (
  id           bigint generated always as identity primary key,
  user_id      uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  day          date        not null,
  created_at   timestamptz not null default now(),
  record_count integer     not null default 0,
  payload      jsonb       not null,
  unique (user_id, day)
);

alter table public.gym_backups enable row level security;

drop policy if exists "gym_backups_select_own" on public.gym_backups;
create policy "gym_backups_select_own" on public.gym_backups
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_backups_insert_own" on public.gym_backups;
create policy "gym_backups_insert_own" on public.gym_backups
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_backups_update_own" on public.gym_backups;
create policy "gym_backups_update_own" on public.gym_backups
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update on public.gym_backups to authenticated;
revoke delete, truncate on public.gym_backups from authenticated;
revoke all on public.gym_backups from anon;
grant usage on all sequences in schema public to authenticated;

-- Poda automática: tras guardar una copia, deja solo las 30 más recientes de ese usuario.
create or replace function public.gym_backups_prune()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.gym_backups b
   where b.user_id = new.user_id
     and b.id not in (
       select id from public.gym_backups
        where user_id = new.user_id
        order by day desc, created_at desc
        limit 30
     );
  return null;
end;
$$;

drop trigger if exists gym_backups_prune on public.gym_backups;
create trigger gym_backups_prune
  after insert or update on public.gym_backups
  for each row execute function public.gym_backups_prune();

-- Listo. Comprobación rápida (debería devolver 0 filas y sin error):
select count(*) as registros from public.gym_records;
