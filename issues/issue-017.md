# Issue 017: Code quality gates — tightened lints + Riverpod lints + format

Status: open | Priority: P1 | Type: chore

## Goal
Bring code quality to a shared, enforced baseline: tightened `flutter_lints` + strict analyzer type checks + `riverpod_lint` + `dart format` / `dart fix`, all runnable locally via `flutter analyze`. No paid tooling, no CI in this issue.

## Decisions (2026-10-11, with repo owner)
- Base ruleset: **tightened `flutter_lints`** (stay on `flutter_lints`, do not switch to `very_good_analysis` — avoids large fix churn on a small MVP codebase; hand-pick extra rules instead).
- Riverpod: **yes, `riverpod_lint` is a must** — app uses Riverpod (`flutter_riverpod` + `ProviderScope` at root); catches `missing_provider_scope`, provider-parameter, dispose-misuse class bugs that base lints miss.
- Paid DCM: **out** — `dcm.dev` (450+ rules, metrics) is future/optional only, overkill for a local-only MVP and paid.
- Enforcement: **local gates only** (`flutter analyze` + `dart format` + `dart fix --dry-run`); no GitHub Actions workflow in this issue (follow-up if wanted).

## Acceptance criteria
- [ ] `analysis_options.yaml`: keeps `include: package:flutter_lints/flutter.yaml`, adds strict type safety:
  ```yaml
  analyzer:
    language:
      strict-casts: true
      strict-inference: true
      strict-raw-types: true
  ```
- [ ] `analysis_options.yaml`: enables `riverpod_lint` analyzer plugin (dev-only, no runtime dep, iOS + Windows safe):
  ```yaml
  plugins:
    riverpod_lint: <pinned version matching flutter_riverpod major>
  ```
  plus `riverpod_lint` in `dev_dependencies` (version pinned in `pubspec.lock`).
- [ ] `analysis_options.yaml`: hand-picked extra `linter.rules` enabled (document why each one is on); candidate set to evaluate: `require_trailing_commas`, `avoid_positional_boolean_parameters`, `prefer_single_quotes` (only one of single/double — pick one, repo currently uses single), `use_key_in_widget_constructors`, `avoid_print`, `prefer_const_constructors`, `prefer_const_declarations`, `unnecessary_imports` (if not already in base). Final list + rationale recorded in the file as comments.
- [ ] `analysis_options.yaml`: `analyzer.exclude` covers generated + platform code: existing `build/**`, `android/**`, `ios/**`, `windows/**` plus `**/*.g.dart` (Drift codegen) and `lib/generated_plugin_registrant.dart`.
- [ ] Zero new runtime dependencies: only `dev_dependencies` touched (`riverpod_lint`, already-present `flutter_lints`); `minSdk 24` pin and android/+ios/+windows/ platforms untouched (3-platform rule).
- [ ] `flutter analyze` clean with zero `info`/`warning`/`error` on a fresh `flutter pub get`; every `// ignore:` in `lib/` + `test/` has a same-line justification comment (no blanket `ignore_for_file` except generated files).
- [ ] `dart format .` clean; `dart fix --dry-run` shows nothing auto-fixable left (run `dart fix --apply` once during the issue, then keep clean).
- [ ] AGENTS.md `## Verify` section updated: documents the four must-tools (`flutter analyze`, `dart format`, `dart fix --dry-run`, `riverpod_lint` via analyze) and keeps the "no separate lint step" note accurate.
- [ ] `flutter test` still green (no behavior change — this issue is config + fixes only).

## Tasks
1. Audit current state: record `flutter analyze` output, `dart format --output=none --set-exit-if-changed .` output, and current `flutter_lints` version; list which extra rules already fire.
2. Update `analysis_options.yaml` (strict language options, `riverpod_lint` plugin, extra rules, `**/*.g.dart` exclude) + `pubspec.yaml` dev-dep; run `flutter pub get`.
3. Fix pass: `dart fix --apply`, then manually fix remaining analyzer + `riverpod_lint` findings (prefer fixing code over adding `ignore:`; where `ignore:` is unavoidable, add justification comment).
4. Format pass: `dart format .`; confirm `flutter test` green.
5. Docs: update AGENTS.md `## Verify` + add short "Lint rules" comment block at top of `analysis_options.yaml` explaining base choice and where to propose new rules.
6. Record final `flutter analyze` + `dart fix --dry-run` output in the closing comment.

## Out of scope
- Switching base to `very_good_analysis` / `lint` package / enable-all-rules setup — rejected for now (revisit post-MVP if the team wants stricter).
- DCM trial, metrics thresholds (complexity, LOC), unused-code/duplicate-code dashboards — future issue if wanted.
- CI workflow (GitHub Actions running analyze/format/test) — follow-up issue; this one stays local-only.
- Behavior or UI changes; per-feature widget/unit tests (stay in #003–#011, #016).
- Golden/screenshot tests, pana score work (app, not package — `publish_to: none`).

## Dependencies
- None blocking — can land any time; ideally **before** the #004–#009 UI wave so new screens start clean (small retrofit of existing `lib/src/library/` + `lib/src/data/` expected in the fix pass).
- Follows #002 (data layer done) — must keep `*.g.dart` regeneration (`build_runner`) working and excluded from analysis.

## Verify
```powershell
flutter pub get
flutter analyze        # must be clean (includes riverpod_lint plugin)
dart format --output=none --set-exit-if-changed .  # must be clean (or: dart format . then git diff --exit-code)
dart fix --dry-run     # nothing auto-fixable left
flutter test           # must be green (no behavior change)
```
