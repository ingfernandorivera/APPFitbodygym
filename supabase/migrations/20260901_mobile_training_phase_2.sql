-- FitBodyGym App - Fase 2
-- Migracion aditiva: no elimina ni modifica datos o tablas existentes.
-- Revisar y ejecutar manualmente en Supabase SQL Editor.

begin;

create extension if not exists pgcrypto;

create or replace function public.fitbodygym_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.training_assessments (
  id uuid primary key default gen_random_uuid(),
  member_id text not null references public.member_profiles(local_member_id) on delete cascade,
  weight_kg numeric(5,2) not null check (weight_kg between 25 and 350),
  height_cm numeric(5,2) not null check (height_cm between 100 and 250),
  age smallint not null check (age between 14 and 100),
  goal text not null check (length(trim(goal)) > 0),
  experience text not null check (length(trim(experience)) > 0),
  days_per_week smallint not null check (days_per_week between 1 and 7),
  minutes_per_session smallint not null check (minutes_per_session between 15 and 240),
  preferences text not null default '',
  limitations text not null default '',
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists training_assessments_one_current_per_member
  on public.training_assessments(member_id) where is_current;
create index if not exists training_assessments_member_created_idx
  on public.training_assessments(member_id, created_at desc);

create table if not exists public.exercise_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  muscle_group text not null,
  equipment text not null,
  instructions text not null default '',
  media_url text,
  media_type text check (media_type is null or media_type in ('image', 'gif', 'video')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (name, equipment)
);

create table if not exists public.workout_plans (
  id uuid primary key default gen_random_uuid(),
  member_id text not null references public.member_profiles(local_member_id) on delete cascade,
  assessment_id uuid references public.training_assessments(id) on delete set null,
  name text not null,
  goal text not null,
  status text not null default 'draft' check (status in ('draft', 'active', 'archived')),
  source text not null default 'ai' check (source in ('ai', 'coach', 'demo')),
  ai_summary text,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists workout_plans_one_active_per_member
  on public.workout_plans(member_id) where status = 'active';
create index if not exists workout_plans_member_created_idx
  on public.workout_plans(member_id, created_at desc);

create table if not exists public.workout_days (
  id uuid primary key default gen_random_uuid(),
  workout_plan_id uuid not null references public.workout_plans(id) on delete cascade,
  day_number smallint not null check (day_number between 1 and 7),
  title text not null,
  focus text not null default '',
  created_at timestamptz not null default now(),
  unique (workout_plan_id, day_number)
);

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_day_id uuid not null references public.workout_days(id) on delete cascade,
  exercise_id uuid references public.exercise_catalog(id) on delete restrict,
  exercise_name text not null,
  position smallint not null check (position > 0),
  sets smallint not null check (sets between 1 and 20),
  repetitions text not null,
  rest_seconds smallint not null check (rest_seconds between 0 and 900),
  instructions text not null default '',
  media_url text,
  created_at timestamptz not null default now(),
  unique (workout_day_id, position)
);

create table if not exists public.progress_entries (
  id uuid primary key default gen_random_uuid(),
  member_id text not null references public.member_profiles(local_member_id) on delete cascade,
  weight_kg numeric(5,2) check (weight_kg is null or weight_kg between 25 and 350),
  waist_cm numeric(5,2) check (waist_cm is null or waist_cm between 30 and 250),
  note text not null default '',
  recorded_on date not null default current_date,
  created_at timestamptz not null default now(),
  check (weight_kg is not null or waist_cm is not null or length(trim(note)) > 0),
  unique (member_id, recorded_on)
);

create index if not exists progress_entries_member_date_idx
  on public.progress_entries(member_id, recorded_on desc);

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  member_id text not null references public.member_profiles(local_member_id) on delete cascade,
  title text not null default 'Asistente de entrenamiento',
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null check (length(trim(content)) > 0),
  proposed_changes jsonb,
  changes_applied boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists ai_conversations_member_created_idx
  on public.ai_conversations(member_id, created_at desc);
create index if not exists ai_messages_conversation_created_idx
  on public.ai_messages(conversation_id, created_at);

drop trigger if exists training_assessments_set_updated_at on public.training_assessments;
create trigger training_assessments_set_updated_at before update on public.training_assessments
for each row execute function public.fitbodygym_set_updated_at();
drop trigger if exists exercise_catalog_set_updated_at on public.exercise_catalog;
create trigger exercise_catalog_set_updated_at before update on public.exercise_catalog
for each row execute function public.fitbodygym_set_updated_at();
drop trigger if exists workout_plans_set_updated_at on public.workout_plans;
create trigger workout_plans_set_updated_at before update on public.workout_plans
for each row execute function public.fitbodygym_set_updated_at();
drop trigger if exists ai_conversations_set_updated_at on public.ai_conversations;
create trigger ai_conversations_set_updated_at before update on public.ai_conversations
for each row execute function public.fitbodygym_set_updated_at();

alter table public.training_assessments enable row level security;
alter table public.exercise_catalog enable row level security;
alter table public.workout_plans enable row level security;
alter table public.workout_days enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.progress_entries enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;

create or replace function public.fitbodygym_current_member_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select local_member_id
  from public.member_profiles
  where auth_user_id = auth.uid()
  limit 1
$$;

revoke all on function public.fitbodygym_current_member_id() from public;
grant execute on function public.fitbodygym_current_member_id() to authenticated;

drop policy if exists "Members manage their assessments" on public.training_assessments;
create policy "Members manage their assessments" on public.training_assessments
for all to authenticated
using (member_id = public.fitbodygym_current_member_id())
with check (member_id = public.fitbodygym_current_member_id());

drop policy if exists "Members read active exercises" on public.exercise_catalog;
create policy "Members read active exercises" on public.exercise_catalog
for select to authenticated using (is_active);

drop policy if exists "Members manage their workout plans" on public.workout_plans;
create policy "Members manage their workout plans" on public.workout_plans
for all to authenticated
using (member_id = public.fitbodygym_current_member_id())
with check (member_id = public.fitbodygym_current_member_id());

drop policy if exists "Members access their workout days" on public.workout_days;
create policy "Members access their workout days" on public.workout_days
for all to authenticated
using (exists (select 1 from public.workout_plans p where p.id = workout_plan_id and p.member_id = public.fitbodygym_current_member_id()))
with check (exists (select 1 from public.workout_plans p where p.id = workout_plan_id and p.member_id = public.fitbodygym_current_member_id()));

drop policy if exists "Members access their workout exercises" on public.workout_exercises;
create policy "Members access their workout exercises" on public.workout_exercises
for all to authenticated
using (exists (select 1 from public.workout_days d join public.workout_plans p on p.id = d.workout_plan_id where d.id = workout_day_id and p.member_id = public.fitbodygym_current_member_id()))
with check (exists (select 1 from public.workout_days d join public.workout_plans p on p.id = d.workout_plan_id where d.id = workout_day_id and p.member_id = public.fitbodygym_current_member_id()));

drop policy if exists "Members manage their progress" on public.progress_entries;
create policy "Members manage their progress" on public.progress_entries
for all to authenticated
using (member_id = public.fitbodygym_current_member_id())
with check (member_id = public.fitbodygym_current_member_id());

drop policy if exists "Members manage their conversations" on public.ai_conversations;
create policy "Members manage their conversations" on public.ai_conversations
for all to authenticated
using (member_id = public.fitbodygym_current_member_id())
with check (member_id = public.fitbodygym_current_member_id());

drop policy if exists "Members access their messages" on public.ai_messages;
create policy "Members access their messages" on public.ai_messages
for all to authenticated
using (exists (select 1 from public.ai_conversations c where c.id = conversation_id and c.member_id = public.fitbodygym_current_member_id()))
with check (exists (select 1 from public.ai_conversations c where c.id = conversation_id and c.member_id = public.fitbodygym_current_member_id()));

commit;
