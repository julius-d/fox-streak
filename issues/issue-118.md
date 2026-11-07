# Issue 118: integration test issue102_image_load_retry fails with "Bad state: No element"

Status: open | Priority: P3 | Type: chore

## Goal

`integration_test/issue102_image_load_retry_test.dart` fails on macOS
(`flutter test integration_test/issue102_image_load_retry_test.dart -d macos`),
also on unmodified `main` (seen 2026-11-07 while doing #113):
`_failCurrentImage` does `tester.widget<Image>(find.byType(Image))` and gets
`Bad state: No element`.

Likely cause: the test points at `http://127.0.0.1:1`, so the real network
error races the test's manually triggered `errorBuilder` calls — the real
auto-retries can already have exhausted and replaced the `Image` with the
failed placeholder before `_failCurrentImage` runs. Make the test
deterministic (e.g. no reliance on a real connection failure / tolerate the
already-failed state).

## Acceptance criteria

- [ ] The test passes reliably on macOS.
