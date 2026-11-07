-- Excerpt from supabase/migration_002_time_logs.sql
-- Row Level Security on the time_logs table. Every user-owned table in the
-- project carries the same four policies: each account can only see and
-- change its own rows, enforced by the database itself.

create table if not exists public.time_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint time_logs_interval check (ended_at > started_at)
);

alter table public.time_logs enable row level security;

create policy "time_logs_select_own" on public.time_logs
  for select to authenticated
  using (auth.uid() = user_id);

create policy "time_logs_insert_own" on public.time_logs
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "time_logs_update_own" on public.time_logs
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "time_logs_delete_own" on public.time_logs
  for delete to authenticated
  using (auth.uid() = user_id);
