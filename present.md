# QuestFlow — Feature Presentation

*A personal productivity app for tasks, events, and continuous quests — built with Flutter Web and Supabase.*

---

## 1. What is QuestFlow?

QuestFlow manages three kinds of personal activity in one responsive web app:

- **Tasks** — things that must be done before a deadline (pending / completed / overdue).
- **Events** — things that happen at a specific time (with optional end time and location).
- **Quests** — continuous daily habits or measurable goals, tracked on a GitHub-style heatmap with streaks and statistics.

The app has exactly **three primary destinations** — Home, Tasks & Events, and Quests — plus a full authentication flow backed by Supabase.

## 2. Technology stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web (Dart), Material 3 |
| Routing | `go_router` (shell route + nested routes) |
| State management | `ChangeNotifier` + `InheritedWidget` (`AppScope`) |
| Backend | Supabase — Auth, PostgreSQL, Row Level Security |
| Data layer | Repository pattern (interfaces + in-memory & Supabase implementations) |
| Testing | `flutter_test` — unit + widget tests |
| Deployment | GitHub Pages via GitHub Actions |

## 3. Screens and features

### 3.1 Home (dashboard)

- **Tasks summary bar** — pending count, due today, overdue count, nearest deadline.
- **Events summary bar** — events today and tomorrow in chronological order with start times.
- **Today's Quests bar** — quests completed today / total active, with a completion percentage.
- Every bar is **clickable** and navigates to the relevant screen.
- Quick-access "+" button for creating items.

### 3.2 Tasks & Events (calendar)

- **Month calendar** with visually distinct markers: red (madder) for tasks, blue (woad) for events, colour-coded by priority/status.
- Previous/next month navigation and date selection.
- **Agenda list** for the selected day; tapping an item opens its detail dialog.
- **Single "+" flow** — asks "Task or Event?" then opens the matching form.
- **Task form** — title, description, deadline date & time, priority, category, status. Full validation (required title, valid deadline).
- **Event form** — title, start date/time, optional end time, location, description, reminder offset. Validation ensures end is not before start.
- **Detail dialogs** for both, with **Edit** and **Delete (with confirmation)** actions.
- Tasks can be marked done / reopened from the list and detail view; overdue status is derived automatically.
- Day dialog shows the full agenda for any selected date.

### 3.3 Quests

- **Quest list** — cards showing name, tracking mode, today's progress, current streak, and completion rate.
- **Quest form** — title, description, tracking mode (binary/numeric), unit, daily target, upper limit, start/end dates, and date-range presets (this month / this year / custom). The end-date picker **cannot pick a date before the start date**.
- **Heatmap screen** — month-by-month grid (Monday-first) of every day in the quest's range:
  - **Binary quests:** grey = not done, green = done. No partial state.
  - **Numeric quests:** grey = zero, **green gradient** scaled by value/target, **full green** at target, **purple** for over-target days.
  - Future days are visually distinct and never shown as failures.
- **Tap any day** to open a dialog to record or edit that day's progress (past days editable, future days blocked).
- **Statistics:** current streak, longest streak, completion rate, successful days, elapsed days, overload days.
- **Archive** as a safer alternative to deletion; permanent delete requires confirmation.
- Values above the configured **upper limit are rejected** with a validation message — never silently capped.

### 3.4 Authentication & cloud

- **Email + password sign-up, sign-in, sign-out**, and **password reset** email.
- **Session restoration** — a returning visitor stays logged in (Supabase persistent session).
- Auth gate at the app shell: signed-out users only see the auth screen.
- All data is stored per-user in PostgreSQL; **Row Level Security policies on every table** guarantee one account can never read or write another account's records.
- Loading, error, and empty states for all cloud operations, with an error banner for runtime failures.

### 3.5 Data retention (project addition)

Finished items are kept for a **one-week buffer**, then automatically removed from the database by a sweep that runs on every load and hourly afterwards:

- Completed tasks — removed 1 week after `completed_at`.
- Events — removed 1 week after they end.
- Quests — removed 1 week after their end date (daily records go with them).

Pending tasks and active quests are never touched.

## 4. Architecture highlights

- **Repository pattern:** widgets never talk to Supabase directly. `TaskRepository`, `EventRepository`, `QuestRepository` are interfaces with two implementations each — **in-memory** (demo mode) and **Supabase** (cloud mode). The app auto-detects which to use, which also makes the whole app testable without a network.
- **Central state:** a single `AppState` (`ChangeNotifier`) holds tasks, events, quests, selected date, and load status; all mutations go through it, so every screen updates reactively.
- **Real database IDs:** creating an item returns the stored database row, so subsequent updates/deletes always reference the true UUID.
- **Database schema** (`supabase/schema.sql`): 5 tables (profiles, tasks, events, quests, quest_daily_records) with RLS policies on **every** table, `updated_at` triggers, a unique constraint on `(quest_id, record_date)`, a composite foreign key ensuring records belong to the owning user's quest, and a check constraint enforcing numeric upper limits at the database level.
- **Theme:** custom "Lichen & Madder" palette (madder red = tasks, woad blue = events, moss green = quests, mulberry = over-target, ash grey = zero) with custom fonts.

## 5. Testing — 66 tests

| Suite | Tests | Covers |
|---|---|---|
| `phase1_test.dart` | 5 | App skeleton, navigation, sample data |
| `phase2_test.dart` | 7 | Forms & validation, CRUD flows, detail dialogs, day dialog |
| `phase3_test.dart` | 42 | Every quest-rule boundary case: binary/numeric colours, streak rules (today/yesterday/gap), completion rate, upper-limit rejection, future-day handling, month grid layout |
| `phase4_test.dart` | 12 | Repository interfaces, memory vs Supabase row mapping, auth service, retention sweep |

Highlights of boundary coverage: partial progress never counts toward streaks; over-target days do; missing past records count as failures while future days never do; streak breaks correctly across gaps; completion rate excludes future days; retention keeps items inside the 7-day buffer and removes them after.

## 6. Spec alignment (coursework concepts)

| Concept | Where it appears |
|---|---|
| Dart basics / data types | Model classes with enums, `DateTime` handling, `copyWith` |
| Flutter widgets | Cards, calendar cells, dialogs, forms, progress bars, reusable components |
| Responsive UI | Desktop sidebar ↔ mobile bottom navigation, adaptive layouts |
| Navigation | `go_router` with shell route, three screens + detail routes |
| State management | `ChangeNotifier` + `InheritedWidget`, reactive UI updates |
| Custom widgets/themes | Heatmap cells, summary bars, colour legend, custom theme |
| Forms and validation | Task/event/quest forms with required fields, date rules, numeric limits |
| Animations | Dialog transitions, progress indicators |
| Async / API work | Supabase CRUD with loading, success, error and empty states |
| Testing/debugging | 66 unit + widget tests across four suites |

## 7. Running the project

```bash
flutter pub get
flutter run -d chrome          # demo mode (in-memory sample data)
flutter test                   # all 66 tests
flutter build web --release    # production bundle
```

Cloud mode is enabled automatically when Supabase credentials are present (`lib/config.dart`, or `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`). The database schema and RLS policies live in `supabase/schema.sql`.

## 8. Deployment

The app is deployed to **GitHub Pages** automatically: pushing to `main` triggers `.github/workflows/deploy.yml`, which runs the test suite, builds the release web bundle with the correct base path for the repository URL, and publishes it. Supabase stores all user data independently of the host.
