-- @description Note Detective: find the bass notes and write them as markers
-- @version 1.0
-- @author Nick Gkogkomitros
-- @license MIT
-- @noindex
-- @about
--   Note Detective - finds the notes of a separated bass track (a stem) and writes them as markers,
--   as text items on a "Notes" track, or both. For a player who learns the part in REAPER.
--   Review the list first: doubtful notes are yellow, a click plays from there, and a correction can go to all
--   the places with the same notes. The note names fit the key of the song.
--   Tempo and bars: finds the tempo of the song (from the metronome or the drums) and puts REAPER's bars on it, for
--   this song only. High notes get their string and fret ("E (A 7)"), fast runs the fingering with the fewest hand
--   moves (Standard, Drop D, Drop C, 5-string...). Export: a MIDI item and a .mid file (for Guitar Pro).
--   Requires: the free ReaImGui extension (ReaPack).
-- @provides
--   [nomain] ../Tab Viewer/Guitar Pro.lua > Guitar Pro.lua
--   [nomain] ../Tab Viewer/Tempo.lua > Tempo.lua
-- @changelog
--   First version.

-- MIT License
--
-- Copyright (c) 2026 Nick Gkogkomitros
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software
-- and associated documentation files (the "Software"), to deal in the Software without
-- restriction, including without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
-- BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local r = reaper

-- The shared files, next to this script (ReaPack installs copies; the tests hand them over): the Guitar Pro reader
-- (GP) and Tempo and bars (TP).
local GP, TP
do
  local test = rawget(_G, "NoteDetectiveTest") or {}
  local dir = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or ""
  local function load(name) return r.file_exists(dir .. name) and dofile(dir .. name) or nil end
  GP, TP = test.GP or load("Guitar Pro.lua"), test.TP or load("Tempo.lua")
  if not (GP and TP) then
    r.ShowMessageBox("Note Detective needs its files \"Guitar Pro.lua\" and \"Tempo.lua\" next to it. Install Note Detective again with ReaPack.", "Note Detective", 0)
    return
  end
end

---------------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------------
local CFG = {}
CFG.TITLE = "Note Detective"   -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.0"            -- keep equal to @version in the header
CFG.EXT = "Note Detective"     -- ExtState section (this computer) and the project data section
CFG.PEXT_KEY = "cfg"           -- the project data key
CFG.TAG = "P_EXT:NoteDetective" -- the mark on the Notes track and on its text items
CFG.TRACK = "Notes"            -- the name of the Notes track
CFG.DEFAULT_W, CFG.DEFAULT_H = 480, 720
CFG.WIN_EDGE = 6               -- floating window: width of the resize edges (inside the window), as in Chart Cue
CFG.WIN_GRIP = 22              -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 340, 300
CFG.FONT_SIZE = 14             -- the same sizes as Chart Cue
CFG.FONT_SIZE_BOLD = 15        -- section titles
CFG.TEXT_LIFT = 1              -- px the text is raised above the true centre in every control
CFG.CTRL_GAP = 8               -- between 2 controls side by side
CFG.SP_ROW, CFG.SP_EDGE, CFG.SP_PANEL = 7, 8, 4 -- spacing (pixels; the same gaps as Chart Cue)
CFG.ROW_H = 26
CFG.TB_ICON_W = 32             -- the gear and "?" in the toolbar
CFG.SETTINGS_BTN_W = 200       -- the buttons in the Settings menu
CFG.KEY_W, CFG.MODE_W, CFG.OUT_W = 120, 150, 200 -- the Key, Markers and Write dropdowns
CFG.COL_NUM_W, CFG.COL_BAR_W, CFG.COL_PLACES_W = 34, 52, 64 -- the columns of the list
CFG.NOTICE_SEC = 4             -- a notice at the bottom of the window shows this long
CFG.TIP_DELAY = 0.5            -- seconds on an item before its tooltip shows (as in Chart Cue)
CFG.TIP_WRAP_EM = 32           -- tooltip lines wrap at this many font sizes
CFG.UNDO_MAX = 50              -- the steps of the Undo button (the list)
CFG.MK_MAX = 3000              -- the kept IDs of written markers (the older ones are dropped)
-- The detection (the values of the trials of 23 November 2026)
CFG.SR, CFG.HOP = TP.CFG.SR, TP.CFG.HOP -- the bass is read at 4000 Hz; 1 frame every 10 ms (as Tempo and bars)
CFG.YIN_W, CFG.LAG0, CFG.LAG1 = 200, 8, 130 -- YIN: the window, and the lags (500 Hz down to 31 Hz)
CFG.YIN_THR, CFG.YIN_MAX = 0.15, 0.3 -- YIN: a sure pitch; a pitch at all
CFG.GATE_DB = 35               -- a frame this far below the loud parts is silence
CFG.ATTACK_GATE_DB = 20        -- the tuning: only from frames that are not this far below the loud parts
CFG.NOTE_MIN = 0.06            -- a shorter note is not a note
CFG.GLITCH = 0.2               -- s: a note this short, a 5th above the note around it, is a glitch (Det.glitches)
CFG.START_COMP = 0.03          -- the notes start this much earlier (the smoothing reports them late)
-- The onsets (Det.onsets_of; Dev 2 of the review of 23 November 2026; trial 9): the band flux in 5 ms frames
CFG.ON_STEP, CFG.ON_DIFF = 0.005, 3 -- s per frame; the rise over this many frames
CFG.ON_BANDS, CFG.ON_F0, CFG.ON_Q = 9, 50, 5 -- bands from 50 Hz, half an octave apart (to 800 Hz), narrow (Q)
CFG.ON_BW = 25                 -- Hz: the narrowest band (a narrower one needs too long to rise: a 2nd, late onset)
CFG.ON_SMOOTH = 1              -- the level of a band: smoothed over this many periods of its frequency (at least 5 ms)
CFG.ON_FLOOR = 30              -- dB: only bands this close to the loudest one of the moment count, from this far below (Dev 5)
CFG.ON_GATE = TP.CFG.ON_GATE   -- dB: no pluck this far below the loud parts of the whole item (noise, bleed)
CFG.ON_K, CFG.ON_D = 2.0, 1.5  -- an onset: a rise of ON_K x the mean of 1 s around it + ON_D dB
CFG.ON_GAP = 0.05              -- s: onsets at least this far apart
CFG.ON_BEFORE, CFG.ON_AFTER = 0.08, 0.04 -- s: a pitch change this close after / before an onset belongs to it
CFG.ON_SKIP = 0.03             -- s: the noise of the attack, not counted for the pitch of the note
CFG.ON_HOLD = 0.15             -- s: a piece too short for a note joins the next one when that starts this soon
CFG.END_GAP = 0.05             -- s: a note ends when its pitch is gone this long
CFG.HARM = { { 0, 1 }, { 12, 0.8 }, { 19, 0.5 }, { 24, 0.4 } } -- the 2nd method: semitones above, weight
CFG.HARM_LO, CFG.HARM_HI = 24, 47 -- the 2nd method: the notes C1 to B2
-- Octaves and strings (the trials of 23 November 2026: the odd harmonics of the low octave against the even ones)
CFG.TUNINGS = { -- the open strings from the lowest (MIDI numbers); the strings keep the names of their places
  { id = "std", label = "Standard (E A D G)", open = { 28, 33, 38, 43 } },
  { id = "half", label = "Half step down", open = { 27, 32, 37, 42 } },
  { id = "dropd", label = "Drop D (D A D G)", open = { 26, 33, 38, 43 } },
  { id = "dropc", label = "Drop C (C G C F)", open = { 24, 31, 36, 41 } },
  { id = "five", label = "5-string (B E A D G)", open = { 23, 28, 33, 38, 43 } },
}
CFG.STRING_NAMES = { [4] = { "E", "A", "D", "G" }, [5] = { "B", "E", "A", "D", "G" } }
CFG.OCT_DB = -6                -- the odd harmonics this far below the even ones: the higher octave (Det.octave_limit:
CFG.OCT_FIT_LO, CFG.OCT_FIT_HI = -20, 0 -- the limit of each song between these, in its emptiest place: the fewest values
CFG.OCT_VALLEY, CFG.OCT_GAP = 3, 0.05 -- within this many dB, at most this share of the notes; at least OCT_FIT_MIN notes)
CFG.OCT_FIT_MIN = 30
CFG.OCT_SURE = 8               -- dB from that limit: sure, even when YIN disagrees (trial 5i: fewer yellow lines,
                               -- song 2: 24 yellow of which 22 wrong, instead of 37 of which 29)
CFG.FRET_MAX = 7               -- a high note goes on the lowest string with this fret or a lower one
CFG.TUNING_W = 190             -- the Tuning dropdown
-- Slides and repeated notes (trial 6d, 23 November 2026)
CFG.SLIDE_MIN = 2              -- semitones: a pitch that glides this far into a note (no new attack) is a slide
CFG.SLIDE_STEPS = 8            -- frames (10 ms) that the pitch moves at least (a plain note change takes 2-3; song 2:
                               -- 5 gave 24 slides that the score does not have, 8 gave 3)
CFG.SLIDE_MAX = 0.25           -- s: the longest glide
CFG.REP_DB = 4                 -- dB: a 16th inside a note with dip + REP_RISE x rise of this size is a new note
CFG.REP_RISE = 0.5
CFG.REP_EDGE = 0.05            -- s: no new note this close to the start or the end of a note
CFG.STRINGS_W = 160            -- Settings > Notes > String names
-- Fingering for runs (trial 4c: 398 of 410 notes in the same place as a Guitar Pro score, "few shifts")
CFG.RUN_MIN = 4                -- a row with this many notes or more is a run: every note gets its string and fret
CFG.FRETS = 15                 -- the highest fret that the fingering uses
-- Tab view (px)
CFG.TAB_SLOT = 12              -- the width of a 16th note (2 bars of 4/4 in the default window)
CFG.TAB_PAD = 10               -- the space at the start of a bar
CFG.TAB_LINE = 17              -- between 2 strings
CFG.TAB_TOP, CFG.TAB_BOTTOM = 22, 30 -- above the top string (the bar number) and below the low one (the beats, a gap)
CFG.TAB_LEFT = 22              -- the string names at the left
CFG.TAB_STRETCH = 1.6          -- the bars of a line stretch to the full width, at most this much
CFG.TAB_DIGITS = 0.8           -- s: 2 digits typed within this time are 1 fret ("1" "2" = 12)
CFG.VIEW_W = 90                -- the View dropdown
-- Export (MIDI)
CFG.MIDI_TRACK = "Bass MIDI"   -- the name of the track of the MIDI item
CFG.MIDI_VEL = 96              -- the velocity of the exported notes
CFG.PPQ = 960                  -- the ticks per quarter note of the .mid file
CFG.GRIDS = { { 0.25, "16th notes" }, { 0.5, "8th notes" }, { 0, "No quantize" } } -- Rhythm (quarter notes)
CFG.FINGER = { move = 0.5, shift = 3, str = 0.3, same = 5, high = 0.2, open = 1, stretch = 0.3 } -- the costs: a hand
                               -- move per fret, any hand move, a string change, the same note on another string,
                               -- per fret above 5, an open string, a stretch over 4 frets low on the neck
CFG.PUSH = 1.25 / 8           -- of a bar: a little more than an 8th note in 4/4 (a note before the bar line)
CFG.SPAN_GAP = 0.15           -- the same note again within this time is the same part
CFG.SEC_LEN = 2               -- "About 2 seconds": a new marker at the first note after this time
CFG.SECTION_BARS = 8           -- a repeat of this many bars starts a new section
CFG.STEP = TP.CFG.STEP         -- s of work per frame while Find notes runs (as Find tempo)
-- Tempo and bars: the shared Tempo.lua (its constants: TP.CFG)
CFG.SRC_W = 170                -- the Beats from dropdown
CFG.UNDO_TRY = "Note Detective: try the tempo" -- the undo step of Play with click (taken back before the next one)

local COL = {
  RED = 0xF26D6DFF, YELLOW = 0xF2C75CFF, GREEN = 0x6FCF8AFF,
  ACCENT = 0x3B82F6FF, ACCENT_HOVER = 0x5B9BFFFF, ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633, HEADING = 0x8DB8FFFF,
  WIN_BG = 0x131518FF, PANEL_BG = 0x1A1C21FF,
  FIELD = 0x2B2F38FF, FIELD_HOVER = 0x333844FF, FIELD_ACTIVE = 0x2C3A55FF,
  BTN = 0x30343EFF, BTN_HOVER = 0x3B404CFF, BTN_ACTIVE = 0x464C5AFF,
  LINE = 0x31353FFF, ROW_HOVER = 0xFFFFFF12, TOGGLE_OFF = 0x4A5060FF,
  TEXT_MAIN = 0xE6E8EEFF, TEXT_DIM = 0x8C93A3FF, TEXT_BRIGHT = 0xEEEEEEFF, WHITE = 0xFFFFFFFF,
  TRANSPARENT = 0x00000000,
  HEADER_HOVER = 0x3B82F655, HEADER_ACTIVE = 0x3B82F677,
  ORANGE = 0xF2994AFF,
  TITLE_BG = 0x0F1114FF, TITLE_BG_ACTIVE = 0x1A1C21FF,
}

-- The themes (gear menu > Light theme): the same palettes as Chart Cue.
local THEMES = { dark = {} }
for k, v in pairs(COL) do THEMES.dark[k] = v end
THEMES.light = {
  RED = 0xD43F3FFF, YELLOW = 0xB7860BFF, GREEN = 0x2E9E5BFF,
  ACCENT = 0x2F6FE0FF, ACCENT_HOVER = 0x3B82F6FF, ACCENT_ACTIVE = 0x2559C7FF, ACTIVE_BG = 0x3B82F617,
  HEADING = 0x2459C2FF,
  WIN_BG = 0xDDE1E7FF, PANEL_BG = 0xF4F5F7FF,
  FIELD = 0xFFFFFFFF, FIELD_HOVER = 0xEEF2F7FF, FIELD_ACTIVE = 0xE1EAFAFF,
  BTN = 0xE3E7EDFF, BTN_HOVER = 0xD5DBE3FF, BTN_ACTIVE = 0xC5CCD7FF,
  LINE = 0xCBD1DAFF, ROW_HOVER = 0x0000000F, TOGGLE_OFF = 0xB3BAC6FF,
  TEXT_MAIN = 0x1E2127FF, TEXT_DIM = 0x667085FF, TEXT_BRIGHT = 0x101216FF,
  HEADER_HOVER = 0x3B82F626, HEADER_ACTIVE = 0x3B82F640, ORANGE = 0xD9771FFF,
  TITLE_BG = 0xD0D5DDFF, TITLE_BG_ACTIVE = 0xE6E9EEFF,
}
local function apply_theme(light)
  for k, v in pairs(THEMES[light and "light" or "dark"]) do COL[k] = v end
end

local Util, Key, Det, Group, List, Project, Find, Out, Beat, Tempo, Export, Tab, Imp, UI = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}

-- R: runtime state (not saved). P: the project data. S: settings of this computer.
local R = {
  proj = nil, projfn = "", state_cc = -1, plast_txt = "", pdirty = false, sdirty = false,
  frames = 0,
  find = nil,        -- the running Find notes: { item, take, proj, rd (the reader), co (the detection), done 0-1 }
  sel = nil,         -- the selected row (its index in P.rows)
  edit = nil,        -- the row whose notes are typed: { i, txt, focus }
  undo = {},         -- the Undo button: the older project data texts
  view = nil,        -- the texts of the list rows (UI.view; rebuilt after a change)
  src_name = nil,    -- the name of the bass item (cached until the project changes)
  finish = nil,      -- the open Finish window
  export = nil,      -- the open Export window: { item, file, step (Rhythm), open }
  import = nil,      -- the open Import tab window: { doc (GP.read), name, track, q0 (Imp.start), matched, bar (QN of
                     -- the tab's 1st bar: the step of "< 1 bar"), lbl, list, open }
  tempo = nil,       -- Tempo and bars: { song = { guid, t0, t1 }, run (Find tempo running), env, f0, bpm, beats,
                     --   i0 (the beat of bar 1), short = { [beat index] = true }, style, steady, try (Play with click) }
  tsrc = nil,        -- the tracks of Beats from (cached until the project changes); tsrc_sel: the chosen track
  tempo_shut = nil,  -- Tempo and bars folded after Set tempo (until a click on its heading; S.tempo stays)
}
local P
local S = {
  light = false,     -- Light theme (Dark is the default)
  dock = 0,          -- the REAPER docker of the window (0 = floating)
  out = "markers",   -- what Write makes: "markers", "track" (the Notes track) or "both"
  tempo = true,      -- the Tempo and bars section is open (folded: false)
  frets = true,      -- Settings > Notes > String and fret for high notes
  finger = true,     -- Settings > Notes > Fingering for runs
  strings = "letters", -- Settings > Notes > String names: "letters" (E A D G) or "numbers" (4 3 2 1)
  counts = true,     -- Settings > Notes > Beat count in the Notes track
  export_dir = "",   -- the folder of the .mid files ("": the project folder)
  slide = "slash",   -- Settings > Notes > Slide mark: "slash" (/C), "sl" (sl. C), "word" (C (slide)), "off"
  simple = true,     -- Settings > Notes > Simple mode: only notes and the string of high notes; the extras hidden
  splits = true,     -- Settings > Notes > Split repeated notes (after Set tempo; full mode)
}
local S_DEFAULTS = { light = false, dock = 0, out = "markers", tempo = true, frets = true, finger = true,
  strings = "letters", counts = true, export_dir = "", slide = "slash", simple = true, splits = true }

---------------------------------------------------------------------------
-- REAIMGUI (pinned to 0.9.3 with the official compatibility shim)
---------------------------------------------------------------------------
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("Note Detective needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end
  else
    r.ShowMessageBox("Note Detective needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run Note Detective again.", CFG.TITLE, 0)
  end
end
local TESTING = rawget(_G, "NoteDetectiveTest") ~= nil
local ImGui = {}
if not TESTING then
  if not r.ImGui_CreateContext or not r.file_exists(IMGUI_SHIM) then imgui_missing(); return end
  if not pcall(function() dofile(IMGUI_SHIM)("0.9.3") end) then imgui_missing(); return end
  setmetatable(ImGui, { __index = function(_, k) return r["ImGui_" .. k] end })
  local raw_set_tooltip = r.ImGui_SetTooltip
  -- Every tooltip: shows after the mouse stays CFG.TIP_DELAY s on the same item (as in Chart Cue).
  function ImGui.SetTooltip(ctx_, text)
    local x, y = r.ImGui_GetItemRectMin(ctx_)
    local now = r.time_precise()
    if R.tip_frame == nil or R.tip_frame < R.frames - 1 or R.tip_x ~= x or R.tip_y ~= y then
      R.tip_t0, R.tip_x, R.tip_y = now, x, y
    end
    R.tip_frame = R.frames
    if now - R.tip_t0 < CFG.TIP_DELAY then return end
    if r.ImGui_BeginTooltip(ctx_) then
      r.ImGui_PushTextWrapPos(ctx_, r.ImGui_GetFontSize(ctx_) * CFG.TIP_WRAP_EM)
      r.ImGui_Text(ctx_, text)
      r.ImGui_PopTextWrapPos(ctx_)
      r.ImGui_EndTooltip(ctx_)
    else
      raw_set_tooltip(ctx_, text)
    end
  end
end

---------------------------------------------------------------------------
-- UTIL
---------------------------------------------------------------------------
function Util.now() return r.time_precise() end
function Util.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function Util.clean(s) return ((s or ""):gsub("[\t\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")) end
function Util.mark_pdirty() R.pdirty, R.view, R.tab, R.places = true, nil, nil, nil end
-- The item of this project with this GUID (nil: none; TP.item_by_guid).
function Util.item_by_guid(guid) return TP.item_by_guid(R.proj, guid) end
-- A folder picker (as in MIDI Pilot): the js_ReaScriptAPI extension's, else on Windows the Windows folder window
-- (REAPER waits until it closes). Returns the folder, or nil.
function Util.browse_folder(title, start)
  if r.JS_Dialog_BrowseForFolder then
    local rv, folder = r.JS_Dialog_BrowseForFolder(title, start or "")
    if rv == 1 and folder and folder ~= "" then return folder end
    return nil
  end
  if not r.GetOS():match("^Win") then return nil end
  local sp = (start or ""):gsub("/", "\\"):gsub("'", "''")
  local cmd = 'powershell -NoProfile -STA -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; '
    .. "$f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.SelectedPath = '" .. sp .. "'; "
    .. "if ($f.ShowDialog() -eq 'OK') { $f.SelectedPath }" .. '"'
  local h = io.popen(cmd)
  if not h then return nil end
  local out = h:read("a") or ""
  h:close()
  out = out:match("^%s*(.-)%s*$")
  return out ~= "" and out or nil
end
function Util.settings_lines()
  return { "light=" .. (S.light and "1" or "0"), "dock=" .. tostring(S.dock), "out=" .. S.out,
    "tempo=" .. (S.tempo and "1" or "0"), "frets=" .. (S.frets and "1" or "0"), "finger=" .. (S.finger and "1" or "0"),
    "strings=" .. S.strings, "counts=" .. (S.counts and "1" or "0"), "export_dir=" .. S.export_dir,
    "slide=" .. S.slide, "simple=" .. (S.simple and "1" or "0"), "splits=" .. (S.splits and "1" or "0") }
end
function Util.apply_setting(k, v)
  if k == "light" then S.light = (v == "1")
  elseif k == "splits" then S.splits = (v ~= "0")
  elseif k == "slide" then S.slide = (v == "sl" or v == "word" or v == "off") and v or "slash"
  elseif k == "simple" then S.simple = (v ~= "0")
  elseif k == "export_dir" then S.export_dir = Util.clean(v)
  elseif k == "strings" then S.strings = v == "numbers" and v or "letters"
  elseif k == "counts" then S.counts = (v ~= "0")
  elseif k == "finger" then S.finger = (v ~= "0")
  elseif k == "tempo" then S.tempo = (v ~= "0")
  elseif k == "frets" then S.frets = (v ~= "0")
  elseif k == "dock" then S.dock = math.floor(tonumber(v) or 0)
  elseif k == "out" then S.out = (v == "track" or v == "both") and v or "markers" end
end
function Util.load_settings()
  for k in pairs(S_DEFAULTS) do
    local v = r.GetExtState(CFG.EXT, k)
    if v ~= "" then Util.apply_setting(k, v) end
  end
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
function Util.save_settings()
  for _, line in ipairs(Util.settings_lines()) do
    local k, v = line:match("^([%w_]+)=(.*)$")
    r.SetExtState(CFG.EXT, k, v, true)
  end
  R.sdirty = false
end

---------------------------------------------------------------------------
-- KEY (the key of the song and the names of the notes)
---------------------------------------------------------------------------
Key.PC = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
Key.SHARP = { [0] = "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
Key.FLAT = { [0] = "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }
local TONIC = { -- the usual name of each tonic
  major = { [0] = "C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B" },
  minor = { [0] = "C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B" },
}
local FLAT_KEY = { major = { [1] = true, [3] = true, [5] = true, [8] = true, [10] = true },
  minor = { [0] = true, [2] = true, [3] = true, [5] = true, [7] = true, [10] = true } }
local DEGREE = { -- the letter step of each interval (0-11 semitones above the tonic)
  major = { [0] = 0, 0, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6 },
  minor = { [0] = 0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6 },
}
local IN_KEY = {
  major = { [0] = true, [2] = true, [4] = true, [5] = true, [7] = true, [9] = true, [11] = true },
  minor = { [0] = true, [2] = true, [3] = true, [5] = true, [7] = true, [8] = true, [10] = true },
}
Key.LIST = {}
for pc = 0, 11 do
  Key.LIST[#Key.LIST + 1] = TONIC.major[pc] .. " major"
  Key.LIST[#Key.LIST + 1] = TONIC.minor[pc] .. " minor"
end

function Key.pc(letter, acc)
  return (Key.PC[letter] + (acc == "#" and 1 or acc == "b" and -1 or 0)) % 12
end

-- The key in a file name ("... C minor ...", "... Cm ...", "... F# major ..."), as in Key.LIST; nil without one.
-- The last one counts (the song title comes first).
function Key.find(text)
  local pc, mode, at
  for pos, l, a, w in (text or ""):gmatch("()%f[%w]([A-G])([#b]?)[%s_]?(%a+)") do
    local m = w:lower()
    m = (m == "minor" or m == "min" or w == "m") and "minor" or (m == "major" or m == "maj") and "major" or nil
    if m and (not at or pos > at) then pc, mode, at = Key.pc(l, a), m, pos end
  end
  return pc and (TONIC[mode][pc] .. " " .. mode) or nil
end

-- The 12 note names of a key (0 = C ...): correct for the key. A note outside the key gets its usual name (F# in
-- C minor); a double sharp or flat gets the simple name. Without a key: sharps.
local names_cache = {}
function Key.names(key)
  local n = names_cache[key or ""]
  if n then return n end
  local l, a, mode = (key or ""):match("^([A-G])([#b]?) (%a+)$")
  if not l or not DEGREE[mode] then n = Key.SHARP
  else
    n = {}
    local tonic = Key.pc(l, a)
    local simple = FLAT_KEY[mode][tonic] and Key.FLAT or Key.SHARP
    local order = "CDEFGAB"
    local l0 = order:find(l, 1, true) - 1
    for i = 0, 11 do
      local pc = (tonic + i) % 12
      local k = (l0 + DEGREE[mode][i]) % 7 + 1
      local letter = order:sub(k, k)
      local d = (pc - Key.PC[letter] + 6) % 12 - 6
      local name = letter .. (d == 1 and "#" or d == -1 and "b" or "")
      local odd = name == "E#" or name == "B#" or name == "Cb" or name == "Fb"
      if math.abs(d) > 1 or (odd and not IN_KEY[mode][i]) then name = simple[pc] end
      n[pc] = name
    end
  end
  names_cache[key or ""] = n
  return n
end

-- The notes of a text with the names of another key. The text in brackets (a string and a fret) stays.
function Key.respell(text, key)
  local names = Key.names(key)
  local out, i = {}, 1
  while i <= #text do
    local a, b = text:find("%b()", i)
    local seg = text:sub(i, (a or #text + 1) - 1)
    out[#out + 1] = (seg:gsub("%f[%w#]([A-G])([#b]?)%f[^%w#]", function(l, acc) return names[Key.pc(l, acc)] end))
    if not a then break end
    out[#out + 1] = text:sub(a, b)
    i = b + 1
  end
  return table.concat(out)
end

-- A tuning of CFG.TUNINGS by its id (Standard when it is not known).
function Key.tuning(id)
  for _, t in ipairs(CFG.TUNINGS) do if t.id == id then return t end end
  return CFG.TUNINGS[1]
end
-- The lowest note of a pitch class on a bass with this lowest open string (the note with the plain name).
function Key.low(pc, lowest)
  return lowest + (pc - lowest) % 12
end
-- The names of the strings of a tuning, from the lowest: "E A D G" (the names of their places), or numbers as in tab
-- books (the lowest string has the highest number: 4 3 2 1).
function Key.string_names(tun, numbers)
  if not numbers then return CFG.STRING_NAMES[#tun.open] end
  local t = {}
  for s = 1, #tun.open do t[s] = tostring(#tun.open + 1 - s) end
  return t
end
-- The text after the name of a note: "" in the lowest octave, else " (string fret)" on the lowest string with a fret
-- of CFG.FRET_MAX or less (else the lowest fret). names: the string names (default: Key.string_names).
function Key.place(midi, tun, names)
  local open = tun.open
  if not midi or midi < open[1] + 12 then return "" end
  local best
  for s = 1, #open do
    local f = midi - open[s]
    if f >= 0 and f <= CFG.FRET_MAX then return Key.place_text({ s = s, f = f }, tun, names) end
    if f >= 0 then best = s end
  end
  return Key.place_text(best and { s = best, f = midi - open[best] }, tun, names)
end
-- The text of a place { s = the string (1 = the lowest), f = the fret }: " (A 3)" ("" for none).
function Key.place_text(pl, tun, names)
  return pl and string.format(" (%s %d)", (names or Key.string_names(tun))[pl.s], pl.f) or ""
end

-- The comfortable fingering of a row of notes (MIDI numbers): { { s, f } or false (not on the neck) } with the fewest
-- hand moves (dynamic programming over the places and the hand position; a hand covers 4 frets). The costs: CFG.FINGER.
-- forced: { [i] = a string that the user chose for note i } (optional).
function Key.finger(midis, tun, forced)
  forced = forced or {}
  local W, open, out = CFG.FINGER, tun.open, {}
  local prev, first = nil, 1
  local function finish(last) -- the best way back through the notes first..last
    local e
    for _, a in ipairs(prev or {}) do if not e or a.cost < e.cost then e = a end end
    for i = last, first, -1 do
      out[i] = e and { s = e.s, f = e.f } or false
      e = e and e.back
    end
  end
  for i, m in ipairs(midis) do
    local col = {}
    for s = 1, #open do
      local f = m - open[s]
      if f >= 0 and f <= CFG.FRETS and (not forced[i] or forced[i] == s) then
        local hands = {}
        if f == 0 then -- (an open string: the hand stays where it is)
          local seen = {}
          for _, a in ipairs(prev or { { h = 1 } }) do
            if not seen[a.h] then seen[a.h] = true; hands[#hands + 1] = a.h end
          end
        else
          for h = math.max(1, f - 3), f do hands[#hands + 1] = h end
        end
        for _, h in ipairs(hands) do
          local c = W.high * math.max(0, f - 5) + (f == 0 and W.open or 0) + ((f > 0 and h < 5 and f - h == 3) and W.stretch or 0)
          local st = { s = s, f = f, h = h, cost = c }
          if prev then
            local bv, bj = math.huge, nil
            for _, a in ipairs(prev) do
              local v = a.cost + W.move * math.abs(a.h - h) + (a.h ~= h and W.shift or 0) + W.str * math.abs(a.s - s)
              if midis[i - 1] == m and a.s ~= s then v = v + W.same end
              if v < bv then bv, bj = v, a end
            end
            st.cost, st.back = c + bv, bj
          end
          col[#col + 1] = st
        end
      end
    end
    if #col == 0 then -- (not on the neck: the fingering starts again after it)
      if prev then finish(i - 1) end
      out[i], prev, first = false, nil, i + 1
    else
      prev = col
    end
  end
  if prev then finish(#midis) end
  return out
end

---------------------------------------------------------------------------
-- DET (the notes of a bass signal)
---------------------------------------------------------------------------
-- YIN: the period of the signal at sample s. Returns the pitch (MIDI number, with a fraction) and how unsure it is.
function Det.yin(x, s, d)
  local W, L0, L1 = CFG.YIN_W, CFG.LAG0, CFG.LAG1
  local run, best, bv = 0, nil, 1e9
  for lag = 1, L1 do
    local sum = 0
    for i = s, s + W - 1 do
      local v = x[i] - x[i + lag]
      sum = sum + v * v
    end
    run = run + sum
    d[lag] = run > 0 and sum * lag / run or 1
  end
  for lag = L0, L1 - 1 do
    if d[lag] < CFG.YIN_THR and d[lag] <= d[lag + 1] then best = lag; break end
    if d[lag] < bv then bv = d[lag] end
  end
  if not best then
    for lag = L0, L1 - 1 do if d[lag] == bv then best = lag; break end end
  end
  if not best then return nil end
  local a, b, c = d[best - 1], d[best], d[best + 1]
  local den = a - 2 * b + c
  local p = best + (den ~= 0 and Util.clamp(0.5 * (a - c) / den, -0.5, 0.5) or 0)
  return 69 + 12 * math.log(CFG.SR / p / 440, 2), b
end

-- The 2nd method: of the notes C1 to B2, the one with the strongest harmonics (samples s0 to s1). Its pitch class.
function Det.harm_pc(x, s0, s1, tune)
  s0, s1 = math.max(1, s0), math.min(#x, s1)
  local n = s1 - s0 + 1
  if n < 200 then return nil end
  local buf, mag = {}, {}
  for k = 1, n do buf[k] = x[s0 + k - 1] * (0.5 - 0.5 * math.cos(2 * math.pi * (k - 0.5) / n)) end
  for m = CFG.HARM_LO, CFG.HARM_HI + CFG.HARM[#CFG.HARM][1] do
    local co = 2 * math.cos(2 * math.pi * 440 * 2 ^ ((m + tune - 69) / 12) / CFG.SR)
    local q1, q2 = 0, 0
    for k = 1, n do q1, q2 = buf[k] + co * q1 - q2, q1 end
    mag[m] = math.sqrt(math.max(0, q1 * q1 + q2 * q2 - co * q1 * q2))
  end
  local best, bv = nil, 0
  for m = CFG.HARM_LO, CFG.HARM_HI do
    local v = 0
    for _, h in ipairs(CFG.HARM) do v = v + h[2] * (mag[m + h[1]] or 0) end
    if v > bv then best, bv = m, v end
  end
  return best and best % 12 or nil
end

-- The octave: how strong the odd harmonics (1, 3, 5) of the note low are against the even ones (2, 4, 6), in dB, for
-- len s from t (s from the start of x). Far below 0: the note sounds an octave higher (the trials: CFG.OCT_DB).
function Det.odd_even(x, t, len, low, tune)
  local f = 440 * 2 ^ ((low + tune - 69) / 12)
  local s0, n = math.floor(t * CFG.SR) + 1, math.floor(len * CFG.SR)
  local function pow(hz)
    local w = 2 * math.pi * hz / CFG.SR
    local c, s = 0, 0
    for k = 0, n - 1 do
      local v = (x[s0 + k] or 0) * (0.5 - 0.5 * math.cos(2 * math.pi * k / n))
      c, s = c + v * math.cos(w * k), s + v * math.sin(w * k)
    end
    return c * c + s * s
  end
  local o = pow(f) + pow(3 * f) + pow(5 * f)
  local e = pow(2 * f) + pow(4 * f) + pow(6 * f)
  return 10 * math.log((o + 1e-12) / (e + 1e-12), 10)
end

-- Slides: a note without its own attack that the pitch glides into (CFG.SLIDE_MIN semitones or more, at most
-- CFG.SLIDE_MAX s, steadily and without a jump) gets slide = true and starts where the glide starts; the short notes
-- of the glide go, and the note before it ends there. m, ap: the YIN pitch (MIDI) and how unsure it is, per frame.
function Det.slides(notes, m, ap, tune, t_of)
  local function frame(t) return math.floor((t * CFG.SR - CFG.YIN_W / 2) / CFG.HOP) + 1 end
  local function pitch(k) return m[k] and ap[k] < CFG.YIN_MAX and m[k] - tune or nil end
  local out = {}
  for _, n in ipairs(notes) do
    local kb = frame(n.t)
    local vals = {}
    for k = kb, kb + 4 do vals[#vals + 1] = pitch(k) end
    if not n.att and #vals >= 3 then
      table.sort(vals)
      local tp = vals[(#vals + 1) // 2] -- (the pitch of the note)
      local k, last, dir, moving, flat, steps = kb - 1, tp, nil, nil, 0, 0
      while k >= math.max(1, frame(n.t - CFG.SLIDE_MAX)) do -- (back from the note: the glide)
        local v = pitch(k)
        if not v or math.abs(v - last) > 1.2 then break end -- (no pitch, or a jump: another note)
        local d = v - last
        if math.abs(d) >= 0.08 then
          local s = d > 0 and 1 or -1
          if dir and s ~= dir then break end
          dir, moving, flat, steps = s, k, 0, steps + 1
        else
          flat = flat + 1
          if flat >= 3 and moving then break end -- (the pitch stays: the glide started here)
        end
        last, k = v, k - 1
      end
      if moving and steps >= CFG.SLIDE_STEPS and math.abs(pitch(moving) - tp) >= CFG.SLIDE_MIN then
        local ts = t_of(moving)
        while out[#out] and out[#out].t >= ts - 0.01 do table.remove(out) end
        if out[#out] and out[#out].t1 > ts then out[#out].t1 = ts end
        n.slide, n.tp, n.t = true, n.t, ts -- (tp: where its pitch is steady, for the checks)
      end
    end
    out[#out + 1] = n
  end
  return out
end

-- Repeated notes: a 16th note of the song inside a note (grid: their times, project time; pos: the start of x in the
-- project) where the level dips and rises again (1 period of the note per window; dip + CFG.REP_RISE x rise of
-- CFG.REP_DB or more) starts a new note of the same pitch (rep = true). Trial 6d: about half of the repeats of a song,
-- few wrong splits.
function Det.repeats(x, notes, grid, pos)
  local SR, out, g = CFG.SR, {}, 1
  local function lev(t, per)
    local s0 = math.floor((t - pos) * SR) + 1
    local a = 0
    for k = s0, s0 + per - 1 do a = a + (x[k] or 0) ^ 2 end
    return 10 * math.log(a / per + 1e-12, 10)
  end
  for _, n in ipairs(notes) do
    local per = math.max(8, math.floor(SR / (440 * 2 ^ ((n.midi - 69) / 12)) + 0.5))
    local cur, t1 = n, n.t1
    while grid[g] and grid[g] < n.t + CFG.REP_EDGE do g = g + 1 end
    local j = g
    while grid[j] and grid[j] <= t1 - CFG.REP_EDGE do
      local tg = grid[j]
      if tg - cur.t >= CFG.REP_EDGE then
        local lo, before, after = 1e9, -1e9, -1e9
        for d = -0.03, 0.0101, 0.005 do lo = math.min(lo, lev(tg + d, per)) end
        for d = -0.07, -0.0299, 0.005 do before = math.max(before, lev(tg + d, per)) end
        for d = 0.01, 0.0501, 0.005 do after = math.max(after, lev(tg + d, per)) end
        if math.min(before - lo, after - lo) + CFG.REP_RISE * (after - lo) >= CFG.REP_DB then
          local nxt = {}
          for k, v in pairs(cur) do nxt[k] = v end
          cur.t1, nxt.t, nxt.rep, nxt.slide = tg, tg, true, nil
          out[#out + 1] = cur
          cur = nxt
        end
      end
      j = j + 1
    end
    out[#out + 1] = cur
  end
  return out
end

-- Glitches (trial 7, Burning Roads: a low C held for 4 bars became C - G - C - C - G ...): the pitch of a very low note
-- jumps to its own overtone (a 5th up) for a moment. Such a short note (CFG.GLITCH s) between 2 parts of the same note,
-- without an attack (or the 2nd method hears the note around it), goes, and the 2 parts join (when the 2nd has no
-- attack). Tried and dropped (they removed real notes of the song): a fading note's overtone joins the note before it;
-- 2 parts of the same note with a short gap join.
function Det.glitches(notes, x, tune)
  local W, SR = CFG.YIN_W, CFG.SR
  -- the 2nd method (the overtone pattern) says that note n is really the note before it
  local function same_as(n, prev)
    return Det.harm_pc(x, math.floor((n.t - W / 2 / SR) * SR), math.floor(math.min(n.t1, n.t + 0.3) * SR), tune) == prev.pc
  end
  local out = {}
  local k = 1
  while k <= #notes do
    local n, prev, nxt = notes[k], out[#out], notes[k + 1]
    local gap_b = prev and n.t - prev.t1 or 1e9
    local fifth = prev and (n.pc - prev.pc) % 12 == 7 -- (the overtone of the note before, a 5th up)
    if fifth and n.t1 - n.t < CFG.GLITCH and gap_b < 0.06 and nxt and nxt.pc == prev.pc and nxt.t - n.t1 < 0.06
      and (not n.att or same_as(n, prev)) then
      if nxt.att then out[#out + 1] = nxt else prev.t1 = nxt.t1 end -- (the glitch goes; the 2 parts join)
      k = k + 2
    else
      out[#out + 1] = n
      k = k + 1
    end
  end
  return out
end

-- The onsets (the plucks; Dev 2 of the review of 23 November 2026) of the signal x (sr): the band flux. The level of
-- CFG.ON_BANDS narrow bands (from CFG.ON_F0 Hz, half an octave apart) in 5 ms frames; the onset curve = the mean rise of
-- the bands over CFG.ON_DIFF frames, relative to the loudest band of the moment (Dev 5). An onset: a peak (30 ms) of at least CFG.ON_K x the mean of 1 s around +
-- CFG.ON_D, at least CFG.ON_GAP after the one before. Returns the times (s). Trial 9 (song 2 against its tab): the
-- notes found 66.6% -> 82.3%, 87.0% with the 16th grid. Tried and dropped: a high band from a 16 kHz read (1 point more:
-- not worth a 2nd read); a stronger onset for the same note again (it lost 2 real repeats for each wrong one).
function Det.onsets_of(x, sr, tick)
  local hop = math.max(1, math.floor(sr * CFG.ON_STEP + 0.5))
  local dt, bands = hop / sr, {}
  for b = 1, CFG.ON_BANDS do
    local f = CFG.ON_F0 * 2 ^ ((b - 1) / 2)
    local w0 = 2 * math.pi * f / sr
    local al = math.sin(w0) / (2 * math.min(CFG.ON_Q, f / CFG.ON_BW)) -- (at least ON_BW Hz wide: a narrow low band rises late)
    local a0 = 1 + al
    -- the level: smoothed over at least CFG.ON_SMOOTH periods of the band (5 ms is shorter than 1 period of a low
    -- band: its level would ripple with the wave, and a held note would get an onset every few frames)
    local k = 1 - math.exp(-1 / (math.max(dt, CFG.ON_SMOOTH / f) * sr))
    bands[b] = { b0 = al / a0, b2 = -al / a0, a1 = -2 * math.cos(w0) / a0, a2 = (1 - al) / a0, x1 = 0, x2 = 0, y1 = 0,
      y2 = 0, e = 0, k = k, L = {} }
  end
  local n = 0
  for i = 1, #x do -- (bandpass filters, RBJ)
    local v = x[i]
    for _, bd in ipairs(bands) do
      local y = bd.b0 * v + bd.b2 * bd.x2 - bd.a1 * bd.y1 - bd.a2 * bd.y2
      bd.x2, bd.x1, bd.y2, bd.y1 = bd.x1, v, bd.y1, y
      bd.e = bd.e + bd.k * (y * y - bd.e)
    end
    n = n + 1
    if n == hop then
      for _, bd in ipairs(bands) do bd.L[#bd.L + 1] = 10 * math.log(bd.e + 1e-12, 10) end
      n = 0
    end
    if tick and i % 4000 == 0 then tick(i / #x) end -- (about 10 ms of work: the window stays smooth)
  end
  local nf, D = #bands[1].L, CFG.ON_DIFF
  -- the loud level of the whole signal (the loudest band of each frame, its 95th percentile): a pluck far below it is
  -- noise (the bleed of a separated stem before the bass starts; lessons 23 November 2026: Set tempo aligned it)
  local top, sorted = {}, {}
  for k = 1, nf do
    local v = -1e9
    for _, bd in ipairs(bands) do v = math.max(v, bd.L[k]) end
    top[k] = v
    if v > -100 then sorted[#sorted + 1] = v end
  end
  table.sort(sorted)
  local quiet = (sorted[math.max(1, math.floor(#sorted * 0.95))] or 0) - CFG.ON_GATE
  local of, pre = {}, { 0 }
  for k = 1, nf do
    -- the rise of each band that is within ON_FLOOR dB of the loudest band of this frame, from at most ON_FLOOR dB
    -- below it (Dev 5: only levels relative to this moment count, so a soft part is as clear as a loud one, and the
    -- noise of an empty band never counts)
    local s = 0
    if k > D then
      local floor = -1e9
      for _, bd in ipairs(bands) do floor = math.max(floor, bd.L[k]) end
      floor = floor - CFG.ON_FLOOR
      for _, bd in ipairs(bands) do
        if bd.L[k] > floor then s = s + bd.L[k] - math.max(floor, math.min(bd.L[k], bd.L[k - D])) end
      end
    end
    of[k] = s / #bands
    pre[k + 1] = pre[k] + of[k]
  end
  local around, near = math.floor(1 / dt + 0.5), math.max(1, math.floor(0.03 / dt + 0.5))
  local out, last = {}, -1
  for k = D + 1, nf do
    local v = of[k]
    local a, b = math.max(1, k - around), math.min(nf, k + around)
    local lim = CFG.ON_K * (pre[b + 1] - pre[a]) / (b - a + 1) + CFG.ON_D
    if v >= lim and math.max(top[k], top[math.min(nf, k + 2 * D)]) > quiet then -- (a soft note is still rising at k)
      local peak = true
      for j = math.max(1, k - near), math.min(nf, k + near) do
        if of[j] > v or (j < k and of[j] == v) then peak = false; break end
      end
      local t = (k - D) * dt -- (the start of the rise)
      if peak and t - last >= CFG.ON_GAP then out[#out + 1], last = t, t end
    end
  end
  return out
end

-- The notes of the signal x (mono, CFG.SR): a list of { pc, midi, t, t1, doubt, slide } (seconds from the start of x) and the
-- tuning (semitones). lowest: the lowest open string (MIDI; the octave of each note starts there). tick(done 0-1) is
-- called often (it can yield).
function Det.analyse(x, tick, lowest, on)
  lowest = lowest or CFG.TUNINGS[1].open[1]
  local W, HOP, SR = CFG.YIN_W, CFG.HOP, CFG.SR
  local last = #x - W - CFG.LAG1 - 1
  local db, sorted = {}, {}
  for s = 1, last, HOP do
    local e = 0
    for i = s, s + W - 1 do e = e + x[i] * x[i] end
    local v = e > 0 and 10 * math.log(e / W, 10) or -150
    db[#db + 1] = v
    if v > -70 then sorted[#sorted + 1] = v end
  end
  tick(0.02)
  if #sorted == 0 then return {}, 0 end
  table.sort(sorted)
  local loud = sorted[math.max(1, math.floor(#sorted * 0.95))]
  -- the pitch of each frame (only above the gate of the whole item: a gate that followed the last seconds (Dev 5)
  -- found notes in the bleed before the bass; lessons 23 November 2026)
  local gate = math.max(-70, loud - CFG.GATE_DB)
  local m, ap, d = {}, {}, {}
  for k = 1, #db do
    if db[k] > gate then m[k], ap[k] = Det.yin(x, (k - 1) * HOP + 1, d) end
    if k % 20 == 0 then tick(0.02 + 0.93 * k / #db) end
  end
  -- the tuning: the mean distance from the semitone (circular)
  local cs, sn = 0, 0
  for k = 1, #db do
    if m[k] and ap[k] < 0.1 and db[k] > loud - CFG.ATTACK_GATE_DB then
      local a = 2 * math.pi * (m[k] - math.floor(m[k] + 0.5))
      cs, sn = cs + math.cos(a), sn + math.sin(a)
    end
  end
  local tune = (cs ~= 0 or sn ~= 0) and math.atan(sn, cs) / (2 * math.pi) or 0
  local pc = {}
  for k = 1, #db do pc[k] = m[k] and ap[k] < CFG.YIN_MAX and math.floor(m[k] - tune + 0.5) % 12 or false end
  -- smooth: the most common pitch class of 7 frames (70 ms)
  local sm = {}
  for k = 1, #db do
    local cnt, bp, bn = {}, nil, 0
    for j = math.max(1, k - 3), math.min(#db, k + 3) do
      local p = pc[j]
      if p then
        cnt[p] = (cnt[p] or 0) + 1
        if cnt[p] > bn then bp, bn = p, cnt[p] end
      end
    end
    sm[k] = bn >= 4 and bp or false
  end
  -- the notes (Dev 1 and 3 of the review of 23 November 2026): the onsets (Det.onsets_of) start them; a pitch change or
  -- a start after silence without an onset near it starts one too (a slide, a hammer-on, a soft note). Each note gets
  -- 1 pitch: the most common one of its frames after the noise of the attack. (Before: a run of 1 pitch, and a level
  -- rise at least 0.12 s after its start: fast repeats could never start a new note.)
  local function t_of(k) return ((k - 1) * HOP + W / 2) / SR end
  on = on or Det.onsets_of(x, SR, function() tick(0.95) end)
  local starts = {}
  for _, t in ipairs(on) do starts[#starts + 1] = { t = t, att = true } end
  local oi = 1
  for k = 1, #db do
    if sm[k] and sm[k] ~= (sm[k - 1] or false) then
      local t = t_of(k) - CFG.START_COMP
      while on[oi] and on[oi] < t - CFG.ON_BEFORE do oi = oi + 1 end
      if not (on[oi] and on[oi] <= t + CFG.ON_AFTER) then starts[#starts + 1] = { t = t, att = false } end
    end
  end
  table.sort(starts, function(a, b) return a.t < b.t end)
  local function most(votes)
    local best, bn = nil, 0
    for p, c in pairs(votes) do if c > bn or (c == bn and p < best) then best, bn = p, c end end
    return best, bn
  end
  local notes, k, held = {}, 1, nil
  for i, st in ipairs(starts) do
    local t_next = starts[i + 1] and starts[i + 1].t or math.huge
    while k <= #db and t_of(k) < st.t do k = k + 1 end
    local votes, all, first, ends, gone, k0 = {}, {}, nil, {}, {}, k
    local skip = math.min(CFG.ON_SKIP, (t_next - st.t) / 3)
    while k <= #db and t_of(k) < t_next do
      -- the end of each pitch: its last frame before a gap of CFG.END_GAP s (a note ends at its own end: not where the
      -- next note is already heard, not after a silence)
      local p = pc[k] or sm[k]
      if p and not gone[p] then
        if ends[p] and t_of(k) - t_of(ends[p]) > CFG.END_GAP then gone[p] = true else ends[p] = k end
      end
      if pc[k] then
        all[pc[k]] = (all[pc[k]] or 0) + 1
        if t_of(k) >= st.t + skip then votes[pc[k]] = (votes[pc[k]] or 0) + 1; first = first or k end
      end
      k = k + 1
    end
    local best, bn = most(votes)
    local prev = notes[#notes]
    local fin = best and ends[best]
    if best and bn >= 3 and t_of(fin) - st.t >= CFG.NOTE_MIN then
      -- a short piece just before with this pitch (or none): the early start of this note (a false onset after it)
      if held and st.t - held.st.t < CFG.ON_HOLD and (held.pc == nil or held.pc == best) then st = held.st end
      local n = { pc = best, t = st.t + (st.att and 0 or CFG.START_COMP), t1 = t_of(fin), att = st.att,
        ap = 0, n = 0, db = -150, mv = {} } -- (att: it starts at its onset, no START_COMP at the end)
      for j = k0, fin do
        if pc[j] then
          n.ap, n.n, n.db = n.ap + (ap[j] or 0.5), n.n + 1, math.max(n.db, db[j])
          if pc[j] == best and j >= first then -- (the octave of YIN: the votes of the frames)
            local v = math.floor(m[j] - tune + 0.5)
            n.mv[v] = (n.mv[v] or 0) + 1
          end
        end
      end
      notes[#notes + 1] = n
      held = nil
    else
      -- too short for a note: the tail of the note before (its pitch), else maybe the start of the next one
      local pp = most(all)
      if pp and prev and pp == prev.pc and st.t - prev.t1 < CFG.ON_HOLD then prev.t1 = t_of(ends[pp]); held = nil
      else held = { st = st, pc = pp } end
    end
  end
  if CFG.GLITCH > 0 then notes = Det.glitches(notes, x, tune) end
  notes = Det.slides(notes, m, ap, tune, t_of)
  -- the doubtful ones (n.why, UX 1): the 2 methods disagree, an unsure pitch, or a fading note that turns into its own
  -- overtone (a 5th higher, without an attack)
  local vals = {}
  for i, n in ipairs(notes) do
    local tp = n.tp or n.t -- (a slide: from where its pitch is steady)
    local s0 = math.floor((tp - W / 2 / SR) * SR)
    local s1 = math.floor(math.min(n.t1 + W / 2 / SR, tp + 0.2) * SR)
    local h = Det.harm_pc(x, s0, s1, tune)
    local before = notes[i - 1]
    local ring = before and not n.att and not n.slide and (n.pc - before.pc) % 12 == 7 and n.t - before.t1 < 0.3
      and n.db < before.db
    n.why = (h ~= nil and h ~= n.pc) and "methods" or n.ap / n.n > 0.15 and "unsure" or ring and "overtone" or nil
    -- the octave: YIN's votes and the odd / even harmonics of the low octave (from the start of the note, 0.15 s: the
    -- best window on the real songs of the trials)
    local my, mn = nil, 0
    n.low = Key.low(n.pc, lowest)
    for v, c in pairs(n.mv) do if c > mn or (c == mn and v < my) then my, mn = v, c end end
    n.my = my and math.max(n.low, my)
    local len = math.min(0.15, n.t1 - tp)
    if not (n.my and n.my >= n.low + 24) and len >= 0.08 then
      n.oe = Det.odd_even(x, tp, len, n.low, tune)
      vals[#vals + 1] = n.oe
    end
    if i % 10 == 0 then tick(0.95 + 0.05 * i / #notes) end
  end
  -- the octave limit of this song (Dev 4), then for each note: when YIN and the harmonics disagree, the harmonics win
  -- (right more often on the notes that the user marked by hand) and the note is doubtful
  local lim = Det.octave_limit(vals)
  for _, n in ipairs(notes) do
    if n.my and n.my >= n.low + 24 then n.midi = n.my -- (very high: the harmonics of the low octave tell nothing)
    elseif n.oe then
      n.midi = n.oe < lim and n.low + 12 or n.low
      if n.my and n.my ~= n.midi and math.abs(n.oe - lim) < CFG.OCT_SURE then n.why = n.why or "octave" end
    else
      n.midi = n.my and n.my >= n.low + 12 and n.low + 12 or n.low
    end
  end
  local out = {}
  for i, n in ipairs(notes) do
    out[i] = { pc = n.pc, midi = n.midi, t = math.max(0, n.t - ((n.slide or n.att) and 0 or CFG.START_COMP)), t1 = n.t1,
      doubt = n.why ~= nil, why = n.why, slide = n.slide }
  end
  return out, tune
end

-- The octave limit of a song (Dev 4 of the review of 23 November 2026): the odd / even values of its notes (Det.odd_even)
-- form 2 groups (the low and the high octave); the limit goes in the emptiest place between them (the fewest values
-- within CFG.OCT_VALLEY dB), between CFG.OCT_FIT_LO and CFG.OCT_FIT_HI. Few notes or no clear gap: CFG.OCT_DB. Trial
-- 9e (song 2, 660 notes): the gap at -12 dB, 659 right against 644 with -6 dB (the middle of the 2 groups: 652).
function Det.octave_limit(vals)
  if #vals < CFG.OCT_FIT_MIN then return CFG.OCT_DB end
  local best, bn = CFG.OCT_DB, math.huge
  for lim = CFG.OCT_FIT_LO, CFG.OCT_FIT_HI, 0.5 do
    local n = 0
    for _, v in ipairs(vals) do if math.abs(v - lim) < CFG.OCT_VALLEY then n = n + 1 end end
    if n < bn or (n == bn and math.abs(lim - CFG.OCT_DB) < math.abs(best - CFG.OCT_DB)) then best, bn = lim, n end
  end
  return bn <= #vals * CFG.OCT_GAP and best or CFG.OCT_DB
end

---------------------------------------------------------------------------
-- GROUP (the notes become the rows of the list)
---------------------------------------------------------------------------
-- The bars of a project between 2 times: { t0, t1, tol }. tol: a note that starts this much before the bar line and
-- goes on belongs to the next bar.
function Group.project_bars(proj, t0, t1)
  local bars = {}
  local _, m = r.TimeMap2_timeToBeats(proj, t0)
  while #bars < 5000 do
    local a, b = r.TimeMap2_beatsToTime(proj, 0, m), r.TimeMap2_beatsToTime(proj, 0, m + 1)
    if a >= t1 or b <= a then break end
    bars[#bars + 1] = { t0 = a, t1 = b, tol = CFG.PUSH * (b - a) }
    m = m + 1
  end
  return bars
end
-- The bar and beat of a time ("7.1"); a 32nd before a beat counts as that beat.
function Group.bar_text(proj, t)
  local q = r.TimeMap2_timeToQN(proj, t) + 0.125
  local beat, m = r.TimeMap2_timeToBeats(proj, r.TimeMap2_QNToTime(proj, q))
  return string.format("%d.%d", m + 1, math.floor(beat + 0.001) + 1)
end
-- The beat of a time in its bar, counted "1 e & a": "1", "2&", "4a" (to the nearest 16th note).
local COUNT = { "", "e", "&", "a" }
function Group.count(proj, t)
  local beat, _, cml = r.TimeMap2_timeToBeats(proj, t)
  local s = math.floor(beat * 4 + 0.5)
  if s >= cml * 4 then s = 0 end -- (just before the next bar line: its "1")
  return tostring(s // 4 + 1) .. COUNT[s % 4 + 1]
end
-- "About 2 seconds": a bar starts at the first note after that time (for songs without a steady tempo).
function Group.second_bars(notes)
  local bars = {}
  for _, n in ipairs(notes) do
    local b = bars[#bars]
    if not b or n.t - b.t0 >= CFG.SEC_LEN then
      if b then b.t1 = n.t end
      bars[#bars + 1] = { t0 = n.t, t1 = math.huge, tol = 0.01 }
    end
  end
  return bars
end
-- "Every note change": each new note has its own bar (octave: also the same name in another octave). A long silence
-- also starts a new one.
function Group.change_bars(notes, octave)
  local bars = {}
  for i, n in ipairs(notes) do
    local b, p = bars[#bars], notes[i - 1]
    if not b or p.pc ~= n.pc or (octave and p.midi ~= n.midi) or n.t - p.t1 > CFG.SEC_LEN then
      if b then b.t1 = n.t end
      bars[#bars + 1] = { t0 = n.t, t1 = math.huge, tol = 0.01 }
    end
  end
  return bars
end

-- The same note played again right away is 1 span { pc, midi, t, t1, bad, len, slide, n, tl } (bad: the seconds of
-- doubtful notes; n: its notes, tl: the start of the last one). octave: the same pitch class in another octave is
-- another note. A slide into the same note starts a new span.
function Group.spans(notes, octave)
  local spans = {}
  for ni, n in ipairs(notes) do
    local s, len = spans[#spans], n.t1 - n.t
    if s and s.pc == n.pc and (not octave or s.midi == n.midi) and n.t - s.t1 < CFG.SPAN_GAP and not n.slide then
      s.t1, s.len, s.bad, s.n, s.tl = n.t1, s.len + len, s.bad + (n.doubt and len or 0), s.n + 1, n.t
    else
      spans[#spans + 1] = { pc = n.pc, midi = n.midi, t = n.t, t1 = n.t1, len = len, bad = n.doubt and len or 0,
        slide = n.slide, n = 1, tl = n.t, ni = ni }
    end
  end
  return spans
end

-- The notes inside each bar: { { pc, midi, t, doubt }, ... } (the same note again is 1 part).
function Group.slice(notes, bars, octave)
  local spans, out, first = Group.spans(notes, octave), {}, 1
  for i, b in ipairs(bars) do
    local parts = {}
    while spans[first] and spans[first].t1 < b.t0 do first = first + 1 end
    for k = first, #spans do
      local n = spans[k]
      if n.t >= b.t1 then break end
      local ov = math.min(n.t1, b.t1) - math.max(n.t, b.t0)
      local tol = b.tol or 0.01
      if ov > tol or ov > 0.5 * (n.t1 - n.t) then
        local p = parts[#parts]
        if not p or p.pc ~= n.pc or (octave and p.midi ~= n.midi) or n.slide then
          p = { pc = n.pc, midi = n.midi, t = n.t >= b.t0 - tol and n.t or b.t0, bad = 0, len = 0, slide = n.slide,
            n = 0, tf = n.t, ni = n.ni }
          parts[#parts + 1] = p
        end
        p.len, p.bad, p.n, p.tl = p.len + n.len, p.bad + n.bad, p.n + n.n, n.tl
      end
    end
    for _, p in ipairs(parts) do p.doubt = p.bad > 0.5 * p.len end
    out[i] = parts
  end
  return out
end

-- The bars that start a section: a block of CFG.SECTION_BARS bars or more (with 3 or more different bars) that was
-- played before from a marker, while the bars before the 2 blocks differ.
function Group.sections(keys)
  local start, n, L = {}, #keys, CFG.SECTION_BARS
  local fresh = {} -- (the bars with a marker of their own)
  for i = 1, n do fresh[i] = keys[i] ~= "" and keys[i] ~= keys[i - 1] end
  for i = 2, n - L + 1 do
    if keys[i] ~= "" and not fresh[i] then
      for j = 1, i - 1 do
        if fresh[j] and keys[j] == keys[i] and keys[j - 1] ~= keys[i - 1] then
          local k, kinds, seen = 0, 0, {}
          while k < L and keys[i + k] == keys[j + k] do
            if not seen[keys[i + k]] then seen[keys[i + k]] = true; kinds = kinds + 1 end
            k = k + 1
          end
          if k == L and kinds >= 3 then start[i] = true; break end
        end
      end
    end
  end
  return start
end

local SLIDE_TEXT = {
  slash = function(s) return "/" .. s end, sl = function(s) return "sl. " .. s end,
  word = function(s) return s .. " (slide)" end, off = function(s) return s end,
}
-- The rows: 1 per bar; a bar with the same notes as the bar before it has none, except at the start of a section.
-- opt: nil (only the names) or { tun = the tuning, names = the string names, high = the string and fret of the high
-- notes, runs = the fingering of every note in a row of CFG.RUN_MIN notes or more, slide = the slide mark (S.slide) }.
function Group.rows(notes, bars, key, opt)
  local slices, names = Group.slice(notes, bars, opt ~= nil and (opt.high or opt.runs)), Key.names(key)
  -- the places: the fingering of the notes (the same as the tab; a string that the user chose in the tab stays)
  local places = opt and (opt.high or opt.runs) and List.places(notes, opt.tun)
  local keys = {}
  for i, parts in ipairs(slices) do
    local t = {}
    local run = opt and opt.runs and #parts >= CFG.RUN_MIN
    for k, p in ipairs(parts) do
      local pl = places and places[p.ni]
      local extra = ""
      if run then extra = Key.place_text(pl, opt.tun, opt.names)
      elseif opt and opt.high and p.midi and p.midi >= opt.tun.open[1] + 12 then -- (a high note)
        extra = pl and Key.place_text(pl, opt.tun, opt.names) or Key.place(p.midi, opt.tun, opt.names)
      end
      local s = names[p.pc] .. extra
      if p.slide and opt then s = SLIDE_TEXT[opt.slide or "slash"](s) end
      t[k] = s
    end
    keys[i] = table.concat(t, " - ")
  end
  local start, rows = Group.sections(keys), {}
  for i, parts in ipairs(slices) do
    if #parts > 0 and (keys[i] ~= keys[i - 1] or start[i]) then
      local row = { t = parts[1].t, text = keys[i], doubt = false, ts = {} }
      for k, p in ipairs(parts) do
        row.ts[k] = p.t
        if p.doubt then row.doubt = true end
      end
      rows[#rows + 1] = row
    end
  end
  table.sort(rows, function(a, b) return a.t < b.t end)
  return rows
end

function Group.make(notes, mode, key, proj, t_end, opt)
  if #notes == 0 then return {} end
  local bars
  if mode == "sec" then bars = Group.second_bars(notes)
  elseif mode == "change" then bars = Group.change_bars(notes, opt ~= nil and (opt.high or opt.runs))
  else bars = Group.project_bars(proj, notes[1].t, t_end) end
  return Group.rows(notes, bars, key, opt)
end

---------------------------------------------------------------------------
-- LIST (the rows and their corrections; the project data P)
---------------------------------------------------------------------------
-- P: { key = "C minor" ("" = unknown), mode = "bar" | "sec" | "change", tuning = an id of CFG.TUNINGS,
--   src = the GUID of the bass item, rows = { { t, text, doubt, ts = { the time of each note } or nil }, ... },
--   keys = { { t, key } } (a key change from that line on), mk = { the GUIDs of the written markers (also of older
--   writes: Ctrl+Z brings them back) }, notes = { the found notes { t, t1, pc, midi, doubt } (to group them again,
--   the export and the tab) }, t_end = the end of the bass item of the last Find notes }
function List.default()
  return { key = "", mode = "bar", tuning = "std", src = "", rows = {}, keys = {}, mk = {}, notes = {} }
end
-- The fingering of the saved notes (1 for the list and the tab; the strings that the user chose stay): a place
-- { s, f } or false per note (cached until the notes or the tuning change).
function List.places(notes, tun)
  notes, tun = notes or P.notes, tun or Key.tuning(P.tuning)
  local c = R.places
  if c and c.src == notes and c.tun == tun and c.n == #notes then return c.list end
  local midis, forced = {}, {}
  for k, n in ipairs(notes) do midis[k], forced[k] = n.midi or Key.low(n.pc, tun.open[1]), n.s end
  local list = Key.finger(midis, tun, forced)
  R.places = { src = notes, tun = tun, n = #notes, list = list }
  return list
end
-- The texts of Group.rows from Settings > Notes. Simple mode: only the notes and the string and fret of high notes.
function List.opt()
  local tun = Key.tuning(P.tuning)
  local names = Key.string_names(tun, S.strings == "numbers")
  if S.simple then return { tun = tun, names = names, high = true, runs = false, slide = "off" } end
  return { tun = tun, names = names, high = S.frets, runs = S.finger, slide = S.slide }
end

function List.parse(txt)
  local p = List.default()
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "key" then p.key = v
    elseif k == "mode" then p.mode = (v == "sec" or v == "change") and v or "bar"
    elseif k == "tuning" then p.tuning = Key.tuning(v).id
    elseif k == "src" then p.src = v
    elseif k == "mk" then p.mk[#p.mk + 1] = v
    elseif k == "tend" then p.t_end = tonumber(v)
    elseif k == "note" then
      local t, t1, pc, midi, doubt, slide, s, man =
        v:match("^([%d%.%-]+)\t([%d%.%-]+)\t(%d+)\t(%d+)\t([01])\t?([01]?)\t?(%d*)\t?([01]?)$")
      if t then
        p.notes[#p.notes + 1] = { t = tonumber(t), t1 = tonumber(t1), pc = tonumber(pc) % 12, midi = tonumber(midi),
          doubt = doubt == "1", slide = slide == "1" or nil, s = (tonumber(s) or 0) > 0 and tonumber(s) or nil,
          man = man == "1" or nil }
      end
    elseif k == "keyat" then
      local t, key = v:match("^([%d%.%-]+)\t(.+)$")
      if t and tonumber(t) then p.keys[#p.keys + 1] = { t = tonumber(t), key = key } end
    elseif k == "row" then
      local t, doubt, ts, text = v:match("^([%d%.%-]+)\t([01])\t([^\t]*)\t(.+)$")
      if t and tonumber(t) then
        local row = { t = tonumber(t), text = text, doubt = doubt == "1" }
        if ts ~= "" then
          row.ts = {}
          for n in ts:gmatch("[%d%.%-]+") do row.ts[#row.ts + 1] = tonumber(n) end
        end
        p.rows[#p.rows + 1] = row
      end
    end
  end
  table.sort(p.rows, function(a, b) return a.t < b.t end)
  table.sort(p.keys, function(a, b) return a.t < b.t end)
  return p
end

function List.serialize(p)
  local t = {}
  if p.key ~= "" then t[#t + 1] = "key=" .. p.key end
  if p.mode ~= "bar" then t[#t + 1] = "mode=" .. p.mode end
  if p.tuning ~= "std" then t[#t + 1] = "tuning=" .. p.tuning end
  if p.src ~= "" then t[#t + 1] = "src=" .. p.src end
  for _, row in ipairs(p.rows) do
    local ts = {}
    for i, v in ipairs(row.ts or {}) do ts[i] = string.format("%.3f", v) end
    t[#t + 1] = string.format("row=%.4f\t%s\t%s\t%s", row.t, row.doubt and "1" or "0", table.concat(ts, ","), Util.clean(row.text))
  end
  for _, c in ipairs(p.keys) do t[#t + 1] = string.format("keyat=%.4f\t%s", c.t, c.key) end
  if p.t_end then t[#t + 1] = string.format("tend=%.4f", p.t_end) end
  for _, n in ipairs(p.notes) do
    t[#t + 1] = string.format("note=%.4f\t%.4f\t%d\t%d\t%s\t%s\t%d\t%s", n.t, n.t1, n.pc, n.midi or Key.low(n.pc, 28),
      n.doubt and "1" or "0", n.slide and "1" or "0", n.s or 0, n.man and "1" or "0")
  end
  for _, g in ipairs(p.mk) do t[#t + 1] = "mk=" .. g end
  return table.concat(t, "\n")
end

-- Before each change of the list: a step for the Undo button.
-- The list moves with the audio by d s (Tempo.align): its lines, notes, key changes and end (Undo of the list: back).
function List.shift(d)
  List.step()
  for _, row in ipairs(P.rows) do
    row.t = row.t + d
    for k, t in ipairs(row.ts or {}) do row.ts[k] = t + d end
  end
  for _, n in ipairs(P.notes) do n.t, n.t1 = n.t + d, n.t1 + d end
  for _, c in ipairs(P.keys) do c.t = c.t + d end
  if P.t_end then P.t_end = P.t_end + d end
  R.view, R.tab = nil, nil
  Util.mark_pdirty()
end
function List.step()
  R.undo[#R.undo + 1] = List.serialize(P)
  if #R.undo > CFG.UNDO_MAX then table.remove(R.undo, 1) end
end
function List.undo()
  local txt = table.remove(R.undo)
  if not txt then return end
  local mk = P.mk
  P = List.parse(txt)
  if #mk > 0 then P.mk = mk end -- (the newest IDs of the written markers; none after Finish)
  R.edit = nil
  if R.sel and not P.rows[R.sel] then R.sel = #P.rows > 0 and #P.rows or nil end
  Util.mark_pdirty()
end

function List.doubtful()
  local n = 0
  for _, row in ipairs(P.rows) do if row.doubt then n = n + 1 end end
  return n
end
-- Why row i is doubtful (UX 1 of the review of 23 November 2026): the reasons of its doubtful notes (Det.analyse's
-- why; not saved: after a reopen only "listen to it"). Kept in the row until the rows are made again.
local WHY_TEXT = { octave = "the octave is unsure (high or low?)", methods = "the 2 methods hear different notes",
  unsure = "the pitch is unclear (noise, or a muted note?)", overtone = "maybe only the overtone of the note before (a 5th up)" }
function List.why(i)
  local row = P.rows[i]
  if not (row and row.doubt) then return nil end
  if not row.why_txt then
    local t0, t1 = row.t - 0.05, P.rows[i + 1] and P.rows[i + 1].t or math.huge
    local seen, parts = {}, {}
    for _, n in ipairs(P.notes) do
      if n.t >= t0 and n.t < t1 and n.why and not seen[n.why] then seen[n.why] = true; parts[#parts + 1] = WHY_TEXT[n.why] end
    end
    row.why_txt = "Doubtful: " .. (#parts > 0 and table.concat(parts, "; ") or "listen to it") .. "."
  end
  return row.why_txt
end
-- The next doubtful row after i (it starts again at the top); nil without one.
function List.next_doubtful(i)
  local n = #P.rows
  for k = 1, n do
    local j = ((i or 0) + k - 1) % n + 1
    if P.rows[j].doubt then return j end
  end
end
-- The row that plays at a time (nil before the first one).
function List.at(t)
  local lo, hi, best = 1, #P.rows, nil
  while lo <= hi do
    local mid = (lo + hi) // 2
    if P.rows[mid].t <= t + 0.001 then best, lo = mid, mid + 1 else hi = mid - 1 end
  end
  return best
end

-- The other rows with the same notes as text.
function List.same(text, except)
  local out = {}
  for i, row in ipairs(P.rows) do if i ~= except and row.text == text then out[#out + 1] = i end end
  return out
end

-- Types the notes of a row. An empty text keeps the old one. Returns the old text when it changed.
function List.set_text(i, txt)
  local row = P.rows[i]
  txt = Util.clean(txt)
  if not row or txt == "" then return nil end
  if txt == row.text then
    if row.doubt then List.step(); row.doubt = false; Util.mark_pdirty() end -- (looked at: no longer doubtful)
    return nil
  end
  List.step()
  local old = row.text
  row.text, row.doubt, row.ts = txt, false, nil
  Util.mark_pdirty()
  return old
end
-- The same correction in other rows (1 Undo step with the first one).
function List.set_all(list, txt)
  for _, i in ipairs(list) do
    local row = P.rows[i]
    if row then row.text, row.doubt, row.ts = txt, false, nil end
  end
  Util.mark_pdirty()
end
function List.checked(i)
  if not P.rows[i] or not P.rows[i].doubt then return end
  List.step()
  P.rows[i].doubt = false
  Util.mark_pdirty()
end

function List.split_text(text)
  local t = {}
  for part in (text .. " - "):gmatch("(.-) %- ") do t[#t + 1] = part end
  return t
end
-- Joins a row with the next one.
function List.join(i)
  local a, b = P.rows[i], P.rows[i + 1]
  if not (a and b) then return end
  List.step()
  local pa, pb = List.split_text(a.text), List.split_text(b.text)
  local ts = a.ts and b.ts and #a.ts == #pa and #b.ts == #pb and {} or nil
  if ts then
    for _, v in ipairs(a.ts) do ts[#ts + 1] = v end
    for k, v in ipairs(b.ts) do if not (k == 1 and pb[1] == pa[#pa]) then ts[#ts + 1] = v end end
  end
  if pb[1] == pa[#pa] then table.remove(pb, 1) end -- (the same note goes on)
  for _, v in ipairs(pb) do pa[#pa + 1] = v end
  a.text, a.ts, a.doubt = table.concat(pa, " - "), ts, a.doubt or b.doubt
  table.remove(P.rows, i + 1)
  Util.mark_pdirty()
end
-- Splits a row in 2: at the cursor when it is inside the row, else in the middle. A row with 1 note needs the cursor
-- (the note then stands in both rows). Returns true when it did.
function List.split(i, cursor)
  local row = P.rows[i]
  if not row then return false end
  local parts = List.split_text(row.text)
  local stop = P.rows[i + 1] and P.rows[i + 1].t or math.max(row.t + 2, cursor or 0) + 0.1
  local inside = cursor and cursor > row.t + 0.02 and cursor < stop - 0.02
  if #parts < 2 and not inside then return false end
  local ts = row.ts
  if not ts or #ts ~= #parts then -- (typed notes: spread over the time of the row)
    ts = {}
    local len = math.min(stop - row.t, 4)
    for k = 1, #parts do ts[k] = row.t + len * (k - 1) / #parts end
  end
  local n = math.ceil(#parts / 2) -- the notes of the first row
  local t = ts[n + 1]
  if inside then
    n = 0
    for k = 1, #parts do if ts[k] <= cursor + 0.02 then n = k end end
    n, t = math.max(1, n), cursor
  end
  List.step()
  local a, b, ta, tb = {}, {}, {}, {}
  for k = 1, #parts do
    if k <= n then a[#a + 1], ta[#ta + 1] = parts[k], ts[k] else b[#b + 1], tb[#tb + 1] = parts[k], ts[k] end
  end
  if #b == 0 then b, tb = { parts[#parts] }, { t } end
  row.text, row.ts = table.concat(a, " - "), ta
  table.insert(P.rows, i + 1, { t = t, text = table.concat(b, " - "), doubt = row.doubt, ts = tb })
  Util.mark_pdirty()
  return true
end
-- A new row at a time, with the notes of the row before it. Returns its index.
function List.add(t)
  List.step()
  local before = List.at(t)
  local row = { t = math.max(0, t), text = before and P.rows[before].text or Key.names(List.key_at(t))[0], doubt = false }
  local i = (before or 0) + 1
  table.insert(P.rows, i, row)
  Util.mark_pdirty()
  return i
end
function List.delete(i)
  if not P.rows[i] then return end
  List.step()
  table.remove(P.rows, i)
  R.edit = nil
  R.sel = #P.rows > 0 and math.min(i, #P.rows) or nil
  Util.mark_pdirty()
end
-- Moves a row to a time (the list stays in order). Returns its new index.
function List.move(i, t)
  local row = P.rows[i]
  if not row then return nil end
  List.step()
  row.t, row.ts = math.max(0, t), nil
  table.remove(P.rows, i)
  local at = (List.at(row.t) or 0) + 1
  table.insert(P.rows, at, row)
  Util.mark_pdirty()
  return at
end
-- The key at a time: the last key change before it (P.keys), else the key of the song.
function List.key_at(t)
  local k = P.key
  for _, c in ipairs(P.keys) do
    if c.t > t + 1e-6 then break end
    k = c.key
  end
  return k
end
-- The note names of every line in the key at its time.
function List.respell()
  for _, row in ipairs(P.rows) do row.text = Key.respell(row.text, List.key_at(row.t)) end
end
-- The key change that starts at line i (its index in P.keys), or nil.
function List.key_change(i)
  local row = P.rows[i]
  if not row then return nil end
  for k, c in ipairs(P.keys) do if math.abs(c.t - row.t) < 1e-6 then return k end end
end
-- New key from line i on; key "": the key change at line i goes.
function List.key_from(i, key)
  local row = P.rows[i]
  if not row then return end
  List.step()
  local k = List.key_change(i)
  if k then table.remove(P.keys, k) end
  if key ~= "" then
    P.keys[#P.keys + 1] = { t = row.t, key = key }
    table.sort(P.keys, function(a, b) return a.t < b.t end)
  end
  List.respell()
  Util.mark_pdirty()
end
function List.set_key(key)
  if key == P.key then return end
  List.step()
  P.key = key
  List.respell()
  Util.mark_pdirty()
end
-- Groups the found notes again (the Markers dropdown).
function List.set_mode(mode)
  if mode == P.mode then return end
  List.step()
  P.mode = mode
  if #P.notes > 0 then
    P.rows = Group.make(P.notes, mode, P.key, R.proj, P.t_end, List.opt())
    List.respell()
  end
  R.sel, R.edit = nil, nil
  Util.mark_pdirty()
end
-- A correction of found note i from the tab: { midi = an octave up or down } (the string goes back to the fingering)
-- or { s = the string that the user chose }. The tab and the export use it; the list keeps its text.
function List.note_edit(i, ch)
  local n = P.notes[i]
  if not n then return end
  List.step()
  if ch.midi then n.midi, n.s = ch.midi, nil end
  if ch.s then n.s = ch.s end
  Util.mark_pdirty()
end
function List.note_delete(i)
  if not P.notes[i] then return end
  List.step()
  table.remove(P.notes, i)
  Util.mark_pdirty()
end
local function sort_notes() table.sort(P.notes, function(a, b) return a.t < b.t end) end
-- Note b becomes part of note a (a split piece of the same note): a lasts until b ends.
function List.note_join(a, b)
  for i, o in ipairs(P.notes) do
    if o == b then
      List.step()
      a.t1 = math.max(a.t1, b.t1)
      table.remove(P.notes, i)
      Util.mark_pdirty()
      return
    end
  end
end
-- The edits of the tab (only while stopped). n: a saved note; q0, q1: where the tab shows it (quarter notes). A moved
-- or added note is on the grid (man = true: the delay of the export does not move it).
function List.note_move(n, q0, q1, dq)
  if q0 + dq < 0 then return end
  List.step()
  n.t, n.t1, n.man = r.TimeMap2_QNToTime(R.proj, q0 + dq), r.TimeMap2_QNToTime(R.proj, q1 + dq), true
  sort_notes()
  Util.mark_pdirty()
end
-- A new fret on string s (the note keeps that string).
function List.note_fret(n, s, fret)
  local tun = Key.tuning(P.tuning)
  if not tun.open[s] or fret < 0 or fret > CFG.FRETS then return end
  List.step()
  n.midi, n.s = tun.open[s] + fret, s
  n.pc = n.midi % 12
  Util.mark_pdirty()
end
-- The same pitch on the next string (dir 1: the next higher string). False when it is not on the neck there.
function List.note_string(n, s, dir)
  local tun = Key.tuning(P.tuning)
  local s2 = s + dir
  local f = tun.open[s2] and n.midi - tun.open[s2]
  if not f or f < 0 or f > CFG.FRETS then return false end
  List.step()
  n.s = s2
  Util.mark_pdirty()
  return true
end
-- A new note at q (quarter notes) on string s: it lasts until the next note, at most 1 bar (4 quarter notes).
function List.note_add(q, s, fret)
  local tun = Key.tuning(P.tuning)
  if not tun.open[s] or fret < 0 or fret > CFG.FRETS then return nil end
  List.step()
  local t = r.TimeMap2_QNToTime(R.proj, q)
  local t1 = r.TimeMap2_QNToTime(R.proj, q + 4)
  for _, o in ipairs(P.notes) do if o.t > t + 1e-6 then t1 = math.min(t1, o.t); break end end
  local midi = tun.open[s] + fret
  local n = { t = t, t1 = t1, pc = midi % 12, midi = midi, s = s, man = true }
  P.notes[#P.notes + 1] = n
  sort_notes()
  Util.mark_pdirty()
  return n
end
-- "Update the list": the list again from the notes (the typed corrections go; Undo brings them back).
function List.from_notes()
  List.step()
  P.rows = Group.make(P.notes, P.mode, P.key, R.proj, P.t_end or (P.notes[#P.notes] and P.notes[#P.notes].t1) or 0,
    List.opt())
  List.respell()
  R.sel, R.edit = nil, nil
  Util.mark_pdirty()
end
-- The tuning of the song. The octaves of the found notes depend on it: Find notes again makes the list with it.
function List.set_tuning(id)
  if id == P.tuning then return end
  List.step()
  P.tuning = id
  Util.mark_pdirty()
end

---------------------------------------------------------------------------
-- PROJECT
---------------------------------------------------------------------------
function Project.read()
  local n, txt = r.GetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY)
  return (n and n > 0 and txt) or ""
end
function Project.load(txt)
  P = List.parse(txt)
  R.plast_txt, R.pdirty = txt, false
  R.sel, R.edit, R.undo, R.view, R.finish, R.ask = nil, nil, {}, nil, nil, nil
  Find.cancel()
  Tempo.cancel()
  Tempo.click_back() -- (the metronome of a Play with click: as it was before)
  R.tempo, R.tsrc = nil, nil
end
-- Writes the project data when it changed (an unchanged text does not mark the project modified).
function Project.save()
  R.pdirty = false
  if not (R.proj and r.ValidatePtr2(0, R.proj, "ReaProject*")) then return end
  local txt = List.serialize(P)
  if txt == R.plast_txt then return end
  r.SetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY, txt)
  r.MarkProjectDirty(R.proj)
  R.plast_txt = txt
end

-- Every frame: another project (a tab, or File > Open in the same tab) loads its own data. The saved text decides:
-- "Save as" keeps it, another project has another one.
function Project.update()
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if proj ~= R.proj then
    if R.pdirty then Project.save() end
    R.proj, R.projfn, R.state_cc = proj, fn, r.GetProjectStateChangeCount(proj)
    R.src_name = nil
    Project.load(Project.read())
    return
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc or fn ~= R.projfn then
    local other = fn ~= R.projfn
    R.state_cc, R.projfn, R.view, R.src_name, R.tsrc, R.tab = cc, fn, nil, nil, nil, nil -- (also the tempo: the tab)
    local txt = Project.read()
    if txt ~= R.plast_txt then Project.load(txt) -- (never write the old list into the next project)
    elseif other and txt == "" then Project.load(txt) end -- (2 projects without a list: the Undo steps go too)
    if R.find then Find.check() end
    if R.tempo then Tempo.check() end
  end
end

---------------------------------------------------------------------------
-- FIND (reads the selected bass item in steps)
---------------------------------------------------------------------------
-- The selected audio item. Returns item, take, or nil and the reason.
function Find.source()
  local n = r.CountSelectedMediaItems(R.proj)
  if n == 0 then return nil, "Select the bass item first." end
  if n > 1 then return nil, "Select 1 item only: the bass." end
  local item = r.GetSelectedMediaItem(R.proj, 0)
  local take = r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return nil, "The selected item is not audio. Select the bass item." end
  local src = r.GetMediaItemTake_Source(take)
  if not src or r.GetMediaSourceSampleRate(src) <= 0 then
    return nil, "The file of the selected item is missing or offline."
  end
  return item, take
end

-- The bass item of the list (nil when it was deleted).
function Find.item() return Util.item_by_guid(P.src) end
function Find.name(item)
  local take = item and r.GetActiveTake(item)
  return take and r.GetTakeName(take) or ""
end

-- The notes of the samples x in project time (the item starts at pos), and the tuning.
function Find.notes(x, pos, tick)
  local notes, tune = Det.analyse(x, tick, Key.tuning(P.tuning).open[1])
  for _, n in ipairs(notes) do n.t, n.t1 = n.t + pos, n.t1 + pos end
  local grid = S.splits and not S.simple and Find.grid(pos, pos + #x / CFG.SR) -- (Settings > Notes > Split repeated notes)
  if grid then notes = Det.repeats(x, notes, grid, pos) end
  return notes, tune
end
-- The 16th notes of the project between 2 times (nil when the project has no tempo marker: its grid is not the
-- song's yet, so the repeated notes are not split).
function Find.grid(t0, t1)
  if r.CountTempoTimeSigMarkers(R.proj) == 0 then return nil end
  local g, q, q1 = {}, math.ceil(r.TimeMap2_timeToQN(R.proj, t0) * 4) / 4, r.TimeMap2_timeToQN(R.proj, t1)
  while q <= q1 do g[#g + 1] = r.TimeMap2_QNToTime(R.proj, q); q = q + 0.25 end
  return g
end

function Find.begin()
  local item, take = Find.source()
  if not item then UI.notice(take, true); return end
  local _, guid = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
  local pos, len = r.GetMediaItemInfo_Value(item, "D_POSITION"), r.GetMediaItemInfo_Value(item, "D_LENGTH")
  R.find = { item = item, take = take, proj = R.proj, guid = guid, name = Find.name(item), done = 0,
    pos = pos, t_end = pos + len, rd = TP.reader(take, len) } -- (the shared audio reader: Tempo.lua)
end
-- false when the item is gone (or in another project): Find stops.
function Find.check()
  local f = R.find
  if not f then return false end
  if f.proj ~= R.proj or not r.ValidatePtr2(R.proj, f.item, "MediaItem*") or not r.ValidatePtr2(R.proj, f.take, "MediaItem_Take*") then
    Find.cancel()
    return false
  end
  return true
end
function Find.step()
  local f = R.find
  if not f or not Find.check() then return end
  f.stop = Util.now() + CFG.STEP
  while not f.co do -- (first the samples, then the notes)
    if TP.read_block(f.rd) then
      f.co = coroutine.create(function()
        return Find.notes(f.rd.x, f.pos, function(v)
          f.done = 0.05 + 0.95 * v
          if Util.now() > f.stop then coroutine.yield() end
        end)
      end)
    end
    if not f.co then f.done = 0.05 * f.rd.i / math.max(1, f.rd.n) end
    if Util.now() > f.stop then return end
  end
  local ok, notes, tune = coroutine.resume(f.co)
  if not ok then Find.cancel(); UI.notice("Find notes stopped: " .. tostring(notes), true); return end
  if coroutine.status(f.co) == "dead" then
    R.find = nil
    Find.done(f, notes, tune, f.t_end)
  end
end
function Find.cancel()
  if R.find then TP.close(R.find.rd) end
  R.find = nil
end
-- The found notes become the list (the Undo button brings the old list back).
function Find.done(f, notes, tune, t_end)
  if #notes == 0 then UI.notice("No notes found. Is this the bass item?", true); return end
  List.step()
  P.notes, P.t_end = notes, t_end
  P.src = f.guid
  P.key = Key.find(f.name) or P.key
  P.rows = Group.make(notes, P.mode, P.key, R.proj, t_end, List.opt())
  List.respell() -- (the key changes)
  R.sel, R.edit, R.src_name = nil, nil, nil
  Util.mark_pdirty()
  UI.notice(string.format("Found %d markers, %d doubtful. Tuning: A = %.0f Hz.", #P.rows, List.doubtful(), 440 * 2 ^ (tune / 12)))
end

---------------------------------------------------------------------------
-- OUT (writes the markers and the Notes track; Finish)
---------------------------------------------------------------------------
-- Every marker and region: fn(index, is_region, pos, end, name, number, guid).
function Out.each_marker(fn)
  local i = 0
  while true do
    local n, rgn, pos, e, name, num = r.EnumProjectMarkers2(R.proj, i)
    if n == 0 then return end
    local _, g = r.GetSetProjectInfo_String(R.proj, "MARKER_GUID:" .. i, "", false)
    fn(i, rgn, pos, e, name, num, g)
    i = i + 1
  end
end
function Out.delete_markers()
  local own, del = {}, {}
  for _, g in ipairs(P.mk) do own[g] = true end
  Out.each_marker(function(i, rgn, _, _, _, _, g) if not rgn and own[g] then del[#del + 1] = i end end)
  for k = #del, 1, -1 do r.DeleteProjectMarkerByIndex(R.proj, del[k]) end
  return #del
end
function Out.add_markers()
  local before = {}
  Out.each_marker(function(_, _, _, _, _, _, g) before[g] = true end)
  for i, row in ipairs(P.rows) do r.AddProjectMarker2(R.proj, false, row.t, 0, row.text, i, 0) end
  for _, c in ipairs(P.keys) do r.AddProjectMarker2(R.proj, false, c.t, 0, "Key: " .. c.key, -1, 0) end
  Out.each_marker(function(_, rgn, _, _, _, _, g) if not rgn and not before[g] then P.mk[#P.mk + 1] = g end end)
  while #P.mk > CFG.MK_MAX do table.remove(P.mk, 1) end
end

-- The track with Note Detective's mark: "1" = the Notes track (the default), "midi" = the Bass MIDI track.
function Out.find_track(mark)
  for i = 0, r.CountTracks(R.proj) - 1 do
    local tr = r.GetTrack(R.proj, i)
    local _, v = r.GetSetMediaTrackInfo_String(tr, CFG.TAG, "", false)
    if v == (mark or "1") then return tr end
  end
end
-- A new track with Note Detective's mark next to the track of the bass item: above it (the Notes track) or below it
-- (below: the Bass MIDI track).
function Out.make_track(name, mark, below)
  local item = Find.item()
  local bass = item and r.GetMediaItemTrack(item)
  local num = bass and math.floor(r.GetMediaTrackInfo_Value(bass, "IP_TRACKNUMBER"))
  local at = num and (below and num or num - 1) or (below and r.CountTracks(R.proj) or 0)
  r.InsertTrackAtIndex(at, false)
  local tr = r.GetTrack(R.proj, at)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  r.GetSetMediaTrackInfo_String(tr, CFG.TAG, mark, true)
  return tr
end
-- Deletes the items of a track that Note Detective made (other items stay).
function Out.delete_marked(tr)
  for i = r.CountTrackMediaItems(tr) - 1, 0, -1 do
    local it = r.GetTrackMediaItem(tr, i)
    local _, v = r.GetSetMediaItemInfo_String(it, CFG.TAG, "", false)
    if v == "1" then r.DeleteTrackMediaItem(tr, it) end
  end
end
-- Removes the text items of Note Detective (other items on the track stay), and the track when nothing is on it.
function Out.delete_items(keep_track)
  local tr = Out.find_track()
  if not tr then return end
  Out.delete_marked(tr)
  if not keep_track and r.CountTrackMediaItems(tr) == 0 and r.TrackFX_GetCount(tr) == 0 then Out.delete_track(tr) end
end
-- Deletes a track; the end of a folder moves to the track before it.
function Out.delete_track(tr)
  local depth = r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
  local num = math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
  local prev = num > 1 and r.GetTrack(R.proj, num - 2) or nil
  if depth < 0 and prev then
    r.SetMediaTrackInfo_Value(prev, "I_FOLDERDEPTH", r.GetMediaTrackInfo_Value(prev, "I_FOLDERDEPTH") + depth)
    r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", 0)
  end
  r.DeleteTrack(tr)
end
-- The end of the song: the end of the bass item (or 2 s after the last row).
function Out.song_end()
  local item = Find.item()
  local last = P.rows[#P.rows]
  local t = last and last.t + 2 or 0
  if item then t = math.max(t, r.GetMediaItemInfo_Value(item, "D_POSITION") + r.GetMediaItemInfo_Value(item, "D_LENGTH")) end
  return t
end
-- The text of a Notes track item: the beat of each note before it (Settings > Notes > Beat count in the Notes track;
-- only when the typed text still has 1 part per note), and a key change on its first line when no markers show it.
function Out.item_text(i, key_line)
  local row = P.rows[i]
  local text = row.text
  local parts = List.split_text(row.text)
  if S.counts and not S.simple and row.ts and #parts == #row.ts then
    local t = {}
    for k, p in ipairs(parts) do t[k] = Group.count(R.proj, row.ts[k]) .. " " .. p end
    text = table.concat(t, " · ")
  end
  local k = key_line and List.key_change(i)
  return k and ("Key: " .. P.keys[k].key .. "\n" .. text) or text
end
-- markers: markers are written too (they show the key changes).
function Out.add_items(markers)
  local tr = Out.find_track() or Out.make_track(CFG.TRACK, "1")
  local stop = Out.song_end()
  for i, row in ipairs(P.rows) do
    local e = P.rows[i + 1] and P.rows[i + 1].t or stop
    if e > row.t then
      local it = r.AddMediaItemToTrack(tr)
      r.SetMediaItemInfo_Value(it, "D_POSITION", row.t)
      r.SetMediaItemInfo_Value(it, "D_LENGTH", e - row.t)
      r.GetSetMediaItemInfo_String(it, "P_NOTES", Out.item_text(i, not markers), true)
      r.GetSetMediaItemInfo_String(it, CFG.TAG, "1", true)
    end
  end
end

-- Clear: what Note Detective wrote goes (its markers, the Notes track items, the Bass MIDI item; 1 undo step), and the
-- list (with its key changes and the found notes; the Undo button brings it back). The key, the Markers choice, the
-- tuning and the marker IDs stay (Ctrl+Z brings the markers back, and a new Write then replaces them).
function Out.clear()
  r.Undo_BeginBlock2(R.proj)
  r.PreventUIRefresh(1)
  Out.delete_markers()
  Out.delete_items(false)
  local mt = Out.find_track("midi")
  if mt then
    Out.delete_marked(mt)
    if r.CountTrackMediaItems(mt) == 0 and r.TrackFX_GetCount(mt) == 0 then Out.delete_track(mt) end
  end
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(R.proj, "Note Detective: clear", -1)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  List.step()
  P.rows, P.keys, P.src, P.notes, P.t_end = {}, {}, "", {}, nil
  R.sel, R.edit, R.written, R.src_name = nil, nil, nil, nil
  Util.mark_pdirty()
end

-- Writes the list: "markers", "track" or "both". Only Note Detective's own markers and text items are replaced.
function Out.write(what)
  if #P.rows == 0 then return end
  r.Undo_BeginBlock2(R.proj)
  r.PreventUIRefresh(1)
  Out.delete_markers()
  if what ~= "track" then Out.add_markers() end
  Out.delete_items(what ~= "markers")
  if what ~= "markers" then Out.add_items(what == "both") end
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(R.proj, "Note Detective: write notes", -1)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  R.written = List.serialize(P)
  R.pdirty = true
end

-- The song title in the name of a bass file: "Far Away-Bass-C minor-120bpm" -> "Far Away".
function Out.title(name)
  local s = name:gsub("%.%w+$", "")
  local a = s:lower():find("[%-_ ]+bass%f[%A]")
  if a and a > 1 then s = s:sub(1, a - 1) end
  s = s:gsub("_", " "):gsub("^%d+[%.%-%s]+", "")
  return Util.clean(s)
end
-- The artist in the name of the project file: "12 - The Band - Far Away" and the title "Far Away" -> "The Band".
function Out.artist(projname, title)
  local prev
  for part in (projname:gsub("%.[Rr][Pp][Pp]$", "") .. " - "):gmatch("(.-) %- ") do
    if part:lower() == title:lower() and prev and not prev:match("^%d+$") then return prev end
    prev = Util.clean(part)
  end
  return ""
end
function Out.region_name(artist, title, key)
  local t = {}
  for _, v in ipairs({ artist, title, (key:gsub(" (%l)", function(c) return " " .. c:upper() end)) }) do
    v = Util.clean(v)
    if v ~= "" then t[#t + 1] = v end
  end
  return table.concat(t, " - ")
end
-- The tracks that look like a metronome (not a folder).
function Out.click_tracks()
  local out = {}
  for i = 0, r.CountTracks(R.proj) - 1 do
    local tr = r.GetTrack(R.proj, i)
    local _, name = r.GetTrackName(tr)
    if TP.is_click(name) and r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") <= 0 then
      out[#out + 1] = { tr = tr, name = name }
    end
  end
  return out
end

function Out.finish_begin()
  local item = Find.item()
  local track = item and r.GetMediaItemTrack(item)
  local title = Out.title(Find.name(item))
  local fx = track and r.TrackFX_GetCount(track) or 0
  local f = { title = title, artist = Out.artist(R.projfn:match("([^/\\]*)$") or "", title), track = track, fx = fx,
    clicks = Out.click_tracks(), del_fx = fx > 0, del_clicks = false, open = true }
  f.del_clicks = #f.clicks > 0
  f.track_name = track and select(2, r.GetTrackName(track)) or ""
  f.fresh = R.written ~= nil and R.written == List.serialize(P)
  R.finish = f
end
-- Makes (or updates) the song region, removes what is ticked, and removes the list from the project. 1 undo step.
function Out.finish(f)
  local name = Out.region_name(f.artist, f.title, P.key)
  local item = Find.item()
  local t0 = item and r.GetMediaItemInfo_Value(item, "D_POSITION") or (P.rows[1] and P.rows[1].t or 0)
  local _, m0 = r.TimeMap2_timeToBeats(R.proj, t0)
  t0 = r.TimeMap2_beatsToTime(R.proj, 0, m0)
  local stop = Out.song_end()
  local _, m1 = r.TimeMap2_timeToBeats(R.proj, stop)
  stop = r.TimeMap2_beatsToTime(R.proj, 0, m1 + 1)
  r.Undo_BeginBlock2(R.proj)
  r.PreventUIRefresh(1)
  local num
  if name ~= "" then
    Out.each_marker(function(_, rgn, _, _, nm, n) if rgn and nm == name then num = num or n end end)
    if num then r.SetProjectMarker2(R.proj, num, true, t0, stop, name)
    else r.AddProjectMarker2(R.proj, true, t0, stop, name, -1, 0) end
  end
  if f.del_fx and f.track and r.ValidatePtr2(R.proj, f.track, "MediaTrack*") then
    for i = r.TrackFX_GetCount(f.track) - 1, 0, -1 do r.TrackFX_Delete(f.track, i) end
  end
  if f.del_clicks then
    for _, c in ipairs(f.clicks) do if r.ValidatePtr2(R.proj, c.tr, "MediaTrack*") then Out.delete_track(c.tr) end end
  end
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(R.proj, "Note Detective: finish the song", -1)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  List.step() -- (the Undo button brings the list back while the window is open)
  P = List.default()
  R.sel, R.edit, R.written, R.finish, R.src_name = nil, nil, nil, nil, nil
  Util.mark_pdirty()
  return name
end

---------------------------------------------------------------------------
-- EXPORT (the found notes as a MIDI item on the Bass MIDI track and as a .mid file)
---------------------------------------------------------------------------
-- How far the notes start after the grid, together (quarter notes; early: below 0). The detection finds the starts a
-- little late or early, the same for all notes (lessons, 23 November 2026: some notes were 1 16th late in Guitar
-- Pro; then "a little early" was taken for "almost a 16th late", and beat 1 moved to 4a). The fine part: the mean of
-- their places in a 16th, on a circle (exact, but it cannot tell a whole 16th); then of that, 1 16th earlier and 1
-- later, the one that puts the most notes on the beats (in a bass line the most common place; a tie: the smallest).
function Export.delay(qs)
  local c, s = 0, 0
  for _, q in ipairs(qs) do
    local a = 2 * math.pi * (q % 0.25) / 0.25
    c, s = c + math.cos(a), s + math.sin(a)
  end
  if c == 0 and s == 0 then return 0 end
  local f = math.atan(s, c) / (2 * math.pi) * 0.25
  local best, bn
  for _, d in ipairs({ f, f - 0.25, f + 0.25 }) do
    local n = 0
    for _, q in ipairs(qs) do
      local x = q - d
      if math.abs(x - math.floor(x + 0.5)) < 0.06 then n = n + 1 end
    end
    if not bn or n > bn or (n == bn and math.abs(d) < math.abs(best)) then best, bn = d, n end
  end
  return best
end
-- The found notes on the grid of the project: { { midi, q0, q1 } } in quarter notes, sorted, without overlaps (a note
-- ends where the next one starts; 2 notes on the same step: the first stays). step: the grid (0: as they are); the
-- common delay of the starts (Export.delay) is taken away first.
-- Also returns the delay (0 without a grid). A note that the user placed in the tab (man) is on the grid already: it
-- does not count for the delay and is not moved by it.
function Export.notes(notes, step)
  local list, qs, d = {}, {}, 0
  for _, n in ipairs(notes) do
    local q0, q1 = r.TimeMap2_timeToQN(R.proj, n.t), r.TimeMap2_timeToQN(R.proj, n.t1)
    list[#list + 1] = { midi = n.midi or Key.low(n.pc, CFG.TUNINGS[1].open[1]), q0 = q0, q1 = q1, i = #list + 1,
      doubt = n.doubt, slide = n.slide, man = n.man }
    if not n.man then qs[#qs + 1] = q0 end
  end
  if step > 0 then
    d = #qs > 0 and Export.delay(qs) or 0
    for _, x in ipairs(list) do
      local dx = x.man and 0 or d
      x.q0 = math.floor((x.q0 - dx) / step + 0.5) * step
      x.q1 = math.max(x.q0 + step, math.floor((x.q1 - dx) / step + 0.5) * step)
    end
  end
  table.sort(list, function(a, b) if a.q0 ~= b.q0 then return a.q0 < b.q0 end return a.i < b.i end)
  local out = {}
  for _, x in ipairs(list) do
    local p = out[#out]
    if not (p and x.q0 <= p.q0 + 1e-9) then
      if p and p.q1 > x.q0 then p.q1 = x.q0 end
      out[#out + 1] = x
    end
  end
  return out, d
end

-- The start of the bar of the first note (quarter notes), and the tempo changes from there to q_end:
-- { { q, bpm, num (0: no time signature), den } } (the first one: the tempo and time signature at the start).
function Export.tempos(q_start, q_end)
  local proj = R.proj
  local t0, t1 = r.TimeMap2_QNToTime(proj, q_start), r.TimeMap2_QNToTime(proj, q_end)
  local num, den, bpm = r.TimeMap_GetTimeSigAtTime(proj, t0)
  local out = { { q = q_start, bpm = bpm, num = num, den = den } }
  for k = 0, r.CountTempoTimeSigMarkers(proj) - 1 do
    local _, t, _, _, b, n, d = r.GetTempoTimeSigMarker(proj, k)
    if t > t0 + 1e-6 and t < t1 then
      out[#out + 1] = { q = r.TimeMap2_timeToQN(proj, t), bpm = b, num = n > 0 and n or 0, den = d }
    end
  end
  return out
end

-- A number of a MIDI file in 7-bit steps.
local function vlq(n)
  local b = { n & 0x7F }
  n = n >> 7
  while n > 0 do table.insert(b, 1, (n & 0x7F) | 0x80); n = n >> 7 end
  return string.char(table.unpack(b))
end
-- The bytes of a .mid file (format 0, 1 track): the notes (from Export.notes), the tempo changes (Export.tempos;
-- tick 0 = tempos[1].q) and the track name.
function Export.smf(list, tempos, name)
  local q0, ev = tempos[1].q, {}
  local function tick(q) return math.max(0, math.floor((q - q0) * CFG.PPQ + 0.5)) end
  local function add(q, order, bytes) ev[#ev + 1] = { tick(q), order, #ev, bytes } end
  add(q0, 0, "\xFF\x03" .. vlq(#name) .. name)
  for _, t in ipairs(tempos) do
    local us = math.floor(60000000 / t.bpm + 0.5)
    add(t.q, 1, "\xFF\x51\x03" .. string.char((us >> 16) & 0xFF, (us >> 8) & 0xFF, us & 0xFF))
    if t.num > 0 then
      add(t.q, 1, "\xFF\x58\x04" .. string.char(t.num, math.floor(math.log(t.den, 2) + 0.5), 24, 8))
    end
  end
  for _, x in ipairs(list) do
    add(x.q0, 3, string.char(0x90, x.midi, CFG.MIDI_VEL))
    add(x.q1, 2, string.char(0x80, x.midi, 0)) -- (a note ends before the next one starts on the same tick)
  end
  table.sort(ev, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    if a[2] ~= b[2] then return a[2] < b[2] end
    return a[3] < b[3]
  end)
  local body, last = {}, 0
  for _, e in ipairs(ev) do
    body[#body + 1] = vlq(e[1] - last) .. e[4]
    last = e[1]
  end
  body[#body + 1] = "\0\xFF\x2F\0"
  local track = table.concat(body)
  return "MThd" .. string.pack(">I4I2I2I2", 6, 0, 1, CFG.PPQ) .. "MTrk" .. string.pack(">I4", #track) .. track
end

-- The name of the export ("Far Away - Bass"), and the .mid file in the export folder (S.export_dir, else the project
-- folder; nil: no folder, the project is not saved).
function Export.name()
  local title = Out.title(Find.name(Find.item()))
  return (title ~= "" and title or "Note Detective") .. " - Bass"
end
function Export.dir()
  if S.export_dir ~= "" then return (S.export_dir:gsub("[/\\]+$", "")) end
  return R.projfn:match("^(.*)[/\\]")
end
function Export.path()
  local dir = Export.dir()
  if not dir then return nil end
  return dir .. "/" .. Export.name():gsub('[\\/:*?"<>|]', "") .. ".mid"
end

-- The MIDI item on the Bass MIDI track (below the bass; an older export of Note Detective there is replaced).
function Export.item(list, q_start)
  local proj = R.proj
  local tr = Out.find_track("midi") or Out.make_track(CFG.MIDI_TRACK, "midi", true)
  Out.delete_marked(tr)
  local it = r.CreateNewMIDIItemInProj(tr, r.TimeMap2_QNToTime(proj, q_start), r.TimeMap2_QNToTime(proj, list[#list].q1), false)
  local take = r.GetActiveTake(it)
  for _, x in ipairs(list) do
    r.MIDI_InsertNote(take, false, false, r.MIDI_GetPPQPosFromProjQN(take, x.q0), r.MIDI_GetPPQPosFromProjQN(take, x.q1),
      0, x.midi, CFG.MIDI_VEL, true)
  end
  r.MIDI_Sort(take)
  r.GetSetMediaItemTakeInfo_String(take, "P_NAME", Export.name(), true)
  r.GetSetMediaItemInfo_String(it, CFG.TAG, "1", true)
  return it
end

-- Export: the MIDI item (1 undo step) and / or the .mid file. Returns the text of the notice, and true on a problem.
function Export.run(e)
  local list = Export.notes(P.notes, e.step)
  if #list == 0 then return "Nothing to export: find the notes first.", true end
  local _, m = r.TimeMap2_timeToBeats(R.proj, r.TimeMap2_QNToTime(R.proj, list[1].q0) + 1e-6)
  local q_start = r.TimeMap2_timeToQN(R.proj, r.TimeMap2_beatsToTime(R.proj, 0, m))
  local done = {}
  if e.item then
    r.Undo_BeginBlock2(R.proj)
    r.PreventUIRefresh(1)
    Export.item(list, q_start)
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock2(R.proj, "Note Detective: export MIDI", -1)
    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()
    done[#done + 1] = "a MIDI item on the \"" .. CFG.MIDI_TRACK .. "\" track"
  end
  if e.file then
    local made = #done > 0 and ("Made " .. done[1] .. ". ") or ""
    local path = Export.path()
    if not path then return made .. "No .mid file: save the project first, or choose a folder.", true end
    r.RecursiveCreateDirectory(Export.dir(), 0)
    local f = io.open(path, "wb")
    if not f then return made .. "Could not write " .. path .. " (is it open in another program?).", true end
    f:write(Export.smf(list, Export.tempos(q_start, list[#list].q1), Export.name()))
    f:close()
    done[#done + 1] = path:match("([^/\\]*)$") .. (S.export_dir ~= "" and " in " .. S.export_dir or " in the project folder")
  end
  return string.format("Exported %d notes: %s.", #list, table.concat(done, " and "))
end

---------------------------------------------------------------------------
-- TAB (the found notes as bass tab: View > Tab; read only)
---------------------------------------------------------------------------
-- The tab of the found notes, on the 16th grid of the project (as the export) with the fingering of the whole song:
-- { bars = { { m (the measure), n16 (its 16th notes), notes = { { slot, s, f, doubt, q0, q1 } } } }, names, nstr,
--   notes (all, in order) }.
function Tab.build()
  local proj, tun = R.proj, Key.tuning(P.tuning)
  local list, delay = Export.notes(P.notes, 0.25)
  local places = List.places(P.notes, tun) -- (by the index of the saved note: x.i)
  local by_m, lo, hi, all = {}, nil, nil, {}
  local function bar(m)
    if not by_m[m] then
      local _, _, cml = r.TimeMap2_timeToBeats(proj, r.TimeMap2_beatsToTime(proj, 0, m) + 1e-6)
      by_m[m] = { m = m, n16 = math.max(1, math.floor(cml * 4 + 0.5)), notes = {} }
    end
    return by_m[m]
  end
  for _, x in ipairs(list) do
    local beat, m, cml = r.TimeMap2_timeToBeats(proj, r.TimeMap2_QNToTime(proj, x.q0) + 1e-6)
    local slot = math.floor(beat * 4 + 1e-3)
    if slot >= cml * 4 then m, slot = m + 1, 0 end
    local pl = places[x.i]
    if pl then
      local nt = { slot = slot, s = pl.s, f = pl.f, doubt = x.doubt, q0 = x.q0, q1 = x.q1, src = x.i, midi = x.midi,
        note = P.notes[x.i], txt = (x.slide and "/" or "") .. pl.f }
      table.insert(bar(m).notes, nt)
      all[#all + 1] = nt
      lo, hi = math.min(lo or m, m), math.max(hi or m, m)
    end
  end
  local bars = {}
  for m = lo or 0, hi or -1 do
    bars[#bars + 1] = bar(m)
    for _, nt in ipairs(bars[#bars].notes) do nt.bi = #bars end
  end
  return { bars = bars, notes = all, names = Key.string_names(tun, S.strings == "numbers"), nstr = #tun.open,
    src = P.notes, tuning = P.tuning, strings = S.strings, delay = delay or 0 }
end
-- The line of the tab that holds bar bi.
function Tab.line_of(tab, bi)
  for _, ln in ipairs(tab.lines or {}) do if bi >= ln.first and bi <= ln.last then return ln end end
end
-- The note of the tab of a saved note (nil: none), and its index in tab.notes (in the order of time).
function Tab.find(tab, n)
  for k, x in ipairs(tab and tab.notes or {}) do if x.note == n then return x, k end end
end
-- True when no other note starts at q (quarter notes): a bass plays 1 note at a time, so 2 notes never share a 16th.
function Tab.free(tab, q, n)
  for _, x in ipairs(tab.notes) do if x.note ~= n and math.abs(x.q0 - q) < 1e-6 then return false end end
  return true
end
-- The middle of a note of the tab (x, y from the top left of the tab), for the box of its fret.
function Tab.pos(tab, nt)
  local b, ln = tab.bars[nt.bi], Tab.line_of(tab, nt.bi)
  if not (b and ln and b.sw) then return nil end
  return CFG.TAB_LEFT + b.x + b.pad + (nt.slot + 0.5) * b.sw, ln.y + CFG.TAB_TOP + (tab.nstr - nt.s) * CFG.TAB_LINE
end
-- What is at a point of the tab (x, y: from the top left of the tab): { bi (the bar), slot (its 16th), s (the string),
-- nt (the note there, or nil) }, or nil (between the lines, before or after the bars).
function Tab.hit(tab, x, y)
  for _, ln in ipairs(tab.lines or {}) do
    local y0 = ln.y + CFG.TAB_TOP
    local s = tab.nstr - math.floor((y - y0) / CFG.TAB_LINE + 0.5)
    if s >= 1 and s <= tab.nstr and math.abs(y - (y0 + (tab.nstr - s) * CFG.TAB_LINE)) <= CFG.TAB_LINE / 2 then
      for bi = ln.first, ln.last do
        local b = tab.bars[bi]
        local bx = CFG.TAB_LEFT + b.x
        if x >= bx and x < bx + b.pad + b.n16 * b.sw then
          local slot = math.max(0, math.floor((x - bx - b.pad) / b.sw))
          for _, nt in ipairs(b.notes) do if nt.slot == slot and nt.s == s then return { bi = bi, slot = slot, s = s, nt = nt } end end
          return { bi = bi, slot = slot, s = s }
        end
      end
    end
  end
end
-- The bar (its index) and the x in the tab (from the left of the tab) of a time in quarter notes; nil outside the tab.
function Tab.x_at(tab, q)
  local beat, m = r.TimeMap2_timeToBeats(R.proj, r.TimeMap2_QNToTime(R.proj, q))
  local b = tab.bars[1] and tab.bars[m - tab.bars[1].m + 1]
  if not b or not b.sw then return nil end
  return m - tab.bars[1].m + 1, CFG.TAB_LEFT + b.x + b.pad + beat * 4 * b.sw
end
-- The lines of the tab for a width: { { first, last (bars), y } } and the height of all of them (px). Each bar gets
-- x, its 16th width sw and its start pad; the bars of a line stretch to the full width (at most CFG.TAB_STRETCH times).
function Tab.layout(tab, w)
  local lines, x, y, first = {}, 0, 0, 1
  local lh = (tab.nstr - 1) * CFG.TAB_LINE + CFG.TAB_TOP + CFG.TAB_BOTTOM
  local function close(last)
    local f = math.min(CFG.TAB_STRETCH, math.max(1, (w - CFG.TAB_LEFT - 1) / math.max(1, x)))
    local bx = 0
    for k = first, last do
      local b = tab.bars[k]
      b.x, b.sw, b.pad = bx, CFG.TAB_SLOT * f, CFG.TAB_PAD * f
      bx = bx + b.n16 * b.sw + b.pad
    end
    lines[#lines + 1] = { first = first, last = last, y = y }
  end
  for i, b in ipairs(tab.bars) do
    local bw = b.n16 * CFG.TAB_SLOT + CFG.TAB_PAD
    if x > 0 and CFG.TAB_LEFT + x + bw > w then
      close(i - 1)
      y, x, first = y + lh, 0, i
    end
    x = x + bw
  end
  if #tab.bars > 0 then close(#tab.bars); y = y + lh end
  return lines, y
end

---------------------------------------------------------------------------
-- IMP (Import tab: the notes of a Guitar Pro tab; the shared reader GP reads the file)
---------------------------------------------------------------------------
-- The bass track: the first bass track of the file (GP.kind), else the 1st track.
function Imp.bass_track(doc)
  for k, t in ipairs(doc.tracks) do
    if t.kind == "bass" then return k end
  end
  return 1
end
-- The tuning of CFG.TUNINGS with these open strings (nil: none).
function Imp.tuning(open)
  for _, t in ipairs(CFG.TUNINGS) do
    if #t.open == #open then
      local same = true
      for k, v in ipairs(open) do if t.open[k] ~= v then same = false end end
      if same then return t end
    end
  end
end
-- Where the tab goes: the quarter note of the project where the tab starts (list = GP.notes), and true when it was
-- lined up with a found note. With found notes (only Find's: never the notes of an import or of the tab, man; a 2nd
-- import must not line up with a wrong 1st one): the first note of the tab exactly on the very first found note
-- (decided 23 November 2026 by the user; before: the bar where the most notes matched, on the grid: it did not line
-- up). Else bar 1 of Set tempo (this session), else the bar of the edit cursor.
function Imp.start(list)
  local proj, first = R.proj, nil
  for _, n in ipairs(P.notes) do if not n.man and (not first or n.t < first) then first = n.t end end
  if first and list[1] then return r.TimeMap2_timeToQN(proj, first) - list[1].q, true end
  local tm, t = R.tempo, r.GetCursorPositionEx(proj)
  if tm and tm.beats and tm.i0 then t = tm.beats[tm.i0] end
  local beat, m, cml = r.TimeMap2_timeToBeats(proj, t)
  if beat > cml - 0.5 then m = m + 1 end -- (just before a bar line: that bar)
  return r.TimeMap2_timeToQN(proj, r.TimeMap2_beatsToTime(proj, 0, m)), false
end
-- Import: the notes of the tab replace the found notes (strings and frets of the tab; the tuning of the tab when it is
-- in the list), the tab starting at the quarter note q0 of the project; the list is made again from them (Undo brings
-- all back). Returns the number of notes.
function Imp.apply(list, open, q0)
  local proj = R.proj
  List.step()
  local tun = Imp.tuning(open)
  if tun then P.tuning = tun.id end
  P.notes = {}
  for _, x in ipairs(list) do
    P.notes[#P.notes + 1] = { t = r.TimeMap2_QNToTime(proj, q0 + x.q), t1 = r.TimeMap2_QNToTime(proj, q0 + x.q + x.len),
      pc = x.midi % 12, midi = x.midi, s = x.s, man = true }
  end
  P.t_end = P.notes[#P.notes] and P.notes[#P.notes].t1 or nil
  P.rows = Group.make(P.notes, P.mode, P.key, proj, P.t_end or 0, List.opt())
  List.respell()
  R.sel, R.edit = nil, nil
  Util.mark_pdirty()
  return #P.notes
end

---------------------------------------------------------------------------
-- TEMPO (Tempo and bars: the shared Tempo.lua, with what Note Detective adds: the song is the bass item, its first
-- note the first found note of the list, the list moves with the audio)
---------------------------------------------------------------------------
Beat = TP.Beat
Tempo = TP.new({
  R = R, name = "Note Detective", undo_try = CFG.UNDO_TRY, note = "bass note",
  notice = function(text, warn) UI.notice(text, warn) end,
  -- the song: the selected bass item, else the bass item of the list (item, start, end; or nil and why)
  song = function()
    local item = Find.source() or Find.item()
    if not item then return nil, "Select the bass item first: Note Detective sets the tempo while it plays." end
    local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
    return item, pos, pos + r.GetMediaItemInfo_Value(item, "D_LENGTH")
  end,
  -- the first found note of the list (when the list is of this item; else the first sound of the item)
  first_note = function(tm)
    if P.src ~= tm.song.guid then return nil end
    local first
    for _, n in ipairs(P.notes) do if not n.man and (not first or n.t < first) then first = n.t end end
    return first
  end,
  shift = function(d, tm) if P.src == tm.song.guid and #P.notes > 0 then List.shift(d) end end, -- (the list too)
  written = function() R.view, R.tab = nil, nil end, -- (the bar numbers of the list, the bars of the tab)
  set_extra = function(d)
    local s = ""
    if d and math.abs(d) >= 0.0005 and #P.mk > 0 then s = s .. " Write again: the markers follow the audio." end
    if #P.rows > 0 and P.mode == "bar" then s = s .. " Click Find notes again: the markers follow the new bars." end
    return s
  end,
})

---------------------------------------------------------------------------
-- TESTS: tests/notedetective.lua sets NoteDetectiveTest: hand it the modules and do not start the UI
---------------------------------------------------------------------------
if TESTING then
  function UI.notice(text, warn) R.notice = { text = text, warn = warn } end
  local test = rawget(_G, "NoteDetectiveTest")
  test.CFG, test.S, test.R, test.Util, test.Key, test.Det, test.Group = CFG, S, R, Util, Key, Det, Group
  test.List, test.Project, test.Find, test.Out, test.Beat, test.Tempo, test.Export = List, Project, Find, Out, Beat, Tempo, Export
  test.Tab, test.Imp, test.GP, test.TP = Tab, Imp, GP, TP
  test.get_P = function() return P end
  test.set_P = function(p) P = p end
  return
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local ctx = ImGui.CreateContext(CFG.TITLE)
local font = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE)
local bold = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE, ImGui.FontFlags_Bold())
local head_font = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE_BOLD, ImGui.FontFlags_Bold())
ImGui.Attach(ctx, font); ImGui.Attach(ctx, bold); ImGui.Attach(ctx, head_font)

local HELP_INTRO = "Note Detective listens to a separated bass track, finds its notes and writes them as markers. "
  .. "You check the list first, so nothing lands in the project before you say so."
-- The Help topics (the "?" button): 1 open at a time.
local HELP_TOPICS = {
  { title = "Getting started", text = [[
1. Separate the song and put the bass file on a track.
2. Select the bass item and click "Find notes".
3. Check the list. Yellow lines are doubtful: click one to hear it, point at it to see why.
4. Click "Write". One Ctrl+Z takes it all away again.

No plugins needed: Note Detective reads the file itself, so an octave shifter or a tuner on the track changes nothing.

REAPER's bars not on the song yet? Do "Tempo and bars" first (see below), then Find notes.]] },
  { title = "Tempo and bars", text = [[
Want the markers on the real bars of the song? Set the tempo first.

1. Select the bass item. Pick the track to listen to in "Beats from": the metronome (click) track is best, else the drums.
2. Click "Find tempo". Twice or half the real tempo? Click "x2" or "1/2".
3. Click "Play with click": REAPER plays from bar 1 with its metronome. Is the click on the "1"? Else move bar 1 with "< 1 beat" or "1 beat >".
4. A bar with only 3 beats? Put the edit cursor in it and click "+ Add" next to Short bars.
5. Click "Set tempo". The song's audio then moves a few ms, so the first bass note sits exactly on the nearest beat. One Ctrl+Z takes both back. The section folds, so the list has room (click its title to open it).

Style: "1 tempo" is 1 steady grid. "Follow the song" puts a tempo marker on every bar, so the bars stay on the drums of a song that speeds up or slows down. Note Detective suggests one for the song.

Only this song changes: its items move only by that small step (all items that lie mostly inside the song, and the list with them; a backing track of the whole set stays), a new bar starts on bar 1, and after the song the old tempo goes on. The count-in before bar 1 gets whole bars at the song tempo too, back to the start of the bass item. Other songs, items and markers keep their places.]] },
  { title = "Checking the list", text = [[
Click a line: REAPER plays from there. Double-click it (or press F2) to type other notes. You can add anything, for example a string and a fret: F (D 3).

Same mistake in more places? After a correction, Note Detective offers to change the other lines with the same notes too. The Places column shows how many there are.

Yellow but right? Click "OK" in the line, or right-click > Not doubtful.

Join puts a line together with the next one. Split cuts a line at the edit cursor (or in the middle). "+ Add" makes a new line at the edit cursor (while playing: at the play position). Right-click a line for more.

Made a mistake? Undo takes back the changes of the list. Ctrl+Z is REAPER's own undo (the written markers).

Want to start again? "Clear..." removes the list and what Note Detective wrote (its markers, the Notes track items, the Bass MIDI item). It asks first; Undo and Ctrl+Z bring it back.

Want to see it as tab? View > Tab shows the found notes as bass tab, with the fingering (Simple mode off). A blue line shows where it plays; stopped, a dashed line shows the edit cursor.

Fix the tab while the song is stopped: click a note to select it (the edit cursor goes there). Left / Right selects the note before or after it, Up / Down puts it on the next string, a number gives it a new fret, Delete removes it. Double-click a note to open its box: type a new fret and press Enter, or move the note with Left / Right (a note never moves onto another one). Click an empty place on a string, type the fret and press Enter for a new note. Right-click a note for Octave up / down. A held note cut in pieces? Select the 2nd piece and press J: it joins the note before it (the same note). "Update the list" then makes the markers from your tab (it asks first).

Keys: Up / Down = previous / next line, N = next doubtful line, Space = play / stop, F2 = type the notes, Delete = delete the line.]] },
  { title = "How the notes become markers", text = [[
1 per bar: each bar gets a marker with its notes. A bar with the same notes as the bar before it gets none, so a long C stays 1 marker. A long part that comes back starts with a marker of its own.

Every note change: each new note gets its own marker.

About 2 seconds: for songs without a steady tempo. It does not use REAPER's bars.

A note that starts just before the bar line and goes on belongs to the next bar.]] },
  { title = "Key and note names", text = [[
The key comes from the file name (for example "C minor"). Wrong or missing? Pick it, and all the names change with it: Ab instead of G#. Text in brackets stays as you typed it.

The song changes key (the last chorus a step up)? Right-click the first line in the new key > New key from here. A blue line "Key: D major" shows it in the list, and Write puts a marker "Key: D major" there.

Which E is it? A note in the lowest octave of the bass has its plain name ("E" = the open E string). A higher note gets its string and fret: "E (A 7)" is the E on the A string, 7th fret. Note Detective puts it on the lowest string with fret 7 or less. Not sure about the octave? The line is yellow.

A fast run (4 notes or more in a bar)? Every note gets its string and fret, chosen for the fewest hand moves: "F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1)".

A slide into a note (the pitch glides into it for 80 ms or more) gets a mark: "/G" (Settings > Notes > Slide mark: "/C", "sl. C", "C (slide)" or Off). Very short slides are missed.

The same note played again and again (8ths, 16ths)? Note Detective listens for each pluck, so the tab and the export get them as separate notes (the markers stay short). Do "Set tempo" first: then it also checks every 16th of a long note for a pluck it missed. Long notes cut in pieces? Turn off Settings > Notes > Split repeated notes (on by default).

Too much? Settings > Notes > Simple mode (on by default): the markers show only the notes and the string and fret of a high note, and the window only the steps that you need for them.

Rather string numbers, as in tab books ("E (3 7)")? Settings > Notes > String names.

Pick the "Tuning" of the bass for the song (Standard, Half step down, Drop D, Drop C, 5-string) before Find notes. Only the names, no frets? Turn off Settings > Notes > String and fret for high notes, and Settings > Notes > Fingering for runs.]] },
  { title = "Import a Guitar Pro tab", text = [[
Have the tab of the song? Then you do not need the detection: the tab gives the exact notes, strings and frets.

1. Do "Set tempo" first, so the bars of REAPER are the bars of the song. Then "Find notes".
2. Click "Import tab..." (next to Find notes; Simple mode off) and pick the tab file (.gp, .gpx, .gp5, .gp4 or .gp3).
3. Pick the bass track. Note Detective puts the first note of the tab exactly on the first found note (empty bars at the start of the tab are fine). Wrong bar? Use "< 1 bar" or "1 bar >". Importing again? Undo the earlier import first, so the found notes are back to line up with.
4. Click "Import". The repeats are played out, and the tab replaces the found notes and the list. Undo brings them back.]] },
  { title = "Markers or a Notes track", text = [[
The dropdown next to "Write" decides what it makes: markers, text items on a "Notes" track above the bass, or both. The text items have more room than the marker names: they also show the beat of each note, counted "1 e & a" ("1 F · 2& Eb · 3 C"; off: Settings > Notes > Beat count in the Notes track).

Write again as often as you like: only Note Detective's own markers and text items are replaced.]] },
  { title = "Export to MIDI (Guitar Pro)", text = [[
Want the part in Guitar Pro, or want to hear the notes? Click "Export..." after Find notes.

It makes a MIDI item on a "Bass MIDI" track below the bass (an older export there is replaced; 1 Ctrl+Z takes it back) and a .mid file in the project folder, or in a folder of your own (Folder > Change...; it stays for all songs). Open the .mid file in Guitar Pro (File > Import > MIDI).

Set the tempo first ("Tempo and bars"), so the notes land on the right bars. Rhythm moves the notes to 16th notes (or 8th notes, or not at all).

The export uses the notes that Find notes found, not the texts of the list: your corrections in the list are not in it. Guitar Pro chooses its own strings and frets.]] },
  { title = "Finish", text = [[
Finish makes a region over the whole song with the artist, the title and the key. If you like, it also removes the plugins from the bass track and deletes the metronome track (you see what before you click).

Then the list leaves the project. The markers and the Notes track stay. Ctrl+Z brings the plugins and tracks back.]] },
  { title = "Why are some notes wrong?", text = [[
Fast fills, slides, and drums or guitars that stayed in the bass file. 2 methods listen to every note; where they disagree, the line is yellow. They can also make the same mistake, so always listen once.

A note that fades out can turn into its own overtone (a 5th higher). These lines are yellow too.]] },
  { title = "Where your stuff is saved", text = [[
In the project: the list, until you click Finish. Save the project to keep it.

In the project, also: the tuning of the song, the key changes and the found notes (for the tab and the export).

On this computer: the Light theme, the window dock, the Write choice, Settings > Notes, the export folder, and whether "Tempo and bars" is folded. The tempo is in the project itself (REAPER's tempo markers).]] },
}
local MODES = { { "bar", "1 per bar" }, { "change", "Every note change" }, { "sec", "About 2 seconds" } }
local OUTS = { { "markers", "Markers" }, { "track", "Notes track" }, { "both", "Markers and Notes track" } }

-- The theme: the same colours and sizes as Chart Cue (pushed every frame; UI.pop_style pops them).
local STYLE_COLS = {
  { "WindowBg", "WIN_BG" }, { "ChildBg", "TRANSPARENT" }, { "PopupBg", "PANEL_BG" },
  { "Border", "LINE" }, { "FrameBg", "FIELD" }, { "FrameBgHovered", "FIELD_HOVER" },
  { "FrameBgActive", "FIELD_ACTIVE" }, { "Button", "BTN" }, { "ButtonHovered", "BTN_HOVER" },
  { "ButtonActive", "BTN_ACTIVE" }, { "Header", "ACTIVE_BG" }, { "HeaderHovered", "HEADER_HOVER" },
  { "HeaderActive", "HEADER_ACTIVE" }, { "CheckMark", "ACCENT" }, { "Text", "TEXT_MAIN" },
  { "TextDisabled", "TEXT_DIM" }, { "Separator", "LINE" }, { "ScrollbarBg", "TRANSPARENT" },
  { "ScrollbarGrab", "BTN_HOVER" }, { "ScrollbarGrabHovered", "BTN_ACTIVE" },
  { "ScrollbarGrabActive", "TOGGLE_OFF" }, { "TitleBg", "TITLE_BG" }, { "TitleBgActive", "TITLE_BG_ACTIVE" },
  { "TitleBgCollapsed", "TITLE_BG" }, { "PlotHistogram", "ACCENT" }, { "TableHeaderBg", "PANEL_BG" },
  { "TableBorderLight", "LINE" },
}
for _, c in ipairs(STYLE_COLS) do c[1] = ImGui["Col_" .. c[1]]() end
local STYLE_VARS = {
  { "FrameRounding", 6 }, { "GrabRounding", 6 }, { "PopupRounding", 6 }, { "ScrollbarRounding", 6 },
  { "ChildRounding", 8 }, { "FramePadding", 10, math.floor((CFG.ROW_H - CFG.FONT_SIZE) / 2) },
  { "ItemSpacing", 8, CFG.SP_ROW }, { "WindowPadding", 8, CFG.SP_EDGE }, { "ScrollbarSize", 12 },
  { "FrameBorderSize", 0 },
}
for _, v in ipairs(STYLE_VARS) do v[1] = ImGui["StyleVar_" .. v[1]]() end
function UI.push_style()
  for _, c in ipairs(STYLE_COLS) do ImGui.PushStyleColor(ctx, c[1], COL[c[2]]) end
  for _, v in ipairs(STYLE_VARS) do
    if v[3] then ImGui.PushStyleVar(ctx, v[1], v[2], v[3]) else ImGui.PushStyleVar(ctx, v[1], v[2]) end
  end
end
function UI.pop_style()
  ImGui.PopStyleVar(ctx, #STYLE_VARS)
  ImGui.PopStyleColor(ctx, #STYLE_COLS)
end

function UI.tip(text)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
end
function UI.tip_disabled(text)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then ImGui.SetTooltip(ctx, text) end
end

-- Exact vertical gap of px pixels after the previous item (ImGui's row spacing is subtracted).
function UI.vgap(px) ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - CFG.SP_ROW + px) end

function UI.text_y(top, h)
  h = h or ImGui.GetFrameHeight(ctx)
  return top + math.floor((h - ImGui.GetFontSize(ctx)) / 2) - CFG.TEXT_LIFT
end

-- Plain text in a row of controls, as a full-height item.
function UI.row_text(text, col)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.Dummy(ctx, (ImGui.CalcTextSize(ctx, text)), ImGui.GetFrameHeight(ctx))
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, UI.text_y(y), col or COL.TEXT_MAIN, text)
end
function UI.label(text)
  ImGui.PushFont(ctx, bold)
  UI.row_text(text)
  ImGui.PopFont(ctx)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
end

-- Text cut to max_w with "..." at the end.
function UI.trunc(text, max_w)
  if (ImGui.CalcTextSize(ctx, text)) <= max_w then return text end
  local n = utf8.len(text) or #text
  while n > 1 do
    n = n - 1
    local cand = text:sub(1, (utf8.offset(text, n + 1) or (n + 1)) - 1) .. "..."
    if (ImGui.CalcTextSize(ctx, cand)) <= max_w then return cand end
  end
  return "..."
end
-- UI.trunc, kept per text until the width changes (the rows of the list: not cut again every frame).
function UI.trunc_c(text, w)
  R.tc = R.tc or {}
  local e = R.tc[text]
  if e and e.w == w then return e.s end
  local cut = UI.trunc(text, w)
  R.tc[text] = { w = w, s = cut }
  return cut
end

-- Button kinds: "primary" (blue: an action), "ghost" (text only), nil (grey).
function UI.button(label, w, h, kind)
  local n = 0
  if kind == "primary" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.ACCENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ACCENT_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACCENT_ACTIVE)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.WHITE); n = 4
  elseif kind == "ghost" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ROW_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACTIVE_BG)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.ACCENT_HOVER); n = 4
  end
  local hit = ImGui.Button(ctx, label, w or 0, h or ImGui.GetFrameHeight(ctx))
  if n > 0 then ImGui.PopStyleColor(ctx, n) end
  return hit
end
function UI.btn_w(label, min_w)
  return math.max(min_w or 0, math.ceil((ImGui.CalcTextSize(ctx, label)) + 22))
end

-- Toggle switch (in place of a tick box). Returns changed, new value.
function UI.toggle(id, v)
  local h = math.floor(ImGui.GetFrameHeight(ctx))
  local th = math.min(20, h - 4)
  local tw = math.floor(th * 1.8)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, id, tw, h)
  local hov, clk = ImGui.IsItemHovered(ctx), ImGui.IsItemClicked(ctx)
  if clk then v = not v end
  local ty = y + math.floor((h - th) / 2)
  local dl = ImGui.GetWindowDrawList(ctx)
  local track = v and (hov and COL.ACCENT_HOVER or COL.ACCENT) or (hov and COL.BTN_ACTIVE or COL.TOGGLE_OFF)
  ImGui.DrawList_AddRectFilled(dl, x, ty, x + tw, ty + th, track, th / 2)
  ImGui.DrawList_AddCircleFilled(dl, v and (x + tw - th / 2) or (x + th / 2), ty + th / 2, th / 2 - 3, COL.WHITE)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  return clk, v
end
-- A toggle with its text at the right.
function UI.toggle_line(label, v, tip)
  local ch, nv = UI.toggle("##tl_" .. label, v)
  if tip then UI.tip(tip) end
  ImGui.SameLine(ctx, 0, 8)
  UI.row_text(label)
  if ImGui.IsItemClicked(ctx) then ch, nv = true, not v end
  if tip then UI.tip(tip) end
  return ch, nv
end

-- A question with 2 buttons (a popup in the window). no / no_fn: the 2nd button (else "Cancel").
function UI.ask(text, yes, fn, no, no_fn)
  R.ask = { text = text, yes = yes, fn = fn, no = no, no_fn = no_fn, open = true }
end
-- A short notice at the bottom of the window (grey; warn: orange); it goes away after CFG.NOTICE_SEC.
function UI.notice(text, warn)
  R.notice = { text = tostring(text or ""), warn = warn, t = Util.now() + CFG.NOTICE_SEC }
end
function UI.notice_h(w) -- the height of the notice (0: none)
  local n = R.notice
  if n and Util.now() > n.t then R.notice = nil; n = nil end
  if not n then return 0 end
  local _, h = ImGui.CalcTextSize(ctx, n.text, nil, nil, false, w)
  return math.min(h, 3 * ImGui.GetTextLineHeight(ctx)) + 6
end
function UI.draw_ask()
  local a = R.ask
  if not a then return end
  if a.open then ImGui.OpenPopup(ctx, "Note Detective##ask"); a.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if ImGui.BeginPopupModal(ctx, "Note Detective##ask", nil, ImGui.WindowFlags_AlwaysAutoResize()) then
    ImGui.PushTextWrapPos(ctx, 360)
    ImGui.Text(ctx, a.text)
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    local no = a.no or "Cancel"
    if UI.button(a.yes, UI.btn_w(a.yes, 120)) then R.ask = nil; ImGui.CloseCurrentPopup(ctx); a.fn() end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button(no, UI.btn_w(no, 90)) then
      R.ask = nil
      ImGui.CloseCurrentPopup(ctx)
      if a.no_fn then a.no_fn() end
    end
    ImGui.EndPopup(ctx)
  else
    R.ask = nil
  end
end

function UI.draw_gear_icon(dl, cx, cy, col)
  for k = 0, 7 do
    local a = k * math.pi / 4
    local c, sn = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * 5, cy + sn * 5, cx + c * 8.5, cy + sn * 8.5, col, 3)
  end
  ImGui.DrawList_AddCircle(dl, cx, cy, 4.5, col, 0, 3)
end

-- The texts of the list (rebuilt after a change of the list or the project, not every frame).
function UI.view()
  if R.view then return R.view end
  local count, v = {}, { n_doubt = 0 }
  for _, row in ipairs(P.rows) do count[row.text] = (count[row.text] or 0) + 1 end
  -- the lines of the table: the rows, and a "Key: D major" line before the row where a key change starts
  v.items, v.item_of = {}, {}
  for i, row in ipairs(P.rows) do
    v[i] = { num = tostring(i), bar = Group.bar_text(R.proj, row.t), places = tostring(count[row.text]) }
    if row.doubt then v.n_doubt = v.n_doubt + 1 end
    local k = List.key_change(i)
    if k then v.items[#v.items + 1] = { key = "Key: " .. P.keys[k].key, row = i } end
    v.items[#v.items + 1] = { row = i }
    v.item_of[i] = #v.items
  end
  v.status = #P.rows == 0 and "" or string.format("%d %s, %d doubtful", #P.rows, #P.rows == 1 and "marker" or "markers", v.n_doubt)
  R.view = v
  return v
end

-- Plays from a time (while playing: jumps there).
function UI.play_at(t)
  local playing = r.GetPlayStateEx(R.proj) & 1 == 1
  r.SetEditCurPos2(R.proj, t, true, playing)
  if not playing then r.OnPlayButtonEx(R.proj) end
end
-- Plays from a row.
function UI.play_row(i)
  local row = P.rows[i]
  if not row then return end
  R.sel = i
  UI.play_at(row.t)
end

-- The Tab view: the lines of bars (only the visible ones are drawn); doubtful notes are yellow. Playing: a blue line at
-- the play position (its line scrolls into view); a click plays from a note. Stopped: a grey line at the edit cursor; a
-- click on a note selects it (blue box; the keys: UI.tab_keys), a double-click plays from it, a click on an empty 16th
-- of a string opens a box for the fret of a new note. Right-click a note: its menu.
function UI.draw_tab(h)
  if #P.notes == 0 then
    ImGui.Dummy(ctx, 0, 4)
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No notes yet. Select the bass item and click Find notes.")
    return
  end
  local tab = R.tab
  if not tab or tab.src ~= P.notes or tab.tuning ~= P.tuning or tab.strings ~= S.strings then
    tab = Tab.build()
    R.tab = tab
  end
  if not ImGui.BeginChild(ctx, "##tab", 0, h) then return end
  -- the top line: the tempo hint (no tempo marker: REAPER's default grid, not the song's bars) and Update the list
  local aw, uw = ImGui.GetContentRegionAvail(ctx), UI.btn_w("Update the list")
  if r.CountTempoTimeSigMarkers(R.proj) == 0 then
    UI.row_text(UI.trunc_c("Set the tempo first: the bars are not the song's yet.", math.max(40, aw - uw - 8)), COL.YELLOW)
    ImGui.SameLine(ctx, math.max(0, aw - uw))
  else
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, aw - uw))
  end
  if UI.button("Update the list", uw, nil, "ghost") then
    UI.ask("Make the list again from the tab? Your typed corrections in the list are replaced (the Undo button brings them back).",
      "Update", List.from_notes)
  end
  UI.tip("The list (the markers) again from the notes of the tab, with your corrections of the tab.")
  local w = ImGui.GetContentRegionAvail(ctx)
  if tab.w ~= w then tab.lines, tab.h = Tab.layout(tab, w); tab.w = w end
  local ox, oy = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##tabarea", math.max(1, w), math.max(1, tab.h))
  local lclick, rclick = ImGui.IsItemClicked(ctx, 0), ImGui.IsItemClicked(ctx, 1)
  local dbl = lclick and ImGui.IsMouseDoubleClicked(ctx, 0)
  local playing = r.GetPlayStateEx(R.proj) & 1 == 1
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, playing and "Click a note: play from there. (Stop to edit.)"
      or "Click a note: select it, the cursor goes there (Left / Right: the note before / after, Up / Down: another string, Delete, a number = the fret, J = join with the note before). Double-click: its box (the fret; Left / Right move it). Click an empty place on a string: a new note. Right-click: more.")
  end
  local mx, my = ImGui.GetMousePos(ctx)
  local hit = (lclick or rclick) and Tab.hit(tab, mx - ox, my - oy)
  local dl, fs = ImGui.GetWindowDrawList(ctx), ImGui.GetFontSize(ctx)
  local sy = ImGui.GetScrollY(ctx)
  local lh = (tab.nstr - 1) * CFG.TAB_LINE + CFG.TAB_TOP + CFG.TAB_BOTTOM
  for _, ln in ipairs(tab.lines) do
    if ln.y + lh >= sy and ln.y <= sy + h then
      local y0 = oy + ln.y + CFG.TAB_TOP -- (the top string)
      local yb = y0 + (tab.nstr - 1) * CFG.TAB_LINE
      local lb = tab.bars[ln.last]
      local x_end = ox + CFG.TAB_LEFT + lb.x + lb.n16 * lb.sw + lb.pad
      -- a text centred on a point (digits have no descent: 1 px lower than the middle of the line height)
      local function centre(cx, cy, col, txt)
        local tw, th = ImGui.CalcTextSize(ctx, txt)
        ImGui.DrawList_AddText(dl, cx - tw / 2, cy - th / 2 + 1, col, txt)
        return tw, th
      end
      for s = 1, tab.nstr do
        local ys = y0 + (tab.nstr - s) * CFG.TAB_LINE
        centre(ox + CFG.TAB_LEFT / 2 - 2, ys, COL.TEXT_DIM, tab.names[s])
        ImGui.DrawList_AddLine(dl, ox + CFG.TAB_LEFT, ys, x_end, ys, COL.LINE, 1)
      end
      ImGui.DrawList_AddLine(dl, x_end, y0, x_end, yb, COL.TEXT_DIM, 1)
      for bi = ln.first, ln.last do
        local b = tab.bars[bi]
        local bx = ox + CFG.TAB_LEFT + b.x
        ImGui.DrawList_AddLine(dl, bx, y0, bx, yb, COL.TEXT_DIM, 1)
        ImGui.DrawList_AddText(dl, bx + 2, oy + ln.y + 2, COL.TEXT_DIM, tostring(b.m + 1))
        for beat = 0, b.n16 // 4 - 1 do -- (the beats, under the middle of their 16th)
          centre(bx + b.pad + (beat * 4 + 0.5) * b.sw, yb + fs, COL.TEXT_DIM, tostring(beat + 1))
        end
        for _, nt in ipairs(b.notes) do
          local x, y = bx + b.pad + (nt.slot + 0.5) * b.sw, y0 + (tab.nstr - nt.s) * CFG.TAB_LINE
          local tw, th = ImGui.CalcTextSize(ctx, nt.txt)
          ImGui.DrawList_AddRectFilled(dl, x - tw / 2 - 2, y - th / 2, x + tw / 2 + 2, y + th / 2, COL.PANEL_BG)
          centre(x, y, nt.doubt and COL.YELLOW or COL.TEXT_MAIN, nt.txt)
          if R.tab_sel and nt.note == R.tab_sel then -- (the selected note: a blue box)
            ImGui.DrawList_AddRect(dl, x - tw / 2 - 4, y - th / 2 - 1, x + tw / 2 + 4, y + th / 2 + 1, COL.ACCENT, 3, 0, 2)
          end
        end
      end
    end
  end
  -- the position line: playing, blue at the play position (its line in view); stopped, grey at the edit cursor
  -- (the found notes of the tab are moved by the delay of the export: the line too, so it meets them)
  local pos = playing and r.GetPlayPositionEx(R.proj) or r.GetCursorPositionEx(R.proj)
  local pbi, px = Tab.x_at(tab, r.TimeMap2_timeToQN(R.proj, pos) - tab.delay)
  local pln = pbi and Tab.line_of(tab, pbi)
  if pln then
    local y0 = oy + pln.y + CFG.TAB_TOP
    local y1 = y0 + (tab.nstr - 1) * CFG.TAB_LINE + 8
    if playing then
      ImGui.DrawList_AddLine(dl, ox + px, y0 - 8, ox + px, y1, COL.ACCENT, 2)
    else -- (dashed: not a bar line)
      for y = y0 - 8, y1, 6 do ImGui.DrawList_AddLine(dl, ox + px, y, ox + px, math.min(y + 3, y1), COL.TEXT_MAIN, 1) end
    end
    if playing and R.tab_line ~= pln.y then
      R.tab_line = pln.y
      ImGui.SetScrollY(ctx, math.max(0, pln.y - CFG.TAB_LINE))
    end
  end
  -- the clicks
  if rclick and hit and hit.nt then
    R.tab_note, R.tab_sel = hit.nt.src, hit.nt.note
    ImGui.OpenPopup(ctx, "##tabnote")
  elseif lclick and hit then
    if hit.nt and dbl and not playing then -- (double-click: the box of its fret; Left / Right then move it)
      R.tab_sel = hit.nt.note
      R.tab_add = { note = hit.nt.note, s = hit.nt.s, txt = tostring(hit.nt.f), focus = true }
    elseif hit.nt then -- (a click: select it, and the cursor goes there)
      R.tab_sel, R.tab_add = hit.nt.note, nil
      UI.tab_cursor(hit.nt.note, playing)
    elseif not playing then -- (an empty 16th of a string: a box for the fret of a new note)
      local b, ln = tab.bars[hit.bi], Tab.line_of(tab, hit.bi)
      local q = r.TimeMap2_timeToQN(R.proj, r.TimeMap2_beatsToTime(R.proj, 0, b.m)) + hit.slot * 0.25
      if Tab.free(tab, q) then
        R.tab_add = { q = q, s = hit.s, x = CFG.TAB_LEFT + b.x + b.pad + (hit.slot + 0.5) * b.sw,
          y = ln.y + CFG.TAB_TOP + (tab.nstr - hit.s) * CFG.TAB_LINE, txt = "", focus = true }
        R.tab_sel = nil
      else
        UI.notice("Another note starts on this 16th (on another string): 1 note at a time.", true)
      end
    end
  end
  UI.tab_add_box(ox, oy, playing)
  UI.tab_menu()
  ImGui.EndChild(ctx)
end
-- Selecting a note moves the cursor there: stopped, the edit cursor; playing, the playback jumps there.
function UI.tab_cursor(n, playing)
  if playing then UI.play_at(n.t) else r.SetEditCurPos2(R.proj, n.t, true, false) end
end
-- Moves a note of the tab by dq quarter notes, never onto another note: it ends where the next note starts.
function UI.tab_move(n, dq)
  local tab = R.tab
  local nt = Tab.find(tab, n)
  if not nt or nt.q0 + dq < 0 then return end
  local q = nt.q0 + dq
  if not Tab.free(tab, q, n) then UI.notice("Another note is there: a note does not move over another one.", true); return end
  local q1 = nt.q1 + dq
  for _, x in ipairs(tab.notes) do
    if x.note ~= n and x.q0 > q + 1e-6 then q1 = math.min(q1, x.q0) end
  end
  List.note_move(n, nt.q0, q1 - dq, dq)
end
-- The box of a fret: a new note (a.q: where, a.s: the string; Enter adds it) or a note of the tab (a.note: Enter = its
-- new fret; Left / Right move the note, as long as the box is open). Escape or a click elsewhere closes it.
function UI.tab_add_box(ox, oy, playing)
  local a = R.tab_add
  if not a then return end
  if playing then R.tab_add = nil; return end
  local x, y = a.x, a.y
  if a.note then -- (it follows the note when it moves)
    local nt = Tab.find(R.tab, a.note)
    if nt then x, y = Tab.pos(R.tab, nt) end
    if not x then R.tab_add = nil; return end
  end
  ImGui.SetCursorScreenPos(ctx, ox + x - 16, oy + y - ImGui.GetFrameHeight(ctx) / 2)
  ImGui.SetNextItemWidth(ctx, 32)
  if a.focus then ImGui.SetKeyboardFocusHere(ctx); a.focus = nil end
  local enter, txt = ImGui.InputText(ctx, "##tabadd", a.txt,
    ImGui.InputTextFlags_CharsDecimal() | ImGui.InputTextFlags_EnterReturnsTrue() | ImGui.InputTextFlags_AutoSelectAll())
  a.txt = txt
  UI.tip(a.note and "Its fret, then Enter. Left / Right: move the note a 16th. Escape: close." or "The fret of the new note, then Enter.")
  if a.note and ImGui.IsItemActive(ctx) then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow(), true) then UI.tab_move(a.note, -0.25)
    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow(), true) then UI.tab_move(a.note, 0.25) end
  end
  if enter then
    local f = tonumber(txt)
    if a.note then
      if f then List.note_fret(a.note, a.s, math.floor(f)) end
      R.tab_add = nil
    else
      local n = f and List.note_add(a.q, a.s, math.floor(f))
      R.tab_add, R.tab_sel = nil, n
      if not n then UI.notice(string.format("A fret from 0 to %d, please.", CFG.FRETS), true) end
    end
  elseif ImGui.IsItemDeactivated(ctx) then
    R.tab_add = nil
  end
end
-- The keys of the tab (stopped, a note selected): Left / Right = select the note before / after it (the cursor goes
-- there), Up / Down = the same pitch on the next string, Delete, a number = its fret (2 digits within CFG.TAB_DIGITS s:
-- "1" then "2" = 12). (Moving a note: in its box, after a double-click.)
local DIGIT_KEYS
function UI.tab_keys()
  local n = R.tab_sel
  if not n or r.GetPlayStateEx(R.proj) & 1 == 1 or not R.tab then return end
  local nt, k = Tab.find(R.tab, n)
  if not nt then return end
  local function key(kc, rep) return ImGui.IsKeyPressed(ctx, kc, rep) end
  if key(ImGui.Key_LeftArrow(), true) or key(ImGui.Key_RightArrow(), true) then
    local o = R.tab.notes[k + (key(ImGui.Key_LeftArrow(), true) and -1 or 1)]
    if o then
      R.tab_sel = o.note
      UI.tab_cursor(o.note, false)
    end
  elseif key(ImGui.Key_UpArrow(), false) or key(ImGui.Key_DownArrow(), false) then
    if not List.note_string(n, nt.s, key(ImGui.Key_UpArrow(), false) and 1 or -1) then
      UI.notice("That note is not on the neck of the next string.", true)
    end
  elseif key(ImGui.Key_Delete(), false) then
    for i, o in ipairs(P.notes) do if o == n then List.note_delete(i); break end end
    R.tab_sel = nil
  elseif key(ImGui.Key_J(), false) then -- (a split piece: joins the note before, when it is the same note)
    local o = R.tab.notes[k - 1]
    if o and o.midi == nt.midi then
      List.note_join(o.note, n)
      R.tab_sel = o.note
    else
      UI.notice("J joins a note with the note before it, when both are the same note.", true)
    end
  else
    if not DIGIT_KEYS then
      DIGIT_KEYS = {}
      for d = 0, 9 do DIGIT_KEYS[d] = { ImGui["Key_" .. d](), ImGui["Key_Keypad" .. d]() } end
    end
    for d = 0, 9 do
      if key(DIGIT_KEYS[d][1], false) or key(DIGIT_KEYS[d][2], false) then
        local now, last = Util.now(), R.tab_num
        local txt = (last and last.n == n and now - last.t < CFG.TAB_DIGITS) and (last.txt .. d) or tostring(d)
        if tonumber(txt) > CFG.FRETS then txt = tostring(d) end
        R.tab_num = { txt = txt, t = now, n = n }
        List.note_fret(n, nt.s, tonumber(txt))
        break
      end
    end
  end
end
-- The right-click menu of a note in the tab: an octave up or down, another string, delete.
function UI.tab_menu()
  if not ImGui.BeginPopup(ctx, "##tabnote") then return end
  local i = R.tab_note
  local n = i and P.notes[i]
  if not n then
    ImGui.CloseCurrentPopup(ctx)
  else
    local tun = Key.tuning(P.tuning)
    local open, midi = tun.open, n.midi or Key.low(n.pc, tun.open[1])
    local done
    if ImGui.MenuItem(ctx, "Octave up", nil, false, midi + 12 <= open[#open] + CFG.FRETS) then
      List.note_edit(i, { midi = midi + 12 }); done = true
    end
    if ImGui.MenuItem(ctx, "Octave down", nil, false, midi - 12 >= open[1]) then
      List.note_edit(i, { midi = midi - 12 }); done = true
    end
    ImGui.Separator(ctx)
    local names = Key.string_names(tun, S.strings == "numbers")
    local cur = (List.places() or {})[i]
    for s = #open, 1, -1 do
      local f = midi - open[s]
      if f >= 0 and f <= CFG.FRETS then
        local on = cur and cur.s == s
        if ImGui.MenuItem(ctx, string.format("String %s, fret %d", names[s], f), nil, on) and not on then
          List.note_edit(i, { s = s }); done = true
        end
      end
    end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Delete the note") then List.note_delete(i); done = true end
    if done then UI.notice("Changed. The tab and the export use it; the list keeps its text (type it there if needed). Undo takes it back.") end
  end
  ImGui.EndPopup(ctx)
end
function UI.select(i, play)
  if not P.rows[i] then return end
  R.scroll_to = i
  if play then UI.play_row(i) else R.sel = i end
end
function UI.edit_row(i)
  if not P.rows[i] then return end
  R.sel = i
  R.edit = { i = i, txt = P.rows[i].text, focus = true }
end
-- The cursor of Split, + Add and Move: the play position while playing, else the edit cursor.
function UI.cursor()
  if r.GetPlayStateEx(R.proj) & 1 == 1 then return r.GetPlayPositionEx(R.proj) end
  return r.GetCursorPositionEx(R.proj)
end
-- The typed notes of a row; then the question about the same notes in other rows.
function UI.commit_edit(i, txt)
  local old = List.set_text(i, txt)
  if not old then return end
  local same, new = List.same(old, i), P.rows[i].text
  if #same == 0 then return end
  UI.ask(string.format("%d other %s the same notes (%s). Change %s to %s too?", #same, #same == 1 and "place has" or "places have",
    old, #same == 1 and "it" or "them", new), string.format("Change all %d", #same + 1),
    function() List.set_all(same, new) end, "Only this one")
end
function UI.split(i)
  if not List.split(i, UI.cursor()) then
    UI.notice("1 note only: put the edit cursor where the new line starts, then Split.", true)
  end
end
function UI.find()
  if #P.rows > 0 then
    UI.ask("Find the notes again? The new list replaces this one (Undo brings it back).", "Find notes", Find.begin)
  else
    Find.begin()
  end
end

function UI.row_menu()
  if R.menu_open then R.menu_open = nil; ImGui.OpenPopup(ctx, "##row_menu") end
  if not ImGui.BeginPopup(ctx, "##row_menu") then return end
  local i = R.menu_row
  local row = i and P.rows[i]
  if not row then ImGui.CloseCurrentPopup(ctx)
  else
    if ImGui.MenuItem(ctx, "Type the notes...", "F2") then UI.edit_row(i) end
    if ImGui.MenuItem(ctx, "Not doubtful", nil, false, row.doubt) then List.checked(i) end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Join with the next line", nil, false, P.rows[i + 1] ~= nil) then List.join(i) end
    if ImGui.MenuItem(ctx, "Split") then UI.split(i) end
    if ImGui.MenuItem(ctx, "Move to the edit cursor") then R.sel = List.move(i, r.GetCursorPositionEx(R.proj)) end
    ImGui.Separator(ctx)
    if ImGui.BeginMenu(ctx, "New key from here") then
      local cur = List.key_at(row.t)
      for _, k in ipairs(Key.LIST) do
        if ImGui.MenuItem(ctx, k, nil, k == cur) and k ~= cur then List.key_from(i, k) end
      end
      ImGui.EndMenu(ctx)
    end
    if List.key_change(i) and ImGui.MenuItem(ctx, "Remove the key change") then List.key_from(i, "") end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Delete", "Del") then List.delete(i) end
  end
  ImGui.EndPopup(ctx)
end

function UI.draw_toolbar()
  UI.vgap(CFG.SP_EDGE)
  local x0, y0 = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local IW, H = CFG.TB_ICON_W, ImGui.GetFrameHeight(ctx)
  local bw = UI.btn_w("Find notes")
  local room = math.max(40, aw - bw - 2 * CFG.CTRL_GAP - 2 * IW)
  if R.find then
    if UI.button("Cancel", bw, H) then Find.cancel() end
    UI.tip("Stop. The list stays as it was.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.ProgressBar(ctx, R.find and R.find.done or 0, room, H, "Listening...")
  else
    local busy = R.tempo and R.tempo.run ~= nil
    ImGui.BeginDisabled(ctx, busy)
    if UI.button("Find notes", bw, H, "primary") then UI.find() end
    ImGui.EndDisabled(ctx)
    UI.tip_disabled(busy and "Wait for Find tempo." or "Select the bass item first. Note Detective reads it and fills the list. Nothing is written to the project yet.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if not S.simple then -- (Import tab: full mode)
      local iw = UI.btn_w("Import tab...")
      ImGui.BeginDisabled(ctx, busy)
      if UI.button("Import tab...", iw, H) then UI.import_begin() end
      ImGui.EndDisabled(ctx)
      UI.tip("Have a Guitar Pro tab of the song (.gp, .gpx, .gp5, .gp4, .gp3)? Its notes, strings and frets replace the found notes, on the bars of the song (Set tempo first). It shows the choices first.")
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      room = math.max(40, room - iw - CFG.CTRL_GAP)
    end
    if not R.src_name then
      local nm = Find.name(Find.item())
      R.src_name = nm ~= "" and ("Bass: " .. nm) or "Select the bass item, then Find notes."
    end
    UI.row_text(UI.trunc_c(R.src_name, room), COL.TEXT_DIM)
    UI.tip(R.src_name)
  end
  -- the gear and "?" at the right end (plain icons, a grey background on hover)
  local dl = ImGui.GetWindowDrawList(ctx)
  local function icon(id, x, tip)
    ImGui.SetCursorPos(ctx, x, y0)
    local hit = ImGui.InvisibleButton(ctx, id, IW, H)
    local hov = ImGui.IsItemHovered(ctx)
    local ix, iy = ImGui.GetItemRectMin(ctx)
    if hov then
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
      ImGui.DrawList_AddRectFilled(dl, ix, iy, ix + IW, iy + H, COL.BTN_HOVER, 6)
    end
    UI.tip(tip)
    return hit, ix + IW / 2, iy + H / 2, hov
  end
  -- the gear: the Settings menu drops down below it; a click on the gear while it is open closes it
  local hit, cx, cy, hov = icon("##gear", x0 + aw - 2 * IW, "Settings")
  if ImGui.IsItemActivated(ctx) then R.gear_toggle = R.settings_open end
  local gx1, gy1 = ImGui.GetItemRectMax(ctx)
  if R.settings_open and not hov then ImGui.DrawList_AddRectFilled(dl, gx1 - IW, gy1 - H, gx1, gy1, COL.BTN_HOVER, 6) end
  UI.draw_gear_icon(dl, cx, cy, (hov or R.settings_open) and COL.TEXT_BRIGHT or COL.TEXT_MAIN)
  if (hit and not R.gear_toggle) or R.settings_req then ImGui.OpenPopup(ctx, "##settings") end
  if hit then R.gear_toggle = nil end
  R.settings_req = nil
  ImGui.SetNextWindowPos(ctx, gx1, gy1 + 4, ImGui.Cond_Appearing(), 1, 0)
  UI.draw_settings()
  hit, cx, cy, hov = icon("##helpbtn", x0 + aw - IW, "Help")
  ImGui.PushFont(ctx, head_font)
  local tw, th = ImGui.CalcTextSize(ctx, "?")
  ImGui.DrawList_AddText(dl, cx - tw / 2, cy - th / 2, hov and COL.TEXT_BRIGHT or COL.TEXT_MAIN, "?")
  ImGui.PopFont(ctx)
  if hit then R.help_open = true end
  ImGui.SetCursorPos(ctx, x0, y0 + H)
  UI.vgap(CFG.SP_EDGE)
end

local STRING_STYLES = { letters = "Letters (E A D G)", numbers = "Numbers (4 3 2 1)" }
local SLIDE_STYLES = { slash = "/C", sl = "sl. C", word = "C (slide)", off = "Off" }
-- The sections of the Settings menu (tools\docs-check.ps1 reads the names).
local SETTINGS_SECTIONS = {
  { "Look" }, { "Notes" }, { "Window" },
}
-- The Settings menu (the gear button): Look, Notes, Window.
function UI.draw_settings()
  R.settings_open = ImGui.BeginPopup(ctx, "##settings")
  if not R.settings_open then return end
  local function head(t, first)
    if not first then UI.vgap(8) end
    ImGui.PushFont(ctx, head_font)
    ImGui.TextColored(ctx, COL.HEADING, t)
    ImGui.PopFont(ctx)
  end
  head(SETTINGS_SECTIONS[1][1], true)
  local ch
  ch, S.light = UI.toggle_line("Light theme", S.light, "On: light panels and fields, dark text. Off: Dark (the default).")
  if ch then apply_theme(S.light); R.sdirty = true end
  head(SETTINGS_SECTIONS[2][1])
  ch, S.simple = UI.toggle_line("Simple mode", S.simple,
    "On (the default): the markers show only the notes, and the string and fret of a high note (\"E (A 7)\"). The window hides Tempo and bars, the Tab view and Export. Off: all the extras. For the next Find notes.")
  if ch then R.sdirty, R.tab_view = true, false end
  if not S.simple then
    ch, S.frets = UI.toggle_line("String and fret for high notes", S.frets,
      "On (the default): a note above the lowest octave gets its string and fret, for example \"E (A 7)\". Off: only the note names. For the next Find notes.")
    if ch then R.sdirty = true end
    ch, S.finger = UI.toggle_line("Fingering for runs", S.finger,
      "On (the default): in a bar with 4 notes or more, every note gets the string and fret with the fewest hand moves, for example \"F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1)\". For the next Find notes.")
    if ch then R.sdirty = true end
    ch, S.counts = UI.toggle_line("Beat count in the Notes track", S.counts,
      "On (the default): the text items on the Notes track show the beat of each note, for example \"1 F · 2& Eb · 3 C\". The markers stay short. For the next Write.")
    if ch then R.sdirty = true end
    ch, S.splits = UI.toggle_line("Split repeated notes", S.splits,
      "On (the default): after Set tempo, every 16th of a long note is checked for a pluck that the first look missed. A song where held notes split into 16ths: turn it off. For the next Find notes.")
    if ch then R.sdirty = true end
  end
  UI.row_text("String names", COL.TEXT_MAIN)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, CFG.STRINGS_W)
  if ImGui.BeginCombo(ctx, "##strings", STRING_STYLES[S.strings]) then
    for _, k in ipairs({ "letters", "numbers" }) do
      if ImGui.Selectable(ctx, STRING_STYLES[k], S.strings == k) then S.strings = k; R.sdirty = true end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("How the strings are named in \"E (A 7)\": by the open string of their place, or by number as in tab books (4 = the lowest of 4 strings). For the next Find notes.")
  if not S.simple then
    UI.row_text("Slide mark", COL.TEXT_MAIN)
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, CFG.STRINGS_W)
    if ImGui.BeginCombo(ctx, "##slide", SLIDE_STYLES[S.slide]) then
      for _, k in ipairs({ "slash", "sl", "word", "off" }) do
        if ImGui.Selectable(ctx, SLIDE_STYLES[k], S.slide == k) then S.slide = k; R.sdirty = true end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("How a slide into a note is written (the pitch glides into it, no new attack). Off: no mark. For the next Find notes.")
  end
  head(SETTINGS_SECTIONS[3][1])
  local docked = R.docked == true
  if UI.toggle_line("Dock in REAPER's docker", docked, "On: Note Detective is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if UI.button("Reset window position", CFG.SETTINGS_BTN_W) then R.reset_win = true; ImGui.CloseCurrentPopup(ctx) end
  UI.tip("Moves the window back to its default size and place, and undocks it.")
  UI.vgap(8)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Note Detective " .. CFG.VERSION .. "  -  MIT license")
  ImGui.EndPopup(ctx)
end

-- The Help window (a popup in the window), in topics as in Segue.
function UI.draw_help()
  if R.help_open then ImGui.OpenPopup(ctx, "Note Detective Help##help"); R.help_open = false end
  local vw, vh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowSize(ctx, math.min(520, math.max(260, vw - 40)), math.min(560, math.max(240, vh - 40)),
    ImGui.Cond_Appearing())
  if ImGui.BeginPopupModal(ctx, "Note Detective Help##help", true) then
    local _, ah = ImGui.GetContentRegionAvail(ctx)
    if ImGui.BeginChild(ctx, "##helpbody", 0, ah - ImGui.GetFrameHeight(ctx) - 8) then
      ImGui.PushTextWrapPos(ctx, 0)
      ImGui.Text(ctx, HELP_INTRO)
      UI.vgap(10)
      ImGui.TextColored(ctx, COL.TEXT_DIM, "Topics - click a topic to open it")
      for i, tp in ipairs(HELP_TOPICS) do
        ImGui.SetNextItemOpen(ctx, R.help_cur == i)
        local open = ImGui.CollapsingHeader(ctx, tp.title .. "##help" .. i)
        if open ~= (R.help_cur == i) then R.help_cur = open and i or nil end
        if open then
          ImGui.Indent(ctx, 10)
          ImGui.Text(ctx, tp.text)
          ImGui.Unindent(ctx, 10)
          UI.vgap(8)
        end
      end
      UI.vgap(10)
      ImGui.PushFont(ctx, head_font)
      ImGui.TextColored(ctx, COL.HEADING, "About")
      ImGui.PopFont(ctx)
      ImGui.TextColored(ctx, COL.TEXT_DIM, "Note Detective " .. CFG.VERSION .. "  -  MIT license")
      ImGui.PopTextWrapPos(ctx)
      ImGui.EndChild(ctx)
    end
    UI.vgap(8)
    if UI.button("Close", 90) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

-- The Finish window (a popup in the window).
function UI.draw_finish()
  local f = R.finish
  if not f then return end
  if f.open then ImGui.OpenPopup(ctx, "Finish##finish"); f.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Finish##finish", nil, ImGui.WindowFlags_AlwaysAutoResize()) then R.finish = nil; return end
  local x0 = ImGui.GetCursorPosX(ctx)
  local function field(label, v)
    UI.label(label)
    ImGui.SetCursorPosX(ctx, x0 + 60)
    ImGui.SetNextItemWidth(ctx, 240)
    local _, nv = ImGui.InputText(ctx, "##fin_" .. label, v)
    return nv
  end
  f.artist = field("Artist", f.artist)
  f.title = field("Title", f.title)
  UI.label("Region")
  ImGui.SetCursorPosX(ctx, x0 + 60)
  UI.row_text(UI.trunc(Out.region_name(f.artist, f.title, P.key), 240), COL.TEXT_DIM)
  local ch
  if f.fx > 0 then
    if f.fx_label == nil then
      f.fx_label = string.format("Remove the plugins from %s (%d)", UI.trunc(f.track_name, 120), f.fx)
    end
    ch, f.del_fx = UI.toggle_line(f.fx_label, f.del_fx, "All the plugins on the track of the bass item.")
  end
  if #f.clicks > 0 then
    if f.click_label == nil then
      local t = {}
      for i, c in ipairs(f.clicks) do t[i] = c.name end
      f.click_tip = table.concat(t, ", ")
      f.click_label = UI.trunc("Delete the metronome track: " .. f.click_tip, 280)
    end
    ch, f.del_clicks = UI.toggle_line(f.click_label, f.del_clicks, "Deletes: " .. f.click_tip)
  end
  if not f.fresh then
    ImGui.PushTextWrapPos(ctx, x0 + 300)
    ImGui.TextColored(ctx, COL.YELLOW, "The list is not written since your last change. Cancel and click Write first?")
    ImGui.PopTextWrapPos(ctx)
  end
  ImGui.PushTextWrapPos(ctx, x0 + 300)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "The list leaves the project. The markers and the Notes track stay.")
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  if UI.button("Finish", 100, nil, "primary") then
    ImGui.CloseCurrentPopup(ctx)
    local name = Out.finish(f)
    UI.notice(name ~= "" and ("Done. Region: " .. name) or "Done. No region (no artist, title or key).")
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then ImGui.CloseCurrentPopup(ctx); R.finish = nil end
  ImGui.EndPopup(ctx)
end

local STYLES = { { "steady", "1 tempo" }, { "follow", "Follow the song" } }
-- Tempo and bars: a section that folds (S.tempo), above the list.
function UI.draw_tempo()
  local fh = ImGui.GetFrameHeight(ctx)
  local tm = R.tempo
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local title = "Tempo and bars"
  ImGui.PushFont(ctx, head_font)
  local hw = 16 + (ImGui.CalcTextSize(ctx, title))
  local open = S.tempo and not R.tempo_shut
  if ImGui.InvisibleButton(ctx, "##tempo_fold", hw, fh) then
    S.tempo, R.tempo_shut, R.sdirty = not open, nil, true
  end
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local dl = ImGui.GetWindowDrawList(ctx)
  local col = hov and COL.TEXT_MAIN or COL.HEADING
  local cx, cy = sx + 6, sy + fh / 2
  if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col)
  else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col) end
  ImGui.DrawList_AddText(dl, sx + 16, UI.text_y(sy, fh), col, title)
  ImGui.PopFont(ctx)
  UI.tip(open and "Fold this section." or "Open: find the tempo of the song and put REAPER's bars on it.")
  if tm and tm.lbl_bpm and not open then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    UI.row_text(tm.lbl_bpm, COL.TEXT_DIM)
  end
  if not open then return end
  local x0 = ImGui.GetCursorPosX(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local LW = 92
  local function label(t)
    UI.label(t)
    ImGui.SetCursorPosX(ctx, x0 + LW)
  end
  local run = tm and tm.run
  -- Beats from, Find tempo (while it runs: the progress in place of the dropdown, and Cancel)
  label("Beats from")
  local src = Tempo.source()
  local bw = UI.btn_w("Find tempo")
  local cw = math.max(80, math.min(CFG.SRC_W, aw - LW - bw - CFG.CTRL_GAP))
  if run then
    ImGui.ProgressBar(ctx, run.done, cw, fh, "Listening...")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Cancel", bw) then Tempo.cancel(); R.tempo = nil end
    UI.tip("Stop. Nothing changes.")
    return
  end
  ImGui.SetNextItemWidth(ctx, cw)
  if ImGui.BeginCombo(ctx, "##tsrc", src and src.label or "No tracks with items") then
    for _, e in ipairs(Tempo.sources()) do
      if ImGui.Selectable(ctx, e.label, e == src) then R.tsrc_sel = e.tr end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The track that Find tempo listens to: the metronome (click) track is best, then the drums.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, src == nil or R.find ~= nil)
  if UI.button("Find tempo", bw, nil, "primary") then Tempo.begin(src and src.tr) end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled("Select the bass item first: Note Detective listens to this track while the song plays. Nothing changes yet.")
  if not (tm and tm.beats) then
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No tempo yet. Select the bass item and click Find tempo.")
    return
  end
  -- Tempo, 1/2, x2
  label("Tempo")
  UI.row_text(tm.lbl_bpm)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  UI.row_text(tm.lbl_drift, COL.TEXT_DIM)
  UI.tip(tm.steady and "The beats stay on 1 steady grid." or "The drums speed up and slow down a little (9 of 10 bars).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, tm.bpm < TP.CFG.BPM_MIN)
  if UI.button("1/2", 40) then Tempo.scale(0.5) end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled("Half the tempo (for example 83 instead of 166). Bar 1 and the short bars start again.")
  ImGui.SameLine(ctx, 0, 4)
  ImGui.BeginDisabled(ctx, tm.bpm > TP.CFG.BPM_MAX)
  if UI.button("x2", 40) then Tempo.scale(2) end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled("Double the tempo (for example 166 instead of 83). Bar 1 and the short bars start again.")
  -- Style
  label("Style")
  local cur = STYLES[1][2]
  for _, s in ipairs(STYLES) do if s[1] == tm.style then cur = s[2] end end
  ImGui.SetNextItemWidth(ctx, CFG.MODE_W)
  if ImGui.BeginCombo(ctx, "##tstyle", cur) then
    for _, s in ipairs(STYLES) do
      if ImGui.Selectable(ctx, s[2], s[1] == tm.style) and s[1] ~= tm.style then Tempo.set_style(s[1]) end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("1 tempo: 1 steady grid. Follow the song: a tempo marker on every bar, so the bars stay on the drums. "
    .. "Suggested for this song: " .. (tm.steady and "1 tempo." or "Follow the song."))
  -- Bar 1, Play with click
  label("Bar 1")
  UI.row_text(tm.lbl_bar1)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("< 1 beat", UI.btn_w("< 1 beat")) then Tempo.nudge(-1) end
  UI.tip("Bar 1 starts 1 beat earlier.")
  ImGui.SameLine(ctx, 0, 4)
  if UI.button("1 beat >", UI.btn_w("1 beat >")) then Tempo.nudge(1) end
  UI.tip("Bar 1 starts 1 beat later.")
  local pw = UI.btn_w("Play with click")
  if (ImGui.GetContentRegionAvail(ctx)) > pw + CFG.CTRL_GAP + 4 then ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  else ImGui.SetCursorPosX(ctx, x0 + LW) end
  if UI.button("Play with click", pw) then Tempo.try() end
  UI.tip("Plays from bar 1 with REAPER's metronome. Is the loud click on the \"1\"? (This try goes away again unless you click Set tempo.)")
  -- Short bars
  -- Short bars: the first one on the label line, "+ Add" at its right end, the others below
  label("Short bars")
  local add_w = UI.btn_w("+ Add")
  local function add_button()
    ImGui.SameLine(ctx, x0 + aw - add_w)
    if UI.button("+ Add", add_w, nil, "ghost") and not Tempo.set_short(UI.cursor(), true) then
      UI.notice("Put the edit cursor in a bar of the song first.", true)
    end
    UI.tip("A bar with only 3 beats: put the edit cursor in it, then click + Add.")
  end
  if #tm.short_list == 0 then UI.row_text("None.", COL.TEXT_DIM); add_button() end
  for k, s in ipairs(tm.short_list) do
    if k > 1 then ImGui.SetCursorPosX(ctx, x0 + LW) end
    UI.row_text(s.text)
    ImGui.SameLine(ctx, 0, 4)
    ImGui.PushID(ctx, s.i)
    if UI.button("x", 26, nil, "ghost") then Tempo.remove_short(s.i) end
    ImGui.PopID(ctx)
    UI.tip("4 beats again.")
    if k == 1 then add_button() end
  end
  -- Set tempo
  ImGui.SetCursorPosX(ctx, x0 + LW)
  if UI.button("Set tempo", UI.btn_w("Set tempo", 100), nil, "primary") then
    Tempo.set()
    R.tempo_shut = true -- (done: the section folds for now, so the list has room; S.tempo stays)
  end
  UI.tip("Writes the tempo of this song into the project, and moves its audio a few ms so the first bass note is on the beat: 1 undo step. Other songs keep their places.")
end

-- Import tab: a file window, then the Import window (the track, bar 1, the tuning).
function UI.import_begin()
  local ok, path = r.GetUserFileNameForRead("", "Import a Guitar Pro tab", "gp")
  if not ok or not path or path == "" then return end
  local doc, why = GP.read(path)
  if not doc then UI.notice(why, true); return end
  local mb = doc.mbars[1]
  R.import = { doc = doc, name = path:match("([^/\\]*)$"), track = Imp.bass_track(doc), q0 = 0, matched = true,
    bar = 4 * mb.num / mb.den, open = true }
end
-- Where bar 1 of the tab starts in the project (q0: a quarter note): "bar 5" or "bar 5, beat 1.08".
function UI.import_label(q0)
  local beat, m = r.TimeMap2_timeToBeats(R.proj, r.TimeMap2_QNToTime(R.proj, q0))
  if math.abs(beat) < 0.005 then return string.format("bar 1 of the tab = bar %d of the project", m + 1) end
  return string.format("bar 1 of the tab = bar %d, beat %.2f of the project", m + 1, beat + 1)
end
function UI.draw_import()
  local im = R.import
  if not im then return end
  if im.open then ImGui.OpenPopup(ctx, "Import tab##import"); im.open = false end
  if im.list_of ~= im.track then -- (the notes of the chosen track, again when the track changes)
    im.list, im.list_of = GP.notes(im.doc, im.track), im.track
    im.q0, im.matched = Imp.start(im.list)
    im.lbl = UI.import_label(im.q0)
    local tun = Imp.tuning(im.doc.tracks[im.track].open)
    im.tun_label = tun and tun.label or ("not in the list (" .. table.concat(im.doc.tracks[im.track].open, " ") .. "): the frets can differ")
  end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Import tab##import", nil, ImGui.WindowFlags_AlwaysAutoResize()) then R.import = nil; return end
  local x0 = ImGui.GetCursorPosX(ctx)
  local function label(t) UI.label(t); ImGui.SetCursorPosX(ctx, x0 + 60) end
  label("File")
  UI.row_text(UI.trunc(im.name, 260), COL.TEXT_DIM)
  label("Track")
  ImGui.SetNextItemWidth(ctx, 260)
  if ImGui.BeginCombo(ctx, "##imptrack", im.doc.tracks[im.track].name) then
    for k, t in ipairs(im.doc.tracks) do
      if ImGui.Selectable(ctx, t.name .. "##t" .. k, k == im.track) then im.track = k end
    end
    ImGui.EndCombo(ctx)
  end
  label("Bar 1")
  UI.row_text(im.lbl)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local first = im.list[1] and im.list[1].q or 0
  if UI.button("< 1 bar", UI.btn_w("< 1 bar")) and im.q0 - im.bar + first >= 0 then
    im.q0 = im.q0 - im.bar; im.lbl = UI.import_label(im.q0)
  end
  ImGui.SameLine(ctx, 0, 4)
  if UI.button("1 bar >", UI.btn_w("1 bar >")) then im.q0 = im.q0 + im.bar; im.lbl = UI.import_label(im.q0) end
  UI.tip("The first note of the tab goes exactly on the first found note (no found notes: bar 1 of Set tempo). Wrong bar? Move it.")
  label("Tuning")
  UI.row_text(UI.trunc(im.tun_label, 300), COL.TEXT_DIM)
  ImGui.PushTextWrapPos(ctx, x0 + 380)
  ImGui.TextColored(ctx, COL.TEXT_DIM, string.format("%d notes (the repeats played out). They replace the found notes, and the list is made again from them (Undo brings all back).", #im.list))
  if r.CountTempoTimeSigMarkers(R.proj) == 0 then
    ImGui.TextColored(ctx, COL.YELLOW, "Set the tempo first (Tempo and bars): the tab follows the bars of the project.")
  end
  if not im.matched then
    ImGui.TextColored(ctx, COL.YELLOW, "No found notes to line the tab up with, so check bar 1. Tab imported before? Cancel, then Undo it or do Find notes again.")
  end
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  ImGui.BeginDisabled(ctx, #im.list == 0)
  if UI.button("Import", 100, nil, "primary") then
    ImGui.CloseCurrentPopup(ctx)
    local n = Imp.apply(im.list, im.doc.tracks[im.track].open, im.q0)
    R.import = nil
    UI.notice(string.format("Imported %d notes from the tab. The list is made from them; Write puts them into the project.", n))
  end
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then ImGui.CloseCurrentPopup(ctx); R.import = nil end
  ImGui.EndPopup(ctx)
end

-- The Export window (a popup in the window).
function UI.draw_export()
  local e = R.export
  if not e then return end
  if e.open then
    ImGui.OpenPopup(ctx, "Export##export")
    e.open, e.path = false, nil
  end
  if e.path == nil then -- (again after Change...)
    e.path = Export.path() or false
    e.file_label = e.path and e.path:match("([^/\\]*)$") or nil
    e.dir_label = S.export_dir ~= "" and UI.trunc(S.export_dir, 190) or "The project folder"
  end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Export##export", nil, ImGui.WindowFlags_AlwaysAutoResize()) then R.export = nil; return end
  local x0 = ImGui.GetCursorPosX(ctx)
  e.item = select(2, UI.toggle_line("MIDI item on a \"" .. CFG.MIDI_TRACK .. "\" track", e.item,
    "Below the bass, to listen to it and fix it in REAPER. An older export there is replaced."))
  ImGui.BeginDisabled(ctx, not e.path)
  e.file = select(2, UI.toggle_line(".mid file", e.file and e.path ~= false,
    "For Guitar Pro or another program. A file with the same name is replaced."))
  ImGui.EndDisabled(ctx)
  UI.label("Folder")
  UI.row_text(e.dir_label, COL.TEXT_DIM)
  UI.tip(S.export_dir ~= "" and S.export_dir or "The folder of the project. Change... picks another folder for all songs.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Change...", UI.btn_w("Change...")) then
    local dir = Util.browse_folder("Export folder", Export.dir())
    if dir then S.export_dir, R.sdirty, e.path = dir, true, nil end
  end
  UI.tip("Pick the folder of the .mid files. It stays for all songs (on this computer).")
  if S.export_dir ~= "" then
    ImGui.SameLine(ctx, 0, 4)
    if UI.button("x", 26, nil, "ghost") then S.export_dir, R.sdirty, e.path = "", true, nil end
    UI.tip("Back to the project folder.")
  end
  UI.label("Rhythm")
  local cur = CFG.GRIDS[1][2]
  for _, g in ipairs(CFG.GRIDS) do if g[1] == e.step then cur = g[2] end end
  ImGui.SetNextItemWidth(ctx, CFG.MODE_W)
  if ImGui.BeginCombo(ctx, "##grid", cur) then
    for _, g in ipairs(CFG.GRIDS) do if ImGui.Selectable(ctx, g[2], g[1] == e.step) then e.step = g[1] end end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The note starts and ends move to the nearest step of REAPER's grid, so the rhythm reads well.")
  ImGui.PushTextWrapPos(ctx, x0 + 320)
  if e.path then
    ImGui.TextColored(ctx, COL.TEXT_DIM, "File: " .. e.file_label)
  else
    ImGui.TextColored(ctx, COL.YELLOW, "The project is not saved yet: save it, or choose a folder, to get a .mid file.")
  end
  ImGui.TextColored(ctx, COL.TEXT_DIM, "The notes that Find notes found. Your text corrections in the list are not in it.")
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  ImGui.BeginDisabled(ctx, not (e.item or e.file))
  if UI.button("Export", 100, nil, "primary") then
    ImGui.CloseCurrentPopup(ctx)
    R.export = nil
    UI.notice(Export.run(e))
  end
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then ImGui.CloseCurrentPopup(ctx); R.export = nil end
  ImGui.EndPopup(ctx)
end

-- Key and Markers, then the number of rows and Next doubtful.
function UI.draw_head(v)
  local aw = ImGui.GetContentRegionAvail(ctx)
  UI.label("Key")
  ImGui.SetNextItemWidth(ctx, CFG.KEY_W)
  if ImGui.BeginCombo(ctx, "##key", P.key ~= "" and P.key or "Not known") then
    for _, k in ipairs(Key.LIST) do
      if ImGui.Selectable(ctx, k, k == P.key) then List.set_key(k) end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The key of the song: it decides the note names (Ab or G#). Found in the file name when it is there.")
  if aw > 370 then ImGui.SameLine(ctx, 0, 2 * CFG.CTRL_GAP) end
  UI.label("Markers")
  local cur = MODES[1][2]
  for _, m in ipairs(MODES) do if m[1] == P.mode then cur = m[2] end end
  local locked = #P.rows > 0 and #P.notes == 0
  ImGui.BeginDisabled(ctx, locked or R.find ~= nil)
  ImGui.SetNextItemWidth(ctx, CFG.MODE_W)
  if ImGui.BeginCombo(ctx, "##mode", cur) then
    for _, m in ipairs(MODES) do
      if ImGui.Selectable(ctx, m[2], m[1] == P.mode) and m[1] ~= P.mode then
        if #P.rows > 0 then
          UI.ask("Make the list again? Your corrections go away (Undo brings them back).", "Make again", function() List.set_mode(m[1]) end)
        else
          List.set_mode(m[1])
        end
      end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled(locked and "Click Find notes again to change this." or "How the notes become markers. No steady tempo? Use \"About 2 seconds\".")
  UI.label("Tuning")
  local tun = Key.tuning(P.tuning)
  ImGui.BeginDisabled(ctx, R.find ~= nil)
  ImGui.SetNextItemWidth(ctx, CFG.TUNING_W)
  if ImGui.BeginCombo(ctx, "##tuning", tun.label) then
    for _, t in ipairs(CFG.TUNINGS) do
      if ImGui.Selectable(ctx, t.label, t.id == P.tuning) and t.id ~= P.tuning then
        List.set_tuning(t.id)
        if #P.rows > 0 then UI.notice("Tuning: " .. t.label .. ". Click Find notes again: the octaves and frets follow it.") end
      end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled("The tuning of the bass in this song. It decides the octave of each note and the string and fret of the high notes (\"E (A 7)\").")
  if not S.simple then
    ImGui.SameLine(ctx, 0, 2 * CFG.CTRL_GAP)
    UI.label("View")
    ImGui.SetNextItemWidth(ctx, CFG.VIEW_W)
    if ImGui.BeginCombo(ctx, "##view", R.tab_view and "Tab" or "List") then
      if ImGui.Selectable(ctx, "List", not R.tab_view) then R.tab_view = false end
      if ImGui.Selectable(ctx, "Tab", R.tab_view == true) then R.tab_view, R.tab_line = true, nil end
      ImGui.EndCombo(ctx)
    end
    UI.tip("List: the markers to check and correct. Tab: the found notes as bass tab, with the fingering (a click plays from a note; right-click: correct it).")
  end
  if #P.rows == 0 then return end
  UI.row_text(v.status, v.n_doubt > 0 and COL.YELLOW or COL.TEXT_DIM)
  if v.n_doubt > 0 then
    local w = UI.btn_w("Next doubtful")
    ImGui.SameLine(ctx, math.max(0, aw - w))
    if UI.button("Next doubtful", w, nil, "ghost") then UI.select(List.next_doubtful(R.sel), true) end
    UI.tip("Go to the next yellow line and play it (N).")
  end
end

function UI.draw_list(v, h)
  if #P.rows == 0 then
    ImGui.Dummy(ctx, 0, 4)
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, R.find and "Listening to the bass..." or "No notes yet. Select the bass item and click Find notes.")
    ImGui.PopTextWrapPos(ctx)
    return
  end
  local flags = ImGui.TableFlags_ScrollY() | ImGui.TableFlags_BordersInnerH() | ImGui.TableFlags_PadOuterX()
  if not ImGui.BeginTable(ctx, "##rows", 4, flags, 0, h) then return end
  ImGui.TableSetupScrollFreeze(ctx, 0, 1)
  local fixed = ImGui.TableColumnFlags_WidthFixed()
  ImGui.TableSetupColumn(ctx, "#", fixed, CFG.COL_NUM_W)
  ImGui.TableSetupColumn(ctx, "Bar", fixed, CFG.COL_BAR_W)
  ImGui.TableSetupColumn(ctx, "Notes", ImGui.TableColumnFlags_WidthStretch(), 1)
  ImGui.TableSetupColumn(ctx, "Places", fixed, CFG.COL_PLACES_W)
  ImGui.TableHeadersRow(ctx)
  if not R.clipper or not ImGui.ValidatePtr(R.clipper, "ImGui_ListClipper*") then R.clipper = ImGui.CreateListClipper(ctx) end
  ImGui.ListClipper_Begin(R.clipper, #v.items)
  if R.scroll_to and v.item_of[R.scroll_to] then ImGui.ListClipper_IncludeItemByIndex(R.clipper, v.item_of[R.scroll_to] - 1) end
  if R.edit and v.item_of[R.edit.i] then -- (drawn until it is closed)
    ImGui.ListClipper_IncludeItemByIndex(R.clipper, v.item_of[R.edit.i] - 1)
  end
  local fh = ImGui.GetFrameHeight(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local now_row = r.GetPlayStateEx(R.proj) & 1 == 1 and List.at(r.GetPlayPositionEx(R.proj)) or nil
  local act -- (what changes the list: after the rows are drawn)
  while ImGui.ListClipper_Step(R.clipper) do
    local d0, d1 = ImGui.ListClipper_GetDisplayRange(R.clipper)
    for n = d0 + 1, math.min(d1, #v.items) do
      local item = v.items[n]
      local i = item.row
      local row, t = P.rows[i], v[i]
      ImGui.TableNextRow(ctx)
      if item.key then -- (a key change: a blue line before its row; right-click: the menu of that row)
        ImGui.TableNextColumn(ctx)
        ImGui.TableNextColumn(ctx)
        ImGui.TableNextColumn(ctx)
        UI.row_text(item.key, COL.HEADING)
        if ImGui.IsItemClicked(ctx, 1) then R.sel, R.menu_row, R.menu_open = i, i, true end
        UI.tip("The note names follow this key from here. Right-click: change or remove it.")
        goto next_item
      end
      ImGui.PushID(ctx, i)
      ImGui.TableNextColumn(ctx)
      local editing = R.edit and R.edit.i == i
      local x, y = ImGui.GetCursorScreenPos(ctx)
      local sflags = ImGui.SelectableFlags_SpanAllColumns() | ImGui.SelectableFlags_AllowDoubleClick() | ImGui.SelectableFlags_AllowOverlap()
      if ImGui.Selectable(ctx, "##row", R.sel == i, sflags, 0, fh) and not editing then
        if ImGui.IsMouseDoubleClicked(ctx, 0) then act = { "edit", i } else act = { "play", i } end
      end
      if ImGui.IsItemClicked(ctx, 1) then R.sel, R.menu_row, R.menu_open = i, i, true end
      if R.scroll_to == i then ImGui.SetScrollHereY(ctx, 0.5); R.scroll_to = nil end
      local col = row.doubt and COL.YELLOW or COL.TEXT_MAIN
      if i == now_row then -- (the line that plays: a blue mark at the left)
        ImGui.DrawList_AddRectFilled(dl, x - 4, y + 3, x - 1, y + fh - 3, COL.ACCENT, 1)
      end
      ImGui.DrawList_AddText(dl, x, UI.text_y(y, fh), COL.TEXT_DIM, t.num)
      ImGui.TableNextColumn(ctx)
      UI.row_text(t.bar, COL.TEXT_DIM)
      ImGui.TableNextColumn(ctx)
      local cw = ImGui.GetContentRegionAvail(ctx)
      local e = R.edit
      if e and editing then
        ImGui.SetNextItemWidth(ctx, cw)
        if e.focus then ImGui.SetKeyboardFocusHere(ctx) end
        local _, nv = ImGui.InputText(ctx, "##edit", e.txt, ImGui.InputTextFlags_AutoSelectAll())
        e.txt = nv
        e.focus = nil
        if ImGui.IsItemActive(ctx) then e.live = true
        elseif e.live then act = { ImGui.IsKeyPressed(ctx, ImGui.Key_Escape(), false) and "stop" or "commit", i, e.txt } end
      else
        UI.row_text(UI.trunc_c(row.text, cw), col)
        if ImGui.IsItemHovered(ctx) then -- (the text only when it shows)
          ImGui.SetTooltip(ctx, row.text .. (row.doubt and "\n" .. List.why(i) or "") .. "\nClick: play from here. Double-click: type the notes.")
        end
      end
      ImGui.TableNextColumn(ctx)
      UI.row_text(t.places, COL.TEXT_DIM)
      if row.doubt and not editing then
        ImGui.SameLine(ctx, 0, 4)
        if UI.button("OK", 34, fh, "ghost") then act = { "ok", i } end
        UI.tip("These notes are right: no longer doubtful.")
      end
      ImGui.PopID(ctx)
      ::next_item::
    end
  end
  UI.row_menu()
  ImGui.EndTable(ctx)
  if act then
    if act[1] == "edit" then UI.edit_row(act[2])
    elseif act[1] == "play" then UI.play_row(act[2])
    elseif act[1] == "ok" then List.checked(act[2])
    elseif act[1] == "stop" then R.edit = nil
    else R.edit = nil; UI.commit_edit(act[2], act[3]) end
  end
end

-- Join, Split, + Add, Delete, Undo; then Write and Finish.
function UI.draw_foot()
  local aw = ImGui.GetContentRegionAvail(ctx)
  local sel = R.sel and P.rows[R.sel] and R.sel or nil
  local function btn(label, on, tip, fn)
    ImGui.BeginDisabled(ctx, not on)
    if UI.button(label, UI.btn_w(label), nil, "ghost") then fn() end
    ImGui.EndDisabled(ctx)
    UI.tip_disabled(tip)
    ImGui.SameLine(ctx, 0, 2)
  end
  btn("Join", sel ~= nil and P.rows[sel + 1] ~= nil, "Puts the selected line together with the next one.", function() List.join(sel) end)
  btn("Split", sel ~= nil, "Cuts the selected line at the edit cursor (while playing: the play position), or in the middle.", function() UI.split(sel) end)
  btn("+ Add", true, "A new line at the edit cursor (while playing: at the play position).", function()
    local i = List.add(UI.cursor())
    UI.select(i)
    UI.edit_row(i)
  end)
  btn("Delete", sel ~= nil, "Deletes the selected line (Delete key).", function() List.delete(sel) end)
  btn("Undo", #R.undo > 0, "Takes back the last change of the list. (Ctrl+Z is REAPER's undo: the written markers.)", List.undo)
  local cw = UI.btn_w("Clear...")
  ImGui.SameLine(ctx, math.max(0, aw - cw))
  ImGui.BeginDisabled(ctx, #P.rows == 0 or R.find ~= nil)
  if UI.button("Clear...", cw, nil, "ghost") then
    UI.ask("Start again? This removes the list and what Note Detective wrote: its markers, the Notes track items and "
      .. "the Bass MIDI item. Your own markers, the tempo and the audio stay.\n\n1 Ctrl+Z brings the project part back; "
      .. "the Undo button brings the list back.", "Clear", Out.clear)
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled("Start from the beginning: removes the list and what Note Detective wrote. It asks first.")
  local cur = OUTS[1][2]
  for _, o in ipairs(OUTS) do if o[1] == S.out then cur = o[2] end end
  local ww, fw = UI.btn_w("Write", 80), UI.btn_w("Finish...")
  local ew = S.simple and -CFG.CTRL_GAP or UI.btn_w("Export...") -- (Simple mode: no Export)
  local has = #P.rows > 0 and not R.find
  ImGui.BeginDisabled(ctx, not has)
  if UI.button("Write", ww, nil, "primary") then
    Out.write(S.out)
    UI.notice(string.format("Written: %d. One Ctrl+Z takes it away again.", #P.rows))
  end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled(has and "Writes the list into the project. Only Note Detective's own markers and text items are replaced." or "Find the notes first.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, math.max(60, math.min(CFG.OUT_W, aw - ww - fw - ew - 3 * CFG.CTRL_GAP)))
  if ImGui.BeginCombo(ctx, "##out", cur) then
    for _, o in ipairs(OUTS) do
      if ImGui.Selectable(ctx, o[2], o[1] == S.out) then S.out = o[1]; R.sdirty = true end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("What Write makes: markers, text items on a \"Notes\" track above the bass, or both.")
  if not S.simple then
    local can_export = #P.notes > 0 and not R.find
    ImGui.SameLine(ctx, math.max(0, aw - fw - ew - CFG.CTRL_GAP))
    ImGui.BeginDisabled(ctx, not can_export)
    if UI.button("Export...", ew) then R.export = { item = true, file = true, step = CFG.GRIDS[1][1], open = true } end
    ImGui.EndDisabled(ctx)
    UI.tip_disabled(can_export and "The found notes as MIDI: a MIDI item to listen to, and a .mid file for Guitar Pro. It shows the choices first."
      or "Find notes first: the export uses the notes that Find notes found.")
  end
  ImGui.SameLine(ctx, math.max(0, aw - fw))
  ImGui.BeginDisabled(ctx, not has)
  if UI.button("Finish...", fw) then Out.finish_begin() end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled(has and "The song region, and the cleanup of the project. It shows what it does first." or "Find the notes first.")
end

-- The right-click menu on an empty part of the panel (as in Segue).
function UI.draw_panel_menu()
  if R.pmenu then ImGui.OpenPopup(ctx, "##panelmenu"); R.pmenu = false end
  if not ImGui.BeginPopup(ctx, "##panelmenu") then return end
  if ImGui.MenuItem(ctx, "Settings...") then R.settings_req = true end
  if ImGui.MenuItem(ctx, "Help") then R.help_open = true end
  ImGui.Separator(ctx)
  local docked = R.docked == true
  if ImGui.MenuItem(ctx, "Dock Note Detective in Docker", nil, docked) then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if ImGui.MenuItem(ctx, "Close Note Detective") then R.close = true end
  ImGui.EndPopup(ctx)
end

-- The window: the toolbar, then one panel (a rounded area) with the list.
function UI.draw_main()
  UI.draw_toolbar()
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  local nh = UI.notice_h(aw - 16)
  ah = ah - CFG.SP_EDGE - nh
  local px, py = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + aw, py + ah, COL.PANEL_BG, 8)
  if ImGui.BeginChild(ctx, "##panel", aw, ah) then
    ImGui.SetCursorPosY(ctx, CFG.SP_PANEL + 6)
    ImGui.Indent(ctx, 10)
    if ImGui.BeginChild(ctx, "##inner", (ImGui.GetContentRegionAvail(ctx)) - 10, ah - CFG.SP_PANEL - 12) then
      local v = UI.view()
      if not S.simple then -- (Simple mode: the original steps only)
        UI.draw_tempo()
        ImGui.Separator(ctx)
      end
      UI.draw_head(v)
      local _, lh = ImGui.GetContentRegionAvail(ctx)
      local foot = 2 * ImGui.GetFrameHeight(ctx) + 2 * CFG.SP_ROW
      local y = ImGui.GetCursorPosY(ctx)
      if R.tab_view and not S.simple then UI.draw_tab(math.max(60, lh - foot)) else UI.draw_list(v, math.max(60, lh - foot)) end
      ImGui.SetCursorPosY(ctx, y + math.max(60, lh - foot) + CFG.SP_ROW)
      UI.draw_foot()
      ImGui.EndChild(ctx)
    end
    ImGui.Unindent(ctx, 10)
    if ImGui.IsMouseClicked(ctx, 1) and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows())
      and not ImGui.IsAnyItemHovered(ctx) and not ImGui.IsPopupOpen(ctx, "##row_menu") then R.pmenu = true end
    ImGui.EndChild(ctx)
  end
  if nh > 0 then -- the notice, below the panel (after it: a cursor move is always followed by the text)
    local n = R.notice
    ImGui.SetCursorScreenPos(ctx, px + 8, py + ah + 4)
    ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + aw - 16)
    ImGui.TextColored(ctx, n.warn and COL.ORANGE or COL.TEXT_DIM, n.text)
    ImGui.PopTextWrapPos(ctx)
  end
  UI.draw_panel_menu()
end

-- The keys (while the window has the focus and no field is typed in).
function UI.keys()
  if not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) or ImGui.IsAnyItemActive(ctx)
    or R.edit or R.ask or R.finish or R.export or R.import or ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopup()) then return end
  local C, SH = ImGui.Mod_Ctrl(), ImGui.Mod_Shift()
  local function key(k, rep) return ImGui.IsKeyPressed(ctx, k, rep or false) end
  if ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Z()) then r.Main_OnCommand(40029, 0) -- Edit: Undo
  elseif ImGui.IsKeyChordPressed(ctx, C | SH | ImGui.Key_Z()) or ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Y()) then
    r.Main_OnCommand(40030, 0) -- Edit: Redo
  elseif ImGui.GetKeyMods(ctx) ~= ImGui.Mod_None() then return
  elseif key(ImGui.Key_Space()) then r.Main_OnCommand(40044, 0) -- Transport: Play/stop
  elseif R.tab_view and not S.simple then UI.tab_keys() -- (the Tab view: its own keys)
  elseif key(ImGui.Key_N()) then UI.select(List.next_doubtful(R.sel), true)
  elseif key(ImGui.Key_UpArrow(), true) then UI.select(math.max(1, (R.sel or 2) - 1), true)
  elseif key(ImGui.Key_DownArrow(), true) then UI.select(math.min(#P.rows, (R.sel or 0) + 1), true)
  elseif key(ImGui.Key_F2()) and R.sel then UI.edit_row(R.sel)
  elseif key(ImGui.Key_Delete()) and R.sel then List.delete(R.sel) end
end

---------------------------------------------------------------------------
-- WINDOW (the same resize edges, corner grip and docked-tab triangle as Chart Cue)
---------------------------------------------------------------------------
function UI.pre_begin()
  local rs = R.rs
  if not rs then return end
  if not ImGui.IsMouseDown(ctx, 0) then R.rs = nil; return end
  local mx, my = ImGui.GetMousePos(ctx)
  local dx, dy = mx - rs.mx, my - rs.my
  local x, w, h = rs.x, rs.w, rs.h
  if rs.l then w = math.max(CFG.WIN_MIN_W, rs.w - dx); x = rs.x + rs.w - w end
  if rs.r then w = math.max(CFG.WIN_MIN_W, rs.w + dx) end
  if rs.b then h = math.max(CFG.WIN_MIN_H, rs.h + dy) end
  ImGui.SetNextWindowPos(ctx, x, rs.y, ImGui.Cond_Always())
  ImGui.SetNextWindowSize(ctx, w, h, ImGui.Cond_Always())
end

function UI.edges()
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  local E, G = CFG.WIN_EDGE, CFG.WIN_GRIP
  local mx, my = ImGui.GetMousePos(ctx)
  local zone
  if not R.rs and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_RootAndChildWindows())
      and not ImGui.IsAnyItemActive(ctx) and my > wy + ImGui.GetFrameHeight(ctx) then
    local l, rr, b = mx < wx + E, mx > wx + ww - E, my > wy + wh - E
    if mx > wx + ww - G and my > wy + wh - G then rr, b = true, true end
    if l or rr or b then zone = { l = l, r = rr and not l, b = b } end
  end
  local z = R.rs or zone
  if z then
    ImGui.SetMouseCursor(ctx, (z.b and (z.l or z.r)) and (z.l and ImGui.MouseCursor_ResizeNESW() or ImGui.MouseCursor_ResizeNWSE())
      or (z.b and ImGui.MouseCursor_ResizeNS()) or ImGui.MouseCursor_ResizeEW())
  end
  if zone and ImGui.IsMouseClicked(ctx, 0) then
    zone.mx, zone.my, zone.x, zone.y, zone.w, zone.h = mx, my, wx, wy, ww, wh
    R.rs = zone
  end
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1 = wx + ww, wy + wh
  ImGui.DrawList_PushClipRect(dl, wx, wy, x1, y1, false)
  local col = (z and z.r and z.b) and COL.ACCENT or COL.TOGGLE_OFF
  for k = 1, 3 do
    local d = k * 5
    ImGui.DrawList_AddLine(dl, x1 - 3 - d, y1 - 3, x1 - 3, y1 - 3 - d, col, 2)
  end
  ImGui.DrawList_PopClipRect(dl)
end

---------------------------------------------------------------------------
-- MAIN LOOP
---------------------------------------------------------------------------
local function loop()
  R.frames = R.frames + 1
  Project.update()
  Find.step()
  Tempo.step()
  Tempo.tick()
  ImGui.SetNextWindowSize(ctx, CFG.DEFAULT_W, CFG.DEFAULT_H, ImGui.Cond_FirstUseEver())
  if R.dock_req then ImGui.SetNextWindowDockID(ctx, R.dock_req); R.dock_req = nil end
  UI.pre_begin()
  if R.reset_win then
    R.reset_win = nil
    ImGui.SetNextWindowSize(ctx, CFG.DEFAULT_W, CFG.DEFAULT_H, ImGui.Cond_Always())
    ImGui.SetNextWindowPos(ctx, 100, 100, ImGui.Cond_Always())
    if R.docked then ImGui.SetNextWindowDockID(ctx, 0) end
  end
  ImGui.PushFont(ctx, font)
  UI.push_style()
  -- docked: ImGui's small corner triangle (show the dock tab bar) uses the button colours: blue, as in Chart Cue
  local tri = R.docked and 3 or 0
  if tri > 0 then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.ACCENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ACCENT_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACCENT_ACTIVE)
  end
  local visible, open = ImGui.Begin(ctx, CFG.TITLE, true, ImGui.WindowFlags_NoResize())
  if tri > 0 then ImGui.PopStyleColor(ctx, tri) end
  if visible then
    local id = ImGui.GetWindowDockID(ctx)
    R.docked = ImGui.IsWindowDocked(ctx)
    if id ~= S.dock then S.dock = id; R.sdirty = true end
    UI.keys()
    UI.draw_main()
    UI.draw_ask()
    UI.draw_finish()
    UI.draw_export()
    UI.draw_import()
    UI.draw_help()
    if not R.docked then UI.edges() else R.rs = nil end -- resize edges: floating only
    ImGui.End(ctx)
  end
  UI.pop_style()
  ImGui.PopFont(ctx)
  if R.pdirty then Project.save() end
  if R.sdirty and not ImGui.IsMouseDown(ctx, 0) then Util.save_settings() end
  if R.close then open = false end
  if open then r.defer(loop) end
end

local function on_exit()
  Find.cancel()
  Tempo.cancel()
  Tempo.untry()
  Tempo.click_back()
  if R.pdirty then Project.save() end
  if R.sdirty then Util.save_settings() end
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end

-- A second start closes the running Note Detective (REAPER 7: no question).
if r.set_action_options then r.set_action_options(1) end
do
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end
end
Util.load_settings()
apply_theme(S.light)
r.atexit(on_exit)
r.defer(loop)
