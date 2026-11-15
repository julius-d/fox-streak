# Issue 135: Report audioplayers_linux crash without GStreamer playbin upstream

Status: open | Priority: P3 | Type: tech-debt | Refined-at: 2026-11-15

## Goal

Found while implementing #129: `audioplayers_linux` 4.3.0 aborts the whole
app when it creates a player while GStreamer's `playbin` element is missing
(e.g. no `gstreamer1.0-plugins-base`). Its `create` handler
(`audioplayers_linux_plugin_create_player`) doesn't catch the `const char*`
the `AudioPlayer` constructor throws, so `std::terminate` kills the process.
No Dart error handling can catch that.

#129 works around it: on Linux, `foxSoundPlayerProvider` first asks GStreamer
itself (`lib/src/widgets/gstreamer_probe.dart`, via `dart:ffi`) and hands out
a `SilentSoundPlayer` if `playbin` is missing.

## Acceptance criteria

- [ ] Bug reported upstream (bluefireteam/audioplayers) with the stack trace:
      the `create` method call needs the same `try`/`catch` the other methods
      already have.
- [ ] Once a fixed version is released and adopted, decide whether to keep
      the FFI probe (it also avoids creating doomed players) or drop it.
