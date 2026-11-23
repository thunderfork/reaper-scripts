-- @description Tab Viewer: Guitar Pro tabs next to the song
-- @version 1.0
-- @author Nick Gkogkomitros
-- @license MIT
-- @noindex
-- @about
--   Tab Viewer - opens a Guitar Pro tab (.gp, .gpx, .gp5, .gp4, .gp3) in the project and lists its tracks: the guitars,
--   the bass and the drums, with their strings, tunings and capo. The project keeps a copy of the tab in a "Tabs"
--   folder next to the project file.
--   Requires: the free ReaImGui extension (ReaPack).
-- @provides
--   [nomain] Guitar Pro.lua
--   [nomain] Tempo.lua
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

-- The shared files next to this script: the Guitar Pro reader (Guitar Pro.lua) and Tempo and bars (Tempo.lua).
local GP, TP
do
  local dir = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or ""
  if r.file_exists(dir .. "Guitar Pro.lua") then GP = dofile(dir .. "Guitar Pro.lua") end
  if r.file_exists(dir .. "Tempo.lua") then TP = dofile(dir .. "Tempo.lua") end
  if not (GP and TP) then
    r.ShowMessageBox("Tab Viewer needs its files \"Guitar Pro.lua\" and \"Tempo.lua\" next to it. Install Tab Viewer again with ReaPack.", "Tab Viewer", 0)
    return
  end
end

---------------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------------
local CFG = {}
CFG.TITLE = "Tab Viewer"       -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.0"            -- keep equal to @version in the header
CFG.EXT = "Tab Viewer"         -- ExtState section (this computer) and the project data section
CFG.PEXT_KEY = "cfg"           -- the project data key
CFG.TABS_DIR = "Tabs"          -- the folder next to the project file that keeps the copies of the tabs
CFG.DEFAULT_W, CFG.DEFAULT_H = 520, 480
CFG.WIN_EDGE = 6               -- floating window: width of the resize edges (inside the window), as in Chart Cue
CFG.WIN_GRIP = 22              -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 340, 240
CFG.FONT_SIZE = 14             -- the same sizes as Chart Cue
CFG.FONT_SIZE_BOLD = 15        -- section titles
CFG.TEXT_LIFT = 1              -- px the text is raised above the true centre in every control
CFG.CTRL_GAP = 8               -- between 2 controls side by side
CFG.SP_ROW, CFG.SP_EDGE, CFG.SP_PANEL = 7, 8, 4 -- spacing (pixels; the same gaps as Chart Cue)
CFG.ROW_H = 26
CFG.TB_ICON_W = 32             -- the gear and "?" in the toolbar
CFG.SETTINGS_BTN_W = 200       -- the buttons in the Settings menu
CFG.NOTICE_SEC = 4             -- a notice at the bottom of the window shows this long
CFG.TIP_DELAY = 0.5            -- seconds on an item before its tooltip shows (as in Chart Cue)
CFG.TIP_WRAP_EM = 32           -- tooltip lines wrap at this many font sizes
CFG.TRACK_W = 320              -- the Track dropdown
CFG.SRC_W = 200                -- the Beats from dropdown (Tempo and bars)
CFG.TEMPO_LW = 92              -- the labels of Tempo and bars
CFG.UNDO_TRY = "Tab Viewer: try the tempo" -- the undo step of Play with click (taken back before the next one)
-- the tab: the same sizes as Note Detective's
CFG.TAB_SLOT = 12              -- the width of a 16th note
CFG.TAB_PAD = 10               -- the space at the start of a bar
CFG.TAB_LINE = 17              -- between 2 strings
CFG.TAB_TOP, CFG.TAB_BOTTOM = 22, 30 -- above the top string (the bar number) and below the low one (the beats, a gap)
CFG.TAB_CHORDS = 18            -- the row of chord names, under the bar numbers (only when the tab has chords)
CFG.TAB_LEFT = 22              -- the string names at the left
CFG.TAB_STRETCH = 1.6          -- the bars of a line stretch to the full width, at most this much

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

-- The themes (Settings > Look > Light theme): the same palettes as Chart Cue.
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

local Util, Project, Tabs, UI = {}, {}, {}, {}
local Tempo -- Tempo and bars (TP.new, below)

-- R: runtime state (not saved). P: the project data. S: settings of this computer.
local R = {
  proj = nil, projfn = "", state_cc = -1, plast_txt = "", pdirty = false, sdirty = false,
  frames = 0,
  err = nil,         -- why the tab of the project could not be read (a line in the window)
  doc = nil,         -- the opened tab (GP.read)
  rows = nil,        -- the tracks of the Track dropdown: { name, what, tun, tip, label } (Tabs.show; with the tab)
  info = nil,        -- the line below the tab: bars, time signature, tempo
  -- tab: the tab of the chosen track (GP.tab; Tabs.build), with its lines for a width (Tabs.layout); nil: none
  tab_why = nil,     -- the chosen track has no tab: why (a line in its place)
  bar_txt = nil,     -- the text of the bar line (Tabs.relabel)
  tempo_warn = nil,  -- the project's tempo is not the tab's: the yellow line (Tabs.tempo_check)
  tempo = nil,       -- Tempo and bars (the shared Tempo.lua): the found tempo, bar 1, a running Find tempo
  tsrc = nil,        -- the tracks of Beats from (cached until the project changes); tsrc_sel: the chosen track
  tsrc_audio = false, -- Beats from is a track (true) or "The tab (its tempo)" (false, the first choice)
  tempo_shut = nil,  -- Tempo and bars folded after Set tempo (until a click on its heading; S.tempo stays)
  cur = nil,         -- the tab in the window (its index in P.tabs; nil: none)
  docs = {},         -- the tabs read in this project, by full path (cleared at a project switch)
  rgns = nil,        -- the regions of the project: { by = { [guid] = region }, list } (Tabs.regions)
  tab_labels = nil,  -- the Tab dropdown: { txt, sel } per tab (Tabs.relist)
  follow_last = nil, -- the tab at the play or edit cursor in the frame before (0: a region without a tab; Tabs.follow)
}
-- tabs: the tabs of the project, each { file, rgn, track, bar }. file: the tab (relative to the project folder:
-- "Tabs/song.gp"; else a full path); rgn: the GUID of its region (nil: no region, it starts from the song's bar 1);
-- track: the chosen track (nil: the default, Tabs.default_track); bar: the bar where bar 1 of the tab starts,
-- counted from the first bar of its region (nil: 1)
local P = { tabs = {} }
local S = {
  light = false,     -- Light theme (Dark is the default)
  dock = 0,          -- the REAPER docker of the window (0 = floating)
  follow = true,     -- Settings > Tab > Follow playback
  chords = true,     -- Settings > Tab > Chord names
  tempo = true,      -- the Tempo and bars section is open
}

---------------------------------------------------------------------------
-- REAIMGUI (pinned to 0.9.3 with the official compatibility shim)
---------------------------------------------------------------------------
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("Tab Viewer needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end
  else
    r.ShowMessageBox("Tab Viewer needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run Tab Viewer again.", CFG.TITLE, 0)
  end
end
local TESTING = rawget(_G, "TabViewerTest") ~= nil
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

function Util.load_settings()
  local v = r.GetExtState(CFG.EXT, "light")
  if v ~= "" then S.light = (v == "1") end
  v = r.GetExtState(CFG.EXT, "dock")
  if v ~= "" then S.dock = math.floor(tonumber(v) or 0) end
  v = r.GetExtState(CFG.EXT, "follow")
  if v ~= "" then S.follow = (v ~= "0") end
  v = r.GetExtState(CFG.EXT, "chords")
  if v ~= "" then S.chords = (v ~= "0") end
  v = r.GetExtState(CFG.EXT, "tempo")
  if v ~= "" then S.tempo = (v ~= "0") end
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
function Util.save_settings()
  r.SetExtState(CFG.EXT, "light", S.light and "1" or "0", true)
  r.SetExtState(CFG.EXT, "dock", tostring(S.dock), true)
  r.SetExtState(CFG.EXT, "follow", S.follow and "1" or "0", true)
  r.SetExtState(CFG.EXT, "chords", S.chords and "1" or "0", true)
  r.SetExtState(CFG.EXT, "tempo", S.tempo and "1" or "0", true)
  R.sdirty = false
end

-- The whole content of a file (nil: it can not be read); writing one (false: it failed). As in FX Link.
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

---------------------------------------------------------------------------
-- TABS (the tab of the project: open it, keep a copy next to the project, read it)
---------------------------------------------------------------------------
-- A full path ("C:\...", "\\server\...", "/..."), not one relative to the project folder.
function Tabs.absolute(path) return path:match("^%a:[/\\]") ~= nil or path:match("^[/\\]") ~= nil end
-- The folder of the project file (nil: the project is not saved yet). fn: the project file (default: this project).
function Tabs.dir(fn) return (fn or R.projfn):match("^(.*)[/\\]") end
-- The full path of the tab of the project.
function Tabs.full(file)
  if Tabs.absolute(file) then return file end
  local dir = Tabs.dir()
  return dir and (dir .. "/" .. file) or file
end

-- The tab in the window (an entry of P.tabs), or nil.
function Tabs.cur() return P.tabs[R.cur] end

-- The tab e of a saved project goes into its Tabs folder (a tab from elsewhere is copied there; the same name with
-- other content gets " (2)"); e.file is then relative ("Tabs/song.gp"). from: the folder that a relative e.file
-- belongs to (the project folder before a Save as). Returns true when the tab is in the Tabs folder.
function Tabs.keep(e, from)
  local dir = Tabs.dir()
  if not dir then return false end
  local src = Tabs.absolute(e.file) and e.file or (from and (from .. "/" .. e.file))
  local data = src and Util.read_all(src)
  if not data then return false end
  local name = e.file:match("([^/\\]+)$")
  local base, ext = name:match("^(.*)(%.[^.]+)$")
  base, ext = base or name, ext or ""
  r.RecursiveCreateDirectory(dir .. "/" .. CFG.TABS_DIR, 0)
  local k, rel = 1, nil
  while true do
    rel = CFG.TABS_DIR .. "/" .. (k == 1 and name or string.format("%s (%d)%s", base, k, ext))
    local old = Util.read_all(dir .. "/" .. rel)
    if not old then
      if not Util.write_all(dir .. "/" .. rel, data) then return false end
      break
    end
    if old == data then break end -- (already there: the same tab)
    k = k + 1
  end
  if e.file ~= rel then e.file, R.pdirty = rel, true end
  return true
end

-- The regions of the project (R.rgns), again after each change of the project: a tab follows its region by GUID.
function Tabs.regions()
  local by, list, i = {}, {}, 0
  while true do
    local n, rgn, pos, rend, name, num = r.EnumProjectMarkers2(R.proj, i)
    if n == 0 then break end
    if rgn then
      local _, g = r.GetSetProjectInfo_String(R.proj, "MARKER_GUID:" .. i, "", false)
      local x = { guid = g, pos = pos, rend = rend, label = name ~= "" and string.format('Region %d "%s"', num, name) or ("Region " .. num) }
      by[g], list[#list + 1] = x, x
    end
    i = i + 1
  end
  R.rgns = { by = by, list = list }
  Tabs.relist()
end
-- The region of tab e (nil: none, or it was deleted).
function Tabs.region(e) return e and e.rgn and R.rgns and R.rgns.by[e.rgn] end
-- The region at time t (the first one), or nil.
function Tabs.region_at(t)
  for _, g in ipairs(R.rgns and R.rgns.list or {}) do if t >= g.pos and t < g.rend then return g end end
end
-- The tab for time t: the tab of the region there (a region without a tab: nil), outside the regions the tab
-- without a region; nil: none. Second value: the region at t.
function Tabs.at(t)
  local g = Tabs.region_at(t)
  for i, e in ipairs(P.tabs) do
    if (g and e.rgn == g.guid) or (not g and not e.rgn) then return i, g end
  end
  return nil, g
end
-- Every frame: the window shows the tab at time t (the play position, stopped the edit cursor). It changes only when
-- the place there changes (a choice in the Tab dropdown stays until then). A region without a tab: none (the grey
-- line); outside the regions with no tab for the whole project: the last tab stays.
function Tabs.follow(t)
  local i, g = Tabs.at(t)
  local want = i or (g and 0) -- (0: a region without a tab)
  if not want or want == R.follow_last then return end
  R.follow_last = want
  if want ~= R.cur then Tabs.select(want) end
end
-- The texts of the Tab dropdown (made when the tabs or the regions change).
function Tabs.relist()
  local labels = {}
  for i, e in ipairs(P.tabs) do
    local g = Tabs.region(e)
    local txt = e.file:match("([^/\\]+)$") .. " - " .. (g and g.label or e.rgn and "its region is gone" or "no region")
    labels[i] = { txt = txt, sel = txt .. "##tb" .. i }
  end
  R.tab_labels = labels
end
-- The window shows tab i (nil: none). Another tab: Tempo and bars starts again (its tempo was for the tab before).
function Tabs.select(i)
  i = P.tabs[i] and i or nil
  if i ~= R.cur and R.tempo then
    Tempo.cancel(); Tempo.click_back()
    R.tempo = nil
  end
  R.cur = i
  Tabs.load()
end
-- Links the tab in the window to region g (nil: no region); its start bar is the region's first bar again.
function Tabs.set_region(g)
  local e = Tabs.cur()
  if not e then return end
  e.rgn, e.bar, R.pdirty = g and g.guid or nil, nil, true
  Tabs.relist()
  Tabs.relabel()
end
-- Removes the tab in the window from the project (its copy stays in the Tabs folder).
function Tabs.remove()
  if not Tabs.cur() then return end
  table.remove(P.tabs, R.cur)
  R.pdirty, R.cur, R.follow_last = true, nil, nil
  Tabs.relist()
  Tabs.select(Tabs.at(r.GetCursorPositionEx(R.proj)) or 1)
end

-- The lines of the track list (cached with the tab), and the line below it.
function Tabs.rows(doc)
  local rows = {}
  for k, t in ipairs(doc.tracks) do
    local strings = #t.open > 0 and string.format(", %d strings", #t.open) or ""
    local what = t.kind == "bass" and ("Bass" .. strings) or t.kind == "guitar" and ("Guitar" .. strings)
      or t.kind == "drums" and "Drums" or (t.inst ~= "" and t.inst or "Other")
    local tab = t.kind == "bass" or t.kind == "guitar"
    local tun = tab and GP.tuning_text(t.open, t.kind, t.capo) or ""
    local tip = t.name .. "\n" .. what
    if tab then tip = tip .. "\nOpen strings, from the lowest: " .. GP.notes_text(t.open) .. (t.capo > 0 and ("\nCapo: fret " .. t.capo) or "") end
    if not tab and t.kind ~= "drums" then tip = tip .. "\nNot a tab part (no strings and frets)." end
    local detail = tab and (#t.open .. " strings, " .. tun) or what
    local label = t.name .. " - " .. detail
    rows[k] = { name = t.name, what = what, tun = tun, tip = tip, label = label, sel = label .. "##tr" .. k }
  end
  local first, change = doc.mbars[1], false
  for _, mb in ipairs(doc.mbars) do if mb.num ~= first.num or mb.den ~= first.den then change = true; break end end
  local parts = { string.format("%d bars", #doc.mbars), string.format("%d/%d%s", first.num, first.den, change and " (changes)" or "") }
  if doc.tempo then parts[3] = string.format("%g BPM in the file%s", doc.tempo, doc.tempos > 1 and " (changes)" or "") end
  return rows, table.concat(parts, "  ·  ")
end
-- The window shows this tab (nil: none; why: the line in its place).
function Tabs.show(doc, why)
  R.doc, R.err, R.rows, R.info = doc, why, nil, nil
  if doc then R.rows, R.info = Tabs.rows(doc) end
  Tabs.build()
end

-- The track that opens first: the first bass track, else the first guitar, else the 1st track.
function Tabs.default_track(doc)
  for _, kind in ipairs({ "bass", "guitar" }) do
    for k, t in ipairs(doc.tracks) do if t.kind == kind then return k end end
  end
  return 1
end
-- The chosen track of the tab (its index).
function Tabs.track()
  local e = Tabs.cur()
  if e and e.track and R.doc and R.doc.tracks[e.track] then return e.track end
  return R.doc and Tabs.default_track(R.doc) or 1
end
-- The Track dropdown: the tab shows track k (saved in the project when it is not the default).
function Tabs.pick(k)
  local e = Tabs.cur()
  local p = k ~= Tabs.default_track(R.doc) and k or nil
  if e and p ~= e.track then e.track, R.pdirty = p, true end
  Tabs.build()
end
-- The tab of the chosen track (R.tab), or why it has none (R.tab_why).
function Tabs.build()
  R.tab, R.tab_why, R.tempo_warn = nil, nil, nil
  if not R.doc then return end
  local t = R.doc.tracks[Tabs.track()]
  if t.kind == "drums" then R.tab_why = "Drum tracks come in a later version (a drum grid). Pick another track."
  elseif t.kind == "other" then R.tab_why = "This track has no tab (no strings and frets). Pick another track."
  else
    local tab = GP.tab(R.doc, Tabs.track())
    R.tab = tab
    tab.chord_row = S.chords and tab.has_chords
    tab.top = CFG.TAB_TOP + (tab.chord_row and CFG.TAB_CHORDS or 0) -- (above the top string)
    tab.lh = (tab.nstr - 1) * CFG.TAB_LINE + tab.top + CFG.TAB_BOTTOM -- (the height of 1 line of the tab)
    for _, b in ipairs(tab.bars) do -- (the texts drawn every frame: made once)
      for _, nt in ipairs(b.notes) do nt.txt = tostring(nt.fret) end
    end
    Tabs.relabel()
  end
end

-- The bar where bar 1 of the tab starts, counted from the first bar of its region (no region: REAPER's bar numbers).
function Tabs.bar()
  local e = Tabs.cur()
  return e and e.bar or 1
end
-- The first bar of the region of tab e (REAPER's measure, from 0): the first bar line at or after its start; 0 without
-- a region. The tab moves with its region.
function Tabs.base(e)
  local g = Tabs.region(e)
  if not g then return 0 end
  local beats, m = r.TimeMap2_timeToBeats(R.proj, g.pos)
  return beats > 1e-6 and m + 1 or m
end
-- The "<" and ">" of the bar line: bar 1 of the tab starts at bar n (of its region; saved when it is not 1).
function Tabs.set_bar(n)
  local e = Tabs.cur()
  if not e then return end
  local bar = math.max(1, math.floor(n))
  local p = bar ~= 1 and bar or nil
  if p ~= e.bar then e.bar, R.pdirty = p, true end
  Tabs.relabel()
end
-- The bar numbers of the tab (of the song, or of its region: from Tabs.bar) and the text of the bar line, made when
-- the bar or the region changes.
function Tabs.relabel()
  local n = Tabs.bar()
  R.bar_txt = string.format("Bar 1 of the tab = bar %d of the %s", n, Tabs.region(Tabs.cur()) and "region" or "song")
  for bi, b in ipairs(R.tab and R.tab.bars or {}) do b.label = tostring(n + bi - 1) end
  Tabs.tempo_check()
end
-- The yellow warning (R.tempo_warn) when the project's tempo where the tab starts is not the tab's first tempo (more
-- than 0.5 BPM apart): the tab would drift. Again after each change of the project (a new tempo) and of the bar.
function Tabs.tempo_check()
  R.tempo_warn = nil
  if not (R.tab and R.doc and R.doc.tempo and R.proj) then return end
  local q0 = Tabs.start_qn()
  local bpm = 60 / (r.TimeMap2_QNToTime(R.proj, q0 + 1) - r.TimeMap2_QNToTime(R.proj, q0)) -- (quarter notes)
  if math.abs(bpm - R.doc.tempo) > 0.5 then
    R.tempo_warn = string.format("The project's tempo here is %.4g BPM, the tab's %.4g BPM: the tab will not stay on the song. Set the song's tempo first (Tempo and bars, above).", bpm, R.doc.tempo)
  end
end
-- The line of the tab that holds bar bi.
function Tabs.line_of(tab, bi)
  for _, ln in ipairs(tab.lines or {}) do if bi >= ln.first and bi <= ln.last then return ln end end
end

-- The lines of the tab for a width: { { first, last (bars), y } } and the height of all of them (px). Each bar gets
-- x, its 16th width sw and its start pad; the bars of a line stretch to the full width (at most CFG.TAB_STRETCH times).
function Tabs.layout(tab, w)
  local lines, x, y, first = {}, 0, 0, 1
  local lh = tab.lh
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
-- The bar (its index) and the place in it (quarter notes, on a 16th) of a point of the tab (x, y from its top left);
-- nil: not on a bar.
function Tabs.hit(tab, x, y)
  local lh = tab.lh
  for _, ln in ipairs(tab.lines or {}) do
    if y >= ln.y and y < ln.y + lh then
      for bi = ln.first, ln.last do
        local b = tab.bars[bi]
        local bx = CFG.TAB_LEFT + b.x
        if x >= bx and x < bx + b.pad + b.n16 * b.sw then
          return bi, math.min(b.n16 - 1, math.max(0, math.floor((x - bx - b.pad) / b.sw))) / 4
        end
      end
    end
  end
end
-- The tab on the song: bar 1 of the tab starts at bar Tabs.bar() (of its region, else of the song); from there the
-- tab follows the song's beats (its quarter notes: REAPER's tempo map), with the bar lengths of the tab (a 3/4 bar of
-- the tab fits even where REAPER has 4/4). The start in quarter notes of the project:
function Tabs.start_qn()
  return r.TimeMap2_timeToQN(R.proj, r.TimeMap2_beatsToTime(R.proj, 0, Tabs.base(Tabs.cur()) + Tabs.bar() - 1))
end
-- The project time of a place in the tab: bar bi, q quarter notes in.
function Tabs.time_of(bi, q)
  local tab = R.tab
  return r.TimeMap2_QNToTime(R.proj, Tabs.start_qn() + (tab and tab.bars[bi].q0 or 0) + q)
end
-- The place in the tab of a project time: the bar (its index) and the quarter notes into it; nil before or after it.
function Tabs.place_of(t)
  local tab = R.tab
  if not tab then return nil end
  local q = r.TimeMap2_timeToQN(R.proj, t) - Tabs.start_qn()
  local last = tab.bars[#tab.bars]
  if not last or q < 0 or q >= last.q0 + last.len then return nil end
  local lo, hi = 1, #tab.bars -- (the bar: a binary search, the place is asked every frame)
  while lo < hi do
    local mid = (lo + hi + 1) // 2
    if tab.bars[mid].q0 <= q then lo = mid else hi = mid - 1 end
  end
  return lo, q - tab.bars[lo].q0
end

-- Reads the tab in the window (read once per project: R.docs), or why not.
function Tabs.load()
  local e = Tabs.cur()
  if not e then Tabs.show(nil); return end
  local full = Tabs.full(e.file)
  local doc, why = R.docs[full], nil
  if not doc then
    if not r.file_exists(full) then
      Tabs.show(nil, "This tab is missing (" .. full .. "). Open it again.")
      return
    end
    doc, why = GP.read(full)
    R.docs[full] = doc
  end
  Tabs.show(doc, why)
end

-- Opens the tab at path in the project, for the region at the edit cursor (it replaces that region's tab; no region
-- there: the tab without a region). Returns true and whether it was copied, or nil and why (nothing changes).
function Tabs.open(path)
  local doc, why = GP.read(path)
  if not doc then return nil, why end
  local g = Tabs.region_at(r.GetCursorPositionEx(R.proj))
  local e, i = { file = path, rgn = g and g.guid }, #P.tabs + 1
  for k, x in ipairs(P.tabs) do if x.rgn == e.rgn then i = k end end
  P.tabs[i], R.cur, R.pdirty = e, i, true
  local copied = Tabs.keep(e)
  R.docs[Tabs.full(e.file)] = doc
  Tabs.relist()
  Tabs.show(doc)
  return true, copied, g
end

-- The project file changed (the 1st save, Save as): the tabs go with it, into the Tabs folder of the new place (the
-- window keeps showing its tab). old_fn: the project file before.
function Tabs.moved(old_fn)
  for _, e in ipairs(P.tabs) do Tabs.keep(e, Tabs.dir(old_fn)) end
  Tabs.relist()
  if not R.rows then Tabs.load() end
end

---------------------------------------------------------------------------
-- TEMPO (Tempo and bars: the shared Tempo.lua; Tab Viewer adds "The tab (its tempo)" in Beats from)
---------------------------------------------------------------------------
-- The song: the selected audio item, else the longest audio item in the region of the tab (no region: of the
-- project) (item, start, end; or nil and why).
function Tabs.song_item()
  local proj = R.proj
  local function audio(it)
    local tk = it and r.GetActiveTake(it)
    return tk and not r.TakeIsMIDI(tk)
  end
  local g = Tabs.region(Tabs.cur())
  local sel = r.GetSelectedMediaItem(proj, 0)
  local best, bl = audio(sel) and sel or nil, -1
  if not best then
    for i = 0, r.CountMediaItems(proj) - 1 do
      local it = r.GetMediaItem(proj, i)
      local pos, len = r.GetMediaItemInfo_Value(it, "D_POSITION"), r.GetMediaItemInfo_Value(it, "D_LENGTH")
      if audio(it) and len > bl and (not g or (pos < g.rend and pos + len > g.pos)) then best, bl = it, len end
    end
  end
  if not best then
    return nil, g and "Put the song's audio in its region first (or select its item)."
      or "Put the song's audio in the project first (select its item when there are several songs)."
  end
  local pos = r.GetMediaItemInfo_Value(best, "D_POSITION")
  return best, pos, pos + r.GetMediaItemInfo_Value(best, "D_LENGTH")
end
-- The quarter note (from the start of the tab) of the first note of the chosen track (0: no notes).
function Tabs.first_qn()
  for _, b in ipairs(R.tab and R.tab.bars or {}) do
    if b.notes[1] then
      local q = b.notes[1].q
      for _, n in ipairs(b.notes) do q = math.min(q, n.q) end
      return b.q0 + q
    end
  end
  return 0
end
-- Find tempo: from the tab (no listening) or from the chosen track (Beats from).
function Tabs.find_tempo(src)
  if R.tsrc_audio then Tempo.begin(src and src.tr)
  elseif R.doc then Tempo.from_tab(GP.timeline(R.doc), Tabs.first_qn()) end
end
-- The song bar where the tab starts after Set tempo (m: the measure of bar 1, from 0). From the tab: bar 1 is the
-- tab's bar 1. From a track: bar 1 is the first beat with sound, so the tab's empty bars before its first note come
-- before it (at least bar 1). Second value: true when they did not fit.
function Tabs.start_bar(m, from_tab)
  if from_tab then return m + 1, false end
  local empty = 0
  for _, b in ipairs(R.tab and R.tab.bars or {}) do
    if b.notes[1] then break end
    empty = empty + 1
  end
  local n = m + 1 - empty
  return math.max(1, n), n < 1
end
-- Set tempo: the tempo map for good; the tab then starts on the new bar 1 of the song.
function Tabs.set_tempo()
  local from_tab = R.tempo and R.tempo.tab ~= nil
  local m = Tempo.set()
  if not m then return end
  local bar, short = Tabs.start_bar(m, from_tab)
  bar = bar - Tabs.base(Tabs.cur()) -- (counted from the region's first bar)
  short = short or bar < 1
  Tabs.set_bar(bar)
  if short then UI.notice("The tab has more empty bars before its first note than the song has before bar 1: it starts on bar 1. Move it with < and >.", true) end
end

Tempo = TP.new({
  R = R, name = "Tab Viewer", undo_try = CFG.UNDO_TRY,
  notice = function(text, warn) UI.notice(text, warn) end,
  song = function() return Tabs.song_item() end,
  written = function() Tabs.tempo_check() end,
})

---------------------------------------------------------------------------
-- PROJECT (the project data: ProjExtState "Tab Viewer"/"cfg"; nothing saved when there is no tab)
---------------------------------------------------------------------------
-- 1 block per tab: "tab=" starts it, then region=, track=, bar= (each only when set).
function Project.parse(txt)
  local p, e = { tabs = {} }, nil
  for line in (txt or ""):gmatch("[^\n]+") do
    local k, v = line:match("^(%w+)=(.*)$")
    if k == "tab" then e = { file = v }; p.tabs[#p.tabs + 1] = e
    elseif e and k == "region" then e.rgn = v
    elseif e and k == "track" then e.track = math.tointeger(tonumber(v))
    elseif e and k == "bar" then e.bar = math.tointeger(tonumber(v)) end
  end
  return p
end
function Project.serialize(p)
  local out = {}
  for _, e in ipairs(p.tabs) do
    out[#out + 1] = "tab=" .. e.file .. "\n" .. (e.rgn and ("region=" .. e.rgn .. "\n") or "")
      .. (e.track and ("track=" .. e.track .. "\n") or "") .. (e.bar and ("bar=" .. e.bar .. "\n") or "")
  end
  return table.concat(out)
end
function Project.read()
  local n, txt = r.GetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY)
  return (n and n > 0 and txt) or ""
end
function Project.load(txt)
  P = Project.parse(txt)
  R.plast_txt, R.pdirty, R.docs, R.follow_last = txt, false, {}, nil
  Tabs.regions()
  Tabs.select(Tabs.at(r.GetCursorPositionEx(R.proj)) or 1)
end
-- Writes the project data when it changed (an unchanged text does not mark the project modified).
function Project.save()
  R.pdirty = false
  if not (R.proj and r.ValidatePtr2(0, R.proj, "ReaProject*")) then return end
  local txt = Project.serialize(P)
  if txt == R.plast_txt then return end
  r.SetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY, txt)
  r.MarkProjectDirty(R.proj)
  R.plast_txt = txt
end

-- Every frame: another project (a tab, or File > Open in the same tab) loads its own data. The saved text decides:
-- "Save as" keeps it (and the tab goes with the project), another project has another one.
function Project.update()
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if proj ~= R.proj then
    if R.pdirty then Project.save() end
    Tempo.cancel()
    Tempo.click_back() -- (the metronome of a Play with click: as it was before)
    R.tempo, R.tsrc, R.tsrc_sel = nil, nil, nil
    R.proj, R.projfn, R.state_cc = proj, fn, r.GetProjectStateChangeCount(proj)
    Project.load(Project.read())
    return
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc or fn ~= R.projfn then
    local old = R.projfn
    R.state_cc, R.projfn = cc, fn
    local txt = Project.read()
    R.tsrc = nil -- (the tracks of Beats from: again)
    if R.tempo then Tempo.check() end
    if txt ~= R.plast_txt then Project.load(txt) -- (never write the old tab into the next project)
    else
      Tabs.regions() -- (a region may have moved: its tab moves with it)
      if fn ~= old then Tabs.moved(old)
      elseif R.tab then Tabs.relabel() end -- (the region or the tempo may have changed)
    end
  end
end

---------------------------------------------------------------------------
-- TESTS: tests/tabviewer.lua sets TabViewerTest: hand it the modules and do not start the UI
---------------------------------------------------------------------------
if TESTING then
  local test = rawget(_G, "TabViewerTest")
  test.CFG, test.S, test.R, test.Util, test.Project, test.Tabs, test.GP = CFG, S, R, Util, Project, Tabs, GP
  test.TP, test.Tempo = TP, Tempo
  function UI.notice(text, warn) R.notice = { text = text, warn = warn } end
  test.get_P = function() return P end -- (Tabs.cur(): the tab in the window)
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

local HELP_INTRO = "Tab Viewer shows a Guitar Pro tab in your project: pick a track, read its tab, and click to hear "
  .. "the song from there."
local HELP_TOPICS = {
  { title = "Open a tab", text = [[
Got a Guitar Pro tab of the song? Click "Open tab..." and pick the file: .gp (Guitar Pro 7 and 8), .gpx (Guitar Pro 6), .gp5, .gp4 or .gp3 (Guitar Pro 5, 4 and 3).

Several songs in 1 project, each in its own region? Put the edit cursor in a region, then Open tab...: the tab belongs to that region and moves with it. While the song plays, the window shows the tab of the region that plays (stopped: the region at the edit cursor). The Tab dropdown lists the tabs of the project; its Region menu links a tab to another region, and "Remove this tab" takes it out of the project. No region at the edit cursor: the tab is for the whole project.

The Track dropdown has every track of the tab: its name, how many strings it has and its tuning ("Standard", "Drop D", "Eb Standard", or the notes of the open strings), and the capo. Point at a track for its open strings. Tab Viewer starts with the bass (else a guitar), and the project remembers your choice.]] },
  { title = "Reading the tab", text = [[
The lines are the strings, the lowest at the bottom; the numbers on them are the frets. Notes 1 above the other are played together (a chord). The chord names above the tab come from the tab; where it has none, Tab Viewer names the chord from its notes (off: Settings > Tab > Chord names). The repeats of the tab are played out, so the bars follow the song from start to end.

Want to hear a part? Click it: the song plays from there. While it plays, a blue line shows where the song is, and the tab scrolls along (off: Settings > Tab > Follow playback). Stopped, the blue line shows the edit cursor.

Does the tab start later than the song (an intro, a count-in)? Set "Bar 1 of the tab = bar ... of the song" with < and > (hold for faster). The bar numbers above the tab are then the song's. A tab in a region counts the bars from the first bar of its region ("bar ... of the region"). From that bar on, the tab follows the beats of your project, so set the tempo of the song first.

A drum track? Drums come in a later version (a drum grid).]] },
  { title = "Tempo and bars", text = [[
Does the tab drift away from the song? Then REAPER's bars are not on the song yet. Open "Tempo and bars" above the Track dropdown.

Beats from "The tab (its tempo)" (the first choice): click Find tempo. Tab Viewer takes the tempo, the tempo changes and the time signatures of the tab, without listening. It puts bar 1 where the first note of the tab meets the first sound of the song (the selected item, else the longest one in the tab's region).

Beats from a track (best a metronome or the drums): Find tempo listens to it (1/2, x2, Style and Short bars as in Note Detective).

Check bar 1 with Play with click: is the loud click on the "1"? If not, move it with < 1 beat and 1 beat >. Then click Set tempo: the tempo goes into the project (1 undo step), and the tab starts on that bar.]] },
  { title = "Where your stuff is saved", text = [[
In the project: its tabs, the region of each one, the track you picked, and the bar where the tab starts. Tab Viewer copies each tab into a "Tabs" folder next to the project file, so the project keeps its tab when you move or delete the original. Not saved yet? The copy is made when you save the project.

On this computer: the Light theme, Follow playback, Chord names and the window dock.]] },
}

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
-- The cursor of + Add: the play position while playing, else the edit cursor.
function UI.cursor()
  if r.GetPlayStateEx(R.proj) & 1 == 1 then return r.GetPlayPositionEx(R.proj) end
  return r.GetCursorPositionEx(R.proj)
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
-- UI.trunc, kept per text until the width changes (the lines of the list: not cut again every frame).
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

function UI.draw_gear_icon(dl, cx, cy, col)
  for k = 0, 7 do
    local a = k * math.pi / 4
    local c, sn = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * 5, cy + sn * 5, cx + c * 8.5, cy + sn * 8.5, col, 3)
  end
  ImGui.DrawList_AddCircle(dl, cx, cy, 4.5, col, 0, 3)
end

-- Open tab...: a file window, then the tab goes into the project (or a notice says why not).
function UI.open_tab()
  local ok, path = r.GetUserFileNameForRead("", "Open a Guitar Pro tab", "gp")
  if not ok or not path or path == "" then return end
  local done, res, g = Tabs.open(path)
  if not done then UI.notice(res, true); return end
  local where = g and ("Opened for " .. g.label .. ".") or "Opened."
  if res then UI.notice(where .. " A copy is in the project's Tabs folder.")
  elseif not Tabs.dir() then UI.notice(where .. " Save the project: a copy of the tab then goes into its Tabs folder.")
  else UI.notice(where) end
end

function UI.draw_toolbar()
  UI.vgap(CFG.SP_EDGE)
  local x0, y0 = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local IW, H = CFG.TB_ICON_W, ImGui.GetFrameHeight(ctx)
  local bw = UI.btn_w("Open tab...")
  if UI.button("Open tab...", bw, H, "primary") then UI.open_tab() end
  UI.tip("Pick a Guitar Pro tab of the song (.gp, .gpx, .gp5, .gp4, .gp3). It goes to the region at the edit cursor (no region there: the whole project). The project keeps a copy of it.")
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

-- The sections of the Settings menu (tools\docs-check.ps1 reads the names).
local SETTINGS_SECTIONS = {
  { "Look" }, { "Tab" }, { "Window" },
}
-- The Settings menu (the gear button): Look, Tab, Window.
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
  ch, S.follow = UI.toggle_line("Follow playback", S.follow,
    "On (the default): while the song plays, the tab scrolls to the line that plays. Off: you scroll yourself (the blue line still shows where it plays).")
  if ch then R.sdirty = true end
  ch, S.chords = UI.toggle_line("Chord names", S.chords,
    "On (the default): the chord names above the tab, where the chord changes (the tab's own names; else named from its notes).")
  if ch then R.sdirty = true; Tabs.build() end
  head(SETTINGS_SECTIONS[3][1])
  local docked = R.docked == true
  if UI.toggle_line("Dock in REAPER's docker", docked, "On: Tab Viewer is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if UI.button("Reset window position", CFG.SETTINGS_BTN_W) then R.reset_win = true; ImGui.CloseCurrentPopup(ctx) end
  UI.tip("Moves the window back to its default size and place, and undocks it.")
  UI.vgap(8)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Tab Viewer " .. CFG.VERSION .. "  -  MIT license")
  ImGui.EndPopup(ctx)
end

-- The Help window (a popup in the window), in topics as in Segue.
function UI.draw_help()
  if R.help_open then ImGui.OpenPopup(ctx, "Tab Viewer Help##help"); R.help_open = false end
  local vw, vh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowSize(ctx, math.min(520, math.max(260, vw - 40)), math.min(560, math.max(240, vh - 40)),
    ImGui.Cond_Appearing())
  if ImGui.BeginPopupModal(ctx, "Tab Viewer Help##help", true) then
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
      ImGui.TextColored(ctx, COL.TEXT_DIM, "Tab Viewer " .. CFG.VERSION .. "  -  MIT license")
      ImGui.PopTextWrapPos(ctx)
      ImGui.EndChild(ctx)
    end
    UI.vgap(8)
    if UI.button("Close", 90) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

-- The Tab dropdown: the tabs of the project (their region), the region of this tab, Remove this tab.
function UI.draw_tab_list()
  if not P.tabs[1] then return end
  Tabs.follow(r.GetPlayStateEx(R.proj) & 1 == 1 and r.GetPlayPositionEx(R.proj) or r.GetCursorPositionEx(R.proj))
  local e = Tabs.cur()
  UI.label("Tab")
  ImGui.SetNextItemWidth(ctx, math.max(80, math.min(CFG.TRACK_W, (ImGui.GetContentRegionAvail(ctx)))))
  if ImGui.BeginCombo(ctx, "##tablist", e and R.tab_labels[R.cur].txt or "None here") then
    for i, lb in ipairs(R.tab_labels) do
      if ImGui.Selectable(ctx, lb.sel, i == R.cur) then Tabs.select(i) end
    end
    ImGui.Separator(ctx)
    if e and ImGui.BeginMenu(ctx, "Region") then
      local function taken(guid) -- (another tab has it)
        for i, x in ipairs(P.tabs) do if i ~= R.cur and x.rgn == guid then return true end end
      end
      for k, g in ipairs(R.rgns.list) do
        if ImGui.MenuItem(ctx, g.label .. "##rg" .. k, nil, e.rgn == g.guid, not taken(g.guid)) then Tabs.set_region(g) end
      end
      if ImGui.MenuItem(ctx, "No region (the whole project)", nil, e.rgn == nil, not taken(nil)) then Tabs.set_region(nil) end
      ImGui.EndMenu(ctx)
    end
    if e and ImGui.Selectable(ctx, "Remove this tab") then Tabs.remove(); UI.notice("Removed. Its copy stays in the Tabs folder: Open tab... brings it back.") end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The tabs of this project. Each one belongs to a region and moves with it; the window shows the tab where the song plays (stopped: at the edit cursor). Region: link this tab to another region.")
end

-- The Track dropdown, the tab of the chosen track, then the bars, time signature and tempo of the file.
function UI.draw_tracks()
  UI.draw_tab_list()
  if not R.rows then
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, R.err or (P.tabs[1] and "No tab for this region yet. Open tab... (the edit cursor in the region)."
      or "No tab yet. Open a Guitar Pro file (.gp, .gpx, .gp5, .gp4 or .gp3)."))
    ImGui.PopTextWrapPos(ctx)
    return
  end
  UI.draw_tempo()
  local k = Tabs.track()
  UI.label("Track")
  ImGui.SetNextItemWidth(ctx, math.max(80, math.min(CFG.TRACK_W, (ImGui.GetContentRegionAvail(ctx)))))
  if ImGui.BeginCombo(ctx, "##track", R.rows[k].label) then
    for i, row in ipairs(R.rows) do
      if ImGui.Selectable(ctx, row.sel, i == k) then Tabs.pick(i) end
      UI.tip(row.tip)
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip(R.rows[k].tip)
  if R.tab then -- (the bar line: where the tab starts in the song)
    local BW = UI.btn_w("<")
    UI.row_text(R.bar_txt)
    UI.tip("Where the tab starts: the bar of its region (no region: of the song, REAPER's bar numbers) that is bar 1 of the tab. From there the tab follows the song's beats. Wrong bar? Click < or > (hold: faster).")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.BeginDisabled(ctx, Tabs.bar() <= 1)
    if UI.repeat_button("<", BW) then Tabs.set_bar(Tabs.bar() - 1) end
    ImGui.EndDisabled(ctx)
    UI.tip("The tab starts 1 bar earlier.")
    ImGui.SameLine(ctx, 0, 4)
    if UI.repeat_button(">", BW) then Tabs.set_bar(Tabs.bar() + 1) end
    UI.tip("The tab starts 1 bar later.")
    if R.tempo_warn then
      ImGui.PushTextWrapPos(ctx, 0)
      ImGui.TextColored(ctx, COL.YELLOW, R.tempo_warn)
      ImGui.PopTextWrapPos(ctx)
    end
  end
  local _, ah = ImGui.GetContentRegionAvail(ctx)
  UI.draw_tab(math.max(40, ah - ImGui.GetTextLineHeightWithSpacing(ctx)))
  ImGui.TextColored(ctx, COL.TEXT_DIM, R.info)
end

local TAB_SRC = "The tab (its tempo)"
local STYLES = { { "steady", "1 tempo" }, { "follow", "Follow the song" } }
-- Tempo and bars: a section that folds (S.tempo), above Track; as in Note Detective, with "The tab (its tempo)" as
-- the first choice of Beats from (no 1/2, x2, Style or Short bars then: the tab has them).
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
  UI.tip(open and "Fold this section." or "Open: put REAPER's bars on the song, from the tab's tempo or by listening to a track.")
  if tm and tm.lbl_bpm and not open then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    UI.row_text(tm.lbl_bpm, COL.TEXT_DIM)
  end
  if not open then return end
  local x0 = ImGui.GetCursorPosX(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local LW = CFG.TEMPO_LW
  local function label(t)
    UI.label(t)
    ImGui.SetCursorPosX(ctx, x0 + LW)
  end
  local run = tm and tm.run
  -- Beats from, Find tempo (while it runs: the progress in place of the dropdown, and Cancel)
  label("Beats from")
  local src = R.tsrc_audio and Tempo.source() or nil
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
  if ImGui.BeginCombo(ctx, "##tsrc", R.tsrc_audio and (src and src.label or "No tracks with items") or TAB_SRC) then
    if ImGui.Selectable(ctx, TAB_SRC, not R.tsrc_audio) then R.tsrc_audio = false end
    UI.tip("No listening: the tempo, the tempo changes and the time signatures of the tab.")
    for _, e in ipairs(Tempo.sources()) do
      if ImGui.Selectable(ctx, e.label, R.tsrc_audio and e == src) then R.tsrc_audio, R.tsrc_sel = true, e.tr end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Where the beats come from: the tab itself (its tempo), or a track that Find tempo listens to (the metronome (click) track is best, then the drums).")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, R.tsrc_audio and src == nil)
  if UI.button("Find tempo", bw, nil, "primary") then Tabs.find_tempo(src) end
  ImGui.EndDisabled(ctx)
  UI.tip_disabled(R.tsrc_audio and "Listens to this track while the song plays (the selected item, else the longest one). Nothing changes yet."
    or "Takes the tempo of the tab, and puts bar 1 where the tab's first note meets the first sound of the song (the selected item, else the longest one). Nothing changes yet.")
  if not (tm and tm.beats) then
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No tempo yet. Click Find tempo.")
    return
  end
  -- Tempo (from a track: 1/2, x2 and Style too)
  label("Tempo")
  UI.row_text(tm.lbl_bpm)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  UI.row_text(tm.lbl_drift, COL.TEXT_DIM)
  if not tm.tab then
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
    label("Style")
    local cur = STYLES[1][2]
    for _, s in ipairs(STYLES) do if s[1] == tm.style then cur = s[2] end end
    ImGui.SetNextItemWidth(ctx, CFG.SRC_W)
    if ImGui.BeginCombo(ctx, "##tstyle", cur) then
      for _, s in ipairs(STYLES) do
        if ImGui.Selectable(ctx, s[2], s[1] == tm.style) and s[1] ~= tm.style then Tempo.set_style(s[1]) end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("1 tempo: 1 steady grid. Follow the song: a tempo marker on every bar, so the bars stay on the drums. "
      .. "Suggested for this song: " .. (tm.steady and "1 tempo." or "Follow the song."))
  else
    UI.tip("The tempo of the tab at bar 1. Set tempo writes its tempo changes and time signatures too.")
  end
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
  -- Short bars (from a track only): the first one on the label line, "+ Add" at its right end, the others below
  if not tm.tab then
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
  end
  -- Set tempo
  ImGui.SetCursorPosX(ctx, x0 + LW)
  if UI.button("Set tempo", UI.btn_w("Set tempo", 100), nil, "primary") then
    Tabs.set_tempo()
    R.tempo_shut = true -- (done: the section folds for now, so the tab has room; S.tempo stays)
  end
  UI.tip(tm.tab and "Writes the tab's tempo, tempo changes and time signatures into the project from bar 1, and the tab starts on that bar: 1 undo step. The audio stays where it is."
    or "Writes the tempo of this song into the project, and moves its audio a few ms so the first note is on the beat; the tab starts on bar 1: 1 undo step. Other songs keep their places.")
end

-- A button that repeats while it is held (after 0.4 s, every 0.08 s). True at each step.
function UI.repeat_button(label, w)
  local hit = UI.button(label, w)
  local h = R.hold and R.hold.id == label and R.hold or nil
  if ImGui.IsItemActive(ctx) then
    local now = Util.now()
    if not h then h = { id = label, t = now + 0.4 }; R.hold = h end
    if now >= h.t then h.t, h.rep = now + 0.08, true; return true end
    return false
  end
  if h then
    R.hold = nil
    if h.rep then return false end -- (the release after repeats: no extra step)
  end
  return hit
end

-- A text centred on a point (digits have no descent: 1 px lower than the middle of the line height).
function UI.centre(dl, cx, cy, col, txt)
  local tw, th = ImGui.CalcTextSize(ctx, txt)
  ImGui.DrawList_AddText(dl, cx - tw / 2, cy - th / 2 + 1, col, txt)
  return tw, th
end
local BEAT_TXT = {}
for k = 1, 32 do BEAT_TXT[k] = tostring(k) end
-- The tab of the chosen track (only the lines in view are drawn); a click plays the song from there.
function UI.draw_tab(h)
  if not ImGui.BeginChild(ctx, "##tab", 0, h) then return end
  local tab = R.tab
  if not tab then
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, R.tab_why or "")
    ImGui.PopTextWrapPos(ctx)
    ImGui.EndChild(ctx)
    return
  end
  local w = ImGui.GetContentRegionAvail(ctx)
  if tab.w ~= w then tab.lines, tab.h = Tabs.layout(tab, w); tab.w = w end
  local ox, oy = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##tabarea", math.max(1, w), math.max(1, tab.h))
  UI.tip("Click: the song plays from there.")
  if ImGui.IsItemClicked(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)
    local bi, q = Tabs.hit(tab, mx - ox, my - oy)
    if bi then UI.play_from(Tabs.time_of(bi, q)) end
  end
  local dl, fs = ImGui.GetWindowDrawList(ctx), ImGui.GetFontSize(ctx)
  local sy = ImGui.GetScrollY(ctx)
  local lh = tab.lh
  for _, ln in ipairs(tab.lines) do
    if ln.y + lh >= sy and ln.y <= sy + h then
      local y0 = oy + ln.y + tab.top -- (the top string)
      local yb = y0 + (tab.nstr - 1) * CFG.TAB_LINE
      local lb = tab.bars[ln.last]
      local x_end = ox + CFG.TAB_LEFT + lb.x + lb.n16 * lb.sw + lb.pad
      for s = 1, tab.nstr do
        local ys = y0 + (tab.nstr - s) * CFG.TAB_LINE
        UI.centre(dl, ox + CFG.TAB_LEFT / 2 - 2, ys, COL.TEXT_DIM, tab.names[s])
        ImGui.DrawList_AddLine(dl, ox + CFG.TAB_LEFT, ys, x_end, ys, COL.LINE, 1)
      end
      ImGui.DrawList_AddLine(dl, x_end, y0, x_end, yb, COL.TEXT_DIM, 1)
      for bi = ln.first, ln.last do
        local b = tab.bars[bi]
        local bx = ox + CFG.TAB_LEFT + b.x
        ImGui.DrawList_AddLine(dl, bx, y0, bx, yb, COL.TEXT_DIM, 1)
        ImGui.DrawList_AddText(dl, bx + 2, oy + ln.y + 2, COL.TEXT_DIM, b.label)
        if tab.chord_row then -- (the chord names, under the bar numbers, at the 16th where the chord starts)
          for _, c in ipairs(b.chords) do
            ImGui.DrawList_AddText(dl, bx + b.pad + c.q * 4 * b.sw, oy + ln.y + CFG.TAB_TOP - 2, COL.TEXT_BRIGHT, c.name)
          end
        end
        for beat = 0, b.n16 // 4 - 1 do -- (the beats, under the middle of their 16th)
          UI.centre(dl, bx + b.pad + (beat * 4 + 0.5) * b.sw, yb + fs, COL.TEXT_DIM, BEAT_TXT[beat + 1] or "")
        end
        for _, nt in ipairs(b.notes) do -- (a chord: its notes on their strings, 1 above the other)
          local x, y = bx + b.pad + (nt.q * 4 + 0.5) * b.sw, y0 + (tab.nstr - nt.s) * CFG.TAB_LINE
          local tw, th = ImGui.CalcTextSize(ctx, nt.txt)
          ImGui.DrawList_AddRectFilled(dl, x - tw / 2 - 2, y - th / 2, x + tw / 2 + 2, y + th / 2, COL.PANEL_BG)
          UI.centre(dl, x, y, COL.TEXT_MAIN, nt.txt)
        end
      end
    end
  end
  -- the position line, blue: playing at the play position (Follow playback: its line in view); stopped at the edit
  -- cursor
  local playing = r.GetPlayStateEx(R.proj) & 1 == 1
  local pbi, pq = Tabs.place_of(playing and r.GetPlayPositionEx(R.proj) or r.GetCursorPositionEx(R.proj))
  local pln = pbi and Tabs.line_of(tab, pbi)
  if pln then
    local b = tab.bars[pbi]
    local px = ox + CFG.TAB_LEFT + b.x + b.pad + math.min(pq or 0, b.len) * 4 * b.sw
    local y0 = oy + pln.y + tab.top
    local y1 = y0 + (tab.nstr - 1) * CFG.TAB_LINE + 8
    ImGui.DrawList_AddLine(dl, px, y0 - 8, px, y1, COL.ACCENT, 2) -- (blue, playing and stopped: decided 24 November 2026)
    if playing and S.follow and R.tab_line ~= pln.y then
      R.tab_line = pln.y
      ImGui.SetScrollY(ctx, math.max(0, pln.y - CFG.TAB_LINE))
    end
  end
  if not playing then R.tab_line = nil end
  ImGui.EndChild(ctx)
end
-- The song plays from time t (playing: it jumps there).
function UI.play_from(t)
  r.SetEditCurPos2(R.proj, t, true, true)
  if r.GetPlayStateEx(R.proj) & 1 == 0 then r.OnPlayButtonEx(R.proj) end
end

function UI.draw_panel_menu()
  if R.pmenu then ImGui.OpenPopup(ctx, "##panelmenu"); R.pmenu = false end
  if not ImGui.BeginPopup(ctx, "##panelmenu") then return end
  if ImGui.MenuItem(ctx, "Settings...") then R.settings_req = true end
  if ImGui.MenuItem(ctx, "Help") then R.help_open = true end
  ImGui.Separator(ctx)
  local docked = R.docked == true
  if ImGui.MenuItem(ctx, "Dock Tab Viewer in Docker", nil, docked) then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if ImGui.MenuItem(ctx, "Close Tab Viewer") then R.close = true end
  ImGui.EndPopup(ctx)
end

-- The window: the toolbar, then one panel (a rounded area) with the Track dropdown and the tab.
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
      UI.draw_tracks()
      ImGui.EndChild(ctx)
    end
    ImGui.Unindent(ctx, 10)
    if ImGui.IsMouseClicked(ctx, 1) and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows())
      and not ImGui.IsAnyItemHovered(ctx) then R.pmenu = true end
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
    UI.draw_main()
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
  Tempo.cancel()
  Tempo.untry()
  Tempo.click_back()
  if R.pdirty then Project.save() end
  if R.sdirty then Util.save_settings() end
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end

-- A second start closes the running Tab Viewer (REAPER 7: no question).
if r.set_action_options then r.set_action_options(1) end
do
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end
end
Util.load_settings()
apply_theme(S.light)
r.atexit(on_exit)
r.defer(loop)
