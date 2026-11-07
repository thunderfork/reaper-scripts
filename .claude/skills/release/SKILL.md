---
name: release
description: Commit, push and release Chart Cue, Segue and MIDI Pilot (a new version on ReaPack, and a GitHub Release for each script with a new version). Use when the user says "push", "commit and push", "release", "publish" or names a version ("release 1.5"), or after "commit only" when they later say push.
---

# Release

CLAUDE.md "Releasing a version" and "Git" are the rules; this is the order. Stop and report at the
first failure; never skip a step silently.

`gh` (GitHub CLI) is on the system PATH. If a shell says "gh: not found" (the editor started before
PATH was updated), use `& "C:\Program Files\GitHub CLI\gh.exe"` in PowerShell, and tell the user that a
restart of VS Code fixes it.

## 0. What is being released

- `git status` and `git log <last tag>..HEAD`: what is new. Scripts in `Chart Cue/` changed = a new
  Chart Cue version; scripts in `Segue/` changed = a new Segue version (both can change in one commit).
  Scripts in `MIDI Pilot/` changed = a new MIDI Pilot version (`@version` and `CFG.VERSION`), with its own GitHub
  Release (tag `midipilot-vX.Y`).
  Only other files (CLAUDE.md, PLAN.md, README.md, tools, tests, .claude): commit and push without a
  version or a release, and say so.
- A commit that is already made (the user said "commit only" before): do not raise the version again.
- ReaPack links a version number to the FIRST commit where that number appears in the header. So a version
  that was already in an earlier commit (also a script committed before its first push) must get a new number when
  the file changed since, else ReaPack installs the old file (MIDI Pilot 0.1, 7 November 2026). After the push, check
  in index.xml that the new version's source URL has the commit of this push.

## 1. Version (only when the scripts changed and the version was not raised yet)

- `@version` and `CFG.VERSION` together (minor step: 1.4 -> 1.5, unless the user says otherwise).
- `@changelog`: 1-3 user-facing lines (what the user gets, plain words), replacing the old lines.
- `@provides`: every action script of the script's folder is listed.
- PLAN.md: the history line of this version (Chart Cue: History; Segue: its own section).
- Segue and MIDI Pilot: the same steps in their own file (their own versions), each with its own GitHub Release.

## 2. Checks

- `.\tools\check.ps1` (must end with "Syntax and globals OK"), `.\tools\test.ps1` ("0 failed").
- When menus, popups, tabs or views changed since the last UI test: ask for the UI test (`ui-test` skill).
- `.\tools\deploy.ps1`.

## 3. Commit and push

- `git add -A`, `git commit -m "Chart Cue X.Y: <short>" -m "<details>" -m "Co-Authored-By: ..."`
  (with Segue: "Segue X.Y: ..." or "Chart Cue X.Y and Segue X.Y: ...")
  (never a message file: BOM).
- `git push`.

## 4. ReaPack index

- `gh run list --limit 3`: wait for the "ReaPack index" run of this push (`gh run watch <id>` or check
  again); it must succeed, else ReaPack users do not get the update. On failure: `gh run view <id> --log`.
- `git pull` (the workflow commits the new `index.xml`).

## 5. GitHub Release

For each script with a new version:
- `.\tools\release.ps1 -Script "<name>"` (makes `release\Chart-Cue-X.Y.zip`, `release\Segue-X.Y.zip` or
  `release\MIDI-Pilot-X.Y.zip`).
- Chart Cue: `gh release create vX.Y "release\Chart-Cue-X.Y.zip" --target main --title "Chart Cue X.Y" --notes "<changelog lines>"`.
- Segue: tag `segue-vX.Y`, title "Segue X.Y", the Segue zip. MIDI Pilot: tag `midipilot-vX.Y`, title "MIDI Pilot X.Y",
  the MIDI Pilot zip. Release notes: that script's changelog lines.
- Check: `gh release view <tag>`.

## 6. Report

The commit, the workflow result (the new versions in index.xml), the release link; what ReaPack users get.
Plain words.
