-- =====================================================================
--  IronLog v2 · SQL NUEVO (perfil, medidas, fotos, preguntas/respuestas,
--  coach IA y clave privada) + bucket privado de fotos.
--  Si ya ejecutaste supabase.sql (v1), pega SOLO este archivo en
--  Supabase → SQL Editor → New query → Run.
--  Se puede ejecutar varias veces sin romper nada.
-- =====================================================================

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
