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
Move the issue file with `git mv issues/issue-NNN.md issues/done/issue-NNN.md` (never copy or recreate it), then run `tool/check_issues.sh` and make sure it passes.

If the change alters a widget covered by `test/golden/` (visuals intentionally changed): regenerate your platform's baselines (`flutter test --update-goldens test/golden`), and also the Linux ones, which CI verifies against and which only CI can generate. Do this after the branch is pushed or merged, via `gh workflow run update-goldens.yml`, then download the `linux-goldens` artifact (`gh run download <run-id> -n linux-goldens`), review the changed PNGs and commit only those that differ into `test/golden/goldens/linux/`. Otherwise main CI goes red.

If the implementation of the issue changed UI: create screenshots that show the changed UI:
1. Write a throwaway test file, e.g. integration_test/_scratch_issueNNN_screenshots_test.dart, with the seed data + pump/capture logic above, writing to ${Directory.systemTemp.path}/screenshots and printing that path.
2. `flutter test integration_test/_scratch_issueNNN_screenshots_test.dart -d macos`
3. Grab the printed SCREENSHOT_OUT_DIR: ... path from the output.
4. `cp "<that path>"/*.png issues/done/issue-NNN-what-it-shows.png`
5. Delete the scratch test file (it's not meant to be a permanent part of the suite — it has side effects and bespoke fixture data) and the temp dir.

Then run a subagent to perform a code review for the changes just made, using the relevant code review skill.

Verify the findings and judge which findings to fix.
Add a short "Code review" block at the end of the issue.
With 2 lines per finding. First line describing the finding. Second line telling weather it was fixed and if not why.

Then commit the changes into the worktree branch.
Then rebase the worktree branch onto a fresh main.
Then ask we if this shall be fast-forward merged (without merge commit) into main.
If the only changes in main are about issue files, there is no need to run tests.

Note on technical debt: If you find a problem that is not part of the issue, but should be fixed, create a new, short issue for it. so that it can be fixed later. 
Do not fix it in this issue, unless it is a small and easy fix that does not require much time and effort.
