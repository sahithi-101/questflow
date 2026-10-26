# QuestFlow

Tasks, events and continuous quests in one Flutter Web app. Built for the
JNTUH R22 Flutter coursework; see `QuestFlow_Specification_v2.docx`.

## Status

Phases 1–4 of the specification (section 10) are implemented:

- **Phase 1 — UI skeleton**: "Lichen & Madder" theme, responsive navigation
  (desktop sidebar / mobile bottom bar), three screens.
- **Phase 2 — Core CRUD**: task, event and quest forms with validation,
  detail views with edit + delete confirmation, the daily-progress dialog,
  all running on in-memory state.
- **Phase 3 — Quest calculations**: full quest heatmap with a day-edit
  dialog, current/longest streak, overload days, completion rate — with unit
  tests for every boundary case in spec section 4 (`test/phase3_test.dart`).
- **Phase 4 — Supabase**: SQL schema with Row Level Security on every table
  (`supabase/schema.sql`), repositories behind interfaces
  (`lib/data/repositories.dart`), email/password auth with password reset
  and session restore, and cloud CRUD with loading, error and empty states.

## Run

Demo mode (no Supabase needed, in-memory sample data):

    flutter pub get
    flutter run -d chrome

Cloud mode (Supabase auth + PostgreSQL):

1. Create a project at supabase.com, then run `supabase/schema.sql` in the
   SQL editor. It creates the `tasks`, `events`, `quests`,
   `quest_daily_records` and `profiles` tables with RLS policies so every
   user only ever sees their own rows.
2. Under Authentication → Providers, enable Email. Add your local and
   deployed URLs to the allowed redirect list.
3. Run the app with the public anon key (never the service-role key):

       flutter run -d chrome \
         --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
         --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY

Without those defines the app stays in demo mode.

## Tests

    flutter test

- `test/phase1_test.dart` — responsive layout and navigation
- `test/phase2_test.dart` — forms, detail views, delete confirmation, day dialog
- `test/phase3_test.dart` — quest boundary cases from spec section 4
- `test/phase4_test.dart` — Supabase row mapping and repository-backed state

## Deploy to GitHub Pages

1. Create a GitHub repository and push this folder to it:

       git init
       git add .
       git commit -m "QuestFlow"
       git branch -M main
       git remote add origin https://github.com/<you>/questflow.git
       git push -u origin main

2. On GitHub: **Settings → Pages → Build and deployment → Source =
   "GitHub Actions"**.
3. `.github/workflows/deploy.yml` runs on every push to `main`: it executes
   the test suite, builds `flutter build web --release` with
   `--base-href "/<repo-name>/"`, and publishes `build/web` to Pages.
4. The live URL will be `https://<you>.github.io/questflow/`. Flutter web's
   default hash URL strategy is used, so refreshing deep links works without
   a 404 fallback.
5. In Supabase → Authentication → URL Configuration, add the deployed URL
   (`https://<you>.github.io/questflow/`) to the allowed redirect URLs.

Note: only the Supabase URL and anon key appear in the client. The anon key
is public by design — it is embedded in the deployed JavaScript bundle
regardless — and data protection comes from Row Level Security. Never put
the service-role key in this project.

## Structure

    lib/theme/      palette ("Lichen & Madder") and ThemeData
    lib/models/     Task, Event, Quest, QuestStats
    lib/state/      AppState (repository-backed store) + AppScope
    lib/data/       repository interfaces, in-memory + Supabase implementations
    lib/auth/       AuthService (sign up, sign in, reset, session restore)
    lib/widgets/    app shell, forms, detail dialogs, heat strip, status views
    lib/screens/    Home, Tasks & Events, Quests, Quest detail, Auth
    lib/router.dart go_router routes, auth redirect
    supabase/       schema.sql — tables, RLS policies, triggers

## Quest rules (spec section 4)

- Binary quests: grey = not done, green = done. No partial state.
- Numeric quests: grey = 0, green gradient = partial (value/target), full
  green = at target, purple = above target. Values above the configured
  upper limit are rejected with a message, never silently capped.
- A day is successful when `recorded_value >= target`. Missing past records
  count as not completed; future days are never failures.
- Current streak ends today if today succeeded, otherwise yesterday while
  today is still open. Completion rate excludes future days.

## Retention

Finished items are kept for one week and then removed from the database by
a sweep that runs on every load and hourly afterwards:

- completed tasks, one week after `completed_at`
- events, one week after they end (or start, when no end time)
- quests, one week after their `ends_on` date — daily records go with them,
  so the heatmap history of an ended quest is intentionally not preserved
