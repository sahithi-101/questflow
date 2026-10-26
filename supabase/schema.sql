-- QuestFlow Supabase schema — run this in the Supabase SQL editor.
--
-- Every user-owned table has Row Level Security enabled with policies that
-- only allow a signed-in user to touch their own rows (spec 6.1: ownership
-- is enforced in the database, not only in the UI). The Flutter client only
-- ever uses the public anon key; the service-role key is never exposed.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------
create table if not exists public.tasks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 200),
  description  text not null default '',
  category     text not null default '',
  deadline_at  timestamptz not null,
  priority     text not null default 'medium'
               check (priority in ('low', 'medium', 'high')),
  status       text not null default 'pending'
               check (status in ('pending', 'completed')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  completed_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  title            text not null check (char_length(title) between 1 and 200),
  description      text not null default '',
  starts_at        timestamptz not null,
  ends_at          timestamptz,
  location         text,
  reminder_offsets int[] not null default '{}', -- minutes before start
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint events_end_after_start
    check (ends_at is null or ends_at >= starts_at)
);

-- ---------------------------------------------------------------------------
-- Quests
-- ---------------------------------------------------------------------------
create table if not exists public.quests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 200),
  description   text not null default '',
  tracking_mode text not null check (tracking_mode in ('binary', 'numeric')),
  unit          text not null default '',
  daily_target  numeric not null default 1 check (daily_target > 0),
  upper_limit   numeric check (upper_limit is null or upper_limit > 0),
  starts_on     date not null,
  ends_on       date not null,
  archived_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint quests_range_valid check (ends_on >= starts_on),
  constraint quests_numeric_needs_limit
    check (tracking_mode = 'binary' or upper_limit is not null),
  -- lets quest_daily_records carry (quest_id, user_id) as a composite FK so
  -- a record can never point at another user's quest
  constraint quests_id_user_unique unique (id, user_id)
);

-- ---------------------------------------------------------------------------
-- Quest daily records — one row per quest per date (spec 7)
-- ---------------------------------------------------------------------------
create table if not exists public.quest_daily_records (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null,
  quest_id         uuid not null,
  record_date      date not null,
  recorded_value   numeric not null default 0 check (recorded_value >= 0),
  binary_completed boolean,
  notes            text not null default '',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint quest_daily_records_unique_day
    unique (quest_id, record_date),
  -- ownership must match the owning quest
  constraint quest_daily_records_quest_fk
    foreign key (quest_id, user_id)
    references public.quests (id, user_id)
    on delete cascade,
  constraint quest_daily_records_user_fk
    foreign key (user_id) references auth.users (id) on delete cascade
);

-- Numeric records may not exceed the quest's upper limit: the database
-- rejects what the form rejects, so nothing is ever silently capped.
create or replace function public.check_record_limit() returns trigger as $$
begin
  if new.user_id is distinct from (select user_id from public.quests where id = new.quest_id) then
    raise exception 'record user_id does not match the quest owner';
  end if;
  if exists (
    select 1 from public.quests q
    where q.id = new.quest_id
      and q.tracking_mode = 'numeric'
      and q.upper_limit is not null
      and new.recorded_value > q.upper_limit
  ) then
    raise exception 'recorded_value % is above the quest upper limit', new.recorded_value;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists quest_daily_records_limit on public.quest_daily_records;
create trigger quest_daily_records_limit
  before insert or update on public.quest_daily_records
  for each row execute function public.check_record_limit();

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

do $$
declare t text;
begin
  foreach t in array array['tasks', 'events', 'quests', 'quest_daily_records']
  loop
    execute format(
      'drop trigger if exists set_updated_at on public.%I;
       create trigger set_updated_at before update on public.%I
       for each row execute function public.set_updated_at();', t, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Row Level Security — enabled and forced on every user-owned table
-- ---------------------------------------------------------------------------
alter table public.tasks               enable row level security;
alter table public.events              enable row level security;
alter table public.quests              enable row level security;
alter table public.quest_daily_records enable row level security;

-- Tasks
create policy "tasks_select_own" on public.tasks
  for select to authenticated using (auth.uid() = user_id);
create policy "tasks_insert_own" on public.tasks
  for insert to authenticated with check (auth.uid() = user_id);
create policy "tasks_update_own" on public.tasks
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "tasks_delete_own" on public.tasks
  for delete to authenticated using (auth.uid() = user_id);

-- Events
create policy "events_select_own" on public.events
  for select to authenticated using (auth.uid() = user_id);
create policy "events_insert_own" on public.events
  for insert to authenticated with check (auth.uid() = user_id);
create policy "events_update_own" on public.events
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "events_delete_own" on public.events
  for delete to authenticated using (auth.uid() = user_id);

-- Quests
create policy "quests_select_own" on public.quests
  for select to authenticated using (auth.uid() = user_id);
create policy "quests_insert_own" on public.quests
  for insert to authenticated with check (auth.uid() = user_id);
create policy "quests_update_own" on public.quests
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "quests_delete_own" on public.quests
  for delete to authenticated using (auth.uid() = user_id);

-- Quest daily records
create policy "records_select_own" on public.quest_daily_records
  for select to authenticated using (auth.uid() = user_id);
create policy "records_insert_own" on public.quest_daily_records
  for insert to authenticated with check (auth.uid() = user_id);
create policy "records_update_own" on public.quest_daily_records
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "records_delete_own" on public.quest_daily_records
  for delete to authenticated using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Optional: auto-create a profile row on sign-up (handy for joins later)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "profiles_select_own" on public.profiles
  for select to authenticated using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

create or replace function public.handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
