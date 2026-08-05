-- Ejecutar en el SQL Editor del proyecto Supabase.
create table if not exists public.member_profiles (
  local_member_id text primary key,
  auth_user_id uuid unique references auth.users(id) on delete set null,
  email text not null unique,
  full_name text not null,
  membership_active boolean not null default false,
  membership_start date,
  membership_end date,
  synced_at timestamptz not null default now()
);

alter table public.member_profiles enable row level security;

drop policy if exists "Members read only their profile" on public.member_profiles;
create policy "Members read only their profile"
on public.member_profiles for select
to authenticated
using (auth.uid() = auth_user_id);

-- Escrituras únicamente desde el sincronizador local usando service_role.
-- Nunca colocar service_role dentro de la aplicación Flutter.
