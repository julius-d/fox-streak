# Issue 028: Per-issue integration test coverage audit

Status: closed (superseded by #016) | Reviewed-at: 2026-10-13

## Goal
Originally: every issue implementation should have a corresponding integration test (new or updated), since this rule wasn't in place from day 0 and some coverage is missing.

## Resolution (2026-10-13, with repo owner)
Superseded by #016, which already defines the on-device integration-test harness (`integration_test` SDK package, four critical-flow specs: Library CRUD, lesson play-through, XP + streak, share round-trip) as the single source of truth for integration/e2e coverage. Tracking the same intent in two issues risked duplicate or contradictory test work.

Per-feature widget-test coverage gaps (not integration-test-level) are tracked individually where found (e.g. #029's `SetDetailScreen` gap), not here.

No further action in this issue — see #016.
