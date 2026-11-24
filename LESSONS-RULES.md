# Rules from lessons

Loaded in every session from `CLAUDE.md`. The entries behind these rules are in `LESSONS.md`. 1 line per accepted
(or rejected) stronger fix, with its date and cause tag; the session start checks each tag against this file.

- 2026-11-17, `stale-state` (accepted): each script that keeps data from a project (a scan, a list, a cache) has a
  test "another project": the data is cleared or not used after a project switch or File > Open in the same tab.
  Done: Session Prep, SFX Drop (spots). To add: Chart Cue, Segue, MIDI Pilot, FX Link (PLAN.md, Open now).
- 2026-11-17, `saved-data` (accepted): every name field checks an empty or a taken name when you finish typing (a
  step in the `new-feature` skill).
- 2026-11-17, `audio-measure` (accepted): every audio measurement (a level, a peak, a verdict, a hit point) has a
  test with a generated WAV file, not only with numbers. Done: Session Prep (sine_wav in `tests\sessionprep.lua`).
  To add: SFX Drop (before its release, PLAN.md).
- 2026-11-24, `file-format` (accepted): before the Guitar Pro reader reads a new mark or value, Claude checks it on 1
  real file on the user's computer (never copied into git) and writes the test data from what that file has, not
  from a guess.
