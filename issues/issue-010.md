# Issue 010: XP + levels system

Status: open | Priority: P1 | Type: gamification

## Goal
Duolingo-like XP per correct answer, levels to chase.

## Duolingo reference
~10 XP per lesson, combo bonuses. Levels give progression without punishing teens.

## Acceptance criteria
- [ ] XP: 10 per correct first-try, 5 if hint used / second try, 0 if wrong; lesson bonus +5 for 100%
- [ ] Level formula fixed: `level = floor(sqrt(xpTotal / 100)) + 1`, progress-to-next shown
- [ ] XP animates on result screen, persists same day
- [ ] Unit tests for formula + accumulation

## Tasks
1. `XpService.addAttempt()` pure logic + persistence via #002
2. Level progress bar widget reusable on home + result
3. Daily goal default 30 XP, editable (see #012)

## Out of scope
Streaks (#011), leaderboards (post-MVP).
