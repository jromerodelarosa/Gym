-- =====================================================================
--  IronLog · Esquema COMPLETO de Supabase (v1 + v2)
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



-- Guardián compartido (el mismo de la v1): jamás sobrescribir un dato más
-- nuevo con uno más viejo, y marca de servidor para la descarga incremental.
create or replace function public.gym_records_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at <= old.updated_at then
      return null;
    end if;
    new.user_id := old.user_id;
  end if;
  new.synced_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Perfil y objetivo de físico (lo que el coach sabe de ti)
-- ---------------------------------------------------------------------
create table if not exists public.gym_profile (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  id         text        not null,
  kind       text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists gym_profile_user_synced_idx on public.gym_profile (user_id, synced_at);

drop trigger if exists gym_profile_guard on public.gym_profile;
create trigger gym_profile_guard
  before insert or update on public.gym_profile
  for each row execute function public.gym_records_guard();

alter table public.gym_profile enable row level security;

drop policy if exists "gym_profile_select_own" on public.gym_profile;
create policy "gym_profile_select_own" on public.gym_profile
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_profile_insert_own" on public.gym_profile;
create policy "gym_profile_insert_own" on public.gym_profile
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_profile_update_own" on public.gym_profile;
create policy "gym_profile_update_own" on public.gym_profile
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sin política DELETE: los borrados son lógicos (deleted_at) y recuperables.
grant select, insert, update on public.gym_profile to authenticated;
revoke delete, truncate on public.gym_profile from authenticated;
revoke all on public.gym_profile from anon;

-- ---------------------------------------------------------------------
-- Medidas con cinta métrica
-- ---------------------------------------------------------------------
create table if not exists public.gym_measurements (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  id         text        not null,
  kind       text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists gym_measurements_user_synced_idx on public.gym_measurements (user_id, synced_at);

drop trigger if exists gym_measurements_guard on public.gym_measurements;
create trigger gym_measurements_guard
  before insert or update on public.gym_measurements
  for each row execute function public.gym_records_guard();

alter table public.gym_measurements enable row level security;

drop policy if exists "gym_measurements_select_own" on public.gym_measurements;
create policy "gym_measurements_select_own" on public.gym_measurements
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_measurements_insert_own" on public.gym_measurements;
create policy "gym_measurements_insert_own" on public.gym_measurements
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_measurements_update_own" on public.gym_measurements;
create policy "gym_measurements_update_own" on public.gym_measurements
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sin política DELETE: los borrados son lógicos (deleted_at) y recuperables.
grant select, insert, update on public.gym_measurements to authenticated;
revoke delete, truncate on public.gym_measurements from authenticated;
revoke all on public.gym_measurements from anon;

-- ---------------------------------------------------------------------
-- Fotos de progreso (solo datos: fecha y pose; la imagen va al bucket privado)
-- ---------------------------------------------------------------------
create table if not exists public.gym_photos (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  id         text        not null,
  kind       text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists gym_photos_user_synced_idx on public.gym_photos (user_id, synced_at);

drop trigger if exists gym_photos_guard on public.gym_photos;
create trigger gym_photos_guard
  before insert or update on public.gym_photos
  for each row execute function public.gym_records_guard();

alter table public.gym_photos enable row level security;

drop policy if exists "gym_photos_select_own" on public.gym_photos;
create policy "gym_photos_select_own" on public.gym_photos
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_photos_insert_own" on public.gym_photos;
create policy "gym_photos_insert_own" on public.gym_photos
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_photos_update_own" on public.gym_photos;
create policy "gym_photos_update_own" on public.gym_photos
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sin política DELETE: los borrados son lógicos (deleted_at) y recuperables.
grant select, insert, update on public.gym_photos to authenticated;
revoke delete, truncate on public.gym_photos from authenticated;
revoke all on public.gym_photos from anon;

-- ---------------------------------------------------------------------
-- Preguntas y respuestas: preguntas tras cada sesión y check-ins semanales
-- ---------------------------------------------------------------------
create table if not exists public.gym_checkins (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  id         text        not null,
  kind       text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists gym_checkins_user_synced_idx on public.gym_checkins (user_id, synced_at);

drop trigger if exists gym_checkins_guard on public.gym_checkins;
create trigger gym_checkins_guard
  before insert or update on public.gym_checkins
  for each row execute function public.gym_records_guard();

alter table public.gym_checkins enable row level security;

drop policy if exists "gym_checkins_select_own" on public.gym_checkins;
create policy "gym_checkins_select_own" on public.gym_checkins
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_checkins_insert_own" on public.gym_checkins;
create policy "gym_checkins_insert_own" on public.gym_checkins
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_checkins_update_own" on public.gym_checkins;
create policy "gym_checkins_update_own" on public.gym_checkins
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sin política DELETE: los borrados son lógicos (deleted_at) y recuperables.
grant select, insert, update on public.gym_checkins to authenticated;
revoke delete, truncate on public.gym_checkins from authenticated;
revoke all on public.gym_checkins from anon;

-- ---------------------------------------------------------------------
-- Coach: chat, propuestas de cambio y análisis de fotos
-- ---------------------------------------------------------------------
create table if not exists public.gym_coach (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  id         text        not null,
  kind       text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists gym_coach_user_synced_idx on public.gym_coach (user_id, synced_at);

drop trigger if exists gym_coach_guard on public.gym_coach;
create trigger gym_coach_guard
  before insert or update on public.gym_coach
  for each row execute function public.gym_records_guard();

alter table public.gym_coach enable row level security;

drop policy if exists "gym_coach_select_own" on public.gym_coach;
create policy "gym_coach_select_own" on public.gym_coach
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_coach_insert_own" on public.gym_coach;
create policy "gym_coach_insert_own" on public.gym_coach
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_coach_update_own" on public.gym_coach;
create policy "gym_coach_update_own" on public.gym_coach
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sin política DELETE: los borrados son lógicos (deleted_at) y recuperables.
grant select, insert, update on public.gym_coach to authenticated;
revoke delete, truncate on public.gym_coach from authenticated;
revoke all on public.gym_coach from anon;

-- ---------------------------------------------------------------------
-- Claves privadas (API key de Gemini). Solo tu usuario puede leerlas
-- ---------------------------------------------------------------------
create table if not exists public.gym_secrets (
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  id         text        not null,
  kind       text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists gym_secrets_user_synced_idx on public.gym_secrets (user_id, synced_at);

drop trigger if exists gym_secrets_guard on public.gym_secrets;
create trigger gym_secrets_guard
  before insert or update on public.gym_secrets
  for each row execute function public.gym_records_guard();

alter table public.gym_secrets enable row level security;

drop policy if exists "gym_secrets_select_own" on public.gym_secrets;
create policy "gym_secrets_select_own" on public.gym_secrets
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "gym_secrets_insert_own" on public.gym_secrets;
create policy "gym_secrets_insert_own" on public.gym_secrets
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "gym_secrets_update_own" on public.gym_secrets;
create policy "gym_secrets_update_own" on public.gym_secrets
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Sin política DELETE: los borrados son lógicos (deleted_at) y recuperables.
grant select, insert, update on public.gym_secrets to authenticated;
revoke delete, truncate on public.gym_secrets from authenticated;
revoke all on public.gym_secrets from anon;

-- ---------------------------------------------------------------------
-- Bucket PRIVADO para las fotos de progreso (máx. 5 MB por foto).
-- Cada usuario solo puede ver y subir fotos dentro de su propia carpeta
-- (<id de usuario>/<foto>.jpg). Sin política de borrado.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('progress-photos', 'progress-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false;

drop policy if exists "progress_photos_select_own" on storage.objects;
create policy "progress_photos_select_own" on storage.objects
  for select to authenticated
  using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "progress_photos_insert_own" on storage.objects;
create policy "progress_photos_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "progress_photos_update_own" on storage.objects;
create policy "progress_photos_update_own" on storage.objects
  for update to authenticated
  using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Comprobación: debe listar las 6 tablas nuevas y el bucket.
select table_name as tabla from information_schema.tables
 where table_schema = 'public' and table_name in ('gym_profile','gym_measurements','gym_photos','gym_checkins','gym_coach','gym_secrets')
union all
select 'bucket: ' || id from storage.buckets where id = 'progress-photos';
