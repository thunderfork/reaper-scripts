---
name: housekeeping
description: Read-only audit of the repository (everything except the scripts) - old or duplicate files, useless tests, outdated docs, skills, the folder CLAUDE.md files - with a short report; nothing changes until the user approves. Use when the user says "housekeeping" or asks for a cleanup / tidy-up / audit of the project folder, and before a major release (x.0).
---

# Housekeeping

Read and follow the global skill first: `%USERPROFILE%\.claude\skills\housekeeping\SKILL.md` (what to find, the
report, after the approval). This project adds:

## Scope (instead of the global scope)

- In scope (may be changed after approval): README.md, PLAN.md, LESSONS.md, LESSONS-RULES.md, the root and folder CLAUDE.md files,
  `.claude/skills/`, `tests/*.lua`, `tools/ui-test.lua`, `tools/known-warnings.txt`, `.luarc.json`, `.gitignore`.
  A change to a test, ui-test.lua or .luarc.json: run check.ps1 and the tests after it.
- Change only after an explicit yes for each file: the scripts (every `.lua` file in a script folder, also
  the shared files; the list: `tools\scripts.psd1`), `tools/*.ps1`,
  `.github/workflows/`, and Claude's memory folder. A script change follows CLAUDE.md (check, tests, deploy).
- Never change: `index.xml` (generated) and anything outside the repository (the deployed copies in
  `%APPDATA%\REAPER\Scripts\`, Chart Cue's data folder, the user's REAPER).

## Also find (added to the global list)

- The automatic checks of this project (first): `.\tools\check.ps1 -All` (the docs check, the publish check, the
  ImGui balance), `git status -sb`.
- Unused files: also search the name in `tools/*.ps1` (they copy by pattern) and the `@provides` lines.
  Git-ignored files (`release/`, `tests/result*.txt`) are generated, not unused.
- Release safety (highest risk): an unreleased script without `@noindex` in its header; the README describing a
  script that is not released.
- A rule written in 2 places also counts across the folder CLAUDE.md files.
- PLAN.md: the "Versions" line and "Last checkup" are current.

## After the approval (added)

LF line endings; check, tests and deploy after a script change. A commit with no `.lua` change is not a new version.
