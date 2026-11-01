-- Migration 002: time_logs for the focus-timer page.
--
-- Run this in the Supabase SQL editor (same as migration_001). One row per
-- finished timer session: what it was called and when it ran. Duration is
-- derived from the two timestamps and never stored.
--
-- RLS follows the same pattern as every other user-owned table: each user
-- can only see and change their own rows.

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

-- Keep updated_at current, same as the other tables.
drop trigger if exists set_updated_at on public.time_logs;
create trigger set_updated_at
  before update on public.time_logs
  for each row execute function public.set_updated_at();
