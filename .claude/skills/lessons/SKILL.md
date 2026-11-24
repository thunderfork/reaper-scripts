---
name: lessons
description: The self-improvement routine for the scripts of this repository (tools\scripts.psd1) - the global lessons skill plus the project steps (the REAPER test files, a search of the other scripts, the tag list, the count before a release). Use when the user reports a bug or a failed manual test, when debug-time finds a bug in committed code, and before a release (the count).
---

# Lessons (project steps)

Read and follow the global skill first: `%USERPROFILE%\.claude\skills\lessons\SKILL.md`. This project adds:

## Trigger

Also a `debug-time` finding in code that was already committed.

## Fix and check

- The regression test goes in the script's test file (`tools\scripts.psd1` names it); run it on the old code with
  `.\tools\test.ps1 -Script "<name>"`: it must fail. No test possible (rendering, scrolling, timing that REAPER
  must show): a manual test under "Open now" in PLAN.md.
- After the fix: `.\tools\check.ps1` ("Syntax and globals OK"), the tests ("0 failed"), deploy. Commit only when
  the user asks (CLAUDE.md).
- Search the other 6 scripts for the same pattern (Segue shares Chart Cue's setlist logic; all scripts copy
  Chart Cue's UI). Report the result in 1 line. A fix in another script follows the same steps.
- Test gaps: `.\tools\test.ps1 -Script "<name>" -Coverage` lists the functions that the tests never run.

## LESSONS.md

The entry format and the tag list are in the file. Exactly 1 tag from the list; a new tag only when no tag fits
(add it to the list). Status "confirmed" when the user reports "Passed" for the manual test.

## A tag comes back

The session start names each tag with 2 or more entries and no line in `LESSONS-RULES.md`. The order of the
stronger fixes: a test for the whole pattern, a check in `tools\check.ps1`, a skill step, a rule last. Write the
answer (accepted or rejected, the date, the tag) in `LESSONS-RULES.md`.

## Before a release, and each quarter

- Before a release: count the entries since the last release (the escaped bugs), in 1 line. The number must go
  down over 2 or 3 releases; when it does not, tell the user and propose a change of this routine.
- Each quarter (or in `housekeeping`): read `LESSONS-RULES.md`; propose to remove a rule that no longer helps.
