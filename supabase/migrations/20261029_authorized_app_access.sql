-- Acceso excepcional a APPFitbodygym sin crear pagos ni membresias ficticias.
-- Seguro e idempotente: no elimina columnas, tablas ni filas existentes.

alter table public.member_profiles
  add column if not exists authorized_access boolean not null default false,
  add column if not exists authorized_access_role text,
  add column if not exists authorized_access_expires_at date,
  add column if not exists authorized_access_note text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'member_profiles_authorized_access_role_check'
      and conrelid = 'public.member_profiles'::regclass
  ) then
    alter table public.member_profiles
      add constraint member_profiles_authorized_access_role_check
      check (
        authorized_access_role is null
        or authorized_access_role in (
          'developer',
          'owner',
          'trainer',
          'staff',
          'other'
        )
      );
  end if;
end $$;

create index if not exists member_profiles_authorized_access_idx
  on public.member_profiles(authorized_access)
  where authorized_access = true;

comment on column public.member_profiles.authorized_access is
  'Permite usar las funciones protegidas de la app sin membresia pagada.';

comment on column public.member_profiles.authorized_access_role is
  'Motivo operativo del acceso: developer, owner, trainer, staff u other.';
