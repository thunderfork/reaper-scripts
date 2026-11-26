---
name: release
description: Commit, push and release the scripts of this repository (tools\scripts.psd1) (a new version on ReaPack, and a GitHub Release for each script with a new version). Use when the user says "push", "commit and push", "release", "publish" or names a version ("release 1.5"), or after "commit only" when they later say push.
---

# Release

This skill and the folder CLAUDE.md files (the tag and title of each script) are the release rules. A script that
is not released yet (`Released = $false`): the pre-push hook (`tools\publish-check.ps1`) stops a push that would
publish it. Use Bash for git and gh (PowerShell quoting breaks `gh --jq`); PowerShell only for the `.ps1` tools. Stop and report at the
first failure; never skip a step silently.

`gh` (GitHub CLI) is on the system PATH. If a shell says "gh: not found" (the editor started before
PATH was updated), use `"/c/Program Files/GitHub CLI/gh.exe"`, and tell the user that a restart of VS Code fixes it.

## 0. What is being released

- `git status` and `git log <last tag>..HEAD`: what is new. `tools\scripts.psd1` is the list of the scripts: the
  folder `Name`, the tag prefix `Tag` (tag = `<Tag>X.Y`, e.g. `tabviewer-v1.2`; Chart Cue: `vX.Y`), `Released`, and
  `Uses` (shared files: a change there is a change of that script too). Changed .lua files in a script's folder (or
  its `Uses`) = a new version of that script, each with its own GitHub Release; several can change in 1 commit.
  Only other files (CLAUDE.md, PLAN.md, README.md, tools, tests, .claude): commit and push without a
  version or a release, and say so.
- A commit that is already made (the user said "commit only" before): do not raise the version again.
- ReaPack links a version number to the FIRST commit where that number appears in the header. So a version
  that was already in an earlier commit (also a script committed before its first push) must get a new number when
  the file changed since, else ReaPack installs the old file (MIDI Pilot 0.1, 7 November 2026). After the push, check
  in index.xml that the new version's source URL has the commit of this push.

## 1. Version (only when the scripts changed and the version was not raised yet)

- `@version` and `CFG.VERSION` together: a patch step for fixes and text changes only (1.0 -> 1.0.1), a minor step
  for new features (1.4 -> 1.5), a major step only when the user says so.
- `@changelog`: 1-3 user-facing lines (what the user gets, plain words), replacing the old lines.
- `@provides`: every action script of the script's folder is listed.
- A first release: merge its branch into main (when it has one); `Released = $true` in `tools\scripts.psd1`;
  remove `@noindex` from its .lua files; show its README part (remove the `<!-- -->` around it). In the same commit,
  so the publish check passes.
- PLAN.md: the new version in the Handoff's "Versions" line; remove the "Open now" items that this release finished.
- Each other script: the same steps in its own file (its own version), each with its own GitHub Release.

## 2. Checks

- `.\tools\check.ps1 -All` ("Syntax and globals OK, all scripts", no new warnings), `.\tools\test.ps1` (all
  scripts, "0 failed"),
  after the version change (step 1), so the pre-commit hook finds them passed on these files and does not run them
  again (`tools\stamp.ps1`).
- This step replaces the global `checkup` before a push:
  - every release with script changes: a normal `debug-time` round on the changes since the last release, unless
    one already ran after the last script change;
  - a major release (x.0): the full `checkup` instead (step 1 = a full `debug-time` round; step 2 = `simplify`
    + `check.ps1`; then `review` and `housekeeping`).
  - A push with only docs, tools or skills: no round.
- The escaped-bug count since the last release (the project `lessons` skill, "Before a release"), in 1 line.
- When menus, popups, tabs or views changed since the last UI test: ask for the UI test (`ui-test` skill).
- `.\tools\deploy.ps1`.
- The global security-review skill on the changes since the last release (the scripts are public on ReaPack): file
  paths, process calls (`os.execute`, `io.popen`, `ExecProcess`), downloads, text from outside used in a command.
  A finding: fix it before the push, or ask the user.

## 3. Commit and push

- `git add -A`, `git commit -m "<Name> X.Y: <short>" -m "<details>" -m "Co-Authored-By: ..."`
  (several scripts: "Chart Cue X.Y and Segue X.Y: ...") (never a message file: BOM). Several finished changes since
  the last commit: 1 commit for each change group (CLAUDE.md "Git"), the version change in the last one.
- `git push`.

## 4. ReaPack index

- `gh run list --limit 3`: wait for the "ReaPack index" run of this push (`gh run watch <id>` or check
  again); it must succeed, else ReaPack users do not get the update. On failure: `gh run view <id> --log`.
- `git pull` (the workflow commits the new `index.xml`).

## 5. GitHub Release

For each script with a new version:
- `.\tools\release.ps1 -Script "<Name>"` (makes `release\<Name with - for spaces>-X.Y.zip`, with its `Uses` files;
  it prints the path).
- `gh release create <Tag>X.Y "<the zip>" --target main --title "<Name> X.Y" --notes "<its changelog lines>"`
  (`Name` and `Tag` from `tools\scripts.psd1`; e.g. `tabviewer-v1.2`, "Tab Viewer 1.2"; Chart Cue: `v1.8`).
- Check: `gh release view <tag>`.

## 6. Report

The commit, the workflow result (the new versions in index.xml), the release link; what ReaPack users get.
Plain words.
