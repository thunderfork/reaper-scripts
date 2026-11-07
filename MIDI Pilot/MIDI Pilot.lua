-- @description MIDI Pilot: MIDI editor for Quad Cortex
-- @version 0.1
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   MIDI Pilot - write the MIDI for a Neural DSP Quad Cortex or Quad Cortex mini in REAPER: presets at the
--   song starts, scenes by name, knob values in real units, nudges and ramps. The MIDI plays without the
--   script. Requires: the free ReaImGui extension (ReaPack).
-- @changelog
--   First version: devices and tracks, presets at the song starts, scenes by name (strip, list, Scene test), knob
--   values in real units (Lanes), and a status bar with the state of the unit.

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
CFG.VERSION = "0.1"            -- keep equal to @version in the header
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
CFG.FORM_MAX_W = 360           -- the widest control column
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
CFG.LANE_ROWS = 10             -- Lanes: a song's value list scrolls after this many rows (Settings > Lists)
CFG.SCENE_ROWS = 10            -- Songs: a song's scene list scrolls after this many rows (Settings > Lists)
CFG.PC_WINDOW = 2.5            -- a preset change up to this many seconds before a song start belongs to that song
CFG.PRESET_W = 230             -- the preset dropdown of a song row
CFG.REABANK = "MIDI Pilot.reabank" -- in REAPER's Data\MIDI Pilot folder: the preset names for REAPER
CFG.STATUS_SEC = 0.25          -- the status bar text (song, preset, scene at the cursor) is made again this often
CFG.TOAST_SEC = 4              -- a notice in the status bar goes away after this many seconds
CFG.CHASE_JUMP = 0.3           -- s: a play position this far from where it should be is a jump (live chase)
CFG.START_AFTER_PC = 0.1       -- s: a start scene from "Fill songs" comes this long after a song's preset change
CFG.STRIP_H = 22               -- the scene strip of a song row
CFG.SC_CC = 43                 -- the Quad Cortex scene CC (values 0-7)
CFG.EDGE = 0.002               -- s: a scene change this close to a song start is at the start (a MIDI tick rounds it)
CFG.START_WINDOW = 3           -- s: the first scene change in the first seconds of a song is its start scene
CFG.TEST_SEQ = { 0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 0 } -- "Scene test": I-A up to II-D and back to I-A
CFG.TEST_BEATS = 2             -- beats between 2 scene changes of a scene test

local COL = {
  RED = 0xF26D6DFF, YELLOW = 0xF2C75CFF, GREEN = 0x6FCF8AFF,
  ACCENT = 0x3B82F6FF, ACCENT_HOVER = 0x5B9BFFFF, ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633, HEADING = 0x8DB8FFFF,
  WIN_BG = 0x1A1C21FF, PANEL_BG = 0x23262DFF, TAB_BG = 0x15171BFF, TAB_HOVER = 0x343944FF,
  FIELD = 0x2B2F38FF, FIELD_HOVER = 0x333844FF, FIELD_ACTIVE = 0x2C3A55FF,
  BTN = 0x30343EFF, BTN_HOVER = 0x3B404CFF, BTN_ACTIVE = 0x464C5AFF,
  LINE = 0x31353FFF, ROW_HOVER = 0xFFFFFF12, TOGGLE_OFF = 0x4A5060FF,
  TEXT_MAIN = 0xE6E8EEFF, TEXT_DIM = 0x8C93A3FF, TEXT_BRIGHT = 0xEEEEEEFF, WHITE = 0xFFFFFFFF,
  TRANSPARENT = 0x00000000,
}

local Util, Project, Dev, Preset, Midi, Knob, UI = {}, {}, {}, {}, {}, {}, {}

-- The 2 models. banks x letters = 256 presets; scenes: CC#43 values 0-7.
local MODELS = {
  qc = { name = "Quad Cortex", letters = "ABCDEFGH", banks = 32,
    scenes = { "A", "B", "C", "D", "E", "F", "G", "H" } },
  mini = { name = "Quad Cortex mini", letters = "ABCD", banks = 64,
    scenes = { "I-A", "I-B", "I-C", "I-D", "II-A", "II-B", "II-C", "II-D" } },
}
local MODEL_IDS = { "qc", "mini" }
-- The preset folders (CC#32 values 0-12): the unit calls them setlists.
local FOLDERS = { [0] = "Factory Presets", [1] = "My Presets" }
for v = 2, 12 do FOLDERS[v] = "User " .. (v - 1) end
local PC_WHEN = { "before", "exact", "after" }
-- The scene colours of the Quad Cortex: yellow, orange, red, pink, purple, blue, light blue, green. Scene v (0-7)
-- gets colour v + 1 unless you choose another (Presets > Scenes...). Light colours: the text on them is dark.
local SC_COLS = { 0xFFE599FF, 0xF9CB9CFF, 0xEA9999FF, 0xF4B6C8FF, 0xB4A7D6FF, 0x9FC5E8FF, 0xA8DCECFF, 0xB6D7A8FF }
local SC_TEST = 0xD5D8DEFF -- the "Scene test" block on the strip (light grey: no scene colour)
local SC_TEXT = 0x1A1C21FF -- the text on a scene block (always dark: the colours are light)
local SC_COL_NAMES = { "Yellow", "Orange", "Red", "Pink", "Purple", "Blue", "Light blue", "Green" }
-- Preset timing in note values: the length in quarter notes (beats) and its name.
local PC_NOTES = { { 0.125, "1/32 note" }, { 0.25, "1/16 note" }, { 0.5, "1/8 note" }, { 1, "1 beat (1/4 note)" }, { 2, "2 beats" } }
local MODEL_ITEMS = "Quad Cortex\0Quad Cortex mini\0"
-- The units of a knob (Lanes): what the knob shows on the unit.
local KNOB_UNITS = { "%", "Hz", "dB", "ms", "" }
local KNOB_UNIT_ITEMS = "%\0Hz\0dB\0ms\0(none)\0"
-- The slope from a CC value to the next one (REAPER's CC shapes; REAPER plays the curve to the unit).
local CC_SHAPE_ITEMS = "Jump\0Straight\0Slow start and end\0Fast start\0Fast end\0Curve\0"
-- A ramp (Lanes): its slope (CC shapes 1-5, no Jump) and its length: { beats, bars } (else the time selection).
local RAMP_SHAPE_ITEMS = "Straight\0Slow start and end\0Fast start\0Fast end\0Curve\0"
local RAMP_LENS = { { 1, 0, "1 beat" }, { 2, 0, "2 beats" }, { 0, 1, "1 bar" }, { 0, 2, "2 bars" }, { 0, 4, "4 bars" },
  { 0, 8, "8 bars" }, { 0, 16, "16 bars" }, { 0, 0, "Custom...", custom = true },
  { 0, 0, "To the time selection end", sel = true } } -- (the last one: not in the Hold and Back lists)
local RAMP_LEN_ITEMS = ""
for _, l in ipairs(RAMP_LENS) do RAMP_LEN_ITEMS = RAMP_LEN_ITEMS .. l[3] .. "\0" end
local BACK_LEN_ITEMS, HOLD_ITEMS = "", "No hold\0"
for i = 1, #RAMP_LENS - 1 do
  BACK_LEN_ITEMS = BACK_LEN_ITEMS .. RAMP_LENS[i][3] .. "\0"; HOLD_ITEMS = HOLD_ITEMS .. RAMP_LENS[i][3] .. "\0"
end
-- CCs that the Quad Cortex uses for its own functions (a knob on them would also do that function).
local QC_CCS = { [0] = "preset group", [32] = "preset folder", [43] = "scenes", [44] = "tap tempo", [45] = "tuner",
  [46] = "Gig View", [47] = "modes", [62] = "Ignore duplicate PC", [64] = "footswitch page (mini)" }
for c = 35, 42 do QC_CCS[c] = "footswitch" end
for c = 48, 61 do QC_CCS[c] = "Looper X" end

-- R: runtime state (not saved). P: the project data (saved in the project). S: settings of this computer.
local R = {
  proj = nil, state_cc = -1, regions = {}, plast_txt = nil, pdirty = false, sdirty = false,
  frames = 0, sel_dev = 1, ports = {}, ports_t = nil, tracks = {},
}
local P
local S = {
  tab = 1,          -- the open tab: 1 Songs, 2 Lanes, 3 Presets, 4 Settings, 5 Help
  dock = 0,         -- the REAPER docker of the window (0 = floating; a negative number = a REAPER docker)
  devices = {},     -- { id, name, model "qc" / "mini", chan 0 (All channels) / 1-16, port (MIDI output name), latency ms }
  pc_when = "before", -- the preset timing at a song start: "before", "exact" or "after"
  pc_ms = CFG.PC_MS,  -- ... by this many ms
  pc_unit = "ms",     -- the preset timing in "ms" or in "notes" (snaps to the beat grid)
  pc_note = 2,        -- ... the note value: an index of PC_NOTES (default 1/16 note)
  check_items = true, -- a new MIDI item on a device's track: its channel is used, the song starts get a scene
  live_chase = true,  -- a play start or jump (window open): the state there is sent to the units
  nudge_unit = "ms",  -- the nudge (the 2 triangle buttons of a row) in "ms" or in "notes"
  nudge_ms = CFG.NUDGE_MS, -- ... by this many ms
  nudge_note = 1,     -- ... by this note value: an index of PC_NOTES (default 1/32 note)
  lib = {},         -- the preset names: device id -> { ["folder:index"] = preset name }
  fnames = {},      -- your folder names: device id -> { [folder] = name }
  snames = {},      -- scene names: device id -> { ["folder:index"] = { [1..8] = name } }
  knobs = {},       -- the knobs (Lanes): device id -> { { cc, name, min, max, unit } }
  lane_all = false, -- Lanes: the values of all songs (else only the song at the edit cursor)
  lane_rows = CFG.LANE_ROWS, -- Lanes: a song's value list scrolls after this many rows
  scene_rows = CFG.SCENE_ROWS, -- Songs: a song's scene list scrolls after this many rows
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

---------------------------------------------------------------------------
-- SETTINGS (this computer: REAPER's ExtState "MIDI Pilot", persistent)
---------------------------------------------------------------------------
-- The devices, 1 line each: id, name, model, channel, MIDI output name, latency, MIDI input name (tab-separated).
function Dev.parse_list(txt)
  local list = {}
  for line in ((txt or "") .. "\n"):gmatch("([^\n]*)\n") do
    local id, name, model, chan, port, lat, inp = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
    if id and id ~= "" then
      list[#list + 1] = { id = id, name = name, model = MODELS[model] and model or "qc",
        chan = Util.clamp(math.floor(tonumber(chan) or 1), 0, 16), port = port,
        latency = Util.clamp(math.floor(tonumber(lat) or 0), 0, CFG.LATENCY_MAX), inport = inp }
    end
  end
  return list
end
function Dev.serialize_list(list)
  local t = {}
  for _, d in ipairs(list) do
    t[#t + 1] = string.format("%s\t%s\t%s\t%d\t%s\t%d\t%s", d.id, Util.clean(d.name), d.model, d.chan,
      Util.clean(d.port), d.latency, Util.clean(d.inport))
  end
  return table.concat(t, "\n")
end

local function load_settings()
  local function get(k) return r.GetExtState(CFG.EXT, k) end
  S.tab = Util.clamp(math.floor(tonumber(get("tab")) or 1), 1, 5)
  S.dock = math.floor(tonumber(get("dock")) or 0)
  S.devices = Dev.parse_list(get("devices"))
  local w = get("pc_when")
  for _, v in ipairs(PC_WHEN) do if v == w then S.pc_when = w end end
  S.pc_ms = Util.clamp(math.floor(tonumber(get("pc_ms")) or CFG.PC_MS), 0, CFG.PC_MS_MAX)
  S.pc_unit = (get("pc_unit") == "notes") and "notes" or "ms"
  S.pc_note = Util.clamp(math.floor(tonumber(get("pc_note")) or 2), 1, #PC_NOTES)
  S.check_items = get("check_items") ~= "0"
  S.live_chase = get("live_chase") ~= "0"
  S.nudge_unit = (get("nudge_unit") == "notes") and "notes" or "ms"
  S.nudge_ms = Util.clamp(math.floor(tonumber(get("nudge_ms")) or CFG.NUDGE_MS), 1, CFG.NUDGE_MS_MAX)
  S.nudge_note = Util.clamp(math.floor(tonumber(get("nudge_note")) or 1), 1, #PC_NOTES)
  for _, d in ipairs(S.devices) do
    S.lib[d.id] = Preset.parse_lib(get("lib_" .. d.id))
    S.fnames[d.id] = Preset.parse_fnames(get("fold_" .. d.id))
    S.snames[d.id] = Preset.parse_snames(get("scn_" .. d.id))
    S.knobs[d.id] = Knob.parse(get("knb_" .. d.id))
  end
  S.lane_all = get("lane_all") == "1"
  S.lane_rows = Util.clamp(math.floor(tonumber(get("lane_rows")) or CFG.LANE_ROWS), 3, 100)
  S.scene_rows = Util.clamp(math.floor(tonumber(get("scene_rows")) or CFG.SCENE_ROWS), 3, 100)
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
local function save_settings()
  r.SetExtState(CFG.EXT, "tab", tostring(S.tab), true)
  r.SetExtState(CFG.EXT, "dock", tostring(S.dock), true)
  r.SetExtState(CFG.EXT, "devices", Dev.serialize_list(S.devices), true)
  r.SetExtState(CFG.EXT, "pc_when", S.pc_when, true)
  r.SetExtState(CFG.EXT, "pc_ms", tostring(S.pc_ms), true)
  r.SetExtState(CFG.EXT, "pc_unit", S.pc_unit, true)
  r.SetExtState(CFG.EXT, "pc_note", tostring(S.pc_note), true)
  r.SetExtState(CFG.EXT, "check_items", S.check_items and "1" or "0", true)
  r.SetExtState(CFG.EXT, "live_chase", S.live_chase and "1" or "0", true)
  r.SetExtState(CFG.EXT, "nudge_unit", S.nudge_unit, true)
  r.SetExtState(CFG.EXT, "nudge_ms", tostring(S.nudge_ms), true)
  r.SetExtState(CFG.EXT, "nudge_note", tostring(S.nudge_note), true)
  for _, d in ipairs(S.devices) do
    r.SetExtState(CFG.EXT, "lib_" .. d.id, Preset.serialize_lib(S.lib[d.id]), true)
    r.SetExtState(CFG.EXT, "fold_" .. d.id, Preset.serialize_fnames(S.fnames[d.id]), true)
    r.SetExtState(CFG.EXT, "scn_" .. d.id, Preset.serialize_snames(S.snames[d.id]), true)
    r.SetExtState(CFG.EXT, "knb_" .. d.id, Knob.serialize(S.knobs[d.id]), true)
  end
  r.SetExtState(CFG.EXT, "lane_all", S.lane_all and "1" or "0", true)
  r.SetExtState(CFG.EXT, "lane_rows", tostring(S.lane_rows), true)
  r.SetExtState(CFG.EXT, "scene_rows", tostring(S.scene_rows), true)
  if R.bank_dirty then Preset.write_reabank() end
  R.sdirty = false
end

---------------------------------------------------------------------------
-- PROJECT (regions, tracks and the project data)
---------------------------------------------------------------------------
-- tracks: device id -> track GUID ("*" = the shared track). track_mode: "own" (1 track per device) or "shared".
-- test_ok: the regions (by name) whose Scene test needs no hint in the status bar ("Ignore").
function Project.default() return { tracks = {}, track_mode = "own", test_ok = {} } end

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
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc then R.state_cc = cc; Project.scan(); Dev.sync_from_tracks(); R.conflicts = nil; Midi.find_new_items() end
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

-- Renames a device; its track follows when it still has the name MIDI Pilot gave it.
function Dev.rename(d, name)
  if name == d.name then return end
  local tr = Dev.track(d)
  if tr and P.track_mode ~= "shared" then
    local _, cur = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if cur == Dev.track_title(d) then r.GetSetMediaTrackInfo_String(tr, "P_NAME", "MIDI " .. name, true) end
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

-- The model that a MIDI output name suggests (USB: the device's own name), or nil.
function Dev.model_from_port(name)
  local n = (name or ""):lower()
  if not n:find("cortex", 1, true) then return nil end
  return n:find("mini", 1, true) and "mini" or "qc"
end

-- A new device. A connected Quad Cortex (USB) that no device uses yet: its output, input and model.
-- (All connected units in use: a device without an output, so the same unit is never added twice.)
function Dev.new()
  local d = { id = "d" .. r.genGuid(""):gsub("[^%w]", ""):sub(1, 12), name = "", model = "qc", chan = 1,
    port = "", latency = 0, inport = "" }
  for _, p in ipairs(R.ports) do
    local m = Dev.model_from_port(p.name)
    if m and not Dev.port_used(p.name) then d.port, d.model = p.name, m; break end
  end
  d.inport = Dev.guess_input(d)
  -- a MIDI Pilot track without a device (its device was removed): the device comes back with it (the track of
  -- the same unit first)
  if P.track_mode ~= "shared" then
    local pick
    for _, o in ipairs(Dev.orphans()) do
      if d.port ~= "" and o.dev.port == d.port then pick = o; break end
    end
    if not pick and d.port == "" then pick = Dev.orphans()[1] end -- (no unit found: the first kept track)
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
  S.lib[d.id] = {}; S.fnames[d.id] = {}; S.snames[d.id] = {}; S.knobs[d.id] = Knob.parse("")
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
  S.lib[d.id] = (back and back.lib) or Preset.parse_lib(r.GetExtState(CFG.EXT, "lib_" .. d.id))
  S.fnames[d.id] = (back and back.fnames) or Preset.parse_fnames(r.GetExtState(CFG.EXT, "fold_" .. d.id))
  S.snames[d.id] = (back and back.snames) or Preset.parse_snames(r.GetExtState(CFG.EXT, "scn_" .. d.id))
  S.knobs[d.id] = (back and back.knobs) or Knob.parse(r.GetExtState(CFG.EXT, "knb_" .. d.id))
  if R.removed then R.removed[d.id] = nil end
  P.tracks[d.id] = o.guid
  Util.mark_pdirty(); Util.mark_sdirty(); R.conflicts = nil; R.bank_dirty = true; R.pick_cache = nil; R.fitems = nil
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
      S.lib[id] = b.lib or {}; S.fnames[id] = b.fnames or {}; S.snames[id] = b.snames or {}
      S.knobs[id] = b.knobs or Knob.parse("")
      P.tracks[id] = b.guid
      S.devices[#S.devices + 1] = b.d
      R.removed[id] = nil
      Util.mark_pdirty(); Util.mark_sdirty(); R.conflicts = nil; R.bank_dirty = true; R.pick_cache = nil; R.fitems = nil
      Util.notify("'" .. b.d.name .. "' is back, with its track.")
    end
  end
end

-- A detected Quad Cortex that no device uses yet (for the "Add device" tooltip), or nil.
function Dev.free_unit()
  for _, p in ipairs(R.ports) do
    if Dev.model_from_port(p.name) and not Dev.port_used(p.name) then return p.name end
  end
  return nil
end

-- A change of the track's MIDI output in REAPER (the routing window): the device follows it.
function Dev.sync_from_tracks()
  if P.track_mode == "shared" then return end
  for _, d in ipairs(S.devices) do
    local tr = Dev.track(d)
    if tr then
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
  R.removed[d.id] = { d = d, lib = S.lib[d.id], fnames = S.fnames[d.id], snames = S.snames[d.id], knobs = S.knobs[d.id], guid = guid }
  if not keep_data then
    r.DeleteExtState(CFG.EXT, "lib_" .. d.id, true); r.DeleteExtState(CFG.EXT, "fold_" .. d.id, true)
    r.DeleteExtState(CFG.EXT, "scn_" .. d.id, true); r.DeleteExtState(CFG.EXT, "knb_" .. d.id, true)
  end
  S.lib[d.id] = nil; S.fnames[d.id] = nil; S.snames[d.id] = nil; S.knobs[d.id] = nil; R.bank_dirty = true
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
-- A preset is a folder (CC#32, 0-12) and an index 0-255 (CC#0 = index // 128, Program = index % 128).
-- The unit shows the index as bank + letter: Quad Cortex 8 letters (A-H), mini 4 letters (A-D).
function Preset.label(model, index)
  local L = MODELS[model].letters
  local n = #L
  local k = index % n + 1
  return (index // n + 1) .. L:sub(k, k)
end
function Preset.index(model, bank, letter_i) return (bank - 1) * #MODELS[model].letters + (letter_i - 1) end
function Preset.key(folder, index) return folder .. ":" .. index end
function Preset.name(d, folder, index)
  local lib = S.lib[d.id]
  return lib and lib[Preset.key(folder, index)]
end
-- "3B Clean" (the name when it has one); the folder only when it is not My Presets.
function Preset.text(d, folder, index)
  local nm = Preset.name(d, folder, index)
  local s = Preset.label(d.model, index) .. ((nm and nm ~= "") and ("  " .. nm) or "")
  if folder ~= 1 then s = s .. "  (" .. Preset.folder_name(d, folder) .. ")" end
  return s
end

-- The name of a folder: your name for it, else the unit's name (My Presets, User 1 ...).
function Preset.folder_name(d, f)
  local fn = S.fnames[d.id]
  return (fn and fn[f]) or FOLDERS[f] or ("Folder " .. f)
end
function Preset.set_folder_name(d, f, name)
  S.fnames[d.id] = S.fnames[d.id] or {}
  name = Util.clean(name):match("^%s*(.-)%s*$")
  S.fnames[d.id][f] = (name ~= "" and name ~= FOLDERS[f]) and name or nil
  R.fitems = nil; R.pick_cache = nil; R.bank_dirty = true; Util.mark_sdirty()
end
-- The folder dropdown items of a device (cached until a folder name changes).
function Preset.folder_items(d)
  R.fitems = R.fitems or {}
  local s = R.fitems[d.id]
  if s then return s end
  s = ""
  for v = 0, 12 do s = s .. Preset.folder_name(d, v) .. "\0" end
  R.fitems[d.id] = s
  return s
end
-- The name of scene v (0-7) of a preset: your name, else the unit's (A, B ... or I-A, II-B on the mini).
function Preset.scene_name(d, folder, index, v)
  local t = folder and S.snames[d.id] and S.snames[d.id][Preset.key(folder, index)]
  local nm = t and t[v + 1]
  return (nm and nm ~= "") and nm or MODELS[d.model].scenes[v + 1]
end
function Preset.has_scene_name(d, folder, index, v)
  if not folder then return false end -- (no preset there)
  local t = S.snames[d.id] and S.snames[d.id][Preset.key(folder, index)]
  return t ~= nil and t[v + 1] ~= nil and t[v + 1] ~= ""
end
-- The colour (1-8 of SC_COLS) of scene v (0-7) of a preset: your choice, else colour v + 1.
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
function Preset.set_name(d, folder, index, name)
  local lib = S.lib[d.id] or {}
  S.lib[d.id] = lib
  name = Util.clean(name):match("^%s*(.-)%s*$")
  lib[Preset.key(folder, index)] = (name ~= "") and name or nil
  Util.mark_sdirty(); R.bank_dirty = true; R.pick_cache = nil
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
        t[#t + 1] = pc .. " " .. Preset.label(d.model, idx) .. ((nm and nm ~= "") and (" " .. nm) or "")
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
    local msb, lsb = 0, 1
    local p0, p1 = Midi.play_range(take)
    local ncc = p0 and select(3, r.MIDI_CountEvts(take)) or 0
    for i = 0, ncc - 1 do
      local _, _, muted, ppq, cm, ch, m2, m3 = r.MIDI_GetCC(take, i)
      if not muted and Midi.is_mine(d, ch) and ppq >= p0 and ppq < p1 then
        if cm == 0xB0 and m2 == 0 then msb = m3
        elseif cm == 0xB0 and m2 == 32 then lsb = m3
        elseif cm == 0xC0 then
          c[#c + 1] = { t = r.MIDI_GetProjTimeFromPPQPos(take, ppq), folder = lsb, index = Util.clamp(msb, 0, 1) * 128 + m2,
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

-- The time of a song's preset change (Settings > Preset timing), and whether it was moved to 0:00.
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
-- else a new MIDI item.
function Midi.take_at(d, t)
  local tr = Dev.track(d)
  if not tr then return nil end
  local first
  for i = 0, r.CountTrackMediaItems(tr) - 1 do
    local item = r.GetTrackMediaItem(tr, i)
    local take = r.GetActiveTake(item)
    if take and r.TakeIsMIDI(take) then
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
  local item = r.CreateNewMIDIItemInProj(tr, math.max(0, t), Dev.item_end(), false)
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

-- Writes the 3 events of a preset change at time t: CC#0 (the preset group), CC#32 (the folder), then the
-- Program Change, at the same position, in this order (as REAPER's Bank/Program Select lane).
function Midi.insert_change(d, t, folder, index)
  local take = Midi.take_at(d, t)
  if not take then return false end
  local ppq = math.floor(r.MIDI_GetPPQPosFromProjTime(take, t) + 0.5)
  local ch = Midi.chan(d)
  r.MIDI_InsertCC(take, false, false, ppq, 0xB0, ch, 0, index // 128)
  r.MIDI_InsertCC(take, false, false, ppq, 0xB0, ch, 32, folder)
  r.MIDI_InsertCC(take, false, false, ppq, 0xC0, ch, index % 128, 0)
  r.MIDI_Sort(take)
  return true
end

-- Writes the preset of a song (no undo step): its old change goes, the new one is written at the time of
-- Settings > Preset timing (the scenes do not change). With folder nil: the change is removed.
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

-- Sets (or with folder nil: removes) the preset of a song, in 1 undo step.
function Midi.set_song(d, rg, folder, index)
  r.Undo_BeginBlock()
  local moved = Midi.write_song(d, rg, folder, index)
  r.UpdateArrange()
  r.Undo_EndBlock(folder and ("MIDI Pilot: preset of " .. rg.name) or ("MIDI Pilot: remove the preset of " .. rg.name), -1)
  return moved
end

-- "Fill songs": a song without its own preset change gets the preset that is active at its start (so a start in
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
    -- each control: the value that plays at the song start (when a value comes before it), at the song start
    for _, k in ipairs(S.knobs[d.id] or {}) do
      local has = false
      for _, e in ipairs(Midi.ccs(d, k.cc)) do if math.abs(e.t - rg.start) < CFG.EDGE then has = true; break end end
      local v, prev = Midi.cc_at(d, k.cc, rg.start)
      if not has and v and prev then
        -- (inside a ramp: the new value keeps its slope, so the ramp goes on as before)
        Midi.write_cc(d, k.cc, rg.start, v, prev.shape, prev.tension); n = n + 1
        R.pcs = {}
      end
    end
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: fill songs", -1)
  return n
end

-- "Presets match Regions": a song whose name is the name of a preset (Presets tab) gets that preset.
-- Returns the number of songs changed.
function Midi.match_names(d)
  local by_name = {}
  for k, nm in pairs(S.lib[d.id] or {}) do by_name[nm:lower()] = by_name[nm:lower()] or k end
  local n = 0
  r.Undo_BeginBlock()
  for _, rg in ipairs(R.regions) do
    local k = by_name[(rg.name:match("^%s*(.-)%s*$")):lower()]
    if k then
      local f, i = k:match("^(%d+):(%d+)$")
      f, i = tonumber(f), tonumber(i)
      local cur = Midi.song_change(d, rg)
      if not (cur and cur.folder == f and cur.index == i) then
        Midi.write_song(d, rg, f, i); n = n + 1
      end
    end
  end
  R.pcs = {}
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: presets match regions", -1)
  return n
end

-- ---------------------------------------------------------------------------------------------------------
-- Scenes. The rule: an edit writes exactly what you choose, where you choose it, and nothing else. A scene change is
-- 1 CC#43 event (values 0-7); no edit moves, adds or removes other scene changes. Start scenes ("Fill songs") and
-- merging ("Merge repeated scenes") happen only with their buttons.

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
      if not muted and cm == 0xB0 and m2 == CFG.SC_CC and m3 <= 7 and Midi.is_mine(d, ch) and ppq >= p0 and ppq < p1 then
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
    if math.abs(ppq - s.ppq) < 0.5 and cm == 0xB0 and m2 == CFG.SC_CC and Midi.is_mine(d, chn) then r.MIDI_DeleteCC(s.take, i) end
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
    if math.abs(p - ppq) < 0.5 and cm == 0xB0 and m2 == CFG.SC_CC and Midi.is_mine(d, chn) then r.MIDI_DeleteCC(take, i) end
  end
  r.MIDI_InsertCC(take, false, false, ppq, 0xB0, Midi.chan(d), CFG.SC_CC, v)
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
  Midi.scene_edit("add a scene change", function() Midi.put_scene(d, t, v) end)
end
function Midi.change_scene(d, s, v)
  Midi.scene_edit("change a scene", function() Midi.delete_scene(d, s); Midi.put_scene(d, s.t, v) end)
end
function Midi.move_scene(d, s, t)
  Midi.scene_edit("move a scene change", function() Midi.delete_scene(d, s); Midi.put_scene(d, t, s.v) end)
end
function Midi.remove_scene(d, s)
  Midi.scene_edit("remove a scene change", function() Midi.delete_scene(d, s) end)
end

-- Nudge: a time moved by the nudge amount (Settings > Nudge), dir -1 (earlier) or 1 (later).
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
  for _, k in ipairs(S.knobs[d.id] or {}) do
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

-- Scene test: CFG.TEST_SEQ (I-A up to II-D and back to I-A), a change every CFG.TEST_BEATS beats from time t.
-- The times of its changes, and its end (CFG.TEST_BEATS after its last change).
function Midi.test_times(t)
  local q0 = r.TimeMap2_timeToQN(R.proj, t)
  local times = {}
  for k = 1, #CFG.TEST_SEQ do times[k] = r.TimeMap2_QNToTime(R.proj, q0 + (k - 1) * CFG.TEST_BEATS) end
  return times, r.TimeMap2_QNToTime(R.proj, q0 + #CFG.TEST_SEQ * CFG.TEST_BEATS)
end
-- True when a test from time t fits in the song (its last change before the song end).
function Midi.test_fits(rg, t)
  local times = Midi.test_times(t)
  return t >= rg.start - 0.0001 and times[#times] < rg.stop
end
-- Writes a test from time t (no undo step): the scene changes in its section are replaced.
local function write_test(d, rg, t)
  local times, tend = Midi.test_times(t)
  for _, s in ipairs(Midi.song_scenes(d, rg)) do
    if s.t >= t - 0.0001 and s.t < tend - 0.0001 then Midi.delete_scene(d, s) end
  end
  for k, v in ipairs(CFG.TEST_SEQ) do Midi.put_scene(d, times[k], v) end
  return tend
end
-- Adds a test at time t (1 undo step). Returns its end time, or nil when it does not fit (nothing written).
function Midi.add_test(d, rg, t)
  if not Midi.test_fits(rg, t) then return nil end
  return Midi.scene_edit("scene test in " .. rg.name, function() return write_test(d, rg, t) end)
end
-- Removes a test; with t: moves it there (1 undo step). Returns false when it does not fit there (nothing changed).
function Midi.remove_test(d, rg, g, t)
  if t and not Midi.test_fits(rg, t) then return false end
  Midi.scene_edit(t and "move a scene test" or "remove a scene test", function()
    for _, s in ipairs(g.evs) do Midi.delete_scene(d, s) end
    if t then write_test(d, rg, t) end
  end)
  return true
end

-- The scene tests of a song (cached until the MIDI changes): runs of scene changes with the values CFG.TEST_SEQ,
-- CFG.TEST_BEATS beats apart. Each: { evs, t0 (its 1st change), t1 (its end) }; of[ev] = the test of a change.
function Midi.song_tests(d, rg)
  R.pcs = R.pcs or {}
  local key = "t" .. d.id .. ":" .. rg.start
  local c = R.pcs[key]
  if c then return c end
  c = { of = {} }
  local list, seq, n = Midi.song_scenes(d, rg), CFG.TEST_SEQ, #CFG.TEST_SEQ
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
-- The time of a new start scene ("Fill songs"): the song start, or CFG.START_AFTER_PC after the song's own preset
-- change when that change comes after the start (the unit first loads the preset).
function Midi.start_time(d, rg)
  local own = Midi.song_change(d, rg)
  if own and own.t + CFG.START_AFTER_PC > rg.start then return own.t + CFG.START_AFTER_PC end
  return rg.start
end
-- The next song after a song (in timeline order), or nil.
function Midi.next_song(rg)
  for i, x in ipairs(R.regions) do if x == rg then return R.regions[i + 1] end end
  return nil
end
-- The start scene of a song: its first scene change, when it is in its first CFG.START_WINDOW seconds
-- (or before its new start scene time).
function Midi.start_scene(d, rg)
  local hi = math.min(rg.stop, math.max(Midi.start_time(d, rg) + 0.01, rg.start + CFG.START_WINDOW))
  for _, s in ipairs(Midi.scenes(d)) do
    if s.t >= rg.start - CFG.EDGE and s.t < hi then return s end
    if s.t >= hi then break end
  end
  return nil
end
-- The default start scene: the first scene with a name in the preset, else scene 1 (A).
function Midi.default_start(d, pc)
  if pc then
    for v = 0, 7 do if Preset.has_scene_name(d, pc.folder, pc.index, v) then return v end end
  end
  return 0
end
-- "Fill songs": a song without a start scene gets the default one (no undo step). Returns true when written.
function Midi.ensure_start_scene(d, rg)
  if not rg or Midi.start_scene(d, rg) then return false end
  local t = Midi.start_time(d, rg)
  Midi.put_scene(d, t, Midi.default_start(d, Midi.preset_at(d, rg, t)))
  return true
end

-- ---------------------------------------------------------------------------------------------------------
-- New MIDI items (Settings > Tracks > Check new MIDI items): a MIDI item that appears on a device's track (copied,
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
-- the scene that plays there (from a scene change before it), else I-A. 1 undo step. Returns the number added.
function Midi.fill_item_starts(d, items)
  local n = 0
  Midi.scene_edit("scenes at the song starts", function()
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
  if n > 0 and UI.toast then UI.toast(string.format("%s: %d scene change(s) added at the song starts.", d.name, n)) end
  return n
end

-- "Merge repeated scenes" (button): in each song, a scene change to the scene that already plays is removed (not the
-- start scene, not a part of a scene test), in 1 undo step. Returns the number removed.
function Midi.merge_all(d)
  local n = 0
  Midi.scene_edit("merge repeated scenes", function()
    for _, rg in ipairs(R.regions) do
      local prev
      local st = Midi.start_scene(d, rg)
      local tests = Midi.song_tests(d, rg).of
      for _, s in ipairs(Midi.song_scenes(d, rg)) do
        if prev ~= nil and s.v == prev and s ~= st and not tests[s] and s.t > rg.start + CFG.EDGE then
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
  Midi.scene_edit(presets and "clear all presets" or (rg and ("clear the scenes of " .. rg.name) or "clear all scenes"),
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
-- scene's letter, A or II-B) gets that scene change. Markers of other scripts (PDFPAGE, PDFSCROLL) are skipped.
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
      for v = 0, 7 do
        local sn = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v):lower()
        if sn == nm or MODELS[d.model].scenes[v + 1]:lower() == nm then
          local cur
          for _, s in ipairs(Midi.scenes(d)) do if math.abs(s.t - mk.pos) < 0.001 then cur = s end end
          if not (cur and cur.v == v) then Midi.put_scene(d, mk.pos, v); n = n + 1 end
          break
        end
      end
    end
  end
  r.UpdateArrange()
  r.Undo_EndBlock("MIDI Pilot: scenes match markers", -1)
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

-- The state of a device at time t: its preset, its scene and the value of each control (Live chase, Send state now).
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
  for _, k in ipairs(S.knobs[d.id] or {}) do
    local v = Midi.cc_at(d, k.cc, t)
    if v then st.ccs[#st.ccs + 1] = { cc = k.cc, v = v } end
  end
  return st
end

-- Sends the state of a device at time t to the unit: the preset now, the scene and the control values
-- CFG.START_AFTER_PC later (the unit first loads the preset). from: the time where playback was before (Live
-- chase): only what differs from the state there is sent, and the same preset is not loaded again (a reload is a
-- gap in the sound); with the same preset, the changes go at once. Returns false when the output is not available.
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

-- Live chase (Settings > Playback): while the window is open, a play start or a jump to a place that is not a song
-- start sends the state there to every device (at a song start, the MIDI there does it). Every frame: cheap.
function Midi.live_chase()
  local playing = Util.playing()
  local pos = r.GetPlayPosition2()
  local now = Util.now()
  local lc = R.chase or {}
  R.chase = lc
  local jump = false
  local from = lc.played -- (the last place that really played: the unit is in the state there)
  if playing then
    if not lc.playing then jump = true
    elseif lc.pos then
      local want = lc.pos + (now - lc.t) * r.Master_GetPlayRate(R.proj)
      if math.abs(pos - want) > CFG.CHASE_JUMP then jump = true end
    end
    lc.played = pos
  end
  lc.playing, lc.pos, lc.t = playing, pos, now
  if not (jump and S.live_chase) then return end
  local rg = Midi.song_at(pos)
  for _, d in ipairs(S.devices) do
    if Dev.track(d) then
      -- (at a song start the song's own preset change and start scene play: nothing is sent twice)
      local at_start = rg and pos < Midi.start_time(d, rg) + 0.05
      if not at_start then Midi.send_state(d, pos, from) end
    end
  end
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
  r.StuffMIDIMessage(16 + pi, 0xB0 + Midi.chan(d), CFG.SC_CC, v)
  return true
end

-- Sends a preset to the unit now (its MIDI output). Returns false when the output is not available.
function Midi.send_now(d, folder, index)
  local pi = Dev.port_index(d.port)
  if not pi then return false end
  local ch = Midi.chan(d)
  r.StuffMIDIMessage(16 + pi, 0xB0 + ch, 0, index // 128)
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

local HELP_TEXT = [[
MIDI Pilot writes the MIDI for a Neural DSP Quad Cortex or Quad Cortex mini in REAPER. The MIDI is normal REAPER MIDI: it plays without MIDI Pilot, also when its window is closed.

This is the first version, in development: the devices, their tracks, the presets, the scenes, the knob values with ramps and swells, the nudge, the latency and the state at the song starts (Fill songs, Live chase, Send state).

Lanes: a control is a CC that moves a knob of the unit (for example Expression 1, CC#1, assigned on the unit to a filter). Enter the range that you set on the unit (heel = Min, toe = Max) and the unit (%, Hz, dB, ms). "Values in <song>" lists the values of the selected control in the song at the edit cursor ("All songs" shows them in every song, under the song names; a click on a song name closes or opens its values; a long list scrolls, Settings > Lists): type a value in the knob's unit (for example 650 or 1.2k), and MIDI Pilot writes the nearest CC value (a CC has 128 steps). Each value row: its position and time (type a new one to move it), the nudge buttons, the value, the slope to the next value, send (the triangle) and remove (the red X). "Add a value": "Value" and "Add at edit cursor" write 1 value (the control jumps there). "Add a ramp" is separate and needs no value first: "From / to / swell" (the start value, the arrow, the end value, the Swell switch), "Length", "Slope" and "Add ramp" write 2 values with a slope between them, from the edit cursor, in 1 step ("Swell": there and back, for example 0 - 100 - 0: under it, "Hold" keeps the top for a time, then "Back to" (empty: the start value), "Length" and "Slope" set the way back; it cannot go past the top). The text after the button says what is missing, or where it goes: for example a filter sweep over 4 bars; the length is in beats, in bars, "Custom..." (type bars.beats: 3 = 3 bars, 0.6 = 6 beats, 2.2 = 2 bars and 2 beats; also for Hold and the way back), or up to the end of REAPER's time selection. A yellow warning sign marks a CC that the unit also uses for a function (scenes, tuner, footswitches ...). Slope: how a value goes to the next one (Jump, Straight, Slow start and end, Fast start, Fast end, or a Curve that you bend), for swells and fades; REAPER plays the curve to the unit.

Songs: each region is a song. The dropdown sets the song's preset: MIDI Pilot writes a preset change (CC#0, CC#32 and a Program Change, as REAPER's Bank/Program Select lane) near the song start, in the device's MIDI item. It also reads the preset changes that are already there. Grey: the song has no change, and the preset from before goes on. "Choose by number..." picks a preset without a name. The triangle sends the preset to the unit now. The red X removes the change. "Fill songs" gives each song without a change the preset that is already playing there, and a start scene, so playback can start in any song. "Presets match Regions" gives a song (region) the preset with its name.

Scenes: the strip under each song shows its scene changes (CC#43), with the scene names of the preset that plays there; a click on a block moves the edit cursor there. The arrow at the song number opens the song's scene list, with labels above the columns (Position, Time, Nudge, Scene): the start scene first (its place shows but cannot be changed), then each scene change with its position in bars and beats and its time in the song (type a new one to move it), the nudge buttons, the scene, send (the triangle) and the red X. The bottom row: "Song" and its nudge buttons (the whole song), "Add scene at edit cursor" and "Clear scenes". A long list scrolls (Settings > Lists). "Add scene at edit cursor": put REAPER's edit cursor where the scene must change (during playback: the play position), then choose the scene; it is written exactly there, and nothing else changes. "Scene test" in that list adds every scene from I-A to II-D and back to I-A, a change every 2 beats from the edit cursor, to hear all scenes of the preset; the strip and the list show it as 1 "Scene test" (type a new position to move it; its red X removes it), and the edit cursor goes to its end. Type a new position or time in a row to move that scene change. A song without scene changes shows an empty strip. "Fill songs" gives each song without a start scene its default start scene (at the song start, or just after the song's preset change); the strip shows it from the song start. "Merge repeated scenes" (button) removes a scene change to the scene that already plays. "Clear scenes" removes the scene changes of a song; "Clear all scenes" and "Clear all presets" remove them from the whole project (they ask first). A click on a song name opens its list too. Right-click a block of the strip to change or remove its scene. The colours of the scenes are the colours of the unit (Presets > Scenes...). "Scenes match Markers" gives a marker inside a song the scene with its name (for example a marker "Chorus"). A MIDI item that you add to a device's track is checked once (Settings > Tracks > Check new MIDI items): its MIDI channel becomes the device's channel (more than 1 channel: MIDI Pilot asks), and each song that starts inside it gets a scene change exactly at its start when it has none there (the scene that plays there, else I-A).

Playback: the MIDI plays from the device tracks. "Fill songs" gives every song its preset, start scene and the value of each control at its start, so playback from any song start is right, also with the window closed. Live chase (Settings > Playback, window open): a play start or a jump into the middle of a song sends the state there at once (the preset, then the scene and the control values); only what differs from the place that played before is sent, so the same preset is never loaded again (no gap in the sound). "Send state" (the status bar) sends the state at the edit cursor now.

Status bar (at the bottom): line 1 shows the device, its MIDI output and channel (green: READY; red: NOT AVAILABLE), and the song, preset and scene at the play position (stopped: at the edit cursor). Line 2 shows the most important message: red for a problem (for example 2 devices on the same output and channel), yellow for a hint (songs without a preset or a start scene, a Scene test that is still in a song: "Ignore" hides it for that song, saved in the project), else "Ready".

Presets: the names of your presets (3B = Song One), of their scenes (Scenes...) and of your folders, for each device. Saved on this computer, for all projects.

Preset timing (Settings): the preset change before, exactly at or after the song start, by milliseconds or by a note value (on the beat grid); before (250 ms) gives the unit time to load the preset.

Device channel: when you change it, MIDI Pilot asks whether the presets and scenes already written move to the new channel too.

Preset names in REAPER (Settings > General): a bank file with your preset names. Load it in ReaControlMIDI on the track (Bank/Program Select > Load File, and leave Enable off): REAPER then shows the names.

Devices (Settings tab): add 1 device for each unit. Adding a device also adds its track (or uses the track called MIDI + its name, when it is there). Removing a device asks whether its track goes too. With USB, "Add device" finds a connected Quad Cortex that has no device yet, and selects its MIDI output, MIDI input and model. With a MIDI cable, select the output and the model yourself. The name: for example Guitar or Bass; empty, it is the model name (Quad Cortex 1, Quad Cortex 2 ... when you have more of 1 model). The MIDI channel is the channel of the unit (on the unit: Settings > Device > MIDI). All channels sends to every channel: use it only when 1 unit is on that output.

MIDI input: the input from the unit, for the recording in a later version.

Latency: the delay of the unit, in milliseconds. MIDI Pilot sets the playback offset of the device's track to minus the latency, so REAPER sends its MIDI that much earlier and the unit changes on the beat; the MIDI stays on the beat in the project. (One shared track: the largest latency of the devices.)

Nudge: the nudge buttons (the 2 triangles) move a change earlier (left) or later (right), by the amount in Settings > Nudge (milliseconds, or a note value that follows the tempo). Each scene change and each knob value has them in its row; "Song" (in the scene list) moves all scene changes (not the start scene) and knob values of the song together. A nudge never moves a change out of its song.

Tracks: each device writes on its own track (default), or all devices write on 1 shared track (Settings > Tracks), separated by their channels. "Create track" adds a track called MIDI + the device name at the end of the project, with its MIDI output set to the device and an empty MIDI item for the MIDI. No plug-in is needed: REAPER sends the MIDI of the item to the unit. "Use selected track" uses a track that you already have. The MIDI output of the track and the device settings follow each other (also a change in REAPER's routing window).

Saved on this computer: the devices, the preset, folder and scene names, the controls (Lanes), Live chase, the preset timing, the nudge, the list sizes, "Check new MIDI items" and the window. Saved in the project: which track belongs to which device, the track mode, and the songs whose Scene test hint you ignored. The MIDI itself is in the device tracks.]]

function UI.tip(text)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then ImGui.SetTooltip(ctx, text) end
end

-- The theme: the same colours and sizes as Chart Cue (pushed every frame; UI.pop_style pops them).
local STYLE_COLS = {
  { "WindowBg", COL.WIN_BG }, { "ChildBg", COL.TRANSPARENT }, { "PopupBg", COL.PANEL_BG },
  { "Border", COL.LINE }, { "FrameBg", COL.FIELD }, { "FrameBgHovered", COL.FIELD_HOVER },
  { "FrameBgActive", COL.FIELD_ACTIVE }, { "Button", COL.BTN }, { "ButtonHovered", COL.BTN_HOVER },
  { "ButtonActive", COL.BTN_ACTIVE }, { "Header", COL.ACTIVE_BG }, { "HeaderHovered", 0x3B82F655 },
  { "HeaderActive", 0x3B82F677 }, { "CheckMark", COL.ACCENT }, { "Text", COL.TEXT_MAIN },
  { "TextDisabled", COL.TEXT_DIM }, { "Separator", COL.LINE }, { "ScrollbarBg", COL.TRANSPARENT },
  { "ScrollbarGrab", COL.BTN_HOVER }, { "ScrollbarGrabHovered", COL.BTN_ACTIVE },
  { "ScrollbarGrabActive", COL.TOGGLE_OFF },
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
  for _, c in ipairs(STYLE_COLS) do ImGui.PushStyleColor(ctx, c[1], c[2]) end
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
  elseif kind == "danger" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED); n = 1
  end
  local hit = ImGui.Button(ctx, label, w or 0, h or ImGui.GetFrameHeight(ctx))
  if n > 0 then ImGui.PopStyleColor(ctx, n) end
  return hit
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
function UI.heading(text, help, note, note_col)
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
  ImGui.PushFont(ctx, head_font)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.TextColored(ctx, COL.HEADING, text)
  ImGui.PopFont(ctx)
  local tx1, ty = ImGui.GetItemRectMax(ctx)
  if note then
    local x_end = sx + full - (help and CFG.HELP_ICON + 10 or 0)
    local avail = x_end - tx1 - 16
    if avail > 40 then
      local s = UI.trunc(note, avail)
      local nw = ImGui.CalcTextSize(ctx, s)
      ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x_end - nw, UI.text_y(sy), note_col or COL.YELLOW, s)
    end
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
    if UI.button(a.yes, UI.btn_w(a.yes, 120), nil, a.safe and "primary" or "danger") then a.fn(); R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if a.alt then
      if UI.button(a.alt, UI.btn_w(a.alt, 120)) then a.alt_fn(); R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    end
    if UI.button("Cancel", 90) then R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  else
    R.ask = nil
  end
end

-- A square button with a drawn icon: "send" (a play triangle), "back" / "fwd" (2 triangles: nudge earlier / later),
-- "minus", "plus". Returns true when clicked.
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
  UI.tip("Move " .. what .. " " .. Midi.nudge_text() .. " earlier (Settings > Nudge).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.icon_button("nr" .. id, "fwd", fh) then dir = 1 end
  UI.tip("Move " .. what .. " " .. Midi.nudge_text() .. " later (Settings > Nudge).")
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
function UI.pill_end(key, x, y, w, t, what)
  local h = ImGui.GetFrameHeight(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  local on = mx >= x - 6 and mx < (R.pill_x1[key] or x + w + 6) and my >= y - 2 and my < y + h + 2
    and ImGui.IsWindowHovered(ctx) and not ImGui.IsAnyItemHovered(ctx)
    and not ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId())
  R.pill_hov[key] = on or nil
  if on then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
    ImGui.SetTooltip(ctx, "Click: move the edit cursor to " .. (what or "this change") .. " (" .. Util.fmt_beats(t) .. ").")
    if ImGui.IsMouseClicked(ctx, 0) then r.SetEditCurPos(t, true, false) end
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
      .. "longer shows it (it still plays). Settings > Devices > Channel can move it to the new channel.") or ""))
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(8)
  local pick
  for k, ch in ipairs(q.chans) do
    if k > 1 then ImGui.SameLine(ctx, 0, CFG.CTRL_GAP) end
    local label = (ch + 1 == q.d.chan) and ("Keep channel " .. (ch + 1)) or ("Channel " .. (ch + 1))
    if UI.button(label .. "##chq" .. ch, UI.btn_w(label, 90), nil, (ch + 1 == q.d.chan) and "primary" or nil) then pick = ch + 1 end
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
  local aw = ImGui.GetContentRegionAvail(ctx)
  local gap, h, lift = CFG.TAB_GAP, CFG.TAB_H, CFG.TAB_LIFT
  local n = #TAB_NAMES
  local tab_w = math.floor((aw - 2 * h - gap * (n + 1) - CFG.TAB_GROUP_GAP - 8) / n)
  -- a narrow window: when 1 name does not fit its tab, every text tab shows its icon (the name is its tooltip)
  ImGui.PushFont(ctx, head_font)
  local icons = false
  for i = 1, n do if (ImGui.CalcTextSize(ctx, TAB_NAMES[i])) > tab_w - 16 then icons = true; break end end
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
  for i = 1, n do tab(i, tab_w, x, icons and TAB_NAMES[i] or nil); x = x + tab_w + gap end
  x = x + CFG.TAB_GROUP_GAP
  tab(TAB_SETTINGS, h, x, "Settings"); x = x + h + gap
  tab(TAB_HELP, h, x, "Help: how MIDI Pilot works")
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
  ImGui.Dummy(ctx, 0, 0)
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
end

-- "No device yet": the hint of the Songs, Lanes and Presets tabs.
function UI.no_device_hint()
  if #S.devices > 0 then return false end
  UI.note("No device yet. Add your Quad Cortex in the Settings tab (the gear).", COL.YELLOW)
  if UI.button("Open Settings", UI.btn_w("Open Settings", 120), nil, "primary") then S.tab = TAB_SETTINGS; Util.mark_sdirty() end
  return true
end

-- The device that the Songs and Presets tabs show (a dropdown when there is more than 1). Returns it.
function UI.device_picker()
  R.cur_dev = Util.clamp(R.cur_dev or 1, 1, math.max(1, #S.devices))
  local d = S.devices[R.cur_dev]
  if #S.devices > 1 then
    local _, cw = UI.row_start("Device")
    ImGui.SetNextItemWidth(ctx, math.min(cw, 240))
    if ImGui.BeginCombo(ctx, "##curdev", d.name) then
      for i, x in ipairs(S.devices) do
        if ImGui.Selectable(ctx, x.name .. "##cd" .. i, i == R.cur_dev) then R.cur_dev = i end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("The device whose presets you see and change.")
    d = S.devices[R.cur_dev]
  end
  return d
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
  if pk.open then ImGui.OpenPopup(ctx, "Choose a preset##pick"); pk.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Choose a preset##pick", true, ImGui.WindowFlags_AlwaysAutoResize()) then
    R.pick = nil; return
  end
  local d, m = pk.d, MODELS[pk.d.model]
  ImGui.Text(ctx, "Song: " .. pk.rg.name)
  UI.vgap(6)
  ImGui.SetNextItemWidth(ctx, 200)
  local ch, v = ImGui.Combo(ctx, "Folder", pk.folder, Preset.folder_items(d))
  if ch then pk.folder = v end
  ImGui.SetNextItemWidth(ctx, 200)
  ch, v = UI.input_int("Bank", pk.bank, 1)
  if ch then pk.bank = Util.clamp(v, 1, m.banks) end
  ImGui.SetNextItemWidth(ctx, 200)
  local letters = R.letter_items and R.letter_items[pk.d.model]
  if not letters then
    R.letter_items = R.letter_items or {}
    letters = ""
    for k = 1, #m.letters do letters = letters .. m.letters:sub(k, k) .. "\0" end
    R.letter_items[pk.d.model] = letters
  end
  ch, v = ImGui.Combo(ctx, "Preset", pk.letter - 1, letters)
  if ch then pk.letter = v + 1 end
  local idx = Preset.index(d.model, pk.bank, pk.letter)
  UI.vgap(6)
  ImGui.TextColored(ctx, COL.TEXT_DIM, Preset.text(d, pk.folder, idx))
  UI.vgap(8)
  if UI.button("Use this preset", 140, nil, "primary") then
    UI.set_preset(d, pk.rg, pk.folder, idx); R.pick = nil; ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then R.pick = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

function UI.set_preset(d, rg, folder, index)
  if Midi.set_song(d, rg, folder, index) then UI.toast("'" .. rg.name .. "' starts at 0:00: its preset change is at 0:00.", true) end
end

-- 1 song row: number, name, length; the preset dropdown, Send now and the red X.
function UI.draw_song_row(d, i, rg, aw)
  ImGui.PushID(ctx, i)
  local fh = ImGui.GetFrameHeight(ctx)
  local ch = Midi.song_change(d, rg)
  local right_w = CFG.PRESET_W + 2 * (fh + CFG.CTRL_GAP)
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
  local cx, cy = x + 5, y + fh / 2
  if sc_open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, acol)
  else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, acol) end
  ImGui.DrawList_AddText(dl, x + 12, ty, acol, tostring(i))
  if on_arrow then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
    ImGui.SetTooltip(ctx, sc_open and "Close the scene list of this song." or "Open the scene list of this song.")
    if ImGui.IsMouseClicked(ctx, 0) then R.sc_open = R.sc_open or {}; R.sc_open[key] = not sc_open or nil end
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
  ImGui.SetNextItemWidth(ctx, CFG.PRESET_W)
  if inherited then ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.TEXT_DIM) end
  local open = ImGui.BeginCombo(ctx, "##preset", preview)
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
      R.pick = { d = d, rg = rg, folder = base and base.folder or 1, bank = idx // #m.letters + 1,
        letter = idx % #m.letters + 1, open = true }
    end
    ImGui.EndCombo(ctx)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, ch and ("The preset change of this song, at " .. Util.fmt_beats(ch.t) .. ".")
      or (inherited and "No preset change in this song: the preset from before goes on (grey).\nChoose a preset to add a change."
      or "No preset change yet. Choose a preset, or 'Choose by number...' for a preset without a name."))
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local cur = ch or Midi.active_at(d, rg.start)
  ImGui.BeginDisabled(ctx, cur == nil)
  if UI.icon_button("send", "send", fh) and cur then
    if not Midi.send_now(d, cur.folder, cur.index) then UI.toast(d.name .. ": the MIDI output is not available.", true) end
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Send this preset to the unit now (to hear it).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, ch == nil)
  if UI.remove_x_button("##rmpc", fh) and ch then UI.set_preset(d, rg, nil) end
  ImGui.EndDisabled(ctx)
  UI.tip("Remove the preset change of this song (the preset from before goes on).")
  local row_w = narrow and (aw - 14) or (name_area + 8 + right_w) -- (the strip ends where the row's last button ends)
  UI.draw_scene_strip(d, rg, x + 30, math.max(60, row_w - 30))
  if sc_open then UI.draw_scene_list(d, rg, x + 30, math.max(60, row_w - 30)) end
  ImGui.PopID(ctx)
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
        skip, t0, v, ev = g, g.t1, CFG.TEST_SEQ[#CFG.TEST_SEQ], nil -- (its change is the test's: no menu)
      else
        t0, v, ev = math.max(ts, rg.start), s.v, s
      end
    end
  end
  if rg.stop > t0 + 0.0001 then blocks[#blocks + 1] = { t0 = t0, t1 = rg.stop, v = v, ev = ev } end
  ImGui.DrawList_AddRectFilled(dl, sx, sy, sx + w, sy + h, COL.FIELD, 5)
  local mx = ImGui.GetMousePos(ctx)
  local hb
  for _, bl in ipairs(blocks) do
    local x0, x1 = xt(bl.t0), xt(bl.t1)
    if bl.test then
      ImGui.DrawList_AddRectFilled(dl, x0 + 1, sy + 1, x1 - 1, sy + h - 1, SC_TEST, 4)
      if x1 - x0 > 14 then
        ImGui.DrawList_PushClipRect(dl, x0 + 3, sy, x1 - 3, sy + h, true)
        local label = UI.trunc("Scene test", math.max(8, x1 - x0 - 8))
        local tw = ImGui.CalcTextSize(ctx, label)
        ImGui.DrawList_AddText(dl, math.max(x0 + 5, math.floor((x0 + x1 - tw) / 2)),
          math.floor(sy + h / 2 - ImGui.GetFontSize(ctx) * CFG.TEXT_MID + 0.5), SC_TEXT, label)
        ImGui.DrawList_PopClipRect(dl)
      end
    elseif bl.v then
      local pc = Midi.preset_at(d, rg, bl.t0)
      local ci = Preset.scene_col(d, pc and pc.folder, pc and pc.index or 0, bl.v)
      ImGui.DrawList_AddRectFilled(dl, x0 + 1, sy + 1, x1 - 1, sy + h - 1, SC_COLS[ci], 4)
      if x1 - x0 > 14 then
        local label = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, bl.v)
        ImGui.DrawList_PushClipRect(dl, x0 + 3, sy, x1 - 3, sy + h, true)
        label = UI.trunc(label, math.max(8, x1 - x0 - 8))
        local tw = ImGui.CalcTextSize(ctx, label)
        -- the middle of the capitals on the middle of the block (CFG.TEXT_MID: measured, as in Chart Cue)
        ImGui.DrawList_AddText(dl, math.max(x0 + 5, math.floor((x0 + x1 - tw) / 2)),
          math.floor(sy + h / 2 - ImGui.GetFontSize(ctx) * CFG.TEXT_MID + 0.5), SC_TEXT, label)
        ImGui.DrawList_PopClipRect(dl)
      end
    end
    if hov and mx >= x0 and mx < x1 then
      hb = bl
      ImGui.DrawList_AddRect(dl, x0 + 1, sy + 1, x1 - 1, sy + h - 1, COL.WHITE, 4, 0, 1.5)
    end
  end
  if not hb then return end
  ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  local pc = Midi.preset_at(d, rg, hb.t0)
  if hb.test then
    ImGui.SetTooltip(ctx, "Scene test: every scene from I-A to II-D and back to I-A, a change every "
      .. CFG.TEST_BEATS .. " beats,\nfrom " .. Util.fmt_song_time(rg, hb.t0) .. " to " .. Util.fmt_song_time(rg, hb.t1)
      .. ". Then the song stays on I-A.\nClick: move the edit cursor here. The red X in the scene list removes it.")
    if clicked then r.SetEditCurPos(hb.t0, true, false) end
    return
  end
  ImGui.SetTooltip(ctx, (hb.v and (Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, hb.v) .. "  (scene "
    .. MODELS[d.model].scenes[hb.v + 1] .. ")  from " .. Util.fmt_song_time(rg, hb.t0)) or "No scene change.")
    .. "\nClick: move the edit cursor here." .. (hb.ev and " Right-click: change or remove this scene." or ""))
  -- (the start scene: the song start, so the cursor is inside the song)
  if clicked then r.SetEditCurPos(hb.ev and math.max(hb.ev.t, rg.start) or hb.t0, true, false) end
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
    for v = 0, 7 do
      local nm = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v)
      if ImGui.Selectable(ctx, nm .. "##sm" .. v, ev.v == v) and ev.v ~= v then
        Midi.change_scene(d, ev, v); R.scm = nil
      end
    end
    ImGui.Separator(ctx)
    if ImGui.Selectable(ctx, "Send this scene now##smsend") and not Midi.send_scene(d, ev.v) then
      UI.toast(d.name .. ": the MIDI output is not available.", true)
    end
    if ImGui.Selectable(ctx, "Remove this scene change##smrm") then
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
      local rt = row.start and rg.start or (row.ev and row.ev.t)
      if rt and rt <= tc + CFG.EDGE then cur_n = n end
    end
  end
  for n, row in ipairs(rows) do
    ImGui.PushID(ctx, n)
    local y = select(2, ImGui.GetCursorScreenPos(ctx))
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
      UI.tip("The start scene: the scene at the song start. Its place cannot be changed (it marks the song start);\n"
        .. "choose its scene on the right.")
      at(C_TIME, y)
      UI.row_text(Util.fmt_song_time(rg, math.max(t, rg.start)), COL.TEXT_DIM)
      UI.tip("The start scene: at the song start.")
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
      local nd = UI.nudge_buttons("s", fh, row.test and "the Scene test" or "this scene change")
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
      UI.tip("Every scene from I-A to II-D and back to I-A, a change every " .. CFG.TEST_BEATS .. " beats. Then the song stays on I-A.\n"
        .. "Type a new position to move the whole test.")
    else
      ImGui.SetNextItemWidth(ctx, cw)
      local preview = cur and Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, cur)
        or ("(" .. Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, Midi.default_start(d, pc)) .. ")")
      if not cur then ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.TEXT_DIM) end
      local open = ImGui.BeginCombo(ctx, "##scv", preview)
      if not cur then ImGui.PopStyleColor(ctx) end
      if open then
        for v = 0, 7 do
          local nm = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v)
          if Preset.has_scene_name(d, pc and pc.folder, pc and pc.index or 0, v) then nm = nm .. "  (" .. MODELS[d.model].scenes[v + 1] .. ")" end
          if ImGui.Selectable(ctx, nm .. "##v" .. v, cur == v) then change = { ev = ev, t = t, v = v } end
        end
        ImGui.EndCombo(ctx)
      end
      UI.tip(row.start and not ev and "No start scene yet. Choose one (or click Fill songs)." or "The scene from here on.")
      at(C_SEND, y)
      local sv = cur or Midi.default_start(d, pc)
      if UI.icon_button("scs", "send", fh) and not Midi.send_scene(d, sv) then UI.toast(d.name .. ": the MIDI output is not available.", true) end
      UI.tip("Send this scene to the unit now (to hear it).")
    end
    at(C_X, y)
    ImGui.BeginDisabled(ctx, ev == nil)
    if UI.remove_x_button("##scx", fh) and ev then
      if row.test then test_rm = row.test else remove = ev end
    end
    ImGui.EndDisabled(ctx)
    UI.tip(row.test and "Remove this scene test (all its scene changes)." or "Remove this scene change.")
    UI.pill_end(pkey, rx, y, row_w, row.start and rg.start or t,
      row.start and "the song start" or (row.test and "the Scene test" or "this scene change"))
    ImGui.PopID(ctx)
  end
  if box then ImGui.EndChild(ctx) end
  -- the bottom row: the song nudge (under the nudge column), add at the edit cursor, clear
  local by = select(2, ImGui.GetCursorScreenPos(ctx))
  ImGui.SetCursorScreenPos(ctx, x0 + C_POS, by)
  UI.row_text("Song", COL.TEXT_DIM)
  UI.tip("The nudge of the whole song: all scene changes (not the start scene) and knob values.")
  ImGui.SetCursorScreenPos(ctx, x0 + C_NUDGE, by)
  local snd = UI.nudge_buttons("song", fh, "all scene changes (not the start scene) and knob values of this song")
  if snd and not Midi.nudge_song(d, rg, snd) then UI.toast("A nudge cannot move a change out of the song (or before its start scene).", true) end
  ImGui.SetCursorScreenPos(ctx, x0 + C_SCENE, by)
  ImGui.SetNextItemWidth(ctx, math.max(cw, 200))
  if ImGui.BeginCombo(ctx, "##scadd", "Add scene at edit cursor", ImGui.ComboFlags_HeightLargest()) then
    local tc = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
    local pc = Midi.preset_at(d, rg, tc) or pcs
    for v = 0, 7 do
      local nm = Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, v)
      if ImGui.Selectable(ctx, nm .. "##a" .. v) then
        local ts = UI.cursor_in_song(rg, tc)
        if ts then Midi.add_scene(d, ts, v) end
      end
    end
    ImGui.Separator(ctx)
    if ImGui.Selectable(ctx, "Scene test##atest") then
      local ts = UI.cursor_in_song(rg, tc)
      local tend = ts and Midi.add_test(d, rg, ts)
      if tend then
        r.SetEditCurPos(tend, true, false) -- (the edit cursor goes to the test end, to add the next scene there)
      elseif ts then
        UI.toast("No room for a scene test here: it needs " .. (#CFG.TEST_SEQ * CFG.TEST_BEATS) .. " beats before the song end.", true)
      end
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Every scene from I-A to II-D and back to I-A, a change every " .. CFG.TEST_BEATS
        .. " beats from the edit cursor.\nThe scene changes already there are replaced.")
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Put REAPER's edit cursor where the scene must change (during playback: the play position),\n"
    .. "then choose the scene. It goes exactly at the edit cursor.")
  ImGui.SameLine(ctx, 0, gap)
  ImGui.BeginDisabled(ctx, #list == 0)
  if UI.button("Clear scenes", UI.btn_w("Clear scenes", 0)) then
    UI.toast(string.format("%d scene change(s) removed from '%s'.", Midi.clear(d, rg), rg.name))
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Removes all scene changes of this song (Ctrl+Z brings them back).")
  if change then
    if change.ev then Midi.change_scene(d, change.ev, change.v) else Midi.add_scene(d, change.t, change.v) end
  end
  if remove then Midi.remove_scene(d, remove) end
  if test_rm then Midi.remove_test(d, rg, test_rm) end
  if test_mv and not Midi.remove_test(d, rg, test_mv.g, test_mv.t) then
    UI.toast("No room for the scene test there: it needs " .. (#CFG.TEST_SEQ * CFG.TEST_BEATS) .. " beats before the song end.", true)
  end
  if movem then Midi.move_scene(d, movem.ev, movem.t) end
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
function UI.draw_songs_tab()
  if UI.no_device_hint() then return end
  local d = UI.device_picker()
  if not Dev.track(d) then
    UI.note(d.name .. " has no track in this project yet. Create it in Settings > Devices.", COL.YELLOW)
    if UI.button("Create track", UI.btn_w("Create track", 110), nil, "primary") then Dev.create_track(d) end
    return
  end
  UI.heading(string.format("Songs (%d)", #R.regions) , "Each song is a region of the project, in timeline order, "
    .. "with its preset. A preset change is written as normal MIDI (Bank/Program Select) at the song start "
    .. "(Settings > Preset timing). Grey: the song has no preset change, and the preset from before goes on.\n\n"
    .. "Fill songs: each song without its own change gets the preset that is already playing there, at its "
    .. "start, a start scene, and the value of each control (Lanes) that plays there. Then playback can start in "
    .. "any song, and the unit loads the right preset, scene and values.\n"
    .. "Presets match Regions: a song (region) with the name of a preset (Presets tab) gets that preset.\n"
    .. "Scenes match Markers: a marker in a song with the name of a scene gets that scene change.\n"
    .. "Merge repeated scenes: a scene change to the scene that already plays is removed.")
  if #R.regions == 0 then
    UI.note("This project has no regions. Make 1 region for each song (Insert > Region from time selection).")
    return
  end
  -- the buttons: on 1 line, or more when the panel is narrow
  local bx0 = ImGui.GetCursorPosX(ctx)
  local bmax = bx0 + ImGui.GetContentRegionAvail(ctx)
  local function flow(label)
    local w = UI.btn_w(label, 0)
    local lx = ImGui.GetItemRectMax(ctx) - ImGui.GetWindowPos(ctx) + ImGui.GetScrollX(ctx)
    if lx + CFG.CTRL_GAP + w <= bmax then ImGui.SameLine(ctx, 0, CFG.CTRL_GAP) end
    return w
  end
  if UI.button("Fill songs", UI.btn_w("Fill songs", 0)) then
    local n = Midi.fill_starts(d)
    UI.toast(n == 0 and "Every song has its preset and start scene." or string.format("%d change(s) added.", n))
  end
  UI.tip("Songs without their own preset change (grey) get the preset that is already playing there,\n"
    .. "songs without a start scene get one, and each control gets the value that plays at each song start.\n"
    .. "Then playback can start in any song, and the unit loads the right preset, scene and values.")
  if UI.button("Presets match Regions", flow("Presets match Regions")) then
    local n = Midi.match_names(d)
    UI.toast(n == 0 and "No song name matches a preset name." or string.format("%d song(s) matched.", n))
  end
  UI.tip("A song with the same name as a preset (Presets tab) gets that preset (for example 'Song One').")
  if UI.button("Scenes match Markers", flow("Scenes match Markers")) then
    local n = Midi.match_markers(d)
    UI.toast(n == 0 and "No marker matches a scene name." or string.format("%d scene change(s) from markers.", n))
  end
  UI.tip("A marker inside a song whose name is a scene name of the preset there (for example 'Chorus'),\n"
    .. "or a scene letter (A, B ... on the mini I-A, II-B), gets that scene change.")
  if UI.button("Merge repeated scenes", flow("Merge repeated scenes")) then
    local n = Midi.merge_all(d)
    UI.toast(n == 0 and "No repeated scenes to merge." or string.format("%d repeated scene change(s) merged.", n))
  end
  UI.tip("In each song, a scene change to the scene that already plays is removed, so 2 blocks of the same scene\n"
    .. "become 1 (not the start scene, not a scene test). Ctrl+Z brings them back.")
  if UI.button("Clear all scenes", flow("Clear all scenes"), nil, "danger") then
    UI.ask("Remove all scene changes of " .. d.name .. " in this project? Ctrl+Z brings them back.", "Yes, clear",
      function() UI.toast(string.format("%d scene change(s) removed.", Midi.clear(d))) end)
  end
  UI.tip("Removes all scene changes of this device in the project (asks first).")
  if UI.button("Clear all presets", flow("Clear all presets"), nil, "danger") then
    UI.ask("Remove all preset changes of " .. d.name .. " in this project? The scene changes stay. Ctrl+Z brings them back.",
      "Yes, clear", function() UI.toast(string.format("%d preset change(s) removed.", Midi.clear(d, nil, true))) end)
  end
  UI.tip("Removes all preset changes of this device in the project (asks first).")
  UI.vgap(4)
  local aw = ImGui.GetContentRegionAvail(ctx)
  for i, rg in ipairs(R.regions) do UI.draw_song_row(d, i, rg, aw); UI.vgap(6) end
  UI.draw_pick()
  UI.draw_scene_menu()
end

-- Lanes: the knobs of a device (a CC in the units of a knob of the unit), and the values of 1 knob in the song
-- at the edit cursor (add, change, remove, send).
function UI.draw_lanes_tab()
  if UI.no_device_hint() then return end
  local d = UI.device_picker()
  local knobs = S.knobs[d.id] or Knob.parse("")
  S.knobs[d.id] = knobs
  local fh = ImGui.GetFrameHeight(ctx)
  UI.heading(string.format("Controls (%d)", #knobs), "A control is a CC that moves a knob of the unit, for example "
    .. "Expression 1 (CC#1) when you assign the expression pedal to a filter on the unit. Enter the range that you "
    .. "set on the unit (heel = Min, toe = Max) and its unit: MIDI Pilot then shows and writes the values in that "
    .. "unit (650 Hz in place of a CC value of 97).\n\nA CC has 128 steps, so some values cannot be sent exactly: "
    .. "MIDI Pilot uses the nearest one. Saved on this computer, for this device.")
  local rm
  -- the columns: CC, name, min, max, unit (the labels above them)
  local x0 = ImGui.GetCursorPosX(ctx)
  local CW = { 120, 160, 90, 90, 90 }
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
    UI.tip("The CC number." .. (QC_CCS[k.cc] and ("\nCC#" .. k.cc .. " is the unit's " .. QC_CCS[k.cc] .. " CC: it also does that.") or ""))
    ImGui.SameLine(ctx, cols[2])
    ImGui.SetNextItemWidth(ctx, CW[2])
    local ch2, nm = ImGui.InputText(ctx, "##kn", k.name)
    if ch2 then k.name = Util.clean(nm); Util.mark_sdirty() end
    UI.tip("The name of the knob, for example Filter or Volume.")
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
    UI.tip("The unit of the knob on the Quad Cortex.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.remove_x_button("##krm", fh) then rm = n end
    UI.tip("Remove this control (its MIDI stays in the project).")
    if QC_CCS[k.cc] then
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      UI.warn_icon("##kw", fh)
      UI.tip("CC#" .. k.cc .. " is the unit's " .. QC_CCS[k.cc] .. " CC: a value here also does that.")
    end
    ImGui.PopID(ctx)
  end
  if rm then table.remove(knobs, rm); Util.mark_sdirty(); R.lane_k = nil end
  if UI.button("Add control", UI.btn_w("Add control", 110)) then
    local used, cc = {}, 3
    for _, k in ipairs(knobs) do used[k.cc] = true end
    while used[cc] or QC_CCS[cc] do cc = cc + 1 end
    knobs[#knobs + 1] = { cc = Util.clamp(cc, 0, 127), name = "Control " .. (#knobs + 1), min = 0, max = 100, unit = "%" }
    Util.mark_sdirty()
  end
  UI.tip("Adds a control on a free CC number. Assign the same CC to the knob on the unit.")
  if #knobs == 0 then return end

  -- the values of 1 knob in the song at the edit cursor (during playback: the play position)
  local tc = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
  local rg = Midi.song_at(tc)
  R.lane_k = Util.clamp(R.lane_k or 1, 1, #knobs)
  local k = knobs[R.lane_k]
  local all = S.lane_all
  UI.heading(all and "Values in all songs" or (rg and ("Values in " .. (rg.name ~= "" and rg.name or "(unnamed region)")) or "Values"),
    "The values of the selected control in the song at the edit cursor (during playback: the play position), "
    .. "or in all songs ('All songs'). Type a value in its unit: MIDI Pilot writes the nearest CC value. Bars and "
    .. "beats: in the project; time: from the song start.\n\nSlope: how the value goes to the next value. Jump: it "
    .. "changes at the next value. Straight, Slow start and end, Fast start, Fast end: it moves there in that way "
    .. "(for swells and fades). Curve: you choose how much it bends.")
  local _, cw = UI.row_start("Control")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 240))
  if ImGui.BeginCombo(ctx, "##lk", string.format("%s  (CC#%d)", k.name, k.cc)) then
    for i, x in ipairs(knobs) do
      if ImGui.Selectable(ctx, string.format("%s  (CC#%d)##k%d", x.name, x.cc, i), i == R.lane_k) then R.lane_k = i end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx, 0, 16)
  local ach, av = UI.toggle_line("All songs", all, "On: the values of this control in every song. Off: only the song at the edit cursor.")
  if ach then S.lane_all = av; all = av; Util.mark_sdirty() end
  if not all and not rg then
    UI.note("Put the edit cursor inside a song (region), or turn on 'All songs'.")
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
  local change, remove, shape, nudge
  local vx = ImGui.GetCursorPosX(ctx)
  -- the columns: position, time, nudge, value, slope (and its bend), then send and remove
  local gap = CFG.CTRL_GAP
  local NUD = vx + 150
  local VAL = NUD + 2 * fh + 2 * gap
  local SLO = VAL + 110 + gap
  local SND = SLO + 160 + gap -- (send and remove right after the slope; a Curve's bend goes after them)
  local VC = { vx, vx + 78, NUD, VAL, SLO, SND, SND + fh + gap }
  local any = false
  for _, g in ipairs(groups) do if #g.list > 0 then any = true end end
  -- the labels above the columns: in each song's section (under its title)
  local function col_labels()
    local vh = { "Position", "Time", "Nudge", "Value", "Slope to the next value" }
    for i, hname in ipairs(vh) do
      if i > 1 then ImGui.SameLine(ctx, VC[i]) else ImGui.SetCursorPosX(ctx, VC[1]) end
      ImGui.TextColored(ctx, COL.TEXT_DIM, hname)
    end
  end
  for gi, g in ipairs(groups) do
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
    -- a long list scrolls (Settings > Lists): the rows go in a child window; its columns start at its own left edge
    local scroll = not closed and #list > S.lane_rows
    local VC, vx = VC, vx
    if scroll then
      local rh = ImGui.GetFrameHeightWithSpacing(ctx)
      ImGui.SetCursorPosX(ctx, vx)
      -- as wide as the rows (the slope, its bend and the red X), so its scrollbar is right after the X buttons;
      -- the scrollbar always shows, in a lighter colour than the page's
      local bw = (VC[7] - vx) + fh + gap + 110 + 26 -- (the bend of a Curve after the red X; room for the pills)
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
    for n, e in ipairs(closed and {} or list) do
      ImGui.PushID(ctx, "v" .. gi .. ":" .. n)
      -- the pill of the row (a click moves the edit cursor there)
      ImGui.SetCursorPosX(ctx, VC[1])
      local px, py = ImGui.GetCursorScreenPos(ctx)
      local pw = VC[7] - VC[1] + fh
      local pkey = "kv" .. k.cc .. ":" .. string.format("%.4f", e.t)
      UI.pill_begin(pkey, px, py, pw, n == cur_n)
      -- position and time (editable: a typed time moves the value)
      local key = string.format("k%d:%.4f", k.cc, e.t)
      local tb = UI.edit_time("kb" .. key, 70, Util.fmt_beats(e.t), Util.parse_beats, BEATS_TIP, true)
      ImGui.SameLine(ctx, VC[2])
      local tt = UI.edit_time("kt" .. key, 64, Util.fmt_song_time(grg, e.t),
        function(s) return Util.parse_song_time(grg, s) end, TIME_TIP)
      local tn = tb or tt
      if tb == false or tt == false then UI.toast("Type a time inside the song, before its end.", true)
      elseif tn then
        if tn < grg.start or tn >= grg.stop - CFG.EDGE then UI.toast("Type a time inside the song, before its end.", true)
        elseif math.abs(tn - e.t) > 0.0005 then nudge = { e = e, t = tn } end
      end
      -- nudge
      ImGui.SameLine(ctx, VC[3])
      local nd = UI.nudge_buttons("k", fh, "this value")
      if nd then
        local nt = Midi.nudged(e.t, nd)
        if nt < grg.start or nt >= grg.stop - CFG.EDGE then UI.toast("A nudge cannot move it out of the song.", true)
        else nudge = { e = e, t = nt } end
      end
      -- the value
      ImGui.SameLine(ctx, VC[4])
      local id = string.format("%d:%.4f", k.cc, e.t)
      R.kv_text = R.kv_text or {}
      ImGui.SetNextItemWidth(ctx, 110)
      local _, nt = ImGui.InputText(ctx, "##kv", R.kv_text[id] or Knob.fmt(k, Knob.from_cc(k, e.v)))
      if ImGui.IsItemActive(ctx) then R.kv_text[id] = nt
      elseif ImGui.IsItemDeactivated(ctx) then
        local val = Knob.parse_value(R.kv_text[id] or nt)
        R.kv_text[id] = nil
        if val then change = { e = e, v = Knob.to_cc(k, val), want = val } else UI.toast("Type a number, for example 650.", true) end
      else R.kv_text[id] = nil end
      UI.tip(string.format("CC value %d. Type a new value in %s and press Enter.", e.v, k.unit ~= "" and k.unit or "numbers"))
      -- the slope to the next value (not on the last value of a song: there is no next one)
      ImGui.SameLine(ctx, VC[5])
      local last = (n == #list)
      ImGui.BeginDisabled(ctx, last)
      ImGui.SetNextItemWidth(ctx, 160)
      local sch, si = ImGui.Combo(ctx, "##shape", e.shape, CC_SHAPE_ITEMS)
      if sch then shape = { e = e, s = si, ten = e.tension } end
      ImGui.EndDisabled(ctx)
      UI.tip(last and "The last value of the song: no next value to move to."
        or "How the value goes to the next value: Jump (changes at the next value), or it moves there in that way.")
      ImGui.SameLine(ctx, VC[6])
      if UI.icon_button("ks", "send", fh) and not Midi.send_cc(d, k.cc, e.v) then UI.toast(d.name .. ": the MIDI output is not available.", true) end
      UI.tip("Send this value to the unit now.")
      ImGui.SameLine(ctx, VC[7])
      if UI.remove_x_button("##kx", fh) then remove = e end
      UI.tip("Remove this value.")
      UI.pill_end(pkey, px, py, pw, e.t, "this value")
      if e.shape == 5 and not last then
        ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
        ImGui.SetNextItemWidth(ctx, 110)
        local tch, tv = ImGui.SliderDouble(ctx, "##ten", e.tension, -1, 1, "%.2f")
        if ImGui.IsItemDeactivatedAfterEdit(ctx) or (tch and not ImGui.IsItemActive(ctx)) then shape = { e = e, s = 5, ten = tv }
        elseif tch then e.tension = tv end
        UI.tip("Curve: how much it bends. Below 0 it starts fast, above 0 it starts slowly.")
      end
      ImGui.PopID(ctx)
    end
    if scroll then ImGui.EndChild(ctx) end
  end
  if not any then UI.note(all and "No values of this control in any song yet." or "No values of this control in this song yet.") end
  if nudge then Midi.set_cc(d, k.cc, nudge.t, nudge.e.v, nudge.e) end
  if not rg then -- (All songs, the cursor outside the songs: nothing to add to)
    if change then Midi.set_cc(d, k.cc, change.e.t, change.v, change.e) end
    if remove then Midi.remove_cc(d, k.cc, remove) end
    if shape then Midi.set_shape(d, k.cc, shape.e, shape.s, shape.ten) end
    UI.note("Put the edit cursor inside a song to add a value.")
    return
  end
  -- add at the edit cursor: 2 groups with a small title each, "Add a value" and "Add a ramp" (a swell: its rows
  -- indented under the Swell toggle), in the label column form of the Settings tab
  local unit = k.unit ~= "" and k.unit or ""
  local function hint(v) return Knob.fmt(k, v) end
  local function subtitle(s, extra)
    UI.vgap(10)
    local sx, sy = ImGui.GetCursorScreenPos(ctx)
    local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
    ImGui.PushFont(ctx, bold)
    UI.row_text(s, COL.HEADING)
    ImGui.PopFont(ctx)
    if extra then ImGui.SameLine(ctx, 0, CFG.CTRL_GAP); UI.row_text(extra, COL.TEXT_DIM) end
    local fh2 = ImGui.GetFrameHeight(ctx)
    ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), sx, sy + fh2 + 1, sx + full, sy + fh2 + 1, COL.LINE, 1)
    UI.vgap(CFG.SP_ROW + 2)
  end
  -- the field of a "Custom..." length, next to its dropdown
  local function custom_field(id, cur)
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, 70)
    local _, nv = ImGui.InputTextWithHint(ctx, id, "2.2", cur or "")
    UI.tip("The length in bars.beats: 3 = 3 bars, 0.6 = 6 beats, 2.2 = 2 bars and 2 beats\n"
      .. "(bars follow the time signature, beats the tempo).")
    if not Midi.parse_length(nv) then ImGui.SameLine(ctx, 0, CFG.CTRL_GAP); UI.row_text("bars.beats", COL.TEXT_DIM) end
    return nv
  end
  local function hint_field(id, w, cur, hint_text, tip)
    ImGui.SetNextItemWidth(ctx, w)
    local _, nv = ImGui.InputTextWithHint(ctx, id, hint_text, cur)
    UI.tip(tip)
    return nv
  end
  -- a value: the control jumps there
  subtitle("Add a value", "at the edit cursor (" .. Util.fmt_beats(tc) .. ")")
  R.kadd = R.kadd or ""
  UI.row_start("Value")
  R.kadd = hint_field("##kadd", 110, R.kadd, hint(k.min),
    "A value in " .. (unit ~= "" and unit or "numbers") .. " (" .. hint(k.min) .. " to " .. hint(k.max) .. "). The control jumps there and stays.")
  local val = Knob.parse_value(R.kadd)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, val == nil)
  if UI.button("Add at edit cursor", UI.btn_w("Add at edit cursor", 0), nil, "primary") and val then
    Midi.set_cc(d, k.cc, tc, Knob.to_cc(k, val))
    UI.toast("Added " .. hint(Knob.from_cc(k, Knob.to_cc(k, val))) .. " at " .. Util.fmt_beats(tc) .. ".")
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Writes the value exactly at the edit cursor (during playback: the play position).")
  if val then
    local c = Knob.to_cc(k, val)
    local near = Knob.from_cc(k, c)
    local outside = val < math.min(k.min, k.max) or val > math.max(k.min, k.max)
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    UI.row_text(outside and ("Outside " .. hint(k.min) .. " - " .. hint(k.max))
      or (math.abs(near - val) > 1e-6 and ("Nearest: " .. hint(near)) or ("CC value " .. c)), outside and COL.YELLOW or COL.TEXT_DIM)
  end
  -- a ramp (needs no value first): from, to, length, slope; a swell goes back
  local rp = R.ramp or { from = "", to = "", len = 5, shape = 0, ten = 0, back = false,
    v2 = "", hold = 0, blen = 5, bshape = 0, bten = 0 }
  R.ramp = rp
  subtitle("Add a ramp", "from the edit cursor (" .. Util.fmt_beats(tc) .. ")")
  local _, cw = UI.row_start("From / to / swell")
  local DW = math.min(cw, 220) -- (the width of the Length dropdown)
  local AW = 18                -- (the arrow between the 2 fields)
  local FW = math.floor((DW - AW - 2 * CFG.CTRL_GAP) / 2)
  rp.from = hint_field("##rfrom", FW, rp.from, hint(k.min), "The value at the start" .. (unit ~= "" and (" (" .. unit .. ")") or "") .. ".")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  do -- the arrow: a line and a head
    local ax, ay = ImGui.GetCursorScreenPos(ctx)
    local fh2 = ImGui.GetFrameHeight(ctx)
    ImGui.Dummy(ctx, AW, fh2)
    local dl = ImGui.GetWindowDrawList(ctx)
    local cy = math.floor(ay + fh2 / 2) + 0.5
    ImGui.DrawList_AddLine(dl, ax + 2, cy, ax + AW - 5, cy, COL.TEXT_DIM, 2)
    ImGui.DrawList_AddTriangleFilled(dl, ax + AW - 7, cy - 5, ax + AW - 7, cy + 5, ax + AW, cy, COL.TEXT_DIM)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  rp.to = hint_field("##rto", FW, rp.to, hint(k.max), "The value at the end (a swell: the top). Then the value stays there.")
  ImGui.SameLine(ctx, 0, 2 * CFG.CTRL_GAP)
  local bch, bk = UI.toggle_line("Swell", rp.back, "Swell: there and back (for example 0 - 100 - 0): a hold at the top, then the way back.")
  if bch then rp.back = bk end
  _, cw = UI.row_start("Length")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
  local lch, li = ImGui.Combo(ctx, "##rlen", rp.len - 1, RAMP_LEN_ITEMS)
  if lch then rp.len = li + 1 end
  UI.tip("How long (beats follow the tempo, bars the time signature). Custom...: type it.\n"
    .. "'To the time selection end': select the end with REAPER's time selection.")
  if RAMP_LENS[rp.len].custom then rp.lenc = custom_field("##rlenc", rp.lenc) end
  _, cw = UI.row_start("Slope")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
  local sch2, sh = ImGui.Combo(ctx, "##rshape", rp.shape, RAMP_SHAPE_ITEMS)
  if sch2 then rp.shape = sh end
  UI.tip("How the value moves.")
  if rp.shape == 4 then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, 110)
    _, rp.ten = ImGui.SliderDouble(ctx, "##rten", rp.ten, -1, 1, "%.2f")
    UI.tip("Curve: how much it bends. Below 0 it starts fast, above 0 it starts slowly.")
  end
  local v0, v1 = Knob.parse_value(rp.from), Knob.parse_value(rp.to)
  local sw, bad
  if rp.back then
    -- the swell rows, indented under Swell
    _, cw = UI.row_start("      Hold")
    ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
    local hch, hi = ImGui.Combo(ctx, "##rhold", rp.hold, HOLD_ITEMS)
    if hch then rp.hold = hi end
    UI.tip("How long the value stays at the top before it goes back. Custom...: type it.")
    if rp.hold > 0 and RAMP_LENS[rp.hold].custom then rp.holdc = custom_field("##rholdc", rp.holdc) end
    UI.row_start("      Back to")
    rp.v2 = hint_field("##rv2", 110, rp.v2, "= start", "The value at the end of the swell. Empty: back to the start value.\n"
      .. "It cannot go past the top (a swell up stays at or below its top, a swell down at or above its bottom).")
    _, cw = UI.row_start("      Length")
    ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
    local blch, bli = ImGui.Combo(ctx, "##rblen", rp.blen - 1, BACK_LEN_ITEMS)
    if blch then rp.blen = bli + 1 end
    UI.tip("How long the way back is. Custom...: type it.")
    if RAMP_LENS[rp.blen].custom then rp.blenc = custom_field("##rblenc", rp.blenc) end
    _, cw = UI.row_start("      Slope")
    ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
    local bsch, bsh = ImGui.Combo(ctx, "##rbshape", rp.bshape, RAMP_SHAPE_ITEMS)
    if bsch then rp.bshape = bsh end
    UI.tip("How the value moves on the way back.")
    if rp.bshape == 4 then
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      ImGui.SetNextItemWidth(ctx, 110)
      _, rp.bten = ImGui.SliderDouble(ctx, "##rbten", rp.bten, -1, 1, "%.2f")
      UI.tip("Curve: how much it bends. Below 0 it starts fast, above 0 it starts slowly.")
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
  if UI.button(blabel .. "##radd", UI.btn_w(blabel, 0), nil, "primary") and ok_add and pts and tend then
    Midi.add_ramp(d, k.cc, pts, rp.back and "swell" or "ramp")
    local function f(c) return hint(Knob.from_cc(k, c)) end
    UI.toast((rp.back and ("Swell " .. f(pts[1].v) .. " - " .. f(Knob.to_cc(k, v1)) .. " - " .. f(pts[#pts].v))
      or ("Ramp " .. f(pts[1].v) .. " to " .. f(pts[#pts].v))) .. ", " .. Util.fmt_beats(tc) .. " to " .. Util.fmt_beats(tend) .. ".")
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Writes it from the edit cursor. Its values show in the list; the values of this control inside it are\n"
    .. "replaced. Ctrl+Z takes it back.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  UI.row_text(UI.trunc(why, math.max(40, ImGui.GetContentRegionAvail(ctx) - 8)), why_col)
  UI.tip(why)
  if change then
    Midi.set_cc(d, k.cc, change.e.t, change.v, change.e)
    local got = Knob.from_cc(k, change.v)
    if math.abs(got - change.want) > 1e-6 then UI.toast("Nearest value: " .. Knob.fmt(k, got) .. ".") end
  end
  if remove then Midi.remove_cc(d, k.cc, remove) end
  if shape then Midi.set_shape(d, k.cc, shape.e, shape.s, shape.ten) end
end

-- A yellow warning sign (a triangle with "!"), the size of a control.
function UI.warn_icon(id, size)
  ImGui.InvisibleButton(ctx, id, size, size)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx = x0 + size / 2
  ImGui.DrawList_AddTriangleFilled(dl, cx, y0 + 3, x0 + size - 3, y0 + size - 4, x0 + 3, y0 + size - 4, COL.YELLOW)
  ImGui.DrawList_AddLine(dl, cx, y0 + 9, cx, y0 + size - 10, COL.WIN_BG, 2)
  ImGui.DrawList_AddCircleFilled(dl, cx, y0 + size - 7, 1.3, COL.WIN_BG)
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
  ImGui.Text(ctx, "The unit's name: " .. FOLDERS[fr.folder] .. ". Empty: this name again.")
  ImGui.SetNextItemWidth(ctx, 260)
  if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
  local _
  _, fr.name = ImGui.InputText(ctx, "##frname", fr.name)
  local enter = ImGui.IsItemDeactivated(ctx) and (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter()) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter()))
  UI.vgap(8)
  if UI.button("Rename", 100, nil, "primary") or enter then
    Preset.set_folder_name(fr.d, fr.folder, fr.name); R.frename = nil; ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then R.frename = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- Presets: the preset names of a device (saved on this computer, for all projects).
function UI.draw_presets_tab()
  if UI.no_device_hint() then return end
  local d = UI.device_picker()
  local m = MODELS[d.model]
  UI.heading("Add a preset", "Give your presets names, for example 3B = Song One. The Songs tab shows them, "
    .. "'Presets match Regions' uses them, and REAPER can show them (Settings > General).\n\n"
    .. "Saved on this computer, for all projects. The scene names and colours of a preset: 'Scenes...' in the list.")
  local a = R.lib_add or { folder = 1, bank = 1, letter = 1, name = "" }
  R.lib_add = a
  local ch, v
  local _, cw = UI.row_start("Folder")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 200))
  ch, v = ImGui.Combo(ctx, "##lfolder", a.folder, Preset.folder_items(d))
  if ch then a.folder = v end
  UI.tip("The folder of the preset on the unit (the unit calls it a setlist).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Rename...##fold", UI.btn_w("Rename...", 80)) then
    R.frename = { d = d, folder = a.folder, name = Preset.folder_name(d, a.folder), open = true }
  end
  UI.tip("Give this folder your own name (for example the name of your band).")
  _, cw = UI.row_start("Bank and preset")
  ImGui.SetNextItemWidth(ctx, 110)
  ch, v = UI.input_int("##lbank", a.bank, 1)
  if ch then a.bank = Util.clamp(v, 1, m.banks) end
  UI.tip(string.format("The bank number (1-%d).", m.banks))
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  a.letter = Util.clamp(a.letter, 1, #m.letters)
  ImGui.SetNextItemWidth(ctx, 70)
  local letters = R.letter_items and R.letter_items[d.model]
  if not letters then
    R.letter_items = R.letter_items or {}
    letters = ""
    for k = 1, #m.letters do letters = letters .. m.letters:sub(k, k) .. "\0" end
    R.letter_items[d.model] = letters
  end
  ch, v = ImGui.Combo(ctx, "##lletter", a.letter - 1, letters)
  if ch then a.letter = v + 1 end
  UI.tip("The preset letter in the bank.")
  local idx = Preset.index(d.model, a.bank, a.letter)
  _, cw = UI.row_start("Name")
  ImGui.SetNextItemWidth(ctx, cw - 80 - CFG.CTRL_GAP)
  local _
  _, a.name = ImGui.InputText(ctx, "##lname", a.name)
  local enter = ImGui.IsItemDeactivated(ctx) and (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter()) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter()))
  UI.tip("The name of the preset, for example the song name. Enter adds it.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local can = a.name:match("%S") ~= nil
  ImGui.BeginDisabled(ctx, not can)
  if (UI.button(Preset.name(d, a.folder, idx) and "Rename" or "Add", 80, nil, "primary") or enter) and can then
    Preset.set_name(d, a.folder, idx, a.name)
    a.name = ""
    a.letter = a.letter + 1 -- the next preset, for the next name
    if a.letter > #m.letters then a.letter = 1; a.bank = math.min(m.banks, a.bank + 1) end
  end
  ImGui.EndDisabled(ctx)
  UI.tip("Saves the name of " .. Preset.label(d.model, idx) .. ". Then the next preset is selected.")

  local keys = Preset.sorted_keys(S.lib[d.id])
  UI.heading(string.format("Preset list (%d)", #keys), "Click a name to change it. Edit... changes its folder, bank "
    .. "or preset (asks first). The red X removes the name (the presets in your songs stay).")
  if #keys == 0 then UI.note("No names yet. Add the first one above.") end
  local fh = ImGui.GetFrameHeight(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local rm
  for n, k in ipairs(keys) do
    local f, i = k:match("^(%d+):(%d+)$")
    f, i = tonumber(f), tonumber(i)
    ImGui.PushID(ctx, k)
    UI.row_text(Preset.label(d.model, i), COL.TEXT_MAIN)
    ImGui.SameLine(ctx, 50)
    ImGui.SetNextItemWidth(ctx, math.max(80, aw - 50 - 240 - fh - 3 * CFG.CTRL_GAP))
    local nm = S.lib[d.id][k]
    local changed, nv = ImGui.InputText(ctx, "##nm", nm)
    if changed and nv:match("%S") then S.lib[d.id][k] = Util.clean(nv); Util.mark_sdirty(); R.bank_dirty = true; R.pick_cache = nil end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    UI.row_text(UI.trunc(Preset.folder_name(d, f), 150 - 70), COL.TEXT_DIM)
    ImGui.SameLine(ctx, aw - fh - 70 - 80 - 2 * CFG.CTRL_GAP)
    if UI.button("Scenes...", 80, nil, "ghost") then
      local names = {}
      local cols = {}
      for v = 1, 8 do
        names[v] = (S.snames[d.id] and S.snames[d.id][k] and S.snames[d.id][k][v]) or ""
        cols[v] = Preset.scene_col(d, f, i, v - 1)
      end
      R.sedit = { d = d, folder = f, index = i, names = names, cols = cols, open = true }
    end
    UI.tip("The names and colours of the 8 scenes of this preset (for example Verse, Chorus).")
    ImGui.SameLine(ctx, aw - fh - 70 - CFG.CTRL_GAP)
    if UI.button("Edit...", 70, nil, "ghost") then
      local L = #m.letters
      R.pedit = { d = d, key = k, name = nm, folder = f, bank = i // L + 1, letter = i % L + 1, open = true }
    end
    UI.tip("Change the folder, bank or preset of this name.")
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
  ImGui.TextDisabled(ctx, "Empty: the unit's name of the scene.")
  UI.vgap(6)
  local fh = ImGui.GetFrameHeight(ctx)
  for v = 1, 8 do
    -- the colour: a swatch; a click opens the 8 colours of the unit
    local ci = se.cols[v] or v
    local x, y = ImGui.GetCursorScreenPos(ctx)
    if ImGui.InvisibleButton(ctx, "##col" .. v, fh, fh) then ImGui.OpenPopup(ctx, "##colpick" .. v) end
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRectFilled(dl, x + 3, y + 3, x + fh - 3, y + fh - 3, SC_COLS[ci], 4)
    if ImGui.IsItemHovered(ctx) then
      ImGui.DrawList_AddRect(dl, x + 2, y + 2, x + fh - 2, y + fh - 2, COL.WHITE, 4, 0, 1.5)
      ImGui.SetTooltip(ctx, SC_COL_NAMES[ci] .. ". Click to choose the colour of this scene.")
    end
    if ImGui.BeginPopup(ctx, "##colpick" .. v) then
      for k = 1, 8 do
        if k > 1 then ImGui.SameLine(ctx, 0, 4) end
        local px, py = ImGui.GetCursorScreenPos(ctx)
        if ImGui.InvisibleButton(ctx, "##c" .. k, 24, 24) then se.cols[v] = k; ImGui.CloseCurrentPopup(ctx) end
        local pdl = ImGui.GetWindowDrawList(ctx)
        ImGui.DrawList_AddCircleFilled(pdl, px + 12, py + 12, (k == ci) and 11 or 8, SC_COLS[k])
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, SC_COL_NAMES[k]) end
      end
      ImGui.EndPopup(ctx)
    end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, 220)
    local _
    _, se.names[v] = ImGui.InputText(ctx, MODELS[d.model].scenes[v] .. "##sn" .. v, se.names[v])
  end
  UI.vgap(8)
  if UI.button("Save", 90, nil, "primary") then
    Preset.set_scene_names(d, se.folder, se.index, se.names, se.cols)
    UI.toast("Scene names saved.")
    R.sedit = nil; ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Cancel", 90) then R.sedit = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- "Edit..." of the preset list: folder, bank and preset of a name; "Save" asks first (in the same window).
function UI.draw_preset_edit()
  local pe = R.pedit
  if not pe then return end
  if pe.open then ImGui.OpenPopup(ctx, "Edit preset##pedit"); pe.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if not ImGui.BeginPopupModal(ctx, "Edit preset##pedit", true, ImGui.WindowFlags_AlwaysAutoResize()) then R.pedit = nil; return end
  local d, m = pe.d, MODELS[pe.d.model]
  local f0, i0 = pe.key:match("^(%d+):(%d+)$")
  f0, i0 = tonumber(f0), tonumber(i0)
  local idx = Preset.index(d.model, pe.bank, pe.letter)
  local from = Preset.label(d.model, i0) .. " (" .. Preset.folder_name(d, f0) .. ")"
  local to = Preset.label(d.model, idx) .. " (" .. Preset.folder_name(d, pe.folder) .. ")"
  ImGui.Text(ctx, "'" .. pe.name .. "'  -  now " .. from)
  UI.vgap(6)
  if not pe.confirm then
    local ch, v
    ImGui.SetNextItemWidth(ctx, 200)
    ch, v = ImGui.Combo(ctx, "Folder", pe.folder, Preset.folder_items(d))
    if ch then pe.folder = v end
    ImGui.SetNextItemWidth(ctx, 200)
    ch, v = UI.input_int("Bank", pe.bank, 1)
    if ch then pe.bank = Util.clamp(v, 1, m.banks) end
    ImGui.SetNextItemWidth(ctx, 200)
    ch, v = ImGui.Combo(ctx, "Preset", pe.letter - 1, R.letter_items and R.letter_items[d.model] or "A\0")
    if ch then pe.letter = v + 1 end
    UI.vgap(8)
    local same = (f0 == pe.folder and i0 == idx)
    ImGui.BeginDisabled(ctx, same)
    if UI.button("Save", 90, nil, "primary") then pe.confirm = true end
    ImGui.EndDisabled(ctx)
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Cancel", 90) then R.pedit = nil; ImGui.CloseCurrentPopup(ctx) end
  else
    local other = Preset.name(d, pe.folder, idx)
    ImGui.PushTextWrapPos(ctx, 380)
    ImGui.Text(ctx, "Are you sure? The name '" .. pe.name .. "' moves from " .. from .. " to " .. to .. "."
      .. (other and ("\n" .. to .. " has the name '" .. other .. "': it is replaced.") or "")
      .. "\nIts scene names and colours move with it. The preset changes in your songs do not change.")
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    if UI.button("Yes, move", 110, nil, "danger") then
      Preset.move(d, f0, i0, pe.folder, idx)
      UI.toast("'" .. pe.name .. "' is now " .. to .. ".")
      R.pedit = nil; ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Back", 90) then pe.confirm = false end
  end
  ImGui.EndPopup(ctx)
end

-- Settings > Devices: the list (click a row to edit it below), Add device; then the selected device.
function UI.draw_device_list()
  UI.heading("Devices", "1 device for each Quad Cortex or Quad Cortex mini. Saved on this computer, for all projects.\n\n"
    .. "With USB, the MIDI output has the unit's name: a new device selects it and the model. "
    .. "With a MIDI cable, select the output of your MIDI interface and the model yourself.\n\n"
    .. "A track keeps the settings of its device: a device that you removed (and kept its track) comes back "
    .. "with Add device; Ctrl+Z of a removed track brings its device back too.")
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
  if UI.button("Add device", UI.btn_w("Add device", 120), nil, #S.devices == 0 and "primary" or nil) then
    Dev.new(); R.sel_dev = #S.devices
  end
  UI.tip((Dev.free_unit() and ("Adds a device for the connected '" .. Dev.free_unit() .. "', with its track.")
    or "Adds a device with its track. Every connected Quad Cortex (USB) has a device already: select the MIDI output yourself.")
    .. "\nA track called MIDI + the device name is used again when it is there.")
  local d = S.devices[R.sel_dev]
  if d then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Remove device...", UI.btn_w("Remove device...", 130), nil, "danger") then
      local i, tr = R.sel_dev, P.track_mode ~= "shared" and Dev.track(d)
      if tr then
        UI.ask("Remove the device '" .. d.name .. "'? You can also remove its track '" .. Dev.track_name(tr)
          .. "' with all its MIDI.", "Remove device and track", function() Dev.remove_with_track(i, true) end,
          "Remove device only", function() Dev.remove_with_track(i, false) end)
      else
        UI.ask("Remove the device '" .. d.name .. "'?", "Yes, remove", function() Dev.remove(i) end)
      end
    end
    UI.tip("Removes the selected device (" .. d.name .. ") from MIDI Pilot. Asks first, also whether its track goes too.")
  end
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
  ImGui.SetNextItemWidth(ctx, cw)
  if R.name_edit == nil or R.name_edit_id ~= d.id then R.name_edit, R.name_edit_id = d.name, d.id end
  ch, R.name_edit = ImGui.InputText(ctx, "##devname", R.name_edit)
  if ImGui.IsItemDeactivated(ctx) then -- the name is used when you leave the field (an empty name: the model)
    local nm = R.name_edit:match("^%s*(.-)%s*$")
    if nm == "" then nm = MODELS[d.model].name end
    Dev.rename(d, nm)
    if Dev.is_default_name(d) then Dev.number_defaults(d.model) end
    R.name_edit = d.name
  elseif not ImGui.IsItemActive(ctx) then R.name_edit = d.name end
  UI.tip("For example Guitar or Bass. The track is called MIDI + this name.\nEmpty: the model name (Quad Cortex 1, 2 ... when you have more).")

  _, cw = UI.row_start("Model")
  ImGui.SetNextItemWidth(ctx, cw)
  local mi = (d.model == "mini") and 1 or 0
  ch, mi = ImGui.Combo(ctx, "##model", mi, MODEL_ITEMS)
  if ch then Dev.set_model(d, MODEL_IDS[mi + 1]) end
  UI.tip("Quad Cortex: scenes and presets A-H (32 banks).\nQuad Cortex mini: scenes A-D on 2 pages, presets A-D (64 banks).")

  _, cw = UI.row_start("MIDI input")
  ImGui.SetNextItemWidth(ctx, cw)
  if ImGui.BeginCombo(ctx, "##inport", d.inport ~= "" and d.inport or "(none)") then
    if ImGui.Selectable(ctx, "(none)", d.inport == "") then d.inport = ""; Util.mark_sdirty() end
    for _, p in ipairs(R.inports or {}) do
      if ImGui.Selectable(ctx, p.name .. "##i" .. p.index, p.name == d.inport) then d.inport = p.name; Util.mark_sdirty() end
    end
    if #(R.inports or {}) == 0 then ImGui.TextDisabled(ctx, "No MIDI input is on. Turn it on in REAPER's Preferences > MIDI Devices.") end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The MIDI input that comes from this unit. A later version records what the unit sends\n"
    .. "(footswitches, expression pedal, preset loads). With USB it has the unit's name.")
  _, cw = UI.row_start("MIDI output")
  ImGui.SetNextItemWidth(ctx, cw)
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
  UI.tip("The MIDI output that goes to this unit. Only outputs that are on in REAPER's Preferences > MIDI Devices show.\n"
    .. "An output with the name Quad Cortex also selects the model.")


  _, cw = UI.row_start("MIDI channel")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 160))
  local old_chan = d.chan
  ch, d.chan = ImGui.Combo(ctx, "##chan", d.chan, CHAN_ITEMS)
  if ch then
    Util.mark_sdirty(); R.conflicts = nil; Dev.apply_out(d)
    local from, to = (old_chan == 0) and 0 or old_chan - 1, Midi.chan(d)
    if from ~= to and Midi.has_channel(d, from) then
      local cname = function(c) return c == 0 and "All channels" or ("channel " .. c) end
      UI.ask(d.name .. " now uses " .. cname(d.chan) .. ". Its presets and scenes in this project are on "
        .. cname(old_chan) .. ". Move them to " .. cname(d.chan) .. " too?", "Move the MIDI",
        function() UI.toast(string.format("%d MIDI event(s) moved.", Midi.move_channel(d, from, to))) end,
        "Keep it", function() end)
      R.ask.safe = true
    end
  end
  UI.tip("The channel of the unit (on the unit: Settings > Device > MIDI > MIDI Channel).\n"
    .. "All channels: every unit on this output reacts.")

  _, cw = UI.row_start("Latency (ms)")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 160))
  local lat
  ch, lat = UI.input_int("##lat", d.latency, 5)
  if ch then
    d.latency = Util.clamp(lat, 0, CFG.LATENCY_MAX); Util.mark_sdirty()
    for _, x in ipairs(S.devices) do if x == d or P.track_mode == "shared" then Dev.apply_latency(x) end end
  end
  UI.tip("The delay of the unit after a MIDI message (0-500 ms). REAPER sends the MIDI of the track this much\n"
    .. "earlier (the track's playback offset), so the unit changes on the beat. The MIDI stays on the beat in the project.")

  local cx = UI.row_start("Track")
  local tr = Dev.track(d)
  UI.row_text(tr and Dev.track_name(tr) or "No track in this project yet", tr and COL.TEXT_MAIN or COL.YELLOW)
  if tr then UI.tip("The track that MIDI Pilot writes on for this device (saved in the project).") end
  ImGui.SetCursorPosX(ctx, cx)
  if UI.button("Create track", UI.btn_w("Create track", 110), nil, not tr and "primary" or nil) then Dev.create_track(d) end
  UI.tip("Adds a track at the end of the project, with its MIDI output set to this device.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local has_sel = r.GetSelectedTrack(R.proj, 0) ~= nil
  ImGui.BeginDisabled(ctx, not has_sel)
  if UI.button("Use selected track", UI.btn_w("Use selected track", 130)) then Dev.use_selected_track(d) end
  ImGui.EndDisabled(ctx)
  UI.tip(has_sel and "The selected track becomes the track of this device. Its MIDI output is set to this device."
    or "Select a track in REAPER first.")

end

function UI.draw_settings_tab()
  if not R.ports_t or Util.now() - R.ports_t > CFG.PORTS_SEC then Dev.read_ports() end
  UI.draw_device_list()
  UI.draw_device_form()
  UI.heading("Tracks", "One track for each device (default): each device writes on its own track.\n"
    .. "One shared track: all devices write on 1 track, and their MIDI channels keep them apart. "
    .. "The track then sends all channels to the MIDI output of the first device. Track mode: saved in this project.\n\n"
    .. "Check new MIDI items: a MIDI item that you add to a device's track is checked once (its channel, a scene "
    .. "at each song start). Saved on this computer.")
  local _, cw = UI.row_start("Track mode")
  ImGui.SetNextItemWidth(ctx, cw)
  local ti = (P.track_mode == "shared") and 1 or 0
  local ch
  ch, ti = ImGui.Combo(ctx, "##trackmode", ti, TRACK_MODE_ITEMS)
  if ch then
    P.track_mode = (ti == 1) and "shared" or "own"; Util.mark_pdirty(); R.conflicts = nil; R.pcs = {}
    for _, d in ipairs(S.devices) do Dev.apply_out(d); Dev.apply_latency(d) end
  end
  UI.tip("One shared track: the devices must use different channels, and the same MIDI output.")
  local cich
  cich, S.check_items = UI.checkbox("Check new MIDI items", S.check_items,
    "On: a MIDI item that you add to a device's track (copy, drag or record) is checked once:\n"
    .. "its MIDI channel becomes the device's channel (more than 1 channel: MIDI Pilot asks),\n"
    .. "and each song that starts inside it gets a scene change at its start when it has none there\n"
    .. "(the scene that plays there, else I-A). Ctrl+Z removes the added scenes.")
  if cich then Util.mark_sdirty() end
  UI.heading("Playback", "Live chase: while the MIDI Pilot window is open, a play start or a jump into the middle of "
    .. "a song sends the state there to the units at once: the preset, then the scene and the value of each control. "
    .. "At a song start the MIDI of the song does it. With the window closed, playback from a song start is right "
    .. "when every song has its preset, start scene and control values (Songs > Fill songs).\n\nSaved on this computer.")
  local lch2
  lch2, S.live_chase = UI.checkbox("Live chase", S.live_chase,
    "On: a play start or a jump inside a song sends the preset, the scene and the control values there (window open).")
  if lch2 then Util.mark_sdirty() end

  UI.heading("Preset timing", "Where a song's preset change goes. The unit needs a moment to load a preset, "
    .. "so 'Before the song start' (default: 250 ms before) has it ready when the song starts. A song that starts at "
    .. "0:00 gets its change at 0:00.\n\nThe timing is used for new changes. Saved on this computer.")
  _, cw = UI.row_start("Preset change")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
  local wi = 0
  for k, w in ipairs(PC_WHEN) do if w == S.pc_when then wi = k - 1 end end
  ch, wi = ImGui.Combo(ctx, "##pcwhen", wi, PC_WHEN_ITEMS)
  if ch then S.pc_when = PC_WHEN[wi + 1]; Util.mark_sdirty() end
  UI.tip("Before: the preset is ready when the song starts. After: for a preset that must change later.")
  ImGui.BeginDisabled(ctx, S.pc_when == "exact")
  _, cw = UI.row_start("By")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
  local ui = (S.pc_unit == "notes") and 1 or 0
  ch, ui = ImGui.Combo(ctx, "##pcunit", ui, PC_UNIT_ITEMS)
  if ch then S.pc_unit = (ui == 1) and "notes" or "ms"; Util.mark_sdirty() end
  UI.tip("Milliseconds: a fixed time. Note value: on the beat grid, so it follows the tempo.")
  _, cw = UI.row_start(S.pc_unit == "notes" and "Note value" or "Milliseconds")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
  if S.pc_unit == "notes" then
    local ni
    ch, ni = ImGui.Combo(ctx, "##pcnote", S.pc_note - 1, PC_NOTE_ITEMS)
    if ch then S.pc_note = ni + 1; Util.mark_sdirty() end
    UI.tip("How far before or after the song start, in notes of the project tempo.")
  else
    local ms
    ch, ms = UI.input_int("##pcms", S.pc_ms, 50)
    if ch then S.pc_ms = Util.clamp(ms, 0, CFG.PC_MS_MAX); Util.mark_sdirty() end
    UI.tip("How many milliseconds before or after the song start (0-2000).")
  end
  ImGui.EndDisabled(ctx)

  UI.heading("Lists", "A song's scene list (Songs) and its list of values (Lanes) scroll when they have more rows "
    .. "than this, so the page stays short. In Lanes 'All songs', a click on a song name closes or opens its values.\n\n"
    .. "Saved on this computer.")
  _, cw = UI.row_start("Scene rows")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 160))
  local sr
  ch, sr = UI.input_int("##srows", S.scene_rows, 1)
  if ch then S.scene_rows = Util.clamp(sr, 3, 100); Util.mark_sdirty() end
  UI.tip("A song's scene list scrolls after this many rows (3-100).")
  _, cw = UI.row_start("Lane rows")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 160))
  local lr
  ch, lr = UI.input_int("##lrows", S.lane_rows, 1)
  if ch then S.lane_rows = Util.clamp(lr, 3, 100); Util.mark_sdirty() end
  UI.tip("A song's values in Lanes scroll after this many rows (3-100).")

  UI.heading("Nudge", "The amount of the nudge buttons (the 2 triangles): the left one moves a change earlier, the right one later. In the scene list "
    .. "(each scene change, and 'Song': all scene changes and knob values of the song) and in Lanes (each value). "
    .. "Milliseconds: a fixed time. Note value: on the beat grid, so it follows the tempo.\n\nSaved on this computer.")
  _, cw = UI.row_start("Nudge by")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
  local nui = (S.nudge_unit == "notes") and 1 or 0
  ch, nui = ImGui.Combo(ctx, "##nunit", nui, PC_UNIT_ITEMS)
  if ch then S.nudge_unit = (nui == 1) and "notes" or "ms"; Util.mark_sdirty() end
  UI.tip("Milliseconds: a fixed time. Note value: on the beat grid, so it follows the tempo.")
  _, cw = UI.row_start(S.nudge_unit == "notes" and "Note value" or "Milliseconds")
  ImGui.SetNextItemWidth(ctx, math.min(cw, 220))
  if S.nudge_unit == "notes" then
    local nni
    ch, nni = ImGui.Combo(ctx, "##nnote", S.nudge_note - 1, PC_NOTE_ITEMS)
    if ch then S.nudge_note = nni + 1; Util.mark_sdirty() end
    UI.tip("How far 1 click moves a change, in notes of the project tempo.")
  else
    local nms
    ch, nms = UI.input_int("##nms", S.nudge_ms, 5)
    if ch then S.nudge_ms = Util.clamp(nms, 1, CFG.NUDGE_MS_MAX); Util.mark_sdirty() end
    UI.tip("How far 1 click moves a change (1-1000 ms).")
  end

  UI.heading("General", "Preset names in REAPER: MIDI Pilot writes your preset names into a bank file. Load it "
    .. "in ReaControlMIDI on a device's track (Bank/Program Select > Load File); REAPER then shows '3B Song One' "
    .. "in place of numbers. Leave 'Enable' off in ReaControlMIDI, so it sends nothing itself. The file is made "
    .. "again after each change of your preset names.")
  UI.row_start("Preset names file")
  UI.row_text(UI.trunc(Preset.reabank_path(), math.max(60, ImGui.GetContentRegionAvail(ctx) - 10)), COL.TEXT_DIM)
  UI.tip(Preset.reabank_path())
  ImGui.SetCursorPosX(ctx, (UI.form("Preset names file")))
  if UI.button("Copy the path", UI.btn_w("Copy the path", 110)) then ImGui.SetClipboardText(ctx, Preset.reabank_path()) end
  UI.tip("Copies the file path, to paste it in REAPER's file window.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Make it now", UI.btn_w("Make it now", 100)) then Preset.write_reabank() end
  UI.tip("Writes the file again now.")
  local docked = R.docked == true
  if UI.checkbox("Dock in docker", docked, "On: MIDI Pilot is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  UI.vgap(8)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "MIDI Pilot " .. CFG.VERSION .. "  -  MIT license")
end

function UI.draw_help_tab()
  UI.heading("Help")
  ImGui.PushTextWrapPos(ctx, 0)
  ImGui.Text(ctx, HELP_TEXT)
  ImGui.PopTextWrapPos(ctx)
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
  local parts = {}
  local rg = Midi.song_at(tc)
  local tr = Dev.track(d)
  if rg and tr then
    local pc = Midi.preset_at(d, rg, tc)
    local sv
    for _, s in ipairs(Midi.scenes(d)) do if s.t <= tc + CFG.EDGE then sv = s.v else break end end
    local st = Midi.start_scene(d, rg) -- (before the start scene, at the song start: the song's own start scene)
    if st and tc < st.t then sv = st.v end
    parts[#parts + 1] = (playing and "Playing: " or "At the cursor: ") .. (rg.name ~= "" and rg.name or "(no name)")
      .. ", " .. (pc and Preset.text(d, pc.folder, pc.index) or "no preset")
      .. (sv and (", " .. Preset.scene_name(d, pc and pc.folder, pc and pc.index or 0, sv)) or "")
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
    if test_song then
      c.l2, c.col = "'" .. (test_song.name ~= "" and test_song.name or "A song") .. "' still has a Scene test (its red X in the scene list removes it).", COL.YELLOW
      c.ignore = test_song
    elseif nopre > 0 then
      c.l2, c.col = string.format("%d song(s) without their own preset (grey): Songs > Fill songs gives them the preset that plays.", nopre), COL.YELLOW
    elseif nostart > 0 then
      c.l2, c.col = string.format("%d song(s) without a start scene: Songs > Fill songs adds them.", nostart), COL.YELLOW
    else
      c.l2, c.col = "Ready: every song has its preset and start scene. REAPER plays them from the track; this window can stay closed.", COL.TEXT_DIM
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
  local sbw = ImGui.CalcTextSize(ctx, "Send state") + 16
  local d0 = S.devices[R.cur_dev or 1]
  if c.l1 ~= "" and dev == c.dev then
    local left = aw - 12 - (ImGui.CalcTextSize(ctx, dev)) - sbw - 8
    if left > 40 then
      ImGui.SameLine(ctx, 0, 0)
      ImGui.TextColored(ctx, COL.TEXT_MAIN, UI.trunc(c.l1, left))
      if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, c.l1:sub(8)) end
    end
  end
  if d0 and Dev.track(d0) then
    ImGui.SameLine(ctx, math.max(ImGui.GetCursorPosX(ctx), aw - sbw + 6))
    if ImGui.SmallButton(ctx, "Send state##sendstate") then
      local tc = Util.playing() and r.GetPlayPosition() or r.GetCursorPosition()
      if Midi.send_state(d0, tc) then UI.toast(d0.name .. ": the preset, scene and control values at " .. Util.fmt_beats(tc) .. " were sent.")
      else UI.toast(d0.name .. ": the MIDI output is not available.", true) end
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Send state now: sends the preset, the scene and the control values at the edit cursor\n"
        .. "(during playback: the play position) to " .. d0.name .. ". For a soundcheck, or after the unit restarts.")
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
    if ImGui.SmallButton(ctx, "Ignore##sttest") then
      P.test_ok[c.ignore.name] = true; Util.mark_pdirty(); R.status = nil
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "No Scene test hint for '" .. c.ignore.name .. "' (all its Scene tests). Saved in this project.")
    end
  end
  ImGui.Unindent(ctx, 6)
end

function UI.draw_main()
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
  Midi.live_chase()
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
load_settings()
Dev.read_ports()
if not r.file_exists(Preset.reabank_path()) then Preset.write_reabank() end
r.atexit(on_exit)
r.defer(loop)
