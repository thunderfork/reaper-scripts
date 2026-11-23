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

-- The shared Guitar Pro reader (Guitar Pro.lua, next to this script).
local GP
do
  local dir = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or ""
  if r.file_exists(dir .. "Guitar Pro.lua") then GP = dofile(dir .. "Guitar Pro.lua") end
  if not GP then
    r.ShowMessageBox("Tab Viewer needs its file \"Guitar Pro.lua\" next to it. Install Tab Viewer again with ReaPack.", "Tab Viewer", 0)
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
CFG.DEFAULT_W, CFG.DEFAULT_H = 480, 420
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
CFG.TRACK_LINE = 24            -- the height of a line of the track list

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

-- R: runtime state (not saved). P: the project data. S: settings of this computer.
local R = {
  proj = nil, projfn = "", state_cc = -1, plast_txt = "", pdirty = false, sdirty = false,
  frames = 0,
  err = nil,         -- why the tab of the project could not be read (a line in the window)
  rows = nil,        -- the lines of the track list: { name, what, tun, tip, id } (Tabs.show; with the tab)
  info = nil,        -- the line below the list: bars, time signature, tempo
}
local P = { file = "" } -- file: the tab (relative to the project folder: "Tabs/song.gp"; else a full path)
local S = {
  light = false,     -- Light theme (Dark is the default)
  dock = 0,          -- the REAPER docker of the window (0 = floating)
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
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
function Util.save_settings()
  r.SetExtState(CFG.EXT, "light", S.light and "1" or "0", true)
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

-- The tab of a saved project goes into its Tabs folder (a tab from elsewhere is copied there; the same name with
-- other content gets " (2)"); P.file is then relative ("Tabs/song.gp"). from: the folder that a relative P.file
-- belongs to (the project folder before a Save as). Returns true when the tab is in the Tabs folder.
function Tabs.keep(from)
  local dir = Tabs.dir()
  if not dir or P.file == "" then return false end
  local src = Tabs.absolute(P.file) and P.file or (from and (from .. "/" .. P.file))
  local data = src and Util.read_all(src)
  if not data then return false end
  local name = P.file:match("([^/\\]+)$")
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
  if P.file ~= rel then P.file, R.pdirty = rel, true end
  return true
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
    rows[k] = { name = t.name, what = what, tun = tun, tip = tip, id = "##track" .. k }
  end
  local first, change = doc.mbars[1], false
  for _, mb in ipairs(doc.mbars) do if mb.num ~= first.num or mb.den ~= first.den then change = true; break end end
  local parts = { string.format("%d bars", #doc.mbars), string.format("%d/%d%s", first.num, first.den, change and " (changes)" or "") }
  if doc.tempo then parts[3] = string.format("%g BPM in the file%s", doc.tempo, doc.tempos > 1 and " (changes)" or "") end
  return rows, table.concat(parts, "  ·  ")
end
-- The window shows this tab (nil: none; why: the line in its place).
function Tabs.show(doc, why)
  R.err, R.rows, R.info = why, nil, nil
  if doc then R.rows, R.info = Tabs.rows(doc) end
end

-- Reads the tab of the project into the window, or why not.
function Tabs.load()
  if P.file == "" then Tabs.show(nil); return end
  local full = Tabs.full(P.file)
  if not r.file_exists(full) then
    Tabs.show(nil, "The tab of this project is missing (" .. full .. "). Open it again.")
    return
  end
  Tabs.show(GP.read(full))
end

-- Opens the tab at path in the project. Returns true, or nil and why (the project does not change).
function Tabs.open(path)
  local doc, why = GP.read(path)
  if not doc then return nil, why end
  P.file, R.pdirty = path, true
  local copied = Tabs.keep()
  Tabs.show(doc)
  return true, copied
end

-- The project file changed (the 1st save, Save as): the tab goes with it, into the Tabs folder of the new place (the
-- window keeps showing it). old_fn: the project file before.
function Tabs.moved(old_fn)
  Tabs.keep(Tabs.dir(old_fn))
  if not R.rows then Tabs.load() end
end

---------------------------------------------------------------------------
-- PROJECT (the project data: ProjExtState "Tab Viewer"/"cfg"; nothing saved when there is no tab)
---------------------------------------------------------------------------
function Project.parse(txt)
  local p = { file = "" }
  for line in (txt or ""):gmatch("[^\n]+") do
    local k, v = line:match("^(%w+)=(.*)$")
    if k == "file" then p.file = v end
  end
  return p
end
function Project.serialize(p) return p.file ~= "" and ("file=" .. p.file .. "\n") or "" end
function Project.read()
  local n, txt = r.GetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY)
  return (n and n > 0 and txt) or ""
end
function Project.load(txt)
  P = Project.parse(txt)
  R.plast_txt, R.pdirty = txt, false
  Tabs.load()
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
    R.proj, R.projfn, R.state_cc = proj, fn, r.GetProjectStateChangeCount(proj)
    Project.load(Project.read())
    return
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc or fn ~= R.projfn then
    local old = R.projfn
    R.state_cc, R.projfn = cc, fn
    local txt = Project.read()
    if txt ~= R.plast_txt then Project.load(txt) -- (never write the old tab into the next project)
    elseif fn ~= old then Tabs.moved(old) end
  end
end

---------------------------------------------------------------------------
-- TESTS: tests/tabviewer.lua sets TabViewerTest: hand it the modules and do not start the UI
---------------------------------------------------------------------------
if TESTING then
  local test = rawget(_G, "TabViewerTest")
  test.CFG, test.S, test.R, test.Util, test.Project, test.Tabs, test.GP = CFG, S, R, Util, Project, Tabs, GP
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

local HELP_INTRO = "Tab Viewer shows the tracks of a Guitar Pro tab in your project. "
  .. "This first version opens a tab and lists its tracks: the guitars, the bass and the drums, with their tunings."
local HELP_TOPICS = {
  { title = "Open a tab", text = [[
Got a Guitar Pro tab of the song? Click "Open tab..." and pick the file: .gp (Guitar Pro 7 and 8), .gpx (Guitar Pro 6), .gp5, .gp4 or .gp3 (Guitar Pro 5, 4 and 3).

The list shows every track of the tab: its instrument, how many strings it has and its tuning ("Standard", "Drop D", "Eb Standard", or the notes of the open strings), and the capo. Point at a track for its open strings.]] },
  { title = "Where your stuff is saved", text = [[
In the project: which tab it uses. Tab Viewer copies the tab into a "Tabs" folder next to the project file, so the project keeps its tab when you move or delete the original. Not saved yet? The copy is made when you save the project.

On this computer: the Light theme and the window dock.]] },
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
  local done, res = Tabs.open(path)
  if not done then UI.notice(res, true); return end
  if res then UI.notice("Opened. A copy is in the project's Tabs folder.")
  elseif not Tabs.dir() then UI.notice("Opened. Save the project: a copy of the tab then goes into its Tabs folder.")
  else UI.notice("Opened.") end
end

function UI.draw_toolbar()
  UI.vgap(CFG.SP_EDGE)
  local x0, y0 = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local IW, H = CFG.TB_ICON_W, ImGui.GetFrameHeight(ctx)
  UI.label("Tab")
  local bw = UI.btn_w("Open tab...")
  if UI.button("Open tab...", bw, H, "primary") then UI.open_tab() end
  UI.tip("Pick a Guitar Pro tab of the song (.gp, .gpx, .gp5, .gp4, .gp3). The project keeps a copy of it.")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  local room = math.max(40, x0 + aw - 2 * IW - CFG.CTRL_GAP - ImGui.GetCursorPosX(ctx))
  if P.file ~= "" then
    local name = P.file:match("([^/\\]+)$")
    UI.row_text(UI.trunc_c(name, room), COL.TEXT_DIM)
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, Tabs.full(P.file)) end -- (built only while it shows)
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

-- The sections of the Settings menu (tools\docs-check.ps1 reads the names).
local SETTINGS_SECTIONS = {
  { "Look" }, { "Window" },
}
-- The Settings menu (the gear button): Look, Window.
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

-- The track list: 1 line per track (name, instrument and strings, tuning), then the bars, time signature and tempo.
function UI.draw_tracks()
  ImGui.PushFont(ctx, head_font)
  ImGui.TextColored(ctx, COL.HEADING, "Tracks")
  ImGui.PopFont(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  if not R.rows then
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, R.err or "No tab yet. Open a Guitar Pro file (.gp, .gpx, .gp5, .gp4 or .gp3).")
    ImGui.PopTextWrapPos(ctx)
    return
  end
  local dl = ImGui.GetWindowDrawList(ctx)
  local w1, w2 = math.floor(aw * 0.42), math.floor(aw * 0.30)
  local LH = CFG.TRACK_LINE
  for _, row in ipairs(R.rows) do
    local x, y = ImGui.GetCursorScreenPos(ctx)
    ImGui.InvisibleButton(ctx, row.id, aw, LH)
    if ImGui.IsItemHovered(ctx) then ImGui.DrawList_AddRectFilled(dl, x, y, x + aw, y + LH, COL.ROW_HOVER, 4) end
    UI.tip(row.tip)
    local ty = UI.text_y(y, LH)
    ImGui.DrawList_AddText(dl, x + 4, ty, COL.TEXT_MAIN, UI.trunc_c(row.name, w1 - 12))
    ImGui.DrawList_AddText(dl, x + w1, ty, COL.TEXT_DIM, UI.trunc_c(row.what, w2 - 8))
    ImGui.DrawList_AddText(dl, x + w1 + w2, ty, COL.TEXT_MAIN, UI.trunc_c(row.tun, aw - w1 - w2 - 4))
    UI.vgap(0)
  end
  UI.vgap(10)
  ImGui.TextColored(ctx, COL.TEXT_DIM, R.info)
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

-- The window: the toolbar, then one panel (a rounded area) with the track list.
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
