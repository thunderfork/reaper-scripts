# Rules from lessons

Loaded in every session from `CLAUDE.md`. The entries behind these rules are in `LESSONS.md`. 1 line per accepted
(or rejected) stronger fix, with its date and cause tag; the session start checks each tag against this file.

- 2026-11-17, `stale-state` (accepted): each script that keeps data from a project (a scan, a list, a cache) has a
  test "another project": the data is cleared or not used after a project switch or File > Open in the same tab.
  Done: every script that keeps project data, except SFX Drop's File > Open case (an open finding in its folder
  CLAUDE.md). A new script gets this test too.
- 2026-11-17, `saved-data` (accepted): every name field checks an empty or a taken name when you finish typing (a
  step in the `new-feature` skill).
- 2026-11-17, `audio-measure` (accepted): every audio measurement (a level, a peak, a verdict, a hit point) has a
  test with a generated WAV file, not only with numbers. Done: Session Prep (sine_wav in `tests\sessionprep.lua`).
  To add: SFX Drop (before its release, PLAN.md).
- 2026-11-26, `edge-case` (rejected): each entry has its own test, and the global "edge cases" rule covers the
  pattern.
- 2026-11-26, `imgui-input` (accepted, new code only): a new or changed click or key rule is a plain function with a
  test (a step in the `new-feature` skill); old code is not rewritten.
- 2026-11-26, `timing` (rejected): no shared pattern (1 Tab Viewer feature with its alignment test, 1 old FX Link
  bug).
- 2026-11-24, `file-format` (accepted): before the Guitar Pro reader reads a new mark or value, Claude checks it on 1
  real file on the user's computer (never copied into git) and writes the test data from what that file has, not
  from a guess.
