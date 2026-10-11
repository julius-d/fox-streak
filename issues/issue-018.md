# Issue 018: GitHub CI workflow (analyze + format + test + Android build)

Status: open | Priority: P1 | Type: chore

## Goal
Add a GitHub Actions CI workflow built on the local `AGENTS.md ## Verify` gates (`flutter analyze`, `flutter test`, `dart format`) plus an Android debug-build smoke check, pinned to the repo's Flutter version, running on PRs targeting `main` and pushes to `main`. CI is intentionally stricter than the local gates: format runs check-only (`--output=none --set-exit-if-changed`, never mutates) and runs first (format → analyze → test → build), whereas AGENTS.md documents mutating `dart format .`. `flutter pub get` (setup) and `flutter build apk --debug` (smoke) are CI additions, not local verify gates.

## Decisions (2026-10-11, with repo owner)
- Jobs: **analyze + format-check + test + build** (single workflow; local gates plus an Android build smoke job).
- Flutter SDK: **pin `3.47.6` stable** (matches `AGENTS.md`; reproducible CI, not floating `stable` latest).
- Runner: **`ubuntu-latest`** (cheapest runner that can do analyze/test/format + Android debug APK; no macOS/Windows runners in this issue).
- Build job: **Android debug APK only** (`flutter build apk --debug`, no signing) as a compile smoke check. iOS (`macos` runner) and Windows (`windows` runner, VS workload) builds are out of scope.
- Triggers: **`push` to `main` + `pull_request` targeting `main`** (no all-branches matrix, no cron, no manual-only).
- Drift codegen freshness check (`build_runner`) is **out** (not selected; `*.g.dart` files stay committed and are verified locally per AGENTS.md).

## Acceptance criteria
- [ ] `.github/workflows/ci.yml` exists and is the only workflow (no duplicate `dart.yml` / `flutter.yml`).
- [ ] Trigger block is exactly: `push` on `branches: [main]` + `pull_request` on `branches: [main]`; `concurrency` cancels superseded runs on the same ref.
- [ ] Setup uses `actions/checkout@v4` + `actions/setup-java@v4` (Temurin 17, gradle cache) + `subosito/flutter-action@v2` with `flutter-version: '3.47.6'`, `channel: stable`, `cache: true`.
- [ ] Workflow runs these steps in order in a single `ci` job on `ubuntu-latest` (locked: one Flutter setup, fastest for a small MVP; tradeoff: a failing early step hides later steps' signals):
  1. `flutter pub get`
  2. `dart format --output=none --set-exit-if-changed .` (check-only, never mutates)
  3. `flutter analyze` (must be clean — see #017-conditional note below)
  4. `flutter test` (unit/widget in `test/` only — must be green; explicitly not `integration_test/` host-check from #016)
  5. `flutter build apk --debug` (unsigned smoke build; `minSdk 24` pin and `android/` platform untouched; debug-compile only — does not satisfy the #013 release/appbundle gate)
- [ ] No new runtime dependencies; no changes to `android/`, `ios/`, `windows/` beyond what the build needs (none expected); `pubspec.lock` still committed.
- [ ] Workflow passes on `main` (green badge run linked in the closing comment); a test PR with an intentional `dart format` violation fails the format step as expected.
- [ ] Conditional on #017 landing order (record which order was used in the closing comment): if #017 landed first, CI `flutter analyze` already includes `riverpod_lint` + strict casts and CI also runs `dart fix --dry-run` (must be clean); if #018 lands first, CI runs base `flutter_lints` only and #017 upgrades it afterwards.
- [ ] README carries the docs: badge at the top + a new `## CI` section with the badge SVG URL (`actions/workflows/ci.yml/badge.svg?branch=main`), a "CI runs X, rerun Y locally" step↔command table, and the intentional-failure proof note; same edit fixes the stale AGENTS.md backlog range (`issue-001.md … issue-013.md` → `… issue-019.md`).

## Tasks
1. Add `.github/workflows/ci.yml` per the acceptance criteria (single `ci` job on `ubuntu-latest` — locked, one Flutter setup).
2. Local dry-run of every CI command in order (`flutter pub get` → format-check → analyze → test → `flutter build apk --debug`); note that the APK build is expected to fail locally (no Android SDK, see AGENTS.md) — CI is the gate for that step.
3. Push to a branch, open a PR, confirm green; push a format-breaking commit to the same PR, confirm the format step fails, then revert.
4. Docs: add CI badge at README top + `## CI` section (badge URL, step↔command table); fix the stale AGENTS.md backlog range to `issue-019.md` in the same edit.
5. Record the green `main` run URL + the intentional-failure run URL in the closing comment.

## Out of scope
- Drift codegen freshness (`dart run build_runner build --check` / `--delete-conflicting-outputs` diff check) — rejected for this issue (local-only per AGENTS.md); follow-up if `*.g.dart` drift becomes a problem.
- iOS (`macos` runner) and Windows (`windows` runner) builds, release signing / Play Store upload, `flutter build appbundle` / `--release` promotion — future issues if wanted.
- Branch-protection rules / required-status-checks enforcement in repo settings — document as a manual follow-up for the repo owner, not automated here.
- `dart fix --dry-run`, golden tests (#019), device e2e (#016), lint tightening itself (#017) — owned by their own issues; CI runs `flutter test` (unit/widget) only, not `integration_test/`; revisit CI when #019 defines a concrete golden command.
- Caching beyond `flutter-action` + gradle defaults, self-hosted runners, Codecov / coverage gates.

## Dependencies
- None blocking — can land any time; best **after #017** so `flutter analyze` in CI already includes `riverpod_lint` + strict casts, otherwise CI runs base `flutter_lints` and #017 upgrades it (note which order was used when closing).
- Blocked toolchain note: local `flutter build apk` stays red until the Android SDK is installed (AGENTS.md) — that is expected and does not block closing; the CI run is the build gate.

## Verify
```powershell
# Local mirror of CI (build step expected to fail locally — no Android SDK):
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze        # must be clean
flutter test           # must be green
# flutter build apk --debug  # local: blocked on toolchains; CI (ubuntu-latest) is the gate
# CI gates to close (links recorded in closing comment):
# - green run on main (.github/workflows/ci.yml)
# - red run on a test PR with an intentional format violation
```

## Summary (implementation complete 2026-10-11, remote verification pending)
- Landing order: **#017 landed first** — CI `flutter analyze` already includes
  `riverpod_lint` + strict casts, and CI runs the extra `dart fix --dry-run`
  hygiene gate per the conditional criterion.
- `.github/workflows/ci.yml` (only workflow): single `ci` job on
  `ubuntu-latest`; triggers exactly `push: branches: [main]` +
  `pull_request: branches: [main]`; `concurrency` cancels superseded runs on
  the same ref. Setup: `actions/checkout@v4` + `actions/setup-java@v4`
  (Temurin 17, gradle cache) + `subosito/flutter-action@v2`
  (`flutter-version: '3.47.6'`, `channel: stable`, `cache: true`).
  Steps in order: `flutter pub get` → `dart format --output=none
  --set-exit-if-changed .` → `flutter analyze` → `dart fix --dry-run`
  (grep-gated, see below) → `flutter test` → `flutter build apk --debug`.
- `dart fix --dry-run` gate detail: the command exits 0 even when fixes are
  proposed (verified empirically), so the step captures its output and
  `grep -q "Nothing to fix!"` — fails the step when fixes exist.
- README: CI badge at top + new `## CI` section (badge SVG URL
  `actions/workflows/ci.yml/badge.svg?branch=main`, step↔command table,
  intentional-failure proof note). AGENTS.md backlog range needed no edit:
  #017 already changed it to `see issues/` (covers `… issue-019.md` and
  beyond); no `android/`/`ios/`/`windows/` changes; no new deps.
- Local gates (Flutter 3.47.6, this machine): `flutter pub get` ok;
  format 0 changed; `flutter analyze` → No issues found;
  `dart fix --dry-run` → Nothing to fix; `flutter test` → All 76 passed.
  `flutter build apk --debug` not run locally (no Android SDK per AGENTS.md;
  CI is the gate for that step).
- Gate-logic proofs (local, probe files removed afterwards): format violation
  → `dart format --output=none --set-exit-if-changed .` exits 1 listing the
  file, clean tree exits 0; fix proposed → `Nothing to fix!` marker absent
  (step would fail), clean tree → marker present (step passes).
- PENDING (owner — no `gh` CLI in this session to open the PR): branch
  `chore/ci-018` is pushed; open the PR at
  `https://github.com/julius-d/fox-streak/pull/new/chore/ci-018` (targets
  `main`; note the diff also contains the 4 unpushed #017-era commits on local
  `main`), record the green run URL, push a format-breaking commit to confirm
  the red format step, revert it, merge, then record the green `main` run URL
  in the closing comment and flip Status to done.

## Verification (remote runs, 2026-10-11)
- PR #1 (`chore/ci-018` → `main`): CI green (owner-reported), merged as
  `e85872c`. Rebased to a #018-only diff before merge (see history).
- RED proof — PR #2 (`test/ci-red-proof` → `main`, never merged, branch
  deleted after): `https://github.com/julius-d/fox-streak/actions/runs/38153827942/job/114512572404?pr=2`
  `Check formatting` failed as expected:
  `Changed ci_red_probe.dart / Formatted 41 files (1 changed) / Error:
  Process completed with exit code 1.`
- PENDING: green `main` run URL (push-to-main CI after the #1 merge) — then
  flip Status to done.
