-- @description SFX Drop: put impacts, risers, drops and atmospheres exactly on the beat
-- @version 1.0
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   SFX Drop - prepare the sound effects of your live show backing tracks fast.
--   Pick a sound from your library (impacts, risers, drops, atmospheres) and insert it: SFX Drop finds the hit point
--   of the sound (the start of an impact, the peak of a riser) and puts it exactly on the beat. No nudging.
--   Insert at the edit cursor, at the nearest bar line or at the start of each region.
--   Find spots reads the song bar by bar and suggests where a riser, an impact, a drop or an atmosphere fits.
--   Favourites, risers that fit a length in bars, and a level per type (LUFS or peak).
--   Soundcheck: a new track after the last song with areas of your backing track from quiet to loud, then each
--   impact and bass drop repeated: a PA check and a quick medley at the full length you choose.
--   The sounds go on 1 track per type, in an "FX" folder. One Ctrl+Z undoes an insert.
--   Requires: the free ReaImGui extension (ReaPack). Optional: SWS (to preview a sound).
-- @changelog
--   First release: the library (scan, types, hit points), search, preview (SWS), insert on the beat.
--   Find spots, favourites, risers that fit a length in bars, a level per type (LUFS or peak), Soundcheck.

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
CFG.TITLE = "SFX Drop"         -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.0"            -- keep equal to @version in the header
CFG.EXT = "SFX Drop"           -- ExtState section (this computer)
CFG.DEFAULT_W, CFG.DEFAULT_H = 560, 560
CFG.WIN_EDGE = 6               -- floating window: width of the resize edges (inside the window), as in Chart Cue
CFG.WIN_GRIP = 22              -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 380, 300
CFG.FONT_SIZE = 14             -- the same sizes as Chart Cue
CFG.FONT_SIZE_BOLD = 15        -- section titles
CFG.TEXT_LIFT = 1              -- px the text is raised above the true centre in every control
CFG.HELP_ICON = 20             -- the round "?" icon
CFG.CTRL_GAP = 8               -- between 2 controls side by side
CFG.SP_ROW, CFG.SP_EDGE, CFG.SP_PANEL = 7, 8, 4 -- spacing (pixels; the same gaps as Chart Cue)
CFG.SP_TITLE_BEFORE, CFG.SP_TITLE_AFTER = 12, 6
CFG.ROW_H = 26
CFG.LABEL_W = 190              -- the label column of the Settings rows (as in MIDI Pilot)
CFG.TAB_H = 32                 -- the tab strip, as in Chart Cue
CFG.TAB_GAP = 4
CFG.TAB_GROUP_GAP = 12         -- between the text tabs and the Settings / Help tabs
CFG.TAB_LIFT = 6               -- the selected tab is this much taller
CFG.NOTICE_SEC = 4             -- a notice at the bottom of the window shows this long
CFG.TIP_DELAY = 0.5            -- seconds on an item before its tooltip shows (as in Chart Cue)
CFG.TIP_WRAP_EM = 32           -- tooltip lines wrap at this many font sizes
CFG.DATA_DIR = r.GetResourcePath() .. "/Data/SFX Drop" -- the library index
CFG.INDEX_FILE = CFG.DATA_DIR .. "/library.txt"
CFG.FOLDER = "FX"              -- the folder track of the type tracks
CFG.COPY_DIR = "SFX Drop"      -- Copy into the project: the folder of the copies, in the project folder
CFG.TAIL_FADE = 0.05           -- Check the show > Cut: the fade-out at the end of the song
CFG.CHECK_W, CFG.CHECK_H, CFG.CHECK_MIN_W = 680, 440, 460 -- the Check the show window
CFG.CHECK_BTN_W = 56           -- its Go / Copy / Cut buttons
CFG.OUT_PAIRS = 8              -- FX output: Out 1/2 up to Out 15/16 (also when the audio device has fewer)
CFG.SC_REGION = "Soundcheck"   -- the Soundcheck track and its region (after the last song)
CFG.SC_KEY = "soundcheck"      -- ProjExtState "SFX Drop" / "soundcheck": the Soundcheck settings of this project
CFG.SC_MARK = "P_EXT:SFXDropSC" -- the track and the items that Build made (Build deletes only these)
CFG.SC_SR = 500                -- Find areas reads the source track at this sample rate (the level of each bar)
CFG.SC_MAX_FRAMES = 4000       -- at most this many frames per bar
CFG.SC_FADE = 0.01             -- a cut edge of a copied item gets a 10 ms fade
CFG.SC_GAP = 1.0               -- 1 s between the steps and the impacts zone, and between 2 impacts
CFG.SC_ZONE_MAX = 0.6          -- the impacts zone takes at most 60 % of the full length
CFG.SC_MIN_AREA = 4            -- an area is at least 4 s long
CFG.SC_SRC_HITS = 2            -- the strongest hits of the source track in the impacts zone
CFG.SC_HIT_JUMP = 10           -- a hit: a peak 10 dB or more above the level of the bar before
CFG.SC_HIT_PRE = 0.05          -- a hit of the source track: 50 ms before its peak ...
CFG.SC_HIT_LEN = 1.5           -- ... and 1.5 s after it
CFG.MB = 1048576
CFG.EXTS = { wav = true, aif = true, aiff = true, flac = true, mp3 = true, ogg = true, wv = true }
CFG.SCAN_BUDGET = 0.03         -- the library scan: at most 30 ms per frame (the window stays responsive)
CFG.PEAK_RATE = 1000           -- the hit point analysis: 1000 peaks per second (1 ms)
CFG.PEAK_MAX = 60000           -- at most this many peaks per file (a long atmosphere is read at a lower rate)
CFG.SILENT = 0.001             -- a file with no peak above -60 dBFS is silent
CFG.START_REL = 0.05           -- the start of the sound: the first peak above -26 dB under the file's peak
CFG.TAIL_REL = 0.001           -- the end of the tail: the last peak above -60 dB under the file's peak
CFG.PEAK_WIN = 0.02            -- the loudest point of a riser: the loudest 20 ms
CFG.PRE_ROLL = 0.003           -- Trim silence keeps 3 ms before the start of the sound
CFG.TAIL_KEEP = 0.05           -- Trim silence keeps 50 ms after the end of the tail
CFG.COL_HIT_W = 70             -- the Hit column
CFG.COL_LEN_W = 56             -- the Length column
CFG.COL_TYPE_W = 70            -- the Type column
CFG.PLAY_W = 26                -- the preview button
CFG.STAR_W = 22                -- the favourite star
CFG.COL_BARS_W = 46            -- the Bars column
CFG.RISER_FIT = 0.1            -- Riser length: a riser fits when its length is within 10 % of the bars
CFG.GAIN_MAX = 24              -- Levels: the item gain stays within +-24 dB
CFG.SPOT_SR = 2000             -- Find spots reads the tracks at this sample rate
CFG.SPOT_MAX_FRAMES = 16000    -- at most this many frames per bar and track (a long bar is read at a lower rate)
CFG.SPOT_BUDGET = 0.03         -- Find spots: at most 30 ms of reading per frame
CFG.SPOT_SILENT = -50          -- a bar below -50 dB is silence (not in the song's average)
CFG.SPOT_QUIET = 12            -- a quiet part: 12 dB or more under the song's average ...
CFG.SPOT_QUIET_BARS = 4        -- ... for 4 bars or more
CFG.SPOT_W = 2                 -- a level jump: the 2 bars after a bar line against the 2 bars before it
CFG.SPOT_SENS_MIN, CFG.SPOT_SENS_MAX = 3, 15
local RISER_BARS = { 0, 1, 2, 4, 8 } -- Riser length (0: Off)

-- The types: the folder and file name words that give a sound its type (the closest folder first, then the file
-- name), the default hit point ("start": the start of the sound, "peak": the loudest point) and the track color.
-- A word of 3 letters or less matches only a whole word ("sub", "hit", "pad"); a longer one also the start of a
-- word ("riser" in "Risers").
-- mode, level: the default of Settings > Insert > Levels: "lufs" (the average loudness of the sound) or "peak"
-- (its loudest sample), and the target (dB).
local TYPES = {
  { name = "Impacts", hit = "start", color = 0xE0654F, mode = "peak", level = -6,
    words = { "impact", "hit", "boom", "slam", "crash", "braam", "stab", "thud", "punch", "smash" } },
  { name = "Risers", hit = "peak", color = 0xE0B34F, mode = "lufs", level = -18,
    words = { "riser", "rise", "uplift", "upsweep", "build", "swell", "rev", "reverse", "tension" } },
  { name = "Drops", hit = "start", color = 0x8F6FE0, mode = "peak", level = -6,
    words = { "drop", "downlift", "downsweep", "down", "sub", "808", "fall" } },
  { name = "Atmos", hit = "start", color = 0x4FA8E0, mode = "lufs", level = -24,
    words = { "atmo", "atmos", "atmosphere", "ambien", "ambience", "pad", "drone", "texture", "soundscape", "bed" } },
  { name = "Other", hit = "start", color = 0x8C93A3, mode = "lufs", level = -18, words = {} },
}
local TYPE_IDX = {}
for i, t in ipairs(TYPES) do TYPE_IDX[t.name] = i end
-- the checks in this order: a "riser" folder wins over "hit" in a file name of that folder, "sub drop" is a Drop
local TYPE_ORDER = { 2, 3, 1, 4 }

local COL = {
  RED = 0xF26D6DFF, YELLOW = 0xF2C75CFF, GREEN = 0x6FCF8AFF,
  ACCENT = 0x3B82F6FF, ACCENT_HOVER = 0x5B9BFFFF, ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633, HEADING = 0x8DB8FFFF,
  WIN_BG = 0x131518FF, PANEL_BG = 0x1A1C21FF, TAB_BG = 0x0F1114FF, TAB_HOVER = 0x343944FF,
  FIELD = 0x2B2F38FF, FIELD_HOVER = 0x333844FF, FIELD_ACTIVE = 0x2C3A55FF,
  BTN = 0x30343EFF, BTN_HOVER = 0x3B404CFF, BTN_ACTIVE = 0x464C5AFF,
  LINE = 0x31353FFF, ROW_HOVER = 0xFFFFFF12, TOGGLE_OFF = 0x4A5060FF,
  TEXT_MAIN = 0xE6E8EEFF, TEXT_DIM = 0x8C93A3FF, TEXT_BRIGHT = 0xEEEEEEFF, WHITE = 0xFFFFFFFF,
  TRANSPARENT = 0x00000000,
  HEADER_HOVER = 0x3B82F655, HEADER_ACTIVE = 0x3B82F677,
  ORANGE = 0xF2994AFF,
  TITLE_BG = 0x0F1114FF, TITLE_BG_ACTIVE = 0x1A1C21FF,
}

-- The themes (Settings > Appearance > Light theme): the same palettes as Chart Cue.
local THEMES = { dark = {} }
for k, v in pairs(COL) do THEMES.dark[k] = v end
THEMES.light = {
  RED = 0xD43F3FFF, YELLOW = 0xB7860BFF, GREEN = 0x2E9E5BFF,
  ACCENT = 0x2F6FE0FF, ACCENT_HOVER = 0x3B82F6FF, ACCENT_ACTIVE = 0x2559C7FF, ACTIVE_BG = 0x3B82F617,
  HEADING = 0x2459C2FF,
  WIN_BG = 0xDDE1E7FF, PANEL_BG = 0xF4F5F7FF, TAB_BG = 0xD0D5DDFF, TAB_HOVER = 0xC4CAD3FF,
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

local Util, Lib, Drop, Prev, Spots, Sc, Chk, UI = {}, {}, {}, {}, {}, {}, {}, {}

-- R: runtime state (not saved). S: settings of this computer. P: the project data (the Soundcheck parts).
local R = {
  frames = 0, sdirty = false,
  lib = {},          -- the library: { { path, rel, name, lname, type, len, start, peak, tail, own, fav, level, top } }
  view = nil,        -- the sounds that the search and the Type filter show (indexes into R.lib; nil: build again)
  scan = nil,        -- the running scan: { dirs, files, i, phase, old, full }
  sel = nil,         -- the selected sound (its path)
  last = nil,        -- the last insert: { item, take, path, target } (for "Learn from the moved item")
  prev = nil,        -- the playing preview: { h, src, path, t_end }
  search = "",       -- the search text
  filter = 0,        -- the Type filter: 0 all, -1 favourites, else the index in TYPES
  by_type = nil,     -- the sounds of each type, favourites first (Lib.by_type; nil: build again)
  spot_scan = nil,   -- the running Find spots: { tracks, ti, bi, acc, bars, regions }
  spot_bars = nil,   -- the last Find spots: the bars { t, num, db } and the regions { t, name }
  spots = nil,       -- the suggestions: { { t, num, kind, delta, name, on, parts = { { type, path } } } }
}
local S = {
  light = false,     -- Light theme (Dark is the default)
  dock = 0,          -- the REAPER docker of the window (0 = floating)
  tab = 1,           -- 1 Sounds, 2 Spots, 3 Soundcheck, 4 Settings, 5 Help
  settings_open = 2, -- the open Settings section (1 Appearance, 2 Library, 3 Insert, 4 Window; 0 none)
  library = "",      -- the library folder (its subfolders too)
  place = "cursor",  -- Place at: "cursor" (the edit cursor), "bar" (the nearest bar line), "regions" (region starts)
  trim = true,       -- Trim silence: the item starts 3 ms before the sound and ends after its tail
  fades = true,      -- short fades at both ends of each item (no clicks)
  fade_ms = 5,       -- the fade length
  color = true,      -- color the FX folder and the type tracks
  select_item = true, -- select the new item(s) after an insert
  riser_bars = 0,    -- Riser length: the risers that fit this many bars come first (0: Off)
  level_on = false,  -- Levels: each new item gets the item gain to reach the level of its type
  levels = {},       -- the target of each type (dB): type name -> dB (the defaults from TYPES)
  lvl_mode = {},     -- the level of each type by "lufs" or "peak": type name -> mode (the defaults from TYPES)
  spot_sens = 6,     -- Find spots: the level jump (dB) that makes a spot
  sort = "name",     -- the sort of the Sounds list: "name", "type", "len", "bars", "hit" (a click on a column title)
  sort_desc = false, -- the sort goes from high to low
  copy = false,      -- Copy into the project: each inserted sound is copied into "<project folder>/SFX Drop"
  copy_asked = false, -- the first-start question about Copy into the project was answered
  copy_warn = 500,   -- ask before a copy when the project's SFX Drop folder is larger than this (MB)
  spot_off = "",     -- Spots > Add: the types that are off, "Drops,Atmos" ("": all on)
  spot_words = "",   -- Spots > Sounds with: the suggested sounds have one of these words ("boom, explosion")
  fx_out = 0,        -- FX output: 0 = the master, k = the hardware outputs 2k-1 / 2k (FX folder)
  vary = false,      -- Vary: an insert at several places uses a different sound of the same folder at each place
}
-- P: the data of the current project (ProjExtState "SFX Drop" / "soundcheck"; only what differs from the defaults).
local P = {
  src = "",          -- Soundcheck: the GUID of the source track ("": none)
  len = 120,         -- the full length (seconds)
  steps = 5,         -- the areas, from quiet to loud
  imp = true,        -- the impacts zone after the steps
  rep = 4,           -- each impact repeated this many times
  saved = "",        -- the text at the last save (a change writes it)
}

---------------------------------------------------------------------------
-- REAIMGUI (pinned to 0.9.3 with the official compatibility shim)
---------------------------------------------------------------------------
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("SFX Drop needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end
  else
    r.ShowMessageBox("SFX Drop needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run SFX Drop again.", CFG.TITLE, 0)
  end
end
local TESTING = rawget(_G, "SFXDropTest") ~= nil
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
function Util.mark_sdirty() R.sdirty = true end
function Util.norm(p) return ((p or ""):gsub("\\", "/"):gsub("/+$", "")) end
function Util.read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("a"); f:close()
  return d
end
function Util.write_all(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data); f:close()
  return true
end
function Util.file_size(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:seek("end"); f:close()
  return s
end
-- The files of a folder (not its subfolders): { { path, size } }.
function Util.dir_files(dir)
  r.EnumerateFiles(dir, -1) -- (REAPER caches the list: read it again)
  local t, i = {}, 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    local pth = dir .. "/" .. fn
    t[#t + 1] = { path = pth, size = Util.file_size(pth) or 0 }
    i = i + 1
  end
  return t
end

-- A folder picker: the js_ReaScriptAPI extension's, else on Windows the Windows folder window (REAPER waits until
-- it closes), as in MIDI Pilot. Returns the folder, or nil.
function Util.browse_folder(title, start)
  if r.JS_Dialog_BrowseForFolder then
    local rv, folder = r.JS_Dialog_BrowseForFolder(title, start or "")
    if rv == 1 and folder and folder ~= "" then return folder end
    return nil
  end
  if not r.GetOS():match("^Win") then
    local ok, f = r.GetUserFileNameForRead(start or "", "Pick any file in the folder", "")
    return ok and f:match("^(.*)[/\\]") or nil
  end
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

-- Seconds as a short text: "0.02 s", "3.1 s", "1:05".
function Util.secs(t)
  if not t then return "-" end
  if t >= 60 then return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60)) end
  if t < 1 then return string.format("%.2f s", t) end
  return string.format("%.1f s", t)
end

---------------------------------------------------------------------------
-- LIBRARY (the sound files, their type and hit points; the index file on this computer)
---------------------------------------------------------------------------
-- The type of a sound from its path inside the library ("Risers/Long/Up 01.wav"): the closest folder first, then
-- the file name; "Other" when no word matches.
local function words_of(s)
  local t = {}
  for w in s:lower():gmatch("[%a%d]+") do t[#t + 1] = w end
  return t
end
local function word_match(token, key)
  if token == key or token == key .. "s" then return true end
  return #key >= 4 and token:sub(1, #key) == key
end
function Lib.type_of(rel)
  local parts = {}
  for p in Util.norm(rel):gmatch("[^/]+") do parts[#parts + 1] = p end
  if #parts == 0 then return "Other" end
  parts[#parts] = parts[#parts]:gsub("%.[^%.]*$", "")
  -- the file name first in the list is checked last: closest folder, then the folders above, then the file name
  local order = {}
  for i = #parts - 1, 1, -1 do order[#order + 1] = parts[i] end
  order[#order + 1] = parts[#parts]
  for _, part in ipairs(order) do
    local toks = words_of(part)
    for _, ti in ipairs(TYPE_ORDER) do
      for _, key in ipairs(TYPES[ti].words) do
        for _, tk in ipairs(toks) do
          if word_match(tk, key) then return TYPES[ti].name end
        end
      end
    end
  end
  return "Other"
end

-- The hit points from a peak envelope (env[i] = the peak of 1 / rate s, 0..1): the start of the sound, the loudest
-- point (the loudest CFG.PEAK_WIN; the last one when equal) and the end of the tail, in seconds. No REAPER calls.
function Lib.measure(env, rate, len)
  local n, top = #env, 0
  for i = 1, n do if env[i] > top then top = env[i] end end
  if top < CFG.SILENT then return 0, 0, len, true, -150, -150 end
  local start, tail = 0, len
  local thr = top * CFG.START_REL
  for i = 1, n do if env[i] >= thr then start = (i - 1) / rate; break end end
  local tthr = top * CFG.TAIL_REL
  for i = n, 1, -1 do if env[i] >= tthr then tail = math.min(len, i / rate); break end end
  local w = math.max(1, math.floor(rate * CFG.PEAK_WIN + 0.5))
  local sum, best, best_i = 0, -1, 1
  for i = 1, n do
    sum = sum + env[i]
    if i > w then sum = sum - env[i - w] end
    if i >= math.min(w, n) and sum >= best then best, best_i = sum, i end
  end
  local peak = math.max(0, (best_i - w / 2) / rate)
  -- the average level (dB) from the start to the end of the tail (a peak is 3 dB above the RMS of a sine)
  local pw, cnt = 0, 0
  for i = math.floor(start * rate) + 1, math.min(n, math.floor(tail * rate) + 1) do pw = pw + env[i] * env[i]; cnt = cnt + 1 end
  local level = (cnt > 0 and pw > 0) and (10 * math.log(pw / cnt, 10) - 3) or -150
  return start, math.max(start, math.min(peak, len)), tail, false, level, 20 * math.log(top, 10)
end

-- Reads a file's peaks (REAPER builds them when needed) and measures it. Returns len, start, peak, tail, level, top
-- (the peak level, dB), or nil.
function Lib.analyse(path)
  local src = r.PCM_Source_CreateFromFile(path)
  if not src then return nil end
  local len = r.GetMediaSourceLength(src)
  if not len or len <= 0 then r.PCM_Source_Destroy(src); return nil end
  if r.PCM_Source_BuildPeaks(src, 0) ~= 0 then
    local guard = 0
    while r.PCM_Source_BuildPeaks(src, 1) ~= 0 and guard < 1000000 do guard = guard + 1 end
    r.PCM_Source_BuildPeaks(src, 2)
  end
  local nch = Util.clamp(r.GetMediaSourceNumChannels(src), 1, 2)
  local rate = CFG.PEAK_RATE
  if len * rate > CFG.PEAK_MAX then rate = CFG.PEAK_MAX / len end
  local n = math.max(1, math.floor(len * rate) + 1)
  local buf = r.new_array(n * nch * 3)
  local ret = r.PCM_Source_GetPeaks(src, rate, 0, nch, n, 0, buf)
  r.PCM_Source_Destroy(src)
  local got = math.floor(ret or 0) & 0xFFFFF
  local env = {}
  if got > 0 then
    local t = buf.table()
    local mn = n * nch -- the minima follow the maxima
    for i = 1, got do
      local v = 0
      for c = 1, nch do
        local k = (i - 1) * nch + c
        local a, b = math.abs(t[k] or 0), math.abs(t[mn + k] or 0)
        if a > v then v = a end
        if b > v then v = b end
      end
      env[i] = v
    end
  end
  if #env == 0 then return len, 0, 0, len, -150, -150 end
  local start, peak, tail, _, level, top = Lib.measure(env, rate, len)
  return len, start, peak, tail, level, top
end

-- The hit point of a sound in the file (seconds): its own (set by you), else the type's default.
function Lib.hit(e)
  if e.own then return e.own end
  local t = TYPES[TYPE_IDX[e.type] or #TYPES]
  return t.hit == "peak" and e.peak or e.start
end

-- The index file: 1 line per sound: type, len, start, peak, tail, own (or ""), fav (0 / 1), level (dB), top (the
-- peak level, dB) and the full path, with tabs.
function Lib.save_index()
  r.RecursiveCreateDirectory(CFG.DATA_DIR, 0)
  local out = { "SFX Drop library\t" .. Util.norm(S.library) }
  for _, e in ipairs(R.lib) do
    out[#out + 1] = string.format("%s\t%.4f\t%.4f\t%.4f\t%.4f\t%s\t%d\t%.2f\t%.2f\t%s", e.type, e.len, e.start, e.peak,
      e.tail, e.own and string.format("%.4f", e.own) or "", e.fav and 1 or 0, e.level or -150, e.top or -150, e.path)
  end
  local f = io.open(CFG.INDEX_FILE, "wb")
  if not f then return false end
  f:write(table.concat(out, "\n"), "\n"); f:close()
  return true
end

function Lib.entry(path, typ, len, start, peak, tail, own, fav, level, top)
  local root = Util.norm(S.library)
  local rel = path:sub(1, #root + 1) == root .. "/" and path:sub(#root + 2) or path
  local name = rel:match("([^/]+)$"):gsub("%.[^%.]*$", "")
  return { path = path, rel = rel, name = name, lname = rel:lower(), type = typ, len = len, start = start,
    peak = peak, tail = tail, own = own, fav = fav or nil, level = level or -150, top = top or -150 }
end

function Lib.load_index()
  R.lib = {}
  Lib.changed()
  local f = io.open(CFG.INDEX_FILE, "rb")
  if not f then return end
  local head = f:read("l") or ""
  if head:match("^SFX Drop library\t(.*)$") ~= Util.norm(S.library) then f:close(); return end -- another folder
  for line in f:lines() do
    local typ, len, st, pk, tl, own, fav, lv, top, path =
      line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t([01])\t([^\t]+)\t([^\t]+)\t(.+)$")
    if typ and TYPE_IDX[typ] then
      R.lib[#R.lib + 1] = Lib.entry(path, typ, tonumber(len) or 0, tonumber(st) or 0, tonumber(pk) or 0,
        tonumber(tl) or 0, tonumber(own), fav == "1", tonumber(lv), tonumber(top))
    end
  end
  f:close()
end

-- The scan: list the files folder by folder, then read each new file (in steps: CFG.SCAN_BUDGET per frame).
-- full: read every file again (else a file that is in the index keeps its values).
function Lib.scan_begin(full)
  local root = Util.norm(S.library)
  if root == "" then return end
  local old = {}
  for _, e in ipairs(R.lib) do old[e.path] = e end
  R.scan = { dirs = { root }, files = {}, i = 0, phase = "list", old = old, full = full }
end
function Lib.scan_step(budget)
  local sc = R.scan
  if not sc then return end
  local t_end = Util.now() + budget
  while Util.now() < t_end do
    if sc.phase == "list" then
      local d = table.remove(sc.dirs)
      if not d then
        table.sort(sc.files, function(a, b) return a:lower() < b:lower() end)
        sc.phase, sc.lib = "read", {}
      else
        r.EnumerateFiles(d, -1); r.EnumerateSubdirectories(d, -1) -- (REAPER caches the lists: read them again)
        local i = 0
        while true do
          local fn = r.EnumerateFiles(d, i)
          if not fn then break end
          local ext = (fn:match("%.([^%.]+)$") or ""):lower()
          if CFG.EXTS[ext] then sc.files[#sc.files + 1] = d .. "/" .. fn end
          i = i + 1
        end
        i = 0
        while true do
          local sd = r.EnumerateSubdirectories(d, i)
          if not sd then break end
          sc.dirs[#sc.dirs + 1] = d .. "/" .. sd
          i = i + 1
        end
      end
    else
      sc.i = sc.i + 1
      local path = sc.files[sc.i]
      if not path then Lib.scan_done(); return end
      local o = sc.old[path]
      if o and not sc.full then
        sc.lib[#sc.lib + 1] = o
      else
        local len, st, pk, tl, lv, top = Lib.analyse(path)
        if len then
          local e = Lib.entry(path, "Other", len, st, pk, tl, o and o.own, o and o.fav, lv, top)
          e.type = Lib.type_of(e.rel)
          sc.lib[#sc.lib + 1] = e
        end
      end
    end
  end
end
function Lib.scan_done()
  local sc = R.scan
  if not sc then return end
  R.scan = nil
  local added, gone = 0, 0
  local now = {}
  for _, e in ipairs(sc.lib) do now[e.path] = true; if not sc.old[e.path] then added = added + 1 end end
  for p in pairs(sc.old) do if not now[p] then gone = gone + 1 end end
  R.lib = sc.lib
  Lib.changed()
  Lib.save_index()
  local t = { #R.lib .. (#R.lib == 1 and " sound" or " sounds") }
  if added > 0 and next(sc.old) then t[#t + 1] = added .. " new" end
  if gone > 0 then t[#t + 1] = gone .. " removed" end
  UI.notice("Library scanned: " .. table.concat(t, ", ") .. ".")
end
-- Stop: keeps the sounds read so far and the known sounds that the scan did not reach (Rescan reads the rest).
function Lib.scan_stop()
  local sc = R.scan
  if not sc then return end
  R.scan = nil
  if sc.phase ~= "read" then UI.notice("Scan stopped: nothing changed."); return end
  for k = sc.i + 1, #sc.files do
    local o = sc.old[sc.files[k]]
    if o then sc.lib[#sc.lib + 1] = o end
  end
  table.sort(sc.lib, function(a, b) return a.path:lower() < b.path:lower() end)
  R.lib = sc.lib
  Lib.changed()
  Lib.save_index()
  UI.notice(string.format("Scan stopped at %d / %d. Rescan reads the rest.", math.min(sc.i, #sc.files), #sc.files))
end
-- The whole scan at once (the tests).
function Lib.scan(full)
  Lib.scan_begin(full)
  while R.scan do Lib.scan_step(1) end
end

-- The library changed (a scan, a favourite): build the cached lists again.
function Lib.changed() R.view, R.by_type, R.by_path = nil, nil, nil end
function Lib.set_fav(e, on)
  e.fav = on or nil
  Lib.changed()
  Lib.save_index()
end
-- The sounds of a type, favourites first (cached; for the sound dropdowns of the Spots tab).
function Lib.by_type(typ)
  R.by_type = R.by_type or {}
  local l = R.by_type[typ]
  if l then return l end
  l = {}
  for _, e in ipairs(R.lib) do if e.type == typ and e.fav then l[#l + 1] = e end end
  for _, e in ipairs(R.lib) do if e.type == typ and not e.fav then l[#l + 1] = e end end
  R.by_type[typ] = l
  return l
end

-- The length of a bar (seconds) at the edit cursor (its tempo and time signature).
function Lib.bar_sec()
  local num, den, bpm = r.TimeMap_GetTimeSigAtTime(0, r.GetCursorPosition())
  if not bpm or bpm <= 0 or not den or den <= 0 then return 2 end
  return num * 4 / den * 60 / bpm
end
-- Riser length: a riser fits when its length in bars (the Bars column) is within 10 % of bars.
function Lib.riser_fit(e, bars, bar_sec)
  if e.type ~= "Risers" or (bars or 0) <= 0 then return false end
  return math.abs(e.len / bar_sec - bars) <= CFG.RISER_FIT * bars
end

-- The sounds that the search and the Type filter show (cached until one of them, the library, Riser length or the
-- tempo changes). With Riser length, the risers that fit come first.
function Lib.view()
  local bs = Lib.bar_sec()
  if R.view and R.view_bars == S.riser_bars and (S.riser_bars == 0 or R.view_bs == bs)
      and R.view_sort == S.sort and R.view_desc == S.sort_desc then return R.view end
  R.view_bars, R.view_bs, R.view_sort, R.view_desc = S.riser_bars, bs, S.sort, S.sort_desc
  local v = {}
  local q = {}
  for w in R.search:lower():gmatch("%S+") do q[#q + 1] = w end
  local tname = R.filter > 0 and TYPES[R.filter].name
  local favs = R.filter == -1
  for i, e in ipairs(R.lib) do
    if (not tname or e.type == tname) and (not favs or e.fav) then
      local ok = true
      for _, w in ipairs(q) do if not e.lname:find(w, 1, true) then ok = false; break end end
      if ok then v[#v + 1] = i end
    end
  end
  Lib.sort(v)
  if S.riser_bars > 0 then -- (the fitting risers first, the sort stays in each part)
    local fit, rest = {}, {}
    for _, i in ipairs(v) do
      local t = Lib.riser_fit(R.lib[i], S.riser_bars, bs) and fit or rest
      t[#t + 1] = i
    end
    for _, i in ipairs(rest) do fit[#fit + 1] = i end
    v = fit
  end
  R.view = v
  return v
end
-- Sorts a list of library indexes by S.sort (Bars sorts as Length); equal values keep the library order.
local SORT_VAL = {
  name = function(e) return e.name:lower() end, -- (the sound's name, not its folder)
  type = function(e) return TYPE_IDX[e.type] or 99 end,
  len = function(e) return e.len end,
  bars = function(e) return e.len end,
  hit = function(e) return Lib.hit(e) end,
}
function Lib.sort(v)
  local f = SORT_VAL[S.sort] or SORT_VAL.name
  local desc = S.sort_desc
  local key = {}
  for _, i in ipairs(v) do key[i] = f(R.lib[i]) end
  table.sort(v, function(a, b)
    local ka, kb = key[a], key[b]
    if ka == kb then return a < b end
    if desc then return ka > kb end
    return ka < kb
  end)
end

-- Vary: n sounds for n places: e first, then the other sounds of the same type in its folder in turn (never the same
-- one twice in a row; a folder with 1 sound: e every time).
function Lib.variants(e, n)
  local dir = e.path:match("^(.*)/")
  local sib, start = {}, 1
  for _, x in ipairs(R.lib) do
    if x.type == e.type and x.path:match("^(.*)/") == dir then
      sib[#sib + 1] = x
      if x == e then start = #sib end
    end
  end
  if #sib == 0 then sib, start = { e }, 1 end
  local out = {}
  for k = 0, n - 1 do out[#out + 1] = sib[(start - 1 + k) % #sib + 1] end
  return out
end

-- A sound by its path (a lookup table, built again after Lib.changed).
function Lib.find(path)
  if not R.by_path then
    R.by_path = {}
    for _, e in ipairs(R.lib) do R.by_path[e.path] = e end
  end
  return R.by_path[path]
end

---------------------------------------------------------------------------
-- DROP (insert a sound on the beat)
---------------------------------------------------------------------------
-- The target times of Place at. Returns a list of seconds, or nil and why.
function Drop.targets()
  local cur = r.GetCursorPosition()
  if S.place == "bar" then
    local _, meas = r.TimeMap2_timeToBeats(0, cur)
    local bar, nxt = r.TimeMap2_beatsToTime(0, 0, meas), r.TimeMap2_beatsToTime(0, 0, meas + 1)
    return { (nxt - cur < cur - bar) and nxt or bar } -- the closer bar line (halfway: the earlier one)
  elseif S.place == "regions" then
    local t0, t1 = r.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local has_ts = t1 > t0
    local list, i = {}, 0
    while true do
      local rv, isrgn, pos = r.EnumProjectMarkers3(0, i)
      if rv == 0 then break end
      if isrgn and (not has_ts or (pos >= t0 - 0.0005 and pos < t1)) then list[#list + 1] = pos end
      i = i + 1
    end
    table.sort(list)
    if #list == 0 then
      return nil, has_ts and "No region starts in the time selection." or "The project has no regions."
    end
    return list
  end
  return { cur }
end

-- The item of a sound for a target time (pure: no REAPER calls): the item position and length, the take's start
-- offset in the file, and true when the start of the sound was cut. The hit point lands on the target.
function Drop.layout(e, target, trim)
  local hit = Lib.hit(e)
  local offs, stop = 0, e.len
  if trim then
    offs = math.max(0, math.min(e.start, hit) - CFG.PRE_ROLL)
    stop = math.min(e.len, math.max(e.tail, hit) + CFG.TAIL_KEEP)
  end
  local pos, cut = target - (hit - offs), false
  if pos < 0 then offs, pos, cut = offs - pos, 0, true end -- (before the project start: the start is cut)
  return pos, math.max(0.001, stop - offs), offs, cut
end

-- Levels: the item gain (a factor) that takes the sound to the target of its type, by its LUFS (the average
-- loudness) or its peak; 1 when Levels is off.
function Drop.gain(e)
  if not S.level_on then return 1 end
  local t = TYPES[TYPE_IDX[e.type] or #TYPES]
  local cur = (S.lvl_mode[e.type] or t.mode) == "peak" and e.top or e.level
  if not cur or cur <= -100 then return 1 end
  local target = S.levels[e.type] or t.level
  return 10 ^ (Util.clamp(target - cur, -CFG.GAIN_MAX, CFG.GAIN_MAX) / 20)
end

-- The folder track "FX" and its type track (made when missing). Returns the type track.
local function native(c) return r.ColorToNative((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF) | 0x1000000 end
local function track_name(tr) return (select(2, r.GetTrackName(tr)) or "") end
function Drop.find_folder()
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    if r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 and track_name(tr):lower() == CFG.FOLDER:lower() then
      return tr, i
    end
  end
end
-- The FX folder and its tracks (a set of tracks; empty when there is no FX folder).
function Drop.fx_tracks()
  local set = {}
  local ft, fi = Drop.find_folder()
  if not ft then return set end
  set[ft] = true
  local depth = 1
  for i = fi + 1, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    set[tr] = true
    depth = depth + r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
    if depth <= 0 then break end
  end
  return set
end
-- FX output: the FX folder plays through the master (S.fx_out 0) or a hardware output pair (its master send off).
-- Its hardware outputs are replaced.
function Drop.apply_output(ft)
  for i = r.GetTrackNumSends(ft, 1) - 1, 0, -1 do r.RemoveTrackSend(ft, 1, i) end
  if S.fx_out == 0 then r.SetMediaTrackInfo_Value(ft, "B_MAINSEND", 1); return end
  local idx = r.CreateTrackSend(ft, nil)
  r.SetTrackSendInfo_Value(ft, 1, idx, "I_DSTCHAN", (S.fx_out - 1) * 2)
  r.SetMediaTrackInfo_Value(ft, "B_MAINSEND", 0)
end
-- The name of an FX output: "Master", "Out 3/4".
function Drop.output_name(k) return k == 0 and "Master" or string.format("Out %d/%d", 2 * k - 1, 2 * k) end
function Drop.folder()
  local ft, fi = Drop.find_folder()
  if ft then return ft, fi end
  local n = r.CountTracks(0)
  r.InsertTrackAtIndex(n, true)
  local tr = r.GetTrack(0, n)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", CFG.FOLDER, true)
  if S.color then r.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", native(0x6B7385)) end
  r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", 1)
  if S.fx_out ~= 0 then Drop.apply_output(tr) end
  return tr, n
end
function Drop.type_track(typ)
  local _, fi = Drop.folder()
  local n = r.CountTracks(0)
  local depth, last = 1, fi
  for i = fi + 1, n - 1 do -- the children of the folder (a type track is a direct child)
    local tr = r.GetTrack(0, i)
    if depth == 1 and track_name(tr):lower() == typ:lower() then return tr end
    last = i
    depth = depth + r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
    if depth <= 0 then break end
  end
  -- the new track goes after the last child and closes the folder in its place (it takes the last child's depth)
  local close = -1
  if last ~= fi then close = r.GetMediaTrackInfo_Value(r.GetTrack(0, last), "I_FOLDERDEPTH") end
  r.InsertTrackAtIndex(last + 1, true)
  local tr = r.GetTrack(0, last + 1)
  if last ~= fi then r.SetMediaTrackInfo_Value(r.GetTrack(0, last), "I_FOLDERDEPTH", 0) end
  r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", math.min(-1, close))
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", typ, true)
  if S.color then r.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", native(TYPES[TYPE_IDX[typ] or #TYPES].color)) end
  return tr
end

-- Copy into the project: the folder of the copies (nil: the project is not saved yet).
function Drop.copy_dir()
  local _, pf = r.EnumProjects(-1)
  if not pf or pf == "" then return nil end
  local d = Util.norm(pf):match("^(.*)/[^/]*$")
  return d and (d .. "/" .. CFG.COPY_DIR) or nil
end
-- The copy of a sound in the folder: the same name and size is used again, else "Name (2).wav". Returns the path and
-- true when it exists already.
function Drop.copy_target(dir, e)
  local fn = e.path:match("([^/]+)$")
  local base, ext = fn:match("^(.*)(%.[^%.]+)$")
  base, ext = base or fn, ext or ""
  local size = Util.file_size(e.path)
  for k = 1, 999 do
    local pth = dir .. "/" .. (k == 1 and fn or string.format("%s (%d)%s", base, k, ext))
    local s = Util.file_size(pth)
    if not s then return pth, false end
    if s == size then return pth, true end
  end
  return dir .. "/" .. fn, true
end
-- Before an insert: the bytes of the new copies of a list of { e = sound } and the size of the folder now (0, 0 when
-- Copy into the project is off or the project is not saved).
function Drop.copy_need(list)
  if not S.copy then return 0, 0 end
  local dir = Drop.copy_dir()
  if not dir then return 0, 0 end
  local need, seen = 0, {}
  for _, it in ipairs(list) do
    if not seen[it.e.path] then
      seen[it.e.path] = true
      local _, exists = Drop.copy_target(dir, it.e)
      if not exists then need = need + (Util.file_size(it.e.path) or 0) end
    end
  end
  local size = 0
  if need > 0 then for _, f in ipairs(Util.dir_files(dir)) do size = size + f.size end end
  return need, size
end
-- The file that a new item uses: the copy in the project folder (made when needed), or the library file (Copy into
-- the project off, "Use the library file", an unsaved project or a failed copy).
function Drop.source(e)
  if not S.copy or R.copy_mode == "library" then return e.path end
  local dir = Drop.copy_dir()
  if not dir then R.copy_note = "Save the project to copy the sounds into it: the library file is used."; return e.path end
  local pth, exists = Drop.copy_target(dir, e)
  if exists then return pth end
  r.RecursiveCreateDirectory(dir, 0)
  local data = Util.read_all(e.path)
  if not data or not Util.write_all(pth, data) then
    R.copy_note = "Could not copy " .. e.name .. ": the library file is used."
    return e.path
  end
  return pth
end
-- Clean up: the files of the project's SFX Drop folder that no item of this project uses and that no other project
-- file (.rpp) of the project folder names (another version of the song). Returns the list and the bytes, or nil and
-- why.
function Drop.cleanup_list()
  local dir = Drop.copy_dir()
  if not dir then return nil, "Save the project first." end
  local _, cur = r.EnumProjects(-1)
  cur = Util.norm(cur):lower()
  local others = {}
  for _, f in ipairs(Util.dir_files(dir:match("^(.*)/[^/]*$"))) do
    if f.path:lower():match("%.rpp$") and f.path:lower() ~= cur then others[#others + 1] = Util.read_all(f.path) or "" end
  end
  local used = {}
  for i = 0, r.CountMediaItems(0) - 1 do
    local it = r.GetMediaItem(0, i)
    for k = 0, r.CountTakes(it) - 1 do
      local tk = r.GetTake(it, k)
      local src = tk and r.GetMediaItemTake_Source(tk)
      if src then
        local par = r.GetMediaSourceParent(src)
        local fn = r.GetMediaSourceFileName(par or src)
        if fn and fn ~= "" then used[Util.norm(fn):lower()] = true end
      end
    end
  end
  local list, bytes = {}, 0
  for _, f in ipairs(Util.dir_files(dir)) do
    local keep = used[f.path:lower()]
    local fn = f.path:match("([^/]+)$")
    for _, txt in ipairs(others) do if keep then break end; keep = txt:find(fn, 1, true) ~= nil end
    if not keep then list[#list + 1] = f.path; bytes = bytes + f.size end
  end
  return list, bytes
end

-- Puts 1 item of a sound with its hit point on t (inside an undo block). Returns the item, and true when the start
-- of the sound was cut.
function Drop.put(e, t)
  local tr = Drop.type_track(e.type)
  local pos, len, offs, cut = Drop.layout(e, t, S.trim)
  local item = r.AddMediaItemToTrack(tr)
  local take = r.AddTakeToMediaItem(item)
  r.SetMediaItemTake_Source(take, r.PCM_Source_CreateFromFile(Drop.source(e)))
  r.GetSetMediaItemTakeInfo_String(take, "P_NAME", e.name, true)
  r.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", offs)
  r.SetMediaItemTakeInfo_Value(take, "D_VOL", Drop.gain(e))
  r.SetMediaItemInfo_Value(item, "D_POSITION", pos)
  r.SetMediaItemInfo_Value(item, "D_LENGTH", len)
  local f = S.fades and math.min(S.fade_ms / 1000, len / 4) or 0
  -- the fade-in ends where the sound starts (it never softens the attack of a hit)
  local fin = (f > 0 and e.start >= offs) and math.min(f, math.max(0.001, e.start - offs)) or f
  r.SetMediaItemInfo_Value(item, "D_FADEINLEN", fin)
  r.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", f)
  if S.select_item then r.SetMediaItemSelected(item, true) end
  R.last = { item = item, take = take, path = e.path, target = t }
  return item, cut
end
local CUT_MSG = "The start of a sound was cut: its hit point is too close to the project start."
-- Inserts a list of { e = sound, t = target } with 1 undo point. Returns the number of items and true when a start
-- was cut.
function Drop.insert_list(list, undo_name)
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  if S.select_item then r.SelectAllMediaItems(0, false) end
  local n, cut = 0, false
  for _, it in ipairs(list) do
    local _, c = Drop.put(it.e, it.t)
    n, cut = n + 1, cut or c
  end
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock(undo_name, -1)
  return n, cut
end
-- Inserts a sound at each target of Place at (1 undo point). Returns the number of items, or nil and why.
function Drop.insert(e)
  if not e then return nil, "Select a sound first." end
  if not r.file_exists(e.path) then return nil, "The file is missing: " .. e.rel end
  local targets, why = Drop.targets()
  if not targets then return nil, why end
  local list = {}
  local vars = S.vary and Lib.variants(e, #targets)
  for k, t in ipairs(targets) do list[#list + 1] = { e = vars and vars[k] or e, t = t } end
  local n, cut = Drop.insert_list(list, "SFX Drop: insert " .. e.name)
  return n, cut and CUT_MSG or nil
end

-- "Learn from the moved item": the hit point of the last inserted sound from where you moved its item to.
function Drop.learn()
  local l = R.last
  if not l or not r.ValidatePtr2(0, l.item, "MediaItem*") then return nil, "Insert a sound first, then move its item." end
  local e = Lib.find(l.path)
  if not e then return nil, "The sound is no longer in the library." end
  local take = r.GetActiveTake(l.item)
  local pos = r.GetMediaItemInfo_Value(l.item, "D_POSITION")
  local offs = take and r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") or 0
  local rate = take and r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE") or 1
  local hit = (l.target - pos) * rate + offs
  if hit < 0 or hit > e.len then return nil, "The item is too far from the beat." end
  e.own = math.floor(hit * 10000 + 0.5) / 10000
  Lib.save_index()
  return e
end

---------------------------------------------------------------------------
-- SPOTS (Find spots: the level of the song bar by bar -> where a riser, an impact, a drop or an atmosphere fits)
---------------------------------------------------------------------------
-- The kinds of spot: the types of the sounds that it suggests, and its text.
local SPOT_KINDS = {
  rise = { types = { "Risers", "Impacts" }, text = "quiet to loud" },
  fall = { types = { "Drops" }, text = "loud to quiet" },
  quiet = { types = { "Atmos" }, text = "quiet part" },
  region = { types = { "Impacts" }, text = "region" },
}

-- The spots from the bars { { t, num, db } } and the regions { { t, name } } (pure: no REAPER calls).
-- A jump: the level of the SPOT_W bars after a bar line against the SPOT_W bars before it, at least sens dB, and the
-- largest jump of its neighbours. A quiet part: SPOT_QUIET_BARS bars or more, SPOT_QUIET dB under the average.
-- A region start that is no spot yet. Jumps are ticked; quiet parts and region starts are not.
function Spots.analyse(bars, regions, sens)
  local n = #bars
  local out, used = {}, {}
  local pw = {}
  local sum, cnt = 0, 0
  for i = 1, n do
    pw[i] = 10 ^ (math.max(bars[i].db, CFG.SPOT_SILENT - 10) / 10) -- (silence counts as -60 dB, not -150)
    if bars[i].db > CFG.SPOT_SILENT then sum, cnt = sum + pw[i], cnt + 1 end
  end
  local avg = cnt > 0 and 10 * math.log(sum / cnt, 10) or -150
  local function mean(a, b)
    local s, k = 0, 0
    for i = math.max(1, a), math.min(n, b) do s, k = s + pw[i], k + 1 end
    return k > 0 and 10 * math.log(math.max(s / k, 1e-15), 10) or -150
  end
  local w = CFG.SPOT_W
  local d = {}
  for b = 2, n do d[b] = mean(b, b + w - 1) - mean(b - w, b - 1) end
  -- (a rise is compared only with the rises next to it, a fall with the falls: a short loud part gives both)
  local function same(b, x) local v = d[x] or 0; return (v > 0) == (d[b] > 0) and math.abs(v) or 0 end
  for b = 2, n do
    local a = math.abs(d[b])
    if a >= sens and a >= same(b, b - 1) and a > same(b, b + 1) then
      out[#out + 1] = { t = bars[b].t, num = bars[b].num, kind = d[b] > 0 and "rise" or "fall", delta = d[b], on = true }
      used[b] = true
    end
  end
  local run = 0
  for b = 1, n + 1 do
    if b <= n and bars[b].db > CFG.SPOT_SILENT and bars[b].db < avg - CFG.SPOT_QUIET then
      run = run + 1
    else
      local s = b - run
      if run >= CFG.SPOT_QUIET_BARS and not used[s] and not used[s + 1] then
        out[#out + 1] = { t = bars[s].t, num = bars[s].num, kind = "quiet", on = false }
        used[s] = true
      end
      run = 0
    end
  end
  for _, rg in ipairs(regions) do
    local b = 0
    for i = 1, n do if bars[i].t <= rg.t + 0.0005 then b = i else break end end
    local on_bar = b > 0 and math.abs(bars[b].t - rg.t) < 0.0005
    if not (on_bar and used[b]) then
      out[#out + 1] = { t = rg.t, num = b > 0 and bars[b].num or 1, kind = "region", name = rg.name, on = false }
    end
  end
  table.sort(out, function(x, y) return x.t < y.t end)
  return out
end

-- The text of a spot: "quiet to loud +9 dB", "Chorus (region)", "quiet part".
function Spots.reason(s)
  local k = SPOT_KINDS[s.kind]
  if s.kind == "region" then return (s.name ~= "" and s.name or "Region") .. " (region)" end
  if s.delta then return string.format("%s %+.0f dB", k.text, s.delta) end
  return k.text
end

-- Spots > Add: is a type on? (S.spot_off: the types that are off, "Drops,Atmos")
function Spots.type_on(ty)
  if R.spot_off_src ~= S.spot_off then
    R.spot_off_src, R.spot_off_set = S.spot_off, {}
    for w in S.spot_off:gmatch("[^,]+") do R.spot_off_set[w] = true end
  end
  return not R.spot_off_set[ty]
end
function Spots.set_type(ty, on)
  local t = {}
  for _, tp in ipairs(TYPES) do
    local off = tp.name == ty and not on or (tp.name ~= ty and not Spots.type_on(tp.name))
    if off then t[#t + 1] = tp.name end
  end
  S.spot_off = table.concat(t, ",")
  R.spot_groups = nil
  Util.mark_sdirty()
end
-- Spots > Sounds with: the words, lower case (cached until the text changes).
function Spots.words()
  if R.spot_words_src ~= S.spot_words then
    R.spot_words_src, R.spot_words_list = S.spot_words, {}
    for w in S.spot_words:lower():gmatch("[^,%s]+") do R.spot_words_list[#R.spot_words_list + 1] = w end
  end
  return R.spot_words_list
end
-- The suggested sound of a type: a sound with one of the words (Sounds with), favourites first; with Riser length a
-- riser that fits first. nil: none.
function Spots.pick(ty)
  local words = Spots.words()
  local fit = ty == "Risers" and S.riser_bars > 0
  local bs = fit and Lib.bar_sec() or 2
  local first, first_fit
  for _, e in ipairs(Lib.by_type(ty)) do
    local ok = #words == 0
    for _, w in ipairs(words) do if e.lname:find(w, 1, true) then ok = true; break end end
    if ok then
      first = first or e
      if fit and Lib.riser_fit(e, S.riser_bars, bs) then first_fit = e; break end
      if not fit then break end
    end
  end
  return first_fit or first
end
-- Sounds with changed: every spot gets the suggestion again (the ticks stay).
function Spots.repick()
  for _, s in ipairs(R.spots or {}) do
    for _, pt in ipairs(s.parts) do
      local e = Spots.pick(pt.type)
      pt.path = e and e.path or nil
    end
  end
end
-- A spot shows when one of its types is on (Spots > Add).
function Spots.visible(s)
  for _, pt in ipairs(s.parts) do if Spots.type_on(pt.type) then return true end end
  return false
end

-- The suggested sounds of each spot: per type Spots.pick. Keeps the choice of a spot of the same time and kind from
-- old (a change of the sensitivity).
function Spots.fill(list, old)
  local keep = {}
  for _, s in ipairs(old or {}) do keep[string.format("%.4f%s", s.t, s.kind)] = s end
  for _, s in ipairs(list) do
    local o = keep[string.format("%.4f%s", s.t, s.kind)]
    if o then s.on, s.parts = o.on, o.parts
    else
      s.parts = {}
      for _, ty in ipairs(SPOT_KINDS[s.kind].types) do
        local first = Spots.pick(ty)
        s.parts[#s.parts + 1] = { type = ty, path = first and first.path or nil }
      end
    end
  end
  return list
end

-- Find spots: the tracks to read (the selected ones, else all; never the FX folder), the range (the time selection,
-- else the whole project) and its bars.
function Spots.find_begin()
  local fx = Drop.fx_tracks()
  local tracks = {}
  local nsel = r.CountSelectedTracks(0)
  for i = 0, (nsel > 0 and nsel or r.CountTracks(0)) - 1 do
    local tr = nsel > 0 and r.GetSelectedTrack(0, i) or r.GetTrack(0, i)
    if not fx[tr] and r.CountTrackMediaItems(tr) > 0 then tracks[#tracks + 1] = tr end
  end
  if #tracks == 0 then return nil, "No tracks with items to read (the FX folder is never read)." end
  local t0, t1 = r.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if t1 <= t0 then t0, t1 = 0, r.GetProjectLength(0) end
  if t1 - t0 < 1 then return nil, "The song is too short." end
  local bars = {}
  local _, m = r.TimeMap2_timeToBeats(0, t0)
  local t = r.TimeMap2_beatsToTime(0, 0, m)
  while t < t1 and #bars < 5000 do
    local nt = r.TimeMap2_beatsToTime(0, 0, m + 1)
    if nt >= t0 then bars[#bars + 1] = { t = math.max(t, t0), t_end = math.min(nt, t1), num = m + 1, p = 0 } end
    m, t = m + 1, nt
  end
  local regions, i = {}, 0
  while true do
    local rv, isrgn, pos, rgnend, name = r.EnumProjectMarkers3(0, i)
    if rv == 0 then break end
    if isrgn and rgnend > t0 and pos < t1 then regions[#regions + 1] = { t = pos, t_end = rgnend, name = name or "" } end
    i = i + 1
  end
  R.spot_scan = { tracks = tracks, ti = 1, bi = 1, bars = bars, regions = regions, buf = r.new_array(CFG.SPOT_MAX_FRAMES * 2),
    proj = r.EnumProjects(-1) }
  return true
end
function Spots.find_step(budget)
  local sc = R.spot_scan
  if not sc then return end
  local t_end = Util.now() + budget
  while Util.now() < t_end do
    local tr = sc.tracks[sc.ti]
    if not tr then Spots.find_done(); return end
    if not r.ValidatePtr2(0, tr, "MediaTrack*") then -- (deleted while Find reads it: skip it)
      if sc.acc then r.DestroyAudioAccessor(sc.acc); sc.acc = nil end
      sc.ti = sc.ti + 1
      goto continue
    end
    if not sc.acc then sc.acc, sc.bi = r.CreateTrackAudioAccessor(tr), 1 end
    do
      local bar = sc.bars[sc.bi]
      if not bar then
        r.DestroyAudioAccessor(sc.acc)
        sc.acc, sc.ti = nil, sc.ti + 1
      else
        local dur = bar.t_end - bar.t
        local sr = math.min(CFG.SPOT_SR, math.floor(CFG.SPOT_MAX_FRAMES / math.max(dur, 0.001)))
        local frames = math.max(1, math.min(CFG.SPOT_MAX_FRAMES, math.floor(dur * sr)))
        sc.buf.clear()
        if r.GetAudioAccessorSamples(sc.acc, sr, 2, bar.t, frames, sc.buf) == 1 then
          local s = 0
          local v = sc.buf.table(1, frames * 2)
          for k = 1, frames * 2 do s = s + v[k] * v[k] end
          bar.p = bar.p + s / (frames * 2) -- (the tracks add up as power: the level of the mix)
        end
        sc.bi = sc.bi + 1
      end
    end
    ::continue::
  end
end
function Spots.find_done()
  local sc = R.spot_scan
  if not sc then return end
  R.spot_scan = nil
  local bars = {}
  for i, b in ipairs(sc.bars) do
    bars[i] = { t = b.t, num = b.num, db = b.p > 0 and 10 * math.log(b.p, 10) or -150 }
  end
  R.spot_bars = { bars = bars, regions = sc.regions }
  R.spot_proj = sc.proj
  Spots.update(true)
end
function Spots.cancel()
  local sc = R.spot_scan
  if sc and sc.acc then r.DestroyAudioAccessor(sc.acc) end
  R.spot_scan = nil
end
-- The spots again (after Find, or a change of the sensitivity: the choices of the same spots stay).
function Spots.update(fresh)
  if not R.spot_bars then return end
  R.spots = Spots.fill(Spots.analyse(R.spot_bars.bars, R.spot_bars.regions, S.spot_sens), not fresh and R.spots or nil)
  R.spot_groups = nil
end
-- The short text of a spot in its line: "+12 dB", "-9 dB", "quiet part", "region start" (cached in the spot).
function Spots.short(s)
  if not s.short then
    s.short = s.delta and string.format("%+.0f dB", s.delta) or (s.kind == "quiet" and "quiet part" or "region start")
  end
  return s.short
end
-- The spots per region (the regions of the last Find, in time order; the spots outside every region last). No
-- regions: 1 group without a name. Cached until the spots change.
function Spots.groups()
  if R.spot_groups then return R.spot_groups end
  local regs = {}
  for _, rg in ipairs(R.spot_bars and R.spot_bars.regions or {}) do regs[#regs + 1] = rg end
  table.sort(regs, function(a, b) return a.t < b.t end)
  local g = {}
  local shown = {}
  for _, s in ipairs(R.spots or {}) do if Spots.visible(s) then shown[#shown + 1] = s end end
  if #regs == 0 then
    g[1] = { spots = shown }
  else
    local out = { name = "Outside the regions", id = "out", spots = {} }
    local by = {}
    for i, rg in ipairs(regs) do
      by[i] = { name = rg.name ~= "" and rg.name or ("Region " .. i), id = string.format("%.3f", rg.t), spots = {} }
    end
    for _, s in ipairs(shown) do
      local home = out
      for i, rg in ipairs(regs) do
        if s.t >= rg.t - 0.0005 and s.t < (rg.t_end or rg.t) - 0.0005 then home = by[i]; break end
      end
      home.spots[#home.spots + 1] = s
    end
    for _, grp in ipairs(by) do if #grp.spots > 0 then g[#g + 1] = grp end end
    if #out.spots > 0 then g[#g + 1] = out end
  end
  for _, grp in ipairs(g) do grp.count = #grp.spots .. (#grp.spots == 1 and " spot" or " spots") end
  R.spot_groups = g
  return g
end
-- The sounds of the ticked spots: { { e, t } }.
function Spots.list()
  local list = {}
  for _, s in ipairs(R.spots or {}) do
    if s.on then
      for _, pt in ipairs(s.parts) do
        local e = Spots.type_on(pt.type) and pt.path and Lib.find(pt.path)
        if e and r.file_exists(e.path) then list[#list + 1] = { e = e, t = s.t } end
      end
    end
  end
  if S.vary then -- (each sound that is used at several spots: a different sound of its folder at each one)
    local count, k = {}, {}
    for _, it in ipairs(list) do count[it.e] = (count[it.e] or 0) + 1 end
    local vars = {}
    for e, n in pairs(count) do if n > 1 then vars[e] = Lib.variants(e, n) end end
    for _, it in ipairs(list) do
      local v = vars[it.e]
      if v then k[it.e] = (k[it.e] or 0) + 1; it.e = v[k[it.e]] end
    end
  end
  return list
end
-- Inserts the ticked spots: each suggested sound with its hit point on the spot (1 undo point). Returns the number of
-- items, or nil and why.
function Spots.insert()
  local list = Spots.list()
  if #list == 0 then return nil, "Tick a spot that has a sound first." end
  local n, cut = Drop.insert_list(list, "SFX Drop: insert spots")
  return n, cut and CUT_MSG or nil
end

---------------------------------------------------------------------------
-- SOUNDCHECK (a new "Soundcheck" track after the last song: areas of the source track from quiet to loud, then the
-- impacts zone: each impact and bass drop repeated)
---------------------------------------------------------------------------
local SC_LENGTHS = { 60, 90, 120, 180, 240, 300 } -- Full length (seconds)
local SC_STEPS = { 3, 4, 5, 6, 8 }                 -- Steps (areas, quiet to loud)
local SC_REPEATS = { 1, 2, 4, 8 }                  -- Repeat each (impact)
local SC_DEF = { len = 120, steps = 5, imp = true, rep = 4 }
local function in_list(v, list) for _, x in ipairs(list) do if x == v then return true end end return false end
-- P: src (the GUID of the source track), len, steps, imp (Impacts zone), rep. Saved as "src=...;len=90" (only what
-- differs from the defaults; nothing: no key).
function Sc.serialize()
  local t = {}
  if P.src ~= "" then t[#t + 1] = "src=" .. P.src end
  if P.len ~= SC_DEF.len then t[#t + 1] = "len=" .. P.len end
  if P.steps ~= SC_DEF.steps then t[#t + 1] = "steps=" .. P.steps end
  if P.imp ~= SC_DEF.imp then t[#t + 1] = "imp=" .. (P.imp and "1" or "0") end
  if P.rep ~= SC_DEF.rep then t[#t + 1] = "rep=" .. P.rep end
  return table.concat(t, ";")
end
function Sc.parse(txt)
  P.src, P.len, P.steps, P.imp, P.rep = "", SC_DEF.len, SC_DEF.steps, SC_DEF.imp, SC_DEF.rep
  for k, v in (txt or ""):gmatch("(%a+)=([^;]*)") do
    local n = tonumber(v)
    if k == "src" then P.src = v
    elseif k == "len" and in_list(n, SC_LENGTHS) then P.len = n
    elseif k == "steps" and in_list(n, SC_STEPS) then P.steps = n
    elseif k == "rep" and in_list(n, SC_REPEATS) then P.rep = n
    elseif k == "imp" then P.imp = v == "1" end
  end
end
function Sc.load()
  local _, txt = r.GetProjExtState(0, CFG.EXT, CFG.SC_KEY)
  Sc.parse(txt)
  P.saved = Sc.serialize()
  R.sc_state, R.sc_plan = nil, nil
end
-- A setting changed: write it into the project (all defaults: the key is removed); the plan is old.
function Sc.changed()
  local txt = Sc.serialize()
  if txt ~= P.saved then
    r.SetProjExtState(0, CFG.EXT, CFG.SC_KEY, txt)
    P.saved = txt
  end
  R.sc_plan = nil
end

local function is_sc_item(it) local _, v = r.GetSetMediaItemInfo_String(it, CFG.SC_MARK, "", false); return v == "1" end
local function is_sc_track(tr) local _, v = r.GetSetMediaTrackInfo_String(tr, CFG.SC_MARK, "", false); return v == "1" end
-- The tracks (by GUID) and the songs (the regions, not the Soundcheck region), again after each project change.
function Sc.refresh()
  local st = r.GetProjectStateChangeCount(0)
  if R.sc_state == st then return end
  R.sc_state = st
  R.sc_tracks = {}
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    R.sc_tracks[r.GetTrackGUID(tr)] = tr
  end
  R.sc_regions = {}
  local i = 0
  while true do
    local rv, isrgn, pos, rend, name, num = r.EnumProjectMarkers3(0, i)
    if rv == 0 then break end
    if isrgn and name ~= CFG.SC_REGION then
      R.sc_regions[#R.sc_regions + 1] = { num = num, name = name ~= "" and name or ("Region " .. num), t = pos, t_end = rend }
    end
    i = i + 1
  end
  table.sort(R.sc_regions, function(a, b) return a.t < b.t end)
  local tr = Sc.src_track()
  R.sc_src_name = tr and Sc.track_label(tr) or nil
end
-- A track's name in the Source list: "Backing", "Band (folder, 6 tracks)".
function Sc.track_label(tr)
  local nm = track_name(tr) ~= "" and track_name(tr) or ("Track " .. math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")))
  if r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
    return string.format("%s (folder, %d tracks)", nm, #Sc.members(tr) - 1)
  end
  return nm
end
-- The tracks of a source: a track alone, or a folder track and all the tracks in it (in order).
function Sc.members(tr)
  local list = { tr }
  if r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") ~= 1 then return list end
  local depth = 1
  for i = math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")), r.CountTracks(0) - 1 do
    local t = r.GetTrack(0, i)
    list[#list + 1] = t
    depth = depth + r.GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
    if depth <= 0 then break end
  end
  return list
end
function Sc.src_track()
  local tr = P.src ~= "" and R.sc_tracks and R.sc_tracks[P.src]
  return tr and r.ValidatePtr2(0, tr, "MediaTrack*") and tr or nil
end
-- The old Soundcheck region: { num, t, t_end }, or nil.
function Sc.old_region()
  local i = 0
  while true do
    local rv, isrgn, pos, rend, name, num = r.EnumProjectMarkers3(0, i)
    if rv == 0 then return nil end
    if isrgn and name == CFG.SC_REGION then return { num = num, t = pos, t_end = rend } end
    i = i + 1
  end
end
-- The songs: the regions, or (no regions) the whole project before the Soundcheck region.
function Sc.songs()
  if #(R.sc_regions or {}) > 0 then return R.sc_regions end
  local old = Sc.old_region()
  return { { num = 0, name = "Project", t = 0, t_end = old and old.t or r.GetProjectLength(0) } }
end
-- The type track of the FX folder (not made when missing).
function Sc.type_track(typ)
  local _, fi = Drop.find_folder()
  if not fi then return nil end
  local depth = 1
  for i = fi + 1, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    if depth == 1 and track_name(tr):lower() == typ:lower() then return tr end
    depth = depth + r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
    if depth <= 0 then break end
  end
end
-- The impacts and bass drops of the FX folder: each different sound once (its first item), in time order.
function Sc.fx_sounds()
  local list, seen = {}, {}
  for _, typ in ipairs({ "Impacts", "Drops" }) do
    local tr = Sc.type_track(typ)
    for i = 0, (tr and r.CountTrackMediaItems(tr) or 0) - 1 do
      local it = r.GetTrackMediaItem(tr, i)
      local tk = r.GetActiveTake(it)
      local s = tk and r.GetMediaItemTake_Source(tk)
      local fn = s and r.GetMediaSourceFileName(s) or ""
      if fn ~= "" and not seen[fn] and not is_sc_item(it) then
        seen[fn] = true
        list[#list + 1] = { item = it, len = r.GetMediaItemInfo_Value(it, "D_LENGTH"), name = r.GetTakeName(tk),
          pos = r.GetMediaItemInfo_Value(it, "D_POSITION") }
      end
    end
  end
  table.sort(list, function(a, b) return a.pos < b.pos end)
  return list
end

-- The areas (pure: no REAPER calls). bars: { { t, t_end, pw, num } } of the source track; songs: { { t, t_end, name } };
-- L: the length of an area (seconds). Each candidate starts on a bar line, lies inside one song and has no silent bar.
-- The n areas are spread over the candidates' levels (from the 10 % quietest up to the loudest) without overlap,
-- then sorted from quiet to loud. Returns { { a, z, db, song, num } }.
function Sc.pick_areas(bars, songs, L, n)
  local silent = 10 ^ (CFG.SPOT_SILENT / 10)
  local cands = {}
  for _, sg in ipairs(songs) do
    for i, b in ipairs(bars) do
      if b.t >= sg.t - 0.0005 and b.t + L <= sg.t_end + 0.0005 then
        local s, cnt, ok = 0, 0, true
        for j = i, #bars do
          local bj = bars[j]
          if bj.t >= b.t + L - 0.0005 then break end
          if bj.pw <= silent then ok = false; break end
          s, cnt = s + bj.pw, cnt + 1
        end
        if ok and cnt > 0 then
          cands[#cands + 1] = { a = b.t, z = b.t + L, db = 10 * math.log(s / cnt, 10), song = sg.name, num = b.num }
        end
      end
    end
  end
  table.sort(cands, function(x, y) return x.db < y.db end)
  local picked = {}
  if #cands == 0 then return picked end
  local lo = math.max(1, math.floor(#cands * 0.1))
  local function free(c)
    for _, p in ipairs(picked) do if c.a < p.z and c.z > p.a then return false end end
    return true
  end
  for k = 1, n do
    local want = n == 1 and #cands or math.floor(lo + (#cands - lo) * (k - 1) / (n - 1) + 0.5)
    for d = 0, #cands do -- the nearest free candidate to the wanted rank
      local c = cands[want + d] or nil
      if c and free(c) then picked[#picked + 1] = c; break end
      c = cands[want - d]
      if c and free(c) then picked[#picked + 1] = c; break end
    end
  end
  table.sort(picked, function(x, y) return x.db < y.db end)
  return picked
end
-- The strongest hits of the source track (pure): a bar whose peak is SC_HIT_JUMP dB or more above the level of the
-- bar before; the strongest first, at least 4 s apart. Returns { { t, db, song, num } }.
function Sc.source_hits(bars, songs, k)
  local hits = {}
  for i = 2, #bars do
    local b, prev = bars[i], bars[i - 1]
    local pk = b.pk and b.pk > 0 and 20 * math.log(b.pk, 10) or -150
    local before = prev.pw > 0 and 10 * math.log(prev.pw, 10) or -150
    if pk - before >= CFG.SC_HIT_JUMP and pk > CFG.SPOT_SILENT then
      for _, sg in ipairs(songs) do
        if b.pk_t >= sg.t and b.pk_t + CFG.SC_HIT_LEN <= sg.t_end then
          hits[#hits + 1] = { t = b.pk_t, db = pk, song = sg.name, num = b.num }
          break
        end
      end
    end
  end
  table.sort(hits, function(x, y) return x.db > y.db end)
  local out = {}
  for _, h in ipairs(hits) do
    local ok = true
    for _, o in ipairs(out) do if math.abs(o.t - h.t) < 4 then ok = false end end
    if ok then out[#out + 1] = h end
    if #out >= k then break end
  end
  return out
end
-- The plan (pure except fx, which the caller gives): the impacts zone (the FX sounds, then the source hits; each
-- repeated rep times; dropped from the end when it is more than SC_ZONE_MAX of the full length), then the length of
-- each area so that everything fits the full length. Returns { steps, zone, L, dropped, total }.
function Sc.make_plan(bars, songs, total, steps, imp, rep, fx)
  local zone = {}
  if imp then
    for _, s in ipairs(fx) do zone[#zone + 1] = { item = s.item, len = s.len, name = s.name } end
    for _, h in ipairs(Sc.source_hits(bars, songs, CFG.SC_SRC_HITS)) do
      zone[#zone + 1] = { a = h.t - CFG.SC_HIT_PRE, z = h.t + CFG.SC_HIT_LEN, len = CFG.SC_HIT_PRE + CFG.SC_HIT_LEN,
        name = string.format("Hit (%s, bar %d)", h.song, h.num) }
    end
  end
  local function zone_len()
    local s = 0
    for _, z in ipairs(zone) do s = s + rep * (z.len + CFG.SC_GAP) end
    return s
  end
  local dropped = 0
  while #zone > 0 and zone_len() > total * CFG.SC_ZONE_MAX do table.remove(zone); dropped = dropped + 1 end
  local zl = zone_len()
  local L = math.max(CFG.SC_MIN_AREA, (total - zl - (zl > 0 and CFG.SC_GAP or 0)) / steps)
  local areas = Sc.pick_areas(bars, songs, L, steps)
  return { steps = areas, zone = zone, L = L, dropped = dropped, rep = rep, total = #areas * L + (zl > 0 and (CFG.SC_GAP + zl) or 0) }
end

-- Find areas: read the level of each bar of the source track (in steps), then make the plan; build = true builds it.
function Sc.find_begin(build)
  Sc.refresh()
  local tr = Sc.src_track()
  if not tr then return nil, "Choose the source track first." end
  local songs = Sc.songs()
  local t0, t1 = math.huge, 0
  for _, sg in ipairs(songs) do t0, t1 = math.min(t0, sg.t), math.max(t1, sg.t_end) end
  if t1 - t0 < 1 then return nil, "The songs are too short." end
  local bars = {}
  local _, m = r.TimeMap2_timeToBeats(0, t0)
  local t = r.TimeMap2_beatsToTime(0, 0, m)
  while t < t1 and #bars < 20000 do
    local nt = r.TimeMap2_beatsToTime(0, 0, m + 1)
    if nt > t0 then bars[#bars + 1] = { t = math.max(t, t0), t_end = math.min(nt, t1), num = m + 1, pw = 0, pk = 0, pk_t = t } end
    m, t = m + 1, nt
  end
  -- the tracks to read: the source, or every track of the source folder that has items (their mix)
  local tracks = {}
  for _, t2 in ipairs(Sc.members(tr)) do if r.CountTrackMediaItems(t2) > 0 then tracks[#tracks + 1] = t2 end end
  if #tracks == 0 then return nil, "The source has no items." end
  R.sc_scan = { tr = tr, tracks = tracks, ti = 1, bi = 1, bars = bars, songs = songs, build = build,
    proj = r.EnumProjects(-1), buf = r.new_array(CFG.SC_MAX_FRAMES * 2) }
  return true
end
function Sc.find_step(budget)
  local sc = R.sc_scan
  if not sc then return end
  local t_end = Util.now() + budget
  while Util.now() < t_end do
    local tr = sc.tracks[sc.ti]
    if not tr then Sc.find_done(); return end
    if not r.ValidatePtr2(0, tr, "MediaTrack*") then Sc.cancel(); UI.notice("A source track was deleted.", true); return end
    if not sc.acc then sc.acc, sc.bi = r.CreateTrackAudioAccessor(tr), 1 end
    local bar = sc.bars[sc.bi]
    if not bar then
      r.DestroyAudioAccessor(sc.acc)
      sc.acc, sc.ti = nil, sc.ti + 1
    else
      local dur = bar.t_end - bar.t
      local sr = math.min(CFG.SC_SR, math.floor(CFG.SC_MAX_FRAMES / math.max(dur, 0.001)))
      local frames = math.max(1, math.min(CFG.SC_MAX_FRAMES, math.floor(dur * sr)))
      sc.buf.clear()
      if r.GetAudioAccessorSamples(sc.acc, sr, 2, bar.t, frames, sc.buf) == 1 then
        local v = sc.buf.table(1, frames * 2)
        local s, pk, pk_k = 0, 0, 1
        for k = 1, frames * 2 do
          local x = v[k]
          s = s + x * x
          if x > pk or -x > pk then pk, pk_k = math.abs(x), k end
        end
        bar.pw = bar.pw + s / (frames * 2) -- (the tracks of a folder add up as power: their mix)
        if pk > bar.pk then bar.pk, bar.pk_t = pk, bar.t + math.floor((pk_k - 1) / 2) / sr end
      end
      sc.bi = sc.bi + 1
    end
  end
end
function Sc.cancel()
  local sc = R.sc_scan
  if sc and sc.acc then r.DestroyAudioAccessor(sc.acc) end
  R.sc_scan = nil
end
function Sc.find_done()
  local sc = R.sc_scan
  if not sc then return end
  Sc.cancel()
  local plan = Sc.make_plan(sc.bars, sc.songs, P.len, P.steps, P.imp, P.rep, P.imp and Sc.fx_sounds() or {})
  -- the plan list texts (made once)
  local at = 0
  for i, st in ipairs(plan.steps) do
    st.text = string.format("%d   %s   %s, bar %d   %.0f dB", i, Util.secs(at), st.song, st.num, st.db)
    at = at + (st.z - st.a)
  end
  if #plan.zone > 0 then
    local names = {}
    for _, z in ipairs(plan.zone) do names[#names + 1] = z.name .. " x" .. plan.rep end
    plan.zone_text = string.format("Impacts   %s   %s", Util.secs(at + CFG.SC_GAP), table.concat(names, ", "))
  end
  R.sc_plan = plan
  if sc.build then Sc.build(plan) end
end
-- Copies the part a..z of an item to the time T on track dest: the takes keep their offsets, the cut edges get a short
-- fade, the copy gets the Soundcheck mark.
function Sc.copy_part(it, a, z, T, dest)
  local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
  local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
  local s, e = math.max(pos, a), math.min(pos + len, z)
  if e - s < 0.001 then return end
  local _, chunk = r.GetItemStateChunk(it, "", false)
  chunk = chunk:gsub("\n%s*IGUID [^\n]*", ""):gsub("\n%s*GUID [^\n]*", "") -- (new GUIDs for the copy)
  local ni = r.AddMediaItemToTrack(dest)
  r.SetItemStateChunk(ni, chunk, false)
  local cut_l = s - pos
  if cut_l > 0 then
    for k = 0, r.CountTakes(ni) - 1 do
      local tk = r.GetTake(ni, k)
      if tk then
        local rate = r.GetMediaItemTakeInfo_Value(tk, "D_PLAYRATE")
        r.SetMediaItemTakeInfo_Value(tk, "D_STARTOFFS", r.GetMediaItemTakeInfo_Value(tk, "D_STARTOFFS") + cut_l * rate)
      end
    end
    r.SetMediaItemInfo_Value(ni, "D_FADEINLEN", CFG.SC_FADE)
    r.SetMediaItemInfo_Value(ni, "D_FADEINLEN_AUTO", 0)
  end
  if e < pos + len then
    r.SetMediaItemInfo_Value(ni, "D_FADEOUTLEN", CFG.SC_FADE)
    r.SetMediaItemInfo_Value(ni, "D_FADEOUTLEN_AUTO", 0)
  end
  r.SetMediaItemInfo_Value(ni, "D_POSITION", T + (s - a))
  r.SetMediaItemInfo_Value(ni, "D_LENGTH", e - s)
  r.GetSetMediaItemInfo_String(ni, CFG.SC_MARK, "1", true)
end
-- Copies the time a..z of a track to T on dest (the items are listed first).
function Sc.copy_range(tr, a, z, T, dest)
  local list = {}
  for i = 0, r.CountTrackMediaItems(tr) - 1 do
    local it = r.GetTrackMediaItem(tr, i)
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    if pos < z and pos + r.GetMediaItemInfo_Value(it, "D_LENGTH") > a and not is_sc_item(it)
        and r.GetMediaItemInfo_Value(it, "B_MUTE") == 0 then list[#list + 1] = it end
  end
  for _, it in ipairs(list) do Sc.copy_part(it, a, z, T, dest) end
end
-- The Soundcheck tracks: copies of the source tracks (their FX, sends, outputs, volume and pan) without items, at the end
-- of the track list. A track: 1 track "Soundcheck". A folder: a folder "Soundcheck" with copies of its tracks (the
-- same nesting; the last one closes only the new folder). All with the Soundcheck mark. Returns orig -> copy, the top.
function Sc.make_tracks(members)
  local map, depths = {}, {}
  for k, m in ipairs(members) do
    local n = r.CountTracks(0)
    r.InsertTrackAtIndex(n, true)
    local nt = r.GetTrack(0, n)
    local _, chunk = r.GetTrackStateChunk(m, "", false)
    chunk = chunk:gsub("TRACKID {[^}]*}", function() return "TRACKID " .. r.genGuid("") end)
      :gsub("FXID {[^}]*}", function() return "FXID " .. r.genGuid("") end)
    r.SetTrackStateChunk(nt, chunk, false)
    for i = r.CountTrackMediaItems(nt) - 1, 0, -1 do r.DeleteTrackMediaItem(nt, r.GetTrackMediaItem(nt, i)) end
    r.GetSetMediaTrackInfo_String(nt, CFG.SC_MARK, "1", true)
    map[m] = nt
    depths[k] = r.GetMediaTrackInfo_Value(m, "I_FOLDERDEPTH")
  end
  local top = map[members[1]]
  if #members == 1 then
    r.SetMediaTrackInfo_Value(top, "I_FOLDERDEPTH", 0)
  else
    local sum = 0
    for k = 1, #members - 1 do sum = sum + depths[k]; r.SetMediaTrackInfo_Value(map[members[k]], "I_FOLDERDEPTH", depths[k]) end
    r.SetMediaTrackInfo_Value(map[members[#members]], "I_FOLDERDEPTH", -sum)
  end
  r.SetMediaTrackInfo_Value(top, "B_MUTE", 0)
  r.GetSetMediaTrackInfo_String(top, "P_NAME", CFG.SC_REGION, true)
  return map, top
end
-- Deletes the old Soundcheck: its track, the marked items, the region and the markers inside it.
function Sc.remove_old()
  for t = r.CountTracks(0) - 1, 0, -1 do
    local tr = r.GetTrack(0, t)
    if is_sc_track(tr) then r.DeleteTrack(tr)
    else
      for i = r.CountTrackMediaItems(tr) - 1, 0, -1 do
        local it = r.GetTrackMediaItem(tr, i)
        if is_sc_item(it) then r.DeleteTrackMediaItem(tr, it) end
      end
    end
  end
  local old = Sc.old_region()
  if not old then return end
  local del, i = {}, 0
  while true do
    local rv, isrgn, pos, _, _, num = r.EnumProjectMarkers3(0, i)
    if rv == 0 then break end
    if not isrgn and pos >= old.t - 0.0005 and pos <= old.t_end + 0.0005 then del[#del + 1] = num end
    i = i + 1
  end
  for _, num in ipairs(del) do r.DeleteProjectMarker(0, num, false) end
  r.DeleteProjectMarker(0, old.num, true)
end
-- Builds a plan (1 undo point): deletes the old Soundcheck, makes the track after the last song: the areas from quiet
-- to loud (a marker each), then the impacts zone (each one rep times, 1 s apart), and the region.
function Sc.build(plan)
  local srctr = Sc.src_track()
  if not srctr then UI.notice("Choose the source track first.", true); return end
  if #plan.steps == 0 and #plan.zone == 0 then UI.notice("Nothing to build: no audible areas in the source track.", true); return end
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  Sc.remove_old()
  local _, m = r.TimeMap2_timeToBeats(0, r.GetProjectLength(0))
  local T0 = r.TimeMap2_beatsToTime(0, 0, m + 2) -- (after the last song, on a bar line, 1 bar or more of space)
  local members = Sc.members(srctr)
  local map, tr = Sc.make_tracks(members)
  local function copy_all(a, z, T1) for _, m in ipairs(members) do Sc.copy_range(m, a, z, T1, map[m]) end end
  local T = T0
  for i, st in ipairs(plan.steps) do
    r.AddProjectMarker2(0, false, T, 0, string.format("Step %d (%.0f dB)", i, st.db), -1, 0)
    copy_all(st.a, st.z, T)
    T = T + (st.z - st.a)
  end
  if #plan.zone > 0 then
    if #plan.steps > 0 then T = T + CFG.SC_GAP end
    r.AddProjectMarker2(0, false, T, 0, "Impacts", -1, 0)
    for _, z in ipairs(plan.zone) do
      for _ = 1, plan.rep do
        if z.item and r.ValidatePtr2(0, z.item, "MediaItem*") then
          local pos = r.GetMediaItemInfo_Value(z.item, "D_POSITION")
          Sc.copy_part(z.item, pos, pos + z.len, T, tr)
        elseif z.a then
          copy_all(z.a, z.z, T)
        end
        T = T + z.len + CFG.SC_GAP
      end
    end
    T = T - CFG.SC_GAP
  end
  r.AddProjectMarker2(0, true, T0, T, CFG.SC_REGION, -1, 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.TrackList_AdjustWindows(false)
  r.Undo_EndBlock("SFX Drop: build soundcheck", -1)
  R.sc_state = nil
  local txt = string.format("Soundcheck built: %d %s from quiet to loud%s, %s.", #plan.steps,
    #plan.steps == 1 and "step" or "steps", #plan.zone > 0 and (", " .. #plan.zone .. " impacts x" .. plan.rep) or "",
    Util.secs(T - T0))
  if plan.dropped > 0 then UI.notice(txt .. " " .. plan.dropped .. " impacts did not fit the full length.", true)
  else UI.notice(txt) end
end
-- Find and build at once (the tests).
function Sc.find_build()
  local ok, why = Sc.find_begin(true)
  if not ok then return nil, why end
  while R.sc_scan do Sc.find_step(1) end
  return true
end

---------------------------------------------------------------------------
-- CHECK THE SHOW (before you pack the laptop: missing files, library files, sample rates, tails into the next song)
---------------------------------------------------------------------------
-- R.check: { { kind, text, name, song, item, path, fix } }; kind: "missing" (any item), "library" (an FX item whose file
-- is outside the project folder; fix "copy"), "srate" (an FX item at another sample rate), "tail" (an FX item that rings
-- into the next song; fix "cut").
function Chk.run()
  local list = {}
  local fx = Drop.fx_tracks()
  local psr = r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, false) == 1 and r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
    or tonumber(select(2, r.GetAudioDeviceInfo("SRATE", ""))) or 0
  local dir = Drop.copy_dir()
  local pdir = dir and dir:match("^(.*)/[^/]*$"):lower() .. "/"
  local libdir = Util.norm(S.library):lower() .. "/" -- (a file of the library folder: offline on another computer)
  local regs, i = {}, 0
  while true do
    local rv, isrgn, pos, rend, name = r.EnumProjectMarkers3(0, i)
    if rv == 0 then break end
    if isrgn and name ~= CFG.SC_REGION then regs[#regs + 1] = { t = pos, t_end = rend, name = name } end
    i = i + 1
  end
  table.sort(regs, function(a, b) return a.t < b.t end)
  for k = 0, r.CountMediaItems(0) - 1 do
    local it = r.GetMediaItem(0, k)
    local tk = r.GetActiveTake(it)
    local s = tk and r.GetMediaItemTake_Source(tk)
    if s then
      local par = r.GetMediaSourceParent(s) or s
      local fn = r.GetMediaSourceFileName(par) or ""
      local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local iend = pos + r.GetMediaItemInfo_Value(it, "D_LENGTH")
      local song, nxt = "", nil
      for j, rg in ipairs(regs) do
        if pos >= rg.t - 0.0005 and pos < rg.t_end then song, nxt = rg.name, regs[j + 1]; break end
      end
      local row = { item = it, name = r.GetTakeName(tk), song = song, path = Util.norm(fn) }
      local function add(kind, text, fix)
        local x = {}
        for kk, v in pairs(row) do x[kk] = v end
        x.kind, x.text, x.fix = kind, text, fix
        list[#list + 1] = x
      end
      if fn ~= "" and not r.file_exists(fn) then add("missing", "Missing file")
      elseif fx[r.GetMediaItem_Track(it)] and fn ~= "" then
        if pdir and libdir ~= "/" and Util.norm(fn):lower():sub(1, #libdir) == libdir then add("library", "Library file", "copy") end
        local sr = r.GetMediaSourceSampleRate(par)
        if psr > 0 and sr > 0 and math.abs(sr - psr) > 1 then add("srate", string.format("%.1f kHz", sr / 1000)) end
        if nxt and iend > nxt.t + 0.01 then add("tail", "Tail into next song", "cut") end
      end
    end
  end
  for _, x in ipairs(list) do -- (the cut point of a tail: the end of its song)
    if x.kind == "tail" then
      local pos = r.GetMediaItemInfo_Value(x.item, "D_POSITION")
      for _, rg in ipairs(regs) do if pos >= rg.t - 0.0005 and pos < rg.t_end then x.cut_at = rg.t_end end end
    end
  end
  R.check = list
  return list
end
-- Go: the edit cursor to the item, and only that item selected.
function Chk.go(x)
  if not r.ValidatePtr2(0, x.item, "MediaItem*") then return end
  r.SetEditCurPos(r.GetMediaItemInfo_Value(x.item, "D_POSITION"), true, false)
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(x.item, true)
  r.UpdateArrange()
end
-- Copy: the file of an item into the project's SFX Drop folder, and the item uses the copy.
function Chk.copy_one(x)
  local dir = Drop.copy_dir()
  if not dir or not r.ValidatePtr2(0, x.item, "MediaItem*") then return false end
  local e = { path = x.path, name = x.name }
  local pth, exists = Drop.copy_target(dir, e)
  if not exists then
    r.RecursiveCreateDirectory(dir, 0)
    local data = Util.read_all(x.path)
    if not data or not Util.write_all(pth, data) then return false end
  end
  local tk = r.GetActiveTake(x.item)
  if not tk then return false end
  r.SetMediaItemTake_Source(tk, r.PCM_Source_CreateFromFile(pth))
  return true
end
function Chk.fix(rows)
  r.Undo_BeginBlock()
  local n = 0
  for _, x in ipairs(rows) do
    if x.fix == "copy" and Chk.copy_one(x) then n = n + 1
    elseif x.fix == "cut" and x.cut_at and r.ValidatePtr2(0, x.item, "MediaItem*") then
      local pos = r.GetMediaItemInfo_Value(x.item, "D_POSITION")
      r.SetMediaItemInfo_Value(x.item, "D_LENGTH", math.max(0.01, x.cut_at - pos))
      r.SetMediaItemInfo_Value(x.item, "D_FADEOUTLEN", math.min(CFG.TAIL_FADE, math.max(0.001, (x.cut_at - pos) / 4)))
      n = n + 1
    end
  end
  r.UpdateArrange()
  r.Undo_EndBlock("SFX Drop: check the show", -1)
  r.Main_OnCommand(40047, 0) -- Peaks: Build any missing peaks (the copies)
  Chk.run()
  return n
end

---------------------------------------------------------------------------
-- PREVIEW (SWS: CF_CreatePreview)
---------------------------------------------------------------------------
function Prev.can() return r.CF_CreatePreview ~= nil end
function Prev.stop()
  local p = R.prev
  if not p then return end
  R.prev = nil
  r.CF_Preview_Stop(p.h)
  r.PCM_Source_Destroy(p.src)
end
function Prev.play(e)
  local was = R.prev and R.prev.path
  Prev.stop()
  if was == e.path or not Prev.can() then return end
  local src = r.PCM_Source_CreateFromFile(e.path)
  if not src then return end
  local h = r.CF_CreatePreview(src)
  if not h then r.PCM_Source_Destroy(src); return end
  r.CF_Preview_Play(h)
  R.prev = { h = h, src = src, path = e.path, t_end = Util.now() + e.len + 0.2 }
end
function Prev.tick() if R.prev and Util.now() > R.prev.t_end then Prev.stop() end end

---------------------------------------------------------------------------
-- SETTINGS (ExtState "SFX Drop")
---------------------------------------------------------------------------
local S_KEYS = { "light", "dock", "tab", "settings_open", "library", "place", "trim", "fades", "fade_ms", "color",
  "select_item", "riser_bars", "level_on", "spot_sens", "sort", "sort_desc", "copy", "copy_asked", "copy_warn",
  "spot_off", "spot_words", "fx_out", "vary" }
local S_BOOL = { light = true, trim = true, fades = true, color = true, select_item = true, level_on = true,
  sort_desc = true, copy = true, copy_asked = true, vary = true }
local S_STR = { library = true, spot_off = true, spot_words = true, -- (true: any text)
  place = { cursor = true, bar = true, regions = true },
  sort = { name = true, type = true, len = true, bars = true, hit = true } }
local S_DEFAULTS = { light = false, dock = 0, tab = 1, settings_open = 2, library = "", place = "cursor", trim = true,
  fades = true, fade_ms = 5, color = true, select_item = true, riser_bars = 0, level_on = false, spot_sens = 6,
  sort = "name", sort_desc = false, copy = false, copy_asked = false, copy_warn = 500,
  spot_off = "", spot_words = "", fx_out = 0, vary = false }
-- The levels: 2 keys per type, "lvl_Impacts" (the target, dB) and "lvm_Impacts" (lufs / peak), each only when it
-- differs from the type's default.
function Util.load_settings()
  for k, v in pairs(S_DEFAULTS) do S[k] = v end
  for _, k in ipairs(S_KEYS) do
    local v = r.GetExtState(CFG.EXT, k)
    if v ~= "" then
      if S_STR[k] then S[k] = (S_STR[k] == true or S_STR[k][v]) and v or S_DEFAULTS[k]
      elseif S_BOOL[k] then S[k] = (v == "1")
      else S[k] = math.floor(tonumber(v) or 0) end
    end
  end
  S.levels, S.lvl_mode = {}, {}
  for _, t in ipairs(TYPES) do
    S.levels[t.name] = Util.clamp(tonumber(r.GetExtState(CFG.EXT, "lvl_" .. t.name)) or t.level, -40, 0)
    local m = r.GetExtState(CFG.EXT, "lvm_" .. t.name)
    S.lvl_mode[t.name] = (m == "lufs" or m == "peak") and m or t.mode
  end
  local ok_bars = false
  for _, b in ipairs(RISER_BARS) do if b == S.riser_bars then ok_bars = true end end
  if not ok_bars then S.riser_bars = 0 end
  S.tab = Util.clamp(S.tab, 1, 5)
  S.fade_ms = Util.clamp(S.fade_ms, 1, 50)
  S.spot_sens = Util.clamp(S.spot_sens, CFG.SPOT_SENS_MIN, CFG.SPOT_SENS_MAX)
  S.copy_warn = Util.clamp(S.copy_warn, 10, 100000)
  S.fx_out = Util.clamp(S.fx_out, 0, 64)
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
-- Saves only what differs from the default.
function Util.save_settings()
  for _, k in ipairs(S_KEYS) do
    local v, d = S[k], S_DEFAULTS[k]
    if v == d then r.DeleteExtState(CFG.EXT, k, true)
    else r.SetExtState(CFG.EXT, k, S_BOOL[k] and (v and "1" or "0") or tostring(v), true) end
  end
  for _, t in ipairs(TYPES) do
    local v = S.levels[t.name] or t.level
    if v == t.level then r.DeleteExtState(CFG.EXT, "lvl_" .. t.name, true)
    else r.SetExtState(CFG.EXT, "lvl_" .. t.name, string.format("%.1f", v), true) end
    local m = S.lvl_mode[t.name] or t.mode
    if m == t.mode then r.DeleteExtState(CFG.EXT, "lvm_" .. t.name, true)
    else r.SetExtState(CFG.EXT, "lvm_" .. t.name, m, true) end
  end
  R.sdirty = false
end

---------------------------------------------------------------------------
-- TESTS: tests/sfxdrop.lua sets SFXDropTest: hand it the modules and do not start the UI
---------------------------------------------------------------------------
if TESTING then
  local test = rawget(_G, "SFXDropTest")
  test.CFG, test.S, test.R, test.Util, test.Lib, test.Drop, test.Spots, test.TYPES = CFG, S, R, Util, Lib, Drop, Spots, TYPES
  test.Sc, test.P, test.Chk = Sc, P, Chk
  UI.notice = function(text) R.last_notice = text end
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

local TAB_NAMES = { "Sounds", "Spots", "Soundcheck" } -- then Settings (gear) and Help ("?")
local TAB_SOUNDS, TAB_SPOTS, TAB_SC, TAB_SETTINGS, TAB_HELP = 1, 2, 3, 4, 5
local RISER_LABELS = {}
for i, b in ipairs(RISER_BARS) do RISER_LABELS[i] = b == 0 and "Off" or (b .. (b == 1 and " bar" or " bars")) end
local RISER_TIP = "The risers that are this many bars long (the Bars column, within 10 %) come first in the list "
  .. "and in the Spots suggestions, and the list sorts by Length. The sounds are not changed. Off: the normal order."
local VARY_TIP = "On: an insert at several places (Region starts, the Spots tab) uses a different sound of the same "
  .. "folder at each place, never the same one twice in a row (the selected sound first). Off (default): the same "
  .. "sound everywhere."
local PLACES = { { "cursor", "Edit cursor" }, { "bar", "Nearest bar line" }, { "regions", "Region starts" } }
local PLACE_TIP = "Where the hit point of the sound lands:\n"
  .. "Edit cursor: exactly at the edit cursor.\n"
  .. "Nearest bar line: the bar line closest to the edit cursor (before or after it).\n"
  .. "Region starts: the start of each region in the time selection (no time selection: all regions)."
local SETTINGS_SECTIONS -- (filled after the Settings functions)

local HELP_INTRO = "SFX Drop puts sound effects from your library (impacts, risers, drops, atmospheres) on the beat "
  .. "of your backing tracks. It finds the hit point of each sound, so you never nudge an item into place."
local HELP_TOPICS = {
  { title = "Getting started", text = [[
1. Settings > Library: choose your library folder. SFX Drop reads all the sounds in it and in its subfolders (the first time takes a while; then only new files are read). Pause or Stop the scan on the status line. SFX Drop also asks if it must copy the sounds into each project.
2. Sounds tab: type in Search, or pick a Type. Click a column title (Name, Type, Length, Bars, Hit) to sort by it; click again for the other direction.
3. Put the edit cursor on the beat where the sound must hit (or pick another Place at).
4. Double-click the sound, or select it and click Insert. One Ctrl+Z undoes the insert.]] },
  { title = "The hit point", text = [[
The hit point is the moment of a sound that lands on the beat:
- Impacts, Drops, Atmos and Other: the start of the sound (the silence before it is skipped).
- Risers: the loudest point (where the riser peaks, just before the downbeat).

The Hit column shows it. Not right for a sound? Right-click the sound:
- Start of the sound / Loudest point: pick the other one.
- Learn from the moved item: insert the sound, move its item in REAPER until it sounds right, then pick this. SFX Drop keeps that hit point for the next inserts.
- Automatic: back to the default of its type.]] },
  { title = "Types", text = [[
The type comes from the folder and file names (the closest folder first):
Impacts: impact, hit, boom, slam, crash, braam, stab...
Risers: riser, rise, uplift, build, swell, reverse...
Drops: drop, downlift, sub, 808, fall...
Atmos: atmo, ambience, pad, drone, texture...
Everything else: Other.

Tip: a folder per type (Impacts, Risers, Drops, Atmos) gives the best result.]] },
  { title = "Where the sounds go", text = [[
Each sound goes on the track of its type (Impacts, Risers, Drops, Atmos, Other) in a folder named "FX". SFX Drop makes the folder and the tracks when they are missing, and finds them again by name.

Copy into the project (Settings > Insert, off by default): each sound is copied into a folder "SFX Drop" in the project folder, so the project works on any computer. SFX Drop asks before the folder grows above the Warn above size (500 MB by default). Clean up deletes the copies that no item uses.

FX output (Settings > Insert): the FX folder plays through the master or its own hardware outputs (a separate FX feed to FOH).

Vary (under Place at): an insert at several places uses a different sound of the same folder each time.

Check the show (the Sounds tab, bottom right): before you pack the laptop, a list of missing files, sounds that are not in the project folder (Copy), other sample rates and effects that ring into the next song (Cut).

Trim silence (Settings > Insert): the item starts just before the sound and ends after its tail.
Fades: short fades at both ends, so the items never click.]] },
  { title = "Find spots", text = [[
The Spots tab finds the places in a song where an effect fits:
- quiet to loud (a build into a chorus): a riser and an impact,
- loud to quiet (a breakdown): a drop,
- a quiet part of 4 bars or more: an atmosphere (not ticked),
- each region start that is no spot yet: an impact (not ticked).

1. Select the tracks to read (the drums or the full mix work best). No selection: all tracks. The FX folder is never read. With a time selection, only that part is read.
2. Click Find. SFX Drop reads the level bar by bar.
3. Sensitivity: a lower value finds smaller jumps.
4. Add: turn the types on or off (an off type is not suggested or added). Sounds with: only sounds with these words, for example "boom, explosion".
5. Tick the spots you want and pick the sounds (click a sound to change it). Click a bar number to move the edit cursor there. A song with regions shows its spots per region: tick or fold a whole region at once.
6. Insert ticked. One Ctrl+Z undoes all of it.

Find spots needs a correct tempo map: the spots are on the bar lines.]] },
  { title = "Soundcheck", text = [[
The Soundcheck tab builds a new track "Soundcheck" after the last song, for FOH (check the PA) and a quick medley:
1. Steps: areas of the source track (for example your stereo backing track) with different levels and intensity, one after the other, from quiet to loud. Each step has a marker.
2. Impacts zone: each different impact and bass drop of the FX folder, then the strongest hits of the source track, each repeated (Repeat each, 4x by default).

Full length: the length of everything together. The steps share what the impacts zone leaves; impacts that do not fit are left out (a notice says so).

1. Choose the source: a track (your stereo backing track) or a folder (your stems: their mix is read, and the Soundcheck becomes a folder with copies of those tracks). Then the full length and the steps.
2. Find areas shows the plan (each step: its song, bar and level). Nothing changes.
3. Build soundcheck makes the track (a copy of the source track's FX and outputs, at the end of the track list) and a region "Soundcheck". A 2nd build replaces it (it asks first). One Ctrl+Z undoes a build.

The settings are saved in the project.]] },
  { title = "Favourites and riser length", text = [[
Favourites: click the star at the left of a sound. Type > Favourites shows only them, and Find spots suggests them first.

Riser length (under Place at): pick 1, 2, 4 or 8 bars. The risers of that length (the Bars column, within 10 %) come first, in the list and in the Spots suggestions, and the list sorts by Length (short to long). The sounds are never stretched.

The Bars column shows the length of each sound in bars, at the tempo at the edit cursor.]] },
  { title = "Levels", text = [[
Settings > Insert > Levels: each new item gets an item gain so that all sounds of a type have the same level. For each type pick:
- Peak: the loudest moment (good for impacts and drops), default -6 dB.
- LUFS: the average loudness (good for risers and atmospheres), for example Atmos at -24.
The levels are measured in the library scan. Off by default.]] },
  { title = "Preview", text = [[
The play button at the left of a sound plays it (click again to stop). This needs the free SWS extension (www.sws-extension.org). Without SWS, everything else works.]] },
}

local STYLE_COLS = {
  { "WindowBg", "WIN_BG" }, { "ChildBg", "TRANSPARENT" }, { "PopupBg", "PANEL_BG" },
  { "Border", "LINE" }, { "FrameBg", "FIELD" }, { "FrameBgHovered", "FIELD_HOVER" },
  { "FrameBgActive", "FIELD_ACTIVE" }, { "Button", "BTN" }, { "ButtonHovered", "BTN_HOVER" },
  { "ButtonActive", "BTN_ACTIVE" }, { "Header", "ACTIVE_BG" }, { "HeaderHovered", "HEADER_HOVER" },
  { "HeaderActive", "HEADER_ACTIVE" }, { "CheckMark", "ACCENT" }, { "Text", "TEXT_MAIN" },
  { "TextDisabled", "TEXT_DIM" }, { "Separator", "LINE" }, { "ScrollbarBg", "TRANSPARENT" },
  { "ScrollbarGrab", "BTN_HOVER" }, { "ScrollbarGrabHovered", "BTN_ACTIVE" },
  { "ScrollbarGrabActive", "TOGGLE_OFF" }, { "TitleBg", "TITLE_BG" }, { "TitleBgActive", "TITLE_BG_ACTIVE" },
  { "TitleBgCollapsed", "TITLE_BG" }, { "TableHeaderBg", "PANEL_BG" }, { "TableRowBg", "TRANSPARENT" },
  { "TableRowBgAlt", "ROW_HOVER" }, { "TableBorderLight", "LINE" }, { "TableBorderStrong", "LINE" },
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
  return math.max(min_w or 0, math.ceil((ImGui.CalcTextSize(ctx, (label:gsub("##.*$", "")))) + 22))
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
-- Section heading, as in Chart Cue: bold, blue, a full-width blue underline, a "?" at the right.
function UI.heading(text, help, id)
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
  local fh = ImGui.GetFrameHeight(ctx)
  ImGui.PushFont(ctx, head_font)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.TextColored(ctx, COL.HEADING, UI.trunc(text, math.max(30, full - (help and CFG.HELP_ICON + 8 or 0) - 8)))
  ImGui.PopFont(ctx)
  local _, ty = ImGui.GetItemRectMax(ctx)
  if help then
    ImGui.SameLine(ctx)
    ImGui.SetCursorScreenPos(ctx, sx + full - CFG.HELP_ICON, sy + (fh - CFG.HELP_ICON) / 2)
    UI.help_icon(id or text, help)
    local _, hy = ImGui.GetItemRectMax(ctx)
    ty = math.max(ty, hy)
  end
  ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), sx, ty + 3, sx + full, ty + 3, COL.ACCENT, 1.5)
  ImGui.SetCursorScreenPos(ctx, sx, ty)
  ImGui.Dummy(ctx, 0, 3)
  UI.vgap(CFG.SP_TITLE_AFTER)
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
function UI.notice(text, warn)
  text = tostring(text or ""):gsub("\n\n", " "):gsub(":\n", ": "):gsub("\n", ", ")
  R.notice = { text = text, warn = warn, t = Util.now() + CFG.NOTICE_SEC }
end
function UI.notice_h(w) -- the height of the notice (0: none)
  local n = R.notice
  if n and Util.now() > n.t then R.notice = nil; n = nil end
  if not n then return 0 end
  local _, h = ImGui.CalcTextSize(ctx, n.text, nil, nil, false, w)
  return math.min(h, 3 * ImGui.GetTextLineHeight(ctx)) + 6
end
function UI.draw_gear_icon(dl, cx, cy, col)
  for k = 0, 7 do
    local a = k * math.pi / 4
    local c, sn = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * 5, cy + sn * 5, cx + c * 8.5, cy + sn * 8.5, col, 3)
  end
  ImGui.DrawList_AddCircle(dl, cx, cy, 4.5, col, 0, 3)
end

-- The tab strip, as in Chart Cue: the text tabs, then the Settings (gear) and Help ("?") tabs.
function UI.draw_tabs()
  local aw = ImGui.GetContentRegionAvail(ctx)
  local gap, h, lift = CFG.TAB_GAP, CFG.TAB_H, CFG.TAB_LIFT
  local n = #TAB_NAMES
  local tab_w = math.floor((aw - 2 * h - gap * (n + 1) - CFG.TAB_GROUP_GAP - 8) / n)
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
      S.tab = i; Util.mark_sdirty()
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
    local label = (i == TAB_HELP) and "?" or TAB_NAMES[i]
    ImGui.PushFont(ctx, active and head_font or font)
    label = UI.trunc(label, w - 12)
    local tw = ImGui.CalcTextSize(ctx, label)
    ImGui.DrawList_AddText(dl, x + math.floor((w - tw) / 2), UI.text_y(top, bottom - top), col, label)
    ImGui.PopFont(ctx)
  end
  local x = x0 + 4
  for i = 1, n do tab(i, tab_w, x); x = x + tab_w + gap end
  x = x + CFG.TAB_GROUP_GAP
  tab(TAB_SETTINGS, h, x, "Settings"); x = x + h + gap
  tab(TAB_HELP, h, x, "Help: how SFX Drop works")
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
  ImGui.Dummy(ctx, 0, 0)
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
end

-- The play / stop button of a row (drawn: a triangle, or a square while it plays).
function UI.play_button(id, playing)
  local fh = ImGui.GetFrameHeight(ctx)
  local w = CFG.PLAY_W
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local hit = ImGui.InvisibleButton(ctx, id, w, fh)
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy = x + w / 2, y + fh / 2
  local col = playing and COL.ACCENT or (hov and COL.TEXT_BRIGHT or COL.TEXT_DIM)
  if playing then ImGui.DrawList_AddRectFilled(dl, cx - 4, cy - 4, cx + 4, cy + 4, col, 1)
  else ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 5, cx - 4, cy + 5, cx + 5, cy, col) end
  return hit
end

-- A column title that sorts the list: a click sorts by it, a 2nd click turns the direction. The sorted one is bright
-- with a small arrow (up: low to high).
local SORT_HEADS = { { "Name", "name" }, { "Type", "type" }, { "Length", "len" }, { "Bars", "bars" }, { "Hit", "hit" } }
function UI.sort_header(label, key)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local tw, th = ImGui.CalcTextSize(ctx, label)
  local w = math.max(tw + 12, ImGui.GetContentRegionAvail(ctx))
  if ImGui.InvisibleButton(ctx, "##sort_" .. key, w, th) then
    if S.sort == key then S.sort_desc = not S.sort_desc else S.sort, S.sort_desc = key, false end
    Util.mark_sdirty()
  end
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  UI.tip("Sort by " .. label:lower() .. " (click again for the other direction).")
  local on = S.sort == key
  local dl = ImGui.GetWindowDrawList(ctx)
  local col = (on or hov) and COL.TEXT_MAIN or COL.TEXT_DIM
  ImGui.DrawList_AddText(dl, x, y, col, label)
  if on then
    local ax, ay = x + tw + 7, y + th / 2
    if S.sort_desc then ImGui.DrawList_AddTriangleFilled(dl, ax - 3.5, ay - 2, ax + 3.5, ay - 2, ax, ay + 2.5, COL.ACCENT_HOVER)
    else ImGui.DrawList_AddTriangleFilled(dl, ax - 3.5, ay + 2, ax + 3.5, ay + 2, ax, ay - 2.5, COL.ACCENT_HOVER) end
  end
end

-- The favourite star of a row: filled when on, an outline when off.
function UI.star_button(id, on)
  local fh = ImGui.GetFrameHeight(ctx)
  local w = CFG.STAR_W
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local hit = ImGui.InvisibleButton(ctx, id, w, fh)
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy, ro, ri = x + w / 2, y + fh / 2 + 1, 7, 3
  local px, py = {}, {}
  for k = 0, 9 do
    local a = -math.pi / 2 + k * math.pi / 5
    local rr = (k % 2 == 0) and ro or ri
    px[k], py[k] = cx + rr * math.cos(a), cy + rr * math.sin(a)
  end
  if on then
    for k = 0, 9 do
      local k2 = (k + 1) % 10
      ImGui.DrawList_AddTriangleFilled(dl, cx, cy, px[k], py[k], px[k2], py[k2], COL.YELLOW)
    end
  else
    for k = 0, 9 do ImGui.DrawList_PathLineTo(dl, px[k], py[k]) end
    ImGui.DrawList_PathStroke(dl, hov and COL.TEXT_BRIGHT or COL.TOGGLE_OFF, ImGui.DrawFlags_Closed(), 1.3)
  end
  return hit
end

-- A question in a window: text, then up to 2 answers ({ label, fn }) and Cancel.
function UI.ask(text, a1, a2)
  R.ask = { text = text, a1 = a1, a2 = a2, open = true }
end
function UI.draw_ask()
  local a = R.ask
  if not a then return end
  if a.open then ImGui.OpenPopup(ctx, "SFX Drop##ask"); a.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if ImGui.BeginPopupModal(ctx, "SFX Drop##ask", nil, ImGui.WindowFlags_AlwaysAutoResize()) then
    ImGui.PushTextWrapPos(ctx, 380)
    ImGui.Text(ctx, a.text)
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    local pick
    if UI.button(a.a1[1], UI.btn_w(a.a1[1], 100), nil, "primary") then pick = a.a1[2] end
    if a.a2 then
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      if UI.button(a.a2[1], UI.btn_w(a.a2[1], 100)) then pick = a.a2[2] end
    end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Cancel", 90) then R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
    if pick then R.ask = nil; ImGui.CloseCurrentPopup(ctx); pick() end
    ImGui.EndPopup(ctx)
  else
    R.ask = nil
  end
end
-- The first-start question: copy the sounds into each project? (Settings > Insert > Copy into the project.)
function UI.ask_copy()
  UI.ask("Copy the sounds into each project?\n\n"
    .. "Copy: each sound that you insert is copied into a folder \"SFX Drop\" in the project folder. The project then "
    .. "works on any computer (your stage laptop too), but it uses more disk space.\n"
    .. "Keep in the library: the items use the files of your library folder (move or rename it, and they go offline).\n\n"
    .. "You can change it later in Settings > Insert > Copy into the project.",
    { "Copy into projects", function() S.copy, S.copy_asked = true, true; Util.mark_sdirty() end },
    { "Keep in the library", function() S.copy, S.copy_asked = false, true; Util.mark_sdirty() end })
end
-- Runs an insert of a list of { e = sound }: with Copy into the project, asks first when the project's SFX Drop
-- folder would grow above the warning size.
function UI.guarded(list, action)
  local function run(mode)
    R.copy_mode, R.copy_note = mode, nil
    action()
    R.copy_mode = nil
    if R.copy_note then UI.notice(R.copy_note, true); R.copy_note = nil end
  end
  local need, size = Drop.copy_need(list)
  if need > 0 and size + need > S.copy_warn * CFG.MB then
    UI.ask(string.format("The SFX Drop folder of this project is %.0f MB, and this insert adds %.1f MB "
      .. "(the warning is above %d MB: Settings > Insert).\n\nCopy the sounds anyway?", size / CFG.MB, need / CFG.MB, S.copy_warn),
      { "Copy", function() run(nil) end }, { "Use the library file", function() run("library") end })
    return
  end
  run(nil)
end

-- Inserts the selected sound and shows the result.
function UI.insert(e)
  UI.guarded({ { e = e } }, function() UI.insert_now(e) end)
end
function UI.insert_now(e)
  local n, why = Drop.insert(e)
  if not n then UI.notice(why, true); return end
  local txt = n == 1 and ("Inserted " .. e.name .. " on " .. e.type .. ".")
    or string.format("Inserted %s %d times on %s.", e.name, n, e.type)
  if why then UI.notice(txt .. " " .. why, true) else UI.notice(txt) end
end

-- The right-click menu of a sound: its hit point.
function UI.sound_menu(e)
  if not ImGui.BeginPopup(ctx, "##sound_menu") then return end
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Hit point of " .. e.name)
  ImGui.Separator(ctx)
  local auto_kind = TYPES[TYPE_IDX[e.type]].hit
  if ImGui.MenuItem(ctx, "Start of the sound (" .. Util.secs(e.start) .. ")", nil, e.own ~= nil and math.abs(e.own - e.start) < 0.0001) then
    e.own = auto_kind == "start" and nil or e.start; Lib.save_index()
  end
  if ImGui.MenuItem(ctx, "Loudest point (" .. Util.secs(e.peak) .. ")", nil, e.own ~= nil and math.abs(e.own - e.peak) < 0.0001) then
    e.own = auto_kind == "peak" and nil or e.peak; Lib.save_index()
  end
  local can_learn = R.last and R.last.path == e.path and r.ValidatePtr2(0, R.last.item, "MediaItem*")
  if ImGui.MenuItem(ctx, "Learn from the moved item", nil, false, can_learn and true or false) then
    local ok, why = Drop.learn()
    if ok then UI.notice("Hit point of " .. e.name .. ": " .. Util.secs(ok.own) .. ".") else UI.notice(why, true) end
  end
  if not can_learn and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, "Insert this sound, move its item in REAPER until it sounds right, then pick this.")
  end
  ImGui.Separator(ctx)
  if ImGui.MenuItem(ctx, "Automatic (" .. (auto_kind == "peak" and "loudest point" or "start of the sound") .. ")", nil, e.own == nil, e.own ~= nil) then
    e.own = nil; Lib.save_index()
  end
  ImGui.EndPopup(ctx)
end

-- The Sounds tab: Search, Type, the list, Place at and Insert.
function UI.draw_sounds()
  UI.vgap(CFG.SP_TITLE_BEFORE)
  if Util.norm(S.library) == "" then
    ImGui.TextWrapped(ctx, "Choose the folder of your sound effects first. SFX Drop reads the sounds in it and in its subfolders.")
    UI.vgap(10)
    if UI.button("Choose library folder...", UI.btn_w("Choose library folder..."), nil, "primary") then UI.choose_library() end
    return
  end
  local aw = ImGui.GetContentRegionAvail(ctx) - 10
  local type_w = 130
  ImGui.SetNextItemWidth(ctx, aw - type_w - CFG.CTRL_GAP)
  local ch, txt = ImGui.InputTextWithHint(ctx, "##search", "Search", R.search)
  if ch then R.search, R.view = txt, nil end
  UI.tip("Type words of the name or the folder (\"riser 8 bar\"). All words must match.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, type_w)
  local fname = R.filter == 0 and "All types" or R.filter == -1 and "Favourites" or TYPES[R.filter].name
  if ImGui.BeginCombo(ctx, "##type", fname) then
    if ImGui.Selectable(ctx, "All types", R.filter == 0) then R.filter, R.view = 0, nil end
    if ImGui.Selectable(ctx, "Favourites", R.filter == -1) then R.filter, R.view = -1, nil end
    for i, t in ipairs(TYPES) do
      if ImGui.Selectable(ctx, t.name, R.filter == i) then R.filter, R.view = i, nil end
    end
    ImGui.EndCombo(ctx)
  end
  -- the list
  local view = Lib.view() or {}
  local _, ah = ImGui.GetContentRegionAvail(ctx)
  local foot = 3 * ImGui.GetFrameHeight(ctx) + 4 * CFG.SP_ROW + 8
  local list_h = math.max(80, ah - foot)
  local flags = ImGui.TableFlags_ScrollY() | ImGui.TableFlags_BordersInnerH() | ImGui.TableFlags_PadOuterX()
  local menu_e
  if R.scan and #R.lib == 0 then
    ImGui.Dummy(ctx, aw, list_h)
  elseif ImGui.BeginTable(ctx, "##sounds", 7, flags, aw, list_h) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed(), CFG.PLAY_W)
    ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed(), CFG.STAR_W)
    ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch(), 1)
    ImGui.TableSetupColumn(ctx, "Type", ImGui.TableColumnFlags_WidthFixed(), CFG.COL_TYPE_W)
    ImGui.TableSetupColumn(ctx, "Length", ImGui.TableColumnFlags_WidthFixed(), CFG.COL_LEN_W)
    ImGui.TableSetupColumn(ctx, "Bars", ImGui.TableColumnFlags_WidthFixed(), CFG.COL_BARS_W)
    ImGui.TableSetupColumn(ctx, "Hit", ImGui.TableColumnFlags_WidthFixed(), CFG.COL_HIT_W)
    ImGui.TableNextRow(ctx, ImGui.TableRowFlags_Headers())
    ImGui.TableNextColumn(ctx); ImGui.TableNextColumn(ctx)
    for _, h in ipairs(SORT_HEADS) do ImGui.TableNextColumn(ctx); UI.sort_header(h[1], h[2]) end
    if not R.clipper or not ImGui.ValidatePtr(R.clipper, "ImGui_ListClipper*") then R.clipper = ImGui.CreateListClipper(ctx) end
    ImGui.ListClipper_Begin(R.clipper, #view)
    local can_prev = Prev.can()
    local bs = Lib.bar_sec()
    while ImGui.ListClipper_Step(R.clipper) do
      local d0, d1 = ImGui.ListClipper_GetDisplayRange(R.clipper)
      for k = d0 + 1, d1 do
        local e = R.lib[view[k]]
        ImGui.TableNextRow(ctx)
        ImGui.PushID(ctx, k)
        ImGui.TableNextColumn(ctx)
        if can_prev then
          if UI.play_button("##play", R.prev and R.prev.path == e.path) then R.sel = e.path; Prev.play(e) end
          UI.tip("Play the sound (click again to stop).")
        end
        ImGui.TableNextColumn(ctx)
        if UI.star_button("##fav", e.fav) then Lib.set_fav(e, not e.fav) end
        UI.tip(e.fav and "A favourite (click to remove)." or "Add to the favourites.")
        ImGui.TableNextColumn(ctx)
        local cw = ImGui.GetContentRegionAvail(ctx)
        local x, y = ImGui.GetCursorScreenPos(ctx)
        local selected = R.sel == e.path
        if ImGui.Selectable(ctx, "##row", selected, ImGui.SelectableFlags_SpanAllColumns() | ImGui.SelectableFlags_AllowDoubleClick(), 0, ImGui.GetFrameHeight(ctx)) then
          R.sel = e.path
          if ImGui.IsMouseDoubleClicked(ctx, 0) then UI.insert(e) end
        end
        if ImGui.IsItemHovered(ctx) then
          ImGui.SetTooltip(ctx, e.rel .. "\nDouble-click: insert. Right-click: the hit point.")
        end
        if ImGui.IsItemClicked(ctx, 1) then R.sel = e.path; R.menu_path = e.path; R.menu_open = true end
        local dl = ImGui.GetWindowDrawList(ctx)
        ImGui.DrawList_AddText(dl, x, UI.text_y(y), COL.TEXT_MAIN, UI.trunc_c(e.name, cw))
        ImGui.TableNextColumn(ctx)
        UI.row_text(e.type, COL.TEXT_DIM)
        ImGui.TableNextColumn(ctx)
        UI.row_text(Util.secs(e.len), COL.TEXT_DIM)
        ImGui.TableNextColumn(ctx)
        local fit = Lib.riser_fit(e, S.riser_bars, bs)
        UI.row_text(string.format("%.1f", e.len / bs), fit and COL.ACCENT_HOVER or COL.TEXT_DIM)
        if fit then UI.tip("This riser fits the Riser length.") end
        ImGui.TableNextColumn(ctx)
        UI.row_text(Util.secs(Lib.hit(e)), e.own and COL.ACCENT_HOVER or COL.TEXT_DIM)
        if e.own then UI.tip("Your own hit point (right-click the sound to change it).") end
        ImGui.PopID(ctx)
      end
    end
    -- (opened here, outside the row's PushID: the same ID as BeginPopup in UI.sound_menu)
    if R.menu_open then R.menu_open = nil; ImGui.OpenPopup(ctx, "##sound_menu") end
    if R.menu_path then menu_e = Lib.find(R.menu_path) end
    if menu_e then UI.sound_menu(menu_e) end
    if not ImGui.IsPopupOpen(ctx, "##sound_menu") then R.menu_path = nil end
    ImGui.EndTable(ctx)
  end
  -- Place at, Insert
  UI.vgap(8)
  ImGui.PushFont(ctx, bold)
  UI.row_text("Place at")
  ImGui.PopFont(ctx)
  UI.tip(PLACE_TIP)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local cur = PLACES[1][2]
  for _, p in ipairs(PLACES) do if p[1] == S.place then cur = p[2] end end
  ImGui.SetNextItemWidth(ctx, 170)
  if ImGui.BeginCombo(ctx, "##place", cur) then
    for _, p in ipairs(PLACES) do
      if ImGui.Selectable(ctx, p[2], S.place == p[1]) then S.place = p[1]; Util.mark_sdirty() end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip(PLACE_TIP)
  UI.riser_row()
  local sel = R.sel and Lib.find(R.sel)
  local iw = UI.btn_w("Insert", 100)
  ImGui.SameLine(ctx, aw - iw + 10)
  ImGui.BeginDisabled(ctx, sel == nil)
  if UI.button("Insert", iw, nil, "primary") then UI.insert(sel) end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, sel and ("Insert " .. sel.name .. " (Enter). One Ctrl+Z undoes it.") or "Select a sound first.")
  end
  -- the status line
  local status
  local sc = R.scan
  if sc then
    if sc.paused then
      status = sc.phase == "list" and "Paused (reading the folders)" or string.format("Paused at %d / %d", sc.i, #sc.files)
    else
      status = sc.phase == "list" and ("Reading the folders... " .. #sc.files .. " files")
        or string.format("Reading the sounds... %d / %d", sc.i, #sc.files)
    end
  else
    status = (#view == #R.lib) and (#R.lib .. (#R.lib == 1 and " sound" or " sounds"))
      or string.format("%d of %d sounds", #view, #R.lib)
  end
  ImGui.TextColored(ctx, COL.TEXT_DIM, status)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 4, 0)
  local lh = ImGui.GetTextLineHeight(ctx)
  if sc then
    if UI.button(sc.paused and "Resume" or "Pause", nil, lh, "ghost") then sc.paused = not sc.paused end
    UI.tip(sc.paused and "Go on with the scan." or "Pause the scan (the window stays free).")
    ImGui.SameLine(ctx, 0, 4)
    if UI.button("Stop", nil, lh, "ghost") then Lib.scan_stop() end
    UI.tip("Stop the scan. The sounds read so far stay; Rescan reads the rest.")
  else
    if UI.button("Rescan", nil, lh, "ghost") then Lib.scan_begin(false) end
    UI.tip("Reads the new files of the library and drops the removed ones.")
  end
  local cw = UI.btn_w("Check the show...")
  ImGui.SameLine(ctx, math.max(ImGui.GetCursorPosX(ctx), aw - cw + 10))
  if UI.button("Check the show...", cw, lh, "ghost") then Chk.run(); R.check_open = true end
  UI.tip("Before you pack the laptop: missing files, sounds that are not in the project folder, other sample rates and "
    .. "effects that ring into the next song. Nothing changes without a click.")
  ImGui.PopStyleVar(ctx)
end

local CHECK_TIP = {
  missing = "The file of this item is missing: the item is silent. Find the file, or replace the sound.",
  library = "This sound plays from your library folder, not from the project folder: on another computer it is offline. Copy puts it into the project.",
  srate = "This sound has another sample rate than the project. REAPER converts it, but a rendered or exported show can differ.",
  tail = "This effect rings into the next song. Cut ends it at the end of its song (with a short fade).",
}
-- The Check the show window: a row per problem (what, sound, song, Go, Fix), Copy all, Close.
function UI.draw_check()
  if R.check_open then ImGui.OpenPopup(ctx, "Check the show##check"); R.check_open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  ImGui.SetNextWindowSize(ctx, math.max(CFG.CHECK_MIN_W, math.min(CFG.CHECK_W, ww - 20)),
    math.max(220, math.min(CFG.CHECK_H, wh - 20)), ImGui.Cond_Appearing())
  if not ImGui.BeginPopupModal(ctx, "Check the show##check", nil, 0) then return end
  local list = R.check or {}
  local fh = ImGui.GetFrameHeight(ctx)
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  if #list == 0 then
    ImGui.TextColored(ctx, COL.GREEN, "No problems found.")
  end
  local flags = ImGui.TableFlags_ScrollY() | ImGui.TableFlags_BordersInnerH() | ImGui.TableFlags_PadOuterX()
  local fixed = false
  if #list > 0 and ImGui.BeginTable(ctx, "##check_list", 4, flags, aw, math.max(60, ah - fh - 2 * CFG.SP_ROW)) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "Problem", ImGui.TableColumnFlags_WidthFixed(), 140)
    ImGui.TableSetupColumn(ctx, "Sound", ImGui.TableColumnFlags_WidthStretch(), 2)
    ImGui.TableSetupColumn(ctx, "Song", ImGui.TableColumnFlags_WidthStretch(), 1)
    ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed(), CFG.CHECK_BTN_W * 2 + 8)
    ImGui.TableNextRow(ctx, ImGui.TableRowFlags_Headers())
    for _, h in ipairs({ "Problem", "Sound", "Song", "" }) do ImGui.TableNextColumn(ctx); ImGui.TextColored(ctx, COL.TEXT_DIM, h) end
    for i, x in ipairs(list) do
      ImGui.TableNextRow(ctx)
      ImGui.PushID(ctx, i)
      ImGui.TableNextColumn(ctx)
      UI.row_text(x.text, x.kind == "missing" and COL.RED or COL.ORANGE)
      UI.tip(CHECK_TIP[x.kind])
      ImGui.TableNextColumn(ctx)
      UI.row_text(UI.trunc_c(x.name, ImGui.GetContentRegionAvail(ctx)), COL.TEXT_MAIN)
      UI.tip(x.path)
      ImGui.TableNextColumn(ctx)
      UI.row_text(UI.trunc_c(x.song, ImGui.GetContentRegionAvail(ctx)), COL.TEXT_DIM)
      ImGui.TableNextColumn(ctx)
      if UI.button("Go", CFG.CHECK_BTN_W) then Chk.go(x) end
      UI.tip("Move the edit cursor to this item and select it.")
      if x.fix and not fixed then
        ImGui.SameLine(ctx, 0, 8)
        if UI.button(x.fix == "copy" and "Copy" or "Cut", CFG.CHECK_BTN_W) then Chk.fix({ x }); fixed = true end
        UI.tip(x.fix == "copy" and "Copy the file into the project folder; the item uses the copy." or "End the item at the end of its song, with a short fade.")
      end
      ImGui.PopID(ctx)
      if fixed then break end -- (the list was made again)
    end
    ImGui.EndTable(ctx)
  end
  local copies = {}
  for _, x in ipairs(list) do if x.fix == "copy" then copies[#copies + 1] = x end end
  ImGui.BeginDisabled(ctx, #copies == 0)
  if UI.button("Copy all into the project", UI.btn_w("Copy all into the project")) then
    local n = Chk.fix(copies)
    UI.notice(string.format("Copied %d %s into the project folder.", n, n == 1 and "sound" or "sounds"))
  end
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx, aw - 90 + 8)
  if UI.button("Close", 90) then ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- "Riser length" (the row under Place at).
function UI.riser_row()
  ImGui.PushFont(ctx, bold)
  UI.row_text("Riser length")
  ImGui.PopFont(ctx)
  UI.tip(RISER_TIP)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local cur = 1
  for i, b in ipairs(RISER_BARS) do if b == S.riser_bars then cur = i end end
  ImGui.SetNextItemWidth(ctx, 110)
  if ImGui.BeginCombo(ctx, "##riser_bars", RISER_LABELS[cur]) then
    for i, b in ipairs(RISER_BARS) do
      if ImGui.Selectable(ctx, RISER_LABELS[i], i == cur) and b ~= S.riser_bars then
        S.riser_bars = b
        if b > 0 then S.sort, S.sort_desc = "len", false end -- (a riser length: short to long)
        Util.mark_sdirty()
      end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip(RISER_TIP)
  ImGui.SameLine(ctx, 0, 14)
  ImGui.PushFont(ctx, bold)
  UI.row_text("Vary")
  ImGui.PopFont(ctx)
  UI.tip(VARY_TIP)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local ch, nv = UI.toggle("##vary", S.vary)
  if ch then S.vary = nv; Util.mark_sdirty() end
  UI.tip(VARY_TIP)
end

-- A small fold arrow (drawn) as a button. Returns true on a click.
function UI.fold_arrow(id, open)
  local fh = ImGui.GetFrameHeight(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local hit = ImGui.InvisibleButton(ctx, id, 14, fh)
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local dl, cx, cy = ImGui.GetWindowDrawList(ctx), x + 6, y + fh / 2
  local col = hov and COL.TEXT_MAIN or COL.HEADING
  if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col)
  else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col) end
  return hit
end

-- 1 line of a spot: tick, bar, a short reason, the sounds (small buttons that open the sound list).
function UI.spot_line(s, i)
  ImGui.PushID(ctx, i)
  local c, nv = ImGui.Checkbox(ctx, "##on", s.on)
  if c then s.on = nv end
  ImGui.SameLine(ctx, 0, 6)
  ImGui.PushFont(ctx, bold)
  if UI.button("Bar " .. s.num .. "##go", 70, nil, "ghost") then r.SetEditCurPos(s.t, true, false) end
  ImGui.PopFont(ctx)
  UI.tip("Move the edit cursor to this spot.")
  ImGui.SameLine(ctx, 0, 4)
  local x = ImGui.GetCursorPosX(ctx)
  UI.row_text(Spots.short(s), (s.kind == "rise" or s.kind == "fall") and COL.TEXT_MAIN or COL.TEXT_DIM)
  UI.tip(Spots.reason(s))
  ImGui.SameLine(ctx, x + 84, 0)
  local flags = ImGui.ComboFlags_NoArrowButton()
  local first = true
  for k, pt in ipairs(s.parts) do
    if not Spots.type_on(pt.type) then goto next_part end
    if not first then ImGui.SameLine(ctx, 0, 6) end
    first = false
    local e = pt.path and Lib.find(pt.path)
    ImGui.SetNextItemWidth(ctx, 120)
    if ImGui.BeginCombo(ctx, "##part" .. k, e and e.name or ("no " .. pt.type:lower()), flags) then
      for j, o in ipairs(Lib.by_type(pt.type)) do
        ImGui.PushID(ctx, j)
        if ImGui.Selectable(ctx, (o.fav and "* " or "") .. o.name, o.path == pt.path) then pt.path = o.path end
        ImGui.PopID(ctx)
      end
      ImGui.EndCombo(ctx)
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, e and (pt.type .. ": " .. e.name .. "\nClick to pick another one.")
        or ("No " .. pt.type .. " in the library: this sound is skipped."))
    end
    ::next_part::
  end
  ImGui.PopID(ctx)
end

-- A type chip of Spots > Add: filled with the type's color when on, grey when off. Returns true on a click.
function UI.type_chip(ty, on, color)
  local fh = ImGui.GetFrameHeight(ctx)
  local tw = ImGui.CalcTextSize(ctx, ty)
  local w = tw + 20
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local hit = ImGui.InvisibleButton(ctx, "##chip_" .. ty, w, fh)
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local dl = ImGui.GetWindowDrawList(ctx)
  local bg = on and ((color << 8) | 0xFF) or (hov and COL.BTN_HOVER or COL.BTN)
  ImGui.DrawList_AddRectFilled(dl, x, y + 2, x + w, y + fh - 2, bg, (fh - 4) / 2)
  if on and hov then ImGui.DrawList_AddRectFilled(dl, x, y + 2, x + w, y + fh - 2, 0xFFFFFF22, (fh - 4) / 2) end
  ImGui.DrawList_AddText(dl, x + 10, UI.text_y(y), on and 0x1E2127FF or COL.TEXT_DIM, ty)
  return hit
end

-- The Spots tab: Find and Sensitivity in 1 line, the spots (per region when the song has regions), Insert ticked.
function UI.draw_spots()
  UI.vgap(CFG.SP_TITLE_BEFORE)
  if #R.lib == 0 then
    ImGui.TextWrapped(ctx, "Choose your library folder first (Settings > Library): the spots suggest its sounds.")
    return
  end
  local aw = ImGui.GetContentRegionAvail(ctx) - 10
  local fh = ImGui.GetFrameHeight(ctx)
  local bw = UI.btn_w("Cancel", 80)
  if R.spot_scan then
    if UI.button("Cancel", bw) then Spots.cancel() end
  else
    if UI.button("Find", bw, nil, "primary") then
      local ok, why = Spots.find_begin()
      if not ok then UI.notice(why, true) end
    end
    UI.tip("Reads the level of the song bar by bar and suggests spots for a riser, an impact, a drop or an atmosphere.")
  end
  ImGui.SameLine(ctx, 0, 14)
  ImGui.PushFont(ctx, bold)
  UI.row_text("Sensitivity")
  ImGui.PopFont(ctx)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, 130)
  local ch, v = ImGui.SliderInt(ctx, "##sens", S.spot_sens, CFG.SPOT_SENS_MIN, CFG.SPOT_SENS_MAX, "%d dB")
  if ch then S.spot_sens = v; Util.mark_sdirty() end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then Spots.update(false) end
  UI.tip("The level jump that makes a spot (default 6 dB). Lower: more spots. Higher: only the big changes.")
  local nsel = r.CountSelectedTracks(0)
  ImGui.SameLine(ctx, 0, 14)
  UI.row_text(nsel > 0 and (nsel .. (nsel == 1 and " track" or " tracks")) or "all tracks", COL.TEXT_DIM)
  UI.tip("Find reads the selected tracks (none selected: all tracks). The FX folder is never read. With a time "
    .. "selection, only that part of the song is read.")
  -- Add: the types; Sounds with: the words
  ImGui.PushFont(ctx, bold)
  UI.row_text("Add")
  ImGui.PopFont(ctx)
  UI.tip("The types that Find suggests and Insert ticked adds. Click a type to turn it on or off.")
  for _, ty in ipairs({ "Risers", "Impacts", "Drops", "Atmos" }) do
    ImGui.SameLine(ctx, 0, ty == "Risers" and 14 or 6)
    local on = Spots.type_on(ty)
    if UI.type_chip(ty, on, TYPES[TYPE_IDX[ty]].color) then Spots.set_type(ty, not on) end
    UI.tip(on and (ty .. " are added (click to leave them out).") or (ty .. " are left out (click to add them)."))
  end
  ImGui.PushFont(ctx, bold)
  UI.row_text("Sounds with")
  ImGui.PopFont(ctx)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, math.min(260, aw - 110))
  local chw, txt = ImGui.InputTextWithHint(ctx, "##words", "any sound (e.g. boom, explosion)", S.spot_words)
  if chw then S.spot_words = txt; Util.mark_sdirty() end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then Spots.repick() end
  UI.tip("The spots suggest only sounds with one of these words in their name or folder (separate them with commas). "
    .. "Empty: any sound. A change picks the sounds of all spots again.")
  UI.vgap(4)
  ImGui.Separator(ctx)
  local sc = R.spot_scan
  if sc then
    local done = (sc.ti - 1) * #sc.bars + (sc.acc and sc.bi - 1 or 0)
    local all = math.max(1, #sc.tracks * #sc.bars)
    ImGui.TextColored(ctx, COL.TEXT_DIM, string.format("Reading the song... %d %%", math.floor(100 * done / all)))
    return
  end
  if not R.spots then
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, "Select the tracks to read (the drums or the full mix work best) and click Find. "
      .. "SFX Drop suggests spots; nothing changes until you click Insert ticked.")
    ImGui.PopTextWrapPos(ctx)
    return
  end
  local _, ah = ImGui.GetContentRegionAvail(ctx)
  local list_h = math.max(80, ah - fh - 2 * CFG.SP_ROW - 8)
  if ImGui.BeginChild(ctx, "##spots", aw, list_h) then
    if #R.spots == 0 then
      ImGui.TextColored(ctx, COL.TEXT_DIM, "No spots found. Lower the sensitivity, or select other tracks.")
    end
    R.spot_fold = R.spot_fold or {}
    local idx = 0
    for gi, grp in ipairs(Spots.groups()) do
      if grp.name then
        ImGui.PushID(ctx, "g" .. gi)
        local open = not R.spot_fold[grp.id]
        if UI.fold_arrow("##fold", open) then R.spot_fold[grp.id] = open or nil; open = not open end
        ImGui.SameLine(ctx, 0, 2)
        local all_on = true
        for _, s in ipairs(grp.spots) do if not s.on then all_on = false; break end end
        local c, nv = ImGui.Checkbox(ctx, "##all", all_on)
        if c then for _, s in ipairs(grp.spots) do s.on = nv end end
        UI.tip("Tick or untick all the spots of this region.")
        ImGui.SameLine(ctx, 0, 6)
        local cw = (ImGui.CalcTextSize(ctx, grp.count))
        ImGui.PushFont(ctx, head_font)
        UI.row_text(UI.trunc_c(grp.name, math.max(40, ImGui.GetContentRegionAvail(ctx) - cw - 24)), COL.HEADING)
        ImGui.PopFont(ctx)
        ImGui.SameLine(ctx, aw - cw - 8)
        UI.row_text(grp.count, COL.TEXT_DIM)
        ImGui.PopID(ctx)
        if open then
          ImGui.Indent(ctx, 22)
          for _, s in ipairs(grp.spots) do idx = idx + 1; UI.spot_line(s, idx) end
          ImGui.Unindent(ctx, 22)
        else
          idx = idx + #grp.spots
        end
        UI.vgap(6)
      else
        for _, s in ipairs(grp.spots) do idx = idx + 1; UI.spot_line(s, idx) end
      end
    end
    ImGui.Dummy(ctx, 0, 0) -- (an item after the last gap: the list must not end on a cursor move)
    ImGui.EndChild(ctx)
  end
  local ticked, n = 0, 0
  for _, s in ipairs(R.spots) do
    if Spots.visible(s) then n = n + 1; if s.on then ticked = ticked + 1 end end
  end
  UI.vgap(8)
  UI.row_text(string.format("%d %s, %d ticked", n, n == 1 and "spot" or "spots", ticked), COL.TEXT_DIM)
  local iw = UI.btn_w("Insert ticked", 120)
  ImGui.SameLine(ctx, aw - iw + 10)
  ImGui.BeginDisabled(ctx, ticked == 0)
  if UI.button("Insert ticked", iw, nil, "primary") then
    UI.guarded(Spots.list(), function()
      local cnt, why = Spots.insert()
      if not cnt then UI.notice(why, true)
      else
        local txt = string.format("Inserted %d %s at %d %s.", cnt, cnt == 1 and "sound" or "sounds", ticked, ticked == 1 and "spot" or "spots")
        if why then UI.notice(txt .. " " .. why, true) else UI.notice(txt) end
      end
    end)
  end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, ticked > 0 and "Insert the sounds of the ticked spots. One Ctrl+Z undoes all of it." or "Tick a spot first.")
  end
end

local SC_HELP = [[Soundcheck builds a new track "Soundcheck" after the last song:
1. Steps: areas of the source track (for example your stereo backing track) with different levels, from quiet to loud, one after the other.
2. Impacts zone: each impact and bass drop of the FX folder, then the strongest hits of the source track, each repeated (Repeat each).

Full length: everything together. The areas share what the impacts zone leaves; impacts that do not fit are left out (a notice says so).

The Soundcheck track is a copy of the source track (its FX and outputs), at the end of the track list. A 2nd build replaces it (it asks first). One Ctrl+Z undoes a build.

Saved in the project.]]
local function sc_len_text(s) return string.format("%d:%02d", math.floor(s / 60), s % 60) end
-- The Soundcheck tab: the settings, Find areas (the plan), Build soundcheck.
function UI.draw_sc()
  UI.vgap(CFG.SP_TITLE_BEFORE)
  Sc.refresh()
  local aw = ImGui.GetContentRegionAvail(ctx) - 10
  local fh = ImGui.GetFrameHeight(ctx)
  UI.heading("Soundcheck track", SC_HELP, "sc_head")
  -- Source track
  UI.form_label("Source track", "The track to take the areas from, for example your stereo backing track.")
  ImGui.SetNextItemWidth(ctx, math.min(260, ImGui.GetContentRegionAvail(ctx) - 10))
  if ImGui.BeginCombo(ctx, "##sc_src", R.sc_src_name or "Choose a track") then
    local fx = Drop.fx_tracks()
    for i = 0, r.CountTracks(0) - 1 do
      local tr = r.GetTrack(0, i)
      local folder = r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1
      if not fx[tr] and not is_sc_track(tr) and (folder or r.CountTrackMediaItems(tr) > 0) then
        ImGui.PushID(ctx, i)
        local g = r.GetTrackGUID(tr)
        local nm = Sc.track_label(tr)
        if ImGui.Selectable(ctx, nm, g == P.src) and g ~= P.src then P.src = g; R.sc_state = nil; Sc.changed() end
        ImGui.PopID(ctx)
      end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The track to take the areas from: a track (your stereo backing track) or a folder (its tracks together, for "
    .. "stems). The FX folder and the Soundcheck tracks are not in the list.")
  -- Full length
  UI.form_label("Full length", "The length of the whole soundcheck track: the steps and the impacts zone.")
  ImGui.SetNextItemWidth(ctx, 110)
  if ImGui.BeginCombo(ctx, "##sc_len", sc_len_text(P.len)) then
    for _, v in ipairs(SC_LENGTHS) do
      if ImGui.Selectable(ctx, sc_len_text(v), v == P.len) and v ~= P.len then P.len = v; Sc.changed() end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The length of the whole soundcheck track: the steps and the impacts zone together.")
  -- Steps
  UI.form_label("Steps", "How many areas of different level, from quiet to loud.")
  ImGui.SetNextItemWidth(ctx, 110)
  if ImGui.BeginCombo(ctx, "##sc_steps", tostring(P.steps)) then
    for _, v in ipairs(SC_STEPS) do
      if ImGui.Selectable(ctx, tostring(v), v == P.steps) and v ~= P.steps then P.steps = v; Sc.changed() end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("How many areas of different level, from quiet to loud.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  UI.row_text("quiet to loud", COL.TEXT_DIM)
  -- Impacts zone
  local ch, nv = UI.form_toggle("Impacts zone", P.imp,
    "On (default): after the steps, each impact and bass drop of the FX folder and the strongest hits of the source "
    .. "track, each repeated. Off: only the steps.")
  if ch then P.imp = nv; Sc.changed() end
  ImGui.SameLine(ctx, 0, 14)
  ImGui.BeginDisabled(ctx, not P.imp)
  UI.row_text("Repeat each", COL.TEXT_DIM)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, 80)
  if ImGui.BeginCombo(ctx, "##sc_rep", P.rep .. "x") then
    for _, v in ipairs(SC_REPEATS) do
      if ImGui.Selectable(ctx, v .. "x", v == P.rep) and v ~= P.rep then P.rep = v; Sc.changed() end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.EndDisabled(ctx)
  UI.vgap(4)
  ImGui.Separator(ctx)
  -- the plan
  local _, ah = ImGui.GetContentRegionAvail(ctx)
  local list_h = math.max(60, ah - fh - 2 * CFG.SP_ROW - 8)
  if ImGui.BeginChild(ctx, "##sc_plan", aw, list_h) then
    local sc = R.sc_scan
    local plan = R.sc_plan
    ImGui.PushTextWrapPos(ctx, 0)
    if sc then
      ImGui.TextColored(ctx, COL.TEXT_DIM, string.format("Reading %s... %d %%", R.sc_src_name or "the track",
        math.floor(100 * ((sc.ti - 1) * #sc.bars + (sc.acc and sc.bi - 1 or 0)) / math.max(1, #sc.tracks * #sc.bars))))
    elseif plan then
      if #plan.steps == 0 then ImGui.TextColored(ctx, COL.ORANGE, "No audible areas found in the source track.") end
      for _, st in ipairs(plan.steps) do ImGui.Text(ctx, st.text) end
      if plan.zone_text then ImGui.Text(ctx, plan.zone_text) end
      if plan.dropped > 0 then
        ImGui.TextColored(ctx, COL.ORANGE, plan.dropped .. " impacts do not fit the full length: they are left out.")
      end
      if #plan.steps > 0 and #plan.steps < P.steps then
        ImGui.TextColored(ctx, COL.ORANGE, "Only " .. #plan.steps .. " areas fit: the songs are short for this length.")
      end
    else
      ImGui.TextColored(ctx, COL.TEXT_DIM, "Choose the source track and click Find areas to see the plan, or Build "
        .. "soundcheck to make it at once.")
    end
    ImGui.PopTextWrapPos(ctx)
    ImGui.Dummy(ctx, 0, 0)
    ImGui.EndChild(ctx)
  end
  -- the footer
  local bw = UI.btn_w("Build soundcheck", 140)
  local has_src = Sc.src_track() ~= nil
  if R.sc_scan then
    if UI.button("Cancel", UI.btn_w("Cancel", 90)) then Sc.cancel() end
    return
  end
  ImGui.BeginDisabled(ctx, not has_src)
  if UI.button("Find areas", UI.btn_w("Find areas", 100), nil, "ghost") then
    local ok, why = Sc.find_begin(false)
    if not ok then UI.notice(why, true) end
  end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, has_src and "Reads the source track and shows the plan. Nothing changes." or "Choose the source track first.")
  end
  ImGui.SameLine(ctx, aw - bw + 10)
  ImGui.BeginDisabled(ctx, not has_src)
  if UI.button("Build soundcheck", bw, nil, "primary") then
    local function go()
      local ok, why = Sc.find_begin(true)
      if not ok then UI.notice(why, true) end
    end
    if Sc.old_region() then
      UI.ask("Replace the Soundcheck? Its track, region and markers are deleted and built again (1 Ctrl+Z brings them back).",
        { "Replace", go })
    else go() end
  end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, has_src and "Reads the source track, then builds the Soundcheck track after the last song. One Ctrl+Z undoes it."
      or "Choose the source track first.")
  end
end

function UI.choose_library()
  local f = Util.browse_folder("SFX Drop library folder", S.library)
  if not f then return end
  f = Util.norm(f)
  if f == Util.norm(S.library) then return end
  S.library = f; Util.mark_sdirty()
  Util.save_settings()
  Lib.load_index()
  Lib.scan_begin(false)
  S.tab = TAB_SOUNDS
  if not S.copy_asked then UI.ask_copy() end
end

function UI.keys()
  if S.tab ~= TAB_SOUNDS or R.ask or ImGui.IsPopupOpen(ctx, "Check the show##check") then return end -- (a window is open)
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter()) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter()) then
    local e = R.sel and Lib.find(R.sel)
    if e then UI.insert(e) end
  end
end

function UI.form_label(label, tip)
  local x0 = ImGui.GetCursorPosX(ctx)
  local wide = ImGui.GetContentRegionAvail(ctx) >= CFG.LABEL_W + 120
  ImGui.PushFont(ctx, bold)
  UI.row_text(label)
  ImGui.PopFont(ctx)
  if tip then UI.tip(tip) end
  if wide then ImGui.SameLine(ctx, 0, 0) end
  ImGui.SetCursorPosX(ctx, wide and (x0 + CFG.LABEL_W) or x0)
end
function UI.form_toggle(label, v, tip)
  UI.form_label(label, tip)
  local ch, nv = UI.toggle("##ft_" .. label, v)
  if tip then UI.tip(tip) end
  return ch, nv
end

-- The Settings tab: Appearance, Library, Insert, Window (collapsing sections, 1 open at a time, as in Session Prep).
function UI.draw_settings()
  UI.vgap(8)
  for i, sec in ipairs(SETTINGS_SECTIONS) do
    ImGui.SetNextItemOpen(ctx, S.settings_open == i)
    local open = ImGui.CollapsingHeader(ctx, sec[1] .. "##settings" .. i)
    if open ~= (S.settings_open == i) then S.settings_open = open and i or 0; Util.mark_sdirty() end
    if open then
      ImGui.Indent(ctx, 8)
      ImGui.PushID(ctx, sec[1])
      sec[2]()
      ImGui.PopID(ctx)
      ImGui.Unindent(ctx, 8)
      UI.vgap(10)
    end
  end
  UI.vgap(12)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "SFX Drop " .. CFG.VERSION .. "  -  MIT license")
end

function UI.draw_settings_appearance()
  local ch
  ch, S.light = UI.form_toggle("Light theme", S.light, "On: light panels and fields, dark text. Off: Dark (the default).")
  if ch then apply_theme(S.light); Util.mark_sdirty() end
end

function UI.draw_settings_library()
  UI.form_label("Library folder", "The folder of your sound effects. SFX Drop reads the sounds in it and in its subfolders.")
  local lib = Util.norm(S.library)
  local bw = UI.btn_w("Change...", 90)
  local tw = math.max(40, ImGui.GetContentRegionAvail(ctx) - bw - CFG.CTRL_GAP - 10)
  UI.row_text(lib == "" and "(none)" or UI.trunc_c(lib, tw), lib == "" and COL.TEXT_DIM or COL.TEXT_MAIN)
  if lib ~= "" then UI.tip(lib) end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Change...", bw) then UI.choose_library() end
  UI.form_label("Sounds", "The number of sounds in the index (Data\\SFX Drop\\library.txt in REAPER's resource folder).")
  UI.row_text(#R.lib .. (#R.lib == 1 and " sound" or " sounds"), COL.TEXT_DIM)
  UI.form_label("Scan")
  ImGui.BeginDisabled(ctx, lib == "" or R.scan ~= nil)
  if UI.button("Rescan", UI.btn_w("Rescan", 90)) then Lib.scan_begin(false) end
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, "Reads the new files of the library and drops the removed ones. Your own hit points stay.")
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Read all again", UI.btn_w("Read all again", 90)) then Lib.scan_begin(true) end
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, "Reads every sound again (after you edited files). Your own hit points stay.")
  end
  ImGui.EndDisabled(ctx)
end

local INSERT_HELP = [[Trim silence: the item starts 3 ms before the sound and ends after its tail.
Fades: short fades at both ends of each item, so it never clicks (the fade-in ends where the sound starts).
Color the FX tracks: the FX folder and each type track get a color when SFX Drop makes them.
FX output: the master or a hardware output pair for the FX folder.
Select the new items: after an insert, only the new items are selected.

Saved on this computer.]]
local FX_OUT_TIP = "Where the FX folder plays: Master (default), or a hardware output pair (for example a separate "
  .. "FX feed to FOH); with a hardware output the folder's master send is off. The list goes up to Out 15/16, also "
  .. "when this computer's audio device has fewer outputs (prepare the show for the stage interface). SFX Drop sets it when it makes the FX "
  .. "folder; Apply sets it on the FX folder of this project now. Saved on this computer."
local LEVELS_HELP = [[Match the level: each new item gets an item gain, so all sounds of a type have the same level.

Per type: Peak (the loudest moment: impacts, drops) or LUFS (the average loudness: risers, atmospheres). SFX Drop measures both in the library scan (its LUFS is a close estimate, without the K filter). The gain stays within +-24 dB.

Saved on this computer.]]
local FILES_HELP = [[Copy into the project: each inserted sound is copied into a folder "SFX Drop" in the project folder, so the project works on any computer (your stage laptop too). Off by default: the items use your library files.

Warn above: SFX Drop asks before a copy that makes the folder larger than this.
Clean up: deletes the copies that no item of the project uses (after you deleted items). A copy that another project file in the same folder names (another version of the song) stays. It asks first. Ctrl+Z cannot bring a deleted file back.

Saved on this computer.]]
-- Clean up: asks, then deletes the unused copies of this project.
function UI.cleanup()
  local list, bytes = Drop.cleanup_list()
  if not list then UI.notice(bytes, true); return end
  if #list == 0 then UI.notice("Nothing to clean up: every file of the SFX Drop folder is in use."); return end
  UI.ask(string.format("Delete %d unused %s (%.1f MB) from the SFX Drop folder of this project?\n\n"
    .. "No item of this project uses them. Ctrl+Z cannot bring a deleted file back, and an older version of the "
    .. "project (or its undo history) may still need them.", #list, #list == 1 and "file" or "files", bytes / CFG.MB),
    { "Delete", function()
      local n = 0
      for _, f in ipairs(list) do if os.remove(f) then n = n + 1 end end
      UI.notice(string.format("Deleted %d %s.", n, n == 1 and "file" or "files"))
    end })
end
function UI.draw_settings_insert()
  local ch
  UI.heading("Items", INSERT_HELP, "s_items")
  ch, S.trim = UI.form_toggle("Trim silence", S.trim,
    "On (default): the item starts 3 ms before the sound and ends 50 ms after its tail. Off: the whole file.")
  if ch then Util.mark_sdirty() end
  ch, S.fades = UI.form_toggle("Fades", S.fades, "On (default): a short fade-in and fade-out on each item, so it never clicks. The fade-in always ends where "
    .. "the sound starts, so it never softens the hit.")
  if ch then Util.mark_sdirty() end
  ImGui.BeginDisabled(ctx, not S.fades)
  UI.form_label("Fade length")
  ImGui.SetNextItemWidth(ctx, 110)
  local chg, v = ImGui.DragInt(ctx, "##fade_ms", S.fade_ms, 0.2, 1, 50, "%d ms")
  if chg then S.fade_ms = Util.clamp(v, 1, 50); Util.mark_sdirty() end
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, "The length of each fade (default 5 ms). Drag, or double-click to type.")
  end
  ImGui.EndDisabled(ctx)
  ch, S.select_item = UI.form_toggle("Select the new items", S.select_item,
    "On (default): after an insert, only the new items are selected (to move or delete them at once).")
  if ch then Util.mark_sdirty() end
  UI.heading("Files", FILES_HELP, "s_files")
  ch, S.copy = UI.form_toggle("Copy into the project", S.copy,
    "On: each inserted sound is copied into a folder \"SFX Drop\" in the project folder (once; the same file is used "
    .. "again). The project works on any computer. Off (default): the items use the library files.")
  if ch then S.copy_asked = true; Util.mark_sdirty() end
  ImGui.BeginDisabled(ctx, not S.copy)
  UI.form_label("Warn above")
  ImGui.SetNextItemWidth(ctx, 110)
  local chw, w = ImGui.DragInt(ctx, "##copy_warn", S.copy_warn, 5, 10, 100000, "%d MB")
  if chw then S.copy_warn = Util.clamp(w, 10, 100000); Util.mark_sdirty() end
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, "Before a copy, SFX Drop asks when the project's SFX Drop folder would grow above this size "
      .. "(default 500 MB). Drag, or double-click to type.")
  end
  ImGui.EndDisabled(ctx)
  UI.form_label("Unused copies")
  if UI.button("Clean up...", UI.btn_w("Clean up...", 90)) then UI.cleanup() end
  UI.tip("Deletes the files of this project's SFX Drop folder that no item of the project uses. It asks first.")
  UI.heading("Tracks", INSERT_HELP, "s_tracks")
  ch, S.color = UI.form_toggle("Color the FX tracks", S.color,
    "On (default): the FX folder and each type track get a color when SFX Drop makes them. Existing tracks keep their color.")
  if ch then Util.mark_sdirty() end
  UI.form_label("FX output", FX_OUT_TIP)
  ImGui.SetNextItemWidth(ctx, 140)
  if ImGui.BeginCombo(ctx, "##fx_out", Drop.output_name(S.fx_out)) then
    local dev = math.floor(r.GetNumAudioOutputs() / 2) -- (the pairs of the audio device now)
    for k = 0, math.max(CFG.OUT_PAIRS, dev, S.fx_out) do
      local label = Drop.output_name(k) .. ((k > dev and k > 0) and "  (not on this device)" or "")
      if ImGui.Selectable(ctx, label, k == S.fx_out) then S.fx_out = k; Util.mark_sdirty() end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip(FX_OUT_TIP)
  local ft = Drop.find_folder()
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, ft == nil)
  if UI.button("Apply to the FX folder", UI.btn_w("Apply to the FX folder")) and ft then
    r.Undo_BeginBlock()
    Drop.apply_output(ft)
    r.Undo_EndBlock("SFX Drop: FX output", -1)
    UI.notice("The FX folder plays through " .. Drop.output_name(S.fx_out) .. ".")
  end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, ft and "Set this output on the FX folder of this project now (its hardware outputs are replaced)."
      or "This project has no FX folder yet: SFX Drop sets the output when it makes it.")
  end
  UI.heading("Levels", LEVELS_HELP, "s_levels")
  ch, S.level_on = UI.form_toggle("Match the level", S.level_on,
    "On: each new item gets an item gain to reach the level of its type. Off (default): the items stay at 0 dB.")
  if ch then Util.mark_sdirty() end
  ImGui.BeginDisabled(ctx, not S.level_on)
  for _, t in ipairs(TYPES) do
    UI.form_label(t.name)
    local mode = S.lvl_mode[t.name] or t.mode
    ImGui.SetNextItemWidth(ctx, 80)
    if ImGui.BeginCombo(ctx, "##lvm_" .. t.name, mode == "peak" and "Peak" or "LUFS") then
      if ImGui.Selectable(ctx, "LUFS", mode == "lufs") then S.lvl_mode[t.name] = "lufs"; Util.mark_sdirty() end
      if ImGui.Selectable(ctx, "Peak", mode == "peak") then S.lvl_mode[t.name] = "peak"; Util.mark_sdirty() end
      ImGui.EndCombo(ctx)
    end
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, "LUFS: the average loudness of the sound. Peak: its loudest moment.")
    end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.SetNextItemWidth(ctx, 110)
    local chg, v = ImGui.DragDouble(ctx, "##lvl_" .. t.name, S.levels[t.name] or t.level, 0.1, -40, 0,
      mode == "peak" and "%.1f dB" or "%.1f LUFS")
    if chg then S.levels[t.name] = Util.clamp(math.floor(v * 10 + 0.5) / 10, -40, 0); Util.mark_sdirty() end
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, string.format("The target of every new %s item (default: %s %d). Drag, or double-click to type.",
        (t.name:lower():gsub("s$", "")), t.mode == "peak" and "Peak" or "LUFS", t.level))
    end
  end
  ImGui.EndDisabled(ctx)
end

function UI.draw_settings_window()
  local docked = R.docked == true
  if UI.form_toggle("Dock in REAPER's docker", docked, "On: SFX Drop is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  UI.form_label("Window position")
  if UI.button("Reset", UI.btn_w("Reset", 90)) then R.reset_win = true end
  UI.tip("Moves the window back to its default size and place, and undocks it.")
end

SETTINGS_SECTIONS = {
  { "Appearance", UI.draw_settings_appearance }, { "Library", UI.draw_settings_library },
  { "Insert", UI.draw_settings_insert }, { "Window", UI.draw_settings_window },
}

-- The Help tab: the topics (1 open at a time).
function UI.draw_help()
  UI.vgap(8)
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
  ImGui.TextColored(ctx, COL.TEXT_DIM, "SFX Drop " .. CFG.VERSION .. "  -  MIT license")
  ImGui.PopTextWrapPos(ctx)
end

-- The window: the tab strip, then the panel of the tab (the sound list scrolls by itself).
function UI.draw_main()
  UI.vgap(CFG.SP_EDGE)
  UI.draw_tabs()
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  local nh = UI.notice_h(aw - 16)
  ah = ah - CFG.SP_EDGE - nh
  local px, py = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + aw, py + ah, COL.PANEL_BG, 8,
    ImGui.DrawFlags_RoundCornersBottom())
  local child_flags = (S.tab == TAB_SOUNDS or S.tab == TAB_SPOTS or S.tab == TAB_SC) and ImGui.WindowFlags_NoScrollbar() or 0
  if ImGui.BeginChild(ctx, "##panel" .. S.tab, aw, ah, 0, child_flags) then
    ImGui.SetCursorPosY(ctx, CFG.SP_PANEL)
    ImGui.Indent(ctx, 10)
    ImGui.PushItemWidth(ctx, ImGui.GetContentRegionAvail(ctx) - 10)
    if S.tab == TAB_SOUNDS then UI.draw_sounds()
    elseif S.tab == TAB_SPOTS then UI.draw_spots()
    elseif S.tab == TAB_SC then UI.draw_sc()
    elseif S.tab == TAB_SETTINGS then UI.draw_settings()
    else UI.draw_help() end
    ImGui.Dummy(ctx, 0, CFG.SP_PANEL)
    ImGui.PopItemWidth(ctx)
    ImGui.Unindent(ctx, 10)
    ImGui.EndChild(ctx)
  end
  local n = R.notice
  if nh > 0 and n then -- the notice, below the panel
    ImGui.SetCursorScreenPos(ctx, px + 8, py + ah + 4)
    ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + aw - 16)
    ImGui.TextColored(ctx, n.warn and COL.ORANGE or COL.TEXT_DIM, n.text)
    ImGui.PopTextWrapPos(ctx)
  end
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
  if R.scan and not R.scan.paused then Lib.scan_step(CFG.SCAN_BUDGET) end
  if R.spot_scan then
    if r.EnumProjects(-1) ~= R.spot_scan.proj then Spots.cancel() else Spots.find_step(CFG.SPOT_BUDGET) end
  end
  if R.spots and r.EnumProjects(-1) ~= R.spot_proj then -- (another project tab: its spots are not these)
    R.spots, R.spot_bars, R.spot_groups = nil, nil, nil
  end
  do -- another project (tab or file): its own Soundcheck list
    local proj, fn = r.EnumProjects(-1)
    if proj ~= R.sc_proj or fn ~= R.sc_fn then R.sc_proj, R.sc_fn = proj, fn; Sc.cancel(); Sc.load() end
  end
  if R.sc_scan then Sc.find_step(CFG.SPOT_BUDGET) end
  Prev.tick()
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
    if id ~= S.dock then S.dock = id; Util.mark_sdirty() end
    -- the window takes the keys while it has the focus: pass Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y on to REAPER
    if ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) and not ImGui.IsAnyItemActive(ctx) then
      local C, SH = ImGui.Mod_Ctrl(), ImGui.Mod_Shift()
      if ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Z()) then r.Main_OnCommand(40029, 0) -- Edit: Undo
      elseif ImGui.IsKeyChordPressed(ctx, C | SH | ImGui.Key_Z()) or ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Y()) then
        r.Main_OnCommand(40030, 0) -- Edit: Redo
      else
        UI.keys()
      end
    end
    UI.draw_main()
    UI.draw_ask()
    UI.draw_check()
    if not R.docked then UI.edges() else R.rs = nil end -- resize edges: floating only
    ImGui.End(ctx)
  end
  UI.pop_style()
  ImGui.PopFont(ctx)
  if R.sdirty and not ImGui.IsMouseDown(ctx, 0) and not ImGui.IsAnyItemActive(ctx) then Util.save_settings() end
  if open then r.defer(loop) end
end

local function on_exit()
  Prev.stop()
  Spots.cancel()
  Sc.cancel()
  if R.sdirty then Util.save_settings() end
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end

-- A second start closes the running SFX Drop (REAPER 7: no question).
if r.set_action_options then r.set_action_options(1) end
do
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end
end
Util.load_settings()
apply_theme(S.light)
Lib.load_index()
if Util.norm(S.library) ~= "" and #R.lib == 0 then Lib.scan_begin(false) end
if Util.norm(S.library) ~= "" and not S.copy_asked then UI.ask_copy() end -- (the library was chosen before the question)
r.atexit(on_exit)
r.defer(loop)
