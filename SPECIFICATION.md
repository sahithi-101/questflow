# QuestFlow

**Flutter Web Application — Project Specification**

A personal productivity app combining tasks, events, and continuous quests.

| | |
|---|---|
| **Purpose** | JNTUH R22 Flutter coursework and personal productivity |
| **Frontend** | Flutter Web + Dart |
| **Authentication and cloud data** | Supabase Auth + PostgreSQL + Row Level Security |
| **Offline support** | Local cache with an explicit synchronization strategy |

*Version 1.0 · Draft specification based on agreed requirements*

---

## 1. Project overview

QuestFlow is a responsive Flutter Web application for managing three kinds of personal activity: **tasks** that must be completed before deadlines, **events** that happen at specific times, and **quests** that track daily habits or measurable goals. The app combines a compact daily dashboard with a calendar for tasks/events and a heatmap-based quest tracker.

Supabase cloud storage is the source of truth for the first version. Local caching and offline synchronization are planned as a later enhancement, not a requirement for the initial coursework release.

## 2. Goals and scope

### Primary goals

- Provide exactly three primary destinations: **Home**, **Tasks & Events**, and **Quests**.
- Support create, read, update, and delete (CRUD) operations for tasks, events, and quests.
- Use Supabase authentication and a user-isolated PostgreSQL database.
- Show a quest heatmap, daily progress, streaks, and completion statistics.
- Use a local cache so recently loaded data can be shown quickly and offline changes can be queued for synchronization.
- Demonstrate responsive layouts, navigation, reusable widgets, forms and validation, state management, asynchronous data/API operations, and testing.

### Out of scope for the first coursework version

- Social features, shared quests, teams, public profiles, or leaderboards.
- A custom backend server; Supabase provides the managed backend services.
- Complex recurrence rules such as every Monday or every Saturday. Quests are active continuously over a date range.
- Guaranteed background notifications when the browser is closed. Browser notification behavior depends on browser permissions and platform restrictions.
- Advanced multi-device conflict resolution beyond a documented, tested initial synchronization policy.

## 3. Navigation and screens

The app has three primary screens. Desktop can use a sidebar; narrow screens can use a bottom navigation bar or compact drawer.

### 3.1 Home

- Tasks summary bar: pending count, tasks due today, overdue count, and optionally the nearest deadline.
- Events summary bar: events today and tomorrow, shown chronologically with start times.
- Today's Quests summary bar: number completed, total active quests for today, and a completion percentage.
- Each bar is clickable and navigates to the relevant screen or a relevant filtered view.
- Provide quick access to create an item, but keep the main create/edit workflows on their relevant screens.

### 3.2 Tasks & Events

- One calendar displays tasks and events using visually distinct markers, colors, and icons.
- Calendar navigation supports previous/next month and selecting a date. A month view is required; an agenda/list for the selected date is recommended.
- A single '+' button asks whether the user wants to add a Task or an Event, then opens the corresponding form.
- Selecting a calendar item opens its detail view. Edit and Delete actions are available from that detail view.
- Tasks and events have different forms because their fields and semantics differ.

#### Task fields

- **Required:** title, deadline date/time, status.
- **Recommended:** description, priority, category, created_at, updated_at, completed_at.
- Task states: Pending, Completed, and Overdue (overdue is derived when a pending task's deadline has passed). A task can be reopened after completion.

#### Event fields

- **Required:** title and start date/time.
- **Recommended:** end date/time, description, location, reminder offset(s), created_at, updated_at.
- An event is time-based, not a task with a deadline. Reminder options may include at event time, 10 minutes before, 1 hour before, or a custom offset. In-app upcoming-event visibility is the baseline; browser notifications are an enhancement subject to permissions and browser behavior.

### 3.3 Quests

- Display active quests as cards or a list, including the quest name, tracking mode, daily target (if numeric), today's progress, current streak, and completion rate.
- Provide Create, View, Edit, and Delete actions for quests. Archiving is recommended as a safer alternative to deletion because it preserves history.
- Selecting a quest opens its heatmap and statistics.
- Selecting a day in the heatmap opens a dialog to inspect or edit that day's progress.
- Quests run continuously from a start date through an end date, inclusive. There are no weekday-only recurrence rules.

## 4. Quest rules and heatmap

Each quest has a tracking mode selected at creation: **Binary** or **Numeric**. Each quest has an active start date and end date. The daily record is unique for a given quest and date. Dates outside the active range are not eligible quest days.

### 4.1 Binary quests

- The user marks a day complete or incomplete.
- Heatmap: grey = 0 / not completed; green = 1 / completed.
- Binary completion is explicit; there is no partial state.

### 4.2 Numeric quests

The user defines a unit (for example minutes, hours, repetitions, pages, problems, or a custom unit), a daily target, and an upper limit. The daily recorded value is numeric and should be validated against the allowed range.

| Recorded value | Heatmap state | Color | Success for streak? |
|---|---|---|---|
| 0 | No progress | Grey | No |
| Greater than 0 but below target | Partial progress | Light-to-dark green based on value/target | No |
| Equal to target | Target reached | Full green | Yes |
| Above target and at/below upper limit | Over target / overload | Purple | Yes |

**Recommended rule:** store the actual recorded value, and calculate the state separately. Values below target can use a green gradient whose intensity is proportional to value/target. The target is full green. Values above target use purple. Values above the configured upper limit should be **rejected with a validation message** or require the user to change the limit; they should not be silently truncated.

For numeric quests, a day is successful when `recorded_value >= target`. Partial progress is visible but does not count as a successful day for streaks. A missing record on a past eligible day is treated as not completed for statistics, while a future day is not treated as a failure.

### 4.3 Quest duration and daily history

- A quest can cover a custom start-to-end date range, a whole month, or a whole year. Month/year choices can prefill start and end dates.
- The active range is continuous: every calendar day in the range is eligible.
- Use one daily record per quest/date. Suggested fields: quest_id, date, recorded_value (or boolean completion), notes, created_at, updated_at.
- A heatmap should visually distinguish future dates from missed past days. Do not show future dates as failures.

### 4.4 Streaks and statistics

- **Current streak:** consecutive successful days ending today if today is successful; otherwise ending yesterday if today is still incomplete; otherwise zero.
- **Longest streak:** the largest consecutive sequence of successful eligible days.
- **Completion rate:** successful eligible days divided by elapsed eligible days, excluding future days.
- **Numeric progress:** show the actual amount and target, for example 30/45 minutes, plus percentage of target.
- **Over-target days** count as successful for streaks and can be separately counted as overload days.

## 5. CRUD behavior

| Operation | Tasks & Events | Quests |
|---|---|---|
| Create | Use '+' then choose Task or Event; validate form. | Create quest; choose binary/numeric mode and date range. |
| Read | Calendar markers, selected-day agenda, item detail. | Quest list, heatmap, daily records, stats. |
| Update | Open item details, choose Edit, save changes. | Edit metadata; update daily progress from a heatmap cell. |
| Delete | Delete from detail view with confirmation. | Confirm permanent deletion; offer archive as safer alternative. |

## 6. Authentication, cloud storage, and local cache

### 6.1 Recommended architecture

- **Flutter Web frontend:** responsive screens, navigation, forms, visualizations, and local UI state.
- **Repository/data layer:** the UI calls repositories rather than querying Supabase directly from widgets.
- **Supabase Auth:** email/password or email magic-link login can be chosen during implementation; sign-up, login, logout, and session restoration are required.
- **Supabase PostgreSQL:** persistent cloud storage for users' tasks, events, quests, and daily quest records.
- **Row Level Security (RLS):** every user-owned table must enforce ownership in the database, not only in the UI.
- **Local cache:** store recently fetched records locally and maintain a queue of local changes that have not yet synced.

### 6.2 Cloud + local cache behavior

**Recommended initial version: Supabase cloud only.** GitHub Pages hosts the compiled Flutter frontend; it does not host or automatically back up the user's personal records. Supabase stores the account and records independently of the browser.

With cloud-only storage, the app loads and saves records through Supabase. An internet connection is generally required for data operations, but records remain available after closing the browser and can be retrieved after login on another device.

**Why add a local cache later?** A cache can show recently loaded data quickly and allow supported reads or edits during temporary network outages. Each device has its own cache, so caching does not automatically synchronize data or create a backup.

- **Phase 1 — Cloud-only:** implement authentication, database schema, Row Level Security, CRUD, loading/error states, and a repository/data layer. Keep widgets independent of direct Supabase calls so the storage strategy can evolve.
- **Phase 2 — Optional local cache:** choose a Flutter Web-compatible local storage package; cache records; track unsynced operations; queue offline changes; retry synchronization; and show sync failures or conflicts instead of silently losing edits.
- **Phase 3 — Backups:** add user-triggered export/import (for example, validated JSON). A local cache is not a backup. Cloud data can persist even if browser storage is cleared, while a separate export provides an additional recovery path.

Security requirements remain the same: enforce Row Level Security on every user-owned table, verify ownership in the database, never expose Supabase service-role keys in the Flutter client, and test that one account cannot access another account's records.

## 7. Suggested data model

| Table | Suggested fields |
|---|---|
| `tasks` | id, user_id, title, description, deadline_at, priority, status, created_at, updated_at, completed_at |
| `events` | id, user_id, title, description, starts_at, ends_at, location, reminder_offsets, created_at, updated_at |
| `quests` | id, user_id, title, description, tracking_mode, unit, daily_target, upper_limit, starts_on, ends_on, archived_at, created_at, updated_at |
| `quest_daily_records` | id, user_id, quest_id, record_date, recorded_value, binary_completed, notes, created_at, updated_at |

Use a unique constraint on `(quest_id, record_date)`. Ensure the quest_daily_records user_id matches the owning quest, and enforce this with database policies/constraints as appropriate. Use timestamps in a consistent format (typically UTC for event instants) and render them in the user's local timezone. Quest heatmap dates are calendar dates and should be stored/handled as dates, not shifted by timezone conversion.

## 8. Flutter coursework alignment

| Coursework concept | Where it appears | Evidence to show |
|---|---|---|
| Dart basics / data types | Task, event, quest and daily-record models | Model classes and date/value handling |
| Flutter widgets | Cards, calendar cells, dialogs, forms, progress bars | Reusable widgets |
| Responsive UI | Desktop sidebar and mobile navigation; adaptive calendar/list | Test multiple widths |
| Navigation | Three main screens and detail/form routes or dialogs | Working navigation flow |
| State management | Selected date, form state, filters, daily progress | UI updates after actions |
| Custom widgets/themes | Task/event markers, quest cells, color legend | Reusable components and theme |
| Forms and validation | Task/event/quest create and edit forms | Required fields, dates, numeric limits |
| Animations | Progress transitions, dialog transitions, heatmap feedback | Small purposeful animation |
| REST/API and async work | Supabase CRUD and optional public-holiday API | Loading, success, error, empty states |
| Testing/debugging | Quest calculations, CRUD repositories, widget tests | Unit and widget tests |

The exact wording and order of the experiments should be checked against the lecturer's supplied coursework sheet. Supabase operations are asynchronous network/database operations; if the syllabus expects a separate public REST API exercise, include a small optional public-holiday or quote API feature rather than assuming Supabase alone satisfies that particular experiment.

## 9. Deployment and repository

**Hosting clarification:** GitHub Pages serves the frontend bundle only. Supabase holds the persistent user data. Cloning the GitHub repository gives a local copy of the source code, not a local copy of Supabase records.

- Develop and test locally using Flutter Web and Chrome.
- Keep the Flutter source code and README in a GitHub repository.
- Build the release web bundle with `flutter build web --release`.
- Deploy the generated `build/web` directory using GitHub Actions and GitHub Pages.
- Configure the correct base path for repository-based Pages URLs.
- Configure Supabase allowed redirect URLs for the deployed website and local development URL.
- Only expose public/anon client configuration in the frontend; rely on RLS for authorization.

## 10. Suggested implementation phases

1. **Phase 1 — UI skeleton:** Create the Flutter project, theme, responsive navigation, and the three screens using sample data.
2. **Phase 2 — Core CRUD:** Implement task/event calendar and forms, quest creation/editing, and daily progress dialogs.
3. **Phase 3 — Quest calculations:** Implement binary/numeric heatmap colors, streaks, completion rates, and boundary tests.
4. **Phase 4 — Supabase:** Configure authentication, schema, RLS, repositories, and cloud CRUD.
5. **Phase 5 — Optional local cache (after the first release):** Add local persistence, a pending-sync queue, sync status, retry handling, and conflict messaging. This phase is not required for the initial coursework submission.
6. **Phase 6 — Coursework polish:** Add responsive checks, validation, animations, loading/error states, tests, README, screenshots, and GitHub Pages deployment. Include cache-specific tests only if Phase 5 is implemented.

## 11. Decisions to confirm before implementation

The main requirements are clear. These decisions can be settled with defaults; they do not block the first draft.

| Decision | Suggested default |
|---|---|
| Authentication method | Default: email + password, with password reset. Add OAuth only if wanted later. |
| Local cache package | Choose a Flutter-web-compatible storage solution after checking current package support. Keep cache behind repository interfaces. |
| Offline conflict policy | Default: detect concurrent edits using updated_at/version and surface a conflict instead of silently overwriting. |
| Event reminders | Default: in-app reminders/upcoming list first; browser notifications as best-effort enhancement. |
| Quest deletion | Default: offer archive first; permanent deletion requires confirmation and deletes its daily records. |
| Editing past quest days | Default: allow corrections to past dates; future dates cannot be marked complete before their day. |
| Upper-limit behavior | Default: reject values above the configured upper limit with a validation message; never silently cap the saved actual value. |
| Date-range presets | Default: custom start/end dates, plus convenience buttons to prefill a whole month or year. |
| Backups | Default: user-triggered JSON export/import with validation; cloud storage remains the primary source of truth. |

## 12. Acceptance checklist

- [ ] A user can sign up, log in, restore a session, and log out.
- [ ] User A cannot access User B's tasks, events, quests, or quest records.
- [ ] Home shows three summary bars and navigates to the relevant screen.
- [ ] The calendar shows task/event markers and selected-day details.
- [ ] The '+' flow creates either a task or an event.
- [ ] Task/event details provide edit and delete with confirmation.
- [ ] Quest creation requires tracking mode, date range, and valid numeric settings when applicable.
- [ ] Binary heatmaps use grey and green only for incomplete/complete days.
- [ ] Numeric heatmaps use grey for zero, green shades for partial progress, full green at target, and purple above target.
- [ ] Streaks and completion rates follow the documented rules and have unit tests.
- [ ] Initial release: cloud data loads and saves reliably with clear loading/error states. If the optional cache phase is implemented, cached data loads when available and offline edits are visibly queued.
- [ ] The app handles loading, empty, error, and sync-failure states.
- [ ] The UI works on desktop and narrow/mobile widths.
- [ ] The repository includes a README, screenshots, setup instructions, and a deployed website link.

## 13. Reference documentation

- Flutter adaptive and responsive design: <https://docs.flutter.dev/ui/adaptive-responsive>
- Flutter navigation: <https://docs.flutter.dev/ui/navigation>
- Flutter forms: <https://docs.flutter.dev/cookbook/forms>
- Flutter offline-first architecture: <https://docs.flutter.dev/app-architecture/design-patterns/offline-first>
- Supabase Flutter quickstart: <https://supabase.com/docs/guides/getting-started/quickstarts/flutter>
- Supabase Row Level Security: <https://supabase.com/docs/guides/database/postgres/row-level-security>
- Flutter web deployment: <https://docs.flutter.dev/deployment/web>

*End of specification*
