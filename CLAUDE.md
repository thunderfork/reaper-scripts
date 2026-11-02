# Chart Cue development

Chart Cue is a Windows-only REAPER Lua/ReaImGui script for displaying and
scrolling PDF charts during playback.

Main file: Chart Cue.lua

## Editing rules

- Never output or rewrite the entire Chart Cue.lua file.
- Make the smallest focused change possible.
- Show a diff before applying non-trivial changes.
- Preserve the existing architecture and naming style.
- Do not change user-facing behaviour unless explicitly requested.
- After editing, list only the functions changed.

## Architecture

- `CFG`: constants, paths and defaults.
- `S`: global settings saved in settings.ini.
- `R`: runtime state.
- `P`: per-project configuration stored in the REAPER project.
- `PDF`: PDF info, rendering, cache and page images.
- `Project`: regions, markers, library, project configuration.
- `UI`: ReaImGui interface and main deferred loop.
- `Nav`: page, scroll, zoom and autoscroll logic.
- `Midi`: MIDI input and CC handling.

## Deployment

- The development copy is `Chart Cue.lua` in this repository.
- Deploy with:

```powershell
.\deploy.ps1
```

- The deployed copy belongs in:
  `C:\Users\ngkog\AppData\Roaming\REAPER\Scripts\Chart Cue.lua`
- Never move or rename:
  `C:\Users\ngkog\AppData\Roaming\REAPER\Scripts\Chart Cue`
- That folder contains settings.ini, cache, tmp and autostart.lua.

## Performance rules

- Avoid disk I/O in per-frame code unless necessary.
- Poll background PDF jobs at most every 100 ms.
- Cache strings, combo labels and tables rebuilt every frame.
- Do not rescan directories or the PDF library every frame.