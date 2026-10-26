# Issue 072: Lesson progress bar drains backward on "Practice again"

Found while implementing #066 (animated lesson progress bar).

`lesson_screen.dart`'s AppBar + `lessonProgressBar` `FoxProgressBar` stay
mounted across the whole screen lifetime — only `Scaffold.body` swaps
between the lesson body and the result screen. Tapping "Practice again"
calls `LessonController.restart()`, which resets `outcomes` to `[]`, so
`state.progress` jumps from `1.0` straight back to `0.0` in one state
update.

Since #066 made `lessonProgressBar` `animated: true`, the still-mounted
`FoxProgressBar` now tweens that drop over ~300ms instead of resetting
instantly — the bar visibly drains backward from full to empty right as
the next lesson's first item appears, instead of just being empty from
the start.

Decide whether a restart should reset the bar instantly (e.g. by keying
`FoxProgressBar` on something that changes per lesson attempt, forcing a
remount) or whether animating the reset is actually fine/intentional, then
implement + cover with a test.
