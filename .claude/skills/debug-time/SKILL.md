---
name: debug-time
description: A review round of Chart Cue, Segue, MIDI Pilot or FX Link before a commit or a release - 4 passes (developer, UI/UX, musician, engineer), a cross-review, feedback, fixes and a check of the fixes. Use when the user says "debug time" (or asks for a debug / optimize / review round).
---

# Debug time

A review of the script(s) that changed: the code, its Help and tooltips, and the documents (README.md, PLAN.md, the
folder CLAUDE.md). The user does not read code: report in plain words, with what they will see.

## 1. Scope (decide first, it sets the cost)

- Normal round: the changes since the last review or release (`git diff --stat <tag>..`, `git log`), plus the code
  around each change (the callers, the data it reads and writes). Read those parts, not the whole file.
- Full round: the whole file, in parts. Only before a major release (x.0) or when the user asks for "full".
- Segue and Chart Cue share `Setlist` and `UI.draw_now_view`: a change there, check the other script too.
- `.\tools\check.ps1` and `.\tools\test.ps1 -Script "<name>"` (quiet: they show only problems).
- The `help-sync` search for the changed names.

## 2. Pass 1: senior developer

- Bugs: state not reset (project switch, mode change, removed items), copies that miss fields, states not handled
  (playing, paused, stopped, empty lists, hidden tabs; Chart Cue: locked, performance mode, part 2).
- Per-frame cost (CLAUDE.md "Performance"): scans, allocations, repeated calculations, file access.
- Saved data: new keys written only when used; parse and serialize symmetric.
- ReaImGui: pushes and pops paired, End only after a successful Begin, popups in the same ID stack.
- Comments, names and constants that no longer match the feature.

## 3. Pass 2: senior UI/UX designer

- Texts: Help, tooltips, headings, messages, menu items: wrong, old or inconsistent; the same word for the same
  thing; the "?" texts say where a setting is saved.
- Layout: wrapping labels, duplicate names, controls in the wrong section, options split over 2 places.
- Behaviour: every optional feature can be turned off; dangerous actions have an undo or a question; the same
  look as Chart Cue.

## 4. Pass 3: pro musician, pass 4: studio / live engineer (by script)

- Chart Cue and Segue (used on stage): what goes wrong under stress (a wrong click, a hidden warning, a step that
  needs reading), what the player must see at a glance.
- MIDI Pilot (a preparation tool, never live): the speed of preparation, things left in a show project by mistake
  (Scene tests, muted items), MIDI timing and order, routing (outputs, channels), what REAPER really plays, undo
  steps and side effects on the user's own MIDI and tracks.

## 5. Cross-review and feedback

Merge the 4 lists, settle conflicts, sort by risk: bugs, then texts, then visible changes. Give 1 numbered list in
plain words (what is wrong, what the user notices, the fix), in a question window. Visible changes need the user's
answer (CLAUDE.md visible-change gate); bugs, texts and clean-ups can be fixed after a "go".

## 6. Fix and check the fixes

CLAUDE.md editing and patch rules; a test for each fixed bug when practical; deploy. Then check only the places
that the fixes touched (new names, missed callers, broken pairs), and run check and test again. Update PLAN.md
(history, open items) and the folder CLAUDE.md when they are out of date.

## 7. Report

A short summary, the manual tests in a question window, then the commit choice (commit and push, commit only, not
yet). For Chart Cue, offer the UI test first when menus, tabs or views changed (`ui-test`).
