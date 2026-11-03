# Chart Cue development

Chart Cue is a Windows-only REAPER Lua/ReaImGui script for displaying and
scrolling PDF charts during playback.

Main file: `Chart Cue/Chart Cue.lua` (the `Chart Cue` folder is the ReaPack category; keep the scripts there).

## Working with me

- I do not read code. I decide what Chart Cue looks like and how it behaves (GUI and taste);
  you decide the technical details.
- Before a change, explain in plain words what I will see or notice, and ask me only about
  visible behaviour, layout and wording. Do not show diffs or code unless I ask.
- Ask me before any change to what is saved in my projects or settings, or before removing
  a feature or a control.
- After editing, list only the functions changed, and the manual test I should do in REAPER.
- Commit only when I ask.

## Editing rules

- Never output or rewrite the entire `Chart Cue.lua` file.
- Make the smallest focused change possible.
- Preserve the existing architecture, naming style, and user-facing behaviour.
- Do not change user-facing behaviour unless explicitly requested.
- Do not introduce external dependencies without asking.
- Keep the files' LF line endings (core.autocrlf can turn them into CRLF).

## Saved data (compatibility)

- Do not change the format of the project data (ExtState "ChartCue"/"cfg") or existing
  settings.ini keys. Add new keys only, with defaults.
- Write a new project key only when it differs from its default: Chart Cue compares the saved
  text to tell "Save as" from "Open another project".
- Keep reading and writing old project keys unchanged (e.g. `fixed_start`), for the same reason.
- A settings.ini key that nothing reads may be removed, with my approval.

## REAPER/Lua constraints

- Target REAPER's embedded Lua runtime on Windows (Lua 5.4).
- Use only `reaper.*` APIs unless explicitly requested otherwise.
- Do not assume external Lua libraries are installed.
- Preserve REAPER-compatible path handling.
- Do not use `io.*` or `os.*` unless the existing code already requires it or I explicitly request it.

## Architecture

- `CFG`: constants, paths, and defaults.
- `S`: global settings persisted in `settings.ini`.
- `R`: volatile runtime state.
- `P`: per-project configuration stored in the REAPER project.
- `PDF`: PDF info, rendering, cache, and page images.
- `Project`: regions, markers, library, and project configuration.
- `UI`: ReaImGui interface and main deferred loop.
- `Nav`: page, scroll, zoom, and autoscroll logic.
- `Midi`: MIDI input and CC handling.

Do not move state between `CFG`, `S`, `R`, and `P` without asking.

## Performance rules

- The UI update loop runs every frame; treat it as hot code.
- Do not allocate tables, concatenate display strings, sort lists, scan folders, or query the filesystem every frame unless unavoidable.
  (Short labels with live values, such as "Page 3 / 12", are fine; cache what does not change between frames.)
- Cache stable labels, formatted strings, directory listings, and lookup tables outside the frame loop.
- Invalidate caches explicitly when their source data changes.
- Poll background PDF jobs at most every 100 ms.

## Verification

- After editing, run `.\check.ps1` before deploying. It must end with "Syntax and globals OK":
  1. syntax (`luac -p`, Lua 5.4.6 from winget DEVCOM.Lua),
  2. undefined globals (from the `luac -l` listing; allowed: standard Lua and `reaper`),
  3. Lua Language Server warnings (information only).
- Compare Language Server warnings with the known false alarms (19 "Need check nil" /
  "unknown|nil" warnings on 2026-11-02); look at every new one.
- For logic changes (navigation, autoscroll, project data, cache), also run `.\test.ps1`. It runs
  `tests\run.lua` in the portable test REAPER `C:\REAPERtest` (never the normal REAPER) and must
  end with "0 failed". Add a test for each fixed bug when practical.
- These checks do not replace a test in REAPER.
- Ensure ReaImGui calls remain valid in their intended UI/deferred-loop context.
- Do not claim a change is tested unless I have tested it in REAPER.
- If a change affects rendering, scrolling, MIDI, caching, or project state, state the manual test I should perform.

## Deployment

- Development copy: `Chart Cue/Chart Cue.lua` in this repository, and the action scripts
  `Chart Cue - Next page.lua`, `Chart Cue - Previous page.lua`, `Chart Cue - Toggle performance mode.lua`
  in the same folder.
- Deploy with:

```powershell
.\deploy.ps1
```

- Deployed copy: `%APPDATA%\REAPER\Scripts\thunderfork\Chart Cue\` (the ReaPack install; the REAPER
  actions run this copy), else `%APPDATA%\REAPER\Scripts\` when ReaPack has not installed it.
- Never move, rename, or edit by hand (Claude must not touch it):
  `%APPDATA%\REAPER\Scripts\Chart Cue`

That folder contains `settings.ini`, cache, `tmp`, and `autostart.lua`; the script itself writes them.

## Other files

- `PLAN.md`: done work, open items and the release checklist.
- `README.md`: for other users. `check.ps1` and `.luarc.json`: the static checks.
- `LICENSE` (MIT). `release.ps1`: makes `release\Chart-Cue-<version>.zip` (git-ignored).
- `.github/workflows/reapack-index.yml`: GitHub builds `index.xml` (the ReaPack repository
  file) after each push to main. Do not edit `index.xml` by hand.

## Releasing a version

1. Run the release checklist in PLAN.md (in REAPER).
2. Raise `@version` and `CFG.VERSION` together; write 1-3 user-facing `@changelog` lines.
3. Commit and push (when I ask). GitHub updates `index.xml`; ReaPack users get the update.
4. `.\release.ps1`, then attach the zip to a GitHub Release with the same version.
