# Issue 016: Device e2e via integration_test (built-in stack)

Status: open | Priority: P1 | Type: test | Reviewed-at: 2026-10-13

## Goal
Device-run end-to-end coverage for the four critical user journeys, using only the Flutter SDK `integration_test` + `flutter_test` stack. No widget-unit-test work here (owned per-feature by #003–#011) — this issue is the on-device harness + four flow specs.

## Decisions (2026-10-11, with repo owner)
- **(2026-10-13) Absorbs #028, now closed as superseded:** #028's one-line ask ("every issue implementation needs a corresponding integration test") is satisfied by this issue's four-flow harness being the single source of truth for integration/e2e coverage — no separate per-issue `integration_test` work is tracked outside this issue. Per-feature widget-test coverage gaps (not integration-test-level) stay tracked individually where found (e.g. #029's `SetDetailScreen` gap).
- Scope: **`integration_test` only** (not `flutter_test` widget tests — those stay per-feature in #003–#011).
- Framework: **built-in stack only** (`integration_test` SDK package + `flutter_test`). Patrol rejected: extra native setup, risks the iOS + Windows support rule (AGENTS.md).
- Flows (all four): Library CRUD (#003/#004), lesson play-through (#005–#009), XP + streak (#010/#011), share import/export (#002/#008).
- Gate: **blocked until device** — issue stays open until at least one real device run passes (see Verify). `flutter analyze` / `flutter test` green alone is not enough to close.

## Acceptance criteria
- [ ] `integration_test/` harness runs on device: `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, app boots under test with Riverpod overrides (isolated test DB — never touches the real `fox_streak` DB; overridable `Clock`; seeded demo content, no network).
- [ ] Flow 1 — Library CRUD (#003/#004): create set → add one item of each type → rename → duplicate (`(copy)` suffix) → delete with confirm; invalid inputs blocked (empty title, future date, bad phone).
- [ ] Flow 2 — Lesson play-through (#005–#009): start lesson from seeded set, answer one vocab-MCQ + one free-text + one phone + one date item through CHECK → feedback → CONTINUE, reach `ResultScreen` with score %; quit-via-X with confirm leaves no dead-end.
- [ ] Flow 3 — XP + streak (#010/#011): completed lesson persists XP (`10` first-try / `5` hint-or-retry / `0` wrong, `+5` for 100%) and `StreakBadge` shows new-day increment exactly once (same-day replay never double-counts).
- [ ] Flow 4 — Share round-trip (#002/#008): `exportSetToJson` → `importSetFromJson` round-trip preserves items; bad JSON surfaces `SetImportException` as snackbar (not crash). Native `share_plus` sheet / `file_picker` dialog are stubbed at the platform-channel level — no real share sheet or file dialog in the test.
- [ ] Finders are stable: exercised screens expose `ValueKey`s (or semantics labels) for set rows, FAB, CHECK/CONTINUE, dial-pad keys, calendar; tests never rely on text-position or timing sleeps (use `pumpAndSettle` / `waitFor`).
- [ ] `flutter analyze` clean, `dart format` clean; `integration_test` dep is SDK-only (`integration_test: sdk: flutter`) so android/ + ios/ + windows/ all keep building, `minSdk 24` pin untouched.

## Tasks
1. Deps + scaffold: add `integration_test` (SDK dev-dep), `integration_test/app_test.dart` entry + `integration_test/helpers.dart` (boot app in `ProviderScope` with test overrides, seed helper, finder keys doc).
2. Testability hooks in app code (minimal, no behavior change): add `ValueKey`s to `LibraryScreen` rows/FAB, `SetDetailScreen` menu, `CheckButton`/feedback banner/`ResultScreen`, `DialPadExercise`, `DateExercise`, `StreakBadge`; expose a test boot path that injects isolated DB + `FakeClock` (reuse `test/data/test_helpers.dart` pattern). Shell keys owned by #005; card-internal keys (dial-pad, calendar, option cards, text field) owned by #006–#009.
3. Write the four flow specs (one `group()` per flow in `app_test.dart`, or one file per flow if it exceeds ~300 lines).
4. Stub `share_plus` / `file_picker` channels in-test; assert snackbar/dialog outcomes per #008 contract (real-number export warning dialog, picker-cancel no-op).
5. Docs: README section with run commands + what is stubbed; note the device gate and the remaining Android-SDK blocker below.

## Out of scope
- Per-widget unit tests (each stays in its feature issue: #003 Task 4, #006–#011 grading/formula tests).
- Golden/screenshot tests, Patrol, performance benchmarks, CI device farm — follow-up issues if wanted.
- Full copy-deck i18n assertions (#012) beyond whatever locale the harness boots in (default EN; assert DE only if the harness sets it explicitly).

## Dependencies / Blocked
- Needs UI from #003–#005 (library + lesson shell) at minimum before flows 1–2 are writable; flows 3–4 need #008–#011 widgets. Scaffold (Task 1) can land first; flow specs fill in as screens land.
- Device gate partially unblocked 2026-10-11: VS + Chrome installed (`flutter build windows --debug` succeeds), so the Windows desktop run below works now; Android emulator still BLOCKED on missing SDK (see #001). Primary gate stays an Android emulator (`flutter test integration_test` / `flutter run integration_test/app_test.dart`); Windows desktop run is a working second signal. Do not close before one of these passes.

## Verify
```powershell
flutter analyze        # must be clean
dart format .          # must be clean
flutter test integration_test   # HOST CHECK only — real gate is a device run below (Android run still blocked on missing SDK; Windows run works since 2026-10-11)
# Gate to close (one required):
# flutter test integration_test -d <android-emulator-id>   (Android-first, preferred — still needs Android SDK)
# or: flutter run integration_test/app_test.dart -d windows (WORKS since VS installed; `flutter build windows --debug` verified 2026-10-11)
```
