# l10n (issue #003)

`app_en.arb` / `app_de.arb` are the source of truth for the library/detail
strings (full copy deck + onboarding stay in #012).

`app_localizations.dart` is a **hand-written** delegate that mirrors the arb
files 1:1 (uses `flutter_localizations` + `intl`, same `AppLocalizations`
API codegen would produce).

## Why there is no root `l10n.yaml`

There used to be one, but it had to go (commit `460d0fb` follow-up):

- The Flutter tool treats a root `l10n.yaml` as "generate localizations
  during every build" and fails the build when the `flutter: generate`
  flag is off.
- Turning the flag on is worse on this machine: `flutter gen-l10n`
  refuses to run here because Dart's `FileStat.modeString()` reports
  `r-xr-xr-x` (no write bit) for every directory inside this OneDrive
  checkout (outside OneDrive it reports `rwxrwxrwx`), so the tool thinks
  `lib/l10n` is not writable. Until that is fixed, codegen cannot run
  in this checkout at all.

## Regenerating (on a non-OneDrive checkout)

1. Temporarily restore a root `l10n.yaml` with:
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   ```
2. Set `flutter: generate: true` in `pubspec.yaml`.
3. Run `flutter gen-l10n`, verify `git diff` on `app_localizations.dart`
   matches the arb files, then revert both the flag and the yaml before
   committing (see above).
