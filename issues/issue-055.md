# Issue 055: Settings screen with haptics + sound toggles

Status: open | Priority: P3 | Type: feature

## Goal

`foxHapticsEnabledProvider` (#015) and the new `foxSoundEnabledProvider`
(#053) both exist (or will exist) as default-on, code-level toggles with no
way for a user to actually flip them — there's no settings screen anywhere
in the app. Add a small settings surface exposing both as switches, so the
mute controls promised by #053/#054 are actually reachable.

## Acceptance criteria

- [ ] A settings screen/section exists and is reachable from the app's
      navigation (exact entry point TBD at implementation time — e.g.
      Home's app bar, a dedicated tab).
- [ ] A switch for haptics, wired to `foxHapticsEnabledProvider.setEnabled`.
- [ ] A switch for sound, wired to `foxSoundEnabledProvider.setEnabled` (or
      whatever the equivalent provider is named once #053/#054 land).
- [ ] Both default to on, matching current provider defaults.
- [ ] Follows #015: kit widgets/tokens, no ad-hoc styling; new strings via
      `lib/l10n` arb params (DE + EN).
- [ ] `flutter analyze` / `dart format` / `flutter test` clean.

## Out of scope

- Any other settings (locale override, data export/reset, etc.) — scoped
  strictly to the two celebration-effect toggles for now.

## Dependencies

- Needs #053's `foxSoundEnabledProvider` (or #054's, whichever lands first
  / whichever sound toggle is introduced) to exist before wiring its
  switch.
- Builds on #015's `foxHapticsEnabledProvider`.
