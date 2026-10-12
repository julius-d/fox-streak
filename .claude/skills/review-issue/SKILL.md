---
name: review-issue
description: Review issues for consistency and completeness
---

Check for inconsistencies within the issue. and compared to other issues and compare to the already implemented features.
Look for missing acceptance criteria, missing tasks, and any other gaps in the issue.
For each inconsistency or gap, provide a clear explanation and suggest a solution or improvement.
Use the askQuestion tool to ask the user for each inconsistency etc, if it shall be adressed and if yes suggsst 2 possible solutions for each.
When the user has answered all questions, provide a summary of the issues and the agreed solutions.
Ask the user if the issue(s) shall be updated with the agreed solutions and if yes, update the issue(s) accordingly. 
In case of an update add a `Reviewed-at` timestamp to the status line of the issue.
Do not implement the issue yet or do any other code changes, this is only about improving the issue(s)