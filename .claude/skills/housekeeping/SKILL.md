---
name: housekeeping
description: Read-only audit of the repository (everything except the scripts) - old or duplicate files, useless tests, outdated docs, skills, the folder CLAUDE.md files - with a short report; nothing changes until the user approves. Use when the user says "housekeeping" or asks for a cleanup / tidy-up / audit of the project folder, and before a major release (x.0).
---

# Housekeeping

## Scope

- In scope (may be changed after approval): README.md, PLAN.md, LESSONS.md, LESSONS-RULES.md, the root and folder CLAUDE.md files,
  `.claude/skills/`, `tests/*.lua`, `tools/ui-test.lua`, `tools/known-warnings.txt`, `.luarc.json`, `.gitignore`.
  A change to a test, ui-test.lua or .luarc.json: run check.ps1 and the tests after it.
- Change only after an explicit yes for each file: the scripts (`Chart Cue/*.lua`, `Segue/*.lua`, `MIDI Pilot/*.lua`, `FX Link/*.lua`,
  `Session Prep/*.lua`, `SFX Drop/*.lua`, `Mono Merge/*.lua`, `Tab Viewer/*.lua`
  with the shared `Guitar Pro.lua` and `Tempo.lua`; the list: `tools\scripts.psd1`), `tools/*.ps1`,
  `.github/workflows/`, and Claude's memory folder. A script change follows CLAUDE.md (check, tests, deploy).
- Never change: `index.xml` (generated) and anything outside the repository (the deployed copies in
  `%APPDATA%\REAPER\Scripts\`, Chart Cue's data folder, the user's REAPER).

## What to find

1. Old, unused or duplicate files and folders. Before calling a file unused, search its name in `tools/*.ps1`
   (they copy by pattern), the `@provides` lines, `.github/workflows/`, `.gitignore`, the skills and the docs.
   Git-ignored files (`release/`, `tests/result*.txt`) are generated, not unused: list them apart.
2. Tests that test removed or renamed features, duplicates, placeholders.
3. Documents and skills that are wrong or out of date: paths, commands, versions, feature names, settings paths
   (the `help-sync` search), rules that contradict CLAUDE.md, a rule written in 2 places (CLAUDE.md, a folder
   CLAUDE.md, a skill, the memory: 1 place per rule).
4. Structure: files in the wrong folder, unclear names.
5. `LESSONS-RULES.md`: rules that no longer help (the `lessons` skill); rules only in LESSONS.md (not loaded); a
   rule that is true for every project or for REAPER in general (propose it for the global files). Project skills
   that copy a global skill instead of adding project steps. Rules in Claude's memory (they belong in a CLAUDE.md).
6. Release safety (highest risk): an unreleased script without `@noindex` in its header; commits that are not
   pushed (`git status -sb`); the README describing a script that is not released.
7. The docs check: every doc, skill and folder CLAUDE.md is in the list of `tools\docs-check.ps1`.
8. PLAN.md: only Handoff, Open now (numbered) and Later; no done work; the version table and "Last checkup" are
   current; "Open now" items that are done.
9. The global checks of the global `housekeeping` skill (privacy, the global files) apply too.

## Report (plain words, exact paths)

- A short project snapshot (2-3 lines).
- The findings, highest risk first: for each, the problem, where, the evidence (1 line), and the proposed change
  (with the replacement text when it is short).
- Deletions apart: each path, why it is unused, what was searched.
- A short plan: safe clean-ups, document updates, the user's decisions, things to leave.

Ask for the approval in a question window, with the findings in groups. Change nothing before the user approves. A tracked file is deleted only after an explicit yes for that file.

## After the approval

Only the approved changes; LF line endings; check.ps1 and the tests when a test or a tool reference changed;
check, tests and deploy after a script change. A commit
with no `.lua` change is not a new version.
