# Thunderfork Scripts

Scripts for playing live with REAPER, installed and updated with ReaPack:

- **Chart Cue:** shows your PDF charts and turns and scrolls the pages while the song plays (Windows only).
- **Segue:** a setlist player: plays your songs (regions) in the order of your show, with stops and pauses.
- **MIDI Pilot:** writes the MIDI for amp modelers (Quad Cortex, Line 6 Helix / HX): presets, scenes, pedals.
- **FX Link:** links plugins across tracks: move a knob in one, and the same knob moves in the others.

# Chart Cue

Chart Cue shows your sheet music or chord charts (PDF files) inside REAPER, and turns and scrolls the pages for you while the song plays.

Windows only. **Needs the free ReaImGui extension** (install it once with ReaPack, see below).

## What it does

- **One PDF for each song.** Give a REAPER region the same name as a PDF, and Chart Cue opens that PDF when the song plays.
- **Images too:** a PNG or JPG file (for example a photo of a chart from your phone), added with "Add PDF...", works like a PDF with 1 page. "Add from folder" takes only PDFs.
- **2 PDFs for one song** (for example lyrics and a bass part): both are shown together, top and bottom or side by side, and each one turns and scrolls with its own cues.
- **Page turns and scrolling during playback**, in one of 2 ways:
  - **Cue list:** play the song and press C at each page turn and S where the page must move. The cues are saved in the project, and no markers are added.
  - **Markers:** put `PDFPAGE 2` and `PDFSCROLL 50` markers in your project.
- **Turn pages early**, for example 1 beat before the page turn, so you can read ahead.
- **Smooth or jump scrolling:** the page moves slowly between scroll points, or jumps to each one.
- **Pages on screen:** 1 page, 2 pages side by side (turn by 1 page or by 2, like a book), or continuous: scroll through the whole PDF without jumps. The next page can slide in at a page turn.
- **Setlist:** put the songs (regions) in the order of your show, without changing the timeline. Each song stops or goes on to the next one; add timed pauses, skip songs, keep several setlists (for example "Friday" and "Festival short"), and lock the list for the show. Play buttons and a "Next song" action for a foot pedal.
- **Page area:** the PDF, the setlist in large text (for shows without charts), or the setlist on top and the PDF below. The setlist view shows the current song with its time left and a progress bar, the next song, and the time left in the set. Near the end of a song, the page shows the next song.
- **Exact stop:** at the end of a song with Stop, REAPER stops at the exact end, and no part of the next song is heard.
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
- **Folder sync:** Chart Cue remembers the folders you add PDFs from; choose 1 folder or all of them, and one click adds new charts and updates changed ones.

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

1. In the Library tab, click "+ Add" > "PDF..." and choose a PDF.
2. Click the PDF in the list. The first page appears.
3. Optional: make a REAPER region with the same name as the PDF.
4. Optional: in the Cues tab, click "Use Cue list mode", turn on "Record" (R), play the song, and press C at each page turn.
5. Optional: in the Setlist tab, click "Make a setlist", put the songs in order, and tick "Play in setlist order".

The round "?" next to each heading explains its settings. The "?" at the end of the tab strip opens the help, which has a full guide.

## Settings and data

- **Your settings** are saved in `Data\Chart Cue\settings.ini` in the REAPER resource folder (Options > Show REAPER resource path). The page cache is in `Data\Chart Cue\cache`; it keeps at most 1 GB (Settings > Appearance > Page quality > Cache limit).
- **The library, the region choices, the cues, the notes and the setlists** are saved inside the REAPER project. Save the project after changes.

# Segue

Segue is a separate, small script for a setlist only (no PDFs), with its own window and its own data. When Chart Cue is open and also plays the project in setlist order, Segue locks itself and asks which script controls the songs, so they never act twice.

- Plays the songs (regions) of your project in the order of your show. The timeline does not change.
- At the end of each song: Stop (press Play to go on) or Continue (the next song plays at once). Pauses between songs count down, then play the next song. Untick a song to skip it.
- More than 1 setlist in each project, Lock setlist, Undo (Ctrl+Z), and the play buttons.
- A large "now playing" area: the current song, the time left in it, the next song and the time left in the set.
- REAPER stops at the exact end of a song with Stop (Segue sets the loop points to the song while it plays, and puts yours back after it).
- The "Segue - Next song" action, for a key or a foot pedal.
- Open automatically (with every project that has a setlist) and Close with project, in the gear menu.
- Needs ReaImGui 0.9.3 or newer, like Chart Cue. It uses only REAPER and ReaImGui, so it can also work on macOS and Linux (not tested there).

Install with ReaPack, after you have imported the repository (see "Install with ReaPack" above): Extensions > ReaPack > Browse packages, search "Segue", right-click it > Install. Then run "Script: Segue.lua" in the Action List and click "Make a setlist". The gear button at the top right has the settings and the help.

Segue saves the setlists in the REAPER project, and its settings in REAPER's own settings (the window, the grip and the gear-menu options).

# MIDI Pilot

MIDI Pilot helps you prepare the MIDI for your amp modeler in REAPER: a Neural DSP Quad Cortex or Quad Cortex mini, or a Line 6 Helix, HX Stomp, HX Stomp XL or HX Effects (the Line 6 profiles are not tested on a unit yet). It writes normal MIDI on a track for each unit, and REAPER plays it without MIDI Pilot.

- **Presets:** each region is a song; choose its preset by name (3B = Song One). A second preset inside a song is possible.
- **Scenes by name:** a coloured timeline under each song, a scene list with positions, a Scene test, and scenes from marker names.
- **Lanes:** the 2 expression pedals of the Quad Cortex as pedal positions, with what they move in each preset; the unit's footswitches, tuner, tap tempo, Gig View and mode; ramps, swells and LFOs (Sine, Triangle, Square, Saw; the rate follows the tempo; the peaks can grow or shrink), each shown as 1 row that you can move, remove, copy and paste. Line 6: your own CCs in real units.
- **Set up songs:** each song gets its preset and first scene, so playback can start at any song.
- **Show overview** of all songs, and **Export MIDI**: 1 standard MIDI file for the show, or 1 per song.
- **Getting started:** a list of the first steps, ticked when each one is done.
- **Toolbar:** the device, previous / next song, the song, Preset and Scene at the cursor, Snap, Send state, Set up songs, Scene timelines and Export; hide any item, any tab or the whole toolbar.
- Adds follow REAPER's Snap. A search field and a sort menu for the Preset list. Back up and restore all settings in 1 file.
- Nudge, latency, a status bar, Light / Dark theme.
- Needs ReaImGui 0.9.3 or newer. It uses only REAPER and ReaImGui. Tested with a Quad Cortex mini.

Install with ReaPack (search "MIDI Pilot"), then run "Script: MIDI Pilot.lua" and click Settings (the gear) > Add device.

MIDI Pilot saves the devices, your preset and scene names and the pedal assignments in REAPER's own settings, and which track belongs to which device (and the export folder) in the project.

# FX Link

FX Link links plugins across tracks. Put instances of the same plugin (for example Pro-Q 3 on your 4 guitar tracks) in a link group: move a knob in one, and the same knob moves in all the others.

- **Exact** (every instance gets the same value) or **Relative** (every instance gets the same change and keeps its own setting).
- **All parameters**, or only the ones you pick: from a list with a search box, or with Learn (move the knobs that you want).
- **All except:** link everything but a few knobs (for example the output gain). Relative works in dB / ms / % when the plugin shows them.
- **Match:** make all plugins of a group equal to one, with 1 click. **Link bypass:** turn them off and on together.
- **Snapshots A / B** per group, an **out-of-sync** warning ("2 differ") and an activity light on each group.
- Plugins inside **FX Containers**; **Find again** for a plugin that went missing (for example after a track template); **Add from folder**.
- Add the focused plugin, the same plugin from all selected tracks, or every copy in the project. Turn each group on or off.
- **Show / Hide plugins:** open all plugin windows of a group at once. Click a group to select its tracks.
- Search, drag and sort the groups; foldable sections; 3 actions for keys (Show plugins, Toggle group, Group focused plugin on selected tracks); pause 1 plugin.
- **Open automatically** with projects that have groups, **Close with project**, Back up / Restore the settings.
- The links work while the FX Link window is open (docked is fine). Needs ReaImGui 0.9.3 or newer.

Install with ReaPack (search "FX Link"), then run "Script: FX Link.lua" and click "+ Add" next to Link groups.

FX Link saves the groups in the project, and its settings (theme, window, folded sections, the options in the gear menu) on this computer.

## Zips

Each script also has a zip on the [Releases](https://github.com/thunderfork/reaper-scripts/releases) page (Chart Cue, Segue, MIDI Pilot, FX Link): unzip it, copy its .lua files into your REAPER `Scripts` folder, and load them with Actions > Show action list > New action > Load ReaScript....

## License

MIT. See [LICENSE](LICENSE).
