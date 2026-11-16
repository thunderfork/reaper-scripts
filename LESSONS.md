# Lessons

The log of the self-improvement routine (`lessons` skill). 1 entry per escaped bug: a bug that the user found, a
failed manual test, or a `debug-time` finding in committed code. Newest first.

## Tags

- `stale-state`: data or a cache is not cleared or read again after its source changes (project switch, rename, undo).
- `imgui-pairing`: a Begin / End or Push / Pop that does not match, or an ImGui call outside its frame.
- `imgui-input`: a click, key or drag that reaches the wrong control, or that a control loses.
- `saved-data`: a setting or project value that is lost, cut or written wrong.
- `path`: file and folder names (spaces, non-Latin letters, missing files).
- `timing`: a value read too early or too late (plugins, playback, REAPER's own updates).
- `small-window`: a layout that breaks at a small or unusual window size.
- `text`: a Help, tooltip or notice text that is wrong or out of date.
- `audio-measure`: a level, peak or verdict read from the audio that is wrong (sample rate, sparse reads, channels).
- `routing`: a track's role (return, bus, instrument) or its sends / outputs not taken into account.
- `per-frame`: work in the UI loop that should be cached (text cuts, string building, scans).
- `naming`: a name rule or match that gives the wrong new name.

## Rules from lessons

- 2026-11-17, stale-state (accepted): each script that keeps data from a project (a scan, a list, a cache) has a test
  "another project": the data is cleared or not used after a project switch or File > Open in the same tab.
  Done: Session Prep, SFX Drop (spots). To add: Chart Cue, Segue, MIDI Pilot, FX Link (PLAN.md).
- 2026-11-17, saved-data (accepted): every name field checks an empty or a taken name when you finish typing (a step
  in the new-feature skill).
- 2026-11-17, audio-measure (accepted): every audio measurement (a level, a peak, a verdict, a hit point) has a test
  with a generated WAV file, not only with numbers. Done: Session Prep (sine_wav in tests\sessionprep.lua). To add:
  SFX Drop (before its release, PLAN.md).

## Entries

Format:

```
YYYY-MM-DD | Script | tag | what the user saw
  Cause: ...
  Why the tests missed it: ...
  Test: "<test name>" (tests\<file>.lua), failed before the fix | no test possible: <reason>
  Other scripts: searched, <result>
  Status: fixed, not confirmed | confirmed
```

```
2026-11-17 | Session Prep | audio-measure | gain staging missed a short loud hit: the peak read 39 dB too low
  Cause: the peak came from the fast audio check (about 11 s of each track, in parts).
  Why the tests missed it: no test had a short hit between 2 reads.
  Test: "gain staging: the peak is exact (a short hit between 2 reads is found)" (tests\sessionprep.lua), failed before the fix
  Other scripts: searched; SFX Drop reads its peaks from the peak files already (Lib.analyse).
  Status: fixed, not confirmed

2026-11-17 | Session Prep | naming | "Electric Piano" became Gtr, "Acoustic Piano" became Ac Gtr
  Cause: the first rule with any matching word won; the Gtr rules come before Piano and have "electric", "acoustic".
  Why the tests missed it: no test had a keys name with a guitar word in it.
  Test: "a 2-word match wins: Electric Piano is Keys, Acoustic Piano is Piano (not Gtr / Ac Gtr)" (tests\sessionprep.lua), failed before the fix
  Other scripts: searched; no other script matches names to rules.
  Status: fixed, not confirmed

2026-11-17 | Session Prep | audio-measure | a hi-hat or cymbal track read "silent" (or far too quiet: gain too high)
  Cause: the audio check read at 11025 Hz, which cuts everything above 5.5 kHz.
  Why the tests missed it: the tests called Audio.verdict / Audio.rms with numbers, never with real audio.
  Test: "gain staging: a bright track (8 kHz, a hi-hat) is measured at its real level" (tests\sessionprep.lua), failed before the fix
  Other scripts: searched; SFX Drop reads at 2000 Hz (Find spots) and 500 Hz (Soundcheck): cymbal parts count too
    little there (PLAN.md open item, before the SFX Drop release).
  Status: fixed, not confirmed

2026-11-17 | Session Prep | routing | a client's reverb return (no items, only receives) was offered "Delete" as empty
  Cause: "empty" meant only "no items"; receives and FX were not looked at.
  Why the tests missed it: no test had a track with receives or FX and no items.
  Test: "an empty track with a receive or FX (a client's return) is not 'empty'" (tests\sessionprep.lua), failed before the fix
  Other scripts: searched; no other script deletes tracks.
  Status: fixed, not confirmed

2026-11-17 | Session Prep | stale-state | Apply after File > Open in the same tab made returns and buses in the new project
  Cause: the rows of the old scan were used without a check that their tracks still exist.
  Why the tests missed it: no test changed the project between Scan and Apply.
  Test: "Apply does nothing when the scanned tracks are gone (another project in the same tab)" (tests\sessionprep.lua), failed before the fix
  Other scripts: searched; SFX Drop clears its spots on a project switch (R.spot_proj); the others keep no scan.
  Status: fixed, not confirmed

2026-11-17 | Session Prep | saved-data | a return could get an empty name or the name of another return (their sends merged)
  Cause: the return name field had no check (the bus name field had one).
  Why the tests missed it: UI code; the tests do not reach it.
  Test: no test possible: the rename is in the window (manual test).
  Other scripts: searched; the bus name has the check already.
  Status: fixed, not confirmed

2026-11-17 | Session Prep | per-frame | the Rules tab cut every rule's match words letter by letter in every frame
  Cause: UI.trunc (not the cached UI.trunc_c) in the rule lines, the return names and the sends header.
  Why the tests missed it: no test measures the UI loop.
  Test: no test possible: UI loop speed.
  Other scripts: searched; MIDI Pilot (19) and FX Link (10) call UI.trunc in their UI too: check which are in lists
    (PLAN.md open item).
  Status: fixed, not confirmed
```

Earlier bugs, from PLAN.md and the git history (before this routine; no test data):

```
2026-11-13 | SFX Drop | stale-state | the found spots stayed after a project switch
  Status: confirmed (historic)

2026-11-11 | FX Link, Segue | small-window | an ImGui error in a very small window (the notice line)
  Status: confirmed (historic)

2026-11-10 | FX Link | timing | "differ" showed during a drag and after Match (plugins report late)
  Status: confirmed (historic)

2026-11-08 | MIDI Pilot | saved-data | names and lists lost their line breaks after a restart
  Status: confirmed (historic)

2026-11-08 | MIDI Pilot | imgui-input | the send and remove buttons of a song row did nothing
  Status: confirmed (historic)
```
