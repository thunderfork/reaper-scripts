---
name: lessons
description: The self-improvement routine for Chart Cue, Segue, MIDI Pilot, FX Link, Session Prep and SFX Drop - an escaped bug gets a test that fails first, a fix, a search of the other scripts and an entry in LESSONS.md; a cause tag that comes back gets a stronger fix. Use when the user reports a bug or a failed manual test, when debug-time finds a bug, and before a release (the count).
---

# Lessons

Goal: each escaped bug makes the scripts and the tests stronger, so the same type of bug does not come back.
The user does not read code: report in plain words.

## 1. Trigger (only an escaped bug)

- The user reports a bug, or a manual test in REAPER fails.
- A `debug-time` round finds a bug in code that was already committed.
- Not a trigger: a check or a test that fails during my own work (that is normal work, no entry).

## 2. Fix

1. Visible behaviour or saved data changes with the fix: ask the user first (CLAUDE.md). Else fix at once.
2. Write the regression test in the script's test file (`tests\`). Run it on the old code: it must fail.
   No test is possible (rendering, scrolling, timing that REAPER must show): write the reason, and add a manual
   test for the user instead.
3. Fix the code. The test passes; `check.ps1` prints "Syntax and globals OK"; `test.ps1 -Script "<name>"` ends
   with "0 failed". Deploy.
4. Search the other 5 scripts for the same pattern (Segue shares Chart Cue's setlist logic; all scripts copy
   Chart Cue's UI). Report the result in 1 line. A fix in another script follows the same steps.
5. Ask: why did the tests not find it? A hole in the tests gets a test too, when practical.

## 3. Entry in LESSONS.md

Add 1 entry at the top of "Entries" (the format is in the file). Exactly 1 tag from the tag list; a new tag only
when no tag fits (add it to the list). Status "fixed, not confirmed" until the user reports "Passed" for the
manual test; then "confirmed". The open manual tests stay in PLAN.md "Open manual tests" (1 place).

## 4. A tag comes back

The session start shows the counts and names a tag at 2 or more that has no line in "Rules from lessons" yet. Then: propose a stronger fix to the user, in a question window (Accept /
Reject / Later), in this order of preference:
1. a test that covers the whole pattern;
2. a check in `tools\check.ps1`;
3. a step in a skill;
4. a rule in CLAUDE.md (the last choice: it makes the other rules less visible).
Write the answer in "Rules from lessons" of LESSONS.md (accepted or rejected, with the date).

## 5. Before a release, and each quarter

- Before a release: count the entries since the last release (the escaped bugs) and report it in 1 line. The
  number must go down over 2 or 3 releases; when it does not, tell the user and propose a change of this routine.
- Each quarter (or in `housekeeping`): read "Rules from lessons"; propose to remove a rule that no longer helps.
