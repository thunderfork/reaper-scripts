# Chart Cue

Chart Cue shows your sheet music or chord charts (PDF files) inside REAPER, and turns and scrolls the pages for you while the song plays.

Windows only. **Needs the free ReaImGui extension** (install it once with ReaPack, see below).

## What it does

- **One PDF for each song.** Give a REAPER region the same name as a PDF, and Chart Cue opens that PDF when the song plays.
- **2 PDFs for one song** (for example lyrics and a bass part): both are shown together, top and bottom or side by side, and each one turns and scrolls with its own cues.
- **Page turns and scrolling during playback**, in one of 2 ways:
  - **Cue list:** play the song and press C at each page turn and S where the page must move. The cues are saved in the project, and no markers are added.
  - **Markers:** put `PDFPAGE 2` and `PDFSCROLL 50` markers in your project.
- **Turn pages early**, for example 1 beat before the page turn, so you can read ahead.
- **Smooth or jump scrolling:** the page moves slowly between scroll points, or jumps to each one.
- **Pages on screen:** 1 page, 2 pages side by side (turn by 1 page or by 2, like a book), or continuous: scroll through the whole PDF without jumps. The next page can slide in at a page turn.
- **Setlist:** put the songs (regions) in the order of your show, without changing the timeline. Each song stops or goes on to the next one; add timed pauses, skip songs, keep several setlists (for example "Friday" and "Festival short"), and lock the list for the show. Play buttons and a "Next song" action for a foot pedal.
- **Page area:** the PDF, the setlist in large text (for shows without charts), or the setlist on top and the PDF below. Near the end of a song, the page shows the next song.
- **Notes on the pages:** short texts such as "repeat x2", with their own colour and size. The PDF file does not change.
- **Stage-ready:**
  - Performance mode (only the page).
  - Lock mode (the page ignores the mouse and the keys during playback).
  - Page brightness for dark stages, also with a toolbar button.
  - A thin countdown line before each automatic page turn, and a short flash at the turn.
  - The last page stays on screen when a song has no PDF.
  - Hide the toolbar items and tabs that you do not use.
- **Control it your way:**
  - Keys.
  - The mouse wheel.
  - A MIDI knob, fader or encoder.
  - MIDI buttons for page turns and cues.
  - REAPER actions for foot pedals, keys, MIDI buttons or OSC, which work when the Chart Cue window is not active. Settings > Control assigns them with one click.
- **Portable projects:** the PDFs can be copied into the project folder, and the library, regions and cues are saved in the project.
- **Folder sync:** Chart Cue remembers the folders you add PDFs from; one click adds new charts and updates changed ones.

## What you need

- REAPER 7 on Windows 10 or 11.
- **ReaImGui 0.9.3 or newer** (free, from the ReaTeam Extensions repository that ReaPack already includes):
  1. Extensions > ReaPack > Browse packages.
  2. Search "ReaImGui", right-click it > Install, and click OK.
  3. Restart REAPER.
  If it is missing, Chart Cue says so at start and can open ReaPack on the ReaImGui package for you.
- Nothing else. Chart Cue uses the PDF engine built into Windows. Poppler (`pdftoppm.exe`) is an optional second engine.

## Install with ReaPack (recommended: you get updates)

1. In REAPER, open Extensions > ReaPack > Import repositories...
2. Paste this link and click OK:
   `https://github.com/thunderfork/reaper-scripts/raw/main/index.xml`
3. Open Extensions > ReaPack > Browse packages, search "Chart Cue", right-click it > Install, and click OK.
4. In the Action List, run "Script: Chart Cue.lua". The 4 actions (next / previous page, performance mode, next song) are installed too.

## Install from the zip

1. Download the zip from the [Releases](https://github.com/thunderfork/reaper-scripts/releases) page and unzip it.
2. Copy `Chart Cue.lua` into your REAPER `Scripts` folder. Options > Show REAPER resource path opens the folder that contains it.
3. Optional: copy the 4 files `Chart Cue - Next page.lua`, `Chart Cue - Previous page.lua`, `Chart Cue - Toggle performance mode.lua` and `Chart Cue - Next song.lua` into the same folder.
4. In REAPER, open Actions > Show action list > New action > Load ReaScript..., and load `Chart Cue.lua` and the optional files.
5. Run the action "Script: Chart Cue.lua".

To open Chart Cue automatically with your projects, use Settings > General > Open automatically.

## First steps

1. In the Library tab, click "Add PDF..." and choose a PDF.
2. Click the PDF in the list. The first page appears.
3. Optional: make a REAPER region with the same name as the PDF.
4. Optional: in the Cues tab, click "Use Cue list mode", turn on "Record" (R), play the song, and press C at each page turn.
5. Optional: in the Setlist tab, click "Make a setlist", put the songs in order, and tick "Play in setlist order".

The round "?" next to each heading explains its settings. The "?" at the end of the tab strip opens the help, which has a full guide.

## Settings and data

- **Your settings** are saved in `Data\Chart Cue\settings.ini` in the REAPER resource folder (Options > Show REAPER resource path). The page cache is in `Data\Chart Cue\cache`; it keeps at most 1 GB (Settings > Appearance > Page quality > Cache limit).
- **The library, the region choices, the cues, the notes and the setlists** are saved inside the REAPER project. Save the project after changes.

## License

MIT. See [LICENSE](LICENSE).
