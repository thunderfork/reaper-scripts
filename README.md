# Thunderfork Scripts

Scripts for playing live and for studio work with REAPER, installed and updated with ReaPack:

- **Chart Cue:** shows your PDF charts and turns and scrolls the pages while the song plays (Windows only).
- **Segue:** a setlist player: plays your songs (regions) in the order of your show, with stops and pauses.
- **MIDI Pilot:** writes the MIDI for amp modelers (Quad Cortex, Line 6 Helix / HX): presets, scenes, pedals.
- **FX Link:** links plugins across tracks: move a knob in one, and the same knob moves in the others.
- **Session Prep:** cleans up the tracks of a multitrack from a client: names, colors, folders, L / R pans, silent and fake stereo tracks.
<!-- SFX Drop: hidden until its release
- **SFX Drop:** puts impacts, risers, drops and atmospheres from your library exactly on the beat of your backing tracks.
-->
- **Mono Merge:** joins 2 mono items (for example Kick In and Kick Out) into 1 stereo file.
- **Tab Viewer:** shows a Guitar Pro tab of your guitar or bass part on the bars of the song, and follows it while the song plays. Its Detection tab turns the bass notes into markers, to learn the part.

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

# Session Prep

Session Prep cleans up the tracks of a multitrack that you got from a client, in one step.

- **Scan** reads the selected tracks (or all) and shows a preview: the old name, the new name, the folder and notes. Nothing changes until you click **Apply**; one Ctrl+Z undoes everything.
- **Names from rules:** a built-in list of short names (kik, sn, oh, gtr, vox...) becomes Kick, Snare, OH, Gtr, Vox; words like In, Out, Top, L, R and numbers stay. "Audio 1_", track numbers, ".wav" and a shared prefix or suffix go.
- **Colors and folders:** each rule has a color and a folder; Apply puts the tracks in folders in the order of the rules.
- **Pan, M and S** on each row: the Pan button starts at L or R from the name ("OH L", "Gtr 1 R") and cycles L, C, R, -; M and S mute and solo the track at once, as in REAPER. **Checks:** empty, silent, fake stereo and one silent side (a Mono button fixes it).
- **Scan all** reads the whole project, whatever is selected.
- **Studio order and names:** drums first (kick, snare, hats, toms, overheads, room), then percussion, bass, guitars, keys, strings, brass, vocals; change the folder order in the Rules tab (or use the "Vocals first" preset). A spacer above each folder (optional). Colors are optional (off by default; SWS Auto Color wins).
- **Client projects:** pans that are already set are kept; armed tracks are disarmed; empty tracks can be deleted; an optional pan width (off: hard L / R).
- **Engineering:** each FX return has its own source (the tracks or the folder), send level and output (the master, a folder or a bus: Drum Crush goes into the drum folder); a polarity button per track (Snare Btm flips by default); a file check (a sample rate that is not the project's, a later start); click / guide never reach the mix; overdubs join their folder later; Kick In, Kick Out, Kick Sub in order.
- **Buses tab:** Instrument Bus (the music), Vocal Bus (lead vocal, BVs) and Lead Bus (lead guitar, lead synth), each optional with its own color and members: the members are routed to the bus track, so one fader (and one FX chain) controls them. The FX returns are here too.
- **Capital letters** for the new names, folders and buses (All by default; or folders and buses, buses only, none).
- **No double prep:** a prepped track is left out of the next Scan (Ctrl+Z of the Apply frees it); later overdubs are scanned alone.
- **FX Chains tab:** an FX chain for each folder and bus (Folder FX) and each track name (Track FX). **FX returns** (Buses tab): Room Verb, Hall Verb, Delay, Drum Crush with post-fader sends from the folders you tick (off by default).
- **Gain staging** (off by default): sets the item gain of each track to a target level (default -18 dBFS RMS, peak limit -6 dBFS); change any value before Apply.
- **Presets** of rules: edit, copy, export and import them. Folders, the pans and the audio check can each be turned off.

Install with ReaPack (search "Session Prep"), then run "Script: Session Prep.lua". Needs ReaImGui 0.9.3 or newer.

Session Prep saves nothing in the project; its presets and settings are saved on this computer.

<!-- SFX Drop: hidden until its release
# SFX Drop

SFX Drop puts sound effects from your library (impacts, risers, drops, atmospheres) on the beat of your backing tracks. No nudging.

- **Hit points:** SFX Drop reads each sound and finds the moment that must land on the beat: the start of an impact (the silence before it is skipped), the peak of a riser.
- **Your library:** choose a folder in Settings; the type of each sound comes from its folder and file name (Impacts, Risers, Drops, Atmos, Other). Search, filter by type, and click a column title to sort.
- **Insert** at the edit cursor, at the nearest bar line, or at the start of each region. Double-click a sound or press Enter. One Ctrl+Z undoes it.
- **Tracks:** each sound goes on the track of its type in an "FX" folder; SFX Drop makes the tracks when they are missing.
- **Clean items:** trim silence and short fades (both optional).
- **Check the show:** one click lists missing files, sounds that are only in your library (Copy into the project), other sample rates and effects that ring into the next song (Cut).
- **FX output:** the FX folder plays through the master or its own hardware outputs (a separate FX feed to FOH).
- **Vary:** an insert at several places uses a different sound of the same folder each time.
- **Copy into the project** (optional, asked at the first start): each sound is copied into the project folder, so the show runs on any computer; a warning above a size (500 MB) and a Clean up for unused copies. Pause or stop the library scan at any time.
- **Your own hit point:** right-click a sound to pick the start or the loudest point, or move an inserted item by ear and let SFX Drop learn it.
- **Preview** a sound (needs the free SWS extension).
- **Soundcheck** tab: builds a new "Soundcheck" track after the last song from a source track (for example your stereo backing track) or a folder of stems: areas of different level, from quiet to loud, then an impacts zone with each impact and bass drop repeated (4x by default). You set the full length; Find areas shows the plan first; 1 Ctrl+Z undoes a build.
- **Find spots** (Spots tab): reads your song bar by bar and suggests where a riser and an impact (quiet to loud), a drop (loud to quiet) or an atmosphere (a quiet part) fits; the spots are grouped by region; choose the types to add and words for the sounds ("boom, explosion"); tick the spots, pick the sounds, insert them all with one click.
- **Favourites:** star your best sounds; they come first everywhere.
- **Riser length:** pick 1, 2, 4 or 8 bars and the risers of that length come first. A Bars column shows each sound's length in bars.
- **Levels** (optional): every impact, riser, drop and atmosphere at its own level, by LUFS or by peak.

Install with ReaPack (search "SFX Drop"), then run "Script: SFX Drop.lua". Needs ReaImGui 0.9.3 or newer.

SFX Drop saves only its Soundcheck list in the project; its settings and its library index are saved on this computer.
-->

# Mono Merge

Mono Merge joins 2 mono items into 1 stereo file. Select the 2 items and run the action. No window.

- **Left and right:** the item on the top track becomes left, the other one right. On 1 track, the earlier item is left.
- **2 actions:** "make stereo (with edits)" uses what you hear (trims, fades, volume, take FX). "make stereo (raw files)" uses the full original files, with their start aligned.
- **The result:** a new track below, named after the common part of the names ("Kick In" + "Kick Out" = "Kick"). The 2 mono items are muted. One Ctrl+Z undoes it all.
- The shorter side gets silence. REAPER's own glue makes the new file (fast; file name and format from REAPER's glue settings).

Install with ReaPack (search "Mono Merge"), then run "Script: Mono Merge.lua". No extensions needed.

Mono Merge saves nothing in the project or on this computer.

# Tab Viewer

Tab Viewer shows a Guitar Pro tab inside REAPER, on the bars of your song, and follows it while the song plays.

- **Open a tab:** .gp (Guitar Pro 7 / 8), .gpx (6), .gp5, .gp4 and .gp3. Pick the guitar or bass track; you see its tuning and capo. Each region can have its own tab, and the window shows the tab where the song plays.
- **As Guitar Pro draws it:** note lengths, rests, triplets, ties, hammer-ons, slides, bends, vibrato, palm mutes, harmonics, dead notes, chord names, section names, tempo marks, time signatures and repeats with their endings (1. 2.).
- **On the song:** a blue line follows playback; click a bar to play from there. Find tempo puts REAPER's tempo and bars on the song, from the tab or from an audio track.
- **Practise:** Shift+click a bar to loop it, and play slower (pitch kept).
- **Fix the tab:** select a note and type a fret, move it, change its length, or add new notes; your fixes are green and saved in the project (the file never changes). Right-click a bar to correct its time signature.
- **Your layout:** your own line breaks (& and Ctrl+Enter, as in Guitar Pro) and a fixed number of bars per line.
- **Detection tab:** the bass notes as markers (or text items on a "Notes" track) to learn the part: "Import to list" takes them from the tab, or "Find notes" listens to a separated bass track (no tab needed; the found notes then show as a tab too). Check the list, then Write; the note names fit the key, high notes get their string and fret. Export to MIDI for Guitar Pro.

Install with ReaPack (search "Tab Viewer"), then run "Script: Tab Viewer.lua". Needs ReaImGui 0.9.3 or newer.

Tab Viewer saves its tabs, fixes, layout and the Notes list in the project, and a copy of each tab in a "Tabs" folder next to the project file; its settings are saved on this computer.

## Zips

Each script also has a zip on the [Releases](https://github.com/thunderfork/reaper-scripts/releases) page (Chart Cue, Segue, MIDI Pilot, FX Link, Session Prep, Tab Viewer): unzip it, copy its .lua files into your REAPER `Scripts` folder, and load them with Actions > Show action list > New action > Load ReaScript....

## License

MIT. See [LICENSE](LICENSE).
