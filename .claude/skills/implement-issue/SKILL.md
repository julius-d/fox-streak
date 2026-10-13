---
name: implement-issue
description: Implement an issue
---

Read the issue carefully and plan its implementation before implementing it. 
Remember that we need a clean code with an maintainable architecture and excellent test coverage.

Create a new git worktree for the issue.
Then implement the issue.
When creating new UI, create `integration_test` test for it, to check they realy work.
Write the `integration_test`, execute it and make sure it passes before you finish the implementation of the issue.

You are done when the issue is implemented, all tests are passing, and the code is formatted.
Especially: `flutter analyze`, `dart format`, `flutter test`.
After you are done, change the status of the issue to "done", add `Completed-at: <date>` and add a very short, few lines only, summary block to the end of the issue that contains important information only.

Then run a subagent to perform a code review for the changes just made, using the relevant code review skill.

Verify the findings and judge which findings to fix.
Add a short "Code review" block at the end of the issue.
With 2 lines per finding. First line describing the finding. Second line telling weather it was fixed and if not why.

Then commit the changes into the worktree branch.
Then rebase the worktree branch onto a fresh main.
Then ask we if this shall be fast-forward merged (without merge commit) into main.

Note on technical debt: If you find a problem that is not part of the issue, but should be fixed, create a new, short issue for it for it. so that it can be fixed later. 
Do not fix it in this issue, unless it is a small and easy fix that does not require much time and effort.
