-- Phase 3: employee attention evaluations. Additive; no cash/auth changes.
-- Run once in the SAME Supabase project used by member_profiles + dashboard_owners.
begin;

-- Abort safely if this is not the shared project expected by the apps.
do $$
begin
  if to_regclass('public.member_profiles') is null
     or to_regclass('public.dashboard_owners') is null
     or to_regprocedure('public.is_dashboard_owner()') is null then
    raise exception 'Proyecto incorrecto o incompleto: faltan member_profiles, dashboard_owners o is_dashboard_owner(). No se aplicaron cambios.';
  end if;
end;
$$;

create or replace function public.employee_evaluation_month()
returns date language sql stable set search_path = ''
as $$ select date_trunc('month', now() at time zone 'America/El_Salvador')::date $$;
revoke all on function public.employee_evaluation_month() from public, anon;
grant execute on function public.employee_evaluation_month() to authenticated;

create table public.employee_evaluations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid default auth.uid() references auth.users(id) on delete set null,
  employee_key text not null check (employee_key in ('cristabel','adilene','domingo')),
  shift_key text not null check (shift_key in ('morning','evening','sunday')),
  evaluation_month date not null default public.employee_evaluation_month(),
  kindness_score smallint not null check (kindness_score between 1 and 5),
  availability_score smallint not null check (availability_score between 1 and 5),
  proactivity_score smallint not null check (proactivity_score between 1 and 5),
  created_at timestamptz not null default now(),
  constraint employee_evaluations_assignment check (
    (employee_key='cristabel' and shift_key='morning') or
    (employee_key='adilene' and shift_key='evening') or
    (employee_key='domingo' and shift_key='sunday')
  ),
  constraint employee_evaluations_month_start check (extract(day from evaluation_month)=1),
  constraint employee_evaluations_once_monthly unique(client_id,employee_key,evaluation_month)
);
create index employee_evaluations_month on public.employee_evaluations(evaluation_month,employee_key);
alter table public.employee_evaluations enable row level security;
revoke all on public.employee_evaluations from anon, authenticated;
grant select on public.employee_evaluations to authenticated;
-- Clients cannot supply identity, month or timestamps.
grant insert(employee_key,shift_key,kindness_score,availability_score,proactivity_score)
on public.employee_evaluations to authenticated;

create policy employee_evaluations_read_own on public.employee_evaluations
for select to authenticated using (client_id=auth.uid());
create policy employee_evaluations_submit_member on public.employee_evaluations
for insert to authenticated with check (
  client_id=auth.uid()
  and evaluation_month=public.employee_evaluation_month()
  and exists (select 1 from public.member_profiles mp where mp.auth_user_id=auth.uid())
);

create or replace function public.employee_evaluation_summary(p_month date)
returns table (
  employee_key text, shift_key text, response_count bigint,
  kindness_avg numeric, availability_avg numeric, proactivity_avg numeric, overall_avg numeric
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_dashboard_owner() then
    raise exception 'No autorizado para consultar evaluaciones' using errcode='42501';
  end if;
  if p_month is null or extract(day from p_month)<>1 then
    raise exception 'El mes debe comenzar en el primer dia' using errcode='22023';
  end if;
  return query select e.employee_key,e.shift_key,count(*),
    round(avg(e.kindness_score),2),round(avg(e.availability_score),2),
    round(avg(e.proactivity_score),2),
    round(avg((e.kindness_score+e.availability_score+e.proactivity_score)::numeric/3),2)
  from public.employee_evaluations e where e.evaluation_month=p_month
  group by e.employee_key,e.shift_key;
end;
$$;
revoke all on function public.employee_evaluation_summary(date) from public, anon;
grant execute on function public.employee_evaluation_summary(date) to authenticated;
comment on table public.employee_evaluations is
'Monthly member feedback. Owner dashboard exposes aggregated scores only. Shift assignment confirmed 2026-11-05.';
commit;
