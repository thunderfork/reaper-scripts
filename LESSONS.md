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
- `file-format`: a part of an outside file format (a mark, a sign, a version) that the script does not read.
- `edge-case`: a case of the input that the code does not handle (1 or 2 items, a repeat, the end of a line).
- `refactor`: a moved, renamed or removed name (a constant, a function, a field) that other code still reads.
- `imgui-value`: a ReaImGui call that gets a wrong kind of value (nil where its default is not what the code means).

The rules that came from these entries are in `LESSONS-RULES.md` (loaded in every session).

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
2026-11-26 | Tab Viewer | imgui-value | Find notes was grey (off) with no reason until Find tempo was clicked once
  Cause: ImGui.BeginDisabled(ctx, busy) with busy = nil (no Find tempo state yet: `R.tempo and ...` gives nil);
  ReaImGui takes a missing value as "disabled = true". After Find tempo the value was false, so the button worked.
  Why the tests missed it: the ReaImGui stand-in of the tests accepted any value in BeginDisabled.
  Test: the stand-in now fails when BeginDisabled gets anything but true or false (the whole pattern, every drawn
  control); "the tab draws (the UI/UX review of 25 November 2026)" (tests\notes.lua) draws before and after Find
  tempo, failed before the fix.
  Other scripts: searched every BeginDisabled call: all others get true or false.
  Status: fixed, not confirmed

2026-11-25 | Tab Viewer | edge-case | (debug-time) Undo in the Note Detection tab after Write did nothing, with no message
  Cause: List.undo takes back a Write, Clear or Export only while it is REAPER's last step (Undo_CanUndo2); with a
  newer REAPER step (an item moved after Write) it skipped it silently.
  Why the tests missed it: the test covered "undone in REAPER already" (silent is right there), not a newer step.
  Test: "undo: 1 undo for the list and Write ..." (tests\notes.lua), failed before the fix
  Other scripts: searched (Undo_CanUndo2): FX Link reads it only to notice an undo; Tempo.untry takes back its own try
  step silently (right: the next try or Set tempo replaces it)
  Status: confirmed

2026-11-25 | Tab Viewer | stale-state | (debug-time) a bar loop and a line loop at the same time: after both, repeat stayed on and the time selection was lost
  Cause: the Tab tab (Tabs.loop) and the Note Detection tab (UI.play_row) each save REAPER's repeat and time selection
  as "before". The 2nd loop saved the 1st one's as "before"; when the 1st ended first (Tab Viewer closes: the bar
  loop first), the 2nd gave back the loop's repeat and selection.
  Why the tests missed it: each loop had its own test; none had both loops on.
  Test: "a bar loop (Tab tab) and a line loop ..." (tests\tabviewer.lua), failed before the fix
  Other scripts: searched (GetSetRepeat): Chart Cue and Segue have 1 owner each, MIDI Pilot and SFX Drop none
  Status: confirmed

2026-11-24 | Tab Viewer | edge-case | Tab Viewer 1.1 stopped with a script error while it drew the tab ("field 'x'")
  Cause: a palm-mute run through a repeat that ends in a later pass of a bar (|: 1 2 :| all palm-muted): UI.tab_pm
  used that pass, which is not drawn and has no x. The case "back to the left" was handled, "on to the right" not.
  Why the tests missed it: the P.M. row was drawing code only; no test had a run into a later pass.
  Test: "P.M. row: ..." (tests\tabviewer.lua; Tabs.pm_span, a plain function now), failed before the fix
  Other scripts: no other script draws repeats as written
  Status: fixed, not confirmed

2026-11-24 | Tab Viewer | stale-state | (debug-time) a new time signature kept the loop and the selection of the old bar times
  Cause: Tabs.set_meter (and its Undo) changed the bar lengths without Tabs.loop_off / Tabs.unselect, as "<" / ">" do.
  Why the tests missed it: the new test did not have a loop on.
  Test: "your time signature: ..." (tests\tabviewer.lua), failed before the fix
  Other scripts: no other script changes bar lengths
  Status: confirmed

2026-11-24 | Tab Viewer | file-format | tremolo picking did not show on the bass of a real tab
  Cause: .gp writes the tremolo as a part of a quarter note ("1/2" = 8ths); the reader expected "1/8" = 8ths (a guess).
  Why the tests missed it: the made-up test used the same guess; no real file was checked first.
  Test: "playing marks: ..." (tests\tabviewer.lua), now "1/4"; checked on the user's real tab: 60 bass notes found
  Other scripts: only Guitar Pro.lua reads it
  Status: fixed, not confirmed

2026-11-24 | Tab Viewer | file-format | an ending of 2 bars: its 2nd bar played in the 2nd pass, the "2." bar was missing
  Cause: the file marks only the 1st bar of an ending; GP.order cleared the pass at the :|, so "2." looked like pass 1.
  Why the tests missed it: the made-up endings were all 1 bar long.
  Test: "repeats as written: ..." (tests\tabviewer.lua), written with the fix (the user's tab showed the failure)
  Other scripts: Note Detective uses the same GP.order: fixed with it
  Status: confirmed

2026-11-24 | Tab Viewer | edge-case | lines ended short of the right edge, or past it (a :| cut off)
  Cause: Tabs.layout stretched the repeat signs and time signatures too, and capped the stretch at 1.6 on every line.
  Why the tests missed it: no test checked the right end of a line.
  Test: "the tab on the window: ..." (tests\tabviewer.lua), 3 widths with repeat signs
  Other scripts: Note Detective has its own layout without repeat signs: not affected
  Status: confirmed

2026-11-24 | Tab Viewer | file-format | the section name showed as "<![CDATA[Solo]]>"
  Cause: the reader expected <Text><![CDATA[...]]></Text> with nothing between; the real file has line breaks.
  Why the tests missed it: the made-up XML had no spaces (written by Claude, not taken from a real file).
  Test: "repeats as written: ..." (tests\tabviewer.lua: "spaces and line breaks around the CDATA"), failed before
    the fix.
  Other scripts: searched; the track names use a strict pattern but show right on the real files (left).
  Status: fixed, not confirmed
```

```
2026-11-24 | Tab Viewer | edge-case | "/" (a triplet beat) did not work properly
  Cause: "/" kept each note as long as the gap to the next one, so 1 note on the beat stayed a quarter (no change),
    and a triplet beat was known only from its note places, so "/" again did nothing; 2 notes got a quarter and
    an 8th triplet, and the "3" waited for 2 beats.
  Why the tests missed it: the test used only a beat with 3 notes (the 1 case where it works); no test of 1 note,
    2 notes or "/" twice.
  Test: "\"/\" (lessons 24 November 2026): 1 note on the beat becomes a triplet 8th and back; 2 notes show the 3"
    (tests\tabviewer.lua), failed before the fix.
  Other scripts: searched, none has note lengths or triplets.
  Status: confirmed (the user, 24 November 2026)
```

```
2026-11-24 | Tab Viewer | imgui-input | a click on the tab, then a click on another place opened the note box, as if
  it was a double-click
  Cause: a single click on an empty place of a string opened the box of a new note (copied from Note Detective),
    and the double-click of a note did not check that both clicks were on the same place.
  Why the tests missed it: the click rule was inside the UI code (no test reaches it); the tests only checked the
    edits behind the box.
  Test: "a click on the tab: selects; only a double-click on the same place opens the box" (tests\tabviewer.lua);
    the rule is now the plain function Tabs.click (it did not exist before, so the test could not run on the old code).
  Other scripts: searched; Note Detective had the same (UI.draw_tab): changed the same way (the user's choice,
    24 November 2026; no test: its click rule is still in the UI code).
  Stronger fix (imgui-input, 2 entries): click rules into plain functions with a test; the user asked for the benefit
    (24 November 2026), not decided yet.
  Status: Tab Viewer confirmed (24 November 2026); Note Detective fixed, not confirmed
```

```
2026-11-23 | Tab Viewer | timing | after Set tempo with Beats from a track (a bass stem), the tab started at the
  first bass note: its 5 empty bars before the first note were left out, so the tab was late (from the tab: right)
  Cause: Find tempo makes the first beat with sound bar 1 of the song; Tabs.set_tempo put bar 1 of the tab on that
  bar, without the tab's empty bars before its first note. Fix: Tabs.start_bar (that bar less the empty bars; at
  least bar 1, with a notice).
  Why the tests missed it: no test for where the tab starts after Set tempo (only the tempo map was tested).
  Test: "Set tempo from a track: the tab's empty bars before its first note come before bar 1 of the song"
  (tests\tabviewer.lua), failed before the fix
  Other scripts: searched, Note Detective's import lines up the first note of the tab (Imp.start, list[1].q): right.
  Status: confirmed (the user, 23 November 2026)
```

```
2026-11-23 | Note Detective | refactor | Tempo and bars: a script error after Find tempo ("Note Detective.lua:3317:
  attempt to compare number with nil"), manual test 29 of segment 2d
  Cause: the move of the tempo code into the shared Tempo.lua removed CFG.BPM_MIN / CFG.BPM_MAX from Note
  Detective's CFG, but its Tempo and bars window still read them (the 1/2 and x2 buttons). Claude's search for the
  uses was anchored to the line start and missed the 2 uses inside the window code.
  Why the tests missed it: the tests never draw the window (UI code); the syntax and globals checks do not see a
  missing field of a table (CFG.X is nil, not an undefined global).
  Test: tools\check.ps1 step 2b "Undefined CFG names" (every CFG.NAME a file reads is set in it), a must-pass check
  for all scripts; failed before the fix with exactly these 2 names. The fix: TP.CFG.BPM_MIN / TP.CFG.BPM_MAX.
  Other scripts: the new check runs on all 9; no other gap (Mono Merge and Tempo.lua set their CFG in 1 block).
  Status: confirmed (the user, 23 November 2026)
```

```
2026-11-23 | Note Detective | audio-measure | Set tempo moved the audio to the wrong place (manual test 27 failed)
  Cause: the first bass note was found in the bleed before the bass (song 2: 56-63 dB below the loud parts, at
  0.035 s; the bass starts at 6.73 s). Dev 5 measured every moment against its own level (the onsets) or the last
  2 s (the pitch gate), so near-silence counted; Find notes found a "note" there too.
  Why the tests missed it: the generated test files have digital silence, no noise.
  Test: in "onsets: 1 per pluck; ..." noise 60 dB down before a note: no pluck, no note, Det.first_sound on the note
  (tests\notedetective.lua), failed before the fix.
  Fix: plucks (Det.onsets_of) and pitches (Det.analyse) only above the loud level of the whole item - 35 dB; Set tempo
  without a list uses Det.first_sound (the first 10 ms above that level). Song 2: the first found note 6.735 s, the
  first sound right; the notes found unchanged (86.3% with the grid).
  Other scripts: searched, only Note Detective uses this code (SFX Drop has its own hit point search, Lib.hit: not
  checked for noise).
  Status: fixed, not confirmed
```

```
2026-11-23 | Note Detective | timing | Import tab: the tab still did not line up with the song (other stems)
  Cause: Imp.bar1 chose the bar where the most tab notes matched found notes, and put bar 1 of the tab on that bar
  line of the grid. On other stems the found notes are poor, so the bar can be wrong, and the grid itself can be
  40-70 ms off the audio (Set tempo's bar 1).
  Why the tests missed it: they checked the bar on a perfect grid with clean found notes; no test of the exact time.
  Test: "import tab: the first note of the tab exactly on the first found note (lessons, 23 November 2026)"
  (tests\notedetective.lua), failed before the fix.
  Fix (the user's rule): Imp.start puts the first tab note exactly on the very first found note; the rest follows the
  project's quarter notes from there. The bar search (Imp.best) is removed.
  Other scripts: searched, no other script reads Guitar Pro files.
  Status: confirmed (the user, 23 November 2026)
```

```
2026-11-23 | Note Detective | stale-state | Import tab: after the fix below, the tab and the song still did not line up
  Cause: Imp.bar1 lined the tab up with all notes of the list; after a 1st (wrong) import those are the notes of that
  import, so a 2nd import matched them perfectly and landed on the same wrong bar (trial 8: measure 6, right: 2).
  Also: a grace note took its full length from the bar, so the rest of that bar came late (not in song 2).
  Why the tests missed it: the test lined up only with found notes; no test imported twice. No grace note in the score.
  Test: "import tab: bar 1 where the tab matches ..." (an import after a wrong one: not lined up, a yellow line; Undo:
  lined up again) and the grace note in the score of "import tab: the notes of a Guitar Pro score"; both failed first.
  Fix: only found notes count (not `man`); none: bar 1 of Set tempo or the edit cursor, and the window says "No found
  notes to line the tab up with". A grace note: no time, no note. Trial 8 (the whole flow in the test REAPER, song 2,
  1 tempo and Follow the song): the right bar; the tab about 40 ms before the found notes (Set tempo's bar 1).
  Other scripts: searched, no other script reads Guitar Pro files.
  Status: fixed, not confirmed
```

```
2026-11-23 | Note Detective | file-format | Import tab: the tab and the song did not line up
  Cause: Imp.bar1 put bar 1 of the tab on bar 1 of Set tempo, but that is lost when the script starts again; then on
  the bar of the first found note. A tab often starts with empty bars (song 2: the bass from bar 5), so the tab came
  4 bars late. Also bar 1 was not found again when another track was picked in the window.
  Why the tests missed it: the made-up score had a note in bar 1, and the check on song 2 compared notes, not the place.
  Test: "import tab: bar 1 where the tab matches the found notes best (a tab with empty bars first; lessons)" (tests\notedetective.lua), failed before the fix.
  Fix: Imp.best: the bar (within 8 of the guess) where the most tab notes start on a found note of the same pitch
  class; song 2 (trial 7d): the right bar, 695 of 981 notes, the next best 473.
  Other scripts: searched, no other script reads Guitar Pro files.
  Status: fixed, not confirmed
```

```
2026-11-23 | Note Detective | file-format | Import tab: the Guitar Pro repeat bars (the "%" sign) stayed empty
  Cause: Imp.notes read only the notes written in each bar; a bar with a repeat bar mark (SimileMark Simple, or
  FirstOfDouble / SecondOfDouble for 2 bars) has no notes of its own and plays the bar (or 2 bars) before it.
  Why the tests missed it: the check on the user's tab of song 2 had no such bar, and the made-up test score had none.
  Test: "import tab: the repeat bar marks (%) play the bar before, or the 2 bars before" (tests\notedetective.lua), failed before the fix.
  Fix: a bar with the mark plays the bar that played 1 (or 2) bars before it, in the played order (after the repeats).
  Other scripts: searched, no other script reads Guitar Pro files.
  Status: fixed, not confirmed
```

```
2026-11-23 | Note Detective | audio-measure | in the tab some notes were 1 16th early: beat 1 showed on 4a of the bar before
  Cause: Export.delay measured the common offset on the 16th grid and took it as "from 1/4 16th early to 3/4 late";
  notes found about 30% of a 16th early were taken as 70% late and moved almost a whole 16th earlier.
  Why the tests missed it: the earlier fix had a test with late notes only, none with early notes.
  Test: "export: notes that are all found a little early stay on their 16th, not 1 16th earlier (lessons, 23 November 2026)" (tests\notedetective.lua), failed before the fix.
  Fix: the fine offset on the 16th grid, then of it, 1 16th earlier and later, the one with the most notes on the
  beats. Song 2: 86.5% on the right 16th (as before). A 1st try (the 8th grid) failed the old mixed test: no.
  Other scripts: searched; no other script quantizes detected notes.
  Status: fixed, not confirmed

2026-11-23 | Note Detective | audio-measure | in Guitar Pro (the exported .mid) some notes were 1 16th note off
  Cause: the detection finds every start about 60 ms late (the pitch needs time); the export rounded to the nearest
  16th, so at 160 BPM (half a 16th = 47 ms) many notes went to the next 16th.
  Why the tests missed it: the export tests used exact times; no test had notes found late.
  Test: "export: notes that are all found late land on their own 16th (lessons, 23 November 2026)" (tests\notedetective.lua), failed before the fix;
  also "export: the notes of a WAV file land on their 8th notes". Fix: Export.delay (the common delay, measured on a
  circle, taken away before the rounding). Song 2: 70.9% -> 86.6% of the notes on the right 16th.
  Other scripts: searched; no other script quantizes detected notes.
  Status: fixed, not confirmed

2026-11-23 | Note Detective | audio-measure | 16 repeated 16th-note E's were 1 long E (in Guitar Pro)
  Cause: the detection splits the same pitch only at a clear attack 0.12 s or more after the note start; in the Moises
  stem a repeated note has a small dip and a small attack (song 2: median 4.6 dB and 0.86, against 2.4 dB and 0.59
  inside a held note), so the 2 overlap.
  Why the tests missed it: no test had repeated notes of the same pitch.
  Test: none kept: attack and dip splitting (trial 6) made a clean test pass but did not improve song 2 (64-66% either
  way), so it was taken out again. NOT FIXED. Next idea: the rhythm grid after Set tempo, measured on the song 2 score.
  Other scripts: not applicable.
  Status: open

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
