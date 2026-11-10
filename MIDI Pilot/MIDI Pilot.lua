-- @description MIDI Pilot: MIDI editor for amp modelers (Quad Cortex, Line 6 Helix / HX)
-- @version 1.2
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   MIDI Pilot - write the MIDI for a Neural DSP Quad Cortex / Quad Cortex mini or a Line 6 Helix, HX Stomp,
--   HX Stomp XL or HX Effects in REAPER: presets at the song starts, scenes (snapshots) by name, knob values in real
--   units, nudges and ramps. The MIDI plays without the script. Requires: the free ReaImGui extension (ReaPack).
-- @changelog
--   Lanes: Add LFO (Sine, Triangle, Square, Saw; the rate follows the tempo; the peaks can grow or shrink); LFOs, ramps and swells show as 1 row that you can move, copy and paste; collapsible sections.
--   A toolbar (device, previous / next song, Snap, Send state, Set up songs, Scene timelines, Export) and hideable tabs; Getting started; adds follow REAPER's Snap.
--   Preset list search and sort; Settings in 4 sections with Back up / Restore; Preset and Scene always written with a capital.

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

---------------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------------
local CFG = {}
CFG.TITLE = "MIDI Pilot"       -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.2"            -- keep equal to @version in the header
CFG.EXT = "MIDI Pilot"         -- ExtState section (REAPER's global settings and the project data)
CFG.PEXT_KEY = "cfg"           -- the project data key
CFG.DEFAULT_W, CFG.DEFAULT_H = 560, 640
CFG.WIN_EDGE = 6               -- floating window: width of the resize edges (inside the window), as in Chart Cue
CFG.WIN_GRIP = 22              -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 320, 220 -- smallest window size when resizing
CFG.FONT_SIZE = 14             -- the same sizes as Chart Cue
CFG.FONT_SIZE_BOLD = 15        -- section titles and the selected tab
CFG.TEXT_LIFT = 1              -- px the text is raised above the true centre in every control
CFG.TEXT_MID = 0.73            -- the middle of the capitals and digits, below the text top (x the font size; Chart Cue)
CFG.HELP_ICON = 20             -- the round "?" icon
CFG.LABEL_W = 190              -- the label column of the settings rows
CFG.FORM_MAX_W = 280           -- the widest control column
CFG.FORM_MIN_WIDE = 220        -- below the label column + this width, the labels go above their control
CFG.CTRL_GAP = 8               -- between 2 controls side by side
CFG.SP_ROW, CFG.SP_EDGE, CFG.SP_PANEL = 7, 8, 4 -- spacing (pixels; the same gaps as Chart Cue)
CFG.SP_TITLE_BEFORE, CFG.SP_TITLE_AFTER = 12, 6
CFG.ROW_H = 26
CFG.TAB_H = 32                 -- the tab strip, as in Chart Cue
CFG.TAB_GAP = 4
CFG.TAB_GROUP_GAP = 12         -- between the text tabs and the Settings / Help tabs
CFG.TAB_LIFT = 6               -- the selected tab is this much taller
CFG.LATENCY_MAX = 500          -- ms
CFG.PORTS_SEC = 2              -- the MIDI output list is read again at most this often (Settings tab)
CFG.TIP_DELAY = 0.5            -- seconds on an item before its tooltip shows (as in Chart Cue)
CFG.TIP_WRAP_EM = 32           -- tooltip lines wrap at this many font sizes
CFG.PC_MS = 250                -- the default preset timing: this many ms before the song start
CFG.PC_MS_MAX = 2000
CFG.NUDGE_MS = 10              -- the default nudge: 10 ms
CFG.NUDGE_MS_MAX = 1000
CFG.LANE_ROWS = 10             -- Lanes: a song's value list scrolls after this many rows (Settings > Appearance > List sizes)
CFG.SCENE_ROWS = 10            -- Songs: a song's scene list scrolls after this many rows (Settings > Appearance > List sizes)
CFG.PC_WINDOW = 2.5            -- a preset change up to this many seconds before a song start belongs to that song
CFG.W_S = 110                  -- a short part of a row (the preset letter, a typed length, a curve's bend)
CFG.W_M = 220                  -- the least width of a table cell dropdown (the song rows' preset)
CFG.W_INT = 150                -- a number field with its - and + buttons in a table (the CC of a control)
CFG.W_POP = 260                -- the fields of a small window (Choose a preset, Edit preset, Rename folder)
CFG.REABANK = "MIDI Pilot.reabank" -- in REAPER's Data\MIDI Pilot folder: the preset names for REAPER
CFG.STATUS_SEC = 0.25          -- the status bar text (song, preset, scene at the cursor) is made again this often
CFG.TOAST_SEC = 4              -- a notice in the status bar goes away after this many seconds
CFG.START_AFTER_PC = 0.1       -- s: a start scene from "Set up songs" comes this long after a song's preset change
CFG.STRIP_H = 22               -- the scene strip of a song row
CFG.EDGE = 0.002               -- s: a scene change this close to a song start is at the start (a MIDI tick rounds it)
CFG.START_WINDOW = 3           -- s: the first scene change in the first seconds of a song is its start scene
CFG.TEST_BEATS = 2             -- beats between 2 scene changes of a scene test

local COL = {
  RED = 0xF26D6DFF, YELLOW = 0xF2C75CFF, GREEN = 0x6FCF8AFF,
  ACCENT = 0x3B82F6FF, ACCENT_HOVER = 0x5B9BFFFF, ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633, HEADING = 0x8DB8FFFF,
  WIN_BG = 0x131518FF, PANEL_BG = 0x1A1C21FF, TAB_BG = 0x0F1114FF, -- (darker panels, more contrast)
  CARD_BG = 0x22252BFF, -- the card of an open scene list (1 step lighter than the panel)
  TAB_HOVER = 0x343944FF,
  FIELD = 0x2B2F38FF, FIELD_HOVER = 0x333844FF, FIELD_ACTIVE = 0x2C3A55FF,
  BTN = 0x30343EFF, BTN_HOVER = 0x3B404CFF, BTN_ACTIVE = 0x464C5AFF,
  LINE = 0x31353FFF, ROW_HOVER = 0xFFFFFF12, TOGGLE_OFF = 0x4A5060FF,
  TEXT_MAIN = 0xE6E8EEFF, TEXT_DIM = 0x8C93A3FF, TEXT_BRIGHT = 0xEEEEEEFF, WHITE = 0xFFFFFFFF,
  TRANSPARENT = 0x00000000,
  DANGER_HOVER = 0xF26D6D2E, DANGER_ACTIVE = 0xF26D6D50, -- red outline buttons (as in Chart Cue)
  HEADER_HOVER = 0x3B82F655, HEADER_ACTIVE = 0x3B82F677, -- list headers (Help topics, Settings sections), selectables
  TITLE_BG = 0x0F1114FF, TITLE_BG_ACTIVE = 0x1A1C21FF, -- the window title bar (in the theme)
}

-- The themes (Settings > Appearance > Theme): the colours that change. Dark: the values above. Light: light panels,
-- white fields, dark text; the accent and the scene colours stay (the same palette as Chart Cue's light theme).
local THEMES = { dark = {} }
for k, v in pairs(COL) do THEMES.dark[k] = v end
THEMES.light = {
  RED = 0xD43F3FFF, YELLOW = 0xB7860BFF, GREEN = 0x2E9E5BFF,
  ACCENT = 0x2F6FE0FF, ACCENT_HOVER = 0x3B82F6FF, ACCENT_ACTIVE = 0x2559C7FF, ACTIVE_BG = 0x3B82F617,
  HEADING = 0x2459C2FF,
  WIN_BG = 0xDDE1E7FF, PANEL_BG = 0xF4F5F7FF, TAB_BG = 0xD0D5DDFF, CARD_BG = 0xE9ECF0FF, TAB_HOVER = 0xC4CAD3FF,
  FIELD = 0xFFFFFFFF, FIELD_HOVER = 0xEEF2F7FF, FIELD_ACTIVE = 0xE1EAFAFF,
  BTN = 0xE3E7EDFF, BTN_HOVER = 0xD5DBE3FF, BTN_ACTIVE = 0xC5CCD7FF,
  LINE = 0xCBD1DAFF, ROW_HOVER = 0x0000000F, TOGGLE_OFF = 0xB3BAC6FF,
  TEXT_MAIN = 0x1E2127FF, TEXT_DIM = 0x667085FF, TEXT_BRIGHT = 0x101216FF,
  DANGER_HOVER = 0xD43F3F24, DANGER_ACTIVE = 0xD43F3F40,
  HEADER_HOVER = 0x3B82F626, HEADER_ACTIVE = 0x3B82F640,
  TITLE_BG = 0xD0D5DDFF, TITLE_BG_ACTIVE = 0xE6E9EEFF,
}
-- Sets the colours of a theme ("dark" or "light") in COL (the style reads COL every frame: no restart).
local function apply_theme(name)
  for k, v in pairs(THEMES[name] or THEMES.dark) do COL[k] = v end
end

local Util, Project, Dev, Preset, Midi, Knob, UI = {}, {}, {}, {}, {}, {}, {}

-- The models (device profiles). Presets: banks x letters (presets in a folder); a preset change is CC#0 (msb: the
-- preset group, Quad Cortex only), CC#32 (the folder: 0 .. folders - 1) and a Program Change. Scenes: CC sc_cc with
-- the values 0 .. #scenes - 1. line6: Line 6 numbering (01A, or 000 with "Preset numbers: Numbers") and setlists.
-- The Line 6 profiles come from the unofficial Helix MIDI guide: not tested on a unit.
local function snapshots(n)
  local names, short = {}, {}
  for i = 1, n do names[i], short[i] = "Snapshot " .. i, "S" .. i end
  return names, short
end
local MODELS = {
  qc = { name = "Quad Cortex", letters = "ABCDEFGH", banks = 32, presets = 256, msb = true, folders = 13,
    def_folder = 1, sc_cc = 43, scenes = { "A", "B", "C", "D", "E", "F", "G", "H" } },
  mini = { name = "Quad Cortex mini", letters = "ABCD", banks = 64, presets = 256, msb = true, folders = 13,
    def_folder = 1, sc_cc = 43, scenes = { "A-I", "B-I", "C-I", "D-I", "A-II", "B-II", "C-II", "D-II" } },
  helix = { name = "Line 6 Helix", line6 = true, n_snap = 8 },
  hxstomp = { name = "Line 6 HX Stomp", line6 = true, n_snap = 3 },
  hxstompxl = { name = "Line 6 HX Stomp XL", line6 = true, n_snap = 4 },
  hxeffects = { name = "Line 6 HX Effects", line6 = true, n_snap = 4 },
}
for _, m in pairs(MODELS) do
  if m.line6 then
    m.letters, m.banks, m.presets, m.msb, m.folders, m.def_folder, m.sc_cc = "ABCD", 32, 128, false, 8, 0, 69
    m.scenes, m.short = snapshots(m.n_snap)
  end
end
local MODEL_IDS = { "qc", "mini", "helix", "hxstomp", "hxstompxl", "hxeffects" }
-- The preset folders (CC#32 values 0-12): the unit calls them setlists.
local FOLDERS = { [0] = "Factory Presets", [1] = "My Presets" }
for v = 2, 12 do FOLDERS[v] = "User " .. (v - 1) end
local PC_WHEN = { "before", "exact", "after" }
-- The 8 scene colours of the Quad Cortex (from the unit's own colour row): yellow, orange, red, pink, purple, blue,
-- light blue, green. Scene v (0-7) gets colour v + 1 unless you choose another (Presets > Scenes...). The active
-- scene block has its colour; the other blocks have it semi-transparent.
local SC_NORMAL = { 0xFFD23FFF, 0xFF7A1FFF, 0xFF3838FF, 0xE8566AFF, 0x7A5CFFFF, 0x2E7BFFFF, 0x8ED6FFFF, 0x3DEB6BFF }
local SC_TEST = 0xD5D8DEFF -- the "Scene test" block on the strip (light grey: no scene colour)
local SC_TEXT = 0x1A1C21FF -- the text on a scene block (always dark: the colours are light)
local SC_COL_NAMES = { "Yellow", "Orange", "Red", "Pink", "Purple", "Blue", "Light blue", "Green" }
-- Preset timing in note values: the length in quarter notes (beats) and its name.
local PC_NOTES = { { 0.125, "1/32 note" }, { 0.25, "1/16 note" }, { 0.5, "1/8 note" }, { 1, "1 beat (1/4 note)" }, { 2, "2 beats" } }
local MODEL_ITEMS = ""
for _, id in ipairs(MODEL_IDS) do MODEL_ITEMS = MODEL_ITEMS .. MODELS[id].name .. (MODELS[id].line6 and " (untested)" or "") .. "\0" end
-- The units of a knob (Lanes): what the knob shows on the unit.
local KNOB_UNITS = { "%", "Hz", "dB", "ms", "" }
local KNOB_UNIT_ITEMS = "%\0Hz\0dB\0ms\0(none)\0"
-- The slope from a CC value to the next one (REAPER's CC shapes; REAPER plays the curve to the unit).
local CC_SHAPE_ITEMS = "Jump\0Straight\0Slow start and end\0Fast start\0Fast end\0Curve\0"
-- A ramp (Lanes): its slope (CC shapes 1-5, no Jump: RAMP_LABELS) and its length: { beats, bars } (else the time selection).
local RAMP_LENS = { { 1, 0, "1 beat" }, { 2, 0, "2 beats" }, { 0, 1, "1 bar" }, { 0, 2, "2 bars" }, { 0, 4, "4 bars" },
  { 0, 8, "8 bars" }, { 0, 16, "16 bars" }, { 0, 0, "Custom...", custom = true },
  { 0, 0, "To the time selection end", sel = true } } -- (the last one: not in the Hold and Back lists)
local RAMP_LEN_ITEMS = ""
for _, l in ipairs(RAMP_LENS) do RAMP_LEN_ITEMS = RAMP_LEN_ITEMS .. l[3] .. "\0" end
local BACK_LEN_ITEMS, HOLD_ITEMS = "", "No hold\0"
-- An LFO (Lanes): its shape (index 0-4) and its rate, the time of 1 cycle: { quarter notes, bars }.
local LFO_RATES = { { 0, 4, "4 bars" }, { 0, 2, "2 bars" }, { 0, 1, "1 bar" }, { 2, 0, "1/2 note" }, { 1, 0, "1/4 note" },
  { 0.5, 0, "1/8 note" }, { 0.25, 0, "1/16 note" }, { 3, 0, "1/2 dotted" }, { 1.5, 0, "1/4 dotted" },
  { 0.75, 0, "1/8 dotted" }, { 2 / 3, 0, "1/4 triplet" }, { 1 / 3, 0, "1/8 triplet" }, { 1 / 6, 0, "1/16 triplet" } }
local LFO_SHAPE_NAMES = { "Sine", "Triangle", "Square", "Saw up", "Saw down" }
local LFO_ICONS = { "sine", "tri", "square", "sawup", "sawdown" } -- (UI.wave)
-- The slopes with an icon before the name (the value rows): the names with room for the icon, and the icons.
local SLOPE_ICONS = { "jump", "straight", "slow", "fast_start", "fast_end", "curve" }
local SLOPE_LABELS, RAMP_LABELS, RAMP_ICONS, LFO_LABELS = {}, {}, {}, {}
for nm in CC_SHAPE_ITEMS:gmatch("([^\0]+)") do SLOPE_LABELS[#SLOPE_LABELS + 1] = "      " .. nm end
for i = 2, #SLOPE_LABELS do RAMP_LABELS[i - 1] = SLOPE_LABELS[i]; RAMP_ICONS[i - 1] = SLOPE_ICONS[i] end -- (no Jump)
for i, nm in ipairs(LFO_SHAPE_NAMES) do LFO_LABELS[i] = "      " .. nm end
local LFO_RATE_ITEMS = ""
for _, l in ipairs(LFO_RATES) do LFO_RATE_ITEMS = LFO_RATE_ITEMS .. l[3] .. "\0" end
for i = 1, #RAMP_LENS - 1 do
  BACK_LEN_ITEMS = BACK_LEN_ITEMS .. RAMP_LENS[i][3] .. "\0"; HOLD_ITEMS = HOLD_ITEMS .. RAMP_LENS[i][3] .. "\0"
end
-- CCs that the Quad Cortex uses for its own functions (a knob on them would also do that function).
local QC_CCS = { [0] = "Preset group", [32] = "Preset folder", [43] = "scenes", [44] = "tap tempo", [45] = "tuner",
  [46] = "Gig View", [47] = "modes", [62] = "Ignore duplicate PC", [64] = "footswitch page (mini)" }
for c = 35, 42 do QC_CCS[c] = "footswitch" end
for c = 48, 61 do QC_CCS[c] = "Looper X" end
-- The CCs of the Line 6 units (CC#1-3, the expression pedals, are free for the controls).
local LINE6_CCS = { [0] = "bank", [32] = "setlist", [64] = "tap tempo", [68] = "tuner", [69] = "snapshots",
  [70] = "bypass", [71] = "footswitch mode" }
for c = 49, 59 do LINE6_CCS[c] = "footswitch" end
for c = 60, 67 do if c ~= 64 then LINE6_CCS[c] = "looper" end end
for _, m in pairs(MODELS) do m.ccs = m.line6 and LINE6_CCS or QC_CCS end
-- The fixed MIDI functions of the Quad Cortex (Lanes > Control), from the Neural DSP manuals (Incoming MIDI CC List).
-- kind: "press" (any value is 1 press), "tap" (tap tempo: 1 tap, or 4 taps on the beat), "choice" (a value from
-- choices: { value, label }). Looper X (CC#48-61): later, in its own section.
local function qc_funcs(mini)
  local fs = mini and { "A (I)", "B (I)", "C (I)", "D (I)", "A (II)", "B (II)", "C (II)", "D (II)" }
    or { "A", "B", "C", "D", "E", "F", "G", "H" }
  local f = {}
  for i = 1, 8 do f[#f + 1] = { cc = 34 + i, name = "Footswitch " .. fs[i], kind = "press", choices = { { 127, "Press" } } } end
  if mini then f[#f + 1] = { cc = 64, name = "Footswitch page", kind = "choice", choices = { { 0, "Page I" }, { 127, "Page II" } } } end
  f[#f + 1] = { cc = 44, name = "Tap tempo", kind = "tap", choices = { { 127, "Tap" } } }
  f[#f + 1] = { cc = 45, name = "Tuner", kind = "choice", choices = { { 127, "Open" }, { 0, "Close" } } }
  f[#f + 1] = { cc = 46, name = "Gig View", kind = "choice", choices = { { 127, "Open" }, { 0, "Close" } } }
  f[#f + 1] = { cc = 47, name = "Mode", kind = "choice",
    choices = { { 0, "Slot 1 (Preset)" }, { 1, "Slot 2 (Scene)" }, { 2, "Slot 3 (Stomp)" } } }
  for _, x in ipairs(f) do x.min, x.max, x.unit = 0, 127, "" end
  return f
end
MODELS.qc.funcs, MODELS.mini.funcs = qc_funcs(false), qc_funcs(true)

-- R: runtime state (not saved). P: the project data (saved in the project). S: settings of this computer.
local R = {
  proj = nil, state_cc = -1, regions = {}, plast_txt = nil, pdirty = false, sdirty = false,
  frames = 0, sel_dev = 1, ports = {}, ports_t = nil, tracks = {},
}
local P
local S = {
  tab = 1,          -- the open tab: 1 Songs, 2 Lanes, 3 Presets, 4 Settings, 5 Help
  dock = 0,         -- the REAPER docker of the window (0 = floating; a negative number = a REAPER docker)
  devices = {},     -- { id, name, model (MODEL_IDS), chan 0 (All channels) / 1-16, port (MIDI output name), latency ms,
                    --   inport, pnum "bank" (01A) / "num" (000; Line 6 only) }
  pc_when = "before", -- the preset timing at a song start: "before", "exact" or "after"
  pc_ms = CFG.PC_MS,  -- ... by this many ms
  pc_unit = "ms",     -- the preset timing in "ms" or in "notes" (snaps to the beat grid)
  pc_note = 2,        -- ... the note value: an index of PC_NOTES (default 1/16 note)
  pc_other = "exact", -- Other presets (a preset added inside a song): "before", "exact" or "after" the cursor / marker
  sc_first = "after_pc", -- First scene: "start", "before", "after" (the region start) or "after_pc" (the song's preset)
  sc_other = "exact", -- Other scenes (a scene added): "before", "exact" or "after" the cursor / marker
  sc_unit = "ms",     -- the scene amount in "ms" or "notes"
  sc_ms = 100,        -- ... by this many ms
  sc_note = 2,        -- ... by this note value: an index of PC_NOTES
  check_items = true, -- a new MIDI item on a device's track: its channel is used, the song starts get a scene
  nudge_unit = "ms",  -- the nudge (the 2 triangle buttons of a row) in "ms" or in "notes"
  nudge_ms = CFG.NUDGE_MS, -- ... by this many ms
  nudge_note = 1,     -- ... by this note value: an index of PC_NOTES (default 1/32 note)
  lib = {},         -- the preset names: device id -> { ["folder:index"] = preset name }
  fnames = {},      -- your folder names: device id -> { [folder] = name }
  snames = {},      -- scene names: device id -> { ["folder:index"] = { [1..8] = name } }
  knobs = {},       -- the knobs (Lanes): device id -> { { cc, name, min, max, unit } }
  expr = {},        -- Quad Cortex: what the 2 expression pedals move in each preset: device id ->
                    --   { ["folder:index"] = { [1] = { { name, from, to, note } }, [2] = { ... } } } (from / to: knob %)
  lane_all = false, -- Lanes: the values of all songs (else only the song at the edit cursor)
  lane_rows = CFG.LANE_ROWS, -- Lanes: a song's value list scrolls after this many rows
  lanes_open = { values = true, add_value = true }, -- Lanes: the open sections (pedals, values, add_value, add_ramp, add_lfo)
  settings_open = 1,  -- Settings: the open section (1 Devices, 2 Editing, 3 Appearance, 4 General; 0 = none)
  theme = "dark",     -- Settings > Appearance > Theme: "dark" (the default) or "light"
  show_strip = true,  -- Settings > Appearance > Scene timelines: the scene timeline under each song (Songs tab)
  scene_keys = true,  -- Settings > Editing > Scene keys: keys 1-8 add a scene at the edit cursor (window active)
  scene_rows = CFG.SCENE_ROWS, -- Songs: a song's scene list scrolls after this many rows
  start_skip = {},    -- Songs > Getting started: the skipped steps ({ [step] = true })
  start_hide = false, -- Songs > Getting started: hidden with its X
  preset_sort = 0,    -- Presets > Preset list: 0 Number, 1 Name, 2 Used first
  tb_hide = {},       -- the toolbar items that are hidden ({ [key] = true }, TB_ITEMS)
  tb_off = false,     -- Settings > Appearance > Toolbar > Show toolbar: off
  tab_hide = {},      -- Settings > Appearance > Tabs: the hidden tabs ({ [1..3] = true }; Settings and Help always show)
}

---------------------------------------------------------------------------
-- REAIMGUI (pinned to 0.9.3 with the official compatibility shim)
---------------------------------------------------------------------------
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local test = rawget(_G, "MidiPilotTest")
local test_mode = test ~= nil
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("MIDI Pilot needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end
  else
    r.ShowMessageBox("MIDI Pilot needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run MIDI Pilot again.", CFG.TITLE, 0)
  end
end
if not test then
  if not r.ImGui_CreateContext or not r.file_exists(IMGUI_SHIM) then imgui_missing(); return end
  if not pcall(function() dofile(IMGUI_SHIM)("0.9.3") end) then imgui_missing(); return end
end

local ImGui = {}
setmetatable(ImGui, { __index = function(_, k) return r["ImGui_" .. k] end })
-- Every tooltip: shows after the mouse stays CFG.TIP_DELAY s on the same item, and long lines wrap (as in Chart Cue).
-- The item is known by its position (a tooltip asked for in the frame before, at the same place: the same item).
local raw_set_tooltip = r.ImGui_SetTooltip
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

---------------------------------------------------------------------------
-- UTIL
---------------------------------------------------------------------------
function Util.now() return r.time_precise() end
function Util.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function Util.fmt_mmss(t)
  t = math.max(0, t or 0)
  return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
end
function Util.playing()
  local st = r.GetPlayState()
  return ((st & 1) ~= 0 or (st & 4) ~= 0) and (st & 2) == 0
end
-- The edit cursor (during playback: the play position) for an add: on the nearest grid line when REAPER's Snap is
-- on (Options > Snap, the N key), else exactly there.
function Util.add_pos()
  local t = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
  if r.GetToggleCommandState(1157) == 1 then t = r.SnapToGrid(R.proj, t) end
  return t
end
-- A number without useless zeros: 2 -> "2", 2.5 -> "2.5".
local function short_num(x)
  local s = string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
  return s
end
-- A time in a song as text: "1:05.3" from the song start.
function Util.fmt_song_time(rg, t) return Util.fmt_time(t - rg.start) end
-- The project position in bars, beats and hundredths of a beat, always "9.1.00" ("9.2.50" = half a beat after
-- beat 2), as REAPER's ruler.
function Util.fmt_beats(t)
  local b, m, cml = r.TimeMap2_timeToBeats(R.proj, t)
  local beat = math.floor(b + 0.000001)
  local hund = math.floor((b - beat) * 100 + 0.5)
  if hund >= 100 then beat, hund = beat + 1, 0 end
  if cml and beat >= cml - 0.000001 then m, beat = m + 1, 0 end -- (rounded up to the next bar line)
  return string.format("%d.%d.%02d", m + 1, beat + 1, hund)
end
-- Reads "bar.beat.hundredths", "bar.beat" or "bar" ("9.2.50" and "9.2.5": half a beat after beat 2): the project
-- time, or nil.
function Util.parse_beats(s)
  s = (s or ""):match("^%s*(.-)%s*$")
  local bar, beat = s:match("^(%d+)%.(%d+%.?%d*)$")
  if not bar then bar, beat = s:match("^(%d+)$"), "1" end
  bar, beat = tonumber(bar), tonumber(beat)
  if not bar or not beat or bar < 1 or beat < 1 then return nil end
  return r.TimeMap2_beatsToTime(R.proj, beat - 1, bar - 1)
end
-- Reads a time typed in a song (m:ss.s or plain seconds, from the song start). Returns the project time or nil.
function Util.parse_song_time(rg, s)
  s = (s or ""):match("^%s*(.-)%s*$")
  local mm, ss = s:match("^(%d+):(%d+%.?%d*)$")
  local sec = mm and (tonumber(mm) * 60 + tonumber(ss)) or tonumber(s)
  if not sec or sec < 0 then return nil end
  return rg.start + sec
end
-- "1:05.3": minutes, seconds and tenths.
function Util.fmt_time(t)
  t = math.max(0, t or 0)
  return string.format("%d:%04.1f", math.floor(t / 60), t % 60)
end
function Util.mark_pdirty() R.pdirty = true end
function Util.mark_sdirty() R.sdirty = true end
function Util.notify(text, warn) if UI.toast then UI.toast(text, warn) end end -- (no window in the tests)
function Util.clean(s) return (tostring(s or ""):gsub("[\t\r\n]", " ")) end
-- A setting of this computer (REAPER's ExtState "MIDI Pilot", persistent). REAPER keeps only the first line of a
-- saved value, so a line break is saved as "\n" (2 characters) and a backslash as "\\".
local EXT_DEC = { n = "\n", ["\\"] = "\\" }
function Util.ext_set(k, v)
  r.SetExtState(CFG.EXT, k, (tostring(v or ""):gsub("\\", "\\\\"):gsub("\n", "\\n")), true)
end
function Util.ext_get(k) return (r.GetExtState(CFG.EXT, k):gsub("\\(.)", EXT_DEC)) end

---------------------------------------------------------------------------
-- SETTINGS (this computer: REAPER's ExtState "MIDI Pilot", persistent)
---------------------------------------------------------------------------
-- The devices, 1 line each: id, name, model, channel, MIDI output name, latency, MIDI input name, preset numbers
-- (tab-separated).
function Dev.parse_list(txt)
  local list = {}
  for line in ((txt or "") .. "\n"):gmatch("([^\n]*)\n") do
    local id, name, model, chan, port, lat, inp, pn = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t([^\t]*)\t?(.*)$")
    if id and id ~= "" then
      list[#list + 1] = { id = id, name = name, model = MODELS[model] and model or "qc",
        chan = Util.clamp(math.floor(tonumber(chan) or 1), 0, 16), port = port,
        latency = Util.clamp(math.floor(tonumber(lat) or 0), 0, CFG.LATENCY_MAX), inport = inp,
        pnum = (pn == "num") and "num" or "bank" }
    end
  end
  return list
end
function Dev.serialize_list(list)
  local t = {}
  for _, d in ipairs(list) do
    t[#t + 1] = string.format("%s\t%s\t%s\t%d\t%s\t%d\t%s\t%s", d.id, Util.clean(d.name), d.model, d.chan,
      Util.clean(d.port), d.latency, Util.clean(d.inport), d.pnum == "num" and "num" or "bank")
  end
  return table.concat(t, "\n")
end

local function load_settings()
  local get = Util.ext_get
  S.tab = Util.clamp(math.floor(tonumber(get("tab")) or 1), 1, 5)
  S.dock = math.floor(tonumber(get("dock")) or 0)
  S.devices = Dev.parse_list(get("devices"))
  local w = get("pc_when")
  for _, v in ipairs(PC_WHEN) do if v == w then S.pc_when = w end end
  S.pc_ms = Util.clamp(math.floor(tonumber(get("pc_ms")) or CFG.PC_MS), 0, CFG.PC_MS_MAX)
  S.pc_unit = (get("pc_unit") == "notes") and "notes" or "ms"
  S.pc_note = Util.clamp(math.floor(tonumber(get("pc_note")) or 2), 1, #PC_NOTES)
  local function one_of(v, list, def) for _, x in ipairs(list) do if x == v then return v end end return def end
  S.pc_other = one_of(get("pc_other"), PC_WHEN, "exact")
  S.sc_first = one_of(get("sc_first"), { "start", "before", "after", "after_pc" }, "after_pc")
  S.sc_other = one_of(get("sc_other"), PC_WHEN, "exact")
  S.sc_unit = (get("sc_unit") == "notes") and "notes" or "ms"
  S.sc_ms = Util.clamp(math.floor(tonumber(get("sc_ms")) or 100), 0, CFG.PC_MS_MAX)
  S.sc_note = Util.clamp(math.floor(tonumber(get("sc_note")) or 2), 1, #PC_NOTES)
  S.check_items = get("check_items") ~= "0"
  S.nudge_unit = (get("nudge_unit") == "notes") and "notes" or "ms"
  S.nudge_ms = Util.clamp(math.floor(tonumber(get("nudge_ms")) or CFG.NUDGE_MS), 1, CFG.NUDGE_MS_MAX)
  S.nudge_note = Util.clamp(math.floor(tonumber(get("nudge_note")) or 1), 1, #PC_NOTES)
  for _, d in ipairs(S.devices) do
    S.lib[d.id] = Preset.parse_lib(get("lib_" .. d.id))
    S.fnames[d.id] = Preset.parse_fnames(get("fold_" .. d.id))
    S.snames[d.id] = Preset.parse_snames(get("scn_" .. d.id))
    S.expr[d.id] = Preset.parse_expr(get("exp_" .. d.id))
    S.knobs[d.id] = Knob.parse(get("knb_" .. d.id))
  end
  S.lane_all = get("lane_all") == "1"
  if r.HasExtState(CFG.EXT, "lanes_open") then
    S.lanes_open = {}
    for key in get("lanes_open"):gmatch("[%w_]+") do S.lanes_open[key] = true end
  end
  S.theme = (get("theme") == "light") and "light" or "dark"
  S.show_strip = get("show_strip") ~= "0"
  S.scene_keys = get("scene_keys") ~= "0"
  S.start_hide = get("start_hide") == "1"
  S.preset_sort = Util.clamp(math.floor(tonumber(get("preset_sort")) or 0), 0, 2)
  S.tb_hide = {}
  for key in get("tb_hide"):gmatch("[%w_]+") do S.tb_hide[key] = true end
  S.tb_off = get("tb_off") == "1"
  S.tab_hide = {}
  for v in get("tab_hide"):gmatch("%d+") do
    local ti = tonumber(v)
    if ti and ti >= 1 and ti <= 3 then S.tab_hide[ti] = true end
  end
  S.start_skip = {}
  for v in get("start_skip"):gmatch("%d+") do S.start_skip[tonumber(v)] = true end
  S.settings_open = Util.clamp(math.floor(tonumber(get("settings_open")) or 1), 0, 4)
  S.lane_rows = Util.clamp(math.floor(tonumber(get("lane_rows")) or CFG.LANE_ROWS), 3, 100)
  S.scene_rows = Util.clamp(math.floor(tonumber(get("scene_rows")) or CFG.SCENE_ROWS), 3, 100)
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
local function save_settings()
  r.SetExtState(CFG.EXT, "tab", tostring(S.tab), true)
  r.SetExtState(CFG.EXT, "dock", tostring(S.dock), true)
  Util.ext_set("devices", Dev.serialize_list(S.devices))
  r.SetExtState(CFG.EXT, "pc_when", S.pc_when, true)
  r.SetExtState(CFG.EXT, "pc_ms", tostring(S.pc_ms), true)
  r.SetExtState(CFG.EXT, "pc_unit", S.pc_unit, true)
  r.SetExtState(CFG.EXT, "pc_note", tostring(S.pc_note), true)
  r.SetExtState(CFG.EXT, "pc_other", S.pc_other, true)
  r.SetExtState(CFG.EXT, "sc_first", S.sc_first, true)
  r.SetExtState(CFG.EXT, "sc_other", S.sc_other, true)
  r.SetExtState(CFG.EXT, "sc_unit", S.sc_unit, true)
  r.SetExtState(CFG.EXT, "sc_ms", tostring(S.sc_ms), true)
  r.SetExtState(CFG.EXT, "sc_note", tostring(S.sc_note), true)
  r.SetExtState(CFG.EXT, "check_items", S.check_items and "1" or "0", true)
  r.SetExtState(CFG.EXT, "nudge_unit", S.nudge_unit, true)
  r.SetExtState(CFG.EXT, "nudge_ms", tostring(S.nudge_ms), true)
  r.SetExtState(CFG.EXT, "nudge_note", tostring(S.nudge_note), true)
  for _, d in ipairs(S.devices) do
    Util.ext_set("lib_" .. d.id, Preset.serialize_lib(S.lib[d.id]))
    Util.ext_set("fold_" .. d.id, Preset.serialize_fnames(S.fnames[d.id]))
    Util.ext_set("scn_" .. d.id, Preset.serialize_snames(S.snames[d.id]))
    Util.ext_set("exp_" .. d.id, Preset.serialize_expr(S.expr[d.id]))
    Util.ext_set("knb_" .. d.id, Knob.serialize(S.knobs[d.id]))
  end
  r.SetExtState(CFG.EXT, "lane_all", S.lane_all and "1" or "0", true)
  local lo = {}
  for key in pairs(S.lanes_open) do lo[#lo + 1] = key end
  table.sort(lo)
  r.SetExtState(CFG.EXT, "lanes_open", table.concat(lo, " "), true)
  r.SetExtState(CFG.EXT, "lane_rows", tostring(S.lane_rows), true)
  r.SetExtState(CFG.EXT, "settings_open", tostring(S.settings_open), true)
  r.SetExtState(CFG.EXT, "theme", S.theme, true)
  r.SetExtState(CFG.EXT, "show_strip", S.show_strip and "1" or "0", true)
  r.SetExtState(CFG.EXT, "scene_keys", S.scene_keys and "1" or "0", true)
  local th = {}
  for key in pairs(S.tb_hide) do th[#th + 1] = key end
  table.sort(th)
  if #th > 0 or r.HasExtState(CFG.EXT, "tb_hide") then r.SetExtState(CFG.EXT, "tb_hide", table.concat(th, " "), true) end
  if S.tb_off or r.HasExtState(CFG.EXT, "tb_off") then r.SetExtState(CFG.EXT, "tb_off", S.tb_off and "1" or "0", true) end
  local hid = {}
  for ti = 1, 3 do if S.tab_hide[ti] then hid[#hid + 1] = tostring(ti) end end
  if #hid > 0 or r.HasExtState(CFG.EXT, "tab_hide") then r.SetExtState(CFG.EXT, "tab_hide", table.concat(hid, " "), true) end
  if S.preset_sort ~= 0 or r.HasExtState(CFG.EXT, "preset_sort") then r.SetExtState(CFG.EXT, "preset_sort", tostring(S.preset_sort), true) end
  if S.start_hide or r.HasExtState(CFG.EXT, "start_hide") then r.SetExtState(CFG.EXT, "start_hide", S.start_hide and "1" or "0", true) end
  local sk = {}
  for v in pairs(S.start_skip) do sk[#sk + 1] = tostring(v) end
  table.sort(sk)
  if #sk > 0 or r.HasExtState(CFG.EXT, "start_skip") then r.SetExtState(CFG.EXT, "start_skip", table.concat(sk, " "), true) end
  r.SetExtState(CFG.EXT, "scene_rows", tostring(S.scene_rows), true)
  if R.bank_dirty then Preset.write_reabank() end
  R.sdirty = false
end

---------------------------------------------------------------------------
-- PROJECT (regions, tracks and the project data)
---------------------------------------------------------------------------
-- tracks: device id -> track GUID ("*" = the shared track). track_mode: "own" (1 track per device) or "shared".
-- test_ok: the regions (by name) whose Scene test needs no hint in the status bar ("Ignore").
-- export_dir: the folder of Export MIDI ("": "MIDI Pilot export" next to the project file).
function Project.default() return { tracks = {}, track_mode = "own", test_ok = {}, export_dir = "" } end

function Project.scan()
  R.regions, R.markers = {}, {}
  local proj = R.proj
  local total = r.CountProjectMarkers(proj) or 0
  for i = 0, total - 1 do
    local ok, isrgn, pos, rend, name = r.EnumProjectMarkers3(proj, i)
    if ok and ok > 0 and isrgn then R.regions[#R.regions + 1] = { name = name or "", start = pos, stop = rend }
    elseif ok and ok > 0 then R.markers[#R.markers + 1] = { name = name or "", pos = pos } end
  end
  table.sort(R.regions, function(a, b) return a.start < b.start end)
  -- the tracks by GUID (for the device tracks)
  R.tracks = {}
  for i = 0, r.CountTracks(proj) - 1 do
    local tr = r.GetTrack(proj, i)
    R.tracks[r.GetTrackGUID(tr)] = tr
  end
  R.pcs = {} -- the preset changes are read again from the MIDI (Midi.changes)
  if P then
    Dev.restore_undone()
    for _, d in ipairs(S.devices) do Dev.link_by_name(d) end
  end
end

-- The project data, as lines "key=value". Only what differs from the default is written.
function Project.parse(txt)
  local p = Project.default()
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "track" then
      local id, guid = v:match("^(.-)\t(.*)$")
      if id and id ~= "" and guid ~= "" then p.tracks[id] = guid end
    elseif k == "track_mode" and v == "shared" then p.track_mode = "shared"
    elseif k == "test_ok" and v ~= "" then p.test_ok[v] = true
    elseif k == "export_dir" then p.export_dir = v
    end
  end
  return p
end

function Project.serialize()
  local t = {}
  local function w(k, v) t[#t + 1] = k .. "=" .. (tostring(v):gsub("[\r\n]", " ")) end -- (a tab separates fields)
  w("version", 1)
  local ids = {}
  for id in pairs(P.tracks) do ids[#ids + 1] = id end
  table.sort(ids) -- (the same text for the same data)
  for _, id in ipairs(ids) do w("track", Util.clean(id) .. "\t" .. Util.clean(P.tracks[id])) end
  if P.track_mode ~= "own" then w("track_mode", P.track_mode) end
  local ok = {}
  for nm in pairs(P.test_ok) do ok[#ok + 1] = nm end
  table.sort(ok)
  for _, nm in ipairs(ok) do w("test_ok", Util.clean(nm)) end
  if P.export_dir ~= "" then w("export_dir", Util.clean(P.export_dir)) end
  return table.concat(t, "\n")
end

function Project.load()
  local n, txt = r.GetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY)
  if n and n > 0 and txt and txt ~= "" then P = Project.parse(txt); R.plast_txt = txt
  else P = Project.default(); R.plast_txt = Project.serialize() end
end

-- Writes the project data when it changed (an unchanged text does not mark the project modified).
function Project.save()
  R.pdirty = false
  if not (R.proj and r.ValidatePtr2(0, R.proj, "ReaProject*")) then return end
  local txt = Project.serialize()
  if txt == R.plast_txt then return end
  r.SetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY, txt)
  R.plast_txt = txt
end

-- Every frame: another project tab loads its own data; a project change reads the regions and tracks again.
function Project.update()
  local proj = r.EnumProjects(-1)
  if proj ~= R.proj then
    if R.pdirty then Project.save() end
    R.proj, R.state_cc = proj, -1
    R.pick, R.scm, R.ask, R.st_text, R.sc_open, R.chq = nil, nil, nil, nil, nil, nil -- (they belong to the old project)
    Project.load()
    R.name_sync, R.trname = true, {} -- (after the first scan of this project)
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc then
    R.state_cc = cc; Project.scan(); Dev.sync_from_tracks(); R.conflicts = nil; Midi.find_new_items()
    if R.name_sync then R.name_sync = nil; Dev.sync_names() end
  end
end

---------------------------------------------------------------------------
-- DEVICES (each Quad Cortex: its model, MIDI output, channel and track)
---------------------------------------------------------------------------
-- The MIDI outputs and inputs of REAPER (Preferences > MIDI devices): { { index, name } }.
function Dev.read_ports()
  local ports, inports = {}, {}
  for i = 0, (r.GetNumMIDIOutputs() or 0) - 1 do
    local ok, name = r.GetMIDIOutputName(i, "")
    if ok and name and name ~= "" then ports[#ports + 1] = { index = i, name = name } end
  end
  for i = 0, (r.GetNumMIDIInputs() or 0) - 1 do
    local ok, name = r.GetMIDIInputName(i, "")
    if ok and name and name ~= "" then inports[#inports + 1] = { index = i, name = name } end
  end
  R.ports, R.inports, R.ports_t = ports, inports, Util.now()
  R.conflicts = nil
end
function Dev.port_index(name)
  for _, p in ipairs(R.ports) do if p.name == name then return p.index end end
  return nil
end
function Dev.port_name(index)
  for _, p in ipairs(R.ports) do if p.index == index then return p.name end end
  return nil
end

-- The name of a model's device: "Quad Cortex", or "Quad Cortex 1", "Quad Cortex 2" ... when there are more.
-- The track of a device is "MIDI " + its name.
function Dev.track_title(d) return "MIDI " .. d.name end
function Dev.is_default_name(d, model)
  local base = MODELS[model or d.model].name
  return d.name == base or d.name:match("^" .. base:gsub("%p", "%%%0") .. " %d+$") ~= nil
end

-- Renames a device; its track follows (the track is always "MIDI " + the device name).
function Dev.rename(d, name)
  if name == d.name then return end
  local tr = Dev.track(d)
  if tr and P.track_mode ~= "shared" then
    r.GetSetMediaTrackInfo_String(tr, "P_NAME", "MIDI " .. name, true); r.TrackList_AdjustWindows(false)
  end
  d.name = name
  Util.mark_sdirty(); R.conflicts = nil; R.bank_dirty = true
  if not tr then Dev.link_by_name(d) end
end

-- Gives the devices of a model with a default name their numbers (1 device: no number).
function Dev.number_defaults(model)
  local list = {}
  for _, d in ipairs(S.devices) do
    if d.model == model and Dev.is_default_name(d) then list[#list + 1] = d end
  end
  local base = MODELS[model].name
  for i, d in ipairs(list) do Dev.rename(d, #list == 1 and base or (base .. " " .. i)) end
end

-- After a change of the model: a default name becomes the default name of the new model.
function Dev.set_model(d, model)
  if model == d.model then return end
  local old = d.model
  local renamed = Dev.is_default_name(d)
  d.model = model
  R.fitems, R.pick_cache, R.conflicts, R.pcs, R.bank_dirty, R.klist, R.lane_k = nil, nil, nil, {}, true, nil, nil
  if renamed then
    Dev.rename(d, MODELS[model].name)
    Dev.number_defaults(old); Dev.number_defaults(model)
  end
  Util.mark_sdirty()
end

-- A MIDI output that another device uses already.
function Dev.port_used(name, except)
  for _, d in ipairs(S.devices) do if d ~= except and d.port == name then return true end end
  return false
end

-- The model that a MIDI output name suggests (USB: the device's own name), or nil. (The Line 6 names: untested.)
function Dev.model_from_port(name)
  local n = (name or ""):lower()
  if n:find("cortex", 1, true) then return n:find("mini", 1, true) and "mini" or "qc" end
  if n:find("helix", 1, true) then return "helix" end
  if n:find("stomp ?xl") then return "hxstompxl" end
  if n:find("hx ?stomp") then return "hxstomp" end
  if n:find("hx ?effects") then return "hxeffects" end
  return nil
end

-- A new device (Settings > Devices > Add device): model, a chosen model (no output yet); port, a connected unit (its
-- output, input and model). Without both: a connected unit that no device uses yet, else a Quad Cortex.
-- (All connected units in use: a device without an output, so the same unit is never added twice.)
function Dev.new(model, port)
  local d = { id = "d" .. r.genGuid(""):gsub("[^%w]", ""):sub(1, 12), name = "", model = model or "qc", chan = 1,
    port = "", latency = 0, inport = "", pnum = "bank" }
  if port then d.port, d.model = port, Dev.model_from_port(port) or d.model
  elseif not model then
    for _, p in ipairs(R.ports) do
      local m = Dev.model_from_port(p.name)
      if m and not Dev.port_used(p.name) then d.port, d.model = p.name, m; break end
    end
  end
  d.inport = Dev.guess_input(d)
  -- a MIDI Pilot track without a device (its device was removed): the device comes back with it (the track of
  -- the same unit first)
  if P.track_mode ~= "shared" then
    local pick
    for _, o in ipairs(Dev.orphans()) do
      if d.port ~= "" and o.dev.port == d.port then pick = o; break end
    end
    if not pick and d.port == "" then -- (no unit found: the first kept track; with a chosen model: of that model)
      for _, o in ipairs(Dev.orphans()) do
        if not model or o.dev.model == model then pick = o; break end
      end
    end
    if pick then
      Dev.adopt(pick, d)
      S.devices[#S.devices + 1] = d
      if Dev.is_default_name(d) then Dev.number_defaults(d.model) end
      Util.notify("The device uses its track '" .. Dev.track_name(pick.tr) .. "' again.")
      return d
    end
  end
  d.name = MODELS[d.model].name
  S.devices[#S.devices + 1] = d
  S.lib[d.id] = {}; S.fnames[d.id] = {}; S.snames[d.id] = {}; S.expr[d.id] = {}; S.knobs[d.id] = Knob.parse("")
  Dev.number_defaults(d.model)
  Util.mark_sdirty(); R.conflicts = nil
  if not Dev.link_by_name(d) and not test_mode then Dev.create_track(d) end -- (the tests make tracks themselves)
  return d
end

-- The MIDI input of a unit: the input with the output's name, else a Quad Cortex input of the same model that
-- no other device uses. "" when there is none.
function Dev.guess_input(d)
  local function used(name)
    for _, x in ipairs(S.devices) do if x ~= d and x.inport == name then return true end end
    return false
  end
  for _, p in ipairs(R.inports or {}) do
    if d.port ~= "" and p.name == d.port and not used(p.name) then return p.name end
  end
  for _, p in ipairs(R.inports or {}) do
    if Dev.model_from_port(p.name) == d.model and not used(p.name) then return p.name end
  end
  return ""
end

-- A device without a track: a track named "MIDI <name>" that no other device uses becomes its track
-- (for example after the device was removed and added again). Returns true when the device has a track.
function Dev.link_by_name(d)
  if Dev.track(d) then return true end
  if P.track_mode == "shared" then return false end
  local want = Dev.track_title(d)
  local used = {}
  for _, x in ipairs(S.devices) do if x ~= d and P.tracks[x.id] then used[P.tracks[x.id]] = true end end
  for g, tr in pairs(R.tracks) do
    if not used[g] and Dev.valid(g, tr) and Dev.track_name(tr) == want then
      P.tracks[d.id] = g; Util.mark_pdirty(); Dev.tag(tr, d)
      return true
    end
  end
  return false
end

-- Removes a device and (with_track) its track, in 1 undo step.
function Dev.remove_with_track(i, with_track)
  local d = S.devices[i]
  if not d then return end
  local tr = P.track_mode ~= "shared" and Dev.track(d)
  if tr then Dev.tag(tr, d) end -- (the settings go with the track: Add device or Ctrl+Z bring the device back)
  if tr and with_track then
    r.Undo_BeginBlock(); r.DeleteTrack(tr); r.Undo_EndBlock("MIDI Pilot: remove the track of " .. d.name, -1)
  end
  Dev.remove(i, tr and not with_track)
end

-- Each MIDI Pilot track keeps the settings of its device (track data "MIDI Pilot": 1 device line).
local TAG = "P_EXT:MIDIPilot"
function Dev.tag(tr, d)
  local line = Dev.serialize_list({ d })
  local _, cur = r.GetSetMediaTrackInfo_String(tr, TAG, "", false)
  if cur ~= line then r.GetSetMediaTrackInfo_String(tr, TAG, line, true) end
end
function Dev.tag_of(tr)
  local ok, line = r.GetSetMediaTrackInfo_String(tr, TAG, "", false)
  if not ok or line == "" then return nil end
  return Dev.parse_list(line)[1]
end

-- The MIDI Pilot tracks of this project that no device uses: { { guid, tr, dev } } (dev: the saved settings).
function Dev.orphans()
  local linked, ids = {}, {}
  for _, x in ipairs(S.devices) do
    ids[x.id] = true
    if P.tracks[x.id] then linked[P.tracks[x.id]] = true end
  end
  local out = {}
  for g, tr in pairs(R.tracks) do
    if not linked[g] and Dev.valid(g, tr) then
      local dv = Dev.tag_of(tr)
      if dv and not ids[dv.id] then out[#out + 1] = { guid = g, tr = tr, dev = dv } end
    end
  end
  table.sort(out, function(a, b) return r.GetMediaTrackInfo_Value(a.tr, "IP_TRACKNUMBER") < r.GetMediaTrackInfo_Value(b.tr, "IP_TRACKNUMBER") end)
  return out
end

-- Brings a device back from its track: its saved settings, names and the link.
function Dev.adopt(o, d)
  local keep_port = d and d.port ~= "" and d.port or nil
  d = d or {}
  for k, v in pairs(o.dev) do d[k] = v end
  if d.port == "" and keep_port then d.port = keep_port end
  local back = R.removed and R.removed[d.id]
  S.lib[d.id] = (back and back.lib) or Preset.parse_lib(Util.ext_get("lib_" .. d.id))
  S.fnames[d.id] = (back and back.fnames) or Preset.parse_fnames(Util.ext_get("fold_" .. d.id))
  S.snames[d.id] = (back and back.snames) or Preset.parse_snames(Util.ext_get("scn_" .. d.id))
  S.expr[d.id] = (back and back.expr) or Preset.parse_expr(Util.ext_get("exp_" .. d.id))
  S.knobs[d.id] = (back and back.knobs) or Knob.parse(Util.ext_get("knb_" .. d.id))
  if R.removed then R.removed[d.id] = nil end
  P.tracks[d.id] = o.guid
  Util.mark_pdirty(); Util.mark_sdirty(); R.conflicts = nil; R.bank_dirty = true; R.pick_cache, R.plist = nil, nil; R.fitems = nil
  return d
end

-- After an undo: a device removed in this session whose track came back (the same track GUID) is a device again,
-- with all its settings and names.
function Dev.restore_undone()
  if not R.removed or not next(R.removed) or P.track_mode == "shared" then return end
  local linked = {}
  for _, x in ipairs(S.devices) do if P.tracks[x.id] then linked[P.tracks[x.id]] = true end end
  for id, b in pairs(R.removed) do
    local tr = b.guid and R.tracks[b.guid]
    if not linked[b.guid] and Dev.valid(b.guid, tr) then
      S.lib[id] = b.lib or {}; S.fnames[id] = b.fnames or {}; S.snames[id] = b.snames or {}; S.expr[id] = b.expr or {}
      S.knobs[id] = b.knobs or Knob.parse("")
      P.tracks[id] = b.guid
      S.devices[#S.devices + 1] = b.d
      R.removed[id] = nil
      Util.mark_pdirty(); Util.mark_sdirty(); R.conflicts = nil; R.bank_dirty = true; R.pick_cache, R.plist = nil, nil; R.fitems = nil
      Util.notify("'" .. b.d.name .. "' is back, with its track.")
    end
  end
end

-- The connected units (their MIDI output names) that no device uses yet: the "Connected" part of Add device.
function Dev.free_units()
  local out = {}
  for _, p in ipairs(R.ports) do
    if Dev.model_from_port(p.name) and not Dev.port_used(p.name) then out[#out + 1] = p.name end
  end
  return out
end
-- A detected unit that no device uses yet, or nil.
function Dev.free_unit()
  for _, p in ipairs(R.ports) do
    if Dev.model_from_port(p.name) and not Dev.port_used(p.name) then return p.name end
  end
  return nil
end

-- The device name that a track name gives: without "MIDI " at the start ("MIDI QC Bass" -> "QC Bass").
function Dev.name_from_track(name)
  return (name:gsub("^MIDI ", "", 1):match("^%s*(.-)%s*$"))
end
-- When a project opens: a device track with an older device name (renamed while another project was open) gets
-- "MIDI " + the device's name (1 undo step). Returns the count.
function Dev.sync_names()
  if P.track_mode == "shared" then return 0 end
  local list = {}
  for _, d in ipairs(S.devices) do
    local tr = Dev.track(d)
    if tr then
      local _, cur = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      if Dev.name_from_track(cur) ~= d.name then list[#list + 1] = { tr, Dev.track_title(d) } end
    end
  end
  if #list == 0 then return 0 end
  r.Undo_BeginBlock()
  for _, x in ipairs(list) do r.GetSetMediaTrackInfo_String(x[1], "P_NAME", x[2], true) end
  r.Undo_EndBlock("MIDI Pilot: device tracks get the device names", -1)
  r.TrackList_AdjustWindows(false) -- (REAPER draws the new names at once)
  return #list
end

-- REAPER's "Reset all MIDI devices" (action 41175), then the outputs and inputs are read again.
function Dev.reset_midi()
  r.Main_OnCommand(41175, 0)
  Dev.read_ports()
  R.conflicts, R.status = nil, nil
  Util.notify("REAPER reset all MIDI devices.")
end

-- A change of the track in REAPER: the device follows its MIDI output and channel, and a rename of the track (also
-- its undo) renames the device (R.trname: the track names of the last scan; not in the first scan of a project).
function Dev.sync_from_tracks()
  if P.track_mode == "shared" then return end
  R.trname = R.trname or {}
  for _, d in ipairs(S.devices) do
    local tr = Dev.track(d)
    if tr then
      local _, nm = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local last = R.trname[d.id]
      if last and nm ~= last and not R.name_sync then
        local new = Dev.name_from_track(nm)
        if new ~= "" and new ~= d.name then d.name = new; Util.mark_sdirty(); R.conflicts = nil; R.bank_dirty = true end
      end
      R.trname[d.id] = nm
      local v = math.floor(r.GetMediaTrackInfo_Value(tr, "I_MIDIHWOUT"))
      if v >= 0 then
        local chan, name = v & 31, Dev.port_name(v >> 5)
        if chan <= 16 and chan ~= d.chan then d.chan = chan; Util.mark_sdirty() end
        if name and name ~= d.port then d.port = name; Util.mark_sdirty() end
      end
    end
  end
end

function Dev.remove(i, keep_data)
  local d = S.devices[i]
  if not d then return end
  table.remove(S.devices, i)
  local guid = P.tracks[d.id]
  if guid then P.tracks[d.id] = nil; Util.mark_pdirty() end
  -- the preset and folder names: kept for this session (Ctrl+Z of a removed track brings the device back);
  -- in the settings only while a kept track can bring the device back (Add device)
  R.removed = R.removed or {}
  R.removed[d.id] = { d = d, lib = S.lib[d.id], fnames = S.fnames[d.id], snames = S.snames[d.id], expr = S.expr[d.id],
    knobs = S.knobs[d.id], guid = guid }
  if not keep_data then
    r.DeleteExtState(CFG.EXT, "lib_" .. d.id, true); r.DeleteExtState(CFG.EXT, "fold_" .. d.id, true)
    r.DeleteExtState(CFG.EXT, "scn_" .. d.id, true); r.DeleteExtState(CFG.EXT, "knb_" .. d.id, true)
    r.DeleteExtState(CFG.EXT, "exp_" .. d.id, true)
  end
  S.lib[d.id] = nil; S.fnames[d.id] = nil; S.snames[d.id] = nil; S.expr[d.id] = nil; S.knobs[d.id] = nil; R.bank_dirty = true
  if Dev.is_default_name(d) then Dev.number_defaults(d.model) end
  R.sel_dev = Util.clamp(R.sel_dev, 1, math.max(1, #S.devices))
  Util.mark_sdirty(); R.conflicts = nil
end

-- The track of a device in this project (nil: none yet, or deleted).
function Dev.track_key(d) return P.track_mode == "shared" and "*" or d.id end
-- A track of the list R.tracks that is still that track (a deleted track's memory can be used again by a new one).
function Dev.valid(g, tr)
  return tr ~= nil and r.ValidatePtr2(R.proj, tr, "MediaTrack*") and r.GetTrackGUID(tr) == g
end
function Dev.track(d)
  local g = P.tracks[Dev.track_key(d)]
  local tr = g and R.tracks[g]
  if Dev.valid(g, tr) then return tr end
  return nil
end
function Dev.track_name(tr)
  local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return name ~= "" and name or ("Track " .. math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")))
end

-- REAPER's track MIDI hardware output value: -1 = none; else the output index * 32 + the channel (0 = all).
function Dev.hw_out(port_index, chan)
  if not port_index then return -1 end
  return port_index * 32 + (chan or 0)
end

-- Sets the track's MIDI hardware output to the device's output and channel (the shared track: all channels,
-- the output of the first device). Only when the value changes (no undo point for nothing).
function Dev.apply_out(d)
  local tr = Dev.track(d)
  if not tr then return end
  local v
  if P.track_mode == "shared" then
    v = Dev.hw_out(S.devices[1] and Dev.port_index(S.devices[1].port), 0)
  else
    v = Dev.hw_out(Dev.port_index(d.port), d.chan)
  end
  if math.floor(r.GetMediaTrackInfo_Value(tr, "I_MIDIHWOUT")) ~= v then
    r.SetMediaTrackInfo_Value(tr, "I_MIDIHWOUT", v)
  end
end

-- The latency of a device: REAPER's playback offset of its track (minus the latency), so REAPER sends the MIDI that
-- much earlier and the MIDI stays on the beat in the project. The shared track: the largest latency. Only when the
-- value changes (no undo point for nothing).
function Dev.apply_latency(d)
  local tr = Dev.track(d)
  if not tr then return end
  local lat = d.latency
  if P.track_mode == "shared" then
    lat = 0
    for _, x in ipairs(S.devices) do lat = math.max(lat, x.latency) end
  end
  local want = -lat / 1000
  local flag = math.floor(r.GetMediaTrackInfo_Value(tr, "I_PLAY_OFFSET_FLAG"))
  local cur = r.GetMediaTrackInfo_Value(tr, "D_PLAY_OFFSET")
  local on = lat > 0
  -- flag: 1 = the offset is off, 2 = in samples; MIDI Pilot uses seconds
  local want_flag = on and 0 or 1
  if flag ~= want_flag or math.abs(cur - (on and want or 0)) > 0.00001 then
    r.SetMediaTrackInfo_Value(tr, "I_PLAY_OFFSET_FLAG", want_flag)
    r.SetMediaTrackInfo_Value(tr, "D_PLAY_OFFSET", on and want or 0)
  end
end

-- The end of the MIDI item of a new track: the end of the last region, else of the project (at least 60 s).
function Dev.item_end()
  local e = 0
  for _, rg in ipairs(R.regions) do e = math.max(e, rg.stop) end
  if e <= 0 then e = r.GetProjectLength(R.proj) end
  return math.max(e, 60)
end

-- A new track at the end of the project for the device (or the shared track), with its MIDI output and an
-- empty MIDI item from the project start (the MIDI of the device goes in it).
function Dev.create_track(d)
  r.Undo_BeginBlock()
  local n = r.CountTracks(R.proj)
  r.InsertTrackAtIndex(n, true)
  local tr = r.GetTrack(R.proj, n)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", P.track_mode == "shared" and "MIDI Pilot" or Dev.track_title(d), true)
  P.tracks[Dev.track_key(d)] = r.GetTrackGUID(tr)
  R.tracks[r.GetTrackGUID(tr)] = tr
  Util.mark_pdirty()
  Dev.apply_out(d)
  if P.track_mode ~= "shared" then Dev.tag(tr, d) end
  Dev.apply_latency(d)
  r.CreateNewMIDIItemInProj(tr, 0, Dev.item_end(), false)
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: create the track of " .. d.name, -1)
end

-- The first selected track becomes the device's track (its MIDI output is set).
function Dev.use_selected_track(d)
  local tr = r.GetSelectedTrack(R.proj, 0)
  if not tr then return false end
  r.Undo_BeginBlock()
  P.tracks[Dev.track_key(d)] = r.GetTrackGUID(tr)
  R.tracks[r.GetTrackGUID(tr)] = tr
  Util.mark_pdirty()
  Dev.apply_out(d)
  if P.track_mode ~= "shared" then Dev.tag(tr, d) end
  if d.latency > 0 then Dev.apply_latency(d) end -- (latency 0: the track keeps its own playback offset)
  r.Undo_EndBlock("MIDI Pilot: use a track for " .. d.name, -1)
  return true
end

-- The warnings of the device list (cached; R.conflicts = nil makes them again): { text }.
function Dev.conflicts()
  if R.conflicts then return R.conflicts end
  local out = {}
  local ds = S.devices
  for i = 1, #ds do
    local a = ds[i]
    if a.port == "" then out[#out + 1] = a.name .. ": no MIDI output selected."
    elseif #R.ports > 0 and not Dev.port_index(a.port) then out[#out + 1] = a.name .. ": the MIDI output '" .. a.port .. "' is not available." end
    for j = i + 1, #ds do
      local b = ds[j]
      if a.port ~= "" and a.port == b.port then
        if a.chan == 0 or b.chan == 0 then
          out[#out + 1] = a.name .. " and " .. b.name .. " share an output, and 1 of them uses All channels: both units react to everything."
        elseif a.chan == b.chan then
          out[#out + 1] = a.name .. " and " .. b.name .. " use the same output and channel."
        end
      end
    end
  end
  if P and P.track_mode == "shared" and #ds > 1 then
    for i = 2, #ds do
      if ds[i].port ~= ds[1].port then
        out[#out + 1] = "One shared track has 1 MIDI output: " .. ds[i].name .. " uses another output than " .. ds[1].name .. "."
        break
      end
    end
  end
  R.conflicts = out
  return out
end

---------------------------------------------------------------------------
-- PRESET (numbers, labels, the preset, scene and folder names, the .reabank file)
---------------------------------------------------------------------------
-- A preset is a folder (CC#32) and an index (Quad Cortex 0-255: CC#0 = index // 128, Program = index % 128; Line 6
-- 0-127: the Program). The unit shows the index as bank + letter: Quad Cortex 8 letters (3B), mini 4 letters, Line 6
-- 4 letters with 2 digits (03B); fmt "num" (Line 6: Preset numbers > Numbers): 000-127.
function Preset.label(model, index, fmt)
  local m = MODELS[model]
  local L = m.letters
  local n = #L
  local k = index % n + 1
  if m.line6 then
    if fmt == "num" then return string.format("%03d", index) end
    return string.format("%02d%s", index // n + 1, L:sub(k, k))
  end
  return (index // n + 1) .. L:sub(k, k)
end
-- The label of a preset of a device (its own number format).
function Preset.plabel(d, index) return Preset.label(d.model, index, d.pnum) end
-- The unit's own name of folder f: Quad Cortex: Factory Presets, My Presets, User 1 ...; Line 6: Setlist 1 ...
function Preset.unit_folder(model, f)
  if MODELS[model].line6 then return "Setlist " .. (f + 1) end
  return FOLDERS[f] or ("Folder " .. f)
end
function Preset.index(model, bank, letter_i) return (bank - 1) * #MODELS[model].letters + (letter_i - 1) end
function Preset.key(folder, index) return folder .. ":" .. index end
function Preset.name(d, folder, index)
  local lib = S.lib[d.id]
  return lib and lib[Preset.key(folder, index)]
end
-- "3B Clean" (the name when it has one); the folder only when it is not the default one (My Presets, Setlist 1).
function Preset.text(d, folder, index)
  local nm = Preset.name(d, folder, index)
  local s = Preset.plabel(d, index) .. ((nm and nm ~= "") and ("  " .. nm) or "")
  if folder ~= MODELS[d.model].def_folder then s = s .. "  (" .. Preset.folder_name(d, folder) .. ")" end
  return s
end

-- The name of a folder: your name for it, else the unit's name (My Presets, User 1 ...).
-- Quad Cortex: Factory Presets (0) and My Presets (1) keep the unit's names; only the user folders can be renamed.
function Preset.fixed_folder(d, f) return not MODELS[d.model].line6 and f <= 1 end
function Preset.folder_name(d, f)
  local fn = S.fnames[d.id]
  return (not Preset.fixed_folder(d, f) and fn and fn[f]) or Preset.unit_folder(d.model, f)
end
function Preset.set_folder_name(d, f, name)
  S.fnames[d.id] = S.fnames[d.id] or {}
  name = Util.clean(name):match("^%s*(.-)%s*$")
  S.fnames[d.id][f] = (name ~= "" and name ~= Preset.unit_folder(d.model, f)) and name or nil
  R.fitems = nil; R.pick_cache, R.plist = nil, nil; R.bank_dirty = true; Util.mark_sdirty()
end
-- The folder dropdown items of a device (cached until a folder name changes).
function Preset.folder_items(d)
  R.fitems = R.fitems or {}
  local s = R.fitems[d.id]
  if s then return s end
  s = ""
  for v = 0, MODELS[d.model].folders - 1 do s = s .. Preset.folder_name(d, v) .. "\0" end
  R.fitems[d.id] = s
  return s
end
-- The name of scene v (0-7) of a preset: your name, else the unit's (A, B ... or A-I, B-II on the mini).
function Preset.scene_name(d, folder, index, v)
  local t = folder and S.snames[d.id] and S.snames[d.id][Preset.key(folder, index)]
  local nm = t and t[v + 1]
  return (nm and nm ~= "") and nm or MODELS[d.model].scenes[v + 1] or ("Scene " .. (v + 1))
end
function Preset.has_scene_name(d, folder, index, v)
  if not folder then return false end -- (no preset there)
  local t = S.snames[d.id] and S.snames[d.id][Preset.key(folder, index)]
  return t ~= nil and t[v + 1] ~= nil and t[v + 1] ~= ""
end
-- The colour (1-8 of SC_NORMAL) of scene v (0-7) of a preset: your choice, else colour v + 1.
function Preset.scene_col(d, folder, index, v)
  local t = folder and S.snames[d.id] and S.snames[d.id][Preset.key(folder, index)]
  return (t and t.c and t.c[v + 1]) or (v + 1)
end
-- names[1..8] and cols[1..8] (colour 1-8; the default colour is not saved).
function Preset.set_scene_names(d, folder, index, names, cols)
  S.snames[d.id] = S.snames[d.id] or {}
  local t, any = { c = {} }, false
  for v = 1, 8 do
    local nm = Util.clean(names[v] or ""):match("^%s*(.-)%s*$")
    if nm ~= "" then t[v] = nm; any = true end
    if cols and cols[v] and cols[v] ~= v then t.c[v] = cols[v]; any = true end
  end
  S.snames[d.id][Preset.key(folder, index)] = any and t or nil
  Util.mark_sdirty()
end
-- The scene names and colours move with a preset name (Presets > Edit...).
function Preset.move(d, f0, i0, f1, i1)
  local name = Preset.name(d, f0, i0)
  local sn = S.snames[d.id] and S.snames[d.id][Preset.key(f0, i0)]
  Preset.set_name(d, f0, i0, "")
  if S.snames[d.id] then S.snames[d.id][Preset.key(f0, i0)] = nil end
  Preset.set_name(d, f1, i1, name or "")
  S.snames[d.id] = S.snames[d.id] or {}
  S.snames[d.id][Preset.key(f1, i1)] = sn
  local ex = S.expr[d.id] and S.expr[d.id][Preset.key(f0, i0)]
  if ex then S.expr[d.id][Preset.key(f0, i0)] = nil; S.expr[d.id][Preset.key(f1, i1)] = ex end
  R.expr_txt = nil
  Util.mark_sdirty()
end
-- Scene names and colours, 1 line each: folder, index, scene (1-8), colour (empty: the default), name.
function Preset.parse_snames(txt)
  local out = {}
  for line in ((txt or "") .. "\n"):gmatch("([^\n]*)\n") do
    local f, i, v, c, nm = line:match("^(%d+)\t(%d+)\t(%d)\t(%d*)\t(.*)$")
    v = tonumber(v)
    if f and v and v >= 1 and v <= 8 then
      local k = Preset.key(tonumber(f), tonumber(i))
      out[k] = out[k] or { c = {} }
      if nm ~= "" then out[k][v] = nm end
      if tonumber(c) and tonumber(c) >= 1 and tonumber(c) <= 8 then out[k].c[v] = tonumber(c) end
    end
  end
  return out
end
function Preset.serialize_snames(sn)
  local out = {}
  for _, k in ipairs(Preset.sorted_keys(sn)) do
    local f, i = k:match("^(%d+):(%d+)$")
    local c = sn[k].c or {}
    for v = 1, 8 do
      if sn[k][v] or c[v] then
        out[#out + 1] = f .. "\t" .. i .. "\t" .. v .. "\t" .. (c[v] or "") .. "\t" .. Util.clean(sn[k][v] or "")
      end
    end
  end
  return table.concat(out, "\n")
end

-- The expression pedal assignments (Quad Cortex), 1 line each: folder, index, pedal (1-2), from %, to %, name, note.
function Preset.parse_expr(txt)
  local out = {}
  for line in ((txt or "") .. "\n"):gmatch("([^\n]*)\n") do
    local f, i, pd, a, b, nm, note = line:match("^(%d+)\t(%d+)\t([12])\t([%d%.]+)\t([%d%.]+)\t([^\t]*)\t?(.*)$")
    if f then
      local k = Preset.key(tonumber(f), tonumber(i))
      out[k] = out[k] or { {}, {} }
      local l = out[k][tonumber(pd)]
      l[#l + 1] = { name = nm, from = Util.clamp(tonumber(a), 0, 100), to = Util.clamp(tonumber(b), 0, 100), note = note }
    end
  end
  return out
end
function Preset.serialize_expr(ex)
  local out = {}
  for _, k in ipairs(Preset.sorted_keys(ex)) do
    local f, i = k:match("^(%d+):(%d+)$")
    for pd = 1, 2 do
      for _, a in ipairs(ex[k][pd] or {}) do
        out[#out + 1] = string.format("%s\t%s\t%d\t%s\t%s\t%s\t%s", f, i, pd, short_num(a.from), short_num(a.to),
          Util.clean(a.name), Util.clean(a.note or ""))
      end
    end
  end
  return table.concat(out, "\n")
end
-- The assignments of pedal pd (1-2) in a preset: { { name, from, to, note } } (empty: none).
function Preset.expr(d, folder, index, pd)
  local e = folder and S.expr[d.id] and S.expr[d.id][Preset.key(folder, index)]
  return e and e[pd] or {}
end
-- Saves the assignments of a preset: lists[1], lists[2] (rows without a name are dropped).
function Preset.set_expr(d, folder, index, lists)
  S.expr[d.id] = S.expr[d.id] or {}
  local e, any = { {}, {} }, false
  for pd = 1, 2 do
    for _, a in ipairs(lists[pd]) do
      local nm = Util.clean(a.name):match("^%s*(.-)%s*$")
      if nm ~= "" then
        e[pd][#e[pd] + 1] = { name = nm, from = Util.clamp(a.from, 0, 100), to = Util.clamp(a.to, 0, 100),
          note = Util.clean(a.note or ""):match("^%s*(.-)%s*$") }
        any = true
      end
    end
  end
  S.expr[d.id][Preset.key(folder, index)] = any and e or nil
  R.expr_txt = nil
  Util.mark_sdirty()
end

function Preset.parse_fnames(txt)
  local t = {}
  for line in ((txt or "") .. "\n"):gmatch("([^\n]*)\n") do
    local f, nm = line:match("^(%d+)\t(.+)$")
    if f and tonumber(f) <= 12 then t[tonumber(f)] = nm end
  end
  return t
end
function Preset.serialize_fnames(t)
  local out = {}
  for f = 0, 12 do if t and t[f] then out[#out + 1] = f .. "\t" .. Util.clean(t[f]) end end
  return table.concat(out, "\n")
end

-- The preset names of a device, 1 line each: folder, index, name.
function Preset.parse_lib(txt)
  local lib = {}
  for line in ((txt or "") .. "\n"):gmatch("([^\n]*)\n") do
    local f, i, nm = line:match("^(%d+)\t(%d+)\t(.*)$")
    if f and nm ~= "" then
      f, i = tonumber(f), tonumber(i)
      if f <= 12 and i <= 255 then lib[Preset.key(f, i)] = nm end
    end
  end
  return lib
end
function Preset.serialize_lib(lib)
  local keys = Preset.sorted_keys(lib)
  local t = {}
  for _, k in ipairs(keys) do
    local f, i = k:match("^(%d+):(%d+)$")
    t[#t + 1] = f .. "\t" .. i .. "\t" .. Util.clean(lib[k])
  end
  return table.concat(t, "\n")
end
-- The keys of a name list in the order folder, index.
function Preset.sorted_keys(lib)
  local keys = {}
  for k in pairs(lib or {}) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local fa, ia = a:match("^(%d+):(%d+)$"); local fb, ib = b:match("^(%d+):(%d+)$")
    fa, ia, fb, ib = tonumber(fa), tonumber(ia), tonumber(fb), tonumber(ib)
    if fa ~= fb then return fa < fb end
    return ia < ib
  end)
  return keys
end
-- The Preset list as its search row shows it: R.psearch (the name, the number or the folder) and S.preset_sort
-- (0 Number, 1 Name, 2 Used first: the Presets that this project's MIDI uses). Cached until a name, the search, the
-- sort or (Used first) the MIDI changes. Returns the keys and the number of names.
function Preset.list_view(d, lib)
  local n = 0
  for _ in pairs(lib) do n = n + 1 end
  local f, so = R.psearch or "", S.preset_sort
  local c = R.plist
  if c and c.lib == lib and c.n == n and c.f == f and c.sort == so and (so ~= 2 or c.pcs == R.pcs) then return c.keys, n end
  local keys = Preset.sorted_keys(lib)
  if f:match("%S") then
    local q, out = f:lower(), {}
    for _, k in ipairs(keys) do
      local fo, i = k:match("^(%d+):(%d+)$")
      local hay = (lib[k] .. " " .. Preset.plabel(d, tonumber(i)) .. " " .. Preset.folder_name(d, tonumber(fo))):lower()
      if hay:find(q, 1, true) then out[#out + 1] = k end
    end
    keys = out
  end
  if so == 1 then
    table.sort(keys, function(a, b)
      local x, y = lib[a]:lower(), lib[b]:lower()
      if x ~= y then return x < y end
      return a < b
    end)
  elseif so == 2 then -- the used ones first, each part in number order
    local used, u, o = {}, {}, {}
    for _, pc in ipairs(Midi.changes(d)) do used[pc.folder .. ":" .. pc.index] = true end
    for _, k in ipairs(keys) do if used[k] then u[#u + 1] = k else o[#o + 1] = k end end
    for _, k in ipairs(o) do u[#u + 1] = k end
    keys = u
  end
  R.plist = { lib = lib, n = n, f = f, sort = so, pcs = R.pcs, keys = keys }
  return keys, n
end
function Preset.set_name(d, folder, index, name)
  local lib = S.lib[d.id] or {}
  S.lib[d.id] = lib
  name = Util.clean(name):match("^%s*(.-)%s*$")
  lib[Preset.key(folder, index)] = (name ~= "") and name or nil
  Util.mark_sdirty(); R.bank_dirty = true; R.pick_cache, R.plist = nil, nil
end

-- The .reabank file: the names that REAPER's Bank/Program Select lane shows. 1 bank for each device,
-- folder and preset group (CC#0 0 or 1) that has a preset name; each program "3B Name".
function Preset.reabank_text()
  local t = { "// MIDI Pilot: the preset names of your Quad Cortex devices. Made by MIDI Pilot; changes here are replaced." }
  for _, d in ipairs(S.devices) do
    local groups = {}
    for k in pairs(S.lib[d.id] or {}) do
      local f, i = k:match("^(%d+):(%d+)$")
      groups[tonumber(f) * 2 + tonumber(i) // 128] = true
    end
    local gl = {}
    for g in pairs(groups) do gl[#gl + 1] = g end
    table.sort(gl)
    for _, g in ipairs(gl) do
      local f, msb = g // 2, g % 2
      t[#t + 1] = string.format("Bank %d %d %s - %s (%d-%d)", msb, f, Util.clean(d.name), Preset.folder_name(d, f), msb * 128 + 1, msb * 128 + 128)
      for pc = 0, 127 do
        local idx = msb * 128 + pc
        local nm = Preset.name(d, f, idx)
        t[#t + 1] = pc .. " " .. Preset.plabel(d, idx) .. ((nm and nm ~= "") and (" " .. nm) or "")
      end
    end
  end
  return table.concat(t, "\n") .. "\n"
end
function Preset.reabank_path()
  return r.GetResourcePath() .. "/Data/MIDI Pilot/" .. CFG.REABANK
end
function Preset.write_reabank()
  R.bank_dirty = false
  r.RecursiveCreateDirectory(r.GetResourcePath() .. "/Data/MIDI Pilot", 0)
  local f = io.open(Preset.reabank_path(), "w")
  if f then f:write(Preset.reabank_text()); f:close() end
end

---------------------------------------------------------------------------
-- KNOB (Lanes: a CC that moves a knob of the unit, in the units of that knob)
---------------------------------------------------------------------------
-- A knob: { cc, name, min, max, unit }. The CC goes from 0 to 127; the unit maps it to min .. max, evenly
-- (the expression pedal range that you set on the unit). A CC has 128 steps: some values cannot be sent.
function Knob.defaults()
  return { { cc = 1, name = "Expression 1", min = 0, max = 100, unit = "%" },
    { cc = 2, name = "Expression 2", min = 0, max = 100, unit = "%" } }
end
-- The knobs, 1 line each: cc, min, max, unit, name. Empty text: the 2 expression pedals.
function Knob.parse(txt)
  if not txt or txt == "" then return Knob.defaults() end
  local list = {}
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local cc, mn, mx, un, nm = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
    cc = tonumber(cc)
    if cc and cc <= 127 then
      local unit = "%"
      for _, u in ipairs(KNOB_UNITS) do if u == un then unit = u end end
      list[#list + 1] = { cc = cc, name = nm, min = tonumber(mn) or 0, max = tonumber(mx) or 100, unit = unit }
    end
  end
  return list
end
function Knob.serialize(list)
  local out = {}
  for _, k in ipairs(list or {}) do
    out[#out + 1] = string.format("%d\t%s\t%s\t%s\t%s", k.cc, short_num(k.min), short_num(k.max), k.unit, Util.clean(k.name))
  end
  if #out == 0 then return "-" end -- ("-": no knobs; empty would bring back the 2 expression pedals)
  return table.concat(out, "\n")
end
-- The controls of a device (Lanes > Control): Line 6: your CC controls (S.knobs); Quad Cortex: the 2 expression pedals
-- (always there, CC#1 and CC#2: your names from S.knobs), then the unit's functions (MODELS.funcs). Cached.
function Knob.list(d)
  local m = MODELS[d.model]
  S.knobs[d.id] = S.knobs[d.id] or Knob.parse("")
  if m.line6 then return S.knobs[d.id] end
  R.klist = R.klist or {}
  local c = R.klist[d.id]
  if c and c.model == d.model and c.src == S.knobs[d.id] then return c.list end
  local list = {}
  for pd = 1, 2 do
    local k
    for _, x in ipairs(S.knobs[d.id]) do if x.cc == pd then k = x; break end end
    if not k then
      k = { cc = pd, name = "Expression " .. pd, min = 0, max = 100, unit = "%" }
      table.insert(S.knobs[d.id], pd, k); Util.mark_sdirty()
    end
    k.min, k.max, k.unit = 0, 100, "%"
    list[#list + 1] = k
  end
  for _, f in ipairs(m.funcs or {}) do list[#list + 1] = f end
  R.klist[d.id] = { model = d.model, src = S.knobs[d.id], list = list }
  return list
end
-- The controls whose value plays on (Set up songs, Send state): Line 6: all; Quad Cortex: the 2 pedals.
function Knob.levels(d)
  if MODELS[d.model].line6 then return S.knobs[d.id] or {} end
  local l = Knob.list(d)
  return { l[1], l[2] }
end
-- The text of a value of a function (k.kind): the label of its choice (Open / Close: 0-63 / 64-127, as the unit).
function Knob.label(k, v)
  local best, bd
  for _, c in ipairs(k.choices) do
    local dist = math.abs(c[1] - v)
    if #k.choices == 2 and c[1] == 127 and v >= 64 then dist = -1 end
    if #k.choices == 2 and c[1] == 0 and v < 64 then dist = -1 end
    if not bd or dist < bd then best, bd = c[2], dist end
  end
  return best or tostring(v)
end
-- Quad Cortex: CC#1 and CC#2 are the 2 expression pedals: their value is the pedal position (0-100%), and each preset
-- says what they move (Preset.expr). Returns the pedal (1-2), or nil.
function Knob.pedal(d, k)
  if k.kind or MODELS[d.model].line6 or (k.cc ~= 1 and k.cc ~= 2) then return nil end
  return k.cc
end
-- The knob % of an assignment at a pedal position p (0-100).
function Knob.assign_at(a, p) return a.from + (a.to - a.from) * p / 100 end
-- The CC value (0-127) nearest to a value in units, and the value in units of a CC value.
function Knob.to_cc(k, v)
  if k.max == k.min then return 0 end
  return Util.clamp(math.floor((v - k.min) / (k.max - k.min) * 127 + 0.5), 0, 127)
end
function Knob.from_cc(k, c) return k.min + c / 127 * (k.max - k.min) end
-- A value with its unit: "650 Hz", "-6.5 dB", "45%".
function Knob.fmt(k, v)
  local u = k.unit
  local span = math.abs(k.max - k.min)
  local s = (span >= 100) and string.format("%.0f", v) or short_num(v)
  if u == "%" then return s .. "%" end
  if u == "" then return s end
  return s .. " " .. u
end
-- Reads a typed value: "650", "650 Hz", "1.2k", "-6 dB", "45%". Returns the number or nil.
function Knob.parse_value(s)
  s = (s or ""):lower():gsub("%s", ""):gsub("hz$", ""):gsub("db$", ""):gsub("ms$", ""):gsub("%%$", "")
  local num, kilo = s:match("^([%-%+]?%d*%.?%d+)(k?)$")
  if not num then return nil end
  return tonumber(num) * (kilo == "k" and 1000 or 1)
end

---------------------------------------------------------------------------
-- MIDI (the preset changes in the device's MIDI items: read, write, remove, send now)
---------------------------------------------------------------------------
-- The MIDI channel of a device's events (0-15; All channels: channel 1).
function Midi.chan(d) return d.chan == 0 and 0 or (d.chan - 1) end
function Midi.is_mine(d, chan) return d.chan == 0 or chan == d.chan - 1 end
-- The scene CC of a device (Quad Cortex CC#43, Line 6 CC#69) and its number of scenes (snapshots).
function Midi.scc(d) return MODELS[d.model].sc_cc end
function Midi.nsc(d) return #MODELS[d.model].scenes end
-- The short name of scene v on a strip block that is too small for its name ("BI", "S2").
function Midi.scene_short(d, v)
  local m = MODELS[d.model]
  return (m.short and m.short[v + 1]) or ((m.scenes[v + 1] or ""):gsub("%-", ""))
end

-- The part of a take that REAPER plays, in PPQ: from, to; nil when its item is muted (events outside it do not play).
function Midi.play_range(take)
  local item = r.GetMediaItemTake_Item(take)
  if r.GetMediaItemInfo_Value(item, "B_MUTE") == 1 then return nil end
  local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  return r.MIDI_GetPPQPosFromProjTime(take, pos) - 0.5, r.MIDI_GetPPQPosFromProjTime(take, pos + len) - 0.5
end

-- The MIDI takes on the device's track.
function Midi.takes(d)
  local out = {}
  local tr = Dev.track(d)
  if not tr then return out end
  for i = 0, r.CountTrackMediaItems(tr) - 1 do
    local item = r.GetTrackMediaItem(tr, i)
    local take = r.GetActiveTake(item)
    if take and r.TakeIsMIDI(take) then out[#out + 1] = take end
  end
  return out
end

-- The preset changes of a device, read from its MIDI (cached until the project changes): sorted by time,
-- { t, folder, index, take, ppq }. A Program Change uses the last CC#0 / CC#32 before it in the same take.
function Midi.changes(d)
  R.pcs = R.pcs or {}
  local c = R.pcs[d.id]
  if c then return c end
  c = {}
  for _, take in ipairs(Midi.takes(d)) do
    local msb, lsb = 0, MODELS[d.model].def_folder
    local p0, p1 = Midi.play_range(take)
    local ncc = p0 and select(3, r.MIDI_CountEvts(take)) or 0
    for i = 0, ncc - 1 do
      local _, _, muted, ppq, cm, ch, m2, m3 = r.MIDI_GetCC(take, i)
      if not muted and Midi.is_mine(d, ch) and ppq >= p0 and ppq < p1 then
        if cm == 0xB0 and m2 == 0 then msb = m3
        elseif cm == 0xB0 and m2 == 32 then lsb = m3
        elseif cm == 0xC0 then
          c[#c + 1] = { t = r.MIDI_GetProjTimeFromPPQPos(take, ppq), folder = lsb,
            index = MODELS[d.model].msb and (Util.clamp(msb, 0, 1) * 128 + m2) or m2,
            take = take, ppq = ppq }
        end
      end
    end
  end
  table.sort(c, function(a, b) return a.t < b.t end)
  R.pcs[d.id] = c
  return c
end

-- The preset change that belongs to a song: the first one from CFG.PC_WINDOW s before its start to its end.
function Midi.song_change(d, rg)
  for _, ch in ipairs(Midi.changes(d)) do
    -- (a change just before the next song belongs to the next song: its timing "before")
    if ch.t >= rg.start - CFG.PC_WINDOW and ch.t < rg.stop and not Midi.next_song_at(ch.t, rg) then return ch end
  end
  return nil
end
-- True when a song after rg starts in the CFG.PC_WINDOW s after time t (a change at t is that song's change).
function Midi.next_song_at(t, rg)
  for _, x in ipairs(R.regions) do
    if x.start > rg.start + 0.0001 and x.start >= t - 0.0001 and x.start <= t + CFG.PC_WINDOW then return true end
  end
  return false
end
-- The preset that is active at a time (the last change at or before it).
function Midi.active_at(d, t)
  local last
  for _, ch in ipairs(Midi.changes(d)) do
    if ch.t <= t + 0.0001 then last = ch else break end
  end
  return last
end

-- A time moved by the preset amount (kind "pc") or the scene amount ("sc"), in Settings > Editing; sign -1, 0, 1.
function Midi.shift(t, sign, kind)
  if sign == 0 then return t end
  local unit, ms, note = S.pc_unit, S.pc_ms, S.pc_note
  if kind == "sc" then unit, ms, note = S.sc_unit, S.sc_ms, S.sc_note end
  if unit == "notes" then
    return r.TimeMap2_QNToTime(R.proj, r.TimeMap2_timeToQN(R.proj, t) + sign * PC_NOTES[note][1])
  end
  return t + sign * ms / 1000
end
local function when_sign(w) return (w == "before" and -1) or (w == "after" and 1) or 0 end
-- The time of a preset ("pc") or a scene ("sc") that you add at time t (the edit cursor or a marker): exactly there,
-- or the amount before or after it (Settings > Editing > Other presets / Other scenes). Never before 0:00.
function Midi.other_time(kind, t)
  return math.max(0, Midi.shift(t, when_sign(kind == "pc" and S.pc_other or S.sc_other), kind))
end

-- The time of a song's First preset (Settings > Editing > Preset settings), and whether it was moved to 0:00.
function Midi.pc_time(rg)
  local sign = (S.pc_when == "before" and -1) or (S.pc_when == "after" and 1) or 0
  local t
  if S.pc_unit == "notes" then -- note values: on the beat grid (follows the tempo)
    local qn = r.TimeMap2_timeToQN(R.proj, rg.start) + sign * PC_NOTES[S.pc_note][1]
    t = (qn < 0) and -1 or r.TimeMap2_QNToTime(R.proj, qn)
  else
    t = rg.start + sign * S.pc_ms / 1000
  end
  if t < 0 then return 0, true end
  return t, false
end

-- A MIDI take of the device that covers time t: an item there, else the first MIDI item made longer,
-- else a new MIDI item. A muted item is never used (it does not play, and MIDI Pilot reads only what plays).
function Midi.take_at(d, t)
  local tr = Dev.track(d)
  if not tr then return nil end
  local first
  for i = 0, r.CountTrackMediaItems(tr) - 1 do
    local item = r.GetTrackMediaItem(tr, i)
    local take = r.GetActiveTake(item)
    if take and r.TakeIsMIDI(take) and r.GetMediaItemInfo_Value(item, "B_MUTE") ~= 1 then
      local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
      if t >= pos and t < pos + len then return take end
      first = first or item
    end
  end
  if first then
    local pos = r.GetMediaItemInfo_Value(first, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(first, "D_LENGTH")
    local s, e = math.min(pos, t), math.max(pos + len, t + 1)
    r.MIDI_SetItemExtents(first, r.TimeMap2_timeToQN(R.proj, s), r.TimeMap2_timeToQN(R.proj, e))
    return r.GetActiveTake(first)
  end
  local item = r.CreateNewMIDIItemInProj(tr, math.max(0, t), math.max(Dev.item_end(), t + 1), false)
  if item then Midi.mark_seen(item) end -- (MIDI Pilot's own item: not a new item to check)
  return item and r.GetActiveTake(item)
end

-- Removes the 3 events of a preset change (CC#0, CC#32 and the Program Change at its position).
function Midi.delete_change(d, ch)
  local take = ch.take
  if not r.ValidatePtr2(R.proj, take, "MediaItem_Take*") then return end
  local _, _, ncc = r.MIDI_CountEvts(take)
  for i = ncc - 1, 0, -1 do
    local _, _, _, ppq, cm, chn, m2 = r.MIDI_GetCC(take, i)
    if math.abs(ppq - ch.ppq) < 0.5 and Midi.is_mine(d, chn) and (cm == 0xC0 or (cm == 0xB0 and (m2 == 0 or m2 == 32))) then
      r.MIDI_DeleteCC(take, i)
    end
  end
end

-- Writes the events of a preset change at time t: CC#0 (the preset group; Quad Cortex only), CC#32 (the folder),
-- then the Program Change, at the same position, in this order (as REAPER's Bank/Program Select lane).
function Midi.insert_change(d, t, folder, index)
  local take = Midi.take_at(d, t)
  if not take then return false end
  local ppq = math.floor(r.MIDI_GetPPQPosFromProjTime(take, t) + 0.5)
  local ch = Midi.chan(d)
  if MODELS[d.model].msb then r.MIDI_InsertCC(take, false, false, ppq, 0xB0, ch, 0, index // 128) end
  r.MIDI_InsertCC(take, false, false, ppq, 0xB0, ch, 32, folder)
  r.MIDI_InsertCC(take, false, false, ppq, 0xC0, ch, index % 128, 0)
  r.MIDI_Sort(take)
  return true
end

-- Writes the preset of a song (no undo step): its old change goes, the new one is written at the time of
-- Settings > Editing > Preset settings > First preset (the scenes do not change). With folder nil: the change is removed.
-- Returns true when the time had to be moved to 0:00.
function Midi.write_song(d, rg, folder, index)
  local old = Midi.song_change(d, rg)
  if old then Midi.delete_change(d, old); R.pcs = {} end
  local t, moved = Midi.pc_time(rg)
  if folder then
    Midi.insert_change(d, t, folder, index)
  end
  R.pcs = {}
  return moved
end

-- The other preset changes inside a song (not its own preset change at its start): sorted by time.
function Midi.song_extra_pcs(d, rg)
  Midi.changes(d) -- (first: it makes R.pcs when the MIDI changed)
  local key = "xp" .. d.id .. ":" .. rg.start
  if R.pcs[key] then return R.pcs[key] end
  local own = Midi.song_change(d, rg)
  local out = {}
  for _, ch in ipairs(Midi.changes(d)) do
    if ch ~= own and ch.t >= rg.start - CFG.EDGE and ch.t < rg.stop - CFG.EDGE and not Midi.next_song_at(ch.t, rg) then
      out[#out + 1] = ch
    end
  end
  R.pcs[key] = out
  return out
end
-- A preset change inside a song: add one at time t, or (old) change or move one; folder nil: remove old. 1 undo step.
function Midi.put_pc(d, t, folder, index, old)
  r.Undo_BeginBlock()
  if old then Midi.delete_change(d, old); R.pcs = {} end
  if folder then Midi.insert_change(d, t, folder, index) end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock(folder and "MIDI Pilot: a Preset change in a song" or "MIDI Pilot: remove a Preset change", -1)
end

-- Sets (or with folder nil: removes) the preset of a song, in 1 undo step.
function Midi.set_song(d, rg, folder, index)
  r.Undo_BeginBlock()
  local moved = Midi.write_song(d, rg, folder, index)
  r.UpdateArrange()
  r.Undo_EndBlock(folder and ("MIDI Pilot: Preset of " .. rg.name) or ("MIDI Pilot: remove the Preset of " .. rg.name), -1)
  return moved
end

-- "Set up songs": a song without its own preset change gets the preset that is active at its start (so a start in
-- the middle of the show, or a jump, always finds the right preset), and a song without a start scene gets one.
-- Returns the number of changes.
function Midi.fill_starts(d)
  local n = 0
  r.Undo_BeginBlock()
  for _, rg in ipairs(R.regions) do
    if not Midi.song_change(d, rg) then
      local a = Midi.active_at(d, rg.start)
      if a then
        Midi.insert_change(d, (Midi.pc_time(rg)), a.folder, a.index); n = n + 1
        R.pcs = {}
      end
    end
    if Midi.preset_at(d, rg, rg.start) and Midi.ensure_start_scene(d, rg) then n = n + 1 end
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: fill songs", -1)
  return n
end

-- A preset number in a text ("Song One [3B]", "3B Song One", "Song One - 3B"; Line 6 "01A", or "000" with
-- Preset numbers: Numbers): the preset index, or nil.
function Preset.parse_label(d, s)
  local m = MODELS[d.model]
  for tok in (s or ""):gmatch("[%w]+") do
    if m.line6 and d.pnum == "num" then
      local n = tok:match("^(%d%d%d)$")
      if n and tonumber(n) < m.presets then return tonumber(n) end
    else
      local b, l = tok:match("^(%d%d?)(%a)$")
      local k = l and m.letters:find(l:upper(), 1, true)
      if b and k and tonumber(b) >= 1 and tonumber(b) <= m.banks then return Preset.index(d.model, tonumber(b), k) end
    end
  end
  return nil
end
-- The preset that a name means: a preset number in it (it wins), else a preset name (Presets tab). folder, index or nil.
function Preset.from_text(d, s, by_name)
  local idx = Preset.parse_label(d, s)
  if idx then return MODELS[d.model].def_folder, idx end
  local k = by_name[((s or ""):match("^%s*(.-)%s*$")):lower()]
  if k then
    local f, i = k:match("^(%d+):(%d+)$")
    return tonumber(f), tonumber(i)
  end
  return nil
end
-- The preset names of a device in lower case: name -> "folder:index".
function Preset.by_name(d)
  local by_name = {}
  for k, nm in pairs(S.lib[d.id] or {}) do by_name[nm:lower()] = by_name[nm:lower()] or k end
  return by_name
end

-- "Presets match Regions": a song whose name has a preset number ("Song One [3B]") or is the name of a preset
-- (Presets tab) gets that preset. Returns the number of songs changed.
function Midi.match_names(d)
  local by_name = Preset.by_name(d)
  local n = 0
  r.Undo_BeginBlock()
  for _, rg in ipairs(R.regions) do
    local f, i = Preset.from_text(d, rg.name, by_name)
    if f then
      local cur = Midi.song_change(d, rg)
      if not (cur and cur.folder == f and cur.index == i) then
        Midi.write_song(d, rg, f, i); n = n + 1
      end
    end
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: Presets from regions", -1)
  return n
end

-- "Presets match Markers": a marker inside a song named "P 3B" or "P <preset name>" gets a preset change at its place.
-- Returns the number written.
function Midi.match_marker_presets(d)
  local by_name = Preset.by_name(d)
  local n = 0
  r.Undo_BeginBlock()
  for _, mk in ipairs(R.markers) do
    local rest = mk.name:match("^%s*[Pp][%s:]+(.-)%s*$")
    local rg = Midi.song_at(mk.pos)
    if rest and rest ~= "" and rg then
      local f, i = Preset.from_text(d, rest, by_name)
      if f then
        local same = false
        local tp = Midi.other_time("pc", mk.pos)
        for _, ch in ipairs(Midi.changes(d)) do
          if math.abs(ch.t - tp) < 0.001 then
            if ch.folder == f and ch.index == i then same = true else Midi.delete_change(d, ch) end
          end
        end
        R.pcs = {}
        if not same then Midi.insert_change(d, tp, f, i); n = n + 1; R.pcs = {} end
      end
    end
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: Presets from markers", -1)
  return n
end

-- "Markers from scenes": a project marker with the scene name at each scene change of each song (not in a Scene
-- test); a marker with that name at that place is not added again. Returns the number added.
function Midi.markers_from_scenes(d)
  local n = 0
  r.Undo_BeginBlock()
  for _, rg in ipairs(R.regions) do
    local tests = Midi.song_tests(d, rg).of
    for _, s in ipairs(Midi.song_scenes(d, rg)) do
      if not tests[s] then
        local pc = Midi.preset_at(d, rg, s.t)
        local nm = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, s.v)
        local t = math.max(s.t, rg.start)
        local have = false
        for _, mk in ipairs(R.markers) do if mk.name == nm and math.abs(mk.pos - t) < CFG.EDGE + 0.001 then have = true end end
        if not have then
          r.AddProjectMarker2(R.proj, false, t, 0, nm, -1, 0)
          R.markers[#R.markers + 1] = { name = nm, pos = t }
          n = n + 1
        end
      end
    end
  end
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: markers from Scenes", -1)
  return n
end

-- ---------------------------------------------------------------------------------------------------------
-- Scenes. The rule: an edit writes exactly what you choose, where you choose it, and nothing else. A scene change is
-- 1 CC event (Quad Cortex CC#43, Line 6 CC#69); no edit moves, adds or removes other scene changes. Start scenes ("Set up songs") and
-- merging ("Merge repeated scenes") happen only from their menu items.

-- The Scene test in words, with the device's scene names: "every scene from A-I to D-II and back to A-I".
function Midi.test_words(d)
  local sc = MODELS[d.model].scenes
  return "every Scene from " .. sc[1] .. " to " .. sc[#sc] .. " and back to " .. sc[1]
end

-- The scene changes of a device, read from its MIDI (cached like Midi.changes): sorted by time, { t, v, take, ppq }.
function Midi.scenes(d)
  R.pcs = R.pcs or {}
  local key = "s" .. d.id
  local c = R.pcs[key]
  if c then return c end
  c = {}
  for _, take in ipairs(Midi.takes(d)) do
    local p0, p1 = Midi.play_range(take)
    local ncc = p0 and select(3, r.MIDI_CountEvts(take)) or 0
    for i = 0, ncc - 1 do
      local _, _, muted, ppq, cm, ch, m2, m3 = r.MIDI_GetCC(take, i)
      if not muted and cm == 0xB0 and m2 == Midi.scc(d) and m3 < Midi.nsc(d) and Midi.is_mine(d, ch) and ppq >= p0 and ppq < p1 then
        c[#c + 1] = { t = r.MIDI_GetProjTimeFromPPQPos(take, ppq), v = m3, take = take, ppq = ppq }
      end
    end
  end
  table.sort(c, function(a, b) return a.t < b.t end)
  R.pcs[key] = c
  return c
end

-- The scene changes of a song (from its start to its end).
function Midi.song_scenes(d, rg)
  local all = Midi.scenes(d) -- (first: it makes R.pcs when the MIDI changed)
  local key = "ss" .. d.id .. ":" .. rg.start
  local list = R.pcs[key]
  if list then return list end -- (cached like Midi.scenes: the callers only read it)
  list = {}
  for _, s in ipairs(all) do
    if s.t >= rg.start - CFG.EDGE and s.t < rg.stop - CFG.EDGE then list[#list + 1] = s end
  end
  R.pcs[key] = list
  return list
end

-- Removes 1 scene change (no undo step).
function Midi.delete_scene(d, s)
  if not r.ValidatePtr2(R.proj, s.take, "MediaItem_Take*") then return end
  local _, _, ncc = r.MIDI_CountEvts(s.take)
  for i = ncc - 1, 0, -1 do
    local _, _, _, ppq, cm, chn, m2 = r.MIDI_GetCC(s.take, i)
    if math.abs(ppq - s.ppq) < 0.5 and cm == 0xB0 and m2 == Midi.scc(d) and Midi.is_mine(d, chn) then r.MIDI_DeleteCC(s.take, i) end
  end
  R.pcs = {}
end

-- Writes scene v exactly at time t (no undo step). A scene change on the same MIDI tick is replaced.
function Midi.put_scene(d, t, v)
  local take = Midi.take_at(d, t)
  if not take then return end
  local ppq = math.floor(r.MIDI_GetPPQPosFromProjTime(take, t) + 0.5)
  local _, _, ncc = r.MIDI_CountEvts(take)
  for i = ncc - 1, 0, -1 do
    local _, _, _, p, cm, chn, m2 = r.MIDI_GetCC(take, i)
    if math.abs(p - ppq) < 0.5 and cm == 0xB0 and m2 == Midi.scc(d) and Midi.is_mine(d, chn) then r.MIDI_DeleteCC(take, i) end
  end
  r.MIDI_InsertCC(take, false, false, ppq, 0xB0, Midi.chan(d), Midi.scc(d), v)
  r.MIDI_Sort(take)
  R.pcs = {}
end

-- 1 undo step around an edit of the scenes.
function Midi.scene_edit(name, fn)
  r.Undo_BeginBlock()
  local res = fn()
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: " .. name, -1)
  return res
end

-- The edits of single scene changes (each 1 undo step).
function Midi.add_scene(d, t, v)
  Midi.scene_edit("add a Scene change", function() Midi.put_scene(d, t, v) end)
end
function Midi.change_scene(d, s, v)
  Midi.scene_edit("change a Scene", function() Midi.delete_scene(d, s); Midi.put_scene(d, s.t, v) end)
end
function Midi.move_scene(d, s, t)
  Midi.scene_edit("move a Scene change", function() Midi.delete_scene(d, s); Midi.put_scene(d, t, s.v) end)
end
function Midi.remove_scene(d, s)
  Midi.scene_edit("remove a Scene change", function() Midi.delete_scene(d, s) end)
end

-- Nudge: a time moved by the nudge amount (Settings > Editing > Nudge), dir -1 (earlier) or 1 (later).
function Midi.nudged(t, dir)
  if S.nudge_unit == "notes" then
    return r.TimeMap2_QNToTime(R.proj, r.TimeMap2_timeToQN(R.proj, t) + dir * PC_NOTES[S.nudge_note][1])
  end
  return t + dir * S.nudge_ms / 1000
end
-- The nudge amount as text: "10 ms" or "1/32 note".
function Midi.nudge_text()
  return S.nudge_unit == "notes" and PC_NOTES[S.nudge_note][2] or (S.nudge_ms .. " ms")
end
-- Nudges all scene changes (not the start scene) and all knob values of a song, in 1 undo step. Returns false
-- (nothing moved) when a change would leave the song.
function Midi.nudge_song(d, rg, dir)
  local st = Midi.start_scene(d, rg)
  local sc = {}
  for _, s in ipairs(Midi.song_scenes(d, rg)) do if s ~= st then sc[#sc + 1] = s end end
  local kv = {}
  for _, k in ipairs(Knob.list(d)) do
    for _, e in ipairs(Midi.ccs(d, k.cc)) do
      if e.t >= rg.start - CFG.EDGE and e.t < rg.stop - CFG.EDGE then kv[#kv + 1] = { k = k, e = e } end
    end
  end
  if #sc == 0 and #kv == 0 then return true end
  for _, s in ipairs(sc) do
    local nt = Midi.nudged(s.t, dir)
    if nt < rg.start + CFG.EDGE or nt >= rg.stop - CFG.EDGE or (st and nt <= st.t + CFG.EDGE) then return false end
  end
  for _, x in ipairs(kv) do
    local nt = Midi.nudged(x.e.t, dir)
    if nt < rg.start or nt >= rg.stop - CFG.EDGE then return false end
  end
  Midi.scene_edit("nudge " .. rg.name, function()
    -- remove all first, then write all (a moved change never replaces another moved one)
    for _, s in ipairs(sc) do Midi.delete_scene(d, s) end
    for _, x in ipairs(kv) do Midi.delete_cc(d, x.k.cc, x.e) end
    for _, s in ipairs(sc) do Midi.put_scene(d, Midi.nudged(s.t, dir), s.v) end
    for _, x in ipairs(kv) do Midi.write_cc(d, x.k.cc, Midi.nudged(x.e.t, dir), x.e.v, x.e.shape, x.e.tension) end
  end)
  return true
end

-- Scene test: every scene of the model up and back (Midi.test_seq: A-I up to D-II and back to A-I), a change every
-- CFG.TEST_BEATS beats from time t.
function Midi.test_seq(d)
  local n = Midi.nsc(d)
  local seq = {}
  for v = 0, n - 1 do seq[#seq + 1] = v end
  for v = n - 2, 0, -1 do seq[#seq + 1] = v end
  return seq
end
-- The times of its n changes, and its end (CFG.TEST_BEATS after its last change).
function Midi.test_times(t, n)
  local q0 = r.TimeMap2_timeToQN(R.proj, t)
  local times = {}
  for k = 1, n do times[k] = r.TimeMap2_QNToTime(R.proj, q0 + (k - 1) * CFG.TEST_BEATS) end
  return times, r.TimeMap2_QNToTime(R.proj, q0 + n * CFG.TEST_BEATS)
end
-- True when a test of device d from time t fits in the song (its last change before the song end).
function Midi.test_fits(d, rg, t)
  local times = Midi.test_times(t, #Midi.test_seq(d))
  return t >= rg.start - 0.0001 and times[#times] < rg.stop
end
-- Writes a test from time t (no undo step): the scene changes in its section are replaced. At its end, a stopping
-- point: a normal scene change back to the scene that played before the test (else the first scene), so the part
-- after the test has its own scene change (a row in the list, a right-click on the timeline). Not when a scene change
-- is already there, or the song ends there.
local function write_test(d, rg, t)
  local seq = Midi.test_seq(d)
  local times, tend = Midi.test_times(t, #seq)
  local back, at_end = 0, false
  for _, s in ipairs(Midi.song_scenes(d, rg)) do
    if s.t < t - 0.0001 then back = s.v end
    if math.abs(s.t - tend) < 0.001 then at_end = true end
  end
  for _, s in ipairs(Midi.song_scenes(d, rg)) do
    if s.t >= t - 0.0001 and s.t < tend - 0.0001 then Midi.delete_scene(d, s) end
  end
  for k, v in ipairs(seq) do Midi.put_scene(d, times[k], v) end
  if not at_end and tend < rg.stop - CFG.EDGE then Midi.put_scene(d, tend, back) end
  return tend
end
-- Adds a test at time t (1 undo step). Returns its end time, or nil when it does not fit (nothing written).
function Midi.add_test(d, rg, t)
  if not Midi.test_fits(d, rg, t) then return nil end
  return Midi.scene_edit("Scene test in " .. rg.name, function() return write_test(d, rg, t) end)
end
-- Removes a test; with t: moves it there (1 undo step). Returns false when it does not fit there (nothing changed).
function Midi.remove_test(d, rg, g, t)
  if t and not Midi.test_fits(d, rg, t) then return false end
  Midi.scene_edit(t and "move a Scene test" or "remove a Scene test", function()
    for _, s in ipairs(g.evs) do Midi.delete_scene(d, s) end
    local before = 0 -- (the scene before the test: its stopping point brings it back)
    for _, s in ipairs(Midi.song_scenes(d, rg)) do if s.t < g.t0 - 0.0001 then before = s.v end end
    for _, s in ipairs(Midi.song_scenes(d, rg)) do -- (its stopping point goes with it; your own change there stays)
      if math.abs(s.t - g.t1) < 0.001 and s.v == before then Midi.delete_scene(d, s) end
    end
    if t then write_test(d, rg, t) end
  end)
  return true
end

-- The scene tests of a song (cached until the MIDI changes): runs of scene changes with the values Midi.test_seq,
-- CFG.TEST_BEATS beats apart. Each: { evs, t0 (its 1st change), t1 (its end) }; of[ev] = the test of a change.
function Midi.song_tests(d, rg)
  R.pcs = R.pcs or {}
  local key = "t" .. d.id .. ":" .. rg.start
  local c = R.pcs[key]
  if c then return c end
  c = { of = {} }
  local seq = Midi.test_seq(d)
  local list, n = Midi.song_scenes(d, rg), #seq
  local i = 1
  while i <= #list - n + 1 do
    local good = true
    local q0 = r.TimeMap2_timeToQN(R.proj, list[i].t)
    for k = 1, n do
      local s = list[i + k - 1]
      if s.v ~= seq[k] or math.abs(r.TimeMap2_timeToQN(R.proj, s.t) - (q0 + (k - 1) * CFG.TEST_BEATS)) > 0.02 then
        good = false; break
      end
    end
    if good then
      local g = { evs = {}, t0 = list[i].t, t1 = math.min(rg.stop, r.TimeMap2_QNToTime(R.proj, q0 + n * CFG.TEST_BEATS)) }
      for k = 1, n do g.evs[k] = list[i + k - 1]; c.of[list[i + k - 1]] = g end
      c[#c + 1] = g
      i = i + n
    else i = i + 1 end
  end
  R.pcs[key] = c
  return c
end

-- The preset of a song at time t: the song's own preset change when t is before it (the start scene and the first
-- part of the song belong to the song's preset), else the preset that is active at t.
function Midi.preset_at(d, rg, t)
  local own = Midi.song_change(d, rg)
  if own and t < own.t + 0.0002 then return own end
  return Midi.active_at(d, t + 0.0002)
end
-- The time of a new first scene ("Set up songs"; Settings > Editing > First scene): at the region start, the scene
-- amount before or after it, or after the region's preset: the amount after the song's preset change, but never
-- before the region start (without a preset change: the region start).
function Midi.start_time(d, rg)
  local w = S.sc_first
  if w == "after_pc" then
    local own = Midi.song_change(d, rg)
    if own then return math.max(rg.start, Midi.shift(own.t, 1, "sc")) end
    return rg.start
  end
  return math.max(0, Midi.shift(rg.start, when_sign(w), "sc"))
end
-- The next song after a song (in timeline order), or nil.
function Midi.next_song(rg)
  for i, x in ipairs(R.regions) do if x == rg then return R.regions[i + 1] end end
  return nil
end
-- The start scene of a song: its first scene change, when it is in its first CFG.START_WINDOW seconds
-- (or before its new start scene time).
function Midi.start_scene(d, rg)
  local ts = Midi.start_time(d, rg)
  local hi = math.min(rg.stop, math.max(ts + 0.01, rg.start + CFG.START_WINDOW))
  local lo = math.min(rg.start, ts) - CFG.EDGE -- (First scene "before": it comes before the region start)
  for _, s in ipairs(Midi.scenes(d)) do
    if s.t >= lo and s.t < hi then return s end
    if s.t >= hi then break end
  end
  return nil
end
-- The default start scene: the first scene with a name in the preset, else scene 1 (A).
function Midi.default_start(d, pc)
  if pc then
    for v = 0, Midi.nsc(d) - 1 do if Preset.has_scene_name(d, pc.folder, pc.index, v) then return v end end
  end
  return 0
end
-- "Set up songs": a song without a start scene gets the default one (no undo step). Returns true when written.
function Midi.ensure_start_scene(d, rg)
  if not rg or Midi.start_scene(d, rg) then return false end
  local t = Midi.start_time(d, rg)
  Midi.put_scene(d, t, Midi.default_start(d, Midi.preset_at(d, rg, t)))
  return true
end

-- ---------------------------------------------------------------------------------------------------------
-- New MIDI items (Settings > Devices > Check new MIDI items): a MIDI item that appears on a device's track (copied,
-- dragged or recorded) is checked once: its MIDI channel becomes the device's channel (more than 1 channel: a
-- question), then each song that starts inside it gets a scene change at its start when it has none there.
local function item_guid(item)
  local _, g = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
  return g
end
-- The items seen in this project (in this session): an item is new only once (also after an undo).
-- R.seen[project] = { items = { [item GUID] = true }, tracks = { [track GUID] = true } }
local function seen_of_proj()
  R.seen = R.seen or {}
  R.seen[R.proj] = R.seen[R.proj] or { items = {}, tracks = {} }
  return R.seen[R.proj]
end
function Midi.mark_seen(item) seen_of_proj().items[item_guid(item)] = true end
-- After each project change: the MIDI items not seen before on the device tracks. A track seen for the first time
-- (the project was opened, a track was created or linked) only notes its items: they are not new.
function Midi.find_new_items()
  local sp = seen_of_proj()
  local seen = sp.items
  local found = {}
  for _, d in ipairs(S.devices) do
    local tr = Dev.track(d)
    if tr then
      local tg = r.GetTrackGUID(tr)
      local first = not sp.tracks[tg]
      sp.tracks[tg] = true
      for i = 0, r.CountTrackMediaItems(tr) - 1 do
        local item = r.GetTrackMediaItem(tr, i)
        local g = item_guid(item)
        if not seen[g] then
          seen[g] = true
          local take = r.GetActiveTake(item)
          if not first and S.check_items and take and r.TakeIsMIDI(take) then
            found[d] = found[d] or {}
            found[d][#found[d] + 1] = item
          end
        end
      end
    end
  end
  for d, items in pairs(found) do
    if not R.chq then Midi.check_items(d, items) end
  end
end

-- The MIDI channels (0-15) used in some items: a sorted list.
function Midi.item_channels(items)
  local set, list = {}, {}
  for _, item in ipairs(items) do
    local take = r.GetActiveTake(item)
    local _, nn, ncc = r.MIDI_CountEvts(take)
    for i = 0, ncc - 1 do
      local _, _, _, _, _, ch = r.MIDI_GetCC(take, i); set[ch] = true
    end
    for i = 0, nn - 1 do
      local _, _, _, _, _, ch = r.MIDI_GetNote(take, i); set[ch] = true
    end
  end
  for ch in pairs(set) do list[#list + 1] = ch end
  table.sort(list)
  return list
end

-- Checks new items of a device: first the channel (own track, not "All channels"), then the song starts.
function Midi.check_items(d, items)
  if P.track_mode ~= "shared" and d.chan ~= 0 then
    local chans = Midi.item_channels(items)
    -- the device's MIDI that is already on the track (other items, the current channel): a switch would leave it
    local is_new, other = {}, false
    for _, item in ipairs(items) do is_new[r.GetActiveTake(item)] = true end
    for _, take in ipairs(Midi.takes(d)) do
      if not is_new[take] then
        local _, _, ncc = r.MIDI_CountEvts(take)
        for i = 0, ncc - 1 do
          local _, _, _, _, _, ch = r.MIDI_GetCC(take, i)
          if ch == d.chan - 1 then other = true; break end
        end
      end
      if other then break end
    end
    local switch = #chans == 1 and chans[1] ~= d.chan - 1
    if #chans > 1 or (switch and other) then
      local list = { d.chan - 1 }
      for _, ch in ipairs(chans) do if ch ~= d.chan - 1 then list[#list + 1] = ch end end
      table.sort(list)
      R.chq = { d = d, items = items, chans = list, other = other, open = true } -- (the question: UI.draw_chan_ask)
      return
    elseif switch then
      Midi.set_channel(d, chans[1] + 1)
      if UI.toast then UI.toast(string.format("%s: channel %d (the channel of the new MIDI item).", d.name, d.chan)) end
    end
  end
  Midi.fill_item_starts(d, items)
end
-- The channel of a device (1-16), saved.
function Midi.set_channel(d, ch)
  d.chan = ch
  R.pcs, R.conflicts = {}, nil
  Util.mark_sdirty()
  Dev.apply_out(d)
end

-- Each song that starts inside the items and has no scene change at its start gets one, exactly at its start:
-- the scene that plays there (from a scene change before it), else A-I. 1 undo step. Returns the number added.
function Midi.fill_item_starts(d, items)
  local n = 0
  Midi.scene_edit("Scenes at the song starts", function()
    for _, rg in ipairs(R.regions) do
      local inside = false
      for _, item in ipairs(items) do
        local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
        if rg.start >= pos - 0.0001 and rg.start < pos + len then inside = true end
      end
      if inside then
        local has, v = false, 0
        for _, s in ipairs(Midi.scenes(d)) do
          if math.abs(s.t - rg.start) < CFG.EDGE then has = true end
          if s.t < rg.start - CFG.EDGE then v = s.v end
        end
        if not has then Midi.put_scene(d, rg.start, v); n = n + 1 end
      end
    end
  end)
  if n > 0 and UI.toast then UI.toast(string.format("%s: %d Scene change(s) added at the song starts.", d.name, n)) end
  return n
end

-- "Merge repeated scenes" (the Tools menu): in each song, a scene change to the scene that already plays is removed (not the
-- start scene, not a part of a scene test), in 1 undo step. Returns the number removed.
function Midi.merge_all(d)
  local n = 0
  Midi.scene_edit("merge repeated Scenes", function()
    for _, rg in ipairs(R.regions) do
      local prev
      local st = Midi.start_scene(d, rg)
      local tg = Midi.song_tests(d, rg)
      local tests = tg.of
      local function at_test_end(s)
        for _, g in ipairs(tg) do if math.abs(s.t - g.t1) < 0.001 then return true end end
        return false
      end
      for _, s in ipairs(Midi.song_scenes(d, rg)) do
        if prev ~= nil and s.v == prev and s ~= st and not tests[s] and not at_test_end(s) and s.t > rg.start + CFG.EDGE then
          Midi.delete_scene(d, s); n = n + 1
        else prev = s.v end
      end
    end
  end)
  return n
end

-- Removes the scene changes of a song ("Clear scenes"), or with rg nil: all scene changes of the device
-- ("Clear all scenes"); with presets: all preset changes ("Clear all presets"). Returns the number removed.
function Midi.clear(d, rg, presets)
  local n = 0
  Midi.scene_edit(presets and "clear all Presets" or (rg and ("clear the Scenes of " .. rg.name) or "clear all Scenes"),
    function()
      if presets then
        for _, ch in ipairs(Midi.changes(d)) do Midi.delete_change(d, ch); n = n + 1 end
      else
        for _, s in ipairs(rg and Midi.song_scenes(d, rg) or Midi.scenes(d)) do Midi.delete_scene(d, s); n = n + 1 end
      end
    end)
  return n
end

-- "Scenes match Markers": a marker inside a song whose name is a scene name of the preset there (or the
-- scene's letter, A or B-II) gets that scene change. Markers of other scripts (PDFPAGE, PDFSCROLL) are skipped.
-- Returns the number of scene changes written.
function Midi.match_markers(d)
  local n = 0
  r.Undo_BeginBlock()
  for _, mk in ipairs(R.markers) do
    local nm = mk.name:match("^%s*(.-)%s*$"):lower()
    local inside = false
    for _, rg in ipairs(R.regions) do if mk.pos >= rg.start and mk.pos < rg.stop then inside = true end end
    if nm ~= "" and inside and not nm:match("^pdfpage") and not nm:match("^pdfscroll") then
      local pc = Midi.active_at(d, mk.pos)
      for v = 0, Midi.nsc(d) - 1 do
        local sn = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v):lower()
        if sn == nm or MODELS[d.model].scenes[v + 1]:lower() == nm then
          local cur
          local tsc = Midi.other_time("sc", mk.pos)
          for _, s in ipairs(Midi.scenes(d)) do if math.abs(s.t - tsc) < 0.001 then cur = s end end
          if not (cur and cur.v == v) then Midi.put_scene(d, tsc, v); n = n + 1 end
          break
        end
      end
    end
  end
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: Scenes from markers", -1)
  return n
end

-- The CC events of a knob (one CC number), cached like Midi.changes: sorted by time, { t, v, take, ppq }.
function Midi.ccs(d, cc)
  R.pcs = R.pcs or {}
  local key = "c" .. cc .. d.id
  local c = R.pcs[key]
  if c then return c end
  c = {}
  for _, take in ipairs(Midi.takes(d)) do
    local p0, p1 = Midi.play_range(take)
    local ncc = p0 and select(3, r.MIDI_CountEvts(take)) or 0
    for i = 0, ncc - 1 do
      local _, _, muted, ppq, cm, ch, m2, m3 = r.MIDI_GetCC(take, i)
      if not muted and cm == 0xB0 and m2 == cc and Midi.is_mine(d, ch) and ppq >= p0 and ppq < p1 then
        local _, shape, tension = r.MIDI_GetCCShape(take, i)
        c[#c + 1] = { t = r.MIDI_GetProjTimeFromPPQPos(take, ppq), v = m3, take = take, ppq = ppq,
          shape = shape or 0, tension = tension or 0 }
      end
    end
  end
  table.sort(c, function(a, b) return a.t < b.t end)
  R.pcs[key] = c
  return c
end
-- The end of a ramp that starts at t0: len = an index of RAMP_LENS (beats follow the tempo, bars the time
-- signature; the last item: the end of REAPER's time selection, nil when there is none after t0).
-- A typed length "bars.beats": "3" = 3 bars, "0.6" = 6 beats, "2.2" = 2 bars and 2 beats. Returns bars, beats or nil.
function Midi.parse_length(s)
  s = (s or ""):match("^%s*(.-)%s*$")
  local bars, beats = s:match("^(%d*)%.(%d+)$")
  if not bars then bars, beats = s:match("^(%d+)$"), "0" end
  bars, beats = tonumber(bars ~= "" and bars or "0"), tonumber(beats)
  if not bars or not beats or (bars == 0 and beats == 0) then return nil end
  return bars, beats
end
-- custom: the typed length of the "Custom..." item (nil when it is not a length).
function Midi.ramp_end(t0, len, custom)
  local l = RAMP_LENS[len]
  if l.custom then
    local bars, beats = Midi.parse_length(custom)
    if not bars then return nil end
    local b, m = r.TimeMap2_timeToBeats(R.proj, t0)
    local t = (bars > 0) and r.TimeMap2_beatsToTime(R.proj, b, m + bars) or t0
    return r.TimeMap2_QNToTime(R.proj, r.TimeMap2_timeToQN(R.proj, t) + beats)
  end
  if l[1] > 0 then return r.TimeMap2_QNToTime(R.proj, r.TimeMap2_timeToQN(R.proj, t0) + l[1]) end
  if l[2] > 0 then
    local b, m = r.TimeMap2_timeToBeats(R.proj, t0)
    return r.TimeMap2_beatsToTime(R.proj, b, m + l[2])
  end
  local _, e = r.GetSet_LoopTimeRange2(R.proj, false, false, 0, 0, false)
  if e and e > t0 + 0.001 then return e end
  return nil
end
-- A ramp or a swell of a knob, in 1 undo step: pts = { { t, v, shape, tension } } in time order (the slope of a
-- point goes to the next point; the last point: a jump). The values of that knob between the first and the last
-- point are replaced.
function Midi.add_ramp(d, cc, pts, name)
  local t0, t1 = pts[1].t, pts[#pts].t
  r.Undo_BeginBlock()
  for _, e in ipairs(Midi.ccs(d, cc)) do
    if e.t >= t0 - 0.0005 and e.t <= t1 + 0.0005 then Midi.delete_cc(d, cc, e) end
  end
  R.pcs = {}
  for i, pt in ipairs(pts) do
    Midi.write_cc(d, cc, pt.t, pt.v, i < #pts and pt.shape or 0, i < #pts and pt.tension or 0)
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: " .. (name or "ramp"), -1)
end
-- The points of a ramp from t0 (v0) to t1 (v1); a swell (sw): a hold at v1 (sw.hold: an index of RAMP_LENS or 0),
-- then the way back to sw.v2 over sw.len with its own slope. Returns the points and the end time.
function Midi.ramp_points(t0, t1, v0, v1, shape, tension, sw)
  local pts = { { t = t0, v = v0, shape = shape, tension = tension } }
  if not sw then
    pts[2] = { t = t1, v = v1 }
    return pts, t1
  end
  local tb = t1
  if sw.hold > 0 then
    pts[2] = { t = t1, v = v1, shape = 0, tension = 0 } -- (the hold: the value stays)
    tb = Midi.ramp_end(t1, sw.hold, sw.hold_c)
    if not tb then return nil end
  end
  pts[#pts + 1] = { t = tb, v = v1, shape = sw.shape, tension = sw.tension }
  local t2 = Midi.ramp_end(tb, sw.len, sw.len_c)
  if not t2 then return nil end
  pts[#pts + 1] = { t = t2, v = sw.v2 }
  return pts, t2
end

-- The time of 1 LFO cycle at time t, in quarter notes: rate = an index of LFO_RATES (bars: the time signature at t).
function Midi.lfo_cycle(t, rate)
  local l = LFO_RATES[rate]
  if l[2] > 0 then
    local num, den = r.TimeMap_GetTimeSigAtTime(R.proj, t)
    return l[2] * num * 4 / den
  end
  return l[1]
end
-- The points of an LFO from t0 to t1 between the CC values lo and hi (the 2 fields): shape 0 Sine, 1 Triangle,
-- 2 Square, 3 Saw up, 4 Saw down (a saw goes from lo to hi); cyc: 1 cycle in quarter notes (it follows the tempo);
-- high: Sine, Triangle and Square start at hi. 1 point at each top and bottom with a slope to the next one (a saw:
-- a straight slope, then a jump back just before the next cycle); the last point at t1: the value there, or fin (a
-- CC value: a jump to it at the end); grow: 1 the peaks grow, 2 they shrink, step by step over the whole LFO (the
-- start value stays: 0-100 with 4 peaks: 0-25, 0-50, 0-75, 0-100). nil when there is no room.
function Midi.lfo_points(t0, t1, lo, hi, shape, cyc, high, fin, grow)
  local q0, q1 = r.TimeMap2_timeToQN(R.proj, t0), r.TimeMap2_timeToQN(R.proj, t1)
  if q1 - q0 < 1e-6 or cyc <= 0 then return nil end
  local a, b = lo, hi
  if shape <= 2 and high then a, b = hi, lo end
  local pts = {}
  local function add(q, v, s)
    pts[#pts + 1] = { t = r.TimeMap2_QNToTime(R.proj, q), v = Util.clamp(math.floor(v + 0.5), 0, 127), shape = s, tension = 0 }
  end
  local function peak(p, np) -- the value of peak p of np
    if grow == 1 then return a + (b - a) * p / np elseif grow == 2 then return a + (b - a) * (np - p + 1) / np end
    return b
  end
  if shape <= 2 then -- a top or a bottom every half cycle
    local half, s = cyc / 2, (shape == 0 and 2) or (shape == 1 and 1) or 0
    local nh = 0
    while q0 + nh * half < q1 - 1e-6 do nh = nh + 1 end
    local np = math.floor((nh + 1) / 2) -- (the peaks: the odd halves, the last one also when the LFO stops in it)
    local function val(i) return i % 2 == 0 and a or peak((i + 1) / 2, np) end
    for i = 0, nh - 1 do add(q0 + i * half, val(i), s) end
    local from, to = val(nh - 1), val(nh)
    local f = Util.clamp((q1 - (q0 + (nh - 1) * half)) / half, 0, 1)
    local v = from
    if shape == 1 then v = from + (to - from) * f
    elseif shape == 0 then v = from + (to - from) * (1 - math.cos(math.pi * f)) / 2 end
    add(q1, v, 0)
  else -- a saw: a ramp each cycle, then a jump back
    local eps = math.min(1 / 64, cyc / 8)
    local nc = 0
    while q0 + nc * cyc < q1 - 1e-6 do nc = nc + 1 end
    for c = 1, nc do
      local qs = q0 + (c - 1) * cyc
      local top = peak(c, nc)
      add(qs, a, 1)
      local qe = qs + cyc
      if qe < q1 - 1e-6 then add(qe - eps, top, 0)
      else add(q1, a + (top - a) * Util.clamp((q1 - qs) / (cyc - eps), 0, 1), 0) end
    end
  end
  if fin and pts[#pts].v ~= fin then -- the end value: the wave stops just before t1, then a jump to fin
    local q = q1 - math.min(1 / 64, cyc / 8)
    if q > r.TimeMap2_timeToQN(R.proj, pts[#pts - 1].t) + 1e-6 then pts[#pts].t = r.TimeMap2_QNToTime(R.proj, q)
    else pts[#pts] = nil end
    add(q1, fin, 0)
  end
  return pts, t1
end

-- Groups of values (Lanes): an LFO, a swell or a ramp, found by its pattern (as a Scene test: nothing is saved).
-- list: the values of 1 control in time order. Returns { { i0, i1, kind ("lfo", "swell", "ramp"), shape (an LFO:
-- 0-4, as LFO_SHAPE_NAMES), a, b, c (CC values: an LFO's 2 values, a swell's start, top and end, a ramp's start and
-- end), cyc (an LFO: 1 cycle in quarter notes) } }. A group ends on a value without a slope (or the last value).
function Midi.find_groups(list)
  local out, qs, n = {}, {}, #list
  for i, e in ipairs(list) do qs[i] = r.TimeMap2_timeToQN(R.proj, e.t) end
  local TOL, EPS = 0.01, 1 / 16 -- (quarter notes: equal distances; the jump of a saw or of an End value)
  local i = 1
  while i <= n do
    local g, j
    local e1, e2 = list[i], list[i + 1]
    -- an LFO (Sine, Triangle, Square): 2 values in turn, at equal distances, the same slope
    local s = e1.shape
    if i + 2 <= n and (s == 0 or s == 1 or s == 2) and e1.v ~= e2.v and qs[i + 1] - qs[i] > TOL then
      local h = qs[i + 1] - qs[i]
      local step, split -- (the peaks: the same, or growing / shrinking by the same step)
      j = i + 1
      while j < n and list[j].shape == s and math.abs(qs[j + 1] - qs[j] - h) < TOL do
        local nv = list[j + 1].v
        if (j + 1 - i) % 2 == 0 then
          if nv ~= e1.v then break end
        else
          local d2 = nv - list[j - 1].v
          if nv == e1.v or (step and math.abs(d2 - step) > 1) then split = true; break end
          step = step or d2
        end
        j = j + 1
      end
      -- (the peaks change their steps: another LFO starts at value j, right after this one)
      if split and j - 1 >= i + 2 then j = j - 1
      elseif j >= i + 2 then
        if j < n and list[j].shape == s and (qs[j + 1] - qs[j] < h - TOL -- (it stops inside a half; a Square: or holds)
          or (s == 0 and list[j + 1].v == list[j].v and qs[j + 1] - qs[j] < h + TOL)) then j = j + 1 end
        if j < n and list[j].shape == 0 and qs[j + 1] - qs[j] <= EPS then j = j + 1 end -- (the End value)
      end
      if j >= i + 2 then
        g = { kind = "lfo", shape = (s == 2 and 0) or (s == 1 and 1) or 2, a = e1.v, b = e2.v, cyc = 2 * h, step = step }
      end
    end
    -- a saw: a straight slope from a to b, a jump back to a just before the next cycle
    if not g and i + 2 <= n and s == 1 and e2.shape == 0 and e1.v ~= e2.v and list[i + 2].v == e1.v
      and qs[i + 2] - qs[i + 1] <= EPS then
      local c = qs[i + 2] - qs[i]
      local step, split
      j = i + 2
      while j + 2 <= n and list[j].shape == 1 and list[j + 1].shape == 0 and list[j + 1].v ~= e1.v
        and list[j + 2].v == e1.v and math.abs(qs[j + 2] - qs[j] - c) < TOL and qs[j + 2] - qs[j + 1] <= EPS do
        local d2 = list[j + 1].v - list[j - 1].v
        if step and math.abs(d2 - step) > 1 then split = true; break end
        step = step or d2
        j = j + 2
      end
      if split or (j < n and list[j].shape == 1 and list[j + 1].shape == 0 and j + 2 <= n and list[j + 2].v == e1.v
        and math.abs(list[j + 1].v - list[j - 1].v - (step or 0)) > 1 and math.abs(qs[j + 2] - qs[j] - c) < TOL) then
        j = j - 1 -- (another saw starts at value j, right after this one)
      else
        if j < n and list[j].shape == 1 and list[j + 1].v ~= e1.v and qs[j + 1] - qs[j] < c + TOL then j = j + 1 end -- (the last ramp)
        if j < n and list[j].shape == 0 and qs[j + 1] - qs[j] <= EPS then j = j + 1 end -- (the End value)
      end
      g = { kind = "lfo", shape = e1.v < e2.v and 3 or 4, a = e1.v, b = e2.v, cyc = c, step = step }
    end
    -- a swell: up, a hold (or none), back
    if not g and i + 2 <= n and s ~= 0 and e2.v ~= e1.v then
      local k2 = i + 1
      if e2.shape == 0 and i + 3 <= n and list[i + 2].v == e2.v and list[i + 2].shape ~= 0 then k2 = i + 2 end
      local back = list[k2 + 1]
      local up = e2.v - e1.v
      if list[k2].shape ~= 0 and back and (k2 + 1 == n or back.shape == 0)
        and ((up > 0 and back.v <= e2.v) or (up < 0 and back.v >= e2.v)) then
        g, j = { kind = "swell", a = e1.v, b = e2.v, c = back.v }, k2 + 1
      end
    end
    -- a ramp: a slope to a value without a slope
    if not g and i < n and s ~= 0 and (i + 1 == n or e2.shape == 0) then
      g, j = { kind = "ramp", a = e1.v, b = e2.v }, i + 1
    end
    if g and g.kind == "lfo" and g.step and g.step ~= 0 then -- growing / shrinking peaks: the largest one in the name
      for m = i + 1, j do
        local v = list[m].v
        if v ~= g.a and math.abs(v - g.a) > math.abs(g.b - g.a) then g.b = v end
      end
      g.grow = ((g.step > 0) == (g.b > g.a)) and 1 or 2
    end
    if g then
      g.i0, g.i1 = i, j
      out[#out + 1] = g
      i = j + 1
    else i = i + 1 end
  end
  return out
end
-- A length from t0 to t1 in words: "2 bars", "3 beats" (quarter notes), else "1.50 beats".
function Midi.len_text(t0, t1)
  local num, den = r.TimeMap_GetTimeSigAtTime(R.proj, t0)
  local dq = r.TimeMap2_timeToQN(R.proj, t1) - r.TimeMap2_timeToQN(R.proj, t0)
  local nb = dq / (num * 4 / den)
  local b = math.floor(nb + 0.5)
  if b >= 1 and math.abs(nb - b) < 0.01 then return b .. (b == 1 and " bar" or " bars") end
  local nq = math.floor(dq + 0.5)
  if nq >= 1 and math.abs(dq - nq) < 0.01 then return nq .. (nq == 1 and " beat" or " beats") end
  return string.format("%.2f beats", dq)
end
-- The name of a group in the units of knob k: "LFO Sine 1/4 note, 20% - 100%, 2 bars" (cached in the group).
function Midi.group_label(g, k, list)
  if g.lab and g.lk == k and g.lmin == k.min and g.lmax == k.max and g.lunit == k.unit then return g.lab end
  local function f(v) return Knob.fmt(k, Knob.from_cc(k, v)) end
  local t0 = list[g.i0].t
  local len = Midi.len_text(t0, list[g.i1].t)
  local lab
  if g.kind == "lfo" then
    local rate
    for i = 1, #LFO_RATES do if math.abs(Midi.lfo_cycle(t0, i) - g.cyc) < 0.02 then rate = LFO_RATES[i][3]; break end end
    g.lab2 = (rate or "") .. (rate and ", " or "") .. f(g.a) .. " - " .. f(g.b) .. ", " .. len
      .. ((g.grow == 1 and ", peaks grow") or (g.grow == 2 and ", peaks shrink") or "") -- (after the icon)
    lab = "LFO " .. LFO_SHAPE_NAMES[g.shape + 1] .. " " .. g.lab2
  elseif g.kind == "swell" then lab = "Swell " .. f(g.a) .. " - " .. f(g.b) .. " - " .. f(g.c) .. ", " .. len
  else lab = "Ramp " .. f(g.a) .. " - " .. f(g.b) .. ", " .. len end
  g.lab, g.lk, g.lmin, g.lmax, g.lunit = lab, k, k.min, k.max, k.unit
  return lab
end
-- A copy of the values i0-i1 of a list: { label, len (quarter notes), pts = { { dq, v, shape, tension } } }.
function Midi.group_clip(list, i0, i1, label)
  local q0 = r.TimeMap2_timeToQN(R.proj, list[i0].t)
  local pts = {}
  for i = i0, i1 do
    local e = list[i]
    pts[#pts + 1] = { dq = r.TimeMap2_timeToQN(R.proj, e.t) - q0, v = e.v, shape = e.shape, tension = e.tension }
  end
  return { label = label, len = pts[#pts].dq, pts = pts }
end
-- The points of a copy from time t (in quarter notes: it follows the tempo), for Midi.add_ramp.
function Midi.clip_points(clip, t)
  local q0 = r.TimeMap2_timeToQN(R.proj, t)
  local pts = {}
  for i, p in ipairs(clip.pts) do
    pts[i] = { t = r.TimeMap2_QNToTime(R.proj, q0 + p.dq), v = p.v, shape = p.shape, tension = p.tension }
  end
  return pts
end
-- Moves the values i0-i1 of a list so the first is at time t, in 1 undo step (the values at the new place are
-- replaced). Removes them when t is nil.
function Midi.move_values(d, cc, list, i0, i1, t, name)
  local pts = t and Midi.clip_points(Midi.group_clip(list, i0, i1, ""), t)
  r.Undo_BeginBlock()
  for i = i0, i1 do Midi.delete_cc(d, cc, list[i]) end
  R.pcs = {}
  if pts then
    for _, e in ipairs(Midi.ccs(d, cc)) do
      if e.t >= pts[1].t - 0.0005 and e.t <= pts[#pts].t + 0.0005 then Midi.delete_cc(d, cc, e) end
    end
    R.pcs = {}
    for i, p in ipairs(pts) do Midi.write_cc(d, cc, p.t, p.v, i < #pts and p.shape or 0, i < #pts and p.tension or 0) end
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: " .. (name or "move values"), -1)
end

-- The value of a knob at time t: the last value at or before t (on a slope: the value on the way to the next
-- value, straight between them), and that value event. nil when no value comes before t.
function Midi.cc_at(d, cc, t)
  local list = Midi.ccs(d, cc)
  local prev, nxt
  for i, e in ipairs(list) do
    if e.t <= t + 0.0005 then prev, nxt = e, list[i + 1] else break end
  end
  if not prev then return nil end
  if prev.shape ~= 0 and nxt and nxt.t > prev.t then
    local f = Util.clamp((t - prev.t) / (nxt.t - prev.t), 0, 1)
    return Util.clamp(math.floor(prev.v + (nxt.v - prev.v) * f + 0.5), 0, 127), prev
  end
  return prev.v, prev
end

-- The state of a device at time t: its preset, its scene and the value of each control (Send state now).
function Midi.state_at(d, t)
  local st = {}
  local rg = Midi.song_at(t)
  st.pc = rg and Midi.preset_at(d, rg, t) or Midi.active_at(d, t + 0.0002)
  for _, s in ipairs(Midi.scenes(d)) do if s.t <= t + CFG.EDGE then st.scene = s.v else break end end
  if rg then -- (before the start scene, at the song start: the song's own start scene)
    local ss = Midi.start_scene(d, rg)
    if ss and t < ss.t then st.scene = ss.v end
  end
  st.ccs = {}
  for _, k in ipairs(Knob.levels(d)) do
    local v = Midi.cc_at(d, k.cc, t)
    if v then st.ccs[#st.ccs + 1] = { cc = k.cc, v = v } end
  end
  return st
end

-- Sends the state of a device at time t to the unit: the preset now, the scene and the control values
-- CFG.START_AFTER_PC later (the unit first loads the preset). from (optional): a time whose state the unit has:
-- only what differs from the state there is sent, and the same preset is not loaded again (a reload is a gap in the
-- sound); with the same preset, the changes go at once. Returns false when the output is not available.
function Midi.send_state(d, t, from)
  if not Dev.port_index(d.port) then return false end
  local st, send_pc, scene, ccs = Midi.state_changes(d, t, from)
  if send_pc then Midi.send_now(d, st.pc.folder, st.pc.index) end
  if not scene and #ccs == 0 then return true end
  R.send_q = R.send_q or {}
  R.send_q[#R.send_q + 1] = { at = Util.now() + (send_pc and CFG.START_AFTER_PC or 0), fn = function()
    if scene then Midi.send_scene(d, scene) end
    for _, c in ipairs(ccs) do Midi.send_cc(d, c.cc, c.v) end
  end }
  return true
end
-- What Midi.send_state sends: the state at t, whether the preset goes, the scene (or nil) and the control values.
function Midi.state_changes(d, t, from)
  local st = Midi.state_at(d, t)
  local old = from and Midi.state_at(d, from)
  local same_pc = old and ((st.pc == nil and old.pc == nil)
    or (st.pc and old.pc and st.pc.folder == old.pc.folder and st.pc.index == old.pc.index))
  local send_pc = st.pc ~= nil and not same_pc
  -- (a new preset: the unit loads its own scene and values, so all of them go again)
  local scene = st.scene
  if scene and old and not send_pc and old.scene == scene then scene = nil end
  local ccs = st.ccs
  if old and not send_pc then
    local was = {}
    for _, c in ipairs(old.ccs) do was[c.cc] = c.v end
    ccs = {}
    for _, c in ipairs(st.ccs) do if was[c.cc] ~= c.v then ccs[#ccs + 1] = c end end
  end
  return st, send_pc, scene, ccs
end
-- Every frame: the messages that wait for their time (R.send_q).
function Midi.run_send_q()
  local q = R.send_q
  if not q or #q == 0 then return end
  local now = Util.now()
  for i = #q, 1, -1 do
    if now >= q[i].at then local job = table.remove(q, i); job.fn() end
  end
end

-- ---------------------------------------------------------------------------------------------------------
-- Export (Songs > Tools > Export MIDI...): the MIDI of a device as a standard MIDI file (type 0, 960 ticks per quarter
-- note, with the tempo map): 1 file for the whole show, or 1 file per song (each from 0:00, with the song's preset and
-- start scene at its start). A slope between 2 values (a ramp) is written as steps (a MIDI file has no slopes).

-- The value of a slope (REAPER's CC shapes) at f (0-1): 1 straight, 2 slow start and end, 3 fast start, 4 fast end,
-- 5 curve (tension -1 .. 1: below 0 it starts fast).
function Midi.shape_val(shape, tension, f)
  if shape == 2 then return 0.5 - 0.5 * math.cos(math.pi * f) end
  if shape == 3 then return 1 - (1 - f) ^ 2 end
  if shape == 4 then return f ^ 2 end
  if shape == 5 then return f ^ (2 ^ ((tension or 0) * 2)) end
  return f
end
-- The events of a device that REAPER plays from time t0 to t1: { t, cm, ch, m2, m3, n } in time order (n: the order
-- of events at the same time); ramps as steps of a 1/32 note.
function Midi.export_events(d, t0, t1)
  local out = {}
  local function add(e) e.n = #out; out[#out + 1] = e end
  for _, take in ipairs(Midi.takes(d)) do
    local p0, p1 = Midi.play_range(take)
    if p0 then
      local evs = {}
      local _, _, ncc = r.MIDI_CountEvts(take)
      for i = 0, ncc - 1 do
        local _, _, muted, ppq, cm, ch, m2, m3 = r.MIDI_GetCC(take, i)
        if not muted and Midi.is_mine(d, ch) and ppq >= p0 and ppq < p1 then
          local _, shape, ten = r.MIDI_GetCCShape(take, i)
          evs[#evs + 1] = { t = r.MIDI_GetProjTimeFromPPQPos(take, ppq), cm = cm, ch = ch, m2 = m2, m3 = m3,
            shape = shape or 0, ten = ten or 0 }
        end
      end
      local nexts = {}
      for i = #evs, 1, -1 do
        local e = evs[i]
        if e.cm == 0xB0 then local key = e.ch * 128 + e.m2; e.nxt = nexts[key]; nexts[key] = e end
      end
      for _, e in ipairs(evs) do
        if e.t >= t0 - CFG.EDGE and e.t < t1 then add({ t = e.t, cm = e.cm, ch = e.ch, m2 = e.m2, m3 = e.m3 }) end
        if e.cm == 0xB0 and e.shape ~= 0 and e.nxt and e.nxt.m3 ~= e.m3 then
          local q0, q1 = r.TimeMap2_timeToQN(R.proj, e.t), r.TimeMap2_timeToQN(R.proj, e.nxt.t)
          local last, q = e.m3, q0 + 0.125
          while q < q1 - 0.000001 do
            local v = math.floor(e.m3 + (e.nxt.m3 - e.m3) * Midi.shape_val(e.shape, e.ten, (q - q0) / (q1 - q0)) + 0.5)
            if v ~= last then
              local tq = r.TimeMap2_QNToTime(R.proj, q)
              if tq >= t0 and tq < t1 then add({ t = tq, cm = 0xB0, ch = e.ch, m2 = e.m2, m3 = Util.clamp(v, 0, 127) }) end
              last = v
            end
            q = q + 0.125
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) if math.abs(a.t - b.t) > 0.0000001 then return a.t < b.t end return a.n < b.n end)
  return out
end
-- A song's file: its events (without the next song's preset change near its end), and at its start the song's
-- preset (when its own change comes before the start) and start scene (when it is not in the song).
function Midi.song_file_events(d, rg)
  local evs = {}
  local function is_pc(e) return e.cm == 0xC0 or (e.cm == 0xB0 and (e.m2 == 0 or e.m2 == 32)) end
  for _, e in ipairs(Midi.export_events(d, rg.start, rg.stop - CFG.EDGE)) do
    if not (is_pc(e) and Midi.next_song_at(e.t, rg)) then evs[#evs + 1] = e end
  end
  local head = {}
  local ch = Midi.chan(d)
  local own = Midi.song_change(d, rg)
  local pc = Midi.preset_at(d, rg, rg.start)
  local after = 0
  if pc and not (own and own.t >= rg.start - CFG.EDGE) then
    if MODELS[d.model].msb then head[#head + 1] = { t = rg.start, cm = 0xB0, ch = ch, m2 = 0, m3 = pc.index // 128 } end
    head[#head + 1] = { t = rg.start, cm = 0xB0, ch = ch, m2 = 32, m3 = pc.folder }
    head[#head + 1] = { t = rg.start, cm = 0xC0, ch = ch, m2 = pc.index % 128, m3 = 0 }
    after = CFG.START_AFTER_PC -- (the unit first loads the preset)
  end
  local ss = Midi.start_scene(d, rg)
  if not (ss and ss.t >= rg.start - CFG.EDGE) then
    local st = Midi.state_at(d, rg.start)
    if st.scene then head[#head + 1] = { t = rg.start + after, cm = 0xB0, ch = ch, m2 = Midi.scc(d), m3 = st.scene } end
  end
  for i, e in ipairs(head) do e.n = -100 + i end
  for _, e in ipairs(evs) do head[#head + 1] = e end
  table.sort(head, function(a, b) if math.abs(a.t - b.t) > 0.0000001 then return a.t < b.t end return a.n < b.n end)
  return head
end
-- Writes a MIDI file: events and the tempo map from time t0 (0:00 of the file) to t1. Returns true, or false and why.
function Midi.write_smf(path, name, evs, t0, t1)
  local q0 = r.TimeMap2_timeToQN(R.proj, t0)
  local function tick(tt) return math.max(0, math.floor((r.TimeMap2_timeToQN(R.proj, tt) - q0) * 960 + 0.5)) end
  local list = {}
  local function put(tk, n, bytes) list[#list + 1] = { tk = tk, n = n, b = bytes } end
  name = (name or ""):sub(1, 120) -- (a MIDI text event of up to 127 bytes)
  put(0, -3, "\xFF\x03" .. string.char(#name) .. name)
  local function tempo(tk, tt, n)
    local num, den, bpm = r.TimeMap_GetTimeSigAtTime(R.proj, tt)
    local us = math.floor(60000000 / bpm + 0.5)
    put(tk, n, "\xFF\x51\x03" .. string.char((us >> 16) & 255, (us >> 8) & 255, us & 255))
    local dd, l2 = den, 0
    while dd > 1 do dd = dd // 2; l2 = l2 + 1 end
    put(tk, n + 1, "\xFF\x58\x04" .. string.char(num, l2, 24, 8))
  end
  tempo(0, t0, -2)
  for i = 0, r.CountTempoTimeSigMarkers(R.proj) - 1 do
    local _, tp = r.GetTempoTimeSigMarker(R.proj, i)
    if tp > t0 + 0.0001 and tp < t1 then tempo(tick(tp), tp + 0.000001, -2) end
  end
  for i, e in ipairs(evs) do
    local st = string.char((e.cm & 0xF0) | (e.ch & 0x0F))
    put(tick(e.t), i, (e.cm == 0xC0 or e.cm == 0xD0) and (st .. string.char(e.m2)) or (st .. string.char(e.m2, e.m3)))
  end
  table.sort(list, function(a, b) if a.tk ~= b.tk then return a.tk < b.tk end return a.n < b.n end)
  local function vlq(n)
    local s = string.char(n & 0x7F)
    n = n >> 7
    while n > 0 do s = string.char((n & 0x7F) | 0x80) .. s; n = n >> 7 end
    return s
  end
  local parts, last = {}, 0
  for _, x in ipairs(list) do parts[#parts + 1] = vlq(x.tk - last) .. x.b; last = x.tk end
  parts[#parts + 1] = vlq(math.max(0, tick(t1) - last)) .. "\xFF\x2F\x00"
  local data = table.concat(parts)
  local f, err = io.open(path, "wb")
  if not f then return false, tostring(err) end
  f:write(string.pack(">c4I4I2I2I2", "MThd", 6, 0, 1, 960), string.pack(">c4I4", "MTrk", #data), data)
  f:close()
  return true
end
-- The default export folder: "MIDI Pilot export" next to the project file (nil when the project is not saved yet).
function Midi.default_export_dir()
  local _, fn = r.EnumProjects(-1)
  if not fn or fn == "" then return nil end
  return (fn:match("^(.*)[/\\]") or ".") .. "/MIDI Pilot export"
end
-- The export folder: the one chosen for this project (saved in it), else the default.
function Midi.export_dir()
  if P.export_dir and P.export_dir ~= "" then return P.export_dir end
  return Midi.default_export_dir()
end
-- Sets the export folder of the project ("" or the default folder: the default).
function Midi.set_export_dir(path)
  path = (path or ""):match("^%s*(.-)%s*$"):gsub("[/\\]+$", "")
  if path == Midi.default_export_dir() then path = "" end
  if path ~= P.export_dir then P.export_dir = path; Util.mark_pdirty() end
end
-- A folder picker: the js_ReaScriptAPI extension's, else on Windows the Windows folder window (REAPER waits until
-- it closes). Returns the folder, or nil.
function Midi.browse_folder(start)
  if r.JS_Dialog_BrowseForFolder then
    local rv, folder = r.JS_Dialog_BrowseForFolder("Export folder", start or "")
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
local function safe_name(s) return ((s or ""):gsub('[\\/:%*%?"<>|]', "_"):match("^%s*(.-)%s*$")) end
-- Exports a device: per_song false: 1 file for the whole show; true: 1 file per song. Returns the number of files and
-- the folder, or nil and why.
function Midi.export(d, per_song)
  local dir = Midi.export_dir()
  if not dir then return nil, "Save the project first, or choose a folder." end
  r.RecursiveCreateDirectory(dir, 0)
  if not per_song then
    local t1 = math.max(r.GetProjectLength(R.proj), Dev.item_end())
    local pname = safe_name((select(2, r.EnumProjects(-1)) or ""):match("([^/\\]+)%.[^%.]*$") or "Project")
    local ok, err = Midi.write_smf(dir .. "/" .. pname .. " - " .. safe_name(d.name) .. ".mid", d.name,
      Midi.export_events(d, 0, t1), 0, t1)
    if not ok then return nil, err end
    return 1, dir
  end
  local sub = dir .. "/" .. safe_name(d.name)
  r.RecursiveCreateDirectory(sub, 0)
  local n = 0
  for i, rg in ipairs(R.regions) do
    local fname = string.format("%s/%02d %s.mid", sub, i, safe_name(rg.name ~= "" and rg.name or "Song"))
    local ok, err = Midi.write_smf(fname, rg.name, Midi.song_file_events(d, rg), rg.start, rg.stop)
    if not ok then return nil, err end
    n = n + 1
  end
  return n, sub
end

-- Removes 1 CC event of a knob.
function Midi.delete_cc(d, cc, e)
  if not r.ValidatePtr2(R.proj, e.take, "MediaItem_Take*") then return end
  local _, _, ncc = r.MIDI_CountEvts(e.take)
  for i = ncc - 1, 0, -1 do
    local _, _, _, ppq, cm, chn, m2 = r.MIDI_GetCC(e.take, i)
    if math.abs(ppq - e.ppq) < 0.5 and cm == 0xB0 and m2 == cc and Midi.is_mine(d, chn) then r.MIDI_DeleteCC(e.take, i) end
  end
end
-- Writes a CC value of a knob at time t (a value at the same time is replaced), in 1 undo step (old: the event
-- that it replaces, for a change of a value or time: its slope stays).
function Midi.set_cc(d, cc, t, val, old)
  r.Undo_BeginBlock()
  local shape, tension = old and old.shape or 0, old and old.tension or 0
  if old then Midi.delete_cc(d, cc, old) end
  for _, e in ipairs(Midi.ccs(d, cc)) do
    if math.abs(e.t - t) < 0.001 and e ~= old then Midi.delete_cc(d, cc, e) end
  end
  R.pcs = {}
  Midi.write_cc(d, cc, t, val, shape, tension)
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: knob value", -1)
end
-- Writes 1 CC value at time t with its slope (no undo step).
function Midi.write_cc(d, cc, t, val, shape, tension)
  local take = Midi.take_at(d, t)
  if not take then return end
  local ppq = math.floor(r.MIDI_GetPPQPosFromProjTime(take, t) + 0.5)
  r.MIDI_InsertCC(take, false, false, ppq, 0xB0, Midi.chan(d), cc, Util.clamp(val, 0, 127))
  if (shape or 0) ~= 0 then
    local _, _, ncc = r.MIDI_CountEvts(take)
    for i = 0, ncc - 1 do
      local _, _, _, p2, cm, chn, m2 = r.MIDI_GetCC(take, i)
      if math.abs(p2 - ppq) < 0.5 and cm == 0xB0 and m2 == cc and Midi.is_mine(d, chn) then
        r.MIDI_SetCCShape(take, i, shape, tension or 0, true)
      end
    end
  end
  r.MIDI_Sort(take)
  R.pcs = {}
end
-- Sets the slope from a value to the next one: shape 0-5 (CC_SHAPE_ITEMS), tension -1 .. 1 (Curve only); 1 undo step.
function Midi.set_shape(d, cc, e, shape, tension)
  if not r.ValidatePtr2(R.proj, e.take, "MediaItem_Take*") then return end
  r.Undo_BeginBlock()
  local _, _, ncc = r.MIDI_CountEvts(e.take)
  for i = 0, ncc - 1 do
    local _, _, _, ppq, cm, chn, m2 = r.MIDI_GetCC(e.take, i)
    if math.abs(ppq - e.ppq) < 0.5 and cm == 0xB0 and m2 == cc and Midi.is_mine(d, chn) then
      r.MIDI_SetCCShape(e.take, i, shape, tension or 0, true)
    end
  end
  r.MIDI_Sort(e.take)
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: slope of a knob value", -1)
end
-- Tap tempo: 4 taps on the next 4 beats from time t (the unit takes the project's tempo), 1 undo step.
function Midi.add_taps(d, cc, t)
  r.Undo_BeginBlock()
  local q = r.TimeMap2_timeToQN(R.proj, t)
  for i = 0, 3 do Midi.write_cc(d, cc, r.TimeMap2_QNToTime(R.proj, q + i), 127, 0, 0) end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: 4 taps", -1)
end
function Midi.remove_cc(d, cc, e)
  r.Undo_BeginBlock()
  Midi.delete_cc(d, cc, e); R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: remove a knob value", -1)
end
-- Sends a CC value to the unit now.
function Midi.send_cc(d, cc, val)
  local pi = Dev.port_index(d.port)
  if not pi then return false end
  r.StuffMIDIMessage(16 + pi, 0xB0 + Midi.chan(d), cc, val)
  return true
end
-- The song (region) at a time, or nil.
function Midi.song_at(t)
  -- (a time up to CFG.EDGE before a song start is that song: a scene there is rounded to a MIDI tick)
  for _, rg in ipairs(R.regions) do if t >= rg.start - CFG.EDGE and t < rg.stop - CFG.EDGE then return rg end end
  for _, rg in ipairs(R.regions) do if t >= rg.start and t < rg.stop then return rg end end
  return nil
end

-- The device's MIDI is on channel `from` (0-15): is there any (CC, Program Change)?
function Midi.has_channel(d, from)
  for _, take in ipairs(Midi.takes(d)) do
    local _, _, ncc = r.MIDI_CountEvts(take)
    for i = 0, ncc - 1 do
      local _, _, _, _, cm, ch = r.MIDI_GetCC(take, i)
      if ch == from and (cm == 0xB0 or cm == 0xC0) then return true end
    end
  end
  return false
end
-- Moves the device's CC and Program Change events from channel `from` to channel `to` (0-15), in 1 undo step.
function Midi.move_channel(d, from, to)
  local n = 0
  r.Undo_BeginBlock()
  for _, take in ipairs(Midi.takes(d)) do
    local _, _, ncc = r.MIDI_CountEvts(take)
    for i = 0, ncc - 1 do
      local _, _, _, _, cm, ch = r.MIDI_GetCC(take, i)
      if ch == from and (cm == 0xB0 or cm == 0xC0) then r.MIDI_SetCC(take, i, nil, nil, nil, nil, to, nil, nil, true); n = n + 1 end
    end
    r.MIDI_Sort(take)
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: move the MIDI of " .. d.name .. " to another channel", -1)
  return n
end

-- Sends a scene to the unit now.
function Midi.send_scene(d, v)
  local pi = Dev.port_index(d.port)
  if not pi then return false end
  r.StuffMIDIMessage(16 + pi, 0xB0 + Midi.chan(d), Midi.scc(d), v)
  return true
end

-- Sends a preset to the unit now (its MIDI output). Returns false when the output is not available.
function Midi.send_now(d, folder, index)
  local pi = Dev.port_index(d.port)
  if not pi then return false end
  local ch = Midi.chan(d)
  if MODELS[d.model].msb then r.StuffMIDIMessage(16 + pi, 0xB0 + ch, 0, index // 128) end
  r.StuffMIDIMessage(16 + pi, 0xB0 + ch, 32, folder)
  r.StuffMIDIMessage(16 + pi, 0xC0 + ch, index % 128, 0)
  return true
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
if test then -- tests/midipilot.lua: hand it the modules and do not start the UI
  test.CFG, test.S, test.R, test.Util, test.Project, test.Dev, test.MODELS = CFG, S, R, Util, Project, Dev, MODELS
  test.Preset, test.Midi, test.Knob = Preset, Midi, Knob
  test.get_P = function() return P end
  test.set_P = function(p) P = p end
  return
end

local ctx = ImGui.CreateContext(CFG.TITLE)
local font = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE)
local bold = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE, ImGui.FontFlags_Bold())
local head_font = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE_BOLD, ImGui.FontFlags_Bold())
ImGui.Attach(ctx, font); ImGui.Attach(ctx, bold); ImGui.Attach(ctx, head_font)

local TAB_NAMES = { "Songs", "Lanes", "Presets" } -- then Settings (gear) and Help ("?")
local TAB_SETTINGS, TAB_HELP = 4, 5
local CHAN_ITEMS = "All channels\0" -- the channel dropdown (built once)
for c = 1, 16 do CHAN_ITEMS = CHAN_ITEMS .. c .. "\0" end
local TRACK_MODE_ITEMS = "One track for each device\0One shared track\0"
local PC_WHEN_ITEMS = "Before the song start\0Exactly at the song start\0After the song start\0"
local PC_UNIT_ITEMS = "Milliseconds\0Note value (snaps to the beat)\0"
local PC_NOTE_ITEMS = ""
for _, n in ipairs(PC_NOTES) do PC_NOTE_ITEMS = PC_NOTE_ITEMS .. n[2] .. "\0" end

-- The Help: an introduction, then topics (one open at a time, as in Chart Cue). In a topic text: "# " starts a bold
-- sub-heading, "- " a bullet, "1. " a numbered step; an empty line is a gap.
local HELP_INTRO = "MIDI Pilot helps you prepare the MIDI for your amp modeler (Neural DSP Quad Cortex or Quad Cortex mini, "
  .. "Line 6 Helix, HX Stomp, HX Stomp XL or HX Effects) in REAPER: Preset changes, Scene changes and pedal moves for "
  .. "each song. It writes normal MIDI on the device's track. REAPER plays it; MIDI Pilot does not need to be open."
local HELP_TOPICS = {
  { title = "Getting started", text = [[
1. Connect the unit by USB (or through a MIDI interface).
2. Settings (the gear) > Add device. Choose your unit under "Connected", or choose a model and then its MIDI output. MIDI Pilot also adds a track for the device.
3. Make 1 region for each song (Insert > Region from time selection). MIDI Pilot calls each region a song.
4. Songs tab: choose the Preset of each song, then add the Scene changes.
5. Songs > Set up songs: each song gets a Preset change and a first Scene, so playback can start at any song.

# Good to know
- Every change is 1 undo step: Ctrl+Z takes it back.
- The Getting started list at the top of the Songs tab ticks these steps. Skip a step that you do not need; its X hides the list (Settings > General > Show Getting started brings it back).
- REAPER's Snap on (the N key): every add at the edit cursor (values, ramps, LFOs, a paste, Scenes, Preset changes) goes to the nearest grid line.
- The toolbar above the tabs: the device, the previous / next song, the song, Preset and Scene at the edit cursor, then Snap, Send state, Set up songs, Scene timelines and Export MIDI. Right-click an item to hide it, or the toolbar to hide all of it (Settings > Appearance > Toolbar shows it again).
- Tabs that you do not use: right-click a tab > Hide this tab, or Settings > Appearance > Tabs. Settings and Help always show.
- Hold the mouse on a control to see what it does.]] },
  { title = "Songs and Presets", text = [[
Each song row has a Preset dropdown. It writes a Preset change near the song start (the time is set in Settings > Editing > Preset settings > First Preset).

- A grey Preset: the song has no Preset change of its own, so the Preset of the song before keeps playing.
- "Choose by number...": choose a Preset that has no name yet.
- The triangle sends the Preset to the unit now, so you can hear it.
- The red X removes the song's Preset change.

# The buttons above the songs
- Set up songs: each song that has no Preset change gets one (the Preset that already plays there), and each song that has no first Scene gets one. Then playback can start at any song.
- Tools > Show overview: all songs in 1 table, with their Preset, their Scenes in order and their Lanes values.
- Tools > Presets from regions: a song gets the Preset whose number is in its name ("Song One [3B]") or whose name it has (Presets tab).
- Tools > Presets from markers: a marker named "P 3B" or "P <Preset name>" gets a Preset change at its place.
- Tools > Markers from Scenes: adds a project marker with the Scene name at each Scene change.
- 1 Preset for several songs: Ctrl+click the song names (Shift+click: a range), then choose the Preset in 1 of them.
- Tools > Scenes from markers: a marker with the name of a Scene gets that Scene change.
- Tools > Merge repeated Scenes: removes a Scene change that selects the Scene that already plays (not a first Scene, not a Scene test or its end).
- Tools > Export MIDI: saves the device's MIDI as a standard MIDI file, 1 file for the whole show or 1 file per song. A gradual tempo change (a tempo ramp) is saved as a sudden change, so events inside a ramp can move a little.
- Clear: removes all Scene changes or all Preset changes of the device (asks first).]] },
  { title = "Scenes", text = [[
The coloured timeline under a song shows its Scenes from start to end. Each block is 1 Scene, with the name it has in the Preset that plays there.
- Click a block: the edit cursor goes there.
- Double-click a block: REAPER's MIDI editor opens at that place.
- Right-click a block: change or remove that Scene change.

# The Scene list
Click the arrow next to the song number to open the list of its Scene changes.
- Position and Time: type a new value to move the Scene change.
- The 2 triangles (Nudge): move it a little earlier or later.
- The first row is the song's first Scene. It always stays at the song start.
- The row at the edit cursor has a blue bar.

# The last row of the list
- Song (the 2 triangles): move all Scene changes and pedal values of the song a little earlier or later.
- Add Scene at edit cursor: add a Scene change exactly at REAPER's edit cursor. Faster: the keys 1-8 (Settings > Editing > Scene settings). This list also has "Scene test" and "Preset change...".
- Preset change...: add a second Preset inside the song. It gets its own row and a white line on the timeline.
- Clear Scenes: remove all Scene changes of this song.

# Good to know
- Name your Scenes and choose their colours in the Presets tab (the Scenes icon of a Preset).
- The block that plays now is in full colour.
- Settings > Appearance > Scene timelines: turn the timelines off for a shorter song list.]] },
  { title = "Scene test", text = [[
"Scene test" (in the Add Scene list) plays every Scene of the unit, 1 after the other and back to the first, 2 beats each, from the edit cursor. Use it to listen to all the Scenes of a Preset.

- It shows as 1 block and 1 row. Type a new position to move it; its red X removes it.
- At its end, the Scene from before the test comes back (a normal Scene change: change or remove it as any other).
- The status bar reminds you of a Scene test that is still in a song. "Ignore" stops the reminder for that song.]] },
  { title = "Lanes: pedals and other controls", text = [[
Lanes writes pedal moves and other control changes in the song at the edit cursor (or in all songs).

# Quad Cortex
- Expression 1 and 2 are the unit's 2 pedals. A value is the pedal position: 0% (heel) to 100% (toe).
- What a pedal moves is different in each Preset. In the Presets tab, the pedal icon of a Preset lists the parameters and their range, as on the unit (for example Hi Pass 0-55%). A value row then shows the result, for example "-> Hi Pass 22%".
- The Control list also has the unit's other MIDI functions: the footswitches, Tap tempo, Tuner, Gig View and Mode.

# Line 6
- Add a control for each CC that you assigned on the unit. Enter its range (heel = Min, toe = Max) and its unit (%, Hz, dB, ms).

# The values
- Position and Time: type a new value to move it. The 2 triangles move it a little.
- Slope: how the value moves to the next value (Jump changes at once; the others move smoothly).
- A blue dot in the Control list: that control has values in this song.

# Add
- Click a section title (the triangle) to close or open it. MIDI Pilot remembers the open sections on this computer.
- Add value: the control jumps to that value at the edit cursor.
- Add ramp: the value moves from one value to another over a length (beats, bars, or to the end of the time selection).
- Swell: a ramp up, a hold, and a ramp back down.
- In the Values list, an LFO, a swell or a ramp is 1 row. Click its name to see its values. Its position and nudge move all of it, the red X removes all of it, and the copy icon copies it: "Paste at edit cursor" then shows under the values (also for another control).
- Add LFO: the value moves between a low and a high value, again and again (Sine, Triangle, Square, Saw up, Saw down), at a rate that follows the tempo. Peaks: the peaks can grow or shrink step by step.]] },
  { title = "Nudge and latency", text = [[
# Nudge
The 2 triangles of a row move a change a little earlier (left) or later (right). Set the amount in Settings > Editing > Nudge.

# Latency
If your unit reacts late, enter its delay in Settings > Devices > Latency. REAPER then sends the device's MIDI that much earlier, so the change happens on the beat.]] },
  { title = "Status bar", text = [[
- Line 1: the device and its MIDI output (green READY or red NOT AVAILABLE), and the song, Preset and Scene at the edit cursor. "Send state" sends that Preset, Scene and pedal values to the unit now. If the output is not available, "Reset MIDI" restarts REAPER's MIDI devices.
- Line 2: a message after an action, or a hint (for example songs without a first Scene).]] },
  { title = "Presets tab", text = [[
Give your Presets names (for example 3B = Song One). The Songs tab then shows the names. The names are saved on this computer and work in all projects.

- Add Preset: choose the folder, the bank and the Preset, type the name and click Add.
- Above the Preset list: a search field (a name, a number such as 3B, or a folder) and the Sort menu (Number, Name, Used first).
- In the list: click a name to change it.
- Scenes icon: name the 8 Scenes of the Preset and choose their colours.
- Pedal icon (Quad Cortex): what the 2 expression pedals move in this Preset.
- Pencil icon: move the name to another folder, bank or Preset.]] },
  { title = "Devices and tracks", text = [[
Add 1 device for each unit (Settings > Devices). Each device writes on its own track.

- Name: for example Guitar. The track is called "MIDI Guitar". If you rename the track in REAPER, the device gets that name too.
- MIDI output and MIDI channel: must match the unit's MIDI settings.
- Create track / Use selected track: give the device a new track, or use a track that you have.
- New MIDI items (Settings > Devices): when you paste or record a MIDI item on a device's track, MIDI Pilot sets it to the device's channel and adds a first Scene to each song in it.

# Line 6 units (not tested on a unit)
- A Scene is called a snapshot: Helix 8, HX Stomp 3, HX Stomp XL and HX Effects 4.
- Preset numbers: show them as the unit does, 01A or 000.]] },
  { title = "Settings and the bank file", text = [[
- Preset settings (Playback): when the first Preset of a song comes ("Before the song start", 250 ms, gives the unit time to load it), and where an added Preset goes (exactly at the edit cursor, before or after it).
- Scene settings (Playback): where Set up songs puts the first Scene (at the region start, before or after it, or after the region's Preset), where an added Scene goes, and the Scene keys. A note value keeps the changes on the grid.
- Nudge (Playback): how far the nudge triangles move a change.
- Appearance: the theme (Dark or Light), the Scene timelines under the songs (on or off), and how many rows a list shows before it scrolls.

# Preset names in REAPER
MIDI Pilot writes your Preset names into a bank file (Settings > General). Load it in ReaControlMIDI on the device's track (Bank/Program Select > Load File) to see the names in REAPER's MIDI editor.]] },
  { title = "What is saved where", text = [[
- On this computer: the devices, the Preset, folder and Scene names, the pedal assignments, the controls and the settings.
- In the project: which track belongs to which device, the track mode, the export folder and the Scene test reminders that you ignored.
- The MIDI itself is on the device tracks.]] },
}

function UI.tip(text)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then ImGui.SetTooltip(ctx, text) end
end

-- The theme: the same colours and sizes as Chart Cue (pushed every frame; UI.pop_style pops them).
-- (the name of the COL colour, so a theme change shows at once)
local STYLE_COLS = {
  { "WindowBg", "WIN_BG" }, { "ChildBg", "TRANSPARENT" }, { "PopupBg", "PANEL_BG" },
  { "Border", "LINE" }, { "FrameBg", "FIELD" }, { "FrameBgHovered", "FIELD_HOVER" },
  { "FrameBgActive", "FIELD_ACTIVE" }, { "Button", "BTN" }, { "ButtonHovered", "BTN_HOVER" },
  { "ButtonActive", "BTN_ACTIVE" }, { "Header", "ACTIVE_BG" }, { "HeaderHovered", "HEADER_HOVER" },
  { "HeaderActive", "HEADER_ACTIVE" }, { "CheckMark", "ACCENT" }, { "Text", "TEXT_MAIN" },
  { "TextDisabled", "TEXT_DIM" }, { "Separator", "LINE" }, { "ScrollbarBg", "TRANSPARENT" },
  { "ScrollbarGrab", "BTN_HOVER" }, { "ScrollbarGrabHovered", "BTN_ACTIVE" },
  { "ScrollbarGrabActive", "TOGGLE_OFF" }, { "TitleBg", "TITLE_BG" }, { "TitleBgActive", "TITLE_BG_ACTIVE" },
  { "TitleBgCollapsed", "TITLE_BG" },
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

-- Exact vertical gap of px pixels after the previous item (ImGui's row spacing is subtracted).
function UI.vgap(px) ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - CFG.SP_ROW + px) end

-- The text top in a row of controls (the same rule as Chart Cue: centred, CFG.TEXT_LIFT px higher).
function UI.text_y(top, h)
  h = h or ImGui.GetFrameHeight(ctx)
  return top + math.floor((h - ImGui.GetFontSize(ctx)) / 2) - CFG.TEXT_LIFT
end

-- Plain text in a row of controls, as a full-height item.
function UI.row_text(text, col)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.Dummy(ctx, math.max(1, (ImGui.CalcTextSize(ctx, text))), ImGui.GetFrameHeight(ctx))
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, UI.text_y(y), col or COL.TEXT_MAIN, text)
end

-- Wrapped text (notes and messages).
function UI.note(text, col)
  ImGui.PushTextWrapPos(ctx, 0)
  ImGui.TextColored(ctx, col or COL.TEXT_DIM, text)
  ImGui.PopTextWrapPos(ctx)
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

-- Button kinds: "primary" (blue: an action), "ghost" (text only), "danger" (red text), nil (grey).
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
  elseif kind == "danger" then -- a red outline (as in Chart Cue)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.DANGER_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.DANGER_ACTIVE)
    ImGui.PushStyleColor(ctx, ImGui.Col_Border(), COL.RED)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED); n = 5
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize(), 1)
  end
  local hit = ImGui.Button(ctx, label, w or 0, h or ImGui.GetFrameHeight(ctx))
  if kind == "danger" then ImGui.PopStyleVar(ctx, 1) end
  if n > 0 then ImGui.PopStyleColor(ctx, n) end
  return hit
end

-- The standard width of the action buttons (as Chart Cue's UI.std_w): the widest of these labels, so the buttons
-- all have the same size; a longer label gets its own width.
local STD_LABELS = { "Set up songs", "Add device", "Press at edit cursor", "4 taps on the beat", "Remove device...", "Reset MIDI devices", "Create track", "Use selected track", "Add control",
  "Add at edit cursor", "Add value", "Add ramp", "Add swell", "Copy the path", "Make it now", "Open Settings", "Clear Scenes" }
function UI.std_w(label)
  if not R.std_w then
    local w = 0
    for _, l in ipairs(STD_LABELS) do w = math.max(w, UI.btn_w(l, 0) + 16) end
    R.std_w = w
  end
  return math.max(R.std_w, UI.btn_w(label, 0) + 16)
end
-- The width of the buttons of a question or a small window (Save / Cancel, Yes / Cancel ...): all the same.
local DLG_LABELS = { "Use this Preset", "Save", "Cancel", "Rename", "Yes, move", "Back", "Yes, clear", "Yes, remove",
  "Move the MIDI", "Keep it", "Channel 16", "Keep channel 16", "Close", "Export", "Browse...", "Default" }
function UI.dlg_w(label)
  if not R.dlg_w then
    local w = 0
    for _, l in ipairs(DLG_LABELS) do w = math.max(w, UI.btn_w(l, 0)) end
    R.dlg_w = w
  end
  return math.max(R.dlg_w, UI.btn_w(label, 0))
end
-- A small button (in rows and in the status bar): the same colours, less height.
function UI.small_button(label)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 8, 1)
  local hit = ImGui.Button(ctx, label)
  ImGui.PopStyleVar(ctx, 1)
  return hit
end
-- The width of a control in a form (as Chart Cue): every control of a form fills the control column cw, so all
-- rows end at the same right edge; a row of 2 parts splits it. In a small window (no cw): CFG.W_POP.
function UI.fit_w(cw)
  return math.floor(cw and math.min(CFG.FORM_MAX_W, cw) or CFG.W_POP)
end
-- The width of a dropdown in a table cell: as wide as its longest option needs (never less than min_w).
function UI.cell_w(longest, min_w)
  local need = (ImGui.CalcTextSize(ctx, longest or "")) + ImGui.GetFrameHeight(ctx) + 24
  return math.floor(math.max(min_w or 0, need))
end
-- The longest option of a dropdown list ("a\0b\0"), cached.
function UI.longest(items)
  R.longest = R.longest or {}
  local c = R.longest[items]
  if c then return c end
  local best, bw = "", -1
  for s in items:gmatch("([^\0]*)\0") do
    local w = ImGui.CalcTextSize(ctx, s)
    if w > bw then best, bw = s, w end
  end
  R.longest[items] = best
  return best
end

-- The width a button needs for its text (never less than min_w).
function UI.btn_w(label, min_w)
  return math.max(min_w or 0, math.ceil((ImGui.CalcTextSize(ctx, label)) + 22))
end

-- Round "?" icon: hovering shows text in a wrapped tooltip.
function UI.help_icon(id, text)
  local d = CFG.HELP_ICON
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##help_" .. id, d, d)
  local hov = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy = x + d / 2, y + d / 2
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, d / 2, hov and COL.ACCENT_HOVER or COL.ACCENT)
  local tw, th = ImGui.CalcTextSize(ctx, "?")
  ImGui.DrawList_AddText(dl, cx - tw / 2, cy - th / 2, COL.WHITE, "?")
  if hov and ImGui.BeginTooltip(ctx) then
    ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 32)
    ImGui.Text(ctx, text)
    ImGui.PopTextWrapPos(ctx)
    ImGui.EndTooltip(ctx)
  end
end

-- A short notice that goes away by itself (line 2 of the status bar, for CFG.TOAST_SEC: UI.draw_status).
function UI.toast(text, warn) R.toast = { text = text, t0 = Util.now(), warn = warn } end

-- Section heading, as in Chart Cue: bold, blue, a full-width blue underline, a "?" at the right.
-- note / note_col: a short text at the right end of the title line (a notice).
-- fold: a key of S.lanes_open: a triangle at the left, a click on the title opens / closes it (saved); extra: a
-- dim text after the title. Returns true when the section is open (always true without fold).
function UI.heading(text, help, note, note_col, fold, extra)
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
  local open = true
  if fold then open = S.lanes_open[fold] == true; ImGui.SetCursorScreenPos(ctx, sx + 16, sy) end
  ImGui.PushFont(ctx, head_font)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.TextColored(ctx, COL.HEADING, text)
  ImGui.PopFont(ctx)
  local tx1, ty = ImGui.GetItemRectMax(ctx)
  if extra then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetCursorScreenPos(ctx, tx1 + CFG.CTRL_GAP, sy)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.TEXT_DIM, extra)
    local ex1, ey = ImGui.GetItemRectMax(ctx)
    tx1, ty = ex1, math.max(ty, ey)
  end
  if fold then -- the click area: the title line up to the device dropdown and the "?"
    local reserve = help and CFG.HELP_ICON + 10 or 0
    if R.dev_head then reserve = reserve + (ImGui.CalcTextSize(ctx, S.devices[R.cur_dev].name)) + ImGui.GetFrameHeight(ctx) + 26 end
    ImGui.SetCursorScreenPos(ctx, sx, sy)
    ImGui.InvisibleButton(ctx, "##fold_" .. fold, math.max(30, full - reserve), math.max(1, ty - sy))
    local hov = ImGui.IsItemHovered(ctx)
    if hov then
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
      ImGui.SetTooltip(ctx, open and "Click to close this section." or "Click to open this section.")
    end
    if ImGui.IsItemClicked(ctx, 0) then
      open = not open; S.lanes_open[fold] = open or nil; Util.mark_sdirty()
    end
    local dl = ImGui.GetWindowDrawList(ctx)
    local col = hov and COL.TEXT_BRIGHT or COL.HEADING
    local cx, cy = sx + 6, sy + (ty - sy) / 2
    if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 5, cy - 3, cx + 5, cy - 3, cx, cy + 3, col)
    else ImGui.DrawList_AddTriangleFilled(dl, cx - 3, cy - 5, cx - 3, cy + 5, cx + 3, cy, col) end
  end
  if note then
    local x_end = sx + full - (help and CFG.HELP_ICON + 10 or 0)
    local avail = x_end - tx1 - 16
    if avail > 40 then
      local s = UI.trunc(note, avail)
      local nw = ImGui.CalcTextSize(ctx, s)
      ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x_end - nw, UI.text_y(sy), note_col or COL.YELLOW, s)
    end
  end
  if R.dev_head then -- the device of the tab: its name and an arrow at the right end of the heading (a dropdown)
    R.dev_head = nil
    local dv = S.devices[R.cur_dev]
    local w = math.floor((ImGui.CalcTextSize(ctx, dv.name)) + ImGui.GetFrameHeight(ctx) + 18)
    ImGui.SetCursorScreenPos(ctx, sx + full - (help and CFG.HELP_ICON + 10 or 0) - w, sy)
    ImGui.SetNextItemWidth(ctx, w)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.HEADING)
    local open = ImGui.BeginCombo(ctx, "##hdev", dv.name)
    ImGui.PopStyleColor(ctx, 3)
    if open then
      for i, x in ipairs(S.devices) do
        if ImGui.Selectable(ctx, x.name .. "##hd" .. i, i == R.cur_dev) then R.cur_dev = i end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("The device that this tab shows. Click to show another device.")
  end
  if help then
    ImGui.SameLine(ctx)
    ImGui.SetCursorScreenPos(ctx, sx + full - CFG.HELP_ICON, sy + (ImGui.GetFrameHeight(ctx) - CFG.HELP_ICON) / 2)
    UI.help_icon(text, help)
    local _, hy = ImGui.GetItemRectMax(ctx)
    ty = math.max(ty, hy)
  end
  ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), sx, ty + 3, sx + full, ty + 3, COL.ACCENT, 1.5)
  ImGui.SetCursorScreenPos(ctx, sx, ty)
  ImGui.Dummy(ctx, 0, 3)
  UI.vgap(CFG.SP_TITLE_AFTER)
  return open
end

-- The label column: returns the control column x and width, and wide (the label is left of its control).
function UI.form(label)
  local x0 = ImGui.GetCursorPosX(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local wide = aw >= CFG.LABEL_W + CFG.FORM_MIN_WIDE
  if wide and label then
    ImGui.PushFont(ctx, bold)
    if (ImGui.CalcTextSize(ctx, label)) > CFG.LABEL_W - 8 then wide = false end
    ImGui.PopFont(ctx)
  end
  local cx = wide and (x0 + CFG.LABEL_W) or x0
  return cx, math.max(100, math.min(CFG.FORM_MAX_W, aw - (cx - x0) - 4)), wide
end

-- A row label (bold), then the cursor in the control column. Returns the control column x and width.
function UI.row_start(label)
  local cx, cw, wide = UI.form(label)
  ImGui.PushFont(ctx, bold)
  UI.row_text(label)
  ImGui.PopFont(ctx)
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, cx)
  return cx, cw
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

-- A setting row: the label in the label column (a click on it also switches), the toggle in the control column.
function UI.checkbox(label, v, tip)
  local cx, _, wide = UI.form(label)
  ImGui.PushFont(ctx, bold)
  UI.row_text(label)
  ImGui.PopFont(ctx)
  local lclk = ImGui.IsItemClicked(ctx)
  if ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  if tip then UI.tip(tip) end
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, cx)
  local ch, nv = UI.toggle("##cb_" .. label, v)
  if tip then UI.tip(tip) end
  if lclk then ch, nv = true, not v end
  return ch, nv
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

-- Small round remove button: a red ring with a red X; filled red with a white X on hover.
function UI.remove_x_button(id, size)
  local hit = ImGui.InvisibleButton(ctx, id, size, size)
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy = x0 + size / 2, y0 + size / 2
  local rad = math.floor(size * 0.36)
  local d = rad * 0.45
  if hov then ImGui.DrawList_AddCircleFilled(dl, cx, cy, rad, COL.RED)
  else ImGui.DrawList_AddCircle(dl, cx, cy, rad, COL.RED, 0, 1.5) end
  local xc = hov and COL.WHITE or COL.RED
  ImGui.DrawList_AddLine(dl, cx - d, cy - d, cx + d, cy + d, xc, 1.8)
  ImGui.DrawList_AddLine(dl, cx - d, cy + d, cx + d, cy - d, xc, 1.8)
  return hit
end

-- The icons of the text tabs in a narrow window (drawn like Chart Cue's): 1 Songs (a song list),
-- 2 Lanes (a CC ramp), 3 Presets (books).
function UI.draw_tab_icon(dl, cx, cy, i, col)
  if i == 1 then
    ImGui.DrawList_AddTriangleFilled(dl, cx - 9, cy - 8, cx - 9, cy - 2, cx - 4, cy - 5, col)
    ImGui.DrawList_AddLine(dl, cx - 1, cy - 5, cx + 9, cy - 5, col, 2)
    for k = 0, 1 do
      local y = cy + 1 + k * 5
      ImGui.DrawList_AddCircleFilled(dl, cx - 6.5, y, 1.6, col)
      ImGui.DrawList_AddLine(dl, cx - 1, y, cx + 9, y, col, 2)
    end
  elseif i == 2 then
    ImGui.DrawList_AddLine(dl, cx - 9, cy + 7, cx + 9, cy + 7, col, 1.5)
    ImGui.DrawList_PathLineTo(dl, cx - 9, cy + 5)
    ImGui.DrawList_PathLineTo(dl, cx - 3, cy + 5)
    ImGui.DrawList_PathLineTo(dl, cx + 4, cy - 6)
    ImGui.DrawList_PathLineTo(dl, cx + 9, cy - 6)
    ImGui.DrawList_PathStroke(dl, col, 0, 2)
    ImGui.DrawList_AddCircleFilled(dl, cx - 3, cy + 5, 2, col)
    ImGui.DrawList_AddCircleFilled(dl, cx + 4, cy - 6, 2, col)
  else
    ImGui.DrawList_AddRectFilled(dl, cx - 8, cy - 6, cx - 4, cy + 7, col, 1)
    ImGui.DrawList_AddRectFilled(dl, cx - 2.5, cy - 8, cx + 1.5, cy + 7, col, 1)
    ImGui.DrawList_AddQuadFilled(dl, cx + 3, cy - 5, cx + 6.5, cy - 6.5, cx + 9.5, cy + 6, cx + 6, cy + 7.5, col)
  end
end

-- Gear icon (the Settings tab): a ring with 8 teeth.
function UI.draw_gear_icon(dl, cx, cy, col)
  for k = 0, 7 do
    local a = k * math.pi / 4
    local c, sn = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * 5, cy + sn * 5, cx + c * 8.5, cy + sn * 8.5, col, 3)
  end
  ImGui.DrawList_AddCircle(dl, cx, cy, 4.5, col, 0, 3)
end

-- A question with 2 buttons (a popup in the window). UI.ask opens it; UI.draw_ask draws it every frame.
-- alt / alt_fn: a 2nd choice (for example "Remove device only").
function UI.ask(text, yes, fn, alt, alt_fn) R.ask = { text = text, yes = yes, fn = fn, alt = alt, alt_fn = alt_fn, open = true } end
function UI.draw_ask()
  local a = R.ask
  if not a then return end
  if a.open then ImGui.OpenPopup(ctx, "MIDI Pilot##ask"); a.open = false end
  -- always in the centre of the window when it opens (a moved question does not keep its place)
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if ImGui.BeginPopupModal(ctx, "MIDI Pilot##ask", nil, ImGui.WindowFlags_AlwaysAutoResize()) then
    ImGui.PushTextWrapPos(ctx, 360)
    ImGui.Text(ctx, a.text)
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    if UI.button(a.yes, UI.dlg_w(a.yes), nil, a.safe and "primary" or "danger") then a.fn(); R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if a.alt then
      if UI.button(a.alt, UI.dlg_w(a.alt)) then a.alt_fn(); R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    end
    if UI.button("Cancel", UI.dlg_w("Cancel")) then R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  else
    R.ask = nil
  end
end

-- A small drawn wave in the box x, y, w, h: an LFO shape (LFO_ICONS) or a slope (SLOPE_ICONS).
function UI.wave(dl, x, y, w, h, kind, col)
  if kind == "sawup" or kind == "sawdown" then -- 1 cycle: from the middle a jump, a straight ramp, a jump back to the middle
    local lo, hi, mid = y + h, y, y + h / 2
    if kind == "sawdown" then lo, hi = hi, lo end
    ImGui.DrawList_AddLine(dl, x, mid, x, lo, col, 1.5)
    ImGui.DrawList_AddLine(dl, x, lo, x + w, hi, col, 1.5)
    ImGui.DrawList_AddLine(dl, x + w, hi, x + w, mid, col, 1.5)
    return
  end
  if kind == "sine" then -- 1 cycle from the middle: up, down, back to the middle
    local px, py
    for i = 0, 24 do
      local u = i / 24
      local qx, qy = x + u * w, y + h / 2 - math.sin(u * 2 * math.pi) * h / 2
      if px then ImGui.DrawList_AddLine(dl, px, py, qx, qy, col, 1.5) end
      px, py = qx, qy
    end
    return
  end
  local N = 24
  local px, py
  for i = 0, N do
    local u = i / N
    local v
    if kind == "sine" then v = 0.5 - 0.5 * math.cos(u * 3 * math.pi)
    elseif kind == "tri" then local p = (u * 1.5) % 1; v = p < 0.5 and p * 2 or 2 - p * 2
    elseif kind == "square" then v = ((u * 1.5) % 1) < 0.5 and 0 or 1
    elseif kind == "sawup" then v = (u * 1.5) % 1
    elseif kind == "sawdown" then v = 1 - (u * 1.5) % 1
    elseif kind == "jump" then v = u < 0.999 and 0 or 1
    elseif kind == "straight" then v = u
    elseif kind == "slow" then v = 0.5 - 0.5 * math.cos(u * math.pi)
    elseif kind == "fast_start" then v = 1 - (1 - u) ^ 3
    elseif kind == "fast_end" then v = u ^ 3
    else v = u ^ 2 end
    local qx, qy = x + u * w, y + h - v * h
    if px then ImGui.DrawList_AddLine(dl, px, py, qx, qy, col, 1.5) end
    px, py = qx, qy
  end
end
-- The bend of a Curve (-1 .. 1): drag it; a double-click sets 0 (it wins until the mouse button is up). Returns
-- changed, the value, and done: the edit ended with a new value (to write it).
function UI.bend_slider(id, v)
  local ch, nv = ImGui.SliderDouble(ctx, id, v, -1, 1, "%.2f", ImGui.SliderFlags_NoInput())
  if ImGui.IsItemActivated(ctx) then R.bend_t0 = v end
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then R.bend_reset = id end
  if R.bend_reset == id then
    ch, nv = true, 0
    if not ImGui.IsMouseDown(ctx, 0) then R.bend_reset = nil end
  end
  local done = ImGui.IsItemDeactivated(ctx) and nv ~= R.bend_t0
  return ch, nv, done
end
-- A dropdown with a small icon (UI.wave) before each name: labels (with room for the icon), icons, cur (0-based).
-- Returns changed, the new index (0-based).
function UI.icon_combo(id, cur, labels, icons, w)
  ImGui.SetNextItemWidth(ctx, w)
  local dl = ImGui.GetWindowDrawList(ctx)
  local bx, by = ImGui.GetCursorScreenPos(ctx)
  local fh = ImGui.GetFrameHeight(ctx)
  local res
  if ImGui.BeginCombo(ctx, id, labels[cur + 1]) then
    for i = 1, #labels do
      if ImGui.Selectable(ctx, labels[i] .. id .. i, i - 1 == cur) and i - 1 ~= cur then res = i - 1 end
      local ix, iy = ImGui.GetItemRectMin(ctx)
      local _, iy1 = ImGui.GetItemRectMax(ctx)
      UI.wave(ImGui.GetWindowDrawList(ctx), ix + 1, iy + 3, 16, iy1 - iy - 6, icons[i], COL.TEXT_MAIN)
    end
    ImGui.EndCombo(ctx)
  end
  UI.wave(dl, bx + 8, by + 5, 16, fh - 10, icons[cur + 1], ImGui.GetColor(ctx, ImGui.Col_Text()))
  return res ~= nil, res
end
-- A square button with a drawn icon: "send" (a play triangle), "back" / "fwd" (2 triangles: nudge earlier / later),
-- "copy" (2 sheets), "minus", "plus". Returns true when clicked.
function UI.icon_button(id, kind, size)
  local hit = ImGui.Button(ctx, "##" .. id, size, size)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local col = ImGui.GetColor(ctx, ImGui.Col_Text()) -- (dimmed when disabled)
  local cx, cy = math.floor(x0 + size / 2) + 0.5, math.floor(y0 + size / 2) + 0.5
  local s = math.max(3, math.floor(size * 0.18))
  if kind == "send" then
    ImGui.DrawList_AddTriangleFilled(dl, cx - s + 1, cy - s - 1, cx - s + 1, cy + s + 1, cx + s + 2, cy, col)
  elseif kind == "fwd" or kind == "back" then
    local dir = (kind == "fwd") and 1 or -1
    for k = 0, 1 do
      local bx = cx + dir * (k * (s + 1) - s / 2 - 1)
      ImGui.DrawList_AddTriangleFilled(dl, bx - dir * s * 0.6, cy - s, bx - dir * s * 0.6, cy + s, bx + dir * s * 0.8, cy, col)
    end
  elseif kind == "scenes" then -- 3 blocks in a row (a scene strip)
    for k = -1, 1 do
      local bx = cx + k * (s + 1)
      ImGui.DrawList_AddRectFilled(dl, bx - s / 2, cy - s, bx + s / 2, cy + s, col, 1)
    end
  elseif kind == "pedal" then -- an expression pedal: a slanted plate on a base
    ImGui.DrawList_AddLine(dl, cx - s - 1, cy + s, cx + s + 1, cy + s, col, 2)
    ImGui.DrawList_AddQuadFilled(dl, cx - s, cy + s - 2, cx + s, cy - s - 1, cx + s + 1, cy - s + 2, cx - s + 2, cy + s - 1, col)
  elseif kind == "copy" then -- 2 sheets
    ImGui.DrawList_AddRect(dl, cx - s - 1, cy - s - 1, cx + s - 2, cy + s - 2, col, 1, 0, 1.5)
    ImGui.DrawList_AddRectFilled(dl, cx - s + 2, cy - s + 2, cx + s + 1, cy + s + 1, col, 1)
  elseif kind == "edit" then -- a pencil
    ImGui.DrawList_AddLine(dl, cx - s, cy + s, cx + s, cy - s, col, 3)
    ImGui.DrawList_AddTriangleFilled(dl, cx - s - 2, cy + s + 2, cx - s + 1, cy + s - 3, cx - s + 3, cy + s - 1, col)
  else
    ImGui.DrawList_AddLine(dl, cx - s - 1, cy, cx + s + 1, cy, col, 2)
    if kind == "plus" then ImGui.DrawList_AddLine(dl, cx, cy - s - 1, cx, cy + s + 1, col, 2) end
  end
  return hit
end

-- A whole-number field with drawn "-" and "+" buttons after it (in place of ImGui's text buttons). The width set
-- with SetNextItemWidth is the width of the field and its 2 buttons. A visible label goes after the buttons.
function UI.input_int(label, v, step)
  local fh = ImGui.GetFrameHeight(ctx)
  local id, vis = label:match("^(.-)##(.*)$")
  if not id then id, vis = label, label else id, vis = vis, id end
  local w = ImGui.CalcItemWidth(ctx) - 2 * (fh + CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, math.max(40, w))
  local ch, nv = ImGui.InputInt(ctx, "##ii" .. id, v, 0, 0)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.icon_button("iim" .. id, "minus", fh) then ch, nv = true, v - (step or 1) end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.icon_button("iip" .. id, "plus", fh) then ch, nv = true, v + (step or 1) end
  if vis ~= "" then ImGui.SameLine(ctx, 0, CFG.CTRL_GAP); UI.row_text(vis, COL.TEXT_MAIN) end
  return ch, nv
end

-- The 2 nudge buttons (earlier / later) of a row: returns -1, 1 or nil.
function UI.nudge_buttons(id, fh, what)
  local dir
  if UI.icon_button("nl" .. id, "back", fh) then dir = -1 end
  UI.tip("Move " .. what .. " " .. Midi.nudge_text() .. " earlier (Settings > Editing > Nudge).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.icon_button("nr" .. id, "fwd", fh) then dir = 1 end
  UI.tip("Move " .. what .. " " .. Midi.nudge_text() .. " later (Settings > Editing > Nudge).")
  return dir
end

-- A clickable row, as Chart Cue's list rows: under the mouse a light highlight (COL.ROW_HOVER, corners 4) and a
-- hand cursor (UI.row_click_area); the row at the edit cursor (during playback: the play position) gets the
-- current-row look (UI.row_highlight: a blue tint and a blue bar on its left). Both reach the right side of the
-- panel. A click on the row (not on one of its controls) moves the edit cursor to the row's time.
-- UI.pill_begin before the row's controls (from the last frame's hover), UI.pill_end after them (the click).
function UI.pill_right(x)
  local cx = ImGui.GetCursorScreenPos(ctx)
  return math.max(x + 40, cx + ImGui.GetContentRegionAvail(ctx) - 4)
end
function UI.pill_begin(key, x, y, w, cur)
  local h = ImGui.GetFrameHeight(ctx)
  local x1 = UI.pill_right(x)
  local dl = ImGui.GetWindowDrawList(ctx)
  R.pill_hov = R.pill_hov or {}
  R.pill_x1 = R.pill_x1 or {}
  R.pill_x1[key] = x1 -- (for UI.pill_end: there the cursor is no longer at the row start)
  if cur then
    ImGui.DrawList_AddRectFilled(dl, x - 6, y - 2, x1, y + h + 2, COL.ACTIVE_BG, 4)
    ImGui.DrawList_AddRectFilled(dl, x - 6, y - 2, x - 3, y + h + 2, COL.ACCENT, 2)
  end
  if R.pill_hov[key] then ImGui.DrawList_AddRectFilled(dl, x - 6, y - 2, x1, y + h + 2, COL.ROW_HOVER, 4) end
end
-- Double-click (a strip block, a list row): REAPER's MIDI editor opens the device's MIDI item at time t, its view at
-- the edit cursor, its CC lane on cc (when REAPER allows it). The item becomes the only selected item.
function UI.open_midi(d, t, cc)
  local tr = Dev.track(d)
  local item
  if tr then
    for i = 0, r.CountTrackMediaItems(tr) - 1 do
      local it = r.GetTrackMediaItem(tr, i)
      local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local take = r.GetActiveTake(it)
      if take and r.TakeIsMIDI(take) and t >= pos - CFG.EDGE and t < pos + r.GetMediaItemInfo_Value(it, "D_LENGTH") then
        item = it; break
      end
    end
  end
  if not item then UI.toast(d.name .. ": no MIDI item at " .. Util.fmt_beats(t) .. ".", true); return end
  r.SetEditCurPos(t, true, false)
  r.Main_OnCommand(40289, 0) -- Item: Unselect all items
  r.SetMediaItemSelected(item, true)
  r.UpdateArrange()
  r.Main_OnCommand(40153, 0) -- Item: Open in built-in MIDI editor
  local me = r.MIDIEditor_GetActive()
  if me then
    if cc and r.MIDIEditor_SetSetting_int then r.MIDIEditor_SetSetting_int(me, "last_clicked_cc_lane", cc) end
    r.MIDIEditor_OnCommand(me, 40151) -- View: Go to edit cursor
  end
end

-- d, cc: a double-click opens the MIDI editor there (UI.open_midi).
function UI.pill_end(key, x, y, w, t, what, d, cc)
  local h = ImGui.GetFrameHeight(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  local on = mx >= x - 6 and mx < (R.pill_x1[key] or x + w + 6) and my >= y - 2 and my < y + h + 2
    and ImGui.IsWindowHovered(ctx) and not ImGui.IsAnyItemHovered(ctx)
    and not ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId())
  R.pill_hov[key] = on or nil
  if on then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
    ImGui.SetTooltip(ctx, "Click: the edit cursor goes to " .. (what or "this change") .. " (" .. Util.fmt_beats(t) .. ")."
      .. (d and "\nDouble-click: open REAPER's MIDI editor here." or ""))
    if d and ImGui.IsMouseDoubleClicked(ctx, 0) then UI.open_midi(d, t, cc)
    elseif ImGui.IsMouseClicked(ctx, 0) then r.SetEditCurPos(t, true, false) end
  end
end

-- An editable position or time of a row (key: unique for the row): returns the typed time when Enter or a click
-- elsewhere ends the edit, false when the text is not a time, else nil.
function UI.edit_time(key, width, text, parse, tip, right)
  R.st_text = R.st_text or {}
  ImGui.SetNextItemWidth(ctx, width)
  -- right: the text right-aligned while it is not edited (ImGui's field has no alignment: it is drawn on top)
  local over = right and R.st_text[key] == nil
  if over then ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.TRANSPARENT) end
  local _, nt = ImGui.InputText(ctx, "##" .. key, R.st_text[key] or text)
  if over then
    ImGui.PopStyleColor(ctx)
    local x1, y0 = ImGui.GetItemRectMax(ctx), select(2, ImGui.GetItemRectMin(ctx))
    local tw = ImGui.CalcTextSize(ctx, text)
    ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x1 - tw - 8, UI.text_y(y0), COL.TEXT_MAIN, text)
  end
  local res
  if ImGui.IsItemActive(ctx) then R.st_text[key] = nt
  elseif ImGui.IsItemDeactivated(ctx) then
    res = parse(R.st_text[key] or nt) or false
    R.st_text[key] = nil
  else R.st_text[key] = nil end
  UI.tip(tip)
  return res
end
local BEATS_TIP = "Bar, beat and hundredths of a beat in the project (as REAPER's ruler). Type a new position and\n"
  .. "press Enter, for example 9.1 or 9.2.50 (half a beat after beat 2)."
local TIME_TIP = "The time from the song start (m:ss.s). Type a new time and press Enter, for example 0:32.5."

-- A box of rows that scrolls when there are more than max_rows (its scrollbar right after the rows, always shown):
-- returns true when the box is open (then call ImGui.EndChild after the rows). w: the width of the rows.
function UI.begin_rows_box(id, n, max_rows, w)
  if n <= max_rows then return false end
  local rh = ImGui.GetFrameHeightWithSpacing(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarBg(), COL.FIELD)
  ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrab(), COL.TOGGLE_OFF)
  local vis = ImGui.BeginChild(ctx, id, w + 18, max_rows * rh + 4, 0, ImGui.WindowFlags_AlwaysVerticalScrollbar())
  ImGui.PopStyleColor(ctx, 2)
  return vis
end

-- The question after a new MIDI item with more than 1 MIDI channel (R.chq): which channel the device uses.
function UI.draw_chan_ask()
  local q = R.chq
  if not q then return end
  if q.open then ImGui.OpenPopup(ctx, "MIDI channel##chq"); q.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "MIDI channel##chq", nil, ImGui.WindowFlags_AlwaysAutoResize()) then return end
  ImGui.PushTextWrapPos(ctx, 360)
  ImGui.Text(ctx, string.format("The new MIDI item uses another MIDI channel than %s (now: channel %d)%s.\n"
    .. "Which channel does %s use?%s", q.d.name, q.d.chan,
    #q.chans > 2 and ", or more than 1 channel" or "", q.d.name,
    q.other and ("\n\nThe track already has MIDI on channel " .. q.d.chan .. ": with another channel, MIDI Pilot no "
      .. "longer shows it (it still plays). Settings > Devices > MIDI channel can move it to the new channel.") or ""))
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  local pick
  for k, ch in ipairs(q.chans) do
    if k > 1 then ImGui.SameLine(ctx, 0, CFG.CTRL_GAP) end
    local label = (ch + 1 == q.d.chan) and ("Keep channel " .. (ch + 1)) or ("Channel " .. (ch + 1))
    if UI.button(label .. "##chq" .. ch, UI.dlg_w(label), nil, (ch + 1 == q.d.chan) and "primary" or nil) then pick = ch + 1 end
  end
  if pick then
    if pick ~= q.d.chan then Midi.set_channel(q.d, pick) end
    R.chq = nil
    ImGui.CloseCurrentPopup(ctx)
    Midi.fill_item_starts(q.d, q.items)
  end
  ImGui.EndPopup(ctx)
end

-- The tab strip, as in Chart Cue: the text tabs, then the Settings (gear) and Help ("?") tabs.
-- The selected tab joins the panel below it.
function UI.draw_tabs()
  if S.tab <= #TAB_NAMES and S.tab_hide[S.tab] then S.tab = TAB_SETTINGS end -- (a hidden tab: Settings)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local gap, h, lift = CFG.TAB_GAP, CFG.TAB_H, CFG.TAB_LIFT
  local n = 0
  for i = 1, #TAB_NAMES do if not S.tab_hide[i] then n = n + 1 end end
  n = math.max(1, n)
  local tab_w = math.floor((aw - 2 * h - gap * (n + 1) - CFG.TAB_GROUP_GAP - 8) / n)
  -- a narrow window: when 1 name does not fit its tab, every text tab shows its icon (the name is its tooltip)
  ImGui.PushFont(ctx, head_font)
  local icons = false
  for i = 1, #TAB_NAMES do
    if not S.tab_hide[i] and (ImGui.CalcTextSize(ctx, TAB_NAMES[i])) > tab_w - 16 then icons = true; break end
  end
  ImGui.PopFont(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local strip_b = y0 + h + lift
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + aw, strip_b, COL.TAB_BG, 8, ImGui.DrawFlags_RoundCornersTop())
  local function tab(i, w, x, tip)
    local active = (S.tab == i)
    local top = active and y0 or (y0 + lift)
    local bottom = active and (strip_b + 1) or (strip_b - 4)
    ImGui.SetCursorScreenPos(ctx, x, top)
    if ImGui.InvisibleButton(ctx, "##tab" .. i, w, bottom - top) and not active then
      S.tab = i; R.ask = nil; Util.mark_sdirty()
    end
    local hov = ImGui.IsItemHovered(ctx)
    if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    if tip then UI.tip(tip) end
    if i <= #TAB_NAMES and ImGui.IsItemClicked(ctx, 1) then R.tab_menu = i end
    if active then
      ImGui.DrawList_AddRectFilled(dl, x, top, x + w, bottom, COL.PANEL_BG, 8, ImGui.DrawFlags_RoundCornersTop())
      ImGui.DrawList_AddRectFilled(dl, x + 8, top, x + w - 8, top + 3, COL.ACCENT, 2)
    elseif hov then
      ImGui.DrawList_AddRectFilled(dl, x, top, x + w, bottom, COL.TAB_HOVER, 7)
    end
    local col = (active or hov) and COL.TEXT_MAIN or COL.TEXT_DIM
    if i == TAB_SETTINGS then UI.draw_gear_icon(dl, x + w / 2, (top + bottom) / 2, col); return end
    if icons and i < TAB_SETTINGS then
      UI.draw_tab_icon(dl, math.floor(x + w / 2) + 0.5, math.floor((top + bottom) / 2) + 0.5, i, col)
      return
    end
    local label = (i == TAB_HELP) and "?" or TAB_NAMES[i]
    local f = active and head_font or font
    ImGui.PushFont(ctx, f)
    label = UI.trunc(label, w - 12)
    local tw = ImGui.CalcTextSize(ctx, label)
    ImGui.DrawList_AddText(dl, x + math.floor((w - tw) / 2), UI.text_y(top, bottom - top), col, label)
    ImGui.PopFont(ctx)
  end
  local x = x0 + 4
  for i = 1, #TAB_NAMES do
    if not S.tab_hide[i] then tab(i, tab_w, x, icons and TAB_NAMES[i] or nil); x = x + tab_w + gap end
  end
  x = x + CFG.TAB_GROUP_GAP
  tab(TAB_SETTINGS, h, x, "Settings"); x = x + h + gap
  tab(TAB_HELP, h, x, "Help: how MIDI Pilot works")
  -- the right-click menu of a tab
  if R.tab_menu then ImGui.OpenPopup(ctx, "##tabmenu"); R.tab_key, R.tab_menu = R.tab_menu, nil end
  if ImGui.BeginPopup(ctx, "##tabmenu") then
    if R.tab_key and ImGui.Selectable(ctx, "Hide this tab") then
      S.tab_hide[R.tab_key] = true
      if S.tab == R.tab_key then S.tab = TAB_SETTINGS end
      Util.mark_sdirty()
      UI.toast("The " .. TAB_NAMES[R.tab_key] .. " tab is hidden. Settings > Appearance > Tabs shows it again.")
    end
    ImGui.EndPopup(ctx)
  end
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
  ImGui.Dummy(ctx, 0, 0)
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
end

-- "No device yet": the hint of the Songs, Lanes and Presets tabs.
function UI.no_device_hint()
  if #S.devices > 0 then return false end
  UI.note("No device yet. Add your Quad Cortex in the Settings tab (the gear).", COL.YELLOW)
  if UI.button("Open Settings", UI.std_w("Open Settings"), nil, "primary") then S.tab = TAB_SETTINGS; S.settings_open = 1; Util.mark_sdirty() end
  return true
end

-- The device that the Songs, Lanes and Presets tabs show. With more than 1 device, the next heading of the tab ends
-- with its name and a small arrow (a dropdown: UI.heading, R.dev_head). Returns it.
function UI.device_picker()
  R.cur_dev = Util.clamp(R.cur_dev or 1, 1, math.max(1, #S.devices))
  R.dev_head = #S.devices > 1
  return S.devices[R.cur_dev]
end

-- The preset dropdown items of a device (cached until the preset names or the device change): the named presets.
function UI.pick_items(d)
  local c = R.pick_cache
  if c and c.d == d and c.model == d.model then return c.items end
  local items = {}
  for _, k in ipairs(Preset.sorted_keys(S.lib[d.id])) do
    local f, i = k:match("^(%d+):(%d+)$")
    f, i = tonumber(f), tonumber(i)
    items[#items + 1] = { folder = f, index = i, text = Preset.text(d, f, i) }
  end
  R.pick_cache = { d = d, model = d.model, items = items }
  return items
end

-- The "Choose by number" window: folder, bank and letter. R.pick = { d, rg, folder, bank, letter }.
function UI.draw_pick()
  local pk = R.pick
  if not pk then return end
  if pk.open then ImGui.OpenPopup(ctx, "Choose a Preset##pick"); pk.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Choose a Preset##pick", true, ImGui.WindowFlags_AlwaysAutoResize()) then
    R.pick = nil; return
  end
  local d, m = pk.d, MODELS[pk.d.model]
  ImGui.Text(ctx, "Song: " .. pk.rg.name .. (pk.at and ("  -  a Preset change at " .. Util.fmt_beats(pk.at)) or ""))
  UI.vgap(6)
  ImGui.SetNextItemWidth(ctx, UI.fit_w())
  local ch, v = ImGui.Combo(ctx, "Folder", pk.folder, Preset.folder_items(d))
  if ch then pk.folder = v end
  if UI.number_mode(d) then UI.number_input(d, pk, "Number", CFG.W_POP)
  else
    ImGui.SetNextItemWidth(ctx, CFG.W_POP)
    ch, v = UI.input_int("Bank", pk.bank, 1)
    if ch then pk.bank = Util.clamp(v, 1, m.banks) end
    ImGui.SetNextItemWidth(ctx, CFG.W_POP)
    ch, v = ImGui.Combo(ctx, "Preset", pk.letter - 1, UI.letter_items(d.model))
    if ch then pk.letter = v + 1 end
  end
  local idx = Preset.index(d.model, pk.bank, pk.letter)
  UI.vgap(6)
  ImGui.TextColored(ctx, COL.TEXT_DIM, Preset.text(d, pk.folder, idx))
  UI.vgap(8)
  if UI.button("Use this Preset", UI.dlg_w("Use this Preset"), nil, "primary") then
    if pk.at then Midi.put_pc(d, pk.old and pk.at or Midi.other_time("pc", pk.at), pk.folder, idx, pk.old)
    else UI.set_preset(d, pk.rg, pk.folder, idx) end
    R.pick = nil; ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", UI.dlg_w("Cancel")) then R.pick = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- The letter dropdown items of a model ("A\0B\0..."), cached.
function UI.letter_items(model)
  R.letter_items = R.letter_items or {}
  local s = R.letter_items[model]
  if s then return s end
  local L = MODELS[model].letters
  s = ""
  for k = 1, #L do s = s .. L:sub(k, k) .. "\0" end
  R.letter_items[model] = s
  return s
end
-- True when a device shows its presets as numbers (Line 6: Preset numbers > Numbers).
function UI.number_mode(d) return MODELS[d.model].line6 and d.pnum == "num" end
-- The preset number field (number mode): st.bank and st.letter follow the typed number (000-127).
function UI.number_input(d, st, label, w)
  local m = MODELS[d.model]
  local L = #m.letters
  local idx = Preset.index(d.model, st.bank, st.letter)
  ImGui.SetNextItemWidth(ctx, w)
  local ch, v = UI.input_int(label, idx, 1)
  if ch then v = Util.clamp(v, 0, m.presets - 1); st.bank, st.letter = v // L + 1, v % L + 1 end
end

function UI.set_preset(d, rg, folder, index)
  -- selected songs (Ctrl+click on their names): all of them get the preset, in 1 undo step
  local sel = R.song_sel
  if sel and sel[string.format("%.3f", rg.start)] then
    local list = {}
    for _, x in ipairs(R.regions) do if sel[string.format("%.3f", x.start)] then list[#list + 1] = x end end
    if #list > 1 then
      r.Undo_BeginBlock()
      for _, x in ipairs(list) do Midi.write_song(d, x, folder, index) end
      r.UpdateArrange()
      r.Undo_EndBlock(folder and "MIDI Pilot: Preset of " .. #list .. " songs" or "MIDI Pilot: remove the Preset of " .. #list .. " songs", -1)
      R.song_sel = nil
      UI.toast(folder and string.format("%d songs get %s.", #list, Preset.text(d, folder, index))
        or string.format("The Preset changes of %d songs are removed.", #list))
      return
    end
  end
  if Midi.set_song(d, rg, folder, index) then UI.toast("'" .. rg.name .. "' starts at 0:00: its Preset change is at 0:00.", true) end
end

-- The width of the preset dropdown of the song rows: as wide as the longest preset name needs (at least CFG.W_M,
-- at most CFG.FORM_MAX_W), the same in every row (measured once, cached with the preset list).
function UI.preset_w(d)
  local c = R.pick_cache
  if c and c.d == d and c.pw then return c.pw end
  local ln, lw = "Choose by number...", (ImGui.CalcTextSize(ctx, "Choose by number..."))
  for _, it in ipairs(UI.pick_items(d)) do
    local s = "(" .. it.text .. ")"
    local w = ImGui.CalcTextSize(ctx, s)
    if w > lw then ln, lw = s, w end
  end
  local w = math.min(CFG.FORM_MAX_W, UI.cell_w(ln, CFG.W_M))
  if R.pick_cache then R.pick_cache.pw = w end
  return w
end

-- 1 song row: number, name, length; the preset dropdown, Send now and the red X.
function UI.draw_song_row(d, i, rg, aw)
  ImGui.PushID(ctx, i)
  local fh = ImGui.GetFrameHeight(ctx)
  local ch = Midi.song_change(d, rg)
  local pw = UI.preset_w(d)
  local right_w = pw + 2 * (fh + CFG.CTRL_GAP)
  local name_area = math.max(80, aw - right_w - 14)
  local narrow = name_area < 140
  if narrow then name_area = aw - 14 end
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.Dummy(ctx, name_area, fh)
  local dl = ImGui.GetWindowDrawList(ctx)
  local ty = UI.text_y(y)
  local len = Util.fmt_mmss(rg.stop - rg.start)
  local lw = (ImGui.CalcTextSize(ctx, len))
  -- the arrow and the number open / close the song's scene list
  local key = string.format("%.3f", rg.start)
  local sc_open = R.sc_open and R.sc_open[key]
  local mx, my = ImGui.GetMousePos(ctx)
  local on_arrow = mx >= x - 4 and mx < x + name_area - lw - 10 and my >= y and my < y + fh
    and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows()) and not ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId())
  local acol = on_arrow and COL.TEXT_MAIN or COL.TEXT_DIM
  if R.song_sel and R.song_sel[key] then -- (a selected song: a light blue tint)
    ImGui.DrawList_AddRectFilled(dl, x - 6, y - 2, x + aw - 8, y + fh + 2, COL.ACTIVE_BG, 4)
  end
  local cx, cy = x + 5, y + fh / 2
  if sc_open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, acol)
  else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, acol) end
  ImGui.DrawList_AddText(dl, x + 12, ty, acol, tostring(i))
  if on_arrow then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
    ImGui.SetTooltip(ctx, (sc_open and "Close the Scene list of this song." or "Open the Scene list of this song.")
      .. "\nCtrl+click: select songs, to give them 1 Preset together. Shift+click: select a range.")
    if ImGui.IsMouseClicked(ctx, 0) then
      local mods = ImGui.GetKeyMods(ctx)
      if mods & ImGui.Mod_Ctrl() ~= 0 then -- select / unselect this song
        R.song_sel = R.song_sel or {}
        R.song_sel[key] = not R.song_sel[key] or nil
        R.sel_anchor = i
      elseif mods & ImGui.Mod_Shift() ~= 0 and R.sel_anchor then -- select the songs from the last one to this one
        R.song_sel = R.song_sel or {}
        for j = math.min(R.sel_anchor, i), math.max(R.sel_anchor, i) do
          local x2 = R.regions[j]
          if x2 then R.song_sel[string.format("%.3f", x2.start)] = true end
        end
      else
        R.song_sel, R.sel_anchor = nil, nil
        R.sc_open = R.sc_open or {}; R.sc_open[key] = not sc_open or nil
      end
    end
  end
  ImGui.PushFont(ctx, bold)
  local title = UI.trunc(rg.name ~= "" and rg.name or "(unnamed region)", math.max(20, name_area - 30 - lw - 16))
  ImGui.PopFont(ctx)
  ImGui.DrawList_AddTextEx(dl, bold, CFG.FONT_SIZE, x + 30, ty, on_arrow and COL.TEXT_BRIGHT or COL.TEXT_MAIN, title)
  ImGui.DrawList_AddText(dl, x + name_area - lw - 6, ty, COL.TEXT_DIM, len)
  if narrow then ImGui.SetCursorPosX(ctx, math.max(ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosX(ctx) + aw - right_w))
  else ImGui.SameLine(ctx, 0, 8) end
  -- the preset: its own change, else the preset that goes on from before (grey)
  local preview, inherited
  if ch then preview = Preset.text(d, ch.folder, ch.index)
  else
    local a = Midi.active_at(d, rg.start)
    if a then preview, inherited = "(" .. Preset.text(d, a.folder, a.index) .. ")", true else preview = "None" end
  end
  -- quiet: the dropdown has its frame, and the send and remove buttons show, only on the row under the mouse
  -- (R.row_hov: from the last frame)
  local loud = (R.row_hov == i) or ImGui.IsPopupOpen(ctx, "##preset")
  ImGui.SetNextItemWidth(ctx, pw)
  if inherited then ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.TEXT_DIM) end
  if not loud then
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
  end
  local open = ImGui.BeginCombo(ctx, "##preset", preview)
  if not loud then ImGui.PopStyleColor(ctx, 2) end
  if inherited then ImGui.PopStyleColor(ctx) end
  if open then
    if ImGui.Selectable(ctx, "None##none", ch == nil) and ch then UI.set_preset(d, rg, nil) end
    for k, it in ipairs(UI.pick_items(d)) do
      if ImGui.Selectable(ctx, it.text .. "##pi" .. k, ch ~= nil and ch.folder == it.folder and ch.index == it.index) then
        UI.set_preset(d, rg, it.folder, it.index)
      end
    end
    if ImGui.Selectable(ctx, "Choose by number...##num") then
      local m = MODELS[d.model]
      local base = ch or Midi.active_at(d, rg.start)
      local idx = base and base.index or 0
      R.pick = { d = d, rg = rg, folder = base and base.folder or m.def_folder, bank = idx // #m.letters + 1,
        letter = idx % #m.letters + 1, open = true }
    end
    ImGui.EndCombo(ctx)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, ch and ("This song's Preset change, at " .. Util.fmt_beats(ch.t) .. ".")
      or (inherited and "This song has no Preset change, so the Preset before it keeps playing (grey).\nChoose a Preset to give the song its own."
      or "No Preset yet. Choose one, or 'Choose by number...' for a Preset without a name."))
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local cur = ch or Midi.active_at(d, rg.start)
  if loud then
    ImGui.BeginDisabled(ctx, cur == nil)
    if UI.icon_button("send", "send", fh) and cur then
      if not Midi.send_now(d, cur.folder, cur.index) then UI.toast(d.name .. ": the MIDI output is not available.", true) end
    end
    ImGui.EndDisabled(ctx)
    UI.tip("Send this Preset to the unit now (to hear it).")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.BeginDisabled(ctx, ch == nil)
    if UI.remove_x_button("##rmpc", fh) and ch then UI.set_preset(d, rg, nil) end
    ImGui.EndDisabled(ctx)
    UI.tip("Remove this song's Preset change (the Preset before it keeps playing).")
  else
    ImGui.Dummy(ctx, 2 * fh + CFG.CTRL_GAP, fh) -- (their place, so nothing moves)
  end
  -- the row under the mouse (for the next frame): its title line and its strip
  do
    local mx2, my2 = ImGui.GetMousePos(ctx)
    local sh = S.show_strip and (CFG.STRIP_H + CFG.SP_ROW) or 0
    local over = mx2 >= x - 4 and mx2 < x + aw and my2 >= y - 4 and my2 < y + fh + sh + 4
      and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows() | ImGui.HoveredFlags_AllowWhenBlockedByActiveItem())
    -- (while a button of the row is pressed it stays: else the button goes away before the click ends)
    if ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId()) then -- (a dropdown over the rows: no change)
    elseif over then R.row_hov = i elseif R.row_hov == i and not ImGui.IsMouseDown(ctx, 0) then R.row_hov = nil end
  end
  local row_w = narrow and (aw - 14) or (name_area + 8 + right_w) -- (the strip ends where the row's last button ends)
  if S.show_strip then UI.draw_scene_strip(d, rg, x + 30, math.max(60, row_w - 30)) end
  if sc_open then
    -- a card: a darker rounded background with a border behind the list (its height: from the last frame), and a
    -- gap after it
    UI.vgap(CFG.SP_ROW + 6)
    local lw = math.max(60, row_w - 30)
    local _, cy0 = ImGui.GetCursorScreenPos(ctx)
    R.card_h = R.card_h or {}
    local chh = R.card_h[key]
    if chh then
      local cdl = ImGui.GetWindowDrawList(ctx)
      ImGui.DrawList_AddRectFilled(cdl, x + 30 - 10, cy0 - 8, x + 30 + lw + 10, cy0 + chh + 4, COL.CARD_BG, 8)
      ImGui.DrawList_AddRect(cdl, x + 30 - 10, cy0 - 8, x + 30 + lw + 10, cy0 + chh + 4, COL.LINE, 8, 0, 1)
    end
    UI.draw_scene_list(d, rg, x + 30, lw)
    R.card_h[key] = select(2, ImGui.GetCursorScreenPos(ctx)) - cy0
    UI.vgap(CFG.SP_ROW + 4)
  end
  ImGui.PopID(ctx)
end

-- The label of a strip block that fits in avail px: the full text, else the short one (for example "BI"), else nil
-- (only the colour; the tooltip names the scene).
function UI.fit_label(full, short, avail)
  if (ImGui.CalcTextSize(ctx, full)) <= avail then return full end
  if short and (ImGui.CalcTextSize(ctx, short)) <= avail then return short end
  return nil
end

-- The scene strip of a song (a view): 1 block for each scene, from the song start to its end, with the scene
-- names of the preset there. A click on a block moves the edit cursor to its start.
function UI.draw_scene_strip(d, rg, sx, w)
  local h = CFG.STRIP_H
  ImGui.SetCursorScreenPos(ctx, sx, select(2, ImGui.GetCursorScreenPos(ctx)))
  local _, sy = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##strip", w, h)
  local hov = ImGui.IsItemHovered(ctx)
  local clicked = ImGui.IsItemClicked(ctx, 0)
  local dl = ImGui.GetWindowDrawList(ctx)
  local len = math.max(0.001, rg.stop - rg.start)
  local list = Midi.song_scenes(d, rg)
  local st = Midi.start_scene(d, rg)
  local function xt(t) return sx + Util.clamp((t - rg.start) / len, 0, 1) * w end
  -- the blocks: { t0, t1, v (nil: no scene change yet), ev }; the start scene is drawn from the song start
  -- (it can come a moment later, after the song's preset change)
  local tests = Midi.song_tests(d, rg).of
  local blocks, t0, v, ev = {}, rg.start, nil, nil
  local skip
  for _, s in ipairs(list) do
    local g = tests[s]
    if g and g == skip then
      -- (inside a scene test: drawn as 1 block)
    else
      local ts = (s == st) and rg.start or s.t
      if ts > t0 + 0.0001 then blocks[#blocks + 1] = { t0 = t0, t1 = ts, v = v, ev = ev } end
      if g then
        blocks[#blocks + 1] = { t0 = math.max(ts, rg.start), t1 = g.t1, test = g }
        skip, t0, v, ev = g, g.t1, 0, nil -- (its last change, the first scene, is the test's: no menu)
      else
        t0, v, ev = math.max(ts, rg.start), s.v, s
      end
    end
  end
  if rg.stop > t0 + 0.0001 then blocks[#blocks + 1] = { t0 = t0, t1 = rg.stop, v = v, ev = ev } end
  ImGui.DrawList_AddRectFilled(dl, sx, sy, sx + w, sy + h, COL.FIELD, 5)
  local mx = ImGui.GetMousePos(ctx)
  local hb
  -- the active block: the scene that plays at the play position (stopped: at the edit cursor)
  local tcur = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
  for _, bl in ipairs(blocks) do
    local x0, x1 = xt(bl.t0), xt(bl.t1)
    local act = tcur >= bl.t0 - CFG.EDGE and tcur < bl.t1 - CFG.EDGE
    if bl.test then
      ImGui.DrawList_AddRectFilled(dl, x0 + 1, sy + 1, x1 - 1, sy + h - 1, UI.sc_col("test", act), 4)
      local label = UI.fit_label("Scene test", "Test", x1 - x0 - 8)
      if label then
        ImGui.DrawList_PushClipRect(dl, x0 + 3, sy, x1 - 3, sy + h, true)
        local tw = ImGui.CalcTextSize(ctx, label)
        ImGui.DrawList_AddText(dl, math.max(x0 + 5, math.floor((x0 + x1 - tw) / 2)),
          math.floor(sy + h / 2 - ImGui.GetFontSize(ctx) * CFG.TEXT_MID + 0.5), UI.sc_text("test", act), label)
        ImGui.DrawList_PopClipRect(dl)
      end
    elseif bl.v then
      local pc = Midi.preset_at(d, rg, bl.t0)
      local ci = Preset.scene_col(d, pc and pc.folder, pc and pc.index or 0, bl.v)
      ImGui.DrawList_AddRectFilled(dl, x0 + 1, sy + 1, x1 - 1, sy + h - 1, UI.sc_col(ci, act), 4)
      local label = UI.fit_label(Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, bl.v),
        Midi.scene_short(d, bl.v), x1 - x0 - 8)
      if label then
        ImGui.DrawList_PushClipRect(dl, x0 + 3, sy, x1 - 3, sy + h, true)
        local tw = ImGui.CalcTextSize(ctx, label)
        -- the middle of the capitals on the middle of the block (CFG.TEXT_MID: measured, as in Chart Cue)
        ImGui.DrawList_AddText(dl, math.max(x0 + 5, math.floor((x0 + x1 - tw) / 2)),
          math.floor(sy + h / 2 - ImGui.GetFontSize(ctx) * CFG.TEXT_MID + 0.5), UI.sc_text(ci, act), label)
        ImGui.DrawList_PopClipRect(dl)
      end
    end
    if act and S.theme == "light" and (bl.v or bl.test) then
      ImGui.DrawList_AddRect(dl, x0 + 1, sy + 1, x1 - 1, sy + h - 1, COL.ACCENT, 4, 0, 2.5)
    end
    if hov and mx >= x0 and mx < x1 then
      hb = bl
      ImGui.DrawList_AddRect(dl, x0 + 1, sy + 1, x1 - 1, sy + h - 1, COL.WHITE, 4, 0, 1.5)
    end
  end
  for _, ch in ipairs(Midi.song_extra_pcs(d, rg)) do -- (a preset change inside the song: a thin line)
    local lx = math.floor(xt(ch.t)) + 0.5
    ImGui.DrawList_AddLine(dl, lx, sy - 3, lx, sy + h + 3, COL.TEXT_BRIGHT, 2)
  end
  if not hb then return end
  ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  local pc = Midi.preset_at(d, rg, hb.t0)
  if hb.test then
    ImGui.SetTooltip(ctx, "Scene test (" .. Util.fmt_song_time(rg, hb.t0) .. " to " .. Util.fmt_song_time(rg, hb.t1) .. "): "
      .. Midi.test_words(d) .. ", " .. CFG.TEST_BEATS .. " beats each.\nClick: the edit cursor goes here. Double-click: open REAPER's MIDI editor.\n"
      .. "Remove it with its red X in the Scene list.")
    if ImGui.IsMouseDoubleClicked(ctx, 0) then UI.open_midi(d, hb.t0, Midi.scc(d))
    elseif clicked then r.SetEditCurPos(hb.t0, true, false) end
    return
  end
  ImGui.SetTooltip(ctx, (hb.v and (Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, hb.v) .. "  (Scene "
    .. MODELS[d.model].scenes[hb.v + 1] .. ")  from " .. Util.fmt_song_time(rg, hb.t0)) or "No Scene change here.")
    .. "\nClick: the edit cursor goes here. Double-click: open REAPER's MIDI editor."
    .. (hb.ev and "\nRight-click: change or remove this Scene change." or ""))
  -- (the start scene: the song start, so the cursor is inside the song)
  local tb = hb.ev and math.max(hb.ev.t, rg.start) or hb.t0
  if ImGui.IsMouseDoubleClicked(ctx, 0) then UI.open_midi(d, tb, Midi.scc(d))
  elseif clicked then r.SetEditCurPos(tb, true, false) end
  if hb.ev and ImGui.IsItemClicked(ctx, 1) then R.scm = { d = d, rg = rg, ev = hb.ev, open = true } end
end

-- The right-click menu of a strip block (R.scm): change its scene, send it, remove it.
function UI.draw_scene_menu()
  if R.scm and R.scm.open then ImGui.OpenPopup(ctx, "##scmenu"); R.scm.open = false end -- (here: the ID of BeginPopup)
  if not ImGui.BeginPopup(ctx, "##scmenu") then return end
  local m = R.scm
  if m then
    local d, ev = m.d, m.ev
    local pc = Midi.preset_at(d, m.rg, ev.t)
    ImGui.TextDisabled(ctx, "Scene at " .. Util.fmt_song_time(m.rg, ev.t))
    for v = 0, Midi.nsc(d) - 1 do
      local nm = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v)
      if ImGui.Selectable(ctx, nm .. "##sm" .. v, ev.v == v) and ev.v ~= v then
        Midi.change_scene(d, ev, v); R.scm = nil
      end
    end
    ImGui.Separator(ctx)
    if ImGui.Selectable(ctx, "Send this Scene now##smsend") and not Midi.send_scene(d, ev.v) then
      UI.toast(d.name .. ": the MIDI output is not available.", true)
    end
    if ImGui.Selectable(ctx, "Remove this Scene change##smrm") then
      Midi.remove_scene(d, ev); R.scm = nil
    end
  end
  ImGui.EndPopup(ctx)
end

-- The scene list of a song (opened with the arrow of its row): the Start row (the start scene), then each scene
-- change: its time in the song, the scene, send, remove. "Add a scene at the edit cursor" adds one.
function UI.draw_scene_list(d, rg, x0, w)
  local fh = ImGui.GetFrameHeight(ctx)
  local gap = CFG.CTRL_GAP
  local list = Midi.song_scenes(d, rg)
  local st = Midi.start_scene(d, rg)
  local pcs = Midi.preset_at(d, rg, rg.start)
  local rows = {}
  if not st then rows[1] = { start = true } end -- (no start scene yet: the Start row only shows it)
  local tests = Midi.song_tests(d, rg).of
  local skip
  for _, s in ipairs(list) do
    local g = tests[s]
    if g then
      if g ~= skip then rows[#rows + 1] = { ev = s, test = g }; skip = g end
    else rows[#rows + 1] = { ev = s, start = (s == st) } end
  end
  local xpcs = Midi.song_extra_pcs(d, rg)
  if #xpcs > 0 then -- (the preset changes inside the song, in time order with the scenes; the Start row stays first)
    for _, ch in ipairs(xpcs) do rows[#rows + 1] = { pc = ch } end
    local function rt(row) return row.start and -math.huge or (row.pc and row.pc.t - 0.0001) or row.ev.t end
    table.sort(rows, function(a, b) return rt(a) < rt(b) end)
  end
  local pc_act -- (a change of a preset change row: { ch, t, folder, index } or { ch } to remove)
  -- the columns (from the left of the list): position, time, nudge, scene, then send and remove
  local C_POS, C_TIME, C_NUDGE = 0, 78, 150
  local C_SCENE = C_NUDGE + 2 * fh + 2 * gap
  local cw = math.max(80, math.min(220, w - C_SCENE - 2 * (fh + gap) - 20))
  local C_SEND = C_SCENE + cw + gap
  local C_X = C_SEND + fh + gap
  local row_w = C_X + fh
  -- the labels above the columns
  local hy = select(2, ImGui.GetCursorScreenPos(ctx))
  for _, hc in ipairs({ { C_POS, "Position" }, { C_TIME, "Time" }, { C_NUDGE, "Nudge" }, { C_SCENE, "Scene" } }) do
    ImGui.SetCursorScreenPos(ctx, x0 + hc[1], hy)
    ImGui.TextColored(ctx, COL.TEXT_DIM, hc[2])
  end
  local change, remove, movem, test_rm, test_mv
  ImGui.SetCursorScreenPos(ctx, x0, select(2, ImGui.GetCursorScreenPos(ctx)))
  local box = UI.begin_rows_box("##scbox", #rows, S.scene_rows, row_w + 8)
  local rx = (box and select(1, ImGui.GetCursorScreenPos(ctx)) or x0) + (box and 4 or 0)
  local function at(col, y) ImGui.SetCursorScreenPos(ctx, rx + col, y) end
  -- the current row: the last one at or before the edit cursor (during playback: the play position), in this song
  local tc = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
  local cur_n
  if tc >= rg.start - CFG.EDGE and tc < rg.stop - CFG.EDGE then
    for n, row in ipairs(rows) do
      local rt = row.start and rg.start or (row.ev and row.ev.t) or (row.pc and row.pc.t)
      if rt and rt <= tc + CFG.EDGE then cur_n = n end
    end
  end
  for n, row in ipairs(rows) do
    ImGui.PushID(ctx, n)
    local y = select(2, ImGui.GetCursorScreenPos(ctx))
    if row.pc then -- a preset change inside the song: position, time, nudge, the preset, send, remove
      local ch = row.pc
      local pkey = "pc" .. rg.start .. ":" .. n
      UI.pill_begin(pkey, rx, y, row_w, n == cur_n)
      at(C_POS, y)
      local key = string.format("%.4f", ch.t)
      local tb = UI.edit_time("pcb" .. key, 70, Util.fmt_beats(ch.t), Util.parse_beats, BEATS_TIP, true)
      at(C_TIME, y)
      local tt = UI.edit_time("pct" .. key, 64, Util.fmt_song_time(rg, ch.t),
        function(s) return Util.parse_song_time(rg, s) end, TIME_TIP)
      local tn = tb or tt
      if tb == false or tt == false then UI.toast("Type a time inside the song, before its end.", true)
      elseif tn then
        if tn < rg.start or tn >= rg.stop - CFG.EDGE then UI.toast("Type a time inside the song, before its end.", true)
        elseif math.abs(tn - ch.t) > 0.0005 then pc_act = { ch, tn, ch.folder, ch.index } end
      end
      at(C_NUDGE, y)
      local nd = UI.nudge_buttons("p", fh, "this Preset change")
      if nd then
        local nt = Midi.nudged(ch.t, nd)
        if nt < rg.start or nt >= rg.stop - CFG.EDGE then UI.toast("A nudge cannot move it out of the song.", true)
        else pc_act = { ch, nt, ch.folder, ch.index } end
      end
      at(C_SCENE, y)
      ImGui.SetNextItemWidth(ctx, cw)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.HEADING)
      local open = ImGui.BeginCombo(ctx, "##pcv", "Preset " .. Preset.text(d, ch.folder, ch.index))
      ImGui.PopStyleColor(ctx)
      if open then
        for k2, it in ipairs(UI.pick_items(d)) do
          if ImGui.Selectable(ctx, it.text .. "##xp" .. k2, it.folder == ch.folder and it.index == ch.index) then
            pc_act = { ch, ch.t, it.folder, it.index }
          end
        end
        if ImGui.Selectable(ctx, "Choose by number...##xpn") then
          local m = MODELS[d.model]
          R.pick = { d = d, rg = rg, folder = ch.folder, bank = ch.index // #m.letters + 1,
            letter = ch.index % #m.letters + 1, at = ch.t, old = ch, open = true }
        end
        ImGui.EndCombo(ctx)
      end
      UI.tip("A second Preset in this song, from " .. Util.fmt_beats(ch.t) .. ". The Scenes after it use its Scene names.")
      at(C_SEND, y)
      if UI.icon_button("pcs", "send", fh) and not Midi.send_now(d, ch.folder, ch.index) then
        UI.toast(d.name .. ": the MIDI output is not available.", true)
      end
      UI.tip("Send this Preset to the unit now (to hear it).")
      at(C_X, y)
      if UI.remove_x_button("##pcx", fh) then pc_act = { ch } end
      UI.tip("Remove this Preset change.")
      UI.pill_end(pkey, rx, y, row_w, ch.t, "this Preset change", d, 0)
      ImGui.PopID(ctx)
      goto next_row
    end
    do
    local ev = row.ev
    local t = ev and ev.t or Midi.start_time(d, rg)
    local pkey = "sc" .. rg.start .. ":" .. n
    UI.pill_begin(pkey, rx, y, row_w, n == cur_n)
    -- position and time: the start scene shows them (they cannot be changed: it marks the song start)
    at(C_POS, y)
    if row.start then
      local ps = Util.fmt_beats(math.max(t, rg.start))
      local cx0 = ImGui.GetCursorPosX(ctx)
      ImGui.SetCursorPosX(ctx, cx0 + 70 - 8 - (ImGui.CalcTextSize(ctx, ps)))
      UI.row_text(ps, COL.TEXT_DIM)
      UI.tip("The song's first Scene. It always stays at the song start; choose the Scene on the right.")
      at(C_TIME, y)
      UI.row_text(Util.fmt_song_time(rg, math.max(t, rg.start)), COL.TEXT_DIM)
      UI.tip("The song's first Scene, at the song start.")
    else
      local key = string.format("%.4f", ev.t)
      local tb = UI.edit_time("scb" .. key, 70, Util.fmt_beats(ev.t), Util.parse_beats, BEATS_TIP, true)
      at(C_TIME, y)
      local tt = UI.edit_time("sct" .. key, 64, Util.fmt_song_time(rg, ev.t),
        function(s) return Util.parse_song_time(rg, s) end, TIME_TIP)
      local tn = tb or tt
      if tb == false or tt == false then UI.toast("Type a time inside the song, before its end.", true)
      elseif tn then
        if tn < rg.start or tn >= rg.stop - CFG.EDGE then UI.toast("Type a time inside the song, before its end.", true)
        elseif math.abs(tn - ev.t) > 0.0005 then
          if row.test then test_mv = { g = row.test, t = tn } else movem = { ev = ev, t = tn } end
        end
      end
      -- nudge
      at(C_NUDGE, y)
      local nd = UI.nudge_buttons("s", fh, row.test and "the Scene test" or "this Scene change")
      if nd then
        local nt = Midi.nudged(ev.t, nd)
        if nt < rg.start or nt >= rg.stop - CFG.EDGE then UI.toast("A nudge cannot move it out of the song.", true)
        elseif row.test then test_mv = { g = row.test, t = nt }
        else movem = { ev = ev, t = nt } end
      end
    end
    at(C_SCENE, y)
    local pc = Midi.preset_at(d, rg, t) or pcs
    local cur = ev and ev.v
    if row.test then
      -- a scene test: 1 row, its name, no scene choice and no send; the red X removes the whole test
      ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.FIELD)
      ImGui.BeginDisabled(ctx, true)
      UI.button("Scene test##sctest", cw, fh)
      ImGui.EndDisabled(ctx)
      ImGui.PopStyleColor(ctx)
      UI.tip("Scene test: " .. Midi.test_words(d) .. ", " .. CFG.TEST_BEATS .. " beats each.\nType a new position to move it.")
    else
      ImGui.SetNextItemWidth(ctx, cw)
      local preview = cur and Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, cur)
        or ("(" .. Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, Midi.default_start(d, pc)) .. ")")
      if not cur then ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.TEXT_DIM) end
      local open = ImGui.BeginCombo(ctx, "##scv", preview)
      if not cur then ImGui.PopStyleColor(ctx) end
      if open then
        for v = 0, Midi.nsc(d) - 1 do
          local nm = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v)
          if Preset.has_scene_name(d, pc and pc.folder, pc and pc.index or 0, v) then nm = nm .. "  (" .. MODELS[d.model].scenes[v + 1] .. ")" end
          if ImGui.Selectable(ctx, nm .. "##v" .. v, cur == v) then change = { ev = ev, t = t, v = v } end
        end
        ImGui.EndCombo(ctx)
      end
      UI.tip(row.start and not ev and "No first Scene yet. Choose one here, or click Set up songs." or "The Scene that plays from here.")
      at(C_SEND, y)
      local sv = cur or Midi.default_start(d, pc)
      if UI.icon_button("scs", "send", fh) and not Midi.send_scene(d, sv) then UI.toast(d.name .. ": the MIDI output is not available.", true) end
      UI.tip("Send this Scene to the unit now (to hear it).")
    end
    at(C_X, y)
    ImGui.BeginDisabled(ctx, ev == nil)
    if UI.remove_x_button("##scx", fh) and ev then
      if row.test then test_rm = row.test else remove = ev end
    end
    ImGui.EndDisabled(ctx)
    UI.tip(row.test and "Remove this Scene test (all its Scene changes)." or "Remove this Scene change.")
    UI.pill_end(pkey, rx, y, row_w, row.start and rg.start or t,
      row.start and "the song start" or (row.test and "the Scene test" or "this Scene change"), d, Midi.scc(d))
    ImGui.PopID(ctx)
    end
    ::next_row::
  end
  if box then ImGui.EndChild(ctx) end
  -- the bottom row: the song nudge (under the nudge column), add at the edit cursor, clear
  local by = select(2, ImGui.GetCursorScreenPos(ctx))
  ImGui.SetCursorScreenPos(ctx, x0 + C_POS, by)
  UI.row_text("Song", COL.TEXT_DIM)
  UI.tip("Move all Scene changes and pedal values of this song (not the first Scene) a little earlier or later.")
  ImGui.SetCursorScreenPos(ctx, x0 + C_NUDGE, by)
  local snd = UI.nudge_buttons("song", fh, "all Scene changes (not the start Scene) and knob values of this song")
  if snd and not Midi.nudge_song(d, rg, snd) then UI.toast("A nudge cannot move a change out of the song (or before its start Scene).", true) end
  ImGui.SetCursorScreenPos(ctx, x0 + C_SCENE, by)
  ImGui.SetNextItemWidth(ctx, UI.cell_w("Add Scene at edit cursor", CFG.W_M))
  if ImGui.BeginCombo(ctx, "##scadd", "Add Scene at edit cursor", ImGui.ComboFlags_HeightLargest()) then
    local tc = Util.add_pos()
    local pc = Midi.preset_at(d, rg, tc) or pcs
    for v = 0, Midi.nsc(d) - 1 do
      local nm = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v)
      if ImGui.Selectable(ctx, nm .. "##a" .. v) then
        local ts = UI.cursor_in_song(rg, tc)
        if ts then Midi.add_scene(d, Midi.other_time("sc", ts), v) end
      end
    end
    ImGui.Separator(ctx)
    if ImGui.Selectable(ctx, "Scene test##atest") then
      local ts = UI.cursor_in_song(rg, tc)
      local tend = ts and Midi.add_test(d, rg, ts)
      if tend then
        r.SetEditCurPos(tend, true, false) -- (the edit cursor goes to the test end, to add the next scene there)
      elseif ts then
        UI.toast("No room for a Scene test here: it needs " .. (#Midi.test_seq(d) * CFG.TEST_BEATS) .. " beats before the song end.", true)
      end
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Scene test: " .. Midi.test_words(d) .. ", " .. CFG.TEST_BEATS
        .. " beats each, from the edit cursor.\nIt replaces the Scene changes in that part of the song.")
    end
    ImGui.Separator(ctx)
    if ImGui.Selectable(ctx, "Preset change...##apc") then
      local ts = UI.cursor_in_song(rg, tc)
      if ts then
        local m = MODELS[d.model]
        local base = Midi.preset_at(d, rg, ts)
        local idx = base and base.index or 0
        R.pick = { d = d, rg = rg, folder = base and base.folder or m.def_folder, bank = idx // #m.letters + 1,
          letter = idx % #m.letters + 1, at = ts, open = true }
      end
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Add a second Preset in this song, at the edit cursor.\nThe song row keeps the song's own Preset.")
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Place REAPER's edit cursor where the Scene must change, then choose the Scene.")
  ImGui.SameLine(ctx, 0, gap)
  ImGui.BeginDisabled(ctx, #list == 0)
  if UI.button("Clear Scenes", UI.btn_w("Clear Scenes", 0) + 16) then
    UI.toast(string.format("%d Scene change(s) removed from '%s'.", Midi.clear(d, rg), rg.name))
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Remove all Scene changes of this song. Ctrl+Z brings them back.")
  if change then
    if change.ev then Midi.change_scene(d, change.ev, change.v) else Midi.add_scene(d, change.t, change.v) end
  end
  if remove then Midi.remove_scene(d, remove) end
  if test_rm then Midi.remove_test(d, rg, test_rm) end
  if test_mv and not Midi.remove_test(d, rg, test_mv.g, test_mv.t) then
    UI.toast("No room for the Scene test there: it needs " .. (#Midi.test_seq(d) * CFG.TEST_BEATS) .. " beats before the song end.", true)
  end
  if movem then Midi.move_scene(d, movem.ev, movem.t) end
  if pc_act then Midi.put_pc(d, pc_act[2], pc_act[3], pc_act[4], pc_act[1]) end
end

-- The edit cursor (or the play position) for a new scene in a song, exactly (never snapped again: REAPER's own
-- snap already placed the edit cursor, and the grid on the screen changes with the zoom). Nil, with a notice,
-- when it is not inside the song.
function UI.cursor_in_song(rg, tc)
  if tc < rg.start - CFG.EDGE or tc >= rg.stop then
    UI.toast("Put the edit cursor inside '" .. rg.name .. "'.", true)
    return nil
  end
  return tc
end

-- Songs: the regions of the project, each with its preset, its scene strip and (opened) its scene list.
-- Songs > Getting started: the first steps, each ticked when it is done (or skipped); it goes away when all are
-- done, or with its X (saved on this computer).
local START_STEPS = { "Add your unit", "Choose its MIDI output", "Create its track", "Make a region for each song",
  "Name your Presets (optional)", "Set up songs" }
function UI.draw_start()
  if S.start_hide then return end
  local d = S.devices[Util.clamp(R.cur_dev or 1, 1, math.max(1, #S.devices))]
  local tr = d and Dev.track(d)
  local done = { #S.devices > 0, d and d.port ~= "", tr ~= nil, #R.regions > 0,
    d and next(S.lib[d.id] or {}) ~= nil, R.status and R.status.setup_done == true }
  local all = true
  for i = 1, #START_STEPS do if not (done[i] or S.start_skip[i]) then all = false end end
  if all then return end
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
  UI.heading("Getting started", "The first steps to prepare a show with MIDI Pilot. A step gets a tick when it is "
    .. "done. Skip: a step that you do not need.\nThe list goes away when every step is done or skipped. The X hides it "
    .. "now.\n\nSaved on this computer.")
  local after_y = select(2, ImGui.GetCursorScreenPos(ctx))
  local fh = ImGui.GetFrameHeight(ctx)
  ImGui.SetCursorScreenPos(ctx, sx + full - CFG.HELP_ICON - 10 - fh, sy + CFG.SP_TITLE_BEFORE)
  if UI.remove_x_button("##starthide", fh) then S.start_hide = true; Util.mark_sdirty() end
  UI.tip("Hide this list (Settings > General > Show Getting started brings it back).")
  ImGui.SetCursorScreenPos(ctx, sx, after_y)
  local dl = ImGui.GetWindowDrawList(ctx)
  -- 2 button columns after the longest step (the same x on every row): the action, then Skip
  if not R.start_lw then
    R.start_lw = 0
    for i, label in ipairs(START_STEPS) do R.start_lw = math.max(R.start_lw, (ImGui.CalcTextSize(ctx, i .. "  " .. label))) end
  end
  local AW = UI.std_w("Open Settings")
  local AX = ImGui.GetCursorPosX(ctx) + (fh - 8) + 10 + R.start_lw + 2 * CFG.CTRL_GAP
  local SX = AX + AW + CFG.CTRL_GAP
  local SW = UI.std_w("Skip")
  for i, label in ipairs(START_STEPS) do
    ImGui.PushID(ctx, "start" .. i)
    local ok, skip = done[i], S.start_skip[i] and not done[i]
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local b = fh - 8
    local bx, by = x + 2, y + 4
    if ok then
      ImGui.DrawList_AddRectFilled(dl, bx, by, bx + b, by + b, COL.GREEN, 3)
      ImGui.DrawList_AddLine(dl, bx + 3, by + b / 2, bx + b / 2 - 1, by + b - 4, COL.TEXT_BRIGHT, 2)
      ImGui.DrawList_AddLine(dl, bx + b / 2 - 1, by + b - 4, bx + b - 3, by + 3, COL.TEXT_BRIGHT, 2)
    else ImGui.DrawList_AddRect(dl, bx, by, bx + b, by + b, skip and COL.TEXT_DIM or COL.TEXT_MAIN, 3, 0, 1.5) end
    ImGui.Dummy(ctx, b + 6, fh)
    ImGui.SameLine(ctx, 0, 4)
    UI.row_text(i .. "  " .. label .. (skip and "  (skipped)" or ""), (ok or skip) and COL.TEXT_DIM or COL.TEXT_MAIN)
    if not ok and not skip then
      ImGui.SameLine(ctx, AX)
      if i == 1 or i == 2 then
        if UI.button("Open Settings", AW) then S.tab = TAB_SETTINGS; S.settings_open = 1; Util.mark_sdirty() end
        UI.tip("Settings > Devices: " .. (i == 1 and "Add device." or "the MIDI output of the device."))
      elseif i == 3 and d then
        if UI.button("Create track##start", AW) then Dev.create_track(d) end
        UI.tip("Creates the track of " .. d.name .. " in this project. MIDI Pilot writes its MIDI there.")
      elseif i == 5 then
        if UI.button("Open Presets", AW) then S.tab_hide[3] = nil; S.tab = 3; Util.mark_sdirty() end
        UI.tip("The Presets tab: give your Presets names (for example 3B = Song One).")
      elseif i == 6 and d and tr then
        if UI.button("Set up songs##start", AW) then
          local n = Midi.fill_starts(d)
          R.status = nil
          UI.toast(n == 0 and "Every song has its Preset and start Scene." or string.format("%d change(s) added.", n))
        end
        UI.tip("Gives each song its Preset and first Scene. Ctrl+Z takes it back.")
      else ImGui.Dummy(ctx, AW, fh) end
      ImGui.SameLine(ctx, SX)
      if UI.button("Skip", SW) then S.start_skip[i] = true; Util.mark_sdirty() end
      UI.tip("Skip this step: it counts as done.")
      if i == 4 then
        ImGui.SameLine(ctx, 0, 2 * CFG.CTRL_GAP)
        UI.row_text("REAPER: select the song's time, then Shift+R.", COL.TEXT_DIM)
      end
    end
    ImGui.PopID(ctx)
  end
  UI.vgap(6)
end
function UI.draw_songs_tab()
  UI.draw_start()
  if UI.no_device_hint() then return end
  local d = UI.device_picker()
  if not Dev.track(d) then
    UI.heading("Songs")
    UI.note(d.name .. " has no track in this project yet. Create it in Settings > Devices.", COL.YELLOW)
    if UI.button("Create track", UI.std_w("Create track"), nil, "primary") then Dev.create_track(d) end
    return
  end
  UI.heading(string.format("Songs (%d)", #R.regions), "Each region of the project is a song.\n\n"
    .. "The dropdown of a song sets its Preset. A grey Preset: the song has no Preset change of its own, so the "
    .. "Preset before it keeps playing.\n\nThe timeline under a song shows its Scenes. The arrow next to the song number "
    .. "opens its Scene list.")
  if #R.regions == 0 then
    UI.note("This project has no regions. Make 1 region for each song (Insert > Region from time selection).")
    return
  end
  -- the actions, centred: the main one (Set up songs), the automatic matches (Tools), the clear actions (Clear, red:
  -- they ask)
  local DDW = UI.cell_w("Clear", UI.std_w("Set up songs")) -- (the Tools and Clear dropdowns: their list is wider)
  local bar_w = UI.std_w("Set up songs") + 2 * (CFG.CTRL_GAP + DDW)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, math.floor((ImGui.GetContentRegionAvail(ctx) - bar_w) / 2)))
  if UI.button("Set up songs", UI.std_w("Set up songs"), nil, "primary") then
    local n = Midi.fill_starts(d)
    UI.toast(n == 0 and "Every song has its Preset and start Scene." or string.format("%d change(s) added.", n))
  end
  UI.tip("For each song:\n  - no Preset change: adds one, with the Preset that already plays there\n"
    .. "  - no first Scene: adds one\nThen playback can start at any song. Ctrl+Z takes it back.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, DDW)
  local tools_open = ImGui.BeginCombo(ctx, "##songtools", "Tools", ImGui.ComboFlags_HeightLargest())
  UI.tip("More actions: Presets and Scenes from names, markers from Scenes, merge, overview, export.")
  if tools_open then
    if ImGui.Selectable(ctx, "Presets from regions") then
      local n = Midi.match_names(d)
      UI.toast(n == 0 and "No song name has a Preset number or a Preset name." or string.format("%d song(s) matched.", n))
    end
    UI.tip("A song gets the Preset whose number is in its name ('Song One [3B]') or whose name it has (Presets tab).")
    if ImGui.Selectable(ctx, "Presets from markers") then
      local n = Midi.match_marker_presets(d)
      UI.toast(n == 0 and "No marker names a Preset ('P 3B' or 'P <Preset name>')." or string.format("%d Preset change(s) from markers.", n))
    end
    UI.tip("A marker inside a song named 'P 3B' or 'P <Preset name>' gets a Preset change at its place.")
    if ImGui.Selectable(ctx, "Scenes from markers") then
      local n = Midi.match_markers(d)
      UI.toast(n == 0 and "No marker matches a Scene name." or string.format("%d Scene change(s) from markers.", n))
    end
    UI.tip("A marker inside a song gets a Scene change when its name is a Scene name of the Preset there\n"
      .. "(for example 'Chorus') or a Scene letter (A, A-I ...).")
    if ImGui.Selectable(ctx, "Markers from Scenes") then
      local n = Midi.markers_from_scenes(d)
      UI.toast(n == 0 and "Every Scene change already has its marker." or string.format("%d marker(s) added.", n))
    end
    UI.tip("Adds a project marker with the Scene name at each Scene change (not in a Scene test).\n"
      .. "A marker that is already there is not added again. Ctrl+Z takes it back.")
    if ImGui.Selectable(ctx, "Merge repeated Scenes") then
      local n = Midi.merge_all(d)
      UI.toast(n == 0 and "No repeated Scenes to merge." or string.format("%d repeated Scene change(s) merged.", n))
    end
    UI.tip("Removes each Scene change that selects the Scene that already plays, so 2 equal blocks become 1.\n"
      .. "The first Scenes and Scene tests stay. Ctrl+Z brings them back.")
    ImGui.Separator(ctx)
    if ImGui.Selectable(ctx, "Show overview...") then R.ov = { d = d, open = true } end
    UI.tip("Every song in 1 list: its Preset, its Scenes in order, and its Lanes values.")
    if ImGui.Selectable(ctx, "Export MIDI...") then R.exp = { d = d, per_song = false, open = true } end
    UI.tip("Writes the MIDI of " .. d.name .. " as a standard MIDI file: 1 file for the show, or 1 file per song.")
    ImGui.Separator(ctx)
    if ImGui.Selectable(ctx, "Collapse all Scene lists") then R.sc_open = nil end
    UI.tip("Closes every open Scene list.")
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, DDW)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
  local clear_open = ImGui.BeginCombo(ctx, "##songclear", "Clear")
  ImGui.PopStyleColor(ctx)
  UI.tip("Remove all Scene changes or all Preset changes of " .. d.name .. " in this project (asks first).")
  if clear_open then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
    if ImGui.Selectable(ctx, "Clear all Scenes...") then
      UI.ask("Remove all Scene changes of " .. d.name .. " in this project? Ctrl+Z brings them back.", "Yes, clear",
        function() UI.toast(string.format("%d Scene change(s) removed.", Midi.clear(d))) end)
    end
    if ImGui.Selectable(ctx, "Clear all Presets...") then
      UI.ask("Remove all Preset changes of " .. d.name .. " in this project? The Scene changes stay. Ctrl+Z brings them back.",
        "Yes, clear", function() UI.toast(string.format("%d Preset change(s) removed.", Midi.clear(d, nil, true))) end)
    end
    ImGui.PopStyleColor(ctx)
    ImGui.EndCombo(ctx)
  end
  UI.vgap(4)
  local aw = ImGui.GetContentRegionAvail(ctx)
  for i, rg in ipairs(R.regions) do
    if i > 1 then -- a thin line between 2 songs, with space above and below it
      UI.vgap(7)
      local lx, ly = ImGui.GetCursorScreenPos(ctx)
      ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), lx, ly, lx + aw - 14, ly, COL.LINE, 1)
      UI.vgap(7)
    end
    UI.draw_song_row(d, i, rg, aw)
  end
  UI.draw_pick()
  UI.draw_scene_menu()
  UI.draw_overview()
end

-- "Show overview" (Songs > Tools): every song in 1 table: start, preset, its scenes in order (a preset change inside
-- the song in brackets), its Lanes values. A click on a song moves the edit cursor there.
function UI.draw_overview()
  local ov = R.ov
  if not ov then return end
  if ov.open then ImGui.OpenPopup(ctx, "Show overview##ov"); ov.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  ImGui.SetNextWindowSize(ctx, math.max(560, ww - 40), math.max(300, wh - 80), ImGui.Cond_Appearing())
  if not ImGui.BeginPopupModal(ctx, "Show overview##ov", true) then R.ov = nil; return end
  local d = ov.d
  ImGui.TextColored(ctx, COL.TEXT_DIM, d.name .. "  -  click a song to move the edit cursor there.")
  local tcur = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
  local flags = ImGui.TableFlags_RowBg() | ImGui.TableFlags_BordersInnerH() | ImGui.TableFlags_ScrollY() | ImGui.TableFlags_Resizable()
  local _, ah = ImGui.GetContentRegionAvail(ctx)
  if ImGui.BeginTable(ctx, "##ovt", 6, flags, 0, ah - ImGui.GetFrameHeightWithSpacing(ctx) - 4) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "#", ImGui.TableColumnFlags_WidthFixed(), 28)
    ImGui.TableSetupColumn(ctx, "Song", ImGui.TableColumnFlags_WidthStretch(), 1.2)
    ImGui.TableSetupColumn(ctx, "Start", ImGui.TableColumnFlags_WidthFixed(), 70)
    ImGui.TableSetupColumn(ctx, "Preset", ImGui.TableColumnFlags_WidthStretch(), 1.2)
    ImGui.TableSetupColumn(ctx, "Scenes", ImGui.TableColumnFlags_WidthStretch(), 2.5)
    ImGui.TableSetupColumn(ctx, "Lanes", ImGui.TableColumnFlags_WidthStretch(), 1.4)
    ImGui.TableHeadersRow(ctx)
    local cl = Knob.list(d)
    for i, rg in ipairs(R.regions) do
      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      local cur = tcur >= rg.start - CFG.EDGE and tcur < rg.stop - CFG.EDGE
      if ImGui.Selectable(ctx, i .. "##ovr" .. i, cur, ImGui.SelectableFlags_SpanAllColumns()) then
        r.SetEditCurPos(rg.start, true, false)
      end
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.Text(ctx, rg.name ~= "" and rg.name or "(unnamed region)")
      ImGui.TableSetColumnIndex(ctx, 2)
      ImGui.TextColored(ctx, COL.TEXT_DIM, Util.fmt_beats(rg.start))
      ImGui.TableSetColumnIndex(ctx, 3)
      local own = Midi.song_change(d, rg)
      local pa = own or Midi.active_at(d, rg.start)
      if own then ImGui.Text(ctx, Preset.text(d, own.folder, own.index))
      elseif pa then ImGui.TextColored(ctx, COL.TEXT_DIM, "(" .. Preset.text(d, pa.folder, pa.index) .. ")")
      else ImGui.TextColored(ctx, COL.TEXT_DIM, "None") end
      -- the scenes in order, with the preset changes inside the song in brackets
      ImGui.TableSetColumnIndex(ctx, 4)
      local items = {}
      for _, s in ipairs(Midi.song_scenes(d, rg)) do
        local pc = Midi.preset_at(d, rg, s.t)
        items[#items + 1] = { t = s.t, s = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, s.v) }
      end
      for _, c in ipairs(Midi.song_extra_pcs(d, rg)) do
        items[#items + 1] = { t = c.t - 0.0001, s = "[" .. Preset.plabel(d, c.index) .. "]" }
      end
      table.sort(items, function(a, b) return a.t < b.t end)
      local parts = {}
      for _, it in ipairs(items) do parts[#parts + 1] = it.s end
      local sc = #parts > 0 and table.concat(parts, "  >  ") or "-"
      ImGui.TextWrapped(ctx, sc)
      -- the Lanes values: each control with its number of values in the song
      ImGui.TableSetColumnIndex(ctx, 5)
      local lv = {}
      for _, k in ipairs(cl) do
        local n = 0
        for _, e in ipairs(Midi.ccs(d, k.cc)) do if e.t >= rg.start - CFG.EDGE and e.t < rg.stop - CFG.EDGE then n = n + 1 end end
        if n > 0 then lv[#lv + 1] = k.name .. " " .. n end
      end
      ImGui.TextWrapped(ctx, #lv > 0 and table.concat(lv, ", ") or "-")
    end
    ImGui.EndTable(ctx)
  end
  if UI.button("Close", UI.dlg_w("Close")) then R.ov = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- "Export MIDI" (Songs > Tools): 1 file for the show or 1 file per song, into "MIDI Pilot export" next to the project.
function UI.draw_export()
  local ex = R.exp
  if not ex then return end
  if ex.open then ImGui.OpenPopup(ctx, "Export MIDI##exp"); ex.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Export MIDI##exp", true, ImGui.WindowFlags_AlwaysAutoResize()) then R.exp = nil; return end
  local d = ex.d
  ImGui.PushTextWrapPos(ctx, 420)
  ImGui.Text(ctx, "The MIDI of " .. d.name .. " as a standard MIDI file, with the tempo map. A slope between 2 values "
    .. "is written as small steps.")
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  ImGui.SetNextItemWidth(ctx, UI.fit_w())
  local ch, v = ImGui.Combo(ctx, "##expmode", ex.per_song and 1 or 0, "1 file for the whole show\0001 file per song\0")
  if ch then ex.per_song = (v == 1); ex.done = nil end
  UI.tip("1 file per song: each file starts at 0:00 with the song's Preset and first Scene.")
  -- the folder: typed or pasted (used when you leave the field), Browse..., Default (saved in the project)
  local dir = Midi.export_dir()
  UI.vgap(6)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Folder")
  local BW2 = UI.dlg_w("Browse...")
  ImGui.SetNextItemWidth(ctx, 420 - 2 * (BW2 + CFG.CTRL_GAP))
  if ex.dir_text == nil or not ImGui.IsItemActive(ctx) and ex.dir_shown ~= dir then ex.dir_text, ex.dir_shown = dir or "", dir end
  local _, dt = ImGui.InputTextWithHint(ctx, "##expdir", "Save the project, or choose a folder", ex.dir_text)
  if ImGui.IsItemActive(ctx) then ex.dir_text = dt
  elseif ImGui.IsItemDeactivated(ctx) then Midi.set_export_dir(dt); ex.dir_text = nil end
  UI.tip("The folder of the files (saved in this project). Type or paste a path, or click Browse...")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local can_browse = r.JS_Dialog_BrowseForFolder ~= nil or r.GetOS():match("^Win") ~= nil
  ImGui.BeginDisabled(ctx, not can_browse)
  if UI.button("Browse...", BW2) then
    local f = Midi.browse_folder(dir)
    if f then Midi.set_export_dir(f); ex.dir_text = nil; ex.done = nil end
  end
  ImGui.EndDisabled(ctx)
  UI.tip(can_browse and "Choose the folder." or "Install js_ReaScriptAPI (ReaPack) for a folder window, or type the path.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, P.export_dir == "")
  if UI.button("Default", BW2) then Midi.set_export_dir(""); ex.dir_text = nil; ex.done = nil end
  ImGui.EndDisabled(ctx)
  UI.tip("Back to the default folder: \"MIDI Pilot export\" next to the project file.")
  dir = Midi.export_dir()
  ImGui.PushTextWrapPos(ctx, 420)
  if dir then ImGui.TextColored(ctx, COL.TEXT_DIM, (ex.per_song and ("1 file per song, in the subfolder '" .. safe_name(d.name) .. "'. ") or "")
    .. "Files with the same name are replaced.")
  else ImGui.TextColored(ctx, COL.YELLOW, "Save the project first, or choose a folder.") end
  if ex.done then ImGui.TextColored(ctx, ex.err and COL.RED or COL.GREEN, ex.done) end
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  ImGui.BeginDisabled(ctx, not dir or not Dev.track(d))
  if UI.button("Export", UI.dlg_w("Export"), nil, "primary") then
    local n, res = Midi.export(d, ex.per_song)
    if n then ex.done, ex.err, ex.dir = n .. " file(s) written.", nil, res
    else ex.done, ex.err = "Not written: " .. tostring(res), true end
  end
  ImGui.EndDisabled(ctx)
  if ex.dir then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Open the folder", UI.dlg_w("Open the folder")) then
      if r.CF_ShellExecute then r.CF_ShellExecute(ex.dir)
      elseif r.GetOS():match("^Win") then os.execute('explorer "' .. ex.dir:gsub("/", "\\") .. '"')
      else os.execute('open "' .. ex.dir .. '"') end
    end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Copy the path", UI.dlg_w("Copy the path")) then ImGui.SetClipboardText(ctx, ex.dir) end
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Close", UI.dlg_w("Close")) then R.exp = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

local SLOPE_W = 160 -- (the slope column of the Lanes value rows: set from its longest option)
-- What a pedal value moves in the preset that plays there: "->  Hi Pass 22%, Low Pass 66%", and its tooltip (the
-- ranges and notes). nil when the preset has no assignments for this pedal. Cached (R.expr_txt) until a change.
function UI.expr_text(d, rg, e, pd)
  local pc = Midi.preset_at(d, rg, e.t)
  if not pc then return nil end
  R.expr_txt = R.expr_txt or {}
  local key = d.id .. ":" .. pc.folder .. ":" .. pc.index .. ":" .. pd .. ":" .. e.v
  local c = R.expr_txt[key]
  if c then return c[1], c[2] end
  local list = Preset.expr(d, pc.folder, pc.index, pd)
  if #list == 0 then R.expr_txt[key] = { nil, nil }; return nil end
  local p = e.v / 127 * 100
  local parts, tips = {}, {}
  for _, a in ipairs(list) do
    local v = short_num(math.floor(Knob.assign_at(a, p) + 0.5))
    parts[#parts + 1] = a.name .. " " .. v .. "%"
    tips[#tips + 1] = a.name .. ": " .. v .. "% (its range " .. short_num(a.from) .. "-" .. short_num(a.to) .. "%)"
      .. ((a.note and a.note ~= "") and ("  -  " .. a.note) or "")
  end
  local txt = "->  " .. table.concat(parts, ", ")
  local tip = "In " .. Preset.text(d, pc.folder, pc.index) .. ", pedal " .. pd .. " at " .. short_num(math.floor(p + 0.5))
    .. "% moves:\n" .. table.concat(tips, "\n")
  R.expr_txt[key] = { txt, tip }
  return txt, tip
end
-- Lanes: the knobs of a device (a CC in the units of a knob of the unit), and the values of 1 knob in the song
-- at the edit cursor (add, change, remove, send).
local NO_ROWS = {} -- (a closed Values section: no songs to draw)
-- The rows of a song's values (cached with the MIDI and the open groups): { n } a value, { grp } a group (1 row),
-- { n, member } a value of an open group.
function UI.lane_rows(g, cc)
  R.gopen, R.gopen_v = R.gopen or {}, R.gopen_v or 0
  if g.rows and g.rows_v == R.gopen_v then return g.rows end
  g.fg = g.fg or Midi.find_groups(g.list)
  local rows, gi, n = {}, 1, 1
  while n <= #g.list do
    local G = g.fg[gi]
    if G and G.i0 == n then
      G.key = G.key or string.format("kg%d:%.4f", cc, g.list[n].t)
      rows[#rows + 1] = { grp = G }
      if R.gopen[G.key] then for m = G.i0, G.i1 do rows[#rows + 1] = { n = m, member = true } end end
      n, gi = G.i1 + 1, gi + 1
    else
      rows[#rows + 1] = { n = n }
      n = n + 1
    end
  end
  g.rows, g.rows_v = rows, R.gopen_v
  return rows
end
function UI.draw_lanes_tab()
  if UI.no_device_hint() then return end
  local d = UI.device_picker()
  local knobs = S.knobs[d.id] or Knob.parse("")
  S.knobs[d.id] = knobs
  local fh = ImGui.GetFrameHeight(ctx)
  if not MODELS[d.model].line6 then
    local cl = Knob.list(d)
    local popen = UI.heading("Expression pedals", "Your Quad Cortex has 2 expression pedals (CC#1 and CC#2). A value is the pedal "
      .. "position: 0% heel, 100% toe.\n\nWhat a pedal moves is set for each Preset: Presets tab > the pedal icon.\n\n"
      .. "The unit's other MIDI functions are in the Control list below. The names are saved on this computer.", nil, nil, "pedals")
    for pd = 1, popen and 2 or 0 do
      local k = cl[pd]
      ImGui.PushID(ctx, "ped" .. pd)
      UI.row_start("CC#" .. pd)
      ImGui.SetNextItemWidth(ctx, 160)
      local chn, nm = ImGui.InputText(ctx, "##pn", k.name)
      if chn then k.name = Util.clean(nm); Util.mark_sdirty() end
      UI.tip("The name of expression pedal " .. pd .. ", for example Wah or Volume.")
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      UI.row_text("Pedal position, 0-100%", COL.TEXT_DIM)
      ImGui.PopID(ctx)
    end
  end
  local cl = Knob.list(d)
  if MODELS[d.model].line6 then
  UI.heading(string.format("Controls (%d)", #knobs), "Add 1 control for each CC that you assigned on the unit. "
    .. "Enter the range that you set on the unit (heel = Min, toe = Max) and its unit: MIDI Pilot then shows the values "
    .. "in that unit (650 Hz instead of CC 97).\n\nA CC has 128 steps, so MIDI Pilot writes the nearest step. "
    .. "Saved on this computer, for this device.", nil, nil, "pedals")
  if S.lanes_open.pedals then
  local rm
  -- the columns: CC, name, min, max, unit (the labels above them)
  local x0 = ImGui.GetCursorPosX(ctx)
  local CW = { CFG.W_INT, 160, 90, 90, 90 }
  local cols = {}
  local cx = x0
  for i, w in ipairs(CW) do cols[i] = cx; cx = cx + w + CFG.CTRL_GAP end
  local heads = { "CC", "Name", "Min (heel)", "Max (toe)", "Unit" }
  for i, hname in ipairs(heads) do
    if i > 1 then ImGui.SameLine(ctx, cols[i]) else ImGui.SetCursorPosX(ctx, cols[1]) end
    ImGui.TextColored(ctx, COL.TEXT_DIM, hname)
  end
  for n, k in ipairs(knobs) do
    ImGui.PushID(ctx, n)
    ImGui.SetCursorPosX(ctx, cols[1])
    ImGui.SetNextItemWidth(ctx, CW[1])
    local ch, v = UI.input_int("##cc", k.cc, 1)
    if ch then k.cc = Util.clamp(v, 0, 127); Util.mark_sdirty(); R.pcs = {} end
    local res = MODELS[d.model].ccs[k.cc]
    UI.tip("The CC number." .. (res and ("\nCC#" .. k.cc .. " is the unit's " .. res .. " CC: it also does that.") or ""))
    ImGui.SameLine(ctx, cols[2])
    ImGui.SetNextItemWidth(ctx, CW[2])
    local ch2, nm = ImGui.InputText(ctx, "##kn", k.name)
    if ch2 then k.name = Util.clean(nm); Util.mark_sdirty() end
    UI.tip("The name of the control, for example Filter.")
    ImGui.SameLine(ctx, cols[3])
    ImGui.SetNextItemWidth(ctx, CW[3])
    local ch3, mn = ImGui.InputDouble(ctx, "##min", k.min, 0, 0, "%g")
    if ch3 then k.min = mn; Util.mark_sdirty() end
    UI.tip("Min: the value at the heel (CC 0).")
    ImGui.SameLine(ctx, cols[4])
    ImGui.SetNextItemWidth(ctx, CW[4])
    local ch4, mx = ImGui.InputDouble(ctx, "##max", k.max, 0, 0, "%g")
    if ch4 then k.max = mx; Util.mark_sdirty() end
    UI.tip("Max: the value at the toe (CC 127).")
    ImGui.SameLine(ctx, cols[5])
    ImGui.SetNextItemWidth(ctx, CW[5])
    local ui = 0
    for i, u in ipairs(KNOB_UNITS) do if u == k.unit then ui = i - 1 end end
    local ch5
    ch5, ui = ImGui.Combo(ctx, "##unit", ui, KNOB_UNIT_ITEMS)
    if ch5 then k.unit = KNOB_UNITS[ui + 1]; Util.mark_sdirty() end
    UI.tip("The unit of the value, as the unit shows it.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.remove_x_button("##krm", fh) then rm = n end
    UI.tip("Remove this control. Its MIDI stays in the project.")
    if res then
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      UI.warn_icon("##kw", fh)
      UI.tip("CC#" .. k.cc .. " is the unit's " .. res .. " CC: a value here also does that.")
    end
    ImGui.PopID(ctx)
  end
  if rm then table.remove(knobs, rm); Util.mark_sdirty(); R.lane_k = nil end
  if UI.button("Add control", UI.std_w("Add control")) then
    local used, cc = {}, 3
    for _, k in ipairs(knobs) do used[k.cc] = true end
    while used[cc] or MODELS[d.model].ccs[cc] do cc = cc + 1 end
    knobs[#knobs + 1] = { cc = Util.clamp(cc, 0, 127), name = "Control " .. (#knobs + 1), min = 0, max = 100, unit = "%" }
    Util.mark_sdirty()
  end
  UI.tip("Add a control on a free CC. Assign the same CC on the unit.")
  end
  end
  if #cl == 0 then return end
  knobs = cl

  -- the values of 1 knob in the song at the edit cursor (during playback: the play position; REAPER's snap: the grid)
  local tc = Util.add_pos()
  local rg = Midi.song_at(tc)
  R.lane_k = Util.clamp(R.lane_k or 1, 1, #knobs)
  local k = knobs[R.lane_k]
  local all = S.lane_all
  -- the controls with values in the song at the edit cursor (or in all songs): { [index] = count }, cached with the MIDI
  local ukey = "use" .. d.id .. ":" .. #knobs .. ":" .. (all and "*" or (rg and rg.start or "-"))
  local used = R.pcs[ukey]
  if not used then
    used = {}
    for i, x in ipairs(knobs) do
      local n = 0
      for _, e in ipairs(Midi.ccs(d, x.cc)) do
        if all then
          for _, g in ipairs(R.regions) do if e.t >= g.start - CFG.EDGE and e.t < g.stop - CFG.EDGE then n = n + 1; break end end
        elseif rg and e.t >= rg.start - CFG.EDGE and e.t < rg.stop - CFG.EDGE then n = n + 1 end
      end
      if n > 0 then used[i] = n end
    end
    R.pcs[ukey] = used
  end
  local vopen = UI.heading(all and "Values in all songs" or (rg and ("Values in " .. (rg.name ~= "" and rg.name or "(unnamed region)")) or "Values"),
    "The values of the selected control in the song at the edit cursor, or in all songs.\n\nPosition: bar.beat in "
    .. "the project. Time: from the song start.\nSlope: how the value moves to the next value. Jump: it changes at "
    .. "the next value; the others move smoothly.\n\nAn LFO, a swell or a ramp is 1 row: click its name to see its "
    .. "values. Its position and nudge move all of it; the copy icon copies it (paste: under the values).\n\nThe Control row also chooses the control for the Add sections. "
    .. "When this section is closed, they use the control that you chose last.", nil, nil, "values",
    (R.clip and not S.lanes_open.values) and "1 copied" or nil)
  if vopen then
  local _, cw = UI.row_start("Control")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  if ImGui.BeginCombo(ctx, "##lk", string.format("%s  (CC#%d)", k.name, k.cc), ImGui.ComboFlags_HeightLargest()) then
    for i, x in ipairs(knobs) do
      if i == 3 and x.kind then ImGui.Separator(ctx) end -- (Quad Cortex: the pedals, then the unit's functions)
      if ImGui.Selectable(ctx, string.format("     %s  (CC#%d)##k%d", x.name, x.cc, i), i == R.lane_k) then R.lane_k = i end
      if used[i] then -- (a blue dot, and the count at the right end)
        local ix0, iy0 = ImGui.GetItemRectMin(ctx)
        local ix1, iy1 = ImGui.GetItemRectMax(ctx)
        local idl = ImGui.GetWindowDrawList(ctx)
        ImGui.DrawList_AddCircleFilled(idl, ix0 + 8, (iy0 + iy1) / 2, 3.5, COL.ACCENT)
        local cs = tostring(used[i])
        local cw2 = ImGui.CalcTextSize(ctx, cs)
        ImGui.DrawList_AddText(idl, ix1 - cw2 - 6, iy0 + math.floor((iy1 - iy0 - ImGui.GetFontSize(ctx)) / 2), COL.TEXT_DIM, cs)
      end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Choose the control whose values you see. A blue dot: it has values " .. (all and "in the songs" or "in this song")
    .. " (the number shows how many).")
  ImGui.SameLine(ctx, 0, 16)
  local ach, av = UI.toggle_line("All songs", all, "On: the values of this control in every song. Off: only in the song at the edit cursor.")
  if ach then S.lane_all = av; all = av; Util.mark_sdirty() end
  end
  if not all and not rg then
    if vopen then UI.note("Put the edit cursor inside a song (region), or turn on 'All songs'.") end
    return
  end
  -- the songs to show, each with its values of this control
  -- (cached until the MIDI changes; a value up to CFG.EDGE before a song start belongs to that song)
  local ccs = Midi.ccs(d, k.cc)
  local gkey = "lg" .. d.id .. ":" .. k.cc .. ":" .. (all and "*" or (rg and rg.start or "-"))
  local groups = R.pcs[gkey]
  if not groups then
    groups = {}
    for _, g in ipairs(all and R.regions or { rg }) do
      local gl = {}
      for _, e in ipairs(ccs) do if e.t >= g.start - CFG.EDGE and e.t < g.stop - CFG.EDGE then gl[#gl + 1] = e end end
      if #gl > 0 or not all then groups[#groups + 1] = { rg = g, list = gl } end
    end
    R.pcs[gkey] = groups
  end
  local change, remove, shape, nudge, gmove, gremove
  local vx = ImGui.GetCursorPosX(ctx)
  -- the columns: position, time, nudge, value, slope (and its bend), then send and remove
  local gap = CFG.CTRL_GAP
  local NUD = vx + 150
  local VAL = NUD + 2 * fh + 2 * gap
  local SLO = VAL + 110 + gap
  SLOPE_W = UI.cell_w(UI.longest(CC_SHAPE_ITEMS)) + 24 -- (a table cell: as wide as its longest option, and its icon)
  local SND = SLO + SLOPE_W + gap -- (send and remove right after the slope; a Curve's bend goes after them)
  local VC = { vx, vx + 78, NUD, VAL, SLO, SND, SND + fh + gap }
  local any = false
  for _, g in ipairs(groups) do if #g.list > 0 then any = true end end
  -- the labels above the columns: in each song's section (under its title)
  local function col_labels()
    local vh = k.kind and { "Position", "Time", "Nudge", "Value" } or { "Position", "Time", "Nudge", "Value", "Slope to the next value" }
    for i, hname in ipairs(vh) do
      if i > 1 then ImGui.SameLine(ctx, VC[i]) else ImGui.SetCursorPosX(ctx, VC[1]) end
      ImGui.TextColored(ctx, COL.TEXT_DIM, hname)
    end
  end
  for gi, g in ipairs(vopen and groups or NO_ROWS) do
    local grg, list = g.rg, g.list
    local closed = false
    if all then -- the song name above its values, with an arrow: a click closes / opens the song
      local key = string.format("%.3f", grg.start)
      R.lane_closed = R.lane_closed or {}
      closed = R.lane_closed[key] == true
      ImGui.SetCursorPosX(ctx, VC[1])
      local x, y = ImGui.GetCursorScreenPos(ctx)
      local fh2 = ImGui.GetFrameHeight(ctx)
      local title = (grg.name ~= "" and grg.name or "(unnamed region)") .. "  (" .. #list .. ")"
      ImGui.PushFont(ctx, bold)
      local tw = ImGui.CalcTextSize(ctx, title)
      ImGui.InvisibleButton(ctx, "##lg" .. gi, 14 + tw, fh2)
      local hov = ImGui.IsItemHovered(ctx)
      local dl = ImGui.GetWindowDrawList(ctx)
      local col = hov and COL.TEXT_BRIGHT or (grg == rg and COL.ACCENT_HOVER or COL.TEXT_MAIN)
      local cx, cy = x + 4, y + fh2 / 2
      if closed then ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col)
      else ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col) end
      ImGui.DrawList_AddText(dl, x + 14, UI.text_y(y), col, title)
      ImGui.PopFont(ctx)
      if hov then
        ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
        ImGui.SetTooltip(ctx, (closed and "Open" or "Close") .. " the values of this song." .. (grg == rg and "\nThe song at the edit cursor." or ""))
      end
      if ImGui.IsItemClicked(ctx, 0) then R.lane_closed[key] = (not closed) or nil; closed = not closed end
    end
    if not closed and #list > 0 then col_labels() end
    -- a long list scrolls (Settings > Appearance > List sizes): the rows go in a child window; its columns start at its own left edge
    local rows = UI.lane_rows(g, k.cc)
    local scroll = not closed and #rows > S.lane_rows
    local VC, vx = VC, vx
    if scroll then
      local rh = ImGui.GetFrameHeightWithSpacing(ctx)
      ImGui.SetCursorPosX(ctx, vx)
      -- as wide as the rows (the slope, its bend and the red X), so its scrollbar is right after the X buttons;
      -- the scrollbar always shows, in a lighter colour than the page's
      local bw = (VC[7] - vx) + fh + gap + 110 + 44 -- (the bend of a Curve after the red X; the indent of a group; the pills)
      ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarBg(), COL.FIELD)
      ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrab(), COL.TOGGLE_OFF)
      local vis = ImGui.BeginChild(ctx, "##lscroll" .. gi, bw, S.lane_rows * rh + 4, 0,
        ImGui.WindowFlags_AlwaysVerticalScrollbar())
      ImGui.PopStyleColor(ctx, 2)
      if not vis then scroll = false; closed = true
      else
        local ox = ImGui.GetCursorPosX(ctx) - vx + 4
        local sh = {}
        for i2 = 1, 7 do sh[i2] = VC[i2] + ox end
        VC, vx = sh, vx + ox
      end
    end
    local tcur = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
    local cur_n
    if tcur >= grg.start - CFG.EDGE and tcur < grg.stop - CFG.EDGE then
      for n, e in ipairs(list) do if e.t <= tcur + CFG.EDGE then cur_n = n end end
    end
    R.vci = R.vci or {} -- (the values of an open group: indented)
    for i2 = 1, 7 do R.vci[i2] = VC[i2] + 18 end
    local VCI = R.vci
    for _, row in ipairs(closed and NO_ROWS or rows) do
      local G = row.grp
      if G then -- a group (an LFO, a swell or a ramp): 1 row; its triangle shows its values
        local e = list[G.i0]
        ImGui.PushID(ctx, "g" .. gi .. ":" .. G.i0)
        ImGui.SetCursorPosX(ctx, VC[1])
        local px, py = ImGui.GetCursorScreenPos(ctx)
        local pw = VC[7] - VC[1] + fh
        local word = G.kind == "lfo" and "LFO" or G.kind
        local aword = G.kind == "lfo" and "an LFO" or ("a " .. G.kind)
        UI.pill_begin(G.key, px, py, pw, cur_n and cur_n >= G.i0 and cur_n <= G.i1)
        local tb = UI.edit_time("gb" .. G.key, 70, Util.fmt_beats(e.t), Util.parse_beats, BEATS_TIP, true)
        ImGui.SameLine(ctx, VC[2])
        local tt = UI.edit_time("gt" .. G.key, 64, Util.fmt_song_time(grg, e.t),
          function(s) return Util.parse_song_time(grg, s) end, TIME_TIP)
        local tn = tb or tt
        if tb == false or tt == false then UI.toast("Type a time inside the song, before its end.", true)
        elseif tn and math.abs(tn - e.t) > 0.0005 then gmove = { G = G, list = list, rg = grg, t = tn } end
        ImGui.SameLine(ctx, VC[3])
        local nd = UI.nudge_buttons("g", fh, "this " .. word)
        if nd then gmove = { G = G, list = list, rg = grg, t = Midi.nudged(e.t, nd) } end
        ImGui.SameLine(ctx, VC[4])
        local open = R.gopen[G.key]
        local lw = VC[6] - VC[4] - gap
        local lab = Midi.group_label(G, k, list)
        local x, y = ImGui.GetCursorScreenPos(ctx)
        ImGui.InvisibleButton(ctx, "##gl", lw, fh)
        local hov = ImGui.IsItemHovered(ctx)
        if ImGui.IsItemClicked(ctx, 0) then R.gopen[G.key] = (not open) or nil; R.gopen_v = R.gopen_v + 1 end
        local dl = ImGui.GetWindowDrawList(ctx)
        local col = hov and COL.TEXT_BRIGHT or COL.TEXT_MAIN
        local cx, cy = x + 6, y + fh / 2
        if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col)
        else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col) end
        if G.kind == "lfo" then -- "LFO", the shape's icon, then the rest of the name
          local w1 = ImGui.CalcTextSize(ctx, "LFO")
          ImGui.DrawList_AddText(dl, x + 16, UI.text_y(y), col, "LFO")
          UI.wave(dl, x + 22 + w1, y + 5, 16, fh - 10, LFO_ICONS[G.shape + 1], col)
          ImGui.DrawList_AddText(dl, x + 44 + w1, UI.text_y(y), col, UI.trunc(G.lab2, lw - 46 - w1))
        else ImGui.DrawList_AddText(dl, x + 16, UI.text_y(y), col, UI.trunc(lab, lw - 18)) end
        if hov then
          ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
          ImGui.SetTooltip(ctx, lab .. " (" .. (G.i1 - G.i0 + 1) .. " values).\nClick to " .. (open and "hide" or "show") .. " its values.")
        end
        ImGui.SameLine(ctx, VC[6])
        if UI.icon_button("gc", "copy", fh) then
          R.clip = Midi.group_clip(list, G.i0, G.i1, lab)
          UI.toast("Copied: " .. lab .. ". 'Paste at edit cursor' is under the values.")
        end
        UI.tip("Copy this " .. word .. ". 'Paste at edit cursor' then shows under the values.")
        ImGui.SameLine(ctx, VC[7])
        if UI.remove_x_button("##gx", fh) then gremove = { G = G, list = list, word = aword } end
        UI.tip("Remove this " .. word .. " (all its values).")
        UI.pill_end(G.key, px, py, pw, e.t, "this " .. word, d, k.cc)
        ImGui.PopID(ctx)
      else
      local n = row.n
      local e = list[n]
      local C = row.member and VCI or VC
      ImGui.PushID(ctx, "v" .. gi .. ":" .. n)
      -- the pill of the row (a click moves the edit cursor there)
      ImGui.SetCursorPosX(ctx, C[1])
      local px, py = ImGui.GetCursorScreenPos(ctx)
      local pw = C[7] - C[1] + fh
      local pkey = "kv" .. k.cc .. ":" .. string.format("%.4f", e.t)
      UI.pill_begin(pkey, px, py, pw, n == cur_n)
      -- position and time (editable: a typed time moves the value)
      local key = string.format("k%d:%.4f", k.cc, e.t)
      local tb = UI.edit_time("kb" .. key, 70, Util.fmt_beats(e.t), Util.parse_beats, BEATS_TIP, true)
      ImGui.SameLine(ctx, C[2])
      local tt = UI.edit_time("kt" .. key, 64, Util.fmt_song_time(grg, e.t),
        function(s) return Util.parse_song_time(grg, s) end, TIME_TIP)
      local tn = tb or tt
      if tb == false or tt == false then UI.toast("Type a time inside the song, before its end.", true)
      elseif tn then
        if tn < grg.start or tn >= grg.stop - CFG.EDGE then UI.toast("Type a time inside the song, before its end.", true)
        elseif math.abs(tn - e.t) > 0.0005 then nudge = { e = e, t = tn } end
      end
      -- nudge
      ImGui.SameLine(ctx, C[3])
      local nd = UI.nudge_buttons("k", fh, "this value")
      if nd then
        local nt = Midi.nudged(e.t, nd)
        if nt < grg.start or nt >= grg.stop - CFG.EDGE then UI.toast("A nudge cannot move it out of the song.", true)
        else nudge = { e = e, t = nt } end
      end
      -- the value
      ImGui.SameLine(ctx, C[4])
      local id = string.format("%d:%.4f", k.cc, e.t)
      R.kv_text = R.kv_text or {}
      local last = (n == #list)
      if k.kind == "choice" then -- a function with choices: its label, a dropdown
        ImGui.SetNextItemWidth(ctx, CFG.W_S + gap + SLOPE_W)
        local lab = Knob.label(k, e.v)
        if ImGui.BeginCombo(ctx, "##kc", lab) then
          for ci, c in ipairs(k.choices) do
            if ImGui.Selectable(ctx, c[2] .. "##kc" .. ci, c[2] == lab) and c[1] ~= e.v then change = { e = e, v = c[1] } end
          end
          ImGui.EndCombo(ctx)
        end
        UI.tip(k.name .. ": " .. lab .. " (CC value " .. e.v .. ").")
      elseif k.kind then -- a press or a tap: nothing to choose
        UI.row_text(Knob.label(k, e.v), COL.TEXT_MAIN)
        ImGui.SameLine(ctx, C[5])
        ImGui.Dummy(ctx, SLOPE_W, fh)
      else
        ImGui.SetNextItemWidth(ctx, CFG.W_S)
        local _, nt = ImGui.InputText(ctx, "##kv", R.kv_text[id] or Knob.fmt(k, Knob.from_cc(k, e.v)))
        if ImGui.IsItemActive(ctx) then R.kv_text[id] = nt
        elseif ImGui.IsItemDeactivated(ctx) then
          local val = Knob.parse_value(R.kv_text[id] or nt)
          R.kv_text[id] = nil
          if val then change = { e = e, v = Knob.to_cc(k, val), want = val } else UI.toast("Type a number, for example 650.", true) end
        else R.kv_text[id] = nil end
        UI.tip(string.format("CC value %d. Type a new value (%s) and press Enter.", e.v, k.unit ~= "" and k.unit or "a number"))
        -- the slope to the next value (not on the last value of a song: there is no next one)
        ImGui.SameLine(ctx, C[5])
        ImGui.BeginDisabled(ctx, last)
        local sch, si = UI.icon_combo("##shape", Util.clamp(e.shape, 0, #SLOPE_LABELS - 1), SLOPE_LABELS, SLOPE_ICONS, SLOPE_W)
        if sch then shape = { e = e, s = si, ten = e.tension } end
        ImGui.EndDisabled(ctx)
        UI.tip(last and "The last value of the song: there is no next value."
          or "How the value moves to the next value. Jump: it changes at the next value.")
      end
      ImGui.SameLine(ctx, C[6])
      if UI.icon_button("ks", "send", fh) and not Midi.send_cc(d, k.cc, e.v) then UI.toast(d.name .. ": the MIDI output is not available.", true) end
      UI.tip("Send this value to the unit now.")
      ImGui.SameLine(ctx, C[7])
      if UI.remove_x_button("##kx", fh) then remove = e end
      UI.tip("Remove this value.")
      UI.pill_end(pkey, px, py, pw, e.t, "this value", d, k.cc)
      if not k.kind and e.shape == 5 and not last then
        ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
        ImGui.SetNextItemWidth(ctx, 110)
        local tch, tv, tdone = UI.bend_slider("##ten", e.tension)
        if tch then e.tension = tv end
        if tdone then shape = { e = e, s = 5, ten = tv } end
        UI.tip("How much the curve bends: below 0 it starts fast, above 0 it starts slowly.\nDouble-click: back to 0.")
      end
      local pd = Knob.pedal(d, k)
      if pd then
        local txt, tip = UI.expr_text(d, grg, e, pd)
        if txt then
          ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
          UI.row_text(txt, COL.TEXT_DIM)
          UI.tip(tip)
        end
      end
      ImGui.PopID(ctx)
      end
    end
    if scroll then ImGui.EndChild(ctx) end
  end
  if vopen and not any then UI.note(all and "No values of this control in any song yet." or "No values of this control in this song yet.") end
  if vopen and R.clip then -- a copied group, under the values: paste it at the edit cursor (on the chosen control)
    local why
    if not rg then why = "Put the edit cursor inside a song."
    elseif r.TimeMap2_QNToTime(R.proj, r.TimeMap2_timeToQN(R.proj, tc) + R.clip.len) >= rg.stop - CFG.EDGE then
      why = "It goes past the end of '" .. rg.name .. "'."
    end
    local PW = UI.std_w("Paste at edit cursor")
    UI.vgap(6)
    UI.row_text(UI.trunc("Copied: " .. R.clip.label,
      math.max(60, ImGui.GetContentRegionAvail(ctx) - PW - fh - 3 * CFG.CTRL_GAP)), COL.TEXT_DIM)
    UI.tip("Copied: " .. R.clip.label .. ".")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.BeginDisabled(ctx, why ~= nil)
    if UI.button("Paste at edit cursor", PW, nil, "primary") and not why then
      local cp = Midi.clip_points(R.clip, tc)
      Midi.add_ramp(d, k.cc, cp, "paste")
      r.SetEditCurPos(cp[#cp].t, true, false) -- (the next paste follows it)
      UI.toast("Pasted on " .. k.name .. " at " .. Util.fmt_beats(tc) .. ".")
    end
    ImGui.EndDisabled(ctx)
    UI.tip(why or ("Pastes it from the edit cursor (" .. Util.fmt_beats(tc) .. ") on " .. k.name
      .. ". The values of this control inside it are replaced. Ctrl+Z takes it back."))
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.remove_x_button("##clipx", fh) then R.clip = nil end
    UI.tip("Close this bar (forget the copy).")
  end
  if nudge then Midi.set_cc(d, k.cc, nudge.t, nudge.e.v, nudge.e) end
  if gmove then
    local G, gl = gmove.G, gmove.list
    local dq = r.TimeMap2_timeToQN(R.proj, gmove.t) - r.TimeMap2_timeToQN(R.proj, gl[G.i0].t)
    local t_end = r.TimeMap2_QNToTime(R.proj, r.TimeMap2_timeToQN(R.proj, gl[G.i1].t) + dq)
    if gmove.t < gmove.rg.start - 0.0005 or t_end >= gmove.rg.stop - CFG.EDGE then UI.toast("It cannot move out of the song.", true)
    else Midi.move_values(d, k.cc, gl, G.i0, G.i1, gmove.t, "move values") end
  end
  if gremove then Midi.move_values(d, k.cc, gremove.list, gremove.G.i0, gremove.G.i1, nil, "remove " .. gremove.word) end
  if not rg then -- (All songs, the cursor outside the songs: nothing to add to)
    if change then Midi.set_cc(d, k.cc, change.e.t, change.v, change.e) end
    if remove then Midi.remove_cc(d, k.cc, remove) end
    if shape then Midi.set_shape(d, k.cc, shape.e, shape.s, shape.ten) end
    UI.note("Put the edit cursor inside a song to add a value.")
    return
  end
  -- add at the edit cursor: the sections "Add value", "Add ramp" and "Add LFO" (a swell: its rows
  -- indented under the Swell toggle), in the label column form of the Settings tab
  local unit = k.unit ~= "" and k.unit or ""
  local function hint(v) return Knob.fmt(k, v) end
  -- the field of a "Custom..." length, next to its dropdown
  local function custom_field(id, cur)
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, CFG.W_S)
    local _, nv = ImGui.InputTextWithHint(ctx, id, "2.2", cur or "")
    UI.tip("The length as bars.beats: 3 = 3 bars, 0.6 = 6 beats, 2.2 = 2 bars and 2 beats.")
    return nv
  end
  local function arrow(AW) -- the arrow between 2 fields: a line and a head
    local ax, ay = ImGui.GetCursorScreenPos(ctx)
    local fh2 = ImGui.GetFrameHeight(ctx)
    ImGui.Dummy(ctx, AW, fh2)
    local dl = ImGui.GetWindowDrawList(ctx)
    local cy = math.floor(ay + fh2 / 2) + 0.5
    ImGui.DrawList_AddLine(dl, ax + 2, cy, ax + AW - 5, cy, COL.TEXT_DIM, 2)
    ImGui.DrawList_AddTriangleFilled(dl, ax + AW - 7, cy - 5, ax + AW - 7, cy + 5, ax + AW, cy, COL.TEXT_DIM)
  end
  local function hint_field(id, w, cur, hint_text, tip)
    ImGui.SetNextItemWidth(ctx, w)
    local _, nv = ImGui.InputTextWithHint(ctx, id, hint_text, cur)
    UI.tip(tip)
    return nv
  end
  if k.kind then -- a function of the unit: add its choice, a press or a tap at the edit cursor (no ramps)
    if UI.heading("Add", nil, nil, nil, "add_value", "at the edit cursor (" .. Util.fmt_beats(tc) .. ")") then
    local _, acw = UI.row_start(k.name)
    local AW2 = UI.std_w("Add at edit cursor")
    if k.kind == "choice" then
      R.kchoice = R.kchoice or {}
      local ci = Util.clamp(R.kchoice[k.cc] or 1, 1, #k.choices)
      ImGui.SetNextItemWidth(ctx, UI.fit_w(acw) - AW2 - CFG.CTRL_GAP)
      if ImGui.BeginCombo(ctx, "##kadd", k.choices[ci][2]) then
        for j, c in ipairs(k.choices) do
          if ImGui.Selectable(ctx, c[2] .. "##ka" .. j, j == ci) then R.kchoice[k.cc] = j; ci = j end
        end
        ImGui.EndCombo(ctx)
      end
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      if UI.button("Add at edit cursor", AW2, nil, "primary") then
        Midi.set_cc(d, k.cc, tc, k.choices[ci][1])
        UI.toast(k.name .. ": " .. k.choices[ci][2] .. " at " .. Util.fmt_beats(tc) .. ".")
      end
      UI.tip("Adds it exactly at the edit cursor.")
    else
      local lab = k.kind == "tap" and "Tap at edit cursor" or "Press at edit cursor"
      if UI.button(lab, UI.std_w(lab), nil, "primary") then
        Midi.set_cc(d, k.cc, tc, 127)
        UI.toast(k.name .. ": " .. (k.kind == "tap" and "a tap" or "a press") .. " at " .. Util.fmt_beats(tc) .. ".")
      end
      UI.tip(k.kind == "tap" and "1 tap tempo press, at the edit cursor."
        or "1 press of " .. k.name .. " at the edit cursor (the unit switches it on or off).")
      if k.kind == "tap" then
        ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
        if UI.button("4 taps on the beat", UI.std_w("4 taps on the beat")) then
          Midi.add_taps(d, k.cc, tc)
          UI.toast("4 taps from " .. Util.fmt_beats(tc) .. ": the unit takes the project's tempo there.")
        end
        UI.tip("4 taps on the next 4 beats, so the unit takes the project's tempo.")
      end
    end
    end
    if change then Midi.set_cc(d, k.cc, change.e.t, change.v, change.e) end
    if remove then Midi.remove_cc(d, k.cc, remove) end
    return
  end
  -- a value: the control jumps there
  if UI.heading("Add value", nil, nil, nil, "add_value", "at the edit cursor (" .. Util.fmt_beats(tc) .. ")") then
  R.kadd = R.kadd or ""
  UI.row_start("Value")
  local VCW = UI.fit_w(select(2, UI.form("Value")))
  local ABW = UI.std_w("Add value")
  R.kadd = hint_field("##kadd", VCW - ABW - CFG.CTRL_GAP, R.kadd, hint(k.min),
    "A value in " .. (unit ~= "" and unit or "numbers") .. " (" .. hint(k.min) .. " to " .. hint(k.max) .. "). The control jumps there and stays.")
  local val = Knob.parse_value(R.kadd)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, val == nil)
  if UI.button("Add value", ABW, nil, "primary") and val then
    Midi.set_cc(d, k.cc, tc, Knob.to_cc(k, val))
    UI.toast("Added " .. hint(Knob.from_cc(k, Knob.to_cc(k, val))) .. " at " .. Util.fmt_beats(tc) .. ".")
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Adds the value exactly at the edit cursor.")
  if val then
    local c = Knob.to_cc(k, val)
    local near = Knob.from_cc(k, c)
    local outside = val < math.min(k.min, k.max) or val > math.max(k.min, k.max)
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    UI.row_text(outside and ("Outside " .. hint(k.min) .. " - " .. hint(k.max))
      or (math.abs(near - val) > 1e-6 and ("Nearest: " .. hint(near)) or ("CC value " .. c)), outside and COL.YELLOW or COL.TEXT_DIM)
  end
  end
  -- a ramp (needs no value first): from, to, length, slope; a swell goes back
  local rp = R.ramp or { from = "", to = "", len = 5, shape = 0, ten = 0, back = false,
    v2 = "", hold = 0, blen = 5, bshape = 0, bten = 0 }
  R.ramp = rp
  if UI.heading("Add ramp", nil, nil, nil, "add_ramp", "from the edit cursor (" .. Util.fmt_beats(tc) .. ")") then
  local _, cw = UI.row_start("From / to")
  local AW = 18                -- (the arrow between the 2 fields)
  local FW = math.floor((UI.fit_w(cw) - AW - 2 * CFG.CTRL_GAP) / 2)
  rp.from = hint_field("##rfrom", FW, rp.from, hint(k.min), "The value at the start" .. (unit ~= "" and (" (" .. unit .. ")") or "") .. ".")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  arrow(AW)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  rp.to = hint_field("##rto", FW, rp.to, hint(k.max), "The value at the end (a swell: the top). Then the value stays there.")
  UI.row_start("Swell")
  local bch, bk = UI.toggle("##swell", rp.back)
  UI.tip("Swell: up, hold, and back down (for example 0 - 100 - 0).")
  if bch then rp.back = bk end
  _, cw = UI.row_start("Length")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw) - ((RAMP_LENS[rp.len].custom) and (CFG.W_S + CFG.CTRL_GAP) or 0))
  local lch, li = ImGui.Combo(ctx, "##rlen", rp.len - 1, RAMP_LEN_ITEMS)
  if lch then rp.len = li + 1 end
  UI.tip("How long the ramp lasts. Custom...: type bars.beats.\n'To the time selection end': it ends where REAPER's time selection ends.")
  if RAMP_LENS[rp.len].custom then rp.lenc = custom_field("##rlenc", rp.lenc) end
  _, cw = UI.row_start("Slope")
  local sch2, sh = UI.icon_combo("##rshape", rp.shape, RAMP_LABELS, RAMP_ICONS,
    UI.fit_w(cw) - ((rp.shape == 4) and (CFG.W_S + CFG.CTRL_GAP) or 0))
  if sch2 then rp.shape = sh end
  UI.tip("How the value moves.")
  if rp.shape == 4 then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, CFG.W_S)
    _, rp.ten = UI.bend_slider("##rten", rp.ten)
    UI.tip("How much the curve bends: below 0 it starts fast, above 0 it starts slowly.\nDouble-click: back to 0.")
  end
  local v0, v1 = Knob.parse_value(rp.from), Knob.parse_value(rp.to)
  local sw, bad
  if rp.back then
    -- the swell rows, indented under Swell
    _, cw = UI.row_start("      Hold")
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw) - ((rp.hold > 0 and RAMP_LENS[rp.hold].custom) and (CFG.W_S + CFG.CTRL_GAP) or 0))
    local hch, hi = ImGui.Combo(ctx, "##rhold", rp.hold, HOLD_ITEMS)
    if hch then rp.hold = hi end
    UI.tip("How long the value stays at the top. Custom...: type bars.beats.")
    if rp.hold > 0 and RAMP_LENS[rp.hold].custom then rp.holdc = custom_field("##rholdc", rp.holdc) end
    UI.row_start("      Back to")
    rp.v2 = hint_field("##rv2", 110, rp.v2, "= start", "The value at the end of the swell. Empty: back to the start value.\n"
      .. "It cannot go past the top (a swell up stays at or below its top, a swell down at or above its bottom).")
    _, cw = UI.row_start("      Length")
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw) - ((RAMP_LENS[rp.blen].custom) and (CFG.W_S + CFG.CTRL_GAP) or 0))
    local blch, bli = ImGui.Combo(ctx, "##rblen", rp.blen - 1, BACK_LEN_ITEMS)
    if blch then rp.blen = bli + 1 end
    UI.tip("How long the way back down takes. Custom...: type bars.beats.")
    if RAMP_LENS[rp.blen].custom then rp.blenc = custom_field("##rblenc", rp.blenc) end
    _, cw = UI.row_start("      Slope")
    local bsch, bsh = UI.icon_combo("##rbshape", rp.bshape, RAMP_LABELS, RAMP_ICONS,
      UI.fit_w(cw) - ((rp.bshape == 4) and (CFG.W_S + CFG.CTRL_GAP) or 0))
    if bsch then rp.bshape = bsh end
    UI.tip("How the value moves on the way back.")
    if rp.bshape == 4 then
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      ImGui.SetNextItemWidth(ctx, CFG.W_S)
      _, rp.bten = UI.bend_slider("##rbten", rp.bten)
      UI.tip("How much the curve bends: below 0 it starts fast, above 0 it starts slowly.\nDouble-click: back to 0.")
    end
    local v2 = rp.v2:match("^%s*$") and v0 or Knob.parse_value(rp.v2)
    if v0 and v1 and v2 then
      if (v1 > v0 and v2 > v1) or (v1 < v0 and v2 < v1) then bad = "'Back to' cannot go past the top (" .. hint(v1) .. ")." end
      sw = { hold = rp.hold, v2 = Knob.to_cc(k, v2), len = rp.blen, shape = rp.bshape + 1, tension = rp.bten,
        hold_c = rp.holdc, len_c = rp.blenc }
    elseif v0 and v1 then bad = "Type a number in 'Back to', or leave it empty." end
  end
  local t1 = Midi.ramp_end(tc, rp.len, rp.lenc)
  local pts, tend
  if v0 and v1 and t1 and not bad then
    pts, tend = Midi.ramp_points(tc, t1, Knob.to_cc(k, v0), Knob.to_cc(k, v1), rp.shape + 1, rp.ten, sw)
    if not pts then bad = "Type the custom length as bars.beats (for example 2.2)." end
  end
  -- what is missing (grey), a problem (red), or where it goes
  local why, why_col = nil, COL.TEXT_DIM
  if bad then why, why_col = bad, COL.RED
  elseif not v0 then why = "Type the start value."
  elseif not v1 then why = "Type the end value."
  elseif not t1 and RAMP_LENS[rp.len].custom then why = "Type the length as bars.beats (for example 2.2)."
  elseif not t1 then why = "Select the end with REAPER's time selection (after the edit cursor)."
  elseif tend >= rg.stop - CFG.EDGE then why, why_col = "It goes past the end of '" .. rg.name .. "': choose a shorter length.", COL.RED
  else why = Util.fmt_beats(tc) .. " to " .. Util.fmt_beats(tend) end
  local ok_add = pts and tend < rg.stop - CFG.EDGE
  ImGui.SetCursorPosX(ctx, (UI.form("Length")))
  local blabel = rp.back and "Add swell" or "Add ramp"
  ImGui.BeginDisabled(ctx, not ok_add)
  if UI.button(blabel .. "##radd", UI.std_w(blabel), nil, "primary") and ok_add and pts and tend then
    Midi.add_ramp(d, k.cc, pts, rp.back and "swell" or "ramp")
    r.SetEditCurPos(pts[#pts].t, true, false) -- (the edit cursor goes to its end)
    local function f(c) return hint(Knob.from_cc(k, c)) end
    UI.toast((rp.back and ("Swell " .. f(pts[1].v) .. " - " .. f(Knob.to_cc(k, v1)) .. " - " .. f(pts[#pts].v))
      or ("Ramp " .. f(pts[1].v) .. " to " .. f(pts[#pts].v))) .. ", " .. Util.fmt_beats(tc) .. " to " .. Util.fmt_beats(tend) .. ".")
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Adds it from the edit cursor. The values of this control inside it are replaced. Ctrl+Z takes it back.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  UI.row_text(UI.trunc(why, math.max(40, ImGui.GetContentRegionAvail(ctx) - 8)), why_col)
  UI.tip(why)
  end
  -- an LFO: low / high, shape and rate, start, length (the points are made only when it is added)
  local lf = R.lfo or { lo = "", hi = "", shape = 0, rate = 5, start = 0, fin = 0, grow = 0, len = 4 }
  R.lfo = lf
  if UI.heading("Add LFO", "Moves the control between 2 values, again and again, from the edit cursor.\n\n"
    .. "Shape: Sine (smooth), Triangle (straight), Square (jumps), Saw up / Saw down (a straight ramp, then a jump "
    .. "back).\nRate: the time of 1 cycle (low, high and back to low). It follows the tempo.\nStart: the first value. "
    .. "A Saw up starts at low, a Saw down at high.\nEnd: the value after the LFO (it jumps there at the end), or "
    .. "where it stops.\nPeaks: Same, or Grow / Shrink step by step over the whole LFO (the Start value stays).\n\nSaw up: the first value is smaller than the second. Saw down: the first value is larger.\n\nMIDI Pilot writes 1 value at each top and bottom, with a slope "
    .. "between them. The values of this control inside it are replaced. Ctrl+Z takes it back.",
    nil, nil, "add_lfo", "from the edit cursor (" .. Util.fmt_beats(tc) .. ")") then
  local _, cw = UI.row_start(lf.shape >= 3 and "From / to" or "Low / high")
  local AW = 18
  local FW = math.floor((UI.fit_w(cw) - AW - 2 * CFG.CTRL_GAP) / 2)
  lf.lo = hint_field("##llo", FW, lf.lo, hint(k.min), "The low value" .. (unit ~= "" and (" (" .. unit .. ")") or "") .. ".")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  arrow(AW)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  lf.hi = hint_field("##lhi", FW, lf.hi, hint(k.max), "The high value" .. (unit ~= "" and (" (" .. unit .. ")") or "") .. ".")
  _, cw = UI.row_start("Shape / rate")
  local HW = math.floor((UI.fit_w(cw) - CFG.CTRL_GAP) / 2)
  local sch, sv = UI.icon_combo("##lshape", lf.shape, LFO_LABELS, LFO_ICONS, HW)
  if sch then lf.shape = sv end
  UI.tip("How the value moves: Sine (smooth), Triangle (straight), Square (jumps),\nSaw up / Saw down (a straight ramp, then a jump back).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, HW)
  local rch, rv = ImGui.Combo(ctx, "##lrate", lf.rate - 1, LFO_RATE_ITEMS)
  if rch then lf.rate = rv + 1 end
  UI.tip("The time of 1 cycle: low, high and back to low. It follows the tempo.")
  _, cw = UI.row_start("Start / end")
  local saw = lf.shape >= 3
  local sx0 = ImGui.GetCursorPosX(ctx)
  if saw then -- (a saw starts at its first value: no choice)
    UI.row_text(lf.shape == 3 and "Saw up: from low" or "Saw down: from high", COL.TEXT_DIM)
    UI.tip("A Saw up starts at low, a Saw down at high (the first field).")
  else
    ImGui.SetNextItemWidth(ctx, HW)
    local stch, stv = ImGui.Combo(ctx, "##lstart", lf.start, "At low\0At high\0")
    if stch then lf.start = stv; lf.fin = stv end
    UI.tip("The first value: low (the first field) or high (the second field).")
  end
  ImGui.SameLine(ctx, sx0 + HW + CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, HW)
  local fch, fv = ImGui.Combo(ctx, "##lend", lf.fin, "At low\0At high\0Where it stops\0")
  if fch then lf.fin = fv end
  UI.tip("The value after the LFO: it jumps there at the end. 'Where it stops': the value of the wave at the end.")
  _, cw = UI.row_start("Peaks")
  ImGui.SetNextItemWidth(ctx, HW)
  local gch, gv = ImGui.Combo(ctx, "##lgrow", lf.grow, "Same\0Grow\0Shrink\0")
  if gch then lf.grow = gv end
  UI.tip("Same: every peak goes to the full value.\nGrow: the peaks get bigger, step by step, until the last one is full "
    .. "(0-100 with 4 peaks: 0-25, 0-50, 0-75, 0-100).\nShrink: the other way.\nThe Start value stays the same.")
  _, cw = UI.row_start("Length")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw) - ((RAMP_LENS[lf.len].custom) and (CFG.W_S + CFG.CTRL_GAP) or 0))
  local lch, lv = ImGui.Combo(ctx, "##llen", lf.len - 1, RAMP_LEN_ITEMS)
  if lch then lf.len = lv + 1 end
  UI.tip("How long the LFO lasts. Custom...: type bars.beats.\n'To the time selection end': it ends where REAPER's time selection ends.")
  if RAMP_LENS[lf.len].custom then lf.lenc = custom_field("##llenc", lf.lenc) end
  local lo, hi = Knob.parse_value(lf.lo), Knob.parse_value(lf.hi)
  local lt1 = Midi.ramp_end(tc, lf.len, lf.lenc)
  local lwhy, lcol = nil, COL.TEXT_DIM
  if not lo then lwhy = "Type the low value."
  elseif not hi then lwhy = "Type the high value."
  elseif lf.shape == 3 and lo >= hi then lwhy, lcol = "Saw up: the first value must be smaller than the second.", COL.RED
  elseif lf.shape == 4 and lo <= hi then lwhy, lcol = "Saw down: the first value must be larger than the second.", COL.RED
  elseif not lt1 and RAMP_LENS[lf.len].custom then lwhy = "Type the length as bars.beats (for example 2.2)."
  elseif not lt1 then lwhy = "Select the end with REAPER's time selection (after the edit cursor)."
  elseif lt1 >= rg.stop - CFG.EDGE then lwhy, lcol = "It goes past the end of '" .. rg.name .. "': choose a shorter length.", COL.RED
  else lwhy = Util.fmt_beats(tc) .. " to " .. Util.fmt_beats(lt1) end
  local lok = lo and hi and lt1 and lt1 < rg.stop - CFG.EDGE and lcol ~= COL.RED
  ImGui.SetCursorPosX(ctx, (UI.form("Length")))
  ImGui.BeginDisabled(ctx, not lok)
  if UI.button("Add LFO##ladd", UI.std_w("Add LFO"), nil, "primary") and lok then
    local c1, c2 = Knob.to_cc(k, lo), Knob.to_cc(k, hi)
    local lowv, highv = c1, c2 -- (End: a saw's low is its smaller value)
    if saw then lowv, highv = math.min(c1, c2), math.max(c1, c2) end
    local fin = (lf.fin == 0 and lowv) or (lf.fin == 1 and highv) or nil
    local pts = Midi.lfo_points(tc, lt1, c1, c2, lf.shape, Midi.lfo_cycle(tc, lf.rate), lf.start == 1, fin, lf.grow)
    if pts then
      Midi.add_ramp(d, k.cc, pts, "LFO")
      r.SetEditCurPos(pts[#pts].t, true, false) -- (the edit cursor goes to its end)
      UI.toast("LFO " .. hint(Knob.from_cc(k, Knob.to_cc(k, lo))) .. " - " .. hint(Knob.from_cc(k, Knob.to_cc(k, hi)))
        .. ", " .. Util.fmt_beats(tc) .. " to " .. Util.fmt_beats(lt1) .. ".")
    end
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Adds it from the edit cursor. The values of this control inside it are replaced. Ctrl+Z takes it back.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  UI.row_text(UI.trunc(lwhy, math.max(40, ImGui.GetContentRegionAvail(ctx) - 8)), lcol)
  UI.tip(lwhy)
  end
  if change then
    Midi.set_cc(d, k.cc, change.e.t, change.v, change.e)
    local got = Knob.from_cc(k, change.v)
    if change.want and math.abs(got - change.want) > 1e-6 then UI.toast("Nearest value: " .. Knob.fmt(k, got) .. ".") end
  end
  if remove then Midi.remove_cc(d, k.cc, remove) end
  if shape then Midi.set_shape(d, k.cc, shape.e, shape.s, shape.ten) end
end

-- The colour of scene colour ci (1-8; "test": the Scene test block). active: the block of the scene that plays at the
-- play position (stopped: the edit cursor): the unit's colour; the other blocks: semi-transparent (Dark theme). In
-- the Light theme every block has its full colour, and the active block has a blue outline (UI.draw_scene_strip).
-- And the text colour on it (readable on that colour).
function UI.sc_col(ci, active)
  local c = (ci == "test") and SC_TEST or SC_NORMAL[ci]
  if active or S.theme == "light" then return c end
  return (c & 0xFFFFFF00) | 0x55
end
function UI.sc_text(ci, active)
  if not active and S.theme ~= "light" then return COL.TEXT_BRIGHT end -- (on a semi-transparent block: the dark strip)
  local c = (ci == "test") and SC_TEST or SC_NORMAL[ci]
  local lum = 0.299 * ((c >> 24) & 255) + 0.587 * ((c >> 16) & 255) + 0.114 * ((c >> 8) & 255)
  return lum > 140 and SC_TEXT or COL.WHITE
end

-- A yellow warning sign (a triangle with "!"), the size of a control.
function UI.warn_icon(id, size)
  ImGui.InvisibleButton(ctx, id, size, size)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx = x0 + size / 2
  ImGui.DrawList_AddTriangleFilled(dl, cx, y0 + 3, x0 + size - 3, y0 + size - 4, x0 + 3, y0 + size - 4, COL.YELLOW)
  ImGui.DrawList_AddLine(dl, cx, y0 + 9, cx, y0 + size - 10, SC_TEXT, 2) -- (dark on the yellow, in both themes)
  ImGui.DrawList_AddCircleFilled(dl, cx, y0 + size - 7, 1.3, SC_TEXT)
end

-- The "Rename folder" window: R.frename = { d, folder, name, open }.
function UI.draw_folder_rename()
  local fr = R.frename
  if not fr then return end
  if fr.open then ImGui.OpenPopup(ctx, "Rename folder##fren"); fr.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Rename folder##fren", true, ImGui.WindowFlags_AlwaysAutoResize()) then R.frename = nil; return end
  ImGui.Text(ctx, "The unit's name: " .. Preset.unit_folder(fr.d.model, fr.folder) .. ". Empty: this name again.")
  ImGui.SetNextItemWidth(ctx, UI.fit_w())
  if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
  local _
  _, fr.name = ImGui.InputText(ctx, "##frname", fr.name)
  local enter = ImGui.IsItemDeactivated(ctx) and (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter()) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter()))
  UI.vgap(8)
  if UI.button("Rename", UI.dlg_w("Rename"), nil, "primary") or enter then
    Preset.set_folder_name(fr.d, fr.folder, fr.name); R.frename = nil; ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", UI.dlg_w("Cancel")) then R.frename = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- Presets: the preset names of a device (saved on this computer, for all projects).
function UI.draw_presets_tab()
  if UI.no_device_hint() then return end
  local d = UI.device_picker()
  local m = MODELS[d.model]
  UI.heading("Add Preset", "Give your Presets names, for example 3B = Song One. The Songs tab then shows the names.\n\n"
    .. "The names are saved on this computer and work in all projects.")
  local a = R.lib_add or { folder = m.def_folder, bank = 1, letter = 1, name = "" }
  R.lib_add = a
  a.folder = Util.clamp(a.folder, 0, m.folders - 1); a.bank = Util.clamp(a.bank, 1, m.banks) -- (another model)
  local ch, v
  local _, cw = UI.row_start("Folder")
  local FWD = UI.fit_w(cw)        -- (the column)
  local BW = UI.dlg_w("Rename...")          -- (the button at the end of the Folder and Name rows)
  ImGui.SetNextItemWidth(ctx, FWD - BW - CFG.CTRL_GAP)
  ch, v = ImGui.Combo(ctx, "##lfolder", a.folder, Preset.folder_items(d))
  if ch then a.folder = v end
  UI.tip("The folder of the Preset on the unit (the unit calls it a setlist).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local fixed = Preset.fixed_folder(d, a.folder)
  ImGui.BeginDisabled(ctx, fixed)
  if UI.button("Rename...##fold", BW) then
    R.frename = { d = d, folder = a.folder, name = Preset.folder_name(d, a.folder), open = true }
  end
  ImGui.EndDisabled(ctx)
  UI.tip(fixed and "Factory Presets and My Presets keep the unit's names. Only the user folders can be renamed."
    or "Give this folder your own name (for example the name of your band).")
  a.letter = Util.clamp(a.letter, 1, #m.letters)
  if UI.number_mode(d) then
    UI.row_start("Number")
    UI.number_input(d, a, "##lnum", FWD)
    UI.tip(string.format("The Preset number (000-%03d), as the unit shows it.", m.presets - 1))
  else
    _, cw = UI.row_start("Bank and Preset")
    ImGui.SetNextItemWidth(ctx, FWD - BW - CFG.CTRL_GAP)
    ch, v = UI.input_int("##lbank", a.bank, 1)
    if ch then a.bank = Util.clamp(v, 1, m.banks) end
    UI.tip(string.format("The bank number (1-%d).", m.banks))
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, BW)
    ch, v = ImGui.Combo(ctx, "##lletter", a.letter - 1, UI.letter_items(d.model))
    if ch then a.letter = v + 1 end
    UI.tip("The Preset letter in the bank.")
  end
  local idx = Preset.index(d.model, a.bank, a.letter)
  _, cw = UI.row_start("Name")
  ImGui.SetNextItemWidth(ctx, FWD - BW - CFG.CTRL_GAP)
  local _
  _, a.name = ImGui.InputText(ctx, "##lname", a.name)
  local enter = ImGui.IsItemDeactivated(ctx) and (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter()) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter()))
  UI.tip("The name of the Preset, for example the song name. Enter adds it.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local can = a.name:match("%S") ~= nil
  ImGui.BeginDisabled(ctx, not can)
  if (UI.button(Preset.name(d, a.folder, idx) and "Rename" or "Add", BW, nil, "primary") or enter) and can then
    Preset.set_name(d, a.folder, idx, a.name)
    a.name = ""
    a.letter = a.letter + 1 -- the next preset, for the next name
    if a.letter > #m.letters then a.letter = 1; a.bank = math.min(m.banks, a.bank + 1) end
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Saves the name for " .. Preset.plabel(d, idx) .. ", then selects the next Preset.")

  local keys, total = Preset.list_view(d, S.lib[d.id] or NO_ROWS)
  UI.heading(#keys == total and string.format("Preset list (%d)", total) or string.format("Preset list (%d of %d)", #keys, total),
    "Click a name to change it.\nScenes icon: Scene names and colours. "
    .. "Pedal icon (Quad Cortex): what the pedals move. Pencil: move the name to another Preset. Red X: remove the name "
    .. "(your songs do not change).\n\nSearch: a name, a number (3B) or a folder. Sort: Number, Name, or Used first "
    .. "(the Presets that the songs of this project use). The sort is saved on this computer.")
  if total == 0 then UI.note("No names yet. Add the first one above.")
  else -- the search row (as Chart Cue's library)
    ImGui.SetNextItemWidth(ctx, math.max(80, ImGui.GetContentRegionAvail(ctx) - 170 - CFG.CTRL_GAP - 4))
    local _, ns = ImGui.InputTextWithHint(ctx, "##psearch", "Search Presets...", R.psearch or "")
    R.psearch = ns
    UI.tip("Shows only the Presets whose name, number or folder has this text.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, 170)
    local sch, sv = ImGui.Combo(ctx, "##psort", S.preset_sort, "Sort: Number\0Sort: Name\0Sort: Used first\0")
    if sch then S.preset_sort = sv; Util.mark_sdirty() end
    UI.tip("Number: folder, bank and letter. Name: A-Z. Used first: the Presets that the songs of this project use.")
    UI.vgap(8)
    if #keys == 0 then UI.note("No Presets match the search.") end
  end
  local fh = ImGui.GetFrameHeight(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local rm
  for n, k in ipairs(keys) do
    local f, i = k:match("^(%d+):(%d+)$")
    f, i = tonumber(f), tonumber(i)
    ImGui.PushID(ctx, k)
    UI.row_text(Preset.plabel(d, i), COL.TEXT_MAIN)
    ImGui.SameLine(ctx, 50)
    local qc = not m.line6 -- (the Quad Cortex: also the pedal icon)
    local nic = qc and 4 or 3
    ImGui.SetNextItemWidth(ctx, math.max(80, aw - 50 - 80 - nic * fh - (nic + 1) * CFG.CTRL_GAP))
    local nm = S.lib[d.id][k]
    local changed, nv = ImGui.InputText(ctx, "##nm", nm)
    if changed and nv:match("%S") then S.lib[d.id][k] = Util.clean(nv); Util.mark_sdirty(); R.bank_dirty = true; R.pick_cache, R.plist = nil, nil end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    UI.row_text(UI.trunc(Preset.folder_name(d, f), 150 - 70), COL.TEXT_DIM)
    if qc then
      ImGui.SameLine(ctx, aw - 4 * fh - 3 * CFG.CTRL_GAP)
      if UI.icon_button("exp", "pedal", fh) then
        local lists = { {}, {} }
        for pd = 1, 2 do
          for _, a in ipairs(Preset.expr(d, f, i, pd)) do
            lists[pd][#lists[pd] + 1] = { name = a.name, from = a.from, to = a.to, note = a.note or "" }
          end
        end
        R.xedit = { d = d, folder = f, index = i, lists = lists, open = true }
      end
      local n1, n2 = #Preset.expr(d, f, i, 1), #Preset.expr(d, f, i, 2)
      UI.tip("Expression pedals: what pedal 1 and 2 move in this Preset (as on the unit's Assign Expression Pedal screen).\n"
        .. "Pedal 1: " .. n1 .. ", pedal 2: " .. n2 .. ".")
    end
    ImGui.SameLine(ctx, aw - 3 * fh - 2 * CFG.CTRL_GAP)
    if UI.icon_button("scn", "scenes", fh) then
      local names = {}
      local cols = {}
      for v = 1, Midi.nsc(d) do
        names[v] = (S.snames[d.id] and S.snames[d.id][k] and S.snames[d.id][k][v]) or ""
        cols[v] = Preset.scene_col(d, f, i, v - 1)
      end
      R.sedit = { d = d, folder = f, index = i, names = names, cols = cols, open = true }
    end
    UI.tip("Scenes: name the Scenes of this Preset and choose their colours.")
    ImGui.SameLine(ctx, aw - 2 * fh - CFG.CTRL_GAP)
    if UI.icon_button("edt", "edit", fh) then
      local L = #m.letters
      R.pedit = { d = d, key = k, name = nm, folder = f, bank = i // L + 1, letter = i % L + 1, open = true }
    end
    UI.tip("Move this name to another folder, bank or Preset.")
    ImGui.SameLine(ctx, aw - fh)
    if UI.remove_x_button("##rmn", fh) then rm = { f, i } end
    UI.tip("Remove this name.")
    ImGui.PopID(ctx)
    if n >= 300 then
      UI.note(string.format("Showing the first 300 of %d names.", #keys))
      break
    end
  end
  if rm then Preset.set_name(d, rm[1], rm[2], "") end
  UI.draw_folder_rename()
  UI.draw_preset_edit()
  UI.draw_scene_names()
  UI.draw_expr_edit()
end

-- The pedal icon of the preset list (Quad Cortex): what the 2 expression pedals move in a preset (R.xedit): for
-- each pedal, rows of name, range (from % - to %, backwards allowed) and a note; Add, the red X; Save / Cancel.
function UI.draw_expr_edit()
  local xe = R.xedit
  if not xe then return end
  if xe.open then ImGui.OpenPopup(ctx, "Expression pedals##xedit"); xe.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Expression pedals##xedit", true, ImGui.WindowFlags_AlwaysAutoResize()) then R.xedit = nil; return end
  local d = xe.d
  local fh = ImGui.GetFrameHeight(ctx)
  ImGui.Text(ctx, Preset.text(d, xe.folder, xe.index))
  ImGui.TextDisabled(ctx, "As on the unit (Assign Expression Pedal): the parameter and its range in % of its knob.")
  local NW, PW, TW = 180, 110, 220 -- (name, a % field with - and +, the note)
  for pd = 1, 2 do
    ImGui.PushID(ctx, pd)
    UI.vgap(10)
    ImGui.PushFont(ctx, bold)
    UI.row_text("Expression pedal " .. pd .. "  (CC#" .. pd .. ")", COL.HEADING)
    ImGui.PopFont(ctx)
    local list = xe.lists[pd]
    if #list > 0 then
      local x0 = ImGui.GetCursorPosX(ctx)
      for ci, hd in ipairs({ { 0, "Parameter" }, { NW + 8, "From %" }, { NW + PW + 16, "To %" }, { NW + 2 * PW + 24, "Note (optional)" } }) do
        if ci > 1 then ImGui.SameLine(ctx, x0 + hd[1]) end
        ImGui.TextColored(ctx, COL.TEXT_DIM, hd[2])
      end
    end
    local rm
    for n, a in ipairs(list) do
      ImGui.PushID(ctx, n)
      local x0 = ImGui.GetCursorPosX(ctx)
      ImGui.SetNextItemWidth(ctx, NW)
      local _
      _, a.name = ImGui.InputTextWithHint(ctx, "##xn", "for example Hi Pass", a.name)
      ImGui.SameLine(ctx, x0 + NW + 8)
      ImGui.SetNextItemWidth(ctx, PW)
      local ch, v = UI.input_int("##xf", math.floor(a.from + 0.5), 5)
      if ch then a.from = Util.clamp(v, 0, 100) end
      UI.tip("The knob % at the heel (pedal 0%).")
      ImGui.SameLine(ctx, x0 + NW + PW + 16)
      ImGui.SetNextItemWidth(ctx, PW)
      ch, v = UI.input_int("##xt", math.floor(a.to + 0.5), 5)
      if ch then a.to = Util.clamp(v, 0, 100) end
      UI.tip("The knob % at the toe (pedal 100%). Lower than From: the knob goes backwards.")
      ImGui.SameLine(ctx, x0 + NW + 2 * PW + 24)
      ImGui.SetNextItemWidth(ctx, TW)
      _, a.note = ImGui.InputTextWithHint(ctx, "##xo", "0% = Off, 100% = 800 Hz", a.note)
      UI.tip("A note for yourself, for example '0% = Off, 100% = 800 Hz'. It shows in Lanes.")
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      if UI.remove_x_button("##xx", fh) then rm = n end
      UI.tip("Remove this assignment.")
      ImGui.PopID(ctx)
    end
    if rm then table.remove(list, rm) end
    if UI.button("Add to pedal " .. pd, UI.btn_w("Add to pedal " .. pd, 0) + 16) then
      list[#list + 1] = { name = "", from = 0, to = 100, note = "" }
    end
    ImGui.PopID(ctx)
  end
  UI.vgap(12)
  if UI.button("Save", UI.dlg_w("Save"), nil, "primary") then
    Preset.set_expr(d, xe.folder, xe.index, xe.lists)
    UI.toast("Expression pedals saved.")
    R.xedit = nil; ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", UI.dlg_w("Cancel")) then R.xedit = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- "Scenes..." of the preset list: the names of the 8 scenes of a preset (R.sedit).
function UI.draw_scene_names()
  local se = R.sedit
  if not se then return end
  if se.open then ImGui.OpenPopup(ctx, "Scene names##sedit"); se.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Scene names##sedit", true, ImGui.WindowFlags_AlwaysAutoResize()) then R.sedit = nil; return end
  local d = se.d
  ImGui.Text(ctx, Preset.text(d, se.folder, se.index))
  ImGui.TextDisabled(ctx, "Empty: the unit's name of the Scene.")
  UI.vgap(6)
  local fh = ImGui.GetFrameHeight(ctx)
  for v = 1, Midi.nsc(d) do
    -- the colour: a swatch; a click opens the 8 colours of the unit
    local ci = se.cols[v] or v
    local x, y = ImGui.GetCursorScreenPos(ctx)
    if ImGui.InvisibleButton(ctx, "##col" .. v, fh, fh) then ImGui.OpenPopup(ctx, "##colpick" .. v) end
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRectFilled(dl, x + 3, y + 3, x + fh - 3, y + fh - 3, UI.sc_col(ci, true), 4)
    if ImGui.IsItemHovered(ctx) then
      ImGui.DrawList_AddRect(dl, x + 2, y + 2, x + fh - 2, y + fh - 2, COL.WHITE, 4, 0, 1.5)
      ImGui.SetTooltip(ctx, SC_COL_NAMES[ci] .. ". Click to choose the colour of this Scene.")
    end
    if ImGui.BeginPopup(ctx, "##colpick" .. v) then
      for k = 1, 8 do
        if k > 1 then ImGui.SameLine(ctx, 0, 4) end
        local px, py = ImGui.GetCursorScreenPos(ctx)
        if ImGui.InvisibleButton(ctx, "##c" .. k, 24, 24) then se.cols[v] = k; ImGui.CloseCurrentPopup(ctx) end
        local pdl = ImGui.GetWindowDrawList(ctx)
        ImGui.DrawList_AddCircleFilled(pdl, px + 12, py + 12, (k == ci) and 11 or 8, UI.sc_col(k, true))
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, SC_COL_NAMES[k]) end
      end
      ImGui.EndPopup(ctx)
    end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, CFG.W_M)
    local _
    _, se.names[v] = ImGui.InputText(ctx, MODELS[d.model].scenes[v] .. "##sn" .. v, se.names[v])
  end
  UI.vgap(8)
  if UI.button("Save", UI.dlg_w("Save"), nil, "primary") then
    Preset.set_scene_names(d, se.folder, se.index, se.names, se.cols)
    UI.toast("Scene names saved.")
    R.sedit = nil; ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", UI.dlg_w("Cancel")) then R.sedit = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- "Edit..." of the preset list: folder, bank and preset of a name; "Save" asks first (in the same window).
function UI.draw_preset_edit()
  local pe = R.pedit
  if not pe then return end
  if pe.open then ImGui.OpenPopup(ctx, "Edit Preset##pedit"); pe.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Edit Preset##pedit", true, ImGui.WindowFlags_AlwaysAutoResize()) then R.pedit = nil; return end
  local d, m = pe.d, MODELS[pe.d.model]
  local f0, i0 = pe.key:match("^(%d+):(%d+)$")
  f0, i0 = tonumber(f0), tonumber(i0)
  local idx = Preset.index(d.model, pe.bank, pe.letter)
  local from = Preset.plabel(d, i0) .. " (" .. Preset.folder_name(d, f0) .. ")"
  local to = Preset.plabel(d, idx) .. " (" .. Preset.folder_name(d, pe.folder) .. ")"
  ImGui.Text(ctx, "'" .. pe.name .. "'  -  now " .. from)
  UI.vgap(6)
  if not pe.confirm then
    local ch, v
    ImGui.SetNextItemWidth(ctx, UI.fit_w())
    ch, v = ImGui.Combo(ctx, "Folder", pe.folder, Preset.folder_items(d))
    if ch then pe.folder = v end
    if UI.number_mode(d) then UI.number_input(d, pe, "Number", CFG.W_POP)
    else
      ImGui.SetNextItemWidth(ctx, CFG.W_POP)
      ch, v = UI.input_int("Bank", pe.bank, 1)
      if ch then pe.bank = Util.clamp(v, 1, m.banks) end
      ImGui.SetNextItemWidth(ctx, CFG.W_POP)
      ch, v = ImGui.Combo(ctx, "Preset", pe.letter - 1, UI.letter_items(d.model))
      if ch then pe.letter = v + 1 end
    end
    UI.vgap(8)
    local same = (f0 == pe.folder and i0 == idx)
    ImGui.BeginDisabled(ctx, same)
    if UI.button("Save", UI.dlg_w("Save"), nil, "primary") then pe.confirm = true end
    ImGui.EndDisabled(ctx)
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Cancel", UI.dlg_w("Cancel")) then R.pedit = nil; ImGui.CloseCurrentPopup(ctx) end
  else
    local other = Preset.name(d, pe.folder, idx)
    ImGui.PushTextWrapPos(ctx, 380)
    ImGui.Text(ctx, "Are you sure? The name '" .. pe.name .. "' moves from " .. from .. " to " .. to .. "."
      .. (other and ("\n" .. to .. " has the name '" .. other .. "': it is replaced.") or "")
      .. "\nIts Scene names and colours move with it. The Preset changes in your songs do not change.")
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    if UI.button("Yes, move", UI.dlg_w("Yes, move"), nil, "danger") then
      Preset.move(d, f0, i0, pe.folder, idx)
      UI.toast("'" .. pe.name .. "' is now " .. to .. ".")
      R.pedit = nil; ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Back", UI.dlg_w("Back")) then pe.confirm = false end
  end
  ImGui.EndPopup(ctx)
end

-- Settings > Devices: the list (click a row to edit it below), Add device; then the selected device.
function UI.draw_device_list()
  UI.heading("Device list", "Add 1 device for each unit. The devices are saved on this computer, for all projects.\n\n"
    .. "With USB, MIDI Pilot finds the unit and its MIDI output. With a MIDI interface, choose the model and the "
    .. "output yourself.\n\nIf you remove a device but keep its track, Add device brings it back with its settings.")
  local fh = ImGui.GetFrameHeight(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  for i, d in ipairs(S.devices) do
    ImGui.PushID(ctx, d.id)
    local sel = (i == R.sel_dev)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    if ImGui.InvisibleButton(ctx, "##row", math.max(1, aw - 4), fh) then R.sel_dev = i end
    local hov = ImGui.IsItemHovered(ctx)
    UI.tip("Click to edit this device below.")
    local dl = ImGui.GetWindowDrawList(ctx)
    if sel then ImGui.DrawList_AddRectFilled(dl, x - 6, y - 2, x + aw - 4, y + fh + 2, COL.ACTIVE_BG, 4)
    elseif hov then ImGui.DrawList_AddRectFilled(dl, x - 6, y - 2, x + aw - 4, y + fh + 2, COL.ROW_HOVER, 4) end
    local ty = UI.text_y(y)
    ImGui.DrawList_AddTextEx(dl, sel and bold or font, CFG.FONT_SIZE, x, ty, sel and COL.ACCENT_HOVER or COL.TEXT_MAIN,
      UI.trunc(d.name, 150))
    local info = MODELS[d.model].name .. "  -  " .. (d.chan == 0 and "All channels" or ("channel " .. d.chan))
    local tr = Dev.track(d)
    ImGui.DrawList_AddText(dl, x + 160, ty, COL.TEXT_DIM, UI.trunc(info .. "  -  " .. (tr and Dev.track_name(tr) or "no track"),
      math.max(20, aw - 170)))
    ImGui.PopID(ctx)
  end
  ImGui.SetNextItemWidth(ctx, UI.cell_w("Add device", UI.std_w("Add device")))
  if ImGui.BeginCombo(ctx, "##adddev", "Add device", ImGui.ComboFlags_HeightLargest()) then
    local free = Dev.free_units()
    if #free > 0 then
      ImGui.TextDisabled(ctx, "Connected")
      for i, pn in ipairs(free) do
        if ImGui.Selectable(ctx, MODELS[Dev.model_from_port(pn)].name .. "  (" .. pn .. ")##fu" .. i) then
          Dev.new(nil, pn); R.sel_dev = #S.devices
        end
      end
      ImGui.Separator(ctx)
    end
    ImGui.TextDisabled(ctx, "Models")
    for i, id in ipairs(MODEL_IDS) do
      if ImGui.Selectable(ctx, MODELS[id].name .. (MODELS[id].line6 and "  (untested)" or "") .. "##am" .. i) then
        Dev.new(id); R.sel_dev = #S.devices
      end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Connected: a unit that MIDI Pilot found on USB.\nModels: any supported unit; then choose its MIDI output below.\n"
    .. "MIDI Pilot also adds a track for the device.")
  local d = S.devices[R.sel_dev]
  if d then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Remove device...", UI.std_w("Remove device..."), nil, "danger") then
      local i, tr = R.sel_dev, P.track_mode ~= "shared" and Dev.track(d)
      if tr then
        UI.ask("Remove the device '" .. d.name .. "'? You can also remove its track '" .. Dev.track_name(tr)
          .. "' with all its MIDI.", "Remove device and track", function() Dev.remove_with_track(i, true) end,
          "Remove device only", function() Dev.remove_with_track(i, false) end)
      else
        UI.ask("Remove the device '" .. d.name .. "'?", "Yes, remove", function() Dev.remove(i) end)
      end
    end
    UI.tip("Remove " .. d.name .. " from MIDI Pilot. It asks whether its track goes too.")
  end
  local rw = UI.std_w("Reset MIDI devices")
  if #S.devices > 0 then
    if ImGui.GetContentRegionAvail(ctx) > rw + CFG.CTRL_GAP + 2 * UI.std_w("Add device") then
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    end
  end
  if UI.button("Reset MIDI devices", rw) then Dev.reset_midi() end
  UI.tip("Restarts REAPER's MIDI devices (REAPER's 'Reset all MIDI devices').\nUse it after you unplug or restart a unit.")
  local warn = Dev.conflicts()
  for _, w in ipairs(warn) do UI.note(w, COL.YELLOW) end
end

-- The selected device: name, model, MIDI output, channel, latency, track; remove.
function UI.draw_device_form()
  local d = S.devices[R.sel_dev]
  if not d then return end
  UI.heading("Device: " .. d.name, "The settings of the selected device. Click another row above to edit it.")
  local ch
  local _, cw = UI.row_start("Name")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  if R.name_edit == nil or R.name_edit_id ~= d.id then R.name_edit, R.name_edit_id = d.name, d.id end
  ch, R.name_edit = ImGui.InputText(ctx, "##devname", R.name_edit)
  if ImGui.IsItemDeactivated(ctx) then -- the name is used when you leave the field (an empty name: the model)
    local nm = R.name_edit:match("^%s*(.-)%s*$")
    if nm == "" then nm = MODELS[d.model].name end
    Dev.rename(d, nm)
    if Dev.is_default_name(d) then Dev.number_defaults(d.model) end
    R.name_edit = d.name
  elseif not ImGui.IsItemActive(ctx) then R.name_edit = d.name end
  UI.tip("For example Guitar. The track is called 'MIDI Guitar'. Renaming the track in REAPER renames the device.\n"
    .. "Empty: the model name.")

  _, cw = UI.row_start("Model")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local mi = 0
  for i, id in ipairs(MODEL_IDS) do if id == d.model then mi = i - 1 end end
  ch, mi = ImGui.Combo(ctx, "##model", mi, MODEL_ITEMS)
  if ch then Dev.set_model(d, MODEL_IDS[mi + 1]) end
  UI.tip("Quad Cortex: Presets and Scenes A-H. Quad Cortex mini: Presets A-D, Scenes A-I ... D-II.\n"
    .. "Line 6 Helix: 8 snapshots; HX Stomp: 3; HX Stomp XL and HX Effects: 4 (Line 6: not tested on a unit).")
  if MODELS[d.model].line6 then
    _, cw = UI.row_start("Preset numbers")
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
    local pni
    ch, pni = ImGui.Combo(ctx, "##pnum", d.pnum == "num" and 1 or 0, "Bank + letter (01A)\0Numbers (000)\0")
    if ch then d.pnum = (pni == 1) and "num" or "bank"; Util.mark_sdirty(); R.pick_cache, R.plist = nil, nil; R.bank_dirty = true end
    UI.tip("Show the Preset numbers as the unit does (on the unit: Global Settings > Preferences > Preset Numbering).")
  end

  _, cw = UI.row_start("MIDI input")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  if ImGui.BeginCombo(ctx, "##inport", d.inport ~= "" and d.inport or "(none)") then
    if ImGui.Selectable(ctx, "(none)", d.inport == "") then d.inport = ""; Util.mark_sdirty() end
    for _, p in ipairs(R.inports or {}) do
      if ImGui.Selectable(ctx, p.name .. "##i" .. p.index, p.name == d.inport) then d.inport = p.name; Util.mark_sdirty() end
    end
    if #(R.inports or {}) == 0 then ImGui.TextDisabled(ctx, "No MIDI input is on. Turn it on in REAPER's Preferences > MIDI Devices.") end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The MIDI input from this unit. Not used yet (for recording, in a later version).")
  _, cw = UI.row_start("MIDI output")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  if ImGui.BeginCombo(ctx, "##port", d.port ~= "" and d.port or "(none)") then
    if ImGui.Selectable(ctx, "(none)", d.port == "") then d.port = ""; Util.mark_sdirty(); R.conflicts = nil; Dev.apply_out(d) end
    for _, p in ipairs(R.ports) do
      if ImGui.Selectable(ctx, p.name .. "##p" .. p.index, p.name == d.port) then
        d.port = p.name
        local m = Dev.model_from_port(p.name)
        if m then Dev.set_model(d, m) end
        if d.inport == "" then d.inport = Dev.guess_input(d) end
        Util.mark_sdirty(); R.conflicts = nil; Dev.apply_out(d)
      end
    end
    if #R.ports == 0 then ImGui.TextDisabled(ctx, "No MIDI output is on. Turn it on in REAPER's Preferences > MIDI Devices.") end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The MIDI output to this unit. Only outputs that are enabled in REAPER (Preferences > MIDI Devices) show here.")


  _, cw = UI.row_start("MIDI channel")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local old_chan = d.chan
  ch, d.chan = ImGui.Combo(ctx, "##chan", d.chan, CHAN_ITEMS)
  if ch then
    Util.mark_sdirty(); R.conflicts = nil; Dev.apply_out(d)
    local from, to = (old_chan == 0) and 0 or old_chan - 1, Midi.chan(d)
    if from ~= to and Midi.has_channel(d, from) then
      local cname = function(c) return c == 0 and "All channels" or ("channel " .. c) end
      UI.ask(d.name .. " now uses " .. cname(d.chan) .. ". Its Presets and Scenes in this project are on "
        .. cname(old_chan) .. ". Move them to " .. cname(d.chan) .. " too?", "Move the MIDI",
        function() UI.toast(string.format("%d MIDI event(s) moved.", Midi.move_channel(d, from, to))) end,
        "Keep it", function() end)
      R.ask.safe = true
    end
  end
  UI.tip("Must match the unit's MIDI channel (on the unit: Settings > Device > MIDI).\n"
    .. "All channels: only when this is the only unit on this output.")

  _, cw = UI.row_start("Latency (ms)")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local lat
  ch, lat = UI.input_int("##lat", d.latency, 5)
  if ch then
    d.latency = Util.clamp(lat, 0, CFG.LATENCY_MAX); Util.mark_sdirty()
    for _, x in ipairs(S.devices) do if x == d or P.track_mode == "shared" then Dev.apply_latency(x) end end
  end
  UI.tip("If the unit reacts late, enter its delay (0-500 ms). REAPER then sends this track's MIDI that much earlier,\n"
    .. "so the changes happen on the beat.")

  local cx = UI.row_start("Track")
  local tr = Dev.track(d)
  UI.row_text(tr and Dev.track_name(tr) or "No track in this project yet", tr and COL.TEXT_MAIN or COL.YELLOW)
  if tr then UI.tip("The track where MIDI Pilot writes this device's MIDI.") end
  ImGui.SetCursorPosX(ctx, cx)
  local _, tcw = UI.form("Track")
  local half = math.floor((UI.fit_w(tcw) - CFG.CTRL_GAP) / 2)
  if UI.button("Create track", half, nil, not tr and "primary" or nil) then Dev.create_track(d) end
  UI.tip("Add a new track for this device, at the end of the project.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local has_sel = r.GetSelectedTrack(R.proj, 0) ~= nil
  ImGui.BeginDisabled(ctx, not has_sel)
  if UI.button("Use selected track", half) then Dev.use_selected_track(d) end
  ImGui.EndDisabled(ctx)
  UI.tip(has_sel and "Use the selected track for this device." or "Select a track in REAPER first.")

end

-- Settings > Devices: the device list, then the selected device.
function UI.set_devices()
  if not R.ports_t or Util.now() - R.ports_t > CFG.PORTS_SEC then Dev.read_ports() end
  UI.draw_device_list()
  UI.draw_device_form()
  UI.set_tracks()
end
-- Settings > Devices > Tracks in the project: the track mode, Check new MIDI items.
function UI.set_tracks()
  local ch, cw, _
  UI.heading("Tracks in the project", "One track for each device (the default), or 1 shared track for all devices "
    .. "(their MIDI channels keep them apart). Saved in this project.\n\n"
    .. "Check new MIDI items: hold the mouse on it for details. Saved on this computer.")
  _, cw = UI.row_start("Track mode")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local ti = (P.track_mode == "shared") and 1 or 0
  ch, ti = ImGui.Combo(ctx, "##trackmode", ti, TRACK_MODE_ITEMS)
  if ch then
    P.track_mode = (ti == 1) and "shared" or "own"; Util.mark_pdirty(); R.conflicts = nil; R.pcs = {}
    for _, d in ipairs(S.devices) do Dev.apply_out(d); Dev.apply_latency(d) end
  end
  UI.tip("Shared track: the devices must use different MIDI channels and the same MIDI output.")
  local cich
  cich, S.check_items = UI.checkbox("Check new MIDI items", S.check_items,
    "On: when you paste, drag or record a MIDI item on a device's track, MIDI Pilot sets it to the device's MIDI\n"
    .. "channel (it asks when the item uses several channels) and adds a first Scene to each song in it that has none.\n"
    .. "Ctrl+Z removes the added Scenes.")
  if cich then Util.mark_sdirty() end
end
-- Settings > Editing: the preset settings, the scene settings and the nudge.
function UI.set_editing()
  local ch, cw, _
  -- the amount rows of a section ("pc" or "sc"): By (ms / note value) and the value
  local function amount_rows(kind, off)
    local uk, mk, nk = kind .. "_unit", kind .. "_ms", kind .. "_note"
    ImGui.BeginDisabled(ctx, off)
    _, cw = UI.row_start("By")
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
    local ui = (S[uk] == "notes") and 1 or 0
    ch, ui = ImGui.Combo(ctx, "##" .. kind .. "unit", ui, PC_UNIT_ITEMS)
    if ch then S[uk] = (ui == 1) and "notes" or "ms"; Util.mark_sdirty() end
    UI.tip("Milliseconds: a fixed time. Note value: follows the tempo (stays on the grid).")
    _, cw = UI.row_start(S[uk] == "notes" and "Note value" or "Milliseconds")
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
    if S[uk] == "notes" then
      local ni
      ch, ni = ImGui.Combo(ctx, "##" .. kind .. "note", S[nk] - 1, PC_NOTE_ITEMS)
      if ch then S[nk] = ni + 1; Util.mark_sdirty() end
      UI.tip("How far before or after, as a note value.")
    else
      local ms
      ch, ms = UI.input_int("##" .. kind .. "ms", S[mk], 50)
      if ch then S[mk] = Util.clamp(ms, 0, CFG.PC_MS_MAX); Util.mark_sdirty() end
      UI.tip("How many milliseconds before or after (0-2000).")
    end
    ImGui.EndDisabled(ctx)
  end
  local OTHER_ITEMS = "Exactly at the edit cursor\0Before the edit cursor\0After the edit cursor\0"
  local OTHER_IDS = { "exact", "before", "after" }
  local function other_row(label, id, key, tip)
    _, cw = UI.row_start(label)
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
    local oi = 0
    for k, w in ipairs(OTHER_IDS) do if w == S[key] then oi = k - 1 end end
    ch, oi = ImGui.Combo(ctx, id, oi, OTHER_ITEMS)
    if ch then S[key] = OTHER_IDS[oi + 1]; Util.mark_sdirty() end
    UI.tip(tip)
  end

  UI.heading("Preset settings", "First Preset: when the Preset change of a song comes. The unit needs a moment to "
    .. "load a Preset, so 'Before the song start' (250 ms) has it ready on time.\nOther Presets: a Preset that you add "
    .. "inside a song (Preset change..., Presets from markers): exactly at the edit cursor or marker, or before or after it.\n"
    .. "By: the amount for both.\n\nREAPER's Snap on (the N key): an add at the edit cursor goes to the nearest grid line first.\n\n"
    .. "Used for new changes. Saved on this computer.")
  _, cw = UI.row_start("First Preset")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local wi = 0
  for k, w in ipairs(PC_WHEN) do if w == S.pc_when then wi = k - 1 end end
  ch, wi = ImGui.Combo(ctx, "##pcwhen", wi, PC_WHEN_ITEMS)
  if ch then S.pc_when = PC_WHEN[wi + 1]; Util.mark_sdirty() end
  UI.tip("The first Preset of a song. Before: ready when the song starts. Exactly: at the song start. After: a moment after the start.")
  other_row("Other Presets", "##pcother", "pc_other",
    "A Preset that you add inside a song (Preset change..., Presets from markers): exactly at the edit cursor or marker,\nor the amount before or after it.")
  amount_rows("pc", S.pc_when == "exact" and S.pc_other == "exact")

  UI.heading("Scene settings", "First Scene: where 'Set up songs' puts the first Scene of a song: at the region "
    .. "start, before or after it, or after the region's Preset (the amount after the song's Preset change, never before "
    .. "the region start).\nOther Scenes: a Scene that you add (Add Scene list, Scene keys, Scenes from markers): exactly "
    .. "at the edit cursor or marker, or before or after it.\nBy: the amount for both. A note value stays on the grid.\n\n"
    .. "Scene keys: with the MIDI Pilot window active, keys 1-8 add that Scene at the edit cursor.\n\nSaved on this computer.")
  _, cw = UI.row_start("First Scene")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local FIRST_IDS = { "start", "before", "after", "after_pc" }
  local fi = 0
  for k, w in ipairs(FIRST_IDS) do if w == S.sc_first then fi = k - 1 end end
  ch, fi = ImGui.Combo(ctx, "##scfirst", fi,
    "At the region start\0Before the region start\0After the region start\0After the region's Preset\0")
  if ch then S.sc_first = FIRST_IDS[fi + 1]; Util.mark_sdirty() end
  UI.tip("Where Set up songs puts the first Scene of a song. 'After the region's Preset': the amount after the\n"
    .. "song's Preset change (so the unit loads the Preset first), never before the region start.")
  other_row("Other Scenes", "##scother", "sc_other",
    "A Scene that you add (Add Scene list, Scene keys, Scenes from markers): exactly at the edit cursor or marker,\nor the amount before or after it.")
  amount_rows("sc", S.sc_first == "start" and S.sc_other == "exact")
  local skch
  skch, S.scene_keys = UI.checkbox("Scene keys", S.scene_keys,
    "On: keys 1-8 (also on the numpad) add Scene 1-8 at the edit cursor, when the MIDI Pilot window is active\n"
    .. "and you are not typing in a field. Each key is 1 undo step.")
  if skch then Util.mark_sdirty() end

  UI.heading("Nudge", "How far the nudge triangles move a change: the left one earlier, the right one later.\n\n"
    .. "Saved on this computer.")
  _, cw = UI.row_start("By")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local nui = (S.nudge_unit == "notes") and 1 or 0
  ch, nui = ImGui.Combo(ctx, "##nunit", nui, PC_UNIT_ITEMS)
  if ch then S.nudge_unit = (nui == 1) and "notes" or "ms"; Util.mark_sdirty() end
  UI.tip("Milliseconds: a fixed time. Note value: follows the tempo.")
  _, cw = UI.row_start(S.nudge_unit == "notes" and "Note value" or "Milliseconds")
  if S.nudge_unit == "notes" then
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
    local nni
    ch, nni = ImGui.Combo(ctx, "##nnote", S.nudge_note - 1, PC_NOTE_ITEMS)
    if ch then S.nudge_note = nni + 1; Util.mark_sdirty() end
    UI.tip("How far 1 click moves a change, as a note value.")
  else
    local nms
    ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
    ch, nms = UI.input_int("##nms", S.nudge_ms, 5)
    if ch then S.nudge_ms = Util.clamp(nms, 1, CFG.NUDGE_MS_MAX); Util.mark_sdirty() end
    UI.tip("How far 1 click moves a change (1-1000 ms).")
  end
end
-- The toolbar (above the tabs, as in Chart Cue): each item can be hidden (right-click; Settings > Appearance >
-- Toolbar). TB_ITEMS: { key, name }.
local TB_ITEMS = {
  { "dev", "Device" }, { "nav", "Previous / next song" }, { "now", "Cursor info" },
  { "snap", "Snap button" }, { "send", "Send state button" }, { "setup", "Set up songs button" },
  { "strip", "Scene timelines button" }, { "export", "Export MIDI button" },
}
local TB_NAME = {}
for _, it in ipairs(TB_ITEMS) do TB_NAME[it[1]] = it[2] end
-- Settings > Appearance: the theme, the scene strips, after how many rows a list scrolls.
function UI.set_appearance()
  local ch, cw, _
  UI.heading("Look", "Theme: Dark (the default) or Light.\nScene timelines: the coloured timeline of Scenes under each song "
    .. "(Songs tab). Off: a shorter song list; the Scene lists stay.\n\nSaved on this computer.")
  _, cw = UI.row_start("Theme")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local thi
  ch, thi = ImGui.Combo(ctx, "##theme", S.theme == "light" and 1 or 0, "Dark\0Light\0")
  if ch then S.theme = (thi == 1) and "light" or "dark"; apply_theme(S.theme); Util.mark_sdirty() end
  UI.tip("Dark: for dark rooms. Light: for daylight.")
  local sch
  sch, S.show_strip = UI.checkbox("Scene timelines", S.show_strip,
    "On: the coloured timeline of Scenes under each song (Songs tab). Off: a shorter song list.")
  if sch then Util.mark_sdirty() end

  UI.heading("List sizes", "How many rows a list shows before it scrolls (Scene lists in Songs, value lists in Lanes).\n\n"
    .. "Saved on this computer.")
  _, cw = UI.row_start("Scene rows")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local sr
  ch, sr = UI.input_int("##srows", S.scene_rows, 1)
  if ch then S.scene_rows = Util.clamp(sr, 3, 100); Util.mark_sdirty() end
  UI.tip("A song's Scene list scrolls after this many rows (3-100).")
  _, cw = UI.row_start("Value rows")
  ImGui.SetNextItemWidth(ctx, UI.fit_w(cw))
  local lr
  ch, lr = UI.input_int("##lrows", S.lane_rows, 1)
  if ch then S.lane_rows = Util.clamp(lr, 3, 100); Util.mark_sdirty() end
  UI.tip("A song's values in Lanes scroll after this many rows (3-100).")

  UI.heading("Tabs", "Hide the tabs that you do not use. Settings and Help always show. A right-click on a tab "
    .. "also hides it.\n\nSaved on this computer.")
  for i, nm in ipairs(TAB_NAMES) do
    local tch, tv = UI.checkbox(nm, not S.tab_hide[i], "Show the " .. nm .. " tab.")
    if tch then S.tab_hide[i] = (not tv) or nil; Util.mark_sdirty() end
  end

  UI.heading("Toolbar", "The toolbar above the tabs and its items. A right-click on an item hides it; a right-click "
    .. "on the toolbar hides all of it.\n\nSaved on this computer.")
  local och, ov = UI.checkbox("Show toolbar", not S.tb_off, "On: the toolbar above the tabs. Off: no toolbar.")
  if och then S.tb_off = not ov; Util.mark_sdirty() end
  ImGui.BeginDisabled(ctx, S.tb_off)
  for _, it in ipairs(TB_ITEMS) do
    local tch, tv = UI.checkbox(it[2], not S.tb_hide[it[1]], it[1] == "now" and "Show the song, Preset and Scene at the edit cursor in the toolbar."
      or ("Show the " .. it[2]:gsub("^%u", string.lower) .. " in the toolbar."))
    if tch then S.tb_hide[it[1]] = (not tv) or nil; Util.mark_sdirty() end
  end
  ImGui.EndDisabled(ctx)
end
-- Settings > General: the preset names file, the docker, the version.
function UI.set_general()
  UI.heading("Preset names in REAPER", "MIDI Pilot writes your Preset names into a bank file. Load it in ReaControlMIDI "
    .. "on a device's track (Bank/Program Select > Load File) to see '3B Song One' in REAPER instead of numbers. Leave "
    .. "'Enable' off in ReaControlMIDI. The file updates when you change a name.")
  UI.row_start("Preset names file")
  UI.row_text(UI.trunc(Preset.reabank_path(), math.max(60, ImGui.GetContentRegionAvail(ctx) - 10)), COL.TEXT_DIM)
  UI.tip(Preset.reabank_path())
  local gx, gcw = UI.form("Preset names file")
  ImGui.SetCursorPosX(ctx, gx)
  local ghalf = math.floor((UI.fit_w(gcw) - CFG.CTRL_GAP) / 2)
  if UI.button("Copy the path", ghalf) then ImGui.SetClipboardText(ctx, Preset.reabank_path()) end
  UI.tip("Copy the file path (to paste it in REAPER's file window).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Make it now", ghalf) then Preset.write_reabank() end
  UI.tip("Write the file again now.")
  UI.heading("Window", "Dock in docker: MIDI Pilot in a REAPER docker, or a floating window.\nShow Getting started: the "
    .. "list of first steps at the top of the Songs tab.\n\nSaved on this computer.")
  local docked = R.docked == true
  if UI.checkbox("Dock in docker", docked, "On: MIDI Pilot is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if UI.checkbox("Show Getting started", not S.start_hide, "On: the Getting started list at the top of the Songs tab, "
    .. "until every step is done or skipped.\nTurning it on also brings back the skipped steps. Saved on this computer.") then
    S.start_hide = not S.start_hide
    if not S.start_hide then S.start_skip = {} end
    Util.mark_sdirty()
  end
  UI.heading("Backup", "Back up...: every MIDI Pilot setting of this computer in 1 file (its name has the date and time): the devices, the Preset, "
    .. "folder and Scene names, the Scene colours, the pedal assignments, the controls and the options. The file goes "
    .. "into REAPER's Data\\MIDI Pilot folder.\nRestore...: choose a backup file; it replaces all MIDI Pilot settings of "
    .. "this computer.\n\nThe projects do not change.")
  UI.row_start("Backup folder")
  UI.row_text(UI.trunc(Util.backup_dir(), math.max(60, ImGui.GetContentRegionAvail(ctx) - 10)), COL.TEXT_DIM)
  UI.tip(Util.backup_dir())
  local bx, bcw = UI.form("Backup folder")
  ImGui.SetCursorPosX(ctx, bx)
  local bhalf = math.floor((UI.fit_w(bcw) - CFG.CTRL_GAP) / 2)
  if UI.button("Back up...", bhalf) then
    local path, err = Util.backup()
    if path then
      UI.ask("Backup saved:\n" .. path, "Open the folder", function() Util.open_folder(path:match("^(.*)[/\\]")) end)
    else UI.toast(err, true) end
  end
  UI.tip("Save every MIDI Pilot setting of this computer in 1 file.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Restore...", bhalf) then
    local okf, path = r.GetUserFileNameForRead(Util.backup_dir() .. "/", "Restore MIDI Pilot settings", ".txt")
    if okf and path ~= "" then
      UI.ask("Replace all MIDI Pilot settings of this computer with this backup?\n" .. path, "Replace", function()
        local okr, err = Util.restore(path)
        UI.toast(okr and "The settings of the backup are back." or err, not okr)
      end)
    end
  end
  UI.tip("Load a backup file. It asks before it replaces anything.")
  UI.vgap(8)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "MIDI Pilot " .. CFG.VERSION .. "  -  MIT license")
end

-- The Settings tab: 1 section open at a time (as in Chart Cue); a click on a section closes the open one. The open
-- section is saved (S.settings_open: 0 = none).
local SETTINGS_SECTIONS = {
  { "Devices", UI.set_devices }, { "Editing", UI.set_editing }, { "Appearance", UI.set_appearance },
  { "General", UI.set_general },
}
function UI.draw_settings_tab()
  for i, sec in ipairs(SETTINGS_SECTIONS) do
    ImGui.SetNextItemOpen(ctx, S.settings_open == i)
    local open = ImGui.CollapsingHeader(ctx, sec[1] .. "##settings" .. i)
    if open ~= (S.settings_open == i) then S.settings_open = open and i or 0; Util.mark_sdirty() end
    if open then
      ImGui.Indent(ctx, 8)
      ImGui.PushID(ctx, sec[1]) -- the sections share 1 panel: their IDs stay apart
      sec[2]()
      ImGui.PopID(ctx)
      ImGui.Unindent(ctx, 8)
      UI.vgap(10)
    end
  end
end

-- A topic text with its formatting: "# " a bold sub-heading, "- " a bullet, "1. " a numbered step, an empty line a gap.
function UI.help_text(text)
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line == "" then UI.vgap(CFG.SP_ROW + 4)
    elseif line:sub(1, 2) == "# " then
      UI.vgap(CFG.SP_ROW + 4)
      ImGui.PushFont(ctx, bold)
      ImGui.TextColored(ctx, COL.TEXT_BRIGHT, line:sub(3))
      ImGui.PopFont(ctx)
    elseif line:sub(1, 2) == "- " then
      ImGui.Bullet(ctx)
      ImGui.SameLine(ctx, 0, 6)
      UI.note(line:sub(3), COL.TEXT_MAIN)
    else
      local num, rest = line:match("^(%d+%.)%s+(.*)$")
      if num then
        ImGui.TextColored(ctx, COL.TEXT_DIM, num)
        ImGui.SameLine(ctx, 0, 6)
        UI.note(rest, COL.TEXT_MAIN)
      else UI.note(line, COL.TEXT_MAIN) end
    end
  end
end

function UI.draw_help_tab()
  UI.heading("Help")
  UI.note(HELP_INTRO, COL.TEXT_MAIN)
  UI.vgap(10)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Topics - click a topic to open it")
  for i, tp in ipairs(HELP_TOPICS) do
    ImGui.SetNextItemOpen(ctx, R.help_cur == i)
    local open = ImGui.CollapsingHeader(ctx, tp.title .. "##help" .. i)
    if open ~= (R.help_cur == i) then R.help_cur = open and i or nil end
    if open then
      ImGui.Indent(ctx, 10)
      UI.help_text(tp.text)
      ImGui.Unindent(ctx, 10)
      UI.vgap(8)
    end
  end
end

-- The window: the tab strip and the panel of the open tab (a rounded area that scrolls).
-- The status bar (as in Chart Cue), at the bottom of the window. Line 1: the device, its output and channel, and
-- the song, preset and scene at the play position (stopped: the edit cursor). Line 2: the most important message
-- (problems first, then hints), else a short help line. Made again every CFG.STATUS_SEC, not every frame.
function UI.status_lines()
  local now = Util.now()
  local c = R.status
  if c and now - c.t0 < CFG.STATUS_SEC and c.pcs == R.pcs then return c end
  if not R.ports_t or now - R.ports_t > CFG.PORTS_SEC then Dev.read_ports() end -- (an output that was unplugged)
  c = { t0 = now, pcs = R.pcs }
  R.cur_dev = Util.clamp(R.cur_dev or 1, 1, math.max(1, #S.devices))
  local d = S.devices[R.cur_dev]
  if not d then
    c.dev, c.dev_col, c.l1, c.l2, c.col = "No device yet.", COL.YELLOW, "", "Add your Quad Cortex in Settings > Devices.", COL.YELLOW
    R.status = c; return c
  end
  local playing = Util.playing()
  local tc = playing and r.GetPlayPosition() or r.GetCursorPosition()
  -- the device and its state: green READY, red NOT AVAILABLE (line 2 does not repeat it)
  local ready = d.port ~= "" and (#R.ports == 0 or Dev.port_index(d.port) ~= nil)
  local chan = d.chan == 0 and "all channels" or ("channel " .. d.chan)
  if d.port == "" then c.dev = d.name .. ": no MIDI output selected (Settings > Devices)"
  else
    c.dev = d.name .. ": " .. d.port .. ", " .. chan .. (ready and " is READY" or " is NOT AVAILABLE")
      .. ((not ready and playing) and ": the unit gets nothing" or "")
  end
  c.dev_col = ready and COL.GREEN or COL.RED
  c.reset = d.port ~= "" and not ready -- (line 1 then has "Reset MIDI" in place of "Send state")
  local parts = {}
  local rg = Midi.song_at(tc)
  local tr = Dev.track(d)
  if rg and tr then
    local pc = Midi.preset_at(d, rg, tc)
    local sv
    for _, s in ipairs(Midi.scenes(d)) do if s.t <= tc + CFG.EDGE then sv = s.v else break end end
    local st = Midi.start_scene(d, rg) -- (before the start scene, at the song start: the song's own start scene)
    if st and tc < st.t then sv = st.v end
    local pname = pc and Preset.text(d, pc.folder, pc.index) or "no Preset"
    local sname = sv and Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, sv)
    parts[#parts + 1] = (playing and "Playing: " or "At the cursor: ") .. (rg.name ~= "" and rg.name or "(no name)")
      .. ", " .. pname .. (sname and (", " .. sname) or "")
    c.now = (rg.name ~= "" and rg.name or "(no name)") .. "  ·  " .. pname .. (sname and ("  ·  " .. sname) or "")
  elseif not rg and #R.regions > 0 then
    parts[#parts + 1] = (playing and "Playing" or "The cursor is") .. " outside the songs"
  end
  c.l1 = #parts > 0 and ("   |   " .. table.concat(parts, "   |   ")) or ""
  -- line 2, by priority: device problems > no track > no songs > hints
  local warns = {}
  local own = d.name .. ": " -- (the selected device's own output state is on line 1)
  for _, w in ipairs(Dev.conflicts()) do
    local mine = w:sub(1, #own) == own and (w:find("not available", 1, true) or w:find("no MIDI output", 1, true))
    if not mine then warns[#warns + 1] = w end
  end
  if #warns > 0 then
    c.l2 = warns[1] .. (#warns > 1 and string.format("  (+%d more: Settings > Devices)", #warns - 1) or "")
    c.col = COL.RED
  elseif not tr then
    c.l2, c.col = d.name .. " has no track in this project yet: Settings > Devices > Create track.", COL.YELLOW
  elseif #R.regions == 0 then
    c.l2, c.col = "This project has no regions: make 1 region for each song.", COL.YELLOW
  else
    local nopre, nostart, test_song = 0, 0, nil
    for _, x in ipairs(R.regions) do
      if not Midi.song_change(d, x) then nopre = nopre + 1 end
      if not Midi.start_scene(d, x) then nostart = nostart + 1 end
      if not test_song and not P.test_ok[x.name] and #Midi.song_tests(d, x) > 0 then test_song = x end
    end
    c.setup_done = nopre == 0 and nostart == 0 -- (Getting started, step 6)
    if test_song then
      c.l2, c.col = "'" .. (test_song.name ~= "" and test_song.name or "A song") .. "' still has a Scene test (its red X in the Scene list removes it).", COL.YELLOW
      c.ignore = test_song
    elseif nopre > 0 then
      c.l2, c.col = string.format("%d song(s) without their own Preset (grey): Songs > Set up songs gives them the Preset that plays.", nopre), COL.YELLOW
    elseif nostart > 0 then
      c.l2, c.col = string.format("%d song(s) without a start Scene: Songs > Set up songs adds them.", nostart), COL.YELLOW
    else
      c.l2, c.col = "Ready: every song has its Preset and start Scene. REAPER plays them from the track; this window can stay closed.", COL.TEXT_DIM
    end
  end
  R.status = c
  return c
end

function UI.draw_status(y)
  local c = UI.status_lines()
  local aw = ImGui.GetContentRegionAvail(ctx)
  ImGui.SetCursorPosY(ctx, y)
  ImGui.Indent(ctx, 6)
  local dev = UI.trunc(c.dev, aw - 12)
  ImGui.TextColored(ctx, c.dev_col, dev)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, c.dev) end
  -- Send state now: a small button at the end of line 1
  local sbw = ImGui.CalcTextSize(ctx, c.reset and "Reset MIDI" or "Send state") + 18
  local d0 = S.devices[R.cur_dev or 1]
  if c.l1 ~= "" and dev == c.dev then
    local left = aw - 12 - (ImGui.CalcTextSize(ctx, dev)) - sbw - 8
    if left > 40 then
      ImGui.SameLine(ctx, 0, 0)
      ImGui.TextColored(ctx, COL.TEXT_MAIN, UI.trunc(c.l1, left))
      if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, c.l1:sub(8)) end
    end
  end
  if c.reset then
    ImGui.SameLine(ctx, math.max(ImGui.GetCursorPosX(ctx), aw - sbw + 6))
    if UI.small_button("Reset MIDI##resetmidi") then Dev.reset_midi() end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Restarts REAPER's MIDI devices. Use it after you unplug or restart a unit.")
    end
  elseif d0 and Dev.track(d0) then
    ImGui.SameLine(ctx, math.max(ImGui.GetCursorPosX(ctx), aw - sbw + 6))
    if UI.small_button("Send state##sendstate") then
      local tc = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
      if Midi.send_state(d0, tc) then UI.toast(d0.name .. ": the Preset, Scene and control values at " .. Util.fmt_beats(tc) .. " were sent.")
      else UI.toast(d0.name .. ": the MIDI output is not available.", true) end
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Sends the Preset, Scene and pedal values at the edit cursor to " .. d0.name .. " now.\n"
        .. "For a soundcheck, or after the unit restarts.")
    end
  end
  -- a fresh notice (UI.toast) first, for CFG.TOAST_SEC: the status bar is always visible (the title lines can be
  -- scrolled away); a problem in red, else green
  local tt = R.toast
  if tt and Util.now() - tt.t0 <= CFG.TOAST_SEC then
    ImGui.TextColored(ctx, tt.warn and COL.RED or COL.GREEN, UI.trunc(tt.text, aw - 12))
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, tt.text) end
    ImGui.Unindent(ctx, 6)
    return
  end
  local bw = c.ignore and (ImGui.CalcTextSize(ctx, "Ignore") + 16) or 0
  ImGui.TextColored(ctx, c.col, UI.trunc(c.l2, aw - 12 - bw))
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, c.l2) end
  if c.ignore then
    ImGui.SameLine(ctx, 0, 8)
    if UI.small_button("Ignore##sttest") then
      P.test_ok[c.ignore.name] = true; Util.mark_pdirty(); R.status = nil
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Hide this reminder for '" .. c.ignore.name .. "' (saved in this project).")
    end
  end
  ImGui.Unindent(ctx, 6)
end

-- Settings > Editing > Scene keys: with the window active and no text field in use, keys 1-8 add that scene at the
-- edit cursor (during playback: the play position), in the song there, for the device of the tabs.
function UI.scene_keys()
  if not S.scene_keys or ImGui.IsAnyItemActive(ctx) or ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId())
    or not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) then return end
  local d = S.devices[R.cur_dev or 1]
  if not d then return end
  for v = 1, math.min(8, Midi.nsc(d)) do
    if ImGui.IsKeyPressed(ctx, ImGui["Key_" .. v](), false) or ImGui.IsKeyPressed(ctx, ImGui["Key_Keypad" .. v](), false) then
      local tc = Util.add_pos()
      local rg = Midi.song_at(tc)
      if not Dev.track(d) then UI.toast(d.name .. " has no track in this project yet.", true)
      elseif not rg then UI.toast("Put the edit cursor inside a song.", true)
      else
        local ts = Midi.other_time("sc", tc)
        Midi.add_scene(d, ts, v - 1)
        local pc = Midi.preset_at(d, rg, ts)
        UI.toast(Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v - 1) .. " at " .. Util.fmt_beats(ts) .. ".")
      end
    end
  end
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape(), false) then R.song_sel = nil end
end

-- A toolbar icon centred at cx, cy (s: half size).
function UI.tb_icon(dl, cx, cy, s, kind, col)
  if kind == "prev" or kind == "next" then
    local dir = kind == "next" and 1 or -1
    ImGui.DrawList_AddTriangleFilled(dl, cx - dir * s * 0.6, cy - s, cx - dir * s * 0.6, cy + s, cx + dir * s * 0.8, cy, col)
  elseif kind == "magnet" then -- a U with 2 pole tips
    local r0, top = s * 0.8, cy - s
    local px, py
    for i = 0, 10 do
      local a = math.pi * i / 10
      local qx, qy = cx - math.cos(a) * r0, cy + math.sin(a) * r0
      if px then ImGui.DrawList_AddLine(dl, px, py, qx, qy, col, 3) end
      px, py = qx, qy
    end
    ImGui.DrawList_AddLine(dl, cx - r0, cy, cx - r0, top, col, 3)
    ImGui.DrawList_AddLine(dl, cx + r0, cy, cx + r0, top, col, 3)
    ImGui.DrawList_AddLine(dl, cx - r0 - 1.5, top + 1, cx - r0 + 1.5, top + 1, COL.RED, 3)
    ImGui.DrawList_AddLine(dl, cx + r0 - 1.5, top + 1, cx + r0 + 1.5, top + 1, COL.RED, 3)
  elseif kind == "send" then
    ImGui.DrawList_AddTriangleFilled(dl, cx - s * 0.6, cy - s, cx - s * 0.6, cy + s, cx + s * 0.9, cy, col)
  elseif kind == "tick" then
    ImGui.DrawList_AddLine(dl, cx - s, cy, cx - s * 0.3, cy + s * 0.7, col, 2.5)
    ImGui.DrawList_AddLine(dl, cx - s * 0.3, cy + s * 0.7, cx + s, cy - s * 0.8, col, 2.5)
  elseif kind == "scenes" then -- 3 blocks in a row (a Scene timeline)
    for k = -1, 1 do
      local bx = cx + k * (s * 0.75)
      ImGui.DrawList_AddRectFilled(dl, bx - s * 0.3, cy - s * 0.7, bx + s * 0.3, cy + s * 0.7, col, 1)
    end
  elseif kind == "export" then -- an arrow up out of a tray
    ImGui.DrawList_AddLine(dl, cx - s, cy + s * 0.2, cx - s, cy + s, col, 2)
    ImGui.DrawList_AddLine(dl, cx - s, cy + s, cx + s, cy + s, col, 2)
    ImGui.DrawList_AddLine(dl, cx + s, cy + s, cx + s, cy + s * 0.2, col, 2)
    ImGui.DrawList_AddLine(dl, cx, cy + s * 0.5, cx, cy - s, col, 2)
    ImGui.DrawList_AddTriangleFilled(dl, cx - s * 0.5, cy - s * 0.4, cx + s * 0.5, cy - s * 0.4, cx, cy - s - 1, col)
  end
end
-- A toolbar button: an icon; on (a toggle): a lighter button and a bright icon, else a grey icon. A right-click
-- opens the "Hide ..." menu of item key. Returns clicked and hovered (the caller shows its tooltip then).
function UI.tb_button(key, kind, on, size)
  local hit = ImGui.InvisibleButton(ctx, "##tb" .. kind, size, size)
  local hov = ImGui.IsItemHovered(ctx)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  if on or hov then ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + size, y0 + size, on and COL.FIELD_HOVER or COL.TAB_HOVER, 5) end
  local col = (on or hov) and COL.TEXT_BRIGHT or (on == nil and COL.TEXT_MAIN or COL.TEXT_DIM)
  UI.tb_icon(dl, math.floor(x0 + size / 2) + 0.5, math.floor(y0 + size / 2) + 0.5, math.floor(size * 0.3), kind, col)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  if ImGui.IsItemClicked(ctx, 1) then R.tb_menu = key end
  return hit, hov
end
function UI.draw_toolbar()
  if S.tb_off then return end
  local _, bar_y0 = ImGui.GetCursorScreenPos(ctx)
  local fh = ImGui.GetFrameHeight(ctx)
  local gap = CFG.CTRL_GAP
  local h = S.tb_hide
  local aw = ImGui.GetContentRegionAvail(ctx)
  local d = S.devices[Util.clamp(R.cur_dev or 1, 1, math.max(1, #S.devices))]
  local tc = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
  -- the right group: Snap, Send state, Set up songs, Scene timelines, Export
  local right = {}
  if not h.snap then right[#right + 1] = "snap" end
  if d and not h.send then right[#right + 1] = "send" end
  if d and not h.setup then right[#right + 1] = "setup" end
  if not h.strip then right[#right + 1] = "strip" end
  if d and not h.export then right[#right + 1] = "export" end
  local x0 = ImGui.GetCursorPosX(ctx)
  local rx = x0 + aw - #right * (fh + gap) + gap
  local any = false
  if d and not h.dev then
    local w = math.floor((ImGui.CalcTextSize(ctx, d.name)) + fh + 18)
    ImGui.SetNextItemWidth(ctx, w)
    if ImGui.BeginCombo(ctx, "##tbdev", d.name) then
      for i, x in ipairs(S.devices) do
        if ImGui.Selectable(ctx, x.name .. "##tbd" .. i, i == R.cur_dev) then R.cur_dev = i; R.status = nil end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("The device that the tabs show. Right-click: hide.")
    if ImGui.IsItemClicked(ctx, 1) then R.tb_menu = "dev" end
    any = true
  end
  if d and not h.nav then
    if any then ImGui.SameLine(ctx, 0, gap) end
    local hit, hov = UI.tb_button("nav", "prev", nil, fh)
    if hov then ImGui.SetTooltip(ctx, "Previous song: the edit cursor goes to its start.") end
    if hit then
      local t
      for _, rg in ipairs(R.regions) do if rg.start < tc - CFG.EDGE then t = rg.start end end
      if t then r.SetEditCurPos(t, true, false) end
    end
    ImGui.SameLine(ctx, 0, 2)
    local hit, hov = UI.tb_button("nav", "next", nil, fh)
    if hov then ImGui.SetTooltip(ctx, "Next song: the edit cursor goes to its start.") end
    if hit then
      for _, rg in ipairs(R.regions) do if rg.start > tc + CFG.EDGE then r.SetEditCurPos(rg.start, true, false); break end end
    end
    any = true
  end
  if d and not h.now and R.status and R.status.now then
    if any then ImGui.SameLine(ctx, 0, 2 * gap) end
    local room = rx - ImGui.GetCursorPosX(ctx) - 2 * gap
    if room > 40 then
      UI.row_text(UI.trunc(R.status.now, room), COL.TEXT_MAIN)
      if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "At the edit cursor: " .. R.status.now .. ".\nRight-click: hide.") end
      if ImGui.IsItemClicked(ctx, 1) then R.tb_menu = "now" end
      any = true
    end
  end
  for i, key in ipairs(right) do
    if any or i > 1 then ImGui.SameLine(ctx, rx + (i - 1) * (fh + gap)) else ImGui.SetCursorPosX(ctx, rx) end
    if key == "snap" then
      local on = r.GetToggleCommandState(1157) == 1
      local hit, hov = UI.tb_button("snap", "magnet", on, fh)
      if hov then ImGui.SetTooltip(ctx, "Snap (REAPER): " .. (on and "on" or "off") .. ". An add at the edit cursor goes to the nearest grid line.\nClick: turn it " .. (on and "off" or "on") .. ". Right-click: hide.") end
      if hit then
        r.Main_OnCommand(1157, 0)
      end
    elseif key == "send" then
      local hit, hov = UI.tb_button("send", "send", nil, fh)
      if hov then ImGui.SetTooltip(ctx, "Send state: the Preset, Scene and control values at the edit cursor to " .. d.name .. ".\nRight-click: hide.") end
      if hit then
        if Midi.send_state(d, tc) then UI.toast(d.name .. ": the Preset, Scene and control values at " .. Util.fmt_beats(tc) .. " were sent.")
        else UI.toast(d.name .. ": the MIDI output is not available.", true) end
      end
    elseif key == "setup" then
      local hit, hov = UI.tb_button("setup", "tick", nil, fh)
      if hov then ImGui.SetTooltip(ctx, "Set up songs: each song gets its Preset and first Scene. Ctrl+Z takes it back.\nRight-click: hide.") end
      if hit then
        if not Dev.track(d) then UI.toast(d.name .. " has no track in this project yet.", true)
        else
          local n = Midi.fill_starts(d)
          R.status = nil
          UI.toast(n == 0 and "Every song has its Preset and start Scene." or string.format("%d change(s) added.", n))
        end
      end
    elseif key == "strip" then
      local hit, hov = UI.tb_button("strip", "scenes", S.show_strip, fh)
      if hov then ImGui.SetTooltip(ctx, "Scene timelines (Songs tab): " .. (S.show_strip and "on" or "off") .. ".\nClick: turn them " .. (S.show_strip and "off" or "on") .. ". Right-click: hide.") end
      if hit then
        S.show_strip = not S.show_strip; Util.mark_sdirty()
      end
    elseif key == "export" then
      local hit, hov = UI.tb_button("export", "export", nil, fh)
      if hov then ImGui.SetTooltip(ctx, "Export MIDI...: " .. d.name .. " as a standard MIDI file.\nRight-click: hide.") end
      if hit then
        R.exp = { d = d, per_song = false, open = true }
      end
    end
    any = true
  end
  if not any then ImGui.Dummy(ctx, 1, fh) end
  -- a right-click on the empty part of the toolbar: its menu (only "Hide toolbar")
  local mx, my = ImGui.GetMousePos(ctx)
  if ImGui.IsMouseClicked(ctx, 1) and not ImGui.IsAnyItemHovered(ctx) and ImGui.IsWindowHovered(ctx)
    and my >= bar_y0 and my < bar_y0 + fh and mx >= 0 then R.tb_menu = "bar" end
  -- the right-click menu: hide the item, or the whole toolbar
  if R.tb_menu then ImGui.OpenPopup(ctx, "##tbmenu"); R.tb_key, R.tb_menu = R.tb_menu, nil end
  if ImGui.BeginPopup(ctx, "##tbmenu") then
    if R.tb_key and TB_NAME[R.tb_key] and ImGui.Selectable(ctx, "Hide " .. TB_NAME[R.tb_key]) then
      S.tb_hide[R.tb_key] = true; Util.mark_sdirty()
    end
    if ImGui.Selectable(ctx, "Hide toolbar") then
      S.tb_off = true; Util.mark_sdirty()
      UI.toast("The toolbar is hidden. Settings > Appearance > Toolbar > Show toolbar shows it again.")
    end
    ImGui.EndPopup(ctx)
  end
  UI.vgap(4)
end
function UI.draw_main()
  R.dev_head = nil
  UI.scene_keys()
  UI.draw_toolbar()
  UI.draw_tabs()
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  local status_h = 2 * ImGui.GetTextLineHeightWithSpacing(ctx) + 4
  local status_y = ImGui.GetCursorPosY(ctx) + ah - status_h
  ah = ah - CFG.SP_EDGE - status_h
  local px, py = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + aw, py + ah, COL.PANEL_BG, 8,
    ImGui.DrawFlags_RoundCornersBottom())
  if ImGui.BeginChild(ctx, "##panel", aw, ah) then
    ImGui.SetCursorPosY(ctx, CFG.SP_PANEL)
    ImGui.Indent(ctx, 10)
    if S.tab == 1 then UI.draw_songs_tab()
    elseif S.tab == 2 then UI.draw_lanes_tab()
    elseif S.tab == 3 then UI.draw_presets_tab()
    elseif S.tab == TAB_SETTINGS then UI.draw_settings_tab()
    else UI.draw_help_tab() end
    ImGui.Unindent(ctx, 10)
    ImGui.Dummy(ctx, 0, CFG.SP_PANEL)
    ImGui.EndChild(ctx)
  end
  UI.draw_export()
  UI.draw_status(status_y)
end

---------------------------------------------------------------------------
-- WINDOW (the same resize edges, corner grip and docked-tab triangle as Chart Cue)
---------------------------------------------------------------------------
-- Floating window: the resize edges and corner grip of Chart Cue (the window uses WindowFlags_NoResize).
-- R.rs = the running resize: edge flags + start mouse / window. Called before Begin: applies a running resize.
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

-- Called between Begin and End of the floating window: hover zones, cursor, grip, start of a resize.
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
  -- corner grip: 3 diagonal lines, brighter on hover / while resizing (drawn over the window edge)
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
  Midi.run_send_q()
  ImGui.SetNextWindowSize(ctx, CFG.DEFAULT_W, CFG.DEFAULT_H, ImGui.Cond_FirstUseEver())
  if R.dock_req then ImGui.SetNextWindowDockID(ctx, R.dock_req); R.dock_req = nil end
  UI.pre_begin()
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
  -- ReaImGui rule: call End() ONLY when Begin() returned true (false: an inactive dock tab or collapsed)
  if visible then
    local id = ImGui.GetWindowDockID(ctx) -- the docker in use (also after a drag onto a docker): kept for the next start
    R.docked = ImGui.IsWindowDocked(ctx)
    if id ~= S.dock then S.dock = id; R.sdirty = true end
    UI.draw_main()
    UI.draw_ask()
    UI.draw_chan_ask()
    if not R.docked then UI.edges() else R.rs = nil end -- resize edges: floating only
    ImGui.End(ctx)
  end
  UI.pop_style()
  ImGui.PopFont(ctx)
  if R.pdirty and not ImGui.IsAnyItemActive(ctx) then Project.save() end
  if R.sdirty and not ImGui.IsMouseDown(ctx, 0) and not ImGui.IsAnyItemActive(ctx) then save_settings() end
  if open then r.defer(loop) end
end

local function on_exit()
  if R.pdirty then Project.save() end
  if R.sdirty then save_settings() end
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end

-- A second start closes the running MIDI Pilot (REAPER 7: no question).
if r.set_action_options then r.set_action_options(1) end
do
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end
end
-- Settings > General > Backup: every setting of this computer (the keys that save_settings writes) in 1 text file
-- ("key=value" lines), and back.
function Util.backup_dir() return r.GetResourcePath() .. "/Data/MIDI Pilot" end
function Util.open_folder(dir)
  if r.CF_ShellExecute then r.CF_ShellExecute(dir)
  elseif r.GetOS():match("^Win") then os.execute('explorer "' .. dir:gsub("/", "\\") .. '"')
  else os.execute('open "' .. dir .. '"') end
end
function Util.backup()
  local lines = { "MIDI Pilot backup", "# MIDI Pilot " .. CFG.VERSION .. ", " .. os.date("%Y-%m-%d %H:%M") }
  local set = r.SetExtState
  r.SetExtState = function(sec, key, val, persist) -- (records what save_settings writes)
    if sec == CFG.EXT then lines[#lines + 1] = key .. "=" .. tostring(val) end
    return set(sec, key, val, persist)
  end
  local ok, err = pcall(save_settings)
  r.SetExtState = set
  if not ok then return nil, "The backup failed: " .. tostring(err) end
  local dir = Util.backup_dir()
  r.RecursiveCreateDirectory(dir, 0)
  local path = dir .. "/MIDI Pilot backup " .. os.date("%Y-%m-%d %H-%M") .. ".txt"
  local f = io.open(path, "w")
  if not f then return nil, "The backup file cannot be written: " .. path end
  f:write(table.concat(lines, "\n"), "\n")
  f:close()
  return path
end
-- The keys that save_settings writes now (nothing is written).
local function settings_keys()
  local keys = {}
  local set = r.SetExtState
  r.SetExtState = function(sec, key) if sec == CFG.EXT then keys[#keys + 1] = key end end
  pcall(save_settings)
  r.SetExtState = set
  return keys
end
function Util.restore(path)
  local f = io.open(path, "r")
  if not f then return nil, "The file cannot be read." end
  if f:read("l") ~= "MIDI Pilot backup" then f:close(); return nil, "This is not a MIDI Pilot backup file." end
  -- (a setting that is not in the backup goes back to its default)
  for _, k in ipairs(settings_keys()) do r.DeleteExtState(CFG.EXT, k, true) end
  for line in f:lines() do
    local k, v = line:match("^([^#=][^=]*)=(.*)$")
    if k then r.SetExtState(CFG.EXT, k, v, true) end
  end
  f:close()
  load_settings()
  apply_theme(S.theme)
  R.conflicts, R.status, R.pick_cache, R.plist, R.fitems, R.expr_txt = nil, nil, nil, nil, nil, nil
  R.bank_dirty = true
  R.pcs = {}
  return true
end
load_settings()
apply_theme(S.theme)
Dev.read_ports()
if not r.file_exists(Preset.reabank_path()) then Preset.write_reabank() end
r.atexit(on_exit)
r.defer(loop)
