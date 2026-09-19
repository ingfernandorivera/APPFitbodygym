-- Migración aditiva. Preparada para revisión; no se aplica desde la app.
begin;
alter table public.exercise_catalog add column if not exists slug text;
alter table public.exercise_catalog add column if not exists metadata jsonb not null default '{}'::jsonb;
-- El UUID conserva identidad incluso con nombres repetidos; los slugs locales se
-- pueden vincular posteriormente de forma explícita, sin renombrar registros.
update public.exercise_catalog set slug = 'exercise_' || replace(id::text, '-', '_') where slug is null;
create unique index if not exists exercise_catalog_slug_idx on public.exercise_catalog(slug) where slug is not null;

alter table public.workout_plans add column if not exists start_date date;
alter table public.workout_plans add column if not exists block_number integer not null default 1 check (block_number > 0);
alter table public.workout_plans add column if not exists week_number integer not null default 1 check (week_number > 0);
alter table public.workout_plans add column if not exists planned_minutes integer not null default 60 check (planned_minutes between 15 and 240);
alter table public.workout_plans add column if not exists origin text not null default 'legacy';
alter table public.workout_plans add column if not exists change_reason text not null default '';
alter table public.workout_exercises add column if not exists target_min integer check (target_min between 1 and 50);
alter table public.workout_exercises add column if not exists target_max integer check (target_max between 1 and 50 and target_max >= target_min);
alter table public.workout_exercises add column if not exists target_rir integer not null default 2 check (target_rir between 0 and 4);

create table if not exists public.workout_plan_versions (
  id uuid primary key default gen_random_uuid(),
  member_id text not null references public.member_profiles(local_member_id) on delete cascade,
  local_plan_id text not null,
  version integer not null check (version > 0),
  plan jsonb not null check (jsonb_typeof(plan) = 'object'),
  change_reason text not null default '',
  created_at timestamptz not null default now(),
  unique(member_id, local_plan_id, version)
);
create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  member_id text not null references public.member_profiles(local_member_id) on delete cascade,
  local_plan_id text,
  plan_version integer not null default 1 check (plan_version > 0),
  plan_name text not null,
  day_number smallint not null check (day_number between 1 and 7),
  day_title text not null,
  completed_at timestamptz not null default now(),
  duration_seconds integer not null default 0 check (duration_seconds >= 0)
);
create table if not exists public.workout_session_exercises (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  catalog_id text not null,
  exercise_name text not null,
  notes text not null default '',
  discomfort boolean not null default false,
  unique(session_id, catalog_id)
);
create table if not exists public.workout_set_results (
  id uuid primary key default gen_random_uuid(),
  session_exercise_id uuid not null references public.workout_session_exercises(id) on delete cascade,
  position smallint not null check (position between 1 and 6),
  weight_kg numeric not null default 0 check (weight_kg between 0 and 1000),
  repetitions smallint not null check (repetitions between 0 and 100),
  rir smallint not null check (rir between 0 and 4),
  completed boolean not null default false,
  warmup boolean not null default false,
  unique(session_exercise_id, position)
);
create table if not exists public.workout_proposals (
  id uuid primary key default gen_random_uuid(),
  member_id text not null references public.member_profiles(local_member_id) on delete cascade,
  expected_version integer not null check (expected_version >= 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status text not null default 'pending' check (status in ('pending','applied','cancelled','invalid')),
  created_at timestamptz not null default now()
);
alter table public.ai_messages add column if not exists action_type text not null default 'answer';
alter table public.ai_messages add column if not exists proposal_status text;
create index if not exists workout_sessions_member_time_idx on public.workout_sessions(member_id, completed_at desc);
create index if not exists workout_session_exercises_session_idx on public.workout_session_exercises(session_id);
create index if not exists workout_set_results_exercise_idx on public.workout_set_results(session_exercise_id);
create index if not exists workout_proposals_member_idx on public.workout_proposals(member_id, created_at desc);
alter table public.workout_plan_versions enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_session_exercises enable row level security;
alter table public.workout_set_results enable row level security;
alter table public.workout_proposals enable row level security;
create policy "Members manage own plan versions" on public.workout_plan_versions for all to authenticated
using (member_id = public.fitbodygym_current_member_id()) with check (member_id = public.fitbodygym_current_member_id());
create policy "Members manage own sessions" on public.workout_sessions for all to authenticated
using (member_id = public.fitbodygym_current_member_id()) with check (member_id = public.fitbodygym_current_member_id());
create policy "Members manage own proposals" on public.workout_proposals for all to authenticated
using (member_id = public.fitbodygym_current_member_id()) with check (member_id = public.fitbodygym_current_member_id());
create policy "Members manage own session exercises" on public.workout_session_exercises for all to authenticated
using (exists (select 1 from public.workout_sessions s where s.id = session_id and s.member_id = public.fitbodygym_current_member_id()))
with check (exists (select 1 from public.workout_sessions s where s.id = session_id and s.member_id = public.fitbodygym_current_member_id()));
create policy "Members manage own sets" on public.workout_set_results for all to authenticated
using (exists (select 1 from public.workout_session_exercises e join public.workout_sessions s on s.id = e.session_id where e.id = session_exercise_id and s.member_id = public.fitbodygym_current_member_id()))
with check (exists (select 1 from public.workout_session_exercises e join public.workout_sessions s on s.id = e.session_id where e.id = session_exercise_id and s.member_id = public.fitbodygym_current_member_id()));
commit;
