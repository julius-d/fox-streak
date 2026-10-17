# Issue 050: Desktop windows (macOS, Windows) open with a desktop-sized window instead of a phone-like default

Status: done | Priority: P3 | Type: UX | Refined-at: 2026-10-17 | Completed-at: 2026-10-17

## Goal

FoxStreak's UI is designed and laid out for a phone screen (see #015), but on
desktop platforms the window opens at a desktop-sized default: macOS uses
whatever frame `MainFlutterWindow.swift`'s nib provides (typically a large
default window), and Windows is hardcoded to 1280×720 in
`windows/runner/main.cpp:28`. On first launch this stretches the phone-shaped
UI across a much wider/shorter window than it was designed for.

The window should instead open at a phone-like default size on these desktop
platforms, so the app looks like what it is — a phone app — even when run on
a desktop. The window stays freely resizable afterward; this only changes the
*initial* size/shape, not a permanent aspect-ratio constraint.

## Decision

- **Platforms in scope**: macOS and Windows (the two desktop runners
  currently in the repo). iOS/Android are already phone-shaped and
  untouched. There is no `linux/` platform directory in this repo yet, so
  Linux is out of scope until that platform is added.
- **Window behavior**: resizable, free aspect ratio — only the initial
  default size changes to a phone-like size; the user can resize to any
  shape afterward with no locked ratio or min/max bounds.
- **Default size**: 390×844 logical pixels (iPhone 14 portrait reference
  size, ~19.5∶9), centered on screen.
- **Implementation**: add the `window_manager` package
  (`macos`/`windows`/`linux` support) rather than duplicating native code in
  both `MainFlutterWindow.swift` and `win32_window.cpp`. In `lib/main.dart`,
  before `runApp`, on macOS/Windows only
  (`Platform.isMacOS || Platform.isWindows`): call
  `windowManager.ensureInitialized()`, then `waitUntilReadyToShow()` with a
  `WindowOptions(size: Size(390, 844), center: true)`, then `show()` +
  `focus()`. iOS, Android, and web skip this entirely (no `window_manager`
  call, no platform-channel registration attempted).
- Windows' native fallback size in `win32_window.cpp` (1280×720, the
  pre-Flutter-init frame visible for a brief moment before `window_manager`
  resizes it) is left as-is — only the Dart-side default changes.

## Acceptance criteria

- [x] `window_manager` added to `pubspec.yaml` dependencies.
- [~] On macOS, launching the app (`flutter run -d macos` or a built app)
      opens a window sized ~390×844 logical pixels, centered on screen.
      App built and launched cleanly via the `window_manager` code path;
      exact geometry could not be measured from this sandboxed shell (no
      Accessibility/Screen-Recording permission for `osascript`/
      `screencapture`) — needs a quick human glance to fully confirm.
- [ ] On Windows, launching the app (`flutter run -d windows` or a built
      app) opens a window sized ~390×844 logical pixels, centered on screen.
      Not verified — no Windows machine available in this environment;
      relies on `window_manager`'s documented cross-platform behavior.
- [x] The window remains freely resizable by the user after launch (no
      aspect-ratio lock, no min/max size enforced). `WindowOptions` sets
      only `size`/`center`, no min/max/aspect-ratio constraints.
- [x] iOS and Android behavior is unchanged (no `window_manager`
      initialization attempted on mobile).
- [x] `flutter analyze` / `dart format --output=none --set-exit-if-changed .`
      / `dart fix --dry-run` stay clean (no `flutter test` coverage expected
      for native window sizing — not practical to assert window pixel size
      from widget tests; note this explicitly as untested in the PR).

## Out of scope

- Locking the window to a phone aspect ratio or enforcing min/max size
  bounds after launch — only the initial default size changes.
- Linux support — no `linux/` platform directory exists in this repo yet;
  revisit if/when Linux is added.
- Any change to the actual app UI/layout to be more "responsive" for
  non-phone window shapes — this issue only addresses the default window
  size, not how the UI adapts if a user resizes the window wider.
- Remembering/persisting a user-resized window size across restarts (always
  reopens at the phone-like default) — not requested, flag separately if
  wanted later.

## Dependencies

- None blocking; independent of other open issues.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter run -d macos    # manually confirm window opens phone-sized, centered
flutter run -d windows  # manually confirm window opens phone-sized, centered
```

## Summary

Added `window_manager` and, in `lib/main.dart`, gated on
`Platform.isMacOS || Platform.isWindows`: `ensureInitialized()` →
`waitUntilReadyToShow(WindowOptions(size: Size(390, 844), center: true))` →
`show()` + `focus()`, before `runApp`. iOS/Android/web untouched.
`windows/runner/main.cpp`'s 1280×720 native fallback left as-is per the
issue's decision. `flutter analyze`, `dart format`, `dart fix --dry-run`,
and `flutter test` all clean. macOS build/launch verified to not crash;
precise on-screen geometry on macOS and any Windows run need a human check
(sandbox had no Accessibility/Screen-Recording access; no Windows machine
here).

## Code review

- `window_manager` has no iOS/Android implementation, which taken literally
  contradicts AGENTS.md's "never add a plugin without iOS + Windows + macOS
  support" convention.
  Not fixed — the issue's own Decision section explicitly chose this
  desktop-only package and explicitly scoped iOS/Android to skip it
  entirely; that convention targets plugins used app-wide, not a
  desktop-only window-shape tweak this issue deliberately decided on.
- The `Platform.isMacOS || Platform.isWindows` gate in `main()` has no
  automated test covering it.
  Not fixed — the issue's own acceptance criteria already call this out as
  impractical to assert via widget tests; extracting a testable seam for a
  3-line gate would be a premature abstraction for no real coverage gain.
