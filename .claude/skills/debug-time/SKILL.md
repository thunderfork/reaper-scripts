---
name: debug-time
description: A review round of a script of this repository (tools\scripts.psd1) before a commit or a release - 1 combined pass for a small change, or 4 passes (developer, UI/UX, musician, engineer), a cross-review, feedback, fixes and a check of the fixes. Use when the user says "debug time" (or asks for a debug / optimize / review round).
---

# Debug time

A review of the script(s) that changed: the code, its Help and tooltips, and the documents (README.md, PLAN.md, the
folder CLAUDE.md). The user does not read code: report in plain words, with what they will see.

## 1. Scope (decide first, it sets the cost)

- Normal round: the changes since the last review or release (`git diff --stat <tag>..`, `git log`), plus the code
  around each change (the callers, the data it reads and writes). Read those parts, not the whole file.
- Full round: the whole file, in parts. Only before a major release (x.0) or when the user asks for "full".
- The passes: a small change (a fix, a text, 1 control): 1 combined pass with the points of passes 1-4 that the
  change touches. A release, a large change (CLAUDE.md) or "full": all the passes. In a `checkup`: only pass 1
  (the bugs); the checkup's `review` step does the UI/UX part.
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

## 4. Passes 3 and 4: the users of the script

1 pass for each user of the script in CLAUDE.md "Users" (stage, preparation, learning): what goes wrong for that
person in that situation. Also what REAPER really does to the tracks and MIDI, undo steps, and side effects on the
user's own tracks.

## 5. Cross-review and feedback

Merge the lists of the passes, settle conflicts, sort by risk: bugs, then texts, then visible changes. Give 1 numbered list in
plain words (what is wrong, what the user notices, the fix), in a question window. Visible changes need the user's
answer (CLAUDE.md visible-change gate); bugs, texts and clean-ups can be fixed after a "go".

## 6. Fix and check the fixes

CLAUDE.md editing and patch rules; a bug in committed code follows the `lessons` skill (a test that fails first,
the other scripts, an entry in LESSONS.md); deploy. Then check only the places
that the fixes touched (new names, missed callers, broken pairs), and run check and test again. Update PLAN.md
("Open now", the handoff) and the folder CLAUDE.md when they are out of date.

## 7. Report

A short summary and the manual tests in a question window (no commit question: the user says when to commit). For
Chart Cue, offer the UI test first when menus, tabs or views changed (`ui-test`).
