-- Run this once in the Supabase SQL editor if you already created the
-- schema before this change. Fresh setups get it from schema.sql directly.
--
-- Makes user_id default to the signed-in user, so an insert that omits
-- user_id still satisfies the RLS policies instead of failing with 42501.

alter table public.tasks  alter column user_id set default auth.uid();
alter table public.events alter column user_id set default auth.uid();
alter table public.quests alter column user_id set default auth.uid();

-- quest_daily_records keeps its explicit user_id (it must match the owning
-- quest via the composite foreign key), so no default is added there.
