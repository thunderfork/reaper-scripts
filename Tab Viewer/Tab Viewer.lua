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
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 400, 340 -- (400: Open tab..., Find tempo, Set tempo and the icons; 340: the rows above the tab and 1 line of a 6-string tab)
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
CFG.LABEL_W = 92              -- the label column (Tab, Track, Start; the Find tempo menu)
CFG.UNDO_TRY = "Tab Viewer: try the tempo" -- the undo step of Play with click (taken back before the next one)
CFG.UNDO_MAX = 100             -- the tab edits that Undo (Ctrl+Z in the window) can take back
CFG.FRETS = 24                 -- the highest fret of an edited note
CFG.TAB_DIGITS = 0.8           -- s: 2 digits typed within this time are 1 fret ("1" "2" = 12), as in Note Detective
-- the tab: the same sizes as Note Detective's
CFG.TAB_SLOT = 12              -- the width of a 16th note (at least; a crowded bar gets more: Tabs.min_slot)
CFG.TAB_GAP = 5                -- the least space between 2 texts on 1 string
CFG.TAB_PAD = 10               -- the space at the start of a bar
CFG.TAB_LINE = 17              -- between 2 strings
CFG.TAB_TOP, CFG.TAB_BOTTOM = 22, 14 -- above the top string (the bar number) and below the low one (a gap)
CFG.TAB_RHYTHM = 30            -- the note lengths under the tab (stems, beams, rests, the "3"; Settings > Tab > Note lengths)
CFG.TAB_STEM = 16              -- the length of a stem
CFG.TAB_CHORDS = 18            -- the row of chord names, under the bar numbers (only when the tab has chords)
CFG.TAB_PM = 14                -- the P.M. row, above the bar numbers (only with palm mutes and Playing marks on)
CFG.TAB_SECTION = 18           -- the row of the section names ("Solo"), at the very top (only when the tab has them)
CFG.TAB_ENDING = 16           -- the row of the endings 1. 2., at the top (only repeats as written, with endings)
CFG.TAB_REPEAT = 10            -- the room of a repeat sign |: or :| in its bar
CFG.TAB_SIG = 14               -- the room of a time signature at the start of its bar
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
  playing = false,   -- the song plays (read once per frame at the start of the loop)
  err = nil,         -- why the tab of the project could not be read (a line in the window)
  doc = nil,         -- the opened tab (GP.read)
  rows = nil,        -- the tracks of the Track dropdown: { name, what, tun, tip, label } (Tabs.show; with the tab)
  info = nil,        -- the grey line under Track: bars, time signature, tempo
  -- tab: the tab of the chosen track (GP.tab; Tabs.build), with its lines for a width (Tabs.layout); nil: none
  tab_why = nil,     -- the chosen track has no tab: why (a line in its place)
  bar_txt = nil,     -- the text of the bar line (Tabs.relabel)
  tempo_warn = nil,  -- the project's tempo is not the tab's: the yellow line (Tabs.tempo_check)
  undo = {}, redo = {}, -- the tab edits to take back / to do again ({ e, tr, wb, list }; this session)
  tsel = nil,        -- the selected note of the tab: { bi, q, s } (stopped only)
  tnum = nil,        -- the digits typed for the selected note ({ txt, t }: "1" "2" = fret 12)
  tlast = nil,       -- the place of the last click on the tab (Tabs.click: a double-click must be on the same place)
  tbox = nil,        -- the open note box ({ txt, focus, new; a new note: bi, q, s }; UI.tab_box)
  tempo = nil,       -- Tempo and bars (the shared Tempo.lua): the found tempo, bar 1, a running Find tempo
  tsrc = nil,        -- the tracks of the Find tempo menu (cached until the project changes); tsrc_sel: the chosen track
  cur = nil,         -- the tab in the window (its index in P.tabs; nil: none)
  docs = {},         -- the tabs read in this project, by full path (cleared at a project switch)
  rgns = nil,        -- the regions of the project: { by = { [guid] = region }, list } (Tabs.regions)
  tab_labels = nil,  -- the Tab dropdown: { txt, sel } per tab (Tabs.relist)
  follow_last = nil, -- the tab at the play or edit cursor in the frame before (0: a region without a tab; Tabs.follow)
}
-- tabs: the tabs of the project, each { file, rgn, track, bar }. file: the tab (relative to the project folder:
-- "Tabs/song.gp"; else a full path); rgn: the GUID of its region (nil: no region, it starts from the song's bar 1);
-- track: the chosen track (nil: the default, Tabs.default_track); bar: the bar where bar 1 of the tab starts,
-- counted from the first bar of its region (nil: 1); lines: your line breaks (the written bars that start a line,
-- Tabs.set_lines; nil: automatic lines)
local P = { tabs = {} }
local S = {
  light = false,     -- Light theme (Dark is the default)
  dock = 0,          -- the REAPER docker of the window (0 = floating)
  follow = true,     -- Settings > Tab > Follow playback
  chords = true,     -- Settings > Tab > Chord names
  marks = true,      -- Settings > Tab > Mark my fixes (the fixed and added notes green)
  pmarks = true,     -- Settings > Tab > Playing marks (h, p, slides, b, ~, PM, harmonics; small and grey)
  lengths = true,    -- Settings > Tab > Note lengths (the rhythm under the tab)
  tremnotes = true,  -- Settings > Tab > Tremolo as notes (each picked note written out; off: slashes above the note)
  written = true,    -- Settings > Tab > Repeats as written (|: :|, 1. 2. as in Guitar Pro; off: played out)
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
-- A place or length read from the project text (6 digits): exact again on the grid of 1/48 quarter note (16ths,
-- 32nds, triplets), so 0.333333 is 1/3 and counts as the same place as a new note there.
function Util.grid(x)
  local g = math.floor(x * 48 + 0.5) / 48
  return math.abs(g - x) < 1e-4 and g or x
end

local ON_OFF = { "light", "follow", "chords", "marks", "pmarks", "lengths", "tremnotes", "written" } -- (the switches of S: "1" / "0")
function Util.load_settings()
  for _, k in ipairs(ON_OFF) do
    local v = r.GetExtState(CFG.EXT, k)
    if v ~= "" then S[k] = (v ~= "0") end
  end
  local v = r.GetExtState(CFG.EXT, "dock")
  if v ~= "" then S.dock = math.floor(tonumber(v) or 0) end
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
function Util.save_settings()
  for _, k in ipairs(ON_OFF) do r.SetExtState(CFG.EXT, k, S[k] and "1" or "0", true) end
  r.SetExtState(CFG.EXT, "dock", tostring(S.dock), true)
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
  if i ~= R.cur then Tabs.loop_off(); Tabs.unselect() end
  R.cur = i
  Tabs.load()
end
-- No selected note or place, no box, no digits typed (another tab, track or project: they were for the one before).
function Tabs.unselect()
  R.tsel, R.tbox, R.tnum, R.tlast = nil, nil, nil, nil
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
  if k ~= Tabs.track() then Tabs.unselect() end
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
    local ce = Tabs.cur()
    Tabs.meters(R.doc, ce and ce.meters) -- (your time signatures: before the bars are made)
    local tab = GP.tab(R.doc, Tabs.track())
    R.tab = tab
    if S.tremnotes then Tabs.tremolo(tab) end
    tab.chord_row = S.chords and tab.has_chords
    tab.top = CFG.TAB_TOP + (tab.chord_row and CFG.TAB_CHORDS or 0) -- (above the top string)
    tab.lh = (tab.nstr - 1) * CFG.TAB_LINE + tab.top + CFG.TAB_BOTTOM -- (the height of 1 line of the tab)
      + (S.lengths and CFG.TAB_RHYTHM or 0)
    local ed = Tabs.edits()
    for _, b in ipairs(tab.bars) do
      local list = ed and ed[b.wb]
      if list then -- (an edited written bar: its notes instead of the file's, at each place it plays; mine: not
        -- in the file at that place, string and fret)
        -- a note at the place and string of a file note keeps its playing marks (a new or moved note: none)
        local file, at = {}, {}
        for _, n in ipairs(b.notes) do
          file[string.format("%.4f/%d/%d", n.q, n.s, n.fret)] = true
          at[string.format("%.4f/%d", n.q, n.s)] = n
        end
        b.notes = {}
        for i, n in ipairs(list) do
          local f = at[string.format("%.4f/%d", n.q, n.s)]
          if f and f.fx and f.fx.dead and f.fret ~= n.fret then f = nil end -- (a dead note with a new fret: a note)
          b.notes[i] = { q = n.q, s = n.s, fret = n.fret, len = n.len, w = n.len,
            mine = not file[string.format("%.4f/%d/%d", n.q, n.s, n.fret)], fx = f and f.fx }
        end
      end
      for _, nt in ipairs(b.notes) do nt.txt = Tabs.note_txt(nt, S.pmarks) end -- (the texts drawn every frame: made once)
    end
    Tabs.link(tab, S.pmarks)
    for _, b in ipairs(tab.bars) do Tabs.rhythm(b) end -- (also when not drawn: the grid of the clicks, Tabs.step)
    tab.pm_row = S.pmarks and tab.pm[1] ~= nil
    local e = Tabs.cur()
    Tabs.view(tab, R.doc.mbars, S.written, e, GP.timeline(R.doc))
    tab.per = e and e.per -- (Layout: bars per line; nil: automatic)
    local head = (tab.pm_row and CFG.TAB_PM or 0) + (tab.end_row and CFG.TAB_ENDING or 0)
      + (tab.sec_row and CFG.TAB_SECTION or 0)
    tab.top, tab.lh = tab.top + head, tab.lh + head
    Tabs.relabel()
  end
end
-- The bars that the window shows (tab.view, in order) and their repeat signs. written (Settings > Tab > Repeats as
-- written, decided 24 November 2026): each written bar once, at its first pass (the later passes draw on it:
-- b.shown), with |: :| (b.rs, b.re), "x3" (b.times) and the endings "1." (b.alt; alt_first / alt_last: the ends of
-- its bracket), tab.end_row; else every bar as it plays. Each bar gets vp: its place in the view (a later pass: the
-- place of its first pass) and drawn = false when it is a later pass. mbars: the master bars of the file (GP).
function Tabs.view(tab, mbars, written, lines, tl)
  tab.view, tab.end_row, tab.starts, tab.joins = {}, false, nil, nil
  local first = {}
  for bi, b in ipairs(tab.bars) do
    if not written then b.shown = bi; tab.view[bi] = bi
    elseif first[b.wb] then b.shown, b.drawn = first[b.wb], false
    else first[b.wb] = bi; b.shown = bi end
  end
  if written then
    for wb = 1, #mbars do if first[wb] then tab.view[#tab.view + 1] = first[wb] end end
  end
  for vp, bi in ipairs(tab.view) do tab.bars[bi].vp = vp end
  for _, b in ipairs(tab.bars) do b.vp = tab.bars[b.shown].vp end
  tab.sec_row = false -- (the section names of the file over their bar: "Solo"; a row at the top when there are any)
  for _, bi in ipairs(tab.view) do
    local b = tab.bars[bi]
    b.section = mbars[b.wb] and mbars[b.wb].section
    if b.section then tab.sec_row = true end
  end
  -- the marks of the score, as in Guitar Pro (24 November 2026): the time signature where it changes (b.sig, the 1st
  -- bar too), the tempo where it changes (b.tempo = { { q, txt "= 120" } }, in the top row: tl = GP.timeline, the
  -- bars as they play), the final double bar on the last bar (b.final; not after a :|)
  local num, den, bpm
  for vp, bi in ipairs(tab.view) do
    local b, mb = tab.bars[bi], mbars[tab.bars[bi].wb] or {}
    b.sig, b.tempo, b.final = nil, nil, nil
    if mb.num and (mb.num ~= num or mb.den ~= den) then b.sig = { tostring(mb.num), tostring(mb.den) } end
    num, den = mb.num, mb.den
    for _, x in ipairs(tl and tl[bi] and tl[bi].tempos or {}) do
      local v = math.floor(x.bpm + 0.5)
      if v ~= bpm then
        b.tempo = b.tempo or {}
        b.tempo[#b.tempo + 1] = { q = x.q, txt = "= " .. v }
        bpm, tab.sec_row = v, true
      end
    end
    if vp == #tab.view then b.final = true end
  end
  if not written then return end
  -- (your line breaks and joins: the written bars -> the places of the view; lines: the tab's entry, e.lines /
  -- e.joins; between them the lines fill automatically)
  for key, set_name in pairs({ lines = "starts", joins = "joins" }) do
    if lines and lines[key] then
      local set = {}
      for _, wb in ipairs(lines[key]) do set[wb] = true end
      tab[set_name] = {}
      for vp, bi in ipairs(tab.view) do if set[tab.bars[bi].wb] then tab[set_name][vp] = true end end
    end
  end
  local prev
  for _, bi in ipairs(tab.view) do
    local b, mb = tab.bars[bi], mbars[tab.bars[bi].wb]
    b.rs, b.re = mb.rstart or nil, mb.rend or nil
    b.times = mb.rend and mb.count > 2 and ("x" .. mb.count) or nil
    if mb.alt then
      local list = {}
      for p = 1, 8 do if mb.alt[p] then list[#list + 1] = p .. "." end end
      b.alt, tab.end_row = table.concat(list, " "), true
      b.alt_first = not (prev and prev.alt == b.alt)
      if prev and prev.alt and prev.alt ~= b.alt then prev.alt_last = true end
    elseif prev and prev.alt then prev.alt_last = true end
    prev = b
  end
  if prev and prev.alt then prev.alt_last = true end
end
-- A line key on bar bi (laid-out tab: tab.lines), as in Guitar Pro; the lines after it fill automatically again
-- (the user, 24 November 2026: Ctrl+Enter packed all the bars into the next line). op "enter" (Ctrl+Enter): a
-- break before the bar after bi; op "&": the first bar of the next line joins the line of bi. lines / joins: your
-- breaks and joins (written bars, nil: none). Returns the new lists (sorted; nil when empty), or false and why.
function Tabs.line_starts(tab, bi, op, lines, joins)
  local b = tab.bars[bi]
  local li = b and b.ln
  if not (li and tab.lines[li]) then return false, "Select a note in the tab first." end
  local vp
  if op == "&" then
    local nxt = tab.lines[li + 1]
    if not nxt then return false, "This is the last line: no bar below to pull up." end
    vp = nxt.first
  else
    if b.vp >= tab.lines[li].last then return false, "This bar ends its line already." end
    vp = b.vp + 1
  end
  local wb = tab.bars[Tabs.vbar(tab, vp)].wb
  -- (a break and a join on 1 bar: the newer one wins)
  local add, drop = lines or {}, joins or {}
  if op == "&" then add, drop = drop, add end
  local function without(list)
    local out = {}
    for _, x in ipairs(list) do if x ~= wb then out[#out + 1] = x end end
    return out
  end
  local a, d = without(add), without(drop)
  a[#a + 1] = wb
  table.sort(a)
  if not d[1] then d = nil end
  if op == "&" then return d, a end
  return a, d
end
-- A line key on bar bi (Tabs.line_starts): your line breaks and joins of the tab in the window, saved in the project
-- (lines=, joins=, as written bars), 1 Undo step. nil, why when it can not.
function Tabs.set_lines(bi, op)
  local tab, e = R.tab, Tabs.cur()
  if not (tab and e and S.written) then return nil, "Line breaks work with Settings > Tab > Repeats as written on." end
  local lines, joins = Tabs.line_starts(tab, bi, op, e.lines, e.joins)
  if lines == false then return nil, joins end
  Tabs.undo_push(Tabs.lines_state(e))
  e.lines, e.joins, R.pdirty = lines, joins, true
  Tabs.build()
  return true
end
-- YOUR TIME SIGNATURES (right-click a bar, decided 24 November 2026): meters = { [written bar] = { num, den } } of a
-- tab (e.meters, saved as meter=). Tabs.meters puts them on the bars of doc (the file's values stay in num0 / den0):
-- the notes stay in their bar and fit it (mb.fit = the new length / the old one; GP.notes, GP.timeline: the tempo
-- times fit, the bar lasts as long as before).
function Tabs.meters(doc, meters)
  for wb, mb in ipairs(doc.mbars) do
    mb.num0, mb.den0 = mb.num0 or mb.num, mb.den0 or mb.den
    local m = meters and meters[wb]
    mb.num, mb.den = m and m[1] or mb.num0, m and m[2] or mb.den0
    mb.fit = m and (mb.num / mb.den) / (mb.num0 / mb.den0) or nil
  end
end
-- The written bars that a new time signature on written bar wb changes: wb, and with following the bars after it up
-- to the next time signature change of the file.
function Tabs.meter_bars(mbars, wb, following)
  local list = { wb }
  if following then
    for k = wb + 1, #mbars do
      local a, p = mbars[k], mbars[k - 1]
      if a.num0 ~= p.num0 or a.den0 ~= p.den0 then break end
      list[#list + 1] = k
    end
  end
  return list
end
-- A new time signature num/den on bar bi of the tab in the window (following: and the bars after it); the file's
-- own: your change goes. 1 Undo step. nil, why when it can not.
function Tabs.set_meter(bi, num, den, following)
  local tab, e, doc = R.tab, Tabs.cur(), R.doc
  local b = tab and tab.bars[bi]
  if not (b and e and doc) then return nil, "Select a bar first." end
  if not (num and den and num >= 1 and num <= 32 and (den == 2 or den == 4 or den == 8 or den == 16)) then
    return nil, "A time signature from 1 to 32 over 2, 4, 8 or 16, please."
  end
  Tabs.undo_push({ e = e, meters = e.meters or false })
  local new = {} -- (a new table: the Undo step keeps the old one)
  for k, m in pairs(e.meters or {}) do new[k] = m end
  for _, wb in ipairs(Tabs.meter_bars(doc.mbars, b.wb, following)) do
    local mb = doc.mbars[wb]
    new[wb] = not (num == mb.num0 and den == mb.den0) and { num, den } or nil
  end
  e.meters, R.pdirty = next(new) and new or nil, true
  Tabs.loop_off(); Tabs.unselect() -- (the bars have other times now: as "<" / ">")
  Tabs.build()
  return true
end
-- The Undo step of the lines of tab entry e (its breaks, joins and Layout).
function Tabs.lines_state(e)
  return { e = e, lines = e.lines or false, joins = e.joins or false, per = e.per or false }
end
-- Tab dropdown > Layout... > OK: per = the bars per line (nil: automatic); reset: your breaks and joins go too.
-- 1 Undo step; false when nothing changes.
function Tabs.set_layout(per, reset)
  local e = Tabs.cur()
  if not e or (e.per == per and not (reset and (e.lines or e.joins))) then return false end
  Tabs.undo_push(Tabs.lines_state(e))
  e.per, R.pdirty = per, true
  if reset then e.lines, e.joins = nil, nil end
  Tabs.build()
  return true
end
-- The pass of the written bar of bar bi that is nearest to the bar pbi that plays (nil: the first pass, bi).
function Tabs.pass_near(tab, bi, pbi)
  if not pbi then return bi end
  local wb, best = tab.bars[bi].wb, bi
  for k, b in ipairs(tab.bars) do
    if b.wb == wb and math.abs(k - pbi) < math.abs(best - pbi) then best = k end
  end
  return best
end

-- Tremolo as notes (Settings > Tab > Tremolo as notes, decided 24 November 2026): each tremolo-picked note (fx.trem:
-- 1 8ths, 2 16ths, 3 32nds; a triplet note: triplet notes, fx.tup) and its held parts become the notes picked, on
-- its string and fret. The 1st keeps a slide in, the last the marks to the next note; all keep P.M., x and <12>.
local KEEP_ALL = { pm = true, dead = true, harm = true }
function Tabs.tremolo(tab)
  for _, b in ipairs(tab.bars) do
    local out, ties = {}, {}
    local function split(src, q, w, fx, first)
      local tup = fx.tup or (Tabs.value(w).trip and 2 / 3) or 1
      local step = 0.5 ^ fx.trem * tup
      local n = math.floor(w / step + 1e-6)
      if n < 2 then return false end
      for k = 0, n - 1 do
        local nfx = {}
        for key, v in pairs(fx) do if KEEP_ALL[key] then nfx[key] = v end end
        if k == 0 and first and fx.slide then nfx.slide = fx.slide & 48 end
        if k == n - 1 then
          nfx.ho, nfx.bend, nfx.vib = fx.ho, fx.bend, fx.vib
          if fx.slide and fx.slide & 15 ~= 0 then nfx.slide = (nfx.slide or 0) | (fx.slide & 15) end
        end
        out[#out + 1] = { q = q + k * step, len = step, w = step, s = src.s, fret = src.fret, fx = next(nfx) and nfx or nil }
      end
      return true
    end
    for _, nt in ipairs(b.notes) do
      if not (nt.fx and nt.fx.trem and split(nt, nt.q, nt.w or nt.len, nt.fx, true)) then out[#out + 1] = nt end
    end
    for _, t in ipairs(b.ties or {}) do
      if not (t.trem and split(t, t.q, t.w or 0.25, t.trem, false)) then ties[#ties + 1] = t end
    end
    table.sort(out, function(a, c) return a.q < c.q - 1e-9 or (math.abs(a.q - c.q) < 1e-9 and a.s < c.s) end)
    b.notes, b.ties = out, b.ties and ties
  end
end

-- The text of a note: its fret; a dead note "x" (always: it is a sound); with the playing marks a harmonic "<12>".
function Tabs.note_txt(nt, marks)
  local fx = nt.fx
  if fx and fx.dead then return "x" end
  if marks and fx and fx.harm then return "<" .. nt.fret .. ">" end
  return tostring(nt.fret)
end

-- NOTE LENGTHS (Settings > Tab > Note lengths): the rhythm under the tab, as Guitar Pro draws it.
-- The note values: { len (quarter notes), base (1 whole, 2 half, 4 quarter ... 32), dot, trip }, the longest first.
local VALUES = {}
for _, base in ipairs({ 1, 2, 4, 8, 16, 32 }) do
  local l = 4 / base
  VALUES[#VALUES + 1] = { len = l, base = base }
  VALUES[#VALUES + 1] = { len = l * 1.5, base = base, dot = true }
  VALUES[#VALUES + 1] = { len = l * 2 / 3, base = base, trip = true }
end
table.sort(VALUES, function(a, b) return a.len > b.len end)
-- The value of a length: the one that fits exactly, else the longest that is shorter (at least a 32nd triplet).
function Tabs.value(len)
  for _, v in ipairs(VALUES) do if math.abs(v.len - len) < 1e-3 then return v end end
  for _, v in ipairs(VALUES) do if v.len < len then return v end end
  return VALUES[#VALUES]
end
-- The value of a rest of len at from: its exact value (dotted only from a beat), else the longest plain value that
-- starts on its own grid (a rest after a 32nd: 32nd, 16th, 8th to the beat).
function Tabs.rest_value(from, len)
  local onbeat = math.abs(from - math.floor(from + 1e-6)) < 1e-6
  for _, v in ipairs(VALUES) do
    if v.len <= len + 1e-6 then
      if math.abs(v.len - len) < 1e-3 and (onbeat or not v.dot) then return v end
      local g = from / v.len
      if not v.dot and not v.trip and math.abs(g - math.floor(g + 0.5)) < 1e-3 then return v end
    end
  end
  return Tabs.value(len)
end
-- The rhythm of 1 bar (after its edits and Tabs.link): b.rh = { { q, len, v (Tabs.value), rest, join (a beam to the
-- next one), flag (an 8th or shorter alone in its beat), t3 (the index of the last of its triplet group: the "3") } };
-- b.fine: a 32nd (or a 16th triplet) in the bar (2 columns per 16th). The notes that start together are 1 event
-- (the shortest written length, cut at the next event); the gaps are rests, split at the beats.
function Tabs.rhythm(b)
  local at, keys = {}, {}
  local function add(q, w)
    local k = math.floor(q * 48 + 0.5)
    if at[k] then at[k].w = math.min(at[k].w, w) else at[k] = { q = q, w = w }; keys[#keys + 1] = k end
  end
  for _, n in ipairs(b.notes) do add(n.q, n.w or n.len or 0.25) end
  for _, t in ipairs(b.ties or {}) do if not t.off then add(t.q, t.w or 0.25) end end
  table.sort(keys)
  local out = {}
  local function rest(from, to)
    while to - from > 1 / 12 - 1e-3 do -- (a shorter gap: no rest; the shortest one is a 32nd triplet)
      local stop = math.floor(from + 1e-6) + 1 -- (a rest ends at the next beat; from a beat: at the last whole beat)
      if math.abs(from - math.floor(from + 1e-6)) < 1e-6 and math.floor(to + 1e-6) > from + 1e-6 then stop = math.floor(to + 1e-6) end
      local v = Tabs.rest_value(from, math.min(stop, to) - from)
      out[#out + 1] = { q = from, len = v.len, v = v, rest = true }
      from = from + v.len
    end
  end
  local pos = 0
  for i, k in ipairs(keys) do
    local e = at[k]
    rest(pos, e.q)
    local len = math.max(0, math.min(e.w, (keys[i + 1] and at[keys[i + 1]].q or b.len) - e.q))
    out[#out + 1] = { q = e.q, len = len, v = Tabs.value(len) }
    pos = math.max(pos, e.q + len)
  end
  rest(pos, b.len)
  local fine = false
  for _, e in ipairs(out) do fine = fine or e.v.base >= 32 or (e.v.base == 16 and e.v.trip == true) end
  local i = 1
  while out[i] do -- (the beams: the 8ths and shorter in 1 beat, no rest between)
    local e = out[i]
    local j = i
    if not e.rest and e.v.base >= 8 then
      local beat = math.floor(e.q + 1e-6)
      while out[j + 1] and not out[j + 1].rest and out[j + 1].v.base >= 8 and math.floor(out[j + 1].q + 1e-6) == beat do
        out[j].join = true
        j = j + 1
      end
      e.flag = j == i or nil
    end
    i = j + 1
  end
  local start, acc, unit -- (the triplets: a group ends at a whole beat (16th triplets: half a beat); mixed values
  -- such as a quarter and an 8th triplet in 1 beat are 1 group)
  for k, e in ipairs(out) do
    if not e.v.trip then start = nil
    else
      if not start then start, acc, unit = k, 0, e.len <= 1 / 6 + 1e-3 and 0.5 or 1 end
      acc = acc + e.len
      local g = acc / unit
      if acc >= unit - 1e-3 and math.abs(g - math.floor(g + 0.5)) < 1e-3 then out[start].t3, start = k, nil end
    end
  end
  b.rh, b.fine = out, fine
end

-- TAB EDITS (only while stopped; the file and its copy never change): the changed written bars of the track in the
-- window, saved in the project (edit=). Each edit replaces the notes of 1 written bar (a repeat changes with it).
-- The edits of the track in the window (nil: none). make: create the table.
function Tabs.edits(make)
  local e = Tabs.cur()
  if not e then return nil end
  local tr = Tabs.track()
  if make then e.edits = e.edits or {}; e.edits[tr] = e.edits[tr] or {} end
  return e.edits and e.edits[tr]
end
local function copy_notes(list)
  local out = {}
  for i, n in ipairs(list) do out[i] = { q = n.q, s = n.s, fret = n.fret, len = n.w or n.len } end -- (len: written)
  return out
end
local function by_place(a, b) return a.q < b.q - 1e-9 or (math.abs(a.q - b.q) < 1e-9 and a.s < b.s) end
-- The links of the tab, after its notes and edits: each note and held part (b.ties, from GP.tab) gets nx / nxb, the
-- next item on its string and its bar (an arc, a slide line). A held part gets its text "(4)", or off: a note is at
-- its place, or the note before it on its string has another fret (a fix). marks: tab.pm = the runs of palm-muted
-- places { b0, q0, b1, q1 } (a place with 1 palm-muted note continues the run; held parts do not end it).
function Tabs.link(tab, marks)
  local last, run = {}, nil
  tab.pm = {}
  local function place(bi, q, pm)
    if not pm then run = nil
    elseif run then run.b1, run.q1 = bi, q
    else run = { b0 = bi, q0 = q, b1 = bi, q1 = q }; tab.pm[#tab.pm + 1] = run end
  end
  for bi, b in ipairs(tab.bars) do
    local items = {}
    for _, nt in ipairs(b.notes) do nt.nx, nt.nxb = nil, nil; items[#items + 1] = nt end
    for _, t in ipairs(b.ties or {}) do
      t.nx, t.nxb, t.off = nil, nil, nil
      if Tabs.note_at(tab, bi, t.q, t.s) then t.off = true else items[#items + 1] = t end
    end
    table.sort(items, by_place)
    local gq, gpm
    for _, it in ipairs(items) do
      local p = last[it.s]
      if it.tie then
        if p and p.fret == it.fret then it.txt = "(" .. it.fret .. ")" else it.off = true end
      end
      if not it.off then
        if p then p.nx, p.nxb = it, bi end
        last[it.s] = it
      end
      if marks and not it.tie then
        if gq and math.abs(it.q - gq) > 1e-9 then place(bi, gq, gpm); gpm = false end
        gq, gpm = it.q, gpm or (it.fx ~= nil and it.fx.pm == true)
      end
    end
    if gq then place(bi, gq, gpm) end
  end
end
-- The note of bar bi at q (its 16th) on string s: its index, or nil.
function Tabs.note_at(tab, bi, q, s)
  for i, nt in ipairs(tab.bars[bi].notes) do
    if nt.s == s and math.abs(nt.q - q) < 1e-3 then return i end
  end
end
-- The grid of the beat at q of bar b (quarter notes): 1/3 (a triplet beat: a note on an 8th triplet place, or with a
-- triplet length), 1/6 (a note on a 16th triplet place, or a 16th triplet), else 1/8 in a bar with 32nds (b.fine),
-- else 1/4.
function Tabs.step(b, q)
  local beat, trip = math.floor(q + 1e-6), nil
  local function look(x)
    local d = x.q - beat
    if d < -1e-6 or d >= 1 - 1e-6 then return end
    local v = Tabs.value(x.w or x.len or 0.25)
    if v.trip and math.abs(v.len - (x.w or x.len or 0.25)) < 1e-3 then
      trip = (trip == 1 / 6 or v.base >= 16) and 1 / 6 or 1 / 3
    elseif math.abs(x.q * 4 - math.floor(x.q * 4 + 0.5)) > 1e-3 then
      local u = x.q * 6
      if math.abs(u - math.floor(u + 0.5)) < 1e-3 then
        trip = (trip == 1 / 6 or math.abs(x.q * 3 - math.floor(x.q * 3 + 0.5)) > 1e-3) and 1 / 6 or 1 / 3
      end
    end
  end
  for _, n in ipairs(b.notes) do look(n) end
  for _, t in ipairs(b.ties or {}) do if not t.off then look(t) end end
  return trip or (b.fine and 0.125 or 0.25)
end
-- The place of the grid (Tabs.step) nearest to q in bar b, inside the bar.
function Tabs.snap(b, q)
  q = math.max(0, math.min(q, b.len - 1e-6))
  local beat = math.floor(q + 1e-6)
  local st = Tabs.step(b, beat)
  local out = beat + math.floor((q - beat) / st + 0.5) * st
  if out > b.len - st + 1e-6 then out = out - st end
  return math.max(0, out)
end
-- A click on the stopped tab at bar bi, q, string s (nil: not on a string). double: ImGui's double-click; last: the
-- place of the click before. Returns the selection ({ bi, q, s } or nil), the box (nil, or the box of the note, or of
-- a new note), the q for the edit cursor, and this place. The box opens only on a double-click on the same place
-- (lessons 24 November 2026: a click, then a click elsewhere, opened it).
function Tabs.click(tab, bi, q, s, double, last)
  local i = s and Tabs.note_at(tab, bi, q, s)
  local nq = i and tab.bars[bi].notes[i].q or q
  local here = { bi = bi, q = math.floor(q * 48 + 0.5), s = s }
  local same = double and last and last.bi == here.bi and last.q == here.q and last.s == here.s
  local sel = i and { bi = bi, q = nq, s = s } or s and { bi = bi, q = q, s = s, empty = true } or nil -- (an empty
  -- place on a string: selected too; a number there adds a note)
  local box
  if same and i then box = { txt = tab.bars[bi].notes[i].txt, focus = true }
  elseif same and s then box = { bi = bi, q = q, s = s, txt = "", focus = true, new = true } end
  return sel, box, nq, here
end
-- The start of a loop to the end of bar bi (Shift+click): from the place sbi / sq (the selected note or the edit
-- cursor); none there, or after bar bi: from the start of bar bi. Returns the bar and the quarter notes into it.
function Tabs.loop_start(bi, sbi, sq)
  if not sbi or sbi > bi then return bi, 0 end
  return sbi, sq or 0
end
-- Shift+click on bar bi: a loop (REAPER's time selection and repeat) from the selected note or the edit cursor to the
-- end of bar bi; the same bar again: the loop ends (decided 24 November 2026).
function Tabs.loop(bi)
  local tab = R.tab
  if not (tab and tab.bars[bi]) then return end
  if R.loop and R.loop.bi == bi then Tabs.loop_off(); return end
  local sbi, sq
  local sel = R.tsel
  if sel and tab.bars[sel.bi] then sbi, sq = sel.bi, sel.q else sbi, sq = Tabs.place_of(r.GetCursorPositionEx(R.proj)) end
  sbi, sq = Tabs.loop_start(bi, sbi, sq)
  local old = R.loop or { rep = r.GetSetRepeatEx(R.proj, -1), ts = { r.GetSet_LoopTimeRange2(R.proj, false, true, 0, 0, false) } }
  local t0, t1 = Tabs.time_of(sbi, sq), Tabs.time_of(bi, tab.bars[bi].len)
  R.loop = { bi = bi, sbi = sbi, sq = sq, rep = old.rep, ts = old.ts, t0 = t0, t1 = t1 }
  r.GetSet_LoopTimeRange2(R.proj, true, true, t0, t1, false)
  r.GetSetRepeatEx(R.proj, 1)
end
-- Ends the loop: repeat and the time selection as they were before it (the time selection only when it is still the
-- loop's: a selection that you made meanwhile stays).
function Tabs.loop_off()
  local l = R.loop
  if not l then return end
  R.loop = nil
  if not r.ValidatePtr(R.proj, "ReaProject*") then return end
  r.GetSetRepeatEx(R.proj, l.rep)
  local a, b = r.GetSet_LoopTimeRange2(R.proj, false, true, 0, 0, false)
  if math.abs(a - l.t0) < 1e-6 and math.abs(b - l.t1) < 1e-6 then
    r.GetSet_LoopTimeRange2(R.proj, true, true, l.ts[1], l.ts[2], false)
  end
end
local SPEEDS = { 1, 0.9, 0.75, 0.6, 0.5 }
local SPEED_TXT = { "100%", "90%", "75%", "60%", "50%" }
-- The speed of the song (REAPER's play rate; pitch kept: the preserve pitch option on while slower, as it was at
-- 100%). Tab Viewer sets 100% again when it closes.
function Tabs.speed(rate)
  if rate ~= 1 and not R.pitch_old then
    R.pitch_old = r.GetToggleCommandStateEx(0, 40671) -- Transport: Toggle preserve pitch when changing playrate
    if R.pitch_old == 0 then r.Main_OnCommand(40671, 0) end
  end
  r.CSurf_OnPlayRateChange(rate)
  if rate == 1 and R.pitch_old then
    if R.pitch_old == 0 and r.GetToggleCommandStateEx(0, 40671) == 1 then r.Main_OnCommand(40671, 0) end
    R.pitch_old = nil
  end
end
-- A new Undo step (the Redo list empties; at most CFG.UNDO_MAX steps).
function Tabs.undo_push(u)
  R.redo = {}
  R.undo[#R.undo + 1] = u
  if #R.undo > CFG.UNDO_MAX then table.remove(R.undo, 1) end
end
-- Changes the notes of the written bar of bar bi: fn(list) changes a copy (false: no change). 1 Undo step.
function Tabs.edit(bi, fn)
  local tab = R.tab
  local b = tab and tab.bars[bi]
  if not b then return false end
  local list = copy_notes(b.notes)
  if fn(list) == false then return false end
  table.sort(list, by_place)
  local ed = Tabs.edits(true)
  if not ed then return false end
  Tabs.undo_push({ e = Tabs.cur(), tr = Tabs.track(), wb = b.wb, list = ed[b.wb] })
  ed[b.wb] = list
  R.pdirty = true
  Tabs.build()
  return true
end
-- Undo (dir -1) or Redo (dir 1) of the last tab edit; false when there is none.
function Tabs.undo(dir)
  local from, to = dir < 0 and R.undo or R.redo, dir < 0 and R.redo or R.undo
  local u = table.remove(from)
  if not u then return false end
  if u.meters ~= nil then -- (your time signatures: Tabs.set_meter)
    to[#to + 1] = { e = u.e, meters = u.e.meters or false }
    u.e.meters, R.pdirty = u.meters or nil, true
    if u.e == Tabs.cur() then Tabs.loop_off(); Tabs.unselect(); Tabs.build() end
    return true
  end
  if u.lines ~= nil then -- (the lines of the tab: Tabs.set_lines, Tabs.set_layout)
    to[#to + 1] = Tabs.lines_state(u.e)
    u.e.lines, u.e.joins, u.e.per, R.pdirty = u.lines or nil, u.joins or nil, u.per or nil, true
    if u.e == Tabs.cur() then Tabs.build() end
    return true
  end
  u.e.edits = u.e.edits or {}
  if u.all ~= nil then -- (Undo all fixes: all the fixes of the track at once)
    to[#to + 1] = { e = u.e, tr = u.tr, all = u.e.edits[u.tr] or false }
    u.e.edits[u.tr] = u.all or nil
  else
    u.e.edits[u.tr] = u.e.edits[u.tr] or {}
    local ed = u.e.edits[u.tr]
    to[#to + 1] = { e = u.e, tr = u.tr, wb = u.wb, list = ed[u.wb] }
    ed[u.wb] = u.list
    if not next(ed) then u.e.edits[u.tr] = nil end
  end
  R.pdirty = true
  if u.e == Tabs.cur() and u.tr == Tabs.track() then Tabs.build() end
  return true
end
-- Undo all fixes: the track in the window shows the file's notes again (1 Undo step).
function Tabs.undo_all()
  local e, tr = Tabs.cur(), Tabs.track()
  local ed = Tabs.edits()
  if not (e and ed and next(ed)) then return false end
  Tabs.undo_push({ e = e, tr = tr, all = ed })
  e.edits[tr] = nil
  R.pdirty = true
  Tabs.unselect()
  Tabs.build()
  return true
end
-- Why a fret can not be used (nil: it can, 0 .. CFG.FRETS).
local function bad_fret(fret)
  if not fret or fret < 0 or fret > CFG.FRETS then return string.format("A fret from 0 to %d, please.", CFG.FRETS) end
end
-- A new fret for note i of bar bi (0 .. CFG.FRETS); nil, why when it is not a fret.
function Tabs.set_fret(bi, i, fret)
  local why = bad_fret(fret)
  if why then return nil, why end
  return Tabs.edit(bi, function(list)
    if list[i].fret == fret then return false end
    list[i].fret = fret
  end)
end
-- Note i of bar bi on the next string (dir 1: the next higher one) at the same pitch. nil, why when it can not.
function Tabs.move_string(bi, i, dir)
  local open = R.doc.tracks[Tabs.track()].open
  local nt = R.tab.bars[bi].notes[i]
  local s2 = nt.s + dir
  if not open[s2] then return nil, "There is no string there." end
  local f = nt.fret + open[nt.s] - open[s2]
  if f < 0 or f > CFG.FRETS then return nil, "That note is not on the neck of the next string." end
  if Tabs.note_at(R.tab, bi, nt.q, s2) then return nil, "Another note is on that string there." end
  Tabs.edit(bi, function(list) list[i].s, list[i].fret = s2, f end)
  return true
end
-- A new note in bar bi at q (quarter notes in the bar) on string s, as long as the note before it (Tabs.new_len).
-- nil, why when it can not.
function Tabs.add(bi, q, s, fret)
  local why = bad_fret(fret)
  if why then return nil, why end
  if Tabs.note_at(R.tab, bi, q, s) then return nil, "A note is already there." end
  local len = Tabs.new_len(R.tab.bars[bi], q)
  Tabs.edit(bi, function(list) list[#list + 1] = { q = q, s = s, fret = math.floor(fret), len = len } end)
  return true
end
-- Moves note i of bar bi by dq quarter notes inside its bar (onto the grid there: Tabs.snap), never onto another note
-- of its string. Its new q, or nil, why.
function Tabs.move(bi, i, dq)
  local b = R.tab.bars[bi]
  local nt = b.notes[i]
  if nt.q + dq < -1e-6 or nt.q + dq > b.len - 1e-6 then return nil, "A note stays in its bar." end
  local q = Tabs.snap(b, nt.q + dq)
  if math.abs(q - nt.q) < 1e-6 then return nil, "A note stays in its bar." end
  if Tabs.note_at(R.tab, bi, q, nt.s) then return nil, "Another note is there: a note does not move over another one." end
  Tabs.edit(bi, function(list) list[i].q = q end)
  return q
end
-- The place where the next note (any string, or a held part) starts after q in bar b; the bar end when none.
local function next_start(b, q)
  local e = b.len
  for _, n in ipairs(b.notes) do if n.q > q + 1e-6 and n.q < e then e = n.q end end
  for _, t in ipairs(b.ties or {}) do if not t.off and t.q > q + 1e-6 and t.q < e then e = t.q end end
  return e
end
-- The length of a new note at q in bar b, as in Guitar Pro (decided 24 November 2026): the length of the note before
-- it in the bar (at the same place: a chord note), a 16th without one; in a triplet beat 1 place of its grid; never
-- past the next note or the bar end.
function Tabs.new_len(b, q)
  local st = Tabs.step(b, q)
  if math.abs(st * 6 - math.floor(st * 6 + 0.5)) < 1e-6 then return st end -- (a triplet beat)
  local len, at = 0.25, -1
  for _, n in ipairs(b.notes) do
    if n.q <= q + 1e-6 and n.q > at then at, len = n.q, n.w or n.len or 0.25 end
  end
  return Tabs.value(math.min(len, next_start(b, q) - q)).len
end
-- The length of note i of bar bi and of the notes that start with it (a chord; decided 24 November 2026): op "+"
-- twice as long, "-" half, "." dotted on / off. From a 32nd to a whole note; never past the next note or the bar end.
-- Returns true, or nil and why.
function Tabs.length(bi, i, op)
  local b = R.tab.bars[bi]
  local nt = b.notes[i]
  local v = Tabs.value(nt.w or nt.len or 0.25)
  local len = op == "+" and v.len * 2 or op == "-" and v.len / 2 or (v.dot and v.len / 1.5 or v.len * 1.5)
  if len > 4 + 1e-6 then return nil, "A whole note is the longest." end
  if op == "-" and v.base >= 32 then return nil, "A 32nd note is the shortest." end
  if nt.q + len > next_start(b, nt.q) + 1e-6 then
    return nil, "There is no room for a longer note (the next note or the end of the bar is there)."
  end
  Tabs.edit(bi, function(list)
    for _, n in ipairs(list) do if math.abs(n.q - nt.q) < 1e-6 then n.len = len end end
  end)
  return true
end
-- "/": the beat of note i of bar bi becomes a triplet, as in Guitar Pro: its notes in order on the triplet places
-- (3; 6 when it has more than 3 places), each 1 place long (a triplet 8th; the rest of the beat: a rest). "/" on a
-- triplet beat: its notes in order on the 16ths (at most 4), each to the next note (the last to the beat end).
-- Returns the new q of note i, or nil and why. (lessons 24 November 2026: the notes kept the gaps, so 1 note stayed
-- a quarter: no change, and "/" again did nothing.)
function Tabs.triplet(bi, i)
  local b = R.tab.bars[bi]
  local nt = b.notes[i]
  local beat = math.floor(nt.q + 1e-6)
  if beat + 1 > b.len + 1e-6 then return nil, "This beat is not complete (the bar ends in it)." end
  for _, t in ipairs(b.ties or {}) do
    if not t.off and t.q > beat - 1e-6 and t.q < beat + 1 - 1e-6 then
      return nil, "A held note (4) is in this beat: fix the note before it first."
    end
  end
  local st = Tabs.step(b, beat)
  local trip = math.abs(st * 6 - math.floor(st * 6 + 0.5)) < 1e-6
  local offs, seen = {}, {}
  for _, n in ipairs(b.notes) do
    local d = n.q - beat
    local k = math.floor(d * 48 + 0.5)
    if d > -1e-6 and d < 1 - 1e-6 and not seen[k] then seen[k] = true; offs[#offs + 1] = d end
  end
  table.sort(offs)
  local g = trip and 4 or (#offs <= 3 and 3 or 6)
  if #offs > g then
    return nil, trip and "More than 4 notes in this beat: they do not fit on 16ths." or "More than 6 notes in this beat: too many for a triplet."
  end
  local place = {}
  for k, d in ipairs(offs) do place[math.floor(d * 48 + 0.5)] = k - 1 end -- (in order)
  local nq
  Tabs.edit(bi, function(list)
    for _, n in ipairs(list) do
      local d = n.q - beat
      local u = d > -1e-6 and d < 1 - 1e-6 and place[math.floor(d * 48 + 0.5)]
      if u then
        local was = n.q
        n.q, n.len = beat + u / g, (trip and (u + 1 < #offs and 1 or g - u) or 1) / g
        if math.abs(was - nt.q) < 1e-6 and n.s == nt.s then nq = n.q end
      end
    end
  end)
  return nq
end
-- Deletes note i of bar bi.
function Tabs.delete(bi, i)
  return Tabs.edit(bi, function(list) table.remove(list, i) end)
end
-- The bar shown before (dir -1) or after (dir 1) bar bi, in the order of the view (tab.view: repeats as written, or
-- played out); nil at the ends. Without a view: the next index.
function Tabs.neighbour(tab, bi, dir)
  local b = tab.bars[bi]
  if tab.view and b and b.vp then return tab.view[b.vp + dir] end
  return tab.bars[bi + dir] and bi + dir or nil
end
-- The note before (dir -1) or after (dir 1) note i of bar bi, in the order of the view: bi2, i2 (nil at the ends).
function Tabs.next_note(tab, bi, i, dir)
  local b = tab.bars[bi]
  if b.notes[i + dir] then return bi, i + dir end
  local k = Tabs.neighbour(tab, bi, dir)
  while k do
    local n = #tab.bars[k].notes
    if n > 0 then return k, dir > 0 and 1 or n end
    k = Tabs.neighbour(tab, k, dir)
  end
end
-- The place before (dir -1) or after (dir 1) place q of bar bi: 1 place of the grid there (Tabs.step), into the bar
-- before or after at the bar ends: bi2, q2 (nil at the ends of the tab).
function Tabs.next_place(tab, bi, q, dir)
  local b = tab.bars[bi]
  local q2 = q + dir * Tabs.step(b, dir > 0 and q or math.max(0, q - 1e-3))
  if q2 > -1e-6 and q2 < b.len - 1e-6 then return bi, Tabs.snap(b, q2) end
  local k = Tabs.neighbour(tab, bi, dir)
  if not k then return nil end
  local b2 = tab.bars[k]
  return k, dir > 0 and 0 or Tabs.snap(b2, b2.len - Tabs.step(b2, b2.len - 1e-3))
end
-- The string at y (from the top of the tab), on the line ln: 1 = the lowest; nil between 2 lines.
function Tabs.string_at(tab, ln, y)
  local s = tab.nstr - math.floor((y - ln.y - tab.top) / CFG.TAB_LINE + 0.5)
  if s >= 1 and s <= tab.nstr then return s end
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
  if p ~= e.bar then e.bar, R.pdirty = p, true end -- (the loop moves with its bars: Tabs.relabel)
  Tabs.relabel()
end
-- The bar numbers of the tab (of the song, or of its region: from Tabs.bar) and the text of the bar line, made when
-- the bar or the region changes.
function Tabs.relabel()
  local n = Tabs.bar()
  R.bar_txt = string.format("Bar %d of the %s", n, Tabs.region(Tabs.cur()) and "region" or "song")
  for bi, b in ipairs(R.tab and R.tab.bars or {}) do -- (repeats as written: the written number, as Guitar Pro)
    b.label = tostring(S.written and b.wb or n + bi - 1)
  end
  Tabs.tempo_check()
  Tabs.loop_sync()
end
-- The loop stays on its bars (another start bar, region or tempo): REAPER's time selection moves with them while it
-- is still the loop's; a time selection that you made meanwhile ends the loop (yours stays).
function Tabs.loop_sync()
  local l, tab = R.loop, R.tab
  if not (l and tab and tab.bars[l.bi] and tab.bars[l.sbi]) then return end
  local t0, t1 = Tabs.time_of(l.sbi, l.sq), Tabs.time_of(l.bi, tab.bars[l.bi].len)
  if math.abs(t0 - l.t0) < 1e-6 and math.abs(t1 - l.t1) < 1e-6 then return end
  local a, b = r.GetSet_LoopTimeRange2(R.proj, false, true, 0, 0, false)
  if math.abs(a - l.t0) < 1e-6 and math.abs(b - l.t1) < 1e-6 then
    r.GetSet_LoopTimeRange2(R.proj, true, true, t0, t1, false)
    l.t0, l.t1 = t0, t1
  else
    Tabs.loop_off()
  end
end
-- The yellow warning (R.tempo_warn) when the project's tempo where the tab starts is not the tab's first tempo (more
-- than 0.5 BPM apart): the tab would drift. Again after each change of the project (a new tempo) and of the bar.
function Tabs.tempo_check()
  R.tempo_warn = nil
  if not (R.tab and R.doc and R.doc.tempo and R.proj) then return end
  local q0 = Tabs.start_qn()
  local bpm = 60 / (r.TimeMap2_QNToTime(R.proj, q0 + 1) - r.TimeMap2_QNToTime(R.proj, q0)) -- (quarter notes)
  if math.abs(bpm - R.doc.tempo) > 0.5 then
    R.tempo_warn = string.format("The project's tempo here is %.4g BPM, the tab's %.4g BPM: the tab will not stay on the song. Set the song's tempo first (Find tempo, at the top).", bpm, R.doc.tempo)
  end
end
-- The line of the tab that holds bar bi.
function Tabs.line_of(tab, bi)
  local b = tab.bars[bi]
  return b and b.ln and tab.lines and tab.lines[b.ln] -- (b.ln: from Tabs.layout; asked every frame)
end

-- The smallest 16th width of bar b so that the texts on 1 string do not touch (the checkup screenshot, 24 November
-- 2026: "0(0)) 0" in a bar of 16ths). width(it): the px of an item's text; a slide or a bend mark needs room after it.
function Tabs.min_slot(b, width)
  local by, need = {}, 0
  local function add(it) local s = by[it.s]; if not s then s = {}; by[it.s] = s end; s[#s + 1] = it end
  for _, n in ipairs(b.notes) do add(n) end
  for _, t in ipairs(b.ties or {}) do if not t.off then add(t) end end
  for _, list in pairs(by) do
    table.sort(list, function(a, c) return a.q < c.q end)
    for k = 2, #list do
      local a, c = list[k - 1], list[k]
      local d = (c.q - a.q) * 4 -- (16ths between them)
      local fx = S.pmarks and a.fx
      local gap = CFG.TAB_GAP + ((fx and (fx.bend or (fx.slide or 0) & 12 ~= 0)) and 10 or 0)
      if d > 1e-6 then need = math.max(need, ((width(a) + width(c)) / 2 + gap) / d) end
    end
  end
  return need
end
-- The x of place q in bar b (the middle of its 16th) and the right end of bar b, from the left of the strings.
function Tabs.x_of(b, q) return b.x + b.pad + (q * 4 + 0.5) * b.sw end
function Tabs.x_end(b) return b.x + b.pad + b.n16 * b.sw + (b.tail or 0) end
-- The room at the start of bar b for its signs: a repeat |: and a time signature.
function Tabs.head_w(b) return (b.rs and CFG.TAB_REPEAT or 0) + (b.sig and CFG.TAB_SIG or 0) end
-- The bar shown at place k of the view (tab.view: the bars drawn, in order; without a view: bar k).
function Tabs.vbar(tab, k) return tab.view and tab.view[k] or k end
-- The lines of the tab for a width: { { first, last (places in the view), y } } and the height of all of them (px).
-- Each bar shown gets x, its 16th width sw, its start pad and ln (its line); the bars of a line stretch to the full
-- width (the last line: at most CFG.TAB_STRETCH times). tab.starts / tab.joins (your breaks and "&" joins: places of
-- the view): a line starts at a break, and else where a bar does not fit (not before a joined bar; a joined line too
-- wide shrinks). width (optional): the px of an item's text; a bar gets wider where its texts
-- need it (Tabs.min_slot; b.slot).
function Tabs.layout(tab, w, width)
  local lines, x, xs, y, first = {}, 0, 0, 0, 1
  local lh = tab.lh
  local n = tab.view and #tab.view or #tab.bars
  local starts, joins = tab.starts, tab.joins
  local function close(last)
    -- (each line fills the width exactly, wider or narrower, as Guitar Pro; only the 16ths and the pads stretch, the
    -- repeat signs and time signatures keep their room (xs: the part that stretches). The last line of the tab
    -- stretches at most CFG.TAB_STRETCH times; the user, 24 November 2026: lines too short, ends cut off)
    local f = (w - CFG.TAB_LEFT - 1 - (x - xs)) / math.max(1, xs)
    if last == n then f = math.min(CFG.TAB_STRETCH, f) end
    f = math.max(0.1, f)
    local bx = 0
    lines[#lines + 1] = { first = first, last = last, y = y }
    for k = first, last do
      local b = tab.bars[Tabs.vbar(tab, k)]
      -- (a repeat sign takes room: at the start of the bar, b.rs, and at its end, b.tail)
      b.x, b.sw, b.pad, b.ln = bx, b.slot * f, CFG.TAB_PAD * f + Tabs.head_w(b), #lines
      b.tail = (b.re or b.final) and CFG.TAB_REPEAT or nil -- (:| or the final double bar)
      bx = Tabs.x_end(b)
    end
  end
  for i = 1, n do
    local b = tab.bars[Tabs.vbar(tab, i)]
    -- (a 32nd: 2 columns per 16th; a bar with crowded texts: as wide as they need)
    -- (b.slot: once per build; the texts do not change with the window width)
    b.slot = b.slot or math.max(CFG.TAB_SLOT * (b.fine and 2 or 1), width and Tabs.min_slot(b, width) or 0)
    local bs = b.n16 * b.slot + CFG.TAB_PAD
    local bw = bs + Tabs.head_w(b) + ((b.re or b.final) and CFG.TAB_REPEAT or 0)
    -- (a new line: at your break, or where the bar does not fit (Layout: a fixed count, tab.per: after that many
    -- bars), unless you joined it to the line, "&")
    local full = tab.per and i - first >= tab.per or not tab.per and CFG.TAB_LEFT + x + bw > w
    if x > 0 and (starts and starts[i] or not (joins and joins[i]) and full) then
      close(i - 1)
      y, x, xs, first = y + lh, 0, 0, i
    end
    x, xs = x + bw, xs + bs
  end
  if n > 0 then close(n); y = y + lh end
  return lines, y
end
-- The chord names of a laid-out tab: each one centred over its chord (c.x, from the left of the strings), pushed right
-- past the name before it, and cut (c.txt, by fit(name, max_w)) so it ends before the next chord. width(t) = px.
function Tabs.place_chords(tab, width, fit)
  for _, ln in ipairs(tab.lines) do
    local list = {}
    for k = ln.first, ln.last do
      local b = tab.bars[Tabs.vbar(tab, k)]
      for _, c in ipairs(b.chords or {}) do list[#list + 1] = { c = c, mid = Tabs.x_of(b, c.q) } end
    end
    local lb = tab.bars[Tabs.vbar(tab, ln.last)]
    local prev = -math.huge
    for i, e in ipairs(list) do
      local tw = width(e.c.name)
      local x = math.max(0, e.mid - tw / 2, prev + 6)
      local nxt = list[i + 1]
      local limit = nxt and nxt.mid - 4 or Tabs.x_end(lb)
      e.c.txt = x + tw > limit and fit(e.c.name, math.max(0, limit - x)) or e.c.name
      e.c.x = x
      prev = x + width(e.c.txt)
    end
  end
end
-- The bar (its index) and the place in it (quarter notes, on a 16th) of a point of the tab (x, y from its top left);
-- nil: not on a bar. Third value: the string there (1 = the lowest; nil: not near a string).
function Tabs.hit(tab, x, y)
  local lh = tab.lh
  for _, ln in ipairs(tab.lines or {}) do
    if y >= ln.y and y < ln.y + lh then
      for k = ln.first, ln.last do
        local bi = Tabs.vbar(tab, k)
        local b = tab.bars[bi]
        local bx = CFG.TAB_LEFT + b.x
        if x >= bx and x < CFG.TAB_LEFT + Tabs.x_end(b) then
          return bi, Tabs.snap(b, ((x - bx - b.pad) / b.sw - 0.5) / 4), Tabs.string_at(tab, ln, y)
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
-- TEMPO (Find tempo: the shared Tempo.lua; Tab Viewer adds "From tab" to its menu)
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
-- Find tempo: from the tab (src nil: no listening) or from a track of the Find tempo menu (src: its entry).
function Tabs.find_tempo(src)
  if src then Tempo.begin(src.tr)
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
  local m = Tempo.set() -- (the loop moves with its bars: Tabs.set_bar, Tabs.relabel)
  if not m then return end
  local bar, short = Tabs.start_bar(m, from_tab)
  bar = bar - Tabs.base(Tabs.cur()) -- (counted from the region's first bar)
  short = short or bar < 1
  Tabs.set_bar(bar)
  R.tempo = nil -- (set: Set tempo goes away; the notice says what was written)
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
-- 1 block per tab: "tab=" starts it, then region=, track=, bar=, lines= (your line breaks: the written bars that start
-- a line, "lines=5 9 14"), joins= (the written bars kept on the line before: "&"), layout= (bars per line; each only
-- when set), meter= (1 line per written bar with your time signature: "meter=12 6/8"), then edit= (1 line per edited
-- written bar of a track: "edit=<track> <bar> <q>/<string>/<fret>/<len> ..."; no notes: the bar is empty).
function Project.parse(txt)
  local p, e = { tabs = {} }, nil
  for line in (txt or ""):gmatch("[^\n]+") do
    local k, v = line:match("^(%w+)=(.*)$")
    if k == "tab" then e = { file = v }; p.tabs[#p.tabs + 1] = e
    elseif e and k == "region" then e.rgn = v
    elseif e and k == "track" then e.track = math.tointeger(tonumber(v))
    elseif e and k == "bar" then e.bar = math.tointeger(tonumber(v))
    elseif e and k == "layout" then e.per = math.tointeger(tonumber(v)) -- (bars per line; none: automatic)
    elseif e and k == "meter" then -- (your time signature of a written bar: "meter=12 6/8")
      local wb, num, den = v:match("^(%d+) (%d+)/(%d+)$")
      if wb then e.meters = e.meters or {}; e.meters[tonumber(wb)] = { tonumber(num), tonumber(den) } end
    elseif e and (k == "lines" or k == "joins") then -- (your line breaks: the written bars that start a line; joins:
      -- the written bars that stay on the line of the bar before)
      local list = {}
      for n in v:gmatch("%d+") do list[#list + 1] = tonumber(n) end
      e[k] = list
    elseif e and k == "edit" then
      local tr, wb, rest = v:match("^(%d+) (%d+)(.*)$")
      if tr then
        local list = {}
        for q, s, f, len in rest:gmatch("([%d%.]+)/(%d+)/(%d+)/([%d%.]+)") do
          list[#list + 1] = { q = Util.grid(tonumber(q)), s = tonumber(s), fret = tonumber(f), len = Util.grid(tonumber(len)) }
        end
        e.edits = e.edits or {}
        e.edits[tonumber(tr)] = e.edits[tonumber(tr)] or {}
        e.edits[tonumber(tr)][tonumber(wb)] = list
      end
    end
  end
  return p
end
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end
function Project.serialize(p)
  local out = {}
  for _, e in ipairs(p.tabs) do
    out[#out + 1] = "tab=" .. e.file .. "\n" .. (e.rgn and ("region=" .. e.rgn .. "\n") or "")
      .. (e.track and ("track=" .. e.track .. "\n") or "") .. (e.bar and ("bar=" .. e.bar .. "\n") or "")
      .. (e.lines and ("lines=" .. table.concat(e.lines, " ") .. "\n") or "")
      .. (e.joins and ("joins=" .. table.concat(e.joins, " ") .. "\n") or "")
      .. (e.per and ("layout=" .. e.per .. "\n") or "")
    for _, wb in ipairs(sorted_keys(e.meters or {})) do
      out[#out + 1] = "meter=" .. wb .. " " .. e.meters[wb][1] .. "/" .. e.meters[wb][2] .. "\n"
    end
    for _, tr in ipairs(sorted_keys(e.edits or {})) do
      for _, wb in ipairs(sorted_keys(e.edits[tr])) do
        local parts = { "edit=" .. tr .. " " .. wb }
        for _, n in ipairs(e.edits[tr][wb]) do
          parts[#parts + 1] = string.format("%.6g/%d/%d/%.6g", n.q, n.s, n.fret, n.len)
        end
        out[#out + 1] = table.concat(parts, " ") .. "\n"
      end
    end
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
  R.undo, R.redo, R.loop = {}, {}, nil
  Tabs.unselect()
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
  R.state_cc = r.GetProjectStateChangeCount(R.proj) -- (its own save: no reload of the project in the next frame)
end

-- Every frame: another project (a tab, or File > Open in the same tab) loads its own data. The saved text decides:
-- "Save as" keeps it (and the tab goes with the project), another project has another one.
function Project.update()
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if proj ~= R.proj then
    if R.pdirty then Project.save() end
    Tabs.loop_off() -- (in the project of the loop, before R.proj changes)
    Tempo.cancel()
    Tempo.click_back() -- (the metronome of a Play with click: as it was before)
    R.tempo, R.tsrc, R.tsrc_sel = nil, nil, nil
    R.proj, R.projfn, R.state_cc = proj, fn, r.GetProjectStateChangeCount(proj)
    Project.load(Project.read())
    local rate = r.Master_GetPlayRate(proj) -- (a project saved slow, or left so after a crash: say it)
    if math.abs(rate - 1) > 1e-3 then
      UI.notice(string.format("The song plays at %d%% (REAPER's play rate). The speed dropdown on the Start row sets 100%% again.",
        math.floor(rate * 100 + 0.5)), true)
    end
    return
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc or fn ~= R.projfn then
    local old = R.projfn
    R.state_cc, R.projfn = cc, fn
    local txt = Project.read()
    R.tsrc = nil -- (the tracks of the Find tempo menu: again)
    Tempo.check()
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
local small_font = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE - 3) -- (the playing marks of the tab)
ImGui.Attach(ctx, font); ImGui.Attach(ctx, bold); ImGui.Attach(ctx, head_font); ImGui.Attach(ctx, small_font)

local HELP_INTRO = "Tab Viewer shows a Guitar Pro tab in your project: pick a track, read its tab, and click to hear "
  .. "the song from there."
local HELP_TOPICS = {
  { title = "Open a tab", text = [[
Got a Guitar Pro tab of the song? Click "Open tab..." and pick the file: .gp (Guitar Pro 7 and 8), .gpx (Guitar Pro 6), .gp5, .gp4 or .gp3 (Guitar Pro 5, 4 and 3).

Several songs in 1 project, each in its own region? Put the edit cursor in a region, then Open tab...: the tab belongs to that region and moves with it. While the song plays, the window shows the tab of the region that plays (stopped: the region at the edit cursor). The Tab dropdown lists the tabs of the project; its Region menu links a tab to another region, and "Remove this tab" takes it out of the project. No region at the edit cursor: the tab is for the whole project.

The Track dropdown has every track of the tab: its name, how many strings it has and its tuning ("Standard", "Drop D", "Eb Standard", or the notes of the open strings), and the capo. Point at a track for its open strings. Tab Viewer starts with the bass (else a guitar), and the project remembers your choice.]] },
  { title = "Reading the tab", text = [[
The lines are the strings, the lowest at the bottom; the numbers on them are the frets. Notes 1 above the other are played together (a chord). The chord names above the tab come from the tab; where it has none, Tab Viewer names the chord from its notes (off: Settings > Tab > Chord names). The grey marks show how to play a note, as in Guitar Pro: an arc to the next note is a hammer-on or pull-off, a sloped line a slide, a curved arrow a bend, a wave a vibrato, "P.M. - - -|" a palm mute, <12> a harmonic (off: Settings > Tab > Playing marks). A tremolo-picked note is written out as the notes you pick (off: Settings > Tab > Tremolo as notes; then it gets slashes above it). A note in brackets, (4), is held on from the note before it (an arc joins them). An x is a dead note (muted, no pitch). Under the tab you see how long each note is, as in printed music: stems, joined 8ths and 16ths, dots, rests and the 3 of triplets (off: Settings > Tab > Note lengths). The section names of the tab ("Intro", "Solo") are over their first bar, and the tempo (a quarter note "= 120") where it changes. The time signature (4 over 4) is at the start and where it changes; a double bar ends the song.Repeats look as in Guitar Pro: |: and :| around the bars that repeat, x3 when they play 3 times, and the endings 1. and 2. over the bars of each pass. While the song plays, the blue line jumps back at a repeat. Rather read the bars one after the other, as they play? Turn off Settings > Tab > Repeats as written.

Want to hear a part? Click it: the song plays from there. While it plays, a blue line shows where the song is, and the tab scrolls along (off: Settings > Tab > Follow playback). Stopped, the blue line shows the edit cursor.

Does the tab start later than the song (an intro, a count-in)? Set Start (the bar of the song where bar 1 of the tab plays) with < and > (hold for faster). The bar numbers above the tab are then the song's. A tab in a region counts the bars from the first bar of its region ("bar ... of the region"). From that bar on, the tab follows the beats of your project, so set the tempo of the song first.

Want to practise a hard part? Shift+click a bar: the song loops from the selected note (or the edit cursor) to the end of that bar (a blue band over the bar numbers). Shift+click that bar again, or press Escape, to stop. Too fast? The speed dropdown on the Start row slows the song down (the pitch stays); it goes back to 100% when Tab Viewer closes.

A drum track? Drums come in a later version (a drum grid).]] },
  { title = "Find tempo", text = [[
Does the tab drift away from the song? Then REAPER's bars are not on the song yet. Click Find tempo (next to Open tab...).

From tab (the first choice): Tab Viewer takes the tempo, the tempo changes and the time signatures of the tab, without listening. It puts bar 1 where the first note of the tab meets the first sound of the song (the selected item, else the longest one in the tab's region).

A track (best a metronome or the drums): Find tempo listens to it while the song plays. Then 1/2 and x2 halve or double a tempo that came out wrong, Style is 1 tempo (a steady grid) or Follow the song (a tempo marker on every bar, so the bars stay on the drums), and Short bars adds a bar with only 3 beats (put the edit cursor in it, then + Add).

Got a result? Open Find tempo again and check bar 1 with Play with click: is the loud click on the "1"? If not, move it with < 1 beat and 1 beat >. Then click the blue Set tempo next to it: the tempo goes into the project (1 undo step), and the tab starts on that bar.]] },
  { title = "Fix the tab", text = [[
A wrong note in the tab? Stop the song, then click the note: a blue box selects it (the edit cursor goes there). Left / Right selects the note before or after it, Up / Down the note (or the empty place) on the next string, as in Guitar Pro. Alt+Up / Alt+Down puts the note on the next string (the same pitch), a number gives it a new fret ("1" "2" quickly = 12), Delete removes it (a rest is left there). On an empty place, type a number: a new note, as long as the note before it. Double-click a note to open its box: type a new fret and press Enter, or move the note with Left / Right (a 16th at a time, inside its bar; never onto another note). A missing note? Double-click an empty place on its string, type the fret and press Enter (a new note is as long as the note before it; in a triplet beat, 1 triplet place). Wrong length? With a note selected, + makes it twice as long and - half as long, "." adds or removes the dot (all the notes that start with it change too; never past the next note or the bar end). "/" turns its beat into a triplet (its notes move to the 3 triplet places), and "/" again back to 16ths.

Want the lines as in your Guitar Pro page? Select a note in a bar, then press & to pull the first bar of the next line up into this line, or Ctrl+Enter to start a new line after this bar (as in Guitar Pro). The lines after it fill up again by themselves. Your breaks are saved in the project; a line wider than the window gets narrower. Wrong time signature in the tab? Right-click a bar > Time signature...: the new one for this bar or the following bars too; the notes fit into the bar and the bar keeps its time (4/4 at 125 becomes 6/8 at 93.75). Tab dropdown > Layout...: how many bars on each line (Automatic: as many as fit), and Reset to remove your own breaks (breaks need Settings > Tab > Repeats as written on).

A fix changes the bar as it is written, so a repeat of that bar changes too. Made a mistake? Ctrl+Z in this window (or Undo next to Start) takes it back. Want the file's notes back? Tab dropdown > Undo all fixes (only the track in the window). Ctrl+Z remembers the fixes of this session only: after a restart, Undo all fixes is the way back. Your fixes are green (Settings > Tab > Mark my fixes). Your fixes are saved in the project; the Guitar Pro file and its copy stay as they are. Drum tracks can not be fixed yet.]] },
  { title = "Where your stuff is saved", text = [[
In the project: its tabs, the region of each one, the track you picked, the bar where the tab starts, your line breaks, and your fixes of the tab. Tab Viewer copies each tab into a "Tabs" folder next to the project file, so the project keeps its tab when you move or delete the original. Not saved yet? The copy is made when you save the project.

On this computer: the Light theme, Follow playback, Chord names, Mark my fixes, Playing marks, Note lengths, Repeats as written and the window dock.

Not saved: the loop and the speed (back to 100% when Tab Viewer closes).]] },
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
-- The play position while playing, else the edit cursor (+ Add, the tab that follows, the position line).
function UI.cursor()
  if R.playing then return r.GetPlayPositionEx(R.proj) end
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
-- A label in the label column (CFG.LABEL_W): its control starts at the same x on every row.
function UI.field(text)
  local x = ImGui.GetCursorPosX(ctx)
  UI.label(text)
  ImGui.SetCursorPosX(ctx, x + CFG.LABEL_W)
end
-- The width of a dropdown in the label column (all of them end at the same x).
function UI.field_w()
  return math.max(80, math.min(CFG.TRACK_W, (ImGui.GetContentRegionAvail(ctx))))
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
-- Button kinds: "primary" (blue: an action), "ghost" (text only, as in Chart Cue), nil (grey).
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
local BTN_W = {} -- (the width of each fixed label: measured once, the font does not change)
function UI.btn_w(label, min_w)
  local w = BTN_W[label]
  if not w then w = math.ceil((ImGui.CalcTextSize(ctx, label)) + 22); BTN_W[label] = w end
  return math.max(min_w or 0, w)
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
  if R.rows then UI.draw_find_tempo(x0 + bw + CFG.CTRL_GAP, y0, H) end
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
  -- play / stop (a click on the tab takes the focus from REAPER, so its Space does not reach REAPER)
  local playing = R.playing
  local hit, cx, cy, hov = icon("##play", x0 + aw - 3 * IW, playing and "Stop (Space)" or "Play (Space)")
  local pc = hov and COL.TEXT_BRIGHT or COL.TEXT_MAIN
  if playing then ImGui.DrawList_AddRectFilled(dl, cx - 5, cy - 5, cx + 5, cy + 5, pc, 1)
  else ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 6, cx - 4, cy + 6, cx + 6, cy, pc) end
  if hit then UI.play_stop() end
  -- the gear: the Settings menu drops down below it; a click on the gear while it is open closes it
  hit, cx, cy, hov = icon("##gear", x0 + aw - 2 * IW, "Settings")
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
  ch, S.marks = UI.toggle_line("Mark my fixes", S.marks,
    "On (the default): the notes you fixed or added are green, so you see what is yours and what is from the file.")
  if ch then R.sdirty = true end
  ch, S.pmarks = UI.toggle_line("Playing marks", S.pmarks,
    "On (the default): how to play each note, as in Guitar Pro (arcs for hammer-ons and pull-offs, lines for slides, bend arrows, vibrato waves, a P.M. row for palm mutes, <12> harmonics, slashes for tremolo picking when Tremolo as notes is off). Held notes (4) and dead notes x always show.")
  if ch then R.sdirty = true; Tabs.build() end
  ch, S.lengths = UI.toggle_line("Note lengths", S.lengths,
    "On (the default): how long each note is, under the tab, as in Guitar Pro (stems, joined 8ths and 16ths, dots, rests, the 3 of triplets). A bar with 32nd notes gets wider.")
  if ch then R.sdirty = true; Tabs.build() end
  ch, S.tremnotes = UI.toggle_line("Tremolo as notes", S.tremnotes,
    "On (the default): a tremolo-picked note is written out as the notes you pick (a whole note with 8th tremolo: 8 8ths), easy to read. Off: 1 note with slashes above it, as in Guitar Pro.")
  if ch then R.sdirty = true; Tabs.unselect(); Tabs.build() end
  ch, S.written = UI.toggle_line("Repeats as written", S.written,
    "On (the default): the tab as Guitar Pro writes it: each bar once, with repeat signs |: :|, x3 and the endings 1. 2.; the blue line jumps back at a repeat. Off: the repeats played out, bar after bar as the song plays.")
  if ch then R.sdirty = true; Tabs.unselect(); Tabs.loop_off(); Tabs.build() end
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

-- Tab dropdown > Layout... (as Guitar Pro's Score system layout): the bars per line (Automatic: as many as fit) and
-- Reset of your own breaks; OK applies (1 Undo step), Cancel does not. R.lay: the choices while it is open.
local PER_LIST = { "Automatic" }
for n = 1, 8 do PER_LIST[n + 1] = n .. (n == 1 and " bar" or " bars") end
function UI.draw_layout()
  local lay, e = R.lay, Tabs.cur()
  if not lay then return end
  if not e then R.lay = nil; return end
  if lay.open then ImGui.OpenPopup(ctx, "Layout##layout"); lay.open = nil end
  if not ImGui.BeginPopupModal(ctx, "Layout##layout", true, ImGui.WindowFlags_AlwaysAutoResize()) then
    R.lay = nil
    return
  end
  local lx = ImGui.GetCursorPosX(ctx) + (ImGui.CalcTextSize(ctx, "Your line breaks")) + 16 -- (the label column)
  UI.label("Bars per line")
  ImGui.SetCursorPosX(ctx, lx)
  ImGui.SetNextItemWidth(ctx, 120)
  if ImGui.BeginCombo(ctx, "##per", PER_LIST[(lay.per or 0) + 1]) then
    for k, txt in ipairs(PER_LIST) do
      local v = k > 1 and k - 1 or nil
      if ImGui.Selectable(ctx, txt, lay.per == v) then lay.per = v end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Automatic: as many bars as fit in the window. A number: that many bars on each line, as wide as the window.")
  local mine = #(e.lines or {}) + #(e.joins or {})
  UI.label("Your line breaks")
  ImGui.SetCursorPosX(ctx, lx)
  ImGui.Text(ctx, lay.reset and "0 (reset)" or tostring(mine))
  ImGui.SameLine(ctx)
  ImGui.BeginDisabled(ctx, mine == 0 or lay.reset)
  if UI.button("Reset", UI.btn_w("Reset")) then lay.reset = true end
  ImGui.EndDisabled(ctx)
  UI.tip("Your own breaks (Ctrl+Enter) and joins (&). Reset: the lines from the setting above only.")
  UI.vgap(8)
  if UI.button("OK", 80, nil, "primary") then
    if Tabs.set_layout(lay.per, lay.reset) then
      UI.notice("The new layout. Changed your mind? Ctrl+Z (or Undo) brings the old lines back.")
    end
    R.lay = nil
    ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx)
  if UI.button("Cancel", 80) then R.lay = nil; ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- Right-click a bar > Time signature... (R.meter: the choices while it is open): the 2 numbers, which bars, OK
-- (Tabs.set_meter, 1 Undo step) or Cancel. The notes fit into the bar (same time).
local DENS = { 2, 4, 8, 16 }
local WHICH = { "This bar only", "This bar and the following bars" }
function UI.draw_meter()
  local m, tab = R.meter, R.tab
  if not m then return end
  local b = tab and tab.bars[m.bi]
  if not b then R.meter = nil; return end
  if m.open then ImGui.OpenPopup(ctx, "Time signature##meter"); m.open = nil end
  if not ImGui.BeginPopupModal(ctx, "Time signature##meter", true, ImGui.WindowFlags_AlwaysAutoResize()) then
    R.meter = nil
    return
  end
  local mb = R.doc.mbars[b.wb]
  ImGui.TextColored(ctx, COL.TEXT_DIM, string.format("Bar %s: %d/%d (in the file: %d/%d)", b.label or b.wb, mb.num, mb.den,
    mb.num0 or mb.num, mb.den0 or mb.den))
  local lx = ImGui.GetCursorPosX(ctx) + (ImGui.CalcTextSize(ctx, "Time signature")) + 16 -- (the label column)
  UI.label("Time signature")
  ImGui.SetCursorPosX(ctx, lx)
  ImGui.SetNextItemWidth(ctx, 90)
  local _, num = ImGui.InputInt(ctx, "##num", m.num, 1, 1)
  m.num = math.max(1, math.min(32, num))
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, "/")
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 60)
  if ImGui.BeginCombo(ctx, "##den", tostring(m.den)) then
    for _, d in ipairs(DENS) do if ImGui.Selectable(ctx, tostring(d), m.den == d) then m.den = d end end
    ImGui.EndCombo(ctx)
  end
  UI.label("Bars")
  ImGui.SetCursorPosX(ctx, lx)
  ImGui.SetNextItemWidth(ctx, 250)
  if ImGui.BeginCombo(ctx, "##which", WHICH[m.following and 2 or 1]) then
    for k, txt in ipairs(WHICH) do if ImGui.Selectable(ctx, txt, (k == 2) == m.following) then m.following = k == 2 end end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The following bars: up to the next time signature change of the file.")
  ImGui.TextColored(ctx, COL.TEXT_DIM, "The notes fit into the bar; the bar keeps its time (the tempo changes with it).")
  UI.vgap(8)
  if UI.button("OK", 80, nil, "primary") then
    local done, why = Tabs.set_meter(m.bi, m.num, m.den, m.following)
    if done then UI.notice("The new time signature. Changed your mind? Ctrl+Z (or Undo) brings the old one back.")
    else UI.notice(why, true) end
    R.meter = nil
    ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.SameLine(ctx)
  if UI.button("Cancel", 80) then R.meter = nil; ImGui.CloseCurrentPopup(ctx) end
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
  Tabs.follow(UI.cursor())
  local e = Tabs.cur()
  UI.field("Tab")
  ImGui.SetNextItemWidth(ctx, UI.field_w())
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
    local ed = e and Tabs.edits()
    if e and ImGui.BeginMenu(ctx, "Undo all fixes", ed ~= nil and next(ed) ~= nil) then -- (a submenu, as Remove)
      if ImGui.MenuItem(ctx, "Undo all fixes of this track") then
        Tabs.undo_all()
        UI.notice("The file's notes again. Changed your mind? Ctrl+Z (or Undo) brings your fixes back.")
      end
      ImGui.EndMenu(ctx)
    end
    if e and ImGui.MenuItem(ctx, "Layout...") then R.lay = { per = e.per, reset = false, open = true } end
    if e and ImGui.BeginMenu(ctx, "Remove this tab") then -- (a submenu: 1 wrong click does not remove it)
      if ImGui.MenuItem(ctx, "Remove it from the project") then Tabs.remove(); UI.notice("Removed. Its copy stays in the Tabs folder: Open tab... brings it back.") end
      ImGui.EndMenu(ctx)
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("The tabs of this project. Each one belongs to a region and moves with it; the window shows the tab where the song plays (stopped: at the edit cursor). Region: link this tab to another region.")
end

-- The Track dropdown, the tab of the chosen track, then the bars, time signature and tempo of the file.
function UI.draw_tracks()
  UI.draw_tab_list()
  if not R.rows then
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, R.err or (P.tabs[1] and "No tab for this region yet. Put the edit cursor in it, then click Open tab..."
      or "No tab yet. Open a Guitar Pro file (.gp, .gpx, .gp5, .gp4 or .gp3)."))
    ImGui.PopTextWrapPos(ctx)
    return
  end
  local k = Tabs.track()
  UI.field("Track")
  local x0 = ImGui.GetCursorPosX(ctx)
  ImGui.SetNextItemWidth(ctx, UI.field_w())
  if ImGui.BeginCombo(ctx, "##track", R.rows[k].label) then
    for i, row in ipairs(R.rows) do
      if ImGui.Selectable(ctx, row.sel, i == k) then Tabs.pick(i) end
      UI.tip(row.tip)
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip(R.rows[k].tip)
  ImGui.SetCursorPosX(ctx, x0) -- (the bars, time signature and tempo of the file, under Track)
  ImGui.TextColored(ctx, COL.TEXT_DIM, R.info)
  if R.tab then -- (the bar line: where the tab starts in the song)
    local BW = UI.btn_w("<")
    UI.field("Start")
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
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP) -- (always there, grey without a fix to take back: the row does not jump)
    ImGui.BeginDisabled(ctx, R.undo[1] == nil)
    if UI.button("Undo", UI.btn_w("Undo"), nil, "ghost") then Tabs.undo(-1) end
    ImGui.EndDisabled(ctx)
    UI.tip("Takes back your last fix of the tab (Ctrl+Z in this window does the same). Only the fixes of this session.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    local rate, sk = r.Master_GetPlayRate(R.proj), 1
    for i, v in ipairs(SPEEDS) do if math.abs(v - rate) < 1e-3 then sk = i end end
    local cur = math.abs(SPEEDS[sk] - rate) < 1e-3 and SPEED_TXT[sk] or string.format("%d%%", math.floor(rate * 100 + 0.5))
    local slow = math.abs(rate - 1) > 1e-3 -- (not 100%: yellow, so you see it at a glance)
    if slow then ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.YELLOW) end
    ImGui.SetNextItemWidth(ctx, UI.btn_w("100%") + ImGui.GetFrameHeight(ctx))
    local open = ImGui.BeginCombo(ctx, "##speed", cur)
    if slow then ImGui.PopStyleColor(ctx) end
    if open then
      for i, v in ipairs(SPEEDS) do
        if ImGui.Selectable(ctx, SPEED_TXT[i], i == sk) then Tabs.speed(v) end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("Too fast to play along? Slow the song down (the pitch stays); yellow while it is not 100%. Back to 100% when Tab Viewer closes.")
    if R.tempo_warn then
      ImGui.PushTextWrapPos(ctx, 0)
      ImGui.TextColored(ctx, COL.YELLOW, R.tempo_warn)
      ImGui.PopTextWrapPos(ctx)
    end
  end
  local _, ah = ImGui.GetContentRegionAvail(ctx)
  UI.draw_tab(math.max(40, ah))
end

local STYLES = { { "steady", "1 tempo" }, { "follow", "Follow the song" } }
-- Find tempo, in the toolbar after Open tab... (only with a tab): its menu (From tab, then the tracks: a choice starts
-- at once), while it listens the progress and Cancel, with a result the blue Set tempo (decided 24 November 2026).
function UI.draw_find_tempo(x, y, H)
  local tm = R.tempo
  ImGui.SetCursorPos(ctx, x, y)
  if UI.button("Find tempo", UI.btn_w("Find tempo"), H) then ImGui.OpenPopup(ctx, "##findtempo") end
  UI.tip("Put REAPER's bars on the song: from the tab's tempo, or by listening to a track. After a result: fine-tune it here.")
  local mx = ImGui.GetItemRectMin(ctx)
  local _, my = ImGui.GetItemRectMax(ctx)
  if tm and tm.run then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    ImGui.ProgressBar(ctx, tm.run.done, 100, H, "Listening...")
    ImGui.SameLine(ctx, 0, 4)
    if UI.button("Cancel", UI.btn_w("Cancel"), H) then Tempo.cancel(); R.tempo = nil end
    UI.tip("Stop. Nothing changes.")
  elseif tm and tm.beats then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Set tempo", UI.btn_w("Set tempo"), H, "primary") then Tabs.set_tempo() end
    UI.tip(tm.tab and "Writes the tab's tempo, tempo changes and time signatures into the project from bar 1, and the tab starts on that bar: 1 undo step. The audio stays where it is."
      or "Writes the tempo of this song into the project, and moves its audio a few ms so the first note is on the beat; the tab starts on bar 1: 1 undo step. Other songs keep their places.")
  end
  ImGui.SetNextWindowPos(ctx, mx, my + 4, ImGui.Cond_Appearing())
  UI.draw_tempo_menu()
end

-- The Find tempo menu: From tab, the tracks, then (with a result) the fine controls; as in Note Detective (no 1/2,
-- x2, Style or Short bars from the tab: the tab has them).
function UI.draw_tempo_menu()
  if not ImGui.BeginPopup(ctx, "##findtempo") then return end
  local tm = R.tempo
  local run = tm and tm.run
  ImGui.BeginDisabled(ctx, run ~= nil)
  if ImGui.Selectable(ctx, "From tab", tm and tm.tab ~= nil) then Tabs.find_tempo() end
  UI.tip("No listening: the tempo, tempo changes and time signatures of the tab. Bar 1 goes where the tab's first note meets the first sound of the song (the selected item, else the longest one). Nothing changes yet.")
  ImGui.Separator(ctx)
  local list = Tempo.sources()
  if not list[1] then ImGui.TextDisabled(ctx, "No tracks with audio yet.") end
  for _, e in ipairs(list) do
    if ImGui.Selectable(ctx, e.label, tm ~= nil and tm.tab == nil and R.tsrc_sel == e.tr) then
      R.tsrc_sel = e.tr
      Tabs.find_tempo(e)
    end
    UI.tip("Listens to this track while the song plays (the selected item, else the longest one; a click track is best, then the drums). Nothing changes yet.")
  end
  ImGui.EndDisabled(ctx)
  if tm and tm.beats and not run then
    ImGui.Separator(ctx)
    UI.draw_tempo_fine(tm)
  end
  ImGui.EndPopup(ctx)
end

-- The fine controls of a result: Tempo (from a track: 1/2, x2 and Style too), Bar 1, Play with click, Short bars.
function UI.draw_tempo_fine(tm)
  local x0 = ImGui.GetCursorPosX(ctx)
  local LW = CFG.LABEL_W
  local label = UI.field
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
    ImGui.SetNextItemWidth(ctx, 180)
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
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Play with click", UI.btn_w("Play with click")) then Tempo.try() end
  UI.tip("Plays from bar 1 with REAPER's metronome. Is the loud click on the \"1\"? (This try goes away again unless you click Set tempo.)")
  -- Short bars (from a track only): the first one on the label line, "+ Add" at its right end, the others below
  if not tm.tab then
    label("Short bars")
    local add_w = UI.btn_w("+ Add")
    local function add_button()
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
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
-- The text size of a note or held part (measured once: the item is made again when its text changes).
function UI.item_size(it)
  if not it.tw then it.tw, it.th = ImGui.CalcTextSize(ctx, it.txt or "") end
  return it.tw, it.th
end
function UI.item_w(it) return (UI.item_size(it)) end
-- 1 note or held part at x, y: its fret on a background (the string line hidden), the blue box when selected, its
-- marks (UI.tab_marks).
function UI.tab_item(dl, tab, ln, ox, it, x, y, col, selected)
  local tw, th = UI.item_size(it)
  ImGui.DrawList_AddRectFilled(dl, x - tw / 2 - 2, y - th / 2, x + tw / 2 + 2, y + th / 2, COL.PANEL_BG)
  if selected then -- (the selected note: a blue box, as in Note Detective)
    ImGui.DrawList_AddRect(dl, x - tw / 2 - 4, y - th / 2 - 1, x + tw / 2 + 4, y + th / 2 + 1, COL.ACCENT, 3, 0, 2)
  end
  ImGui.DrawList_AddText(dl, x - tw / 2, y - th / 2 + 1, col, it.txt)
  UI.tab_marks(dl, tab, ln, ox, it, x, y, tw, th)
end
-- The marks of 1 item of the tab (a note or a held part) at x, y (its text tw x th), as Guitar Pro draws them: an
-- arc to the next item on its string (a tie always; a hammer-on / pull-off), a sloped line to it (a slide), a short
-- line into or out of the note, a bend arrow, a vibrato wave (all but the tie: Settings > Tab > Playing marks).
-- The next item on another line, or not drawn (after a repeat sign: it plays in another pass), or back to the left:
-- a short stub to the right.
function UI.tab_marks(dl, tab, ln, ox, it, x, y, tw, th)
  local fx, nx = S.pmarks and it.fx or nil, it.nx
  local col, sl = COL.TEXT_DIM, fx and fx.slide or 0
  if nx and (nx.tie or (fx and (fx.ho or sl & 3 ~= 0))) then
    local nb = tab.bars[it.nxb]
    local x2 = nb.drawn ~= false and nb.ln and tab.lines[nb.ln] == ln and ox + CFG.TAB_LEFT + Tabs.x_of(nb, nx.q)
    local half
    if x2 and x2 > x then half = (UI.item_size(nx)) / 2 + 2
    else x2, half = x + tw / 2 + 16, 0 end
    if nx.tie or (fx and fx.ho) then
      local ya = y - th / 2 - 1
      ImGui.DrawList_AddBezierQuadratic(dl, x, ya, (x + x2) / 2, ya - 8, x2, ya, col, 1, 0)
    else
      local d = nx.fret > it.fret and 3 or -3 -- (up: the line rises)
      ImGui.DrawList_AddLine(dl, x + tw / 2 + 2, y + d, x2 - half, y - d, col, 1)
    end
  end
  if not fx then return end
  local xl, xr = x - tw / 2 - 2, x + tw / 2 + 2
  if sl & 16 ~= 0 then ImGui.DrawList_AddLine(dl, xl - 8, y + 3, xl, y - 3, col, 1)     -- (in from below)
  elseif sl & 32 ~= 0 then ImGui.DrawList_AddLine(dl, xl - 8, y - 3, xl, y + 3, col, 1) end -- (in from above)
  if sl & 3 == 0 and sl & 8 ~= 0 then ImGui.DrawList_AddLine(dl, xr, y + 3, xr + 8, y - 3, col, 1) -- (out up)
  elseif sl & 3 == 0 and sl & 4 ~= 0 then ImGui.DrawList_AddLine(dl, xr, y - 3, xr + 8, y + 3, col, 1) end
  if fx.bend then -- (a curved arrow up)
    ImGui.DrawList_AddBezierQuadratic(dl, xr, y, xr + 7, y, xr + 7, y - 10, col, 1, 0)
    ImGui.DrawList_AddTriangleFilled(dl, xr + 4, y - 9, xr + 10, y - 9, xr + 7, y - 14, col)
  end
  local yv = y - th / 2 - 4
  if fx.vib then -- (a short wave above the note)
    for k = 0, 3 do
      ImGui.DrawList_AddLine(dl, x - 6 + k * 3, yv + (k % 2 == 0 and 1.5 or -1.5), x - 3 + k * 3, yv + (k % 2 == 0 and -1.5 or 1.5), col, 1)
    end
    yv = yv - 5
  end
  if fx.trem then -- (tremolo picking: 1, 2 or 3 slashes above the note, for 8ths, 16ths, 32nds; the user, 24 November 2026)
    for k = 0, fx.trem - 1 do
      local ys = yv - k * 3
      ImGui.DrawList_AddLine(dl, x - 4, ys + 1, x + 4, ys - 2, col, 1.5)
    end
  end
end
-- The repeat signs of bar b as Guitar Pro draws them (repeats as written): "|:" at a repeat start (a thick and a thin
-- line, 2 dots), ":|" at its end, "x3" over the end when it plays more than twice, and the bracket of an ending
-- ("1.", "2.") in the top row. bx / bxe: the left and right x of the bar; top: the top of its line; y0 / yb: the top
-- and the low string; pmh: the rows above the bar numbers.
function UI.tab_repeat(dl, b, line_start, bx, bxe, top, y0, yb, pmh)
  local col, ym, d = COL.TEXT_MAIN, (y0 + yb) / 2, CFG.TAB_LINE / 2
  if b.rs then
    ImGui.DrawList_AddRectFilled(dl, bx, y0, bx + 3, yb, col)
    ImGui.DrawList_AddLine(dl, bx + 6, y0, bx + 6, yb, col, 1)
    ImGui.DrawList_AddCircleFilled(dl, bx + 10, ym - d, 2, col)
    ImGui.DrawList_AddCircleFilled(dl, bx + 10, ym + d, 2, col)
  end
  if b.re then
    ImGui.DrawList_AddRectFilled(dl, bxe - 3, y0, bxe, yb, col)
    ImGui.DrawList_AddLine(dl, bxe - 6, y0, bxe - 6, yb, col, 1)
    ImGui.DrawList_AddCircleFilled(dl, bxe - 10, ym - d, 2, col)
    ImGui.DrawList_AddCircleFilled(dl, bxe - 10, ym + d, 2, col)
    if b.times then
      local tw = ImGui.CalcTextSize(ctx, b.times)
      ImGui.DrawList_AddText(dl, bxe - tw - 2, top + pmh + 2, COL.TEXT_DIM, b.times)
    end
  end
  if b.alt then -- (the ending bracket: its number at its start, a tick down at both ends)
    local y = top + 3
    ImGui.DrawList_AddLine(dl, bx + 2, y, bxe - 3, y, col, 1)
    if b.alt_first or line_start then
      ImGui.DrawList_AddLine(dl, bx + 2, y, bx + 2, y + CFG.TAB_ENDING - 4, col, 1)
      if b.alt_first then
        ImGui.PushFont(ctx, small_font)
        ImGui.DrawList_AddText(dl, bx + 5, y + 1, col, b.alt)
        ImGui.PopFont(ctx)
      end
    end
    if b.alt_last then ImGui.DrawList_AddLine(dl, bxe - 3, y, bxe - 3, y + CFG.TAB_ENDING - 4, col, 1) end
  end
end
-- The marks of the score on bar b (Tabs.view), as in Guitar Pro: the tempo in the top row (a quarter note "= 120",
-- after the section name), the time signature (the 2 numbers over each other, after a |:), the final double bar.
-- top: the y of its line; y0 / yb: the top and the bottom string.
function UI.tab_score(dl, b, lx, bx, top, y0, yb)
  local col = COL.TEXT_MAIN
  for _, t in ipairs(b.tempo or {}) do
    local x = lx + Tabs.x_of(b, t.q) - 4
    if t.q < 1e-6 then
      if b.section and not b.sec_w then b.sec_w = (ImGui.CalcTextSize(ctx, b.section)) end
      x = bx + 2 + (b.sec_w and b.sec_w + 10 or 0)
    end
    local y = top + 2 + ImGui.GetFontSize(ctx) - 4 -- (the note head, on the text's baseline)
    ImGui.DrawList_AddCircleFilled(dl, x + 3, y, 3, COL.TEXT_DIM)
    ImGui.DrawList_AddLine(dl, x + 5.5, y, x + 5.5, y - 10, COL.TEXT_DIM, 1)
    ImGui.DrawList_AddText(dl, x + 10, top + 2, COL.TEXT_DIM, t.txt)
  end
  if b.sig then
    ImGui.PushFont(ctx, head_font)
    local x, ym = bx + (b.rs and CFG.TAB_REPEAT or 0) + CFG.TAB_SIG / 2 + 2, (y0 + yb) / 2
    for k, s in ipairs(b.sig) do
      local w, h = ImGui.CalcTextSize(ctx, s)
      ImGui.DrawList_AddText(dl, x - w / 2, k == 1 and ym - h + 1 or ym - 1, col, s)
    end
    ImGui.PopFont(ctx)
  end
  if b.final and not b.re then
    local xe = lx + Tabs.x_end(b)
    ImGui.DrawList_AddLine(dl, xe - 5, y0, xe - 5, yb, col, 1)
    ImGui.DrawList_AddRectFilled(dl, xe - 3, y0, xe, yb, col)
  end
end
-- The P.M. row of 1 line of the tab (top: its y): "P.M." where a run of palm mutes starts, dashes over it, "|" at its
-- end (a run that goes on to the next line: no text there, no end). Repeats as written: a run of a later pass is
-- the same as the first one (not drawn again); a run over a repeat sign ends at its bar end.
function UI.tab_pm(dl, tab, ln, ox, top)
  local lx = ox + CFG.TAB_LEFT
  ImGui.PushFont(ctx, small_font)
  for _, run in ipairs(tab.pm) do
    local b0, b1 = tab.bars[run.b0], tab.bars[run.b1]
    local v0, v1, q1 = b0.vp or run.b0, b1.vp or run.b1, run.q1
    if v1 < v0 then v1, b1, q1 = v0, b0, nil end
    if b0.drawn ~= false and v0 <= ln.last and v1 >= ln.first then
      local x0 = v0 >= ln.first and lx + Tabs.x_of(b0, run.q0) - 6 or lx
      local x1 = v1 <= ln.last and lx + (q1 and Tabs.x_of(b1, q1) + 4 or Tabs.x_end(b1) - 4)
        or lx + Tabs.x_end(tab.bars[Tabs.vbar(tab, ln.last)])
      local ym = top + 6
      if v0 >= ln.first then
        ImGui.DrawList_AddText(dl, x0, top, COL.TEXT_DIM, "P.M.")
        x0 = x0 + (ImGui.CalcTextSize(ctx, "P.M.")) + 3
        x1 = math.max(x1, x0 + 6) -- (1 short note: still a dash and its end)
      end
      for dx = x0, x1 - 3, 6 do ImGui.DrawList_AddLine(dl, dx, ym, math.min(dx + 3, x1), ym, COL.TEXT_DIM, 1) end
      if v1 <= ln.last then ImGui.DrawList_AddLine(dl, x1, ym - 3, x1, ym + 3, COL.TEXT_DIM, 1) end
    end
  end
  ImGui.PopFont(ctx)
end
local BEAMS = { [8] = 1, [16] = 2, [32] = 3 }
-- A rest of value v at x (y: the middle of the stems), as Guitar Pro draws it (small and grey).
function UI.tab_rest(dl, v, x, y, col)
  if v.base <= 2 then -- (a whole rest hangs from a line, a half rest sits on it)
    ImGui.DrawList_AddLine(dl, x - 5, y - 2, x + 5, y - 2, col, 1)
    if v.base == 1 then ImGui.DrawList_AddRectFilled(dl, x - 3, y - 2, x + 3, y + 1, col)
    else ImGui.DrawList_AddRectFilled(dl, x - 3, y - 5, x + 3, y - 2, col) end
  elseif v.base == 4 then -- (a zigzag)
    ImGui.DrawList_AddLine(dl, x - 1, y - 7, x + 2, y - 3, col, 1.5)
    ImGui.DrawList_AddLine(dl, x + 2, y - 3, x - 2, y + 1, col, 1.5)
    ImGui.DrawList_AddLine(dl, x - 2, y + 1, x + 2, y + 5, col, 1.5)
    ImGui.DrawList_AddLine(dl, x + 2, y + 5, x - 1, y + 7, col, 1.5)
  else -- (a slanted stem with 1, 2 or 3 flags)
    ImGui.DrawList_AddLine(dl, x + 3, y - 6, x - 1, y + 6, col, 1)
    for k = 0, BEAMS[v.base] - 1 do
      local fy = y - 5 + k * 4
      ImGui.DrawList_AddCircleFilled(dl, x - 2, fy, 1.5, col)
      ImGui.DrawList_AddLine(dl, x - 2, fy + 1, x + 3 - k * 1.3, fy, col, 1)
    end
  end
  if v.dot then ImGui.DrawList_AddCircleFilled(dl, x + 6, y, 1.3, col) end
end
-- The note lengths of 1 bar (b.rh: Tabs.rhythm); lx: the left of the strings, y: the top of the stems. Stems (a half
-- note: short, a whole note: none), beams over the 8ths and shorter of 1 beat, flags, dots, rests, the "3".
function UI.tab_rhythm(dl, b, lx, y, ym)
  local col, st = COL.TEXT_DIM, CFG.TAB_STEM
  local ye = y + st
  local rh = b.rh
  for k, e in ipairs(rh) do
    local x, v = lx + Tabs.x_of(b, e.q), e.v
    if e.rest then -- (in the middle of the strings, as Guitar Pro (ym; the user, 24 November 2026); an empty bar:
      -- its rest in the middle of the bar)
      UI.tab_rest(dl, v, #rh == 1 and lx + b.x + b.pad + b.n16 * b.sw / 2 or x, ym, col)
    else
      if v.base >= 2 then ImGui.DrawList_AddLine(dl, x, v.base == 2 and y + st / 2 or y, x, ye, col, 1) end
      local n = BEAMS[v.base] or 0
      if e.join then -- (the beams shared with the next note; more of its own: a short stub)
        local nx = rh[k + 1]
        local m = math.min(n, BEAMS[nx.v.base] or 0)
        for l = 0, m - 1 do ImGui.DrawList_AddRectFilled(dl, x, ye - 2 - l * 4, lx + Tabs.x_of(b, nx.q), ye - l * 4, col) end
        for l = m, n - 1 do ImGui.DrawList_AddRectFilled(dl, x, ye - 2 - l * 4, x + 5, ye - l * 4, col) end
      elseif e.flag then -- (an 8th or shorter alone: flags)
        for l = 0, n - 1 do ImGui.DrawList_AddLine(dl, x, ye - l * 4, x + 5, ye - 5 - l * 4, col, 1.5) end
      elseif k > 1 and rh[k - 1].join and n > (BEAMS[rh[k - 1].v.base] or 0) then -- (the last of a group: stubs back)
        for l = BEAMS[rh[k - 1].v.base], n - 1 do ImGui.DrawList_AddRectFilled(dl, x - 5, ye - 2 - l * 4, x, ye - l * 4, col) end
      end
      if v.dot then ImGui.DrawList_AddCircleFilled(dl, x + 4, ye - 1, 1.3, col) end
    end
    if e.t3 then -- (a triplet group, as Guitar Pro draws it: a bracket from its first to its last note, "3" in a gap
      -- in its middle, the ends turned up to the notes; the user's screenshot, 24 November 2026)
      local x2 = lx + Tabs.x_of(b, rh[e.t3].q)
      local mid, yb = (x + x2) / 2, ye + 7
      ImGui.PushFont(ctx, small_font)
      local tw = UI.centre(dl, mid, yb, col, "3")
      ImGui.PopFont(ctx)
      if x2 - x > tw + 8 then
        ImGui.DrawList_AddLine(dl, x, yb - 3, x, yb, col, 1)
        ImGui.DrawList_AddLine(dl, x, yb, mid - tw / 2 - 2, yb, col, 1)
        ImGui.DrawList_AddLine(dl, mid + tw / 2 + 2, yb, x2, yb, col, 1)
        ImGui.DrawList_AddLine(dl, x2, yb, x2, yb - 3, col, 1)
      end
    end
  end
end
-- The tab of the chosen track (only the lines in view are drawn); a click plays the song from there.
function UI.draw_tab(h)
  -- (a clear frame around the tab, with room inside it: the user, 24 November 2026)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border(), COL.BTN_ACTIVE)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding(), 4)
  local vis = ImGui.BeginChild(ctx, "##tab", 0, h, ImGui.ChildFlags_Border())
  ImGui.PopStyleVar(ctx)
  ImGui.PopStyleColor(ctx)
  if not vis then return end
  local tab = R.tab
  if not tab then
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, R.tab_why or "")
    ImGui.PopTextWrapPos(ctx)
    ImGui.EndChild(ctx)
    return
  end
  local w = ImGui.GetContentRegionAvail(ctx)
  if tab.w ~= w then
    tab.lines, tab.h = Tabs.layout(tab, w, UI.item_w); tab.w = w
    if tab.chord_row then Tabs.place_chords(tab, function(t) return (ImGui.CalcTextSize(ctx, t)) end, UI.trunc) end
  end
  local ox, oy = ImGui.GetCursorScreenPos(ctx)
  local lx = ox + CFG.TAB_LEFT -- (the left of the strings)
  ImGui.InvisibleButton(ctx, "##tabarea", math.max(1, w), math.max(1, tab.h))
  local playing = R.playing
  UI.tip(playing and "Click: the song plays from there. Shift+click a bar: loop it (Escape: stop)."
    or "Click a note to select it and fix it (Help: Fix the tab). Double-click: its box, or a new note on an empty place. Shift+click a bar: loop it (Escape: stop). Right-click a bar: its time signature.")
  if ImGui.IsItemClicked(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)
    local bi, q, s = Tabs.hit(tab, mx - ox, my - oy)
    if bi and ImGui.GetKeyMods(ctx) == ImGui.Mod_Shift() then Tabs.loop(bi)
    elseif bi and playing then -- (a repeated bar: the pass nearest to the one that plays)
      UI.play_from(Tabs.time_of(Tabs.pass_near(tab, bi, (Tabs.place_of(r.GetPlayPositionEx(R.proj)))), q))
    elseif bi then -- (stopped: Tabs.click)
      local nq
      R.tsel, R.tbox, nq, R.tlast = Tabs.click(tab, bi, q, s, ImGui.IsMouseDoubleClicked(ctx, 0), R.tlast)
      r.SetEditCurPos2(R.proj, Tabs.time_of(bi, nq), true, false)
    end
  end
  if ImGui.IsItemClicked(ctx, 1) then -- (right-click a bar: its menu)
    local mx, my = ImGui.GetMousePos(ctx)
    local bi = Tabs.hit(tab, mx - ox, my - oy)
    if bi then R.bar_menu = bi; ImGui.OpenPopup(ctx, "##barmenu") end
  end
  if ImGui.BeginPopup(ctx, "##barmenu") then
    local b = tab.bars[R.bar_menu or 0]
    if b and ImGui.MenuItem(ctx, "Time signature...") then
      local mb = R.doc.mbars[b.wb]
      R.meter = { bi = R.bar_menu, num = mb.num, den = mb.den, following = false, open = true }
    end
    ImGui.EndPopup(ctx)
  end
  local sel_bi, sel_i = UI.tab_sel()
  local dl, fs = ImGui.GetWindowDrawList(ctx), ImGui.GetFontSize(ctx)
  local sy = ImGui.GetScrollY(ctx)
  local lh = tab.lh
  local lp = R.loop
  local sh = tab.sec_row and CFG.TAB_SECTION or 0 -- (the section names, at the very top)
  local eh = sh + (tab.end_row and CFG.TAB_ENDING or 0) -- (then the row of the endings 1. 2.)
  local pmh = eh + (tab.pm_row and CFG.TAB_PM or 0) -- (then P.M.; the bar numbers below them)
  for _, ln in ipairs(tab.lines) do
    if ln.y + lh >= sy and ln.y <= sy + h then
      local v0, v1 = lp and tab.bars[lp.sbi].vp or lp and lp.sbi, lp and tab.bars[lp.bi].vp or lp and lp.bi
      if v0 and v1 and v0 <= ln.last and v1 >= ln.first then -- (the loop: a blue band over the bar numbers)
        local b0, b1 = tab.bars[Tabs.vbar(tab, math.max(v0, ln.first))], tab.bars[Tabs.vbar(tab, math.min(v1, ln.last))]
        local x0 = lx + b0.x + (v0 >= ln.first and b0.pad + lp.sq * 4 * b0.sw or 0)
        local x1 = lx + Tabs.x_end(b1)
        ImGui.DrawList_AddRectFilled(dl, x0, oy + ln.y + pmh + 1, x1, oy + ln.y + pmh + fs + 3, COL.HEADER_ACTIVE, 3)
      end
      if tab.pm_row then UI.tab_pm(dl, tab, ln, ox, oy + ln.y + eh + 1) end
      local y0 = oy + ln.y + tab.top -- (the top string)
      local yb = y0 + (tab.nstr - 1) * CFG.TAB_LINE
      local x_end = lx + Tabs.x_end(tab.bars[Tabs.vbar(tab, ln.last)])
      for s = 1, tab.nstr do
        local ys = y0 + (tab.nstr - s) * CFG.TAB_LINE
        UI.centre(dl, ox + CFG.TAB_LEFT / 2 - 2, ys, COL.TEXT_DIM, tab.names[s])
        ImGui.DrawList_AddLine(dl, lx, ys, x_end, ys, COL.LINE, 1)
      end
      ImGui.DrawList_AddLine(dl, x_end, y0, x_end, yb, COL.TEXT_DIM, 1)
      for vk = ln.first, ln.last do
        local bi = Tabs.vbar(tab, vk)
        local b = tab.bars[bi]
        local bx = lx + b.x
        ImGui.DrawList_AddLine(dl, bx, y0, bx, yb, COL.TEXT_DIM, 1)
        ImGui.DrawList_AddText(dl, bx + 2, oy + ln.y + pmh + 2, COL.TEXT_DIM, b.label)
        if b.rs or b.re or b.alt then UI.tab_repeat(dl, b, vk == ln.first, bx, lx + Tabs.x_end(b), oy + ln.y + sh, y0, yb, pmh - sh) end
        if b.section then ImGui.DrawList_AddText(dl, bx + 2, oy + ln.y + 2, COL.TEXT_BRIGHT, b.section) end
        if b.tempo or b.sig or (b.final and not b.re) then UI.tab_score(dl, b, lx, bx, oy + ln.y, y0, yb) end
        if tab.chord_row then -- (the chord names, under the bar numbers, over their chord: Tabs.place_chords)
          for _, c in ipairs(b.chords) do
            ImGui.DrawList_AddText(dl, lx + c.x, oy + ln.y + pmh + CFG.TAB_TOP - 2, COL.TEXT_BRIGHT, c.txt)
          end
        end
        if S.lengths then UI.tab_rhythm(dl, b, lx, yb + 10, (y0 + yb) / 2) end
        for k, nt in ipairs(b.notes) do -- (a chord: its notes on their strings, 1 above the other)
          UI.tab_item(dl, tab, ln, ox, nt, lx + Tabs.x_of(b, nt.q), y0 + (tab.nstr - nt.s) * CFG.TAB_LINE,
            (nt.mine and S.marks) and COL.GREEN or COL.TEXT_MAIN, bi == sel_bi and k == sel_i)
        end
        if b.ties then -- (the held parts of tied notes: "(4)", an arc from the note before)
          for _, t in ipairs(b.ties) do
            if not t.off then -- (grey: it is held, not played; the user, 24 November 2026)
              UI.tab_item(dl, tab, ln, ox, t, lx + Tabs.x_of(b, t.q), y0 + (tab.nstr - t.s) * CFG.TAB_LINE, COL.TEXT_DIM)
            end
          end
        end
      end
    end
  end
  local esel = sel_bi and not sel_i and R.tsel -- (a selected empty place: a blue box there, as a selected note has)
  local eln = esel and Tabs.line_of(tab, sel_bi)
  if esel and eln then
    local b = tab.bars[sel_bi]
    local x = lx + Tabs.x_of(b, esel.q)
    local y = oy + eln.y + tab.top + (tab.nstr - esel.s) * CFG.TAB_LINE
    ImGui.DrawList_AddRect(dl, x - 7, y - fs / 2 - 1, x + 7, y + fs / 2 + 1, COL.ACCENT, 3, 0, 2)
  end
  -- the position line, blue: playing at the play position (Follow playback: its line in view); stopped at the edit
  -- cursor (a later pass of a repeat: on its written bar)
  local pbi, pq = Tabs.place_of(UI.cursor())
  pbi = pbi and (tab.bars[pbi].shown or pbi)
  local pln = pbi and Tabs.line_of(tab, pbi)
  if pln then
    local b = tab.bars[pbi]
    local px = lx + b.x + b.pad + math.min(pq or 0, b.len) * 4 * b.sw
    local y0 = oy + pln.y + tab.top
    local y1 = y0 + (tab.nstr - 1) * CFG.TAB_LINE + 8
    ImGui.DrawList_AddLine(dl, px, y0 - 8, px, y1, COL.ACCENT, 2) -- (blue, playing and stopped: decided 24 November 2026)
    if playing and S.follow and R.tab_line ~= pln.y then
      R.tab_line = pln.y
      ImGui.SetScrollY(ctx, math.max(0, pln.y - CFG.TAB_LINE))
    end
  end
  if not playing then R.tab_line = nil end
  UI.tab_box(ox, oy, playing, sel_bi, sel_i)
  ImGui.EndChild(ctx)
end
-- The selected note of the tab: its bar and index (nil: none, or the song plays; a note that is gone: no selection).
-- A selected empty place (R.tsel.empty: a click there, Up / Down): its bar and no index.
function UI.tab_sel()
  local sel, tab = R.tsel, R.tab
  if not (sel and tab and tab.bars[sel.bi]) or R.playing then return nil end
  local i = Tabs.note_at(tab, sel.bi, sel.q, sel.s)
  if not i and not sel.empty then R.tsel = nil; return nil end
  if i then sel.empty = nil end
  return sel.bi, i
end
-- The box of a note (after a double-click: the selected note; else a new note at R.tbox.bi / q / s): its fret, then
-- Enter; Left / Right moves the selected note 1 place of the grid (in its bar); + - . / its length (UI.len_op);
-- Escape or a click elsewhere closes it.
function UI.tab_box(ox, oy, playing, sel_bi, sel_i)
  local a, tab = R.tbox, R.tab
  if not a then return end
  local bi, q, s = a.bi, a.q, a.s
  if not a.new then
    if not sel_i then R.tbox = nil; return end
    local nt = tab.bars[sel_bi].notes[sel_i]
    bi, q, s = sel_bi, nt.q, nt.s
  end
  local ln = Tabs.line_of(tab, bi)
  if playing or not ln then R.tbox = nil; return end
  local b = tab.bars[bi]
  local x = CFG.TAB_LEFT + Tabs.x_of(b, q)
  local y = ln.y + tab.top + (tab.nstr - s) * CFG.TAB_LINE
  ImGui.SetCursorScreenPos(ctx, ox + x - 16, oy + y - ImGui.GetFrameHeight(ctx) / 2)
  ImGui.SetNextItemWidth(ctx, 32)
  if a.focus then ImGui.SetKeyboardFocusHere(ctx); a.focus = nil end
  ImGui.PushID(ctx, a.gen or 0) -- (a length key: a new id, so the box starts again without the typed key)
  local enter, txt = ImGui.InputText(ctx, "##tabbox", a.txt,
    ImGui.InputTextFlags_CharsDecimal() | ImGui.InputTextFlags_EnterReturnsTrue() | ImGui.InputTextFlags_AutoSelectAll())
  ImGui.PopID(ctx)
  a.txt = txt
  UI.tip(a.new and "The fret of the new note, then Enter. Escape: close."
    or "Its fret, then Enter. Left / Right: move the note. + / -: twice as long / half. \".\": dotted. \"/\": a triplet beat. Escape: close.")
  if not a.new and ImGui.IsItemActive(ctx) then
    local op = UI.len_char()
    if op and op ~= "&" then -- (in the box: the length keys only)
      UI.len_op(bi, sel_i, op)
      a.txt, a.gen, a.focus = txt:gsub("[^%d]", ""), (a.gen or 0) + 1, true
      return
    end
    local dir = ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow(), true) and -1
      or ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow(), true) and 1 or nil
    if dir then -- (1 place of the grid there: a 16th, a triplet place)
      local dq = dir * Tabs.step(b, q)
      local nq, why = Tabs.move(bi, sel_i, dq)
      if nq then R.tsel.q = nq; r.SetEditCurPos2(R.proj, Tabs.time_of(bi, nq), true, false)
      else UI.notice(why, true) end
    end
  end
  if enter then
    local f = tonumber(txt)
    f = f and math.floor(f)
    local done, why
    if a.new then
      done, why = Tabs.add(bi, q, s, f)
      if done then R.tsel = { bi = bi, q = q, s = s } end
    elseif f then
      why = select(2, Tabs.set_fret(bi, sel_i, f))
    end
    if why then UI.notice(why, true) end
    R.tbox = nil
  elseif ImGui.IsItemDeactivated(ctx) then
    R.tbox = nil
  end
end
local DIGIT_KEYS
-- The keys of the tab (the window has the focus, nothing typed in, no menu open). Ctrl+Z / Ctrl+Shift+Z: the tab
-- edits first, then REAPER's undo. Stopped, a note selected: Left / Right, Up / Down (select on the next string, as in
-- Guitar Pro), Alt+Up / Down (the note to the next string), a fret, Delete, + - . / (its length); an empty place
-- selected: Left / Right, Up / Down, a number adds a note there.
function UI.tab_keys()
  if not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) or ImGui.IsAnyItemActive(ctx)
    or ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopup()) then return end
  local C, SH = ImGui.Mod_Ctrl(), ImGui.Mod_Shift()
  if ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Z()) then
    if not Tabs.undo(-1) then r.Main_OnCommand(40029, 0) end -- Edit: Undo
    return
  elseif ImGui.IsKeyChordPressed(ctx, C | SH | ImGui.Key_Z()) or ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Y()) then
    if not Tabs.undo(1) then r.Main_OnCommand(40030, 0) end -- Edit: Redo
    return
  end
  local op = UI.len_char() -- (the typed "+", "-", ".", "/", "&": any keyboard layout, Shift too)
  local line = op == "&" and "&" or (ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Enter()) or ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_KeypadEnter())) and "enter"
  if line then -- (the line keys of Guitar Pro: & pulls the next line's first bar up, Ctrl+Enter moves the rest down)
    local bi = UI.tab_sel()
    local ok, why = Tabs.set_lines(bi or (R.tsel and R.tsel.bi) or 0, line)
    if not ok then UI.notice(why, true) end
    return
  elseif op then
    local bi, i = UI.tab_sel()
    if i then UI.len_op(bi, i, op) end
    return
  end
  local function key(k, rep) return ImGui.IsKeyPressed(ctx, k, rep) end
  local up, down = key(ImGui.Key_UpArrow(), false), key(ImGui.Key_DownArrow(), false)
  if ImGui.GetKeyMods(ctx) == ImGui.Mod_Alt() and (up or down) then -- (Alt+Up / Down: the note to the next string)
    local bi, i = UI.tab_sel()
    if i then
      local dir = up and 1 or -1
      local ok, why = Tabs.move_string(bi, i, dir)
      if ok then R.tsel.s = R.tsel.s + dir else UI.notice(why, true) end
    end
    return
  end
  if ImGui.GetKeyMods(ctx) ~= ImGui.Mod_None() then return
  elseif R.loop and key(ImGui.Key_Escape(), false) then Tabs.loop_off(); return
  elseif key(ImGui.Key_Space(), false) then UI.play_stop(); return end
  local bi, i = UI.tab_sel()
  local tab, sel = R.tab, R.tsel
  if not (bi and tab and sel) then return end
  local function select(b2, q, s) -- (a note there, else the empty place)
    R.tsel = { bi = b2, q = q, s = s, empty = not Tabs.note_at(tab, b2, q, s) or nil }
    r.SetEditCurPos2(R.proj, Tabs.time_of(b2, q), true, false)
  end
  if key(ImGui.Key_LeftArrow(), true) or key(ImGui.Key_RightArrow(), true) then
    local dir = key(ImGui.Key_LeftArrow(), true) and -1 or 1
    if i then -- (a note: the note before or after it)
      local b2, i2 = Tabs.next_note(tab, bi, i, dir)
      if b2 then local nt = tab.bars[b2].notes[i2]; select(b2, nt.q, nt.s) end
    else -- (an empty place: the place before or after it on its string)
      local b2, q2 = Tabs.next_place(tab, bi, sel.q, dir)
      if b2 then select(b2, q2, sel.s) end
    end
  elseif up or down then -- (the note or the empty place on the next string, as in Guitar Pro)
    local s2 = sel.s + (up and 1 or -1)
    if s2 >= 1 and s2 <= tab.nstr then select(bi, sel.q, s2) end
  elseif not i then -- (an empty place: a number adds a note there)
    local d = UI.digit()
    if d and Tabs.add(bi, sel.q, sel.s, d) then
      sel.empty = nil
      R.tnum = { txt = tostring(d), t = Util.now(), bi = bi, i = Tabs.note_at(R.tab, bi, sel.q, sel.s) }
    end
  elseif key(ImGui.Key_Delete(), false) then
    Tabs.delete(bi, i)
    sel.empty = true -- (its place stays selected: a number adds a note again)
  else
    local d = UI.digit()
    if d then
      local now, last = Util.now(), R.tnum
      local txt = (last and last.bi == bi and last.i == i and now - last.t < CFG.TAB_DIGITS) and (last.txt .. d) or tostring(d)
      if tonumber(txt) > CFG.FRETS then txt = tostring(d) end
      R.tnum = { txt = txt, t = now, bi = bi, i = i }
      Tabs.set_fret(bi, i, tonumber(txt))
    end
  end
end
-- The number key (0 .. 9, also on the keypad) pressed in this frame, or nil.
function UI.digit()
  if not DIGIT_KEYS then
    DIGIT_KEYS = {}
    for d = 0, 9 do DIGIT_KEYS[d] = { ImGui["Key_" .. d](), ImGui["Key_Keypad" .. d]() } end
  end
  for d = 0, 9 do
    if ImGui.IsKeyPressed(ctx, DIGIT_KEYS[d][1], false) or ImGui.IsKeyPressed(ctx, DIGIT_KEYS[d][2], false) then return d end
  end
end
local LEN_CHARS = { [43] = "+", [45] = "-", [46] = ".", [47] = "/", [38] = "&" }
-- The length or line key typed in this frame ("+", "-", ".", "/"; "&": a line break), or nil.
function UI.len_char()
  local k = 0
  while true do
    local got, c = ImGui.GetInputQueueCharacter(ctx, k)
    if not got then return nil end
    if LEN_CHARS[c] then return LEN_CHARS[c] end
    k = k + 1
  end
end
-- A length key on the selected note i of bar bi: Tabs.length or Tabs.triplet (the selection follows the note).
function UI.len_op(bi, i, op)
  local q, why
  if op == "/" then
    q, why = Tabs.triplet(bi, i)
    if q then R.tsel.q = q; r.SetEditCurPos2(R.proj, Tabs.time_of(bi, q), true, false) end
  else
    q, why = Tabs.length(bi, i, op)
  end
  if why then UI.notice(why, true) end
end
-- The song plays from time t (playing: it jumps there).
function UI.play_from(t)
  r.SetEditCurPos2(R.proj, t, true, true)
  if r.GetPlayStateEx(R.proj) & 1 == 0 then r.OnPlayButtonEx(R.proj) end
end
-- Play / stop (the toolbar icon, Space in the window).
function UI.play_stop()
  if r.GetPlayStateEx(R.proj) & 1 == 1 then r.OnStopButtonEx(R.proj) else r.OnPlayButtonEx(R.proj) end
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
  UI.tab_keys()
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
  local playing = R.proj ~= nil and r.GetPlayStateEx(R.proj) & 1 == 1 -- (read once per frame: R.playing)
  if playing and not R.playing then R.tbox = nil end -- (the song starts: the note box closes)
  R.playing = playing
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
    UI.draw_layout()
    UI.draw_meter()
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
  Tabs.loop_off()
  if R.pitch_old or r.Master_GetPlayRate(R.proj) ~= 1 then Tabs.speed(1) end
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
