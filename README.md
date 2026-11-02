# Chart Cue

Chart Cue shows your sheet music or chord charts (PDF files) inside REAPER, and turns and scrolls the pages for you while the song plays.

Windows only.

## What it does

- **One PDF for each song.** Give a REAPER region the same name as a PDF, and Chart Cue opens that PDF when the song plays.
- **Page turns and scrolling during playback**, in one of 2 ways:
  - **Cue list:** play the song and press C at each page turn and S where the page must move. The cues are saved in the project, and no markers are added.
  - **Markers:** put `PDFPAGE 2` and `PDFSCROLL 50` markers in your project.
- **Turn pages early**, for example 1 beat before the page turn, so you can read ahead.
- **Stage-ready:**
  - Performance mode (only the page).
  - Lock mode (the page ignores the mouse and the keys during playback).
  - Page brightness for dark stages.
  - The last page stays on screen when a song has no PDF.
- **Control it your way:**
  - Keys.
  - The mouse wheel.
  - A MIDI knob, fader or encoder.
  - MIDI buttons for page turns and cues.
  - REAPER actions for foot pedals or keys, which work when the Chart Cue window is not active.
- **Portable projects:** the PDFs can be copied into the project folder, and the library, regions and cues are saved in the project.

## What you need

- REAPER 7 on Windows 10 or 11.
- **ReaImGui 0.9.3 or newer.** Install it with ReaPack: Extensions > ReaPack > Browse packages > search "ReaImGui" > Install, then restart REAPER.
- Nothing else. Chart Cue uses the PDF engine built into Windows. Poppler (`pdftoppm.exe`) is an optional second engine.

## Install with ReaPack (recommended: you get updates)

1. In REAPER, open Extensions > ReaPack > Import repositories...
2. Paste this link and click OK:
   `https://github.com/thunderfork/chart-cue/raw/main/index.xml`
3. Open Extensions > ReaPack > Browse packages, search "Chart Cue", right-click it > Install, and click OK.
4. In the Action List, run "Script: Chart Cue.lua". The 3 page-turn actions are installed too.

## Install from the zip

1. Download the zip from the [Releases](https://github.com/thunderfork/chart-cue/releases) page and unzip it.
2. Copy `Chart Cue.lua` into your REAPER `Scripts` folder. Options > Show REAPER resource path opens the folder that contains it.
3. Optional: copy the 3 files `Chart Cue - Next page.lua`, `Chart Cue - Previous page.lua` and `Chart Cue - Toggle performance mode.lua` into the same folder.
4. In REAPER, open Actions > Show action list > New action > Load ReaScript..., and load `Chart Cue.lua` and the optional files.
5. Run the action "Chart Cue".

To open Chart Cue automatically with your projects, use Settings > General > Open automatically.

## First steps

1. In the Library tab, click "Add PDF..." and choose a PDF.
2. Click the PDF in the list. The first page appears.
3. Optional: make a REAPER region with the same name as the PDF.
4. Optional: in the Cues tab, click "Use Cue list mode", play the song, and press C at each page turn.

The round "?" next to each heading explains its settings. The "?" at the end of the tab strip opens the help, which has a full guide.

## Settings and data

- **Your settings** are saved in `Scripts\Chart Cue\settings.ini`. The page cache is in `Scripts\Chart Cue\cache`.
- **The library, the region choices and the cues** are saved inside the REAPER project. Save the project after changes.

## License

MIT. See [LICENSE](LICENSE).
