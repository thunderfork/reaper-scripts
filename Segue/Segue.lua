-- @description Segue: Setlist player
-- @version 1.3.1
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   Segue - a setlist for REAPER. Plays the songs (regions) of your project in the order of your show:
--   at the end of each song REAPER stops or goes on with the next song; pauses between songs.
--   The timeline does not change. Requires: the free ReaImGui extension (ReaPack).
-- @provides
--   [main] Segue - Next song.lua
-- @changelog
--   Open automatically and Close with project (gear menu), as in Chart Cue and FX Link.
--   Right-click a setlist row (Go to song, Skip, Move, Remove); Delete removes a row; F2 renames the setlist.
--   Short notices at the bottom of the window instead of OK windows.

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
CFG.TITLE = "Segue"          -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.3.1"        -- keep equal to @version in the header
CFG.EXT = "Segue"              -- ExtState section (REAPER's global settings and the project data)
CFG.PEXT_KEY = "cfg"           -- the project data key
CFG.DATA_DIR = r.GetResourcePath() .. "/Data/Segue" -- the backups and the autostart watcher
CFG.STARTUP_FILE = r.GetResourcePath() .. "/Scripts/__startup.lua"
CFG.AUTOSTART_FILE = CFG.DATA_DIR .. "/autostart.lua"
CFG.AS_BEGIN = "-- >>> Segue autostart (added by Segue; remove with the Segue option) >>>"
CFG.AS_END = "-- <<< Segue autostart <<<"
CFG.AS_BLOCK = CFG.AS_BEGIN .. "\n"
  .. 'pcall(dofile, reaper.GetResourcePath() .. "/Data/Segue/autostart.lua")\n'
  .. CFG.AS_END .. "\n"
CFG.HEARTBEAT = 0.25           -- s between the "Segue runs" signals for the autostart watcher
CFG.SL_EARLY = 0.02            -- the least time before the region end that the end is handled (Setlist.lead)
CFG.SL_GUARD = 0.25            -- after a jump, wait this long for the play position to follow
CFG.DEFAULT_W, CFG.DEFAULT_H = 520, 640
CFG.WIN_EDGE = 6               -- floating window: width of the resize edges (inside the window), as in Chart Cue
CFG.WIN_GRIP = 22              -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 300, 200 -- smallest window size when resizing
CFG.FONT_SIZE = 14             -- the same sizes as Chart Cue
CFG.FONT_SIZE_BOLD = 15        -- section titles
-- The fonts of the "now playing" view (UI.draw_now_view): each made at its own size (bold: NOW_FONT_BOLD)
CFG.NOW_FONT_SIZES = { pill = 13, small = 12, stat = 22, hero = 34, hero_s = 26, time = 21, next = 17,
  row = 21, row_b = 21, row_s = 18, row_sb = 18 }
CFG.NOW_FONT_BOLD = { pill = true, stat = true, hero = true, hero_s = true, time = true, row_b = true, row_sb = true }
CFG.NOW_TEXT_MID = 0.73 -- the middle of the capitals and digits, below the text top (x the font size; measured)
CFG.TEXT_LIFT = 1              -- px the text is raised above the true centre in every control
CFG.HELP_ICON = 20             -- the round "?" icon
CFG.LABEL_W = 190              -- the label column of the settings rows
CFG.FORM_MAX_W = 360           -- the widest control column
CFG.FORM_MIN_WIDE = 220        -- below the label column + this width, the labels go above their control
CFG.CTRL_GAP = 8               -- between 2 controls side by side
CFG.SMALL_BTN_W = 80           -- Add pause
CFG.TB_ICON_W = 32             -- the gear and "?" in the toolbar
-- spacing (pixels; the same gaps as Chart Cue)
CFG.SP_ROW, CFG.SP_EDGE, CFG.SP_PANEL = 7, 8, 4
CFG.SP_TITLE_BEFORE, CFG.SP_TITLE_AFTER, CFG.SP_SECTION = 12, 6, 4
CFG.TB_GROUP_GAP = 25          -- the gap between the play buttons and the hide button (a divider line in the middle)
CFG.ROW_H = 26
CFG.END_W = 110                -- the Stop / Continue dropdown and the pause seconds
CFG.ROW_GAP = 6
CFG.ROW_NAME_MIN_W = 140       -- less room than this for the name puts the row controls on a 2nd line
CFG.TRANSPORT_W, CFG.TRANSPORT_H, CFG.TRANSPORT_GAP = 44, 32, 8
CFG.SPLIT_H = 12               -- the grip between the panel and the "now playing" area (its hit area)
CFG.SPLIT_DEFAULT = 0.6        -- the share of the panel
CFG.GRIP_GAP = 4               -- the gap above and below the grip (measured on Chart Cue: 25 px at 125 %)
CFG.SPLIT_MIN, CFG.SPLIT_MAX = 0.2, 0.85
CFG.LIST_MIN_H, CFG.NOW_MIN_H = 80, 90
CFG.PAUSE_SEC = 10             -- a new pause
CFG.UNDO_MAX = 50              -- undo steps of the setlist rows
CFG.CONFLICT_SEC = 0.5         -- how often Segue checks whether Chart Cue also plays in setlist order
CFG.MORE_W = 110               -- the "More..." dropdown
CFG.SETTINGS_BTN_W = 200       -- the buttons in the gear menu
CFG.PICK_W = 220               -- the setlist dropdown (at most)
CFG.NOTICE_SEC = 4             -- a notice at the bottom of the window shows this long
CFG.TIP_DELAY = 0.5           -- seconds on an item before its tooltip shows (as in Chart Cue)
CFG.TIP_WRAP_EM = 32           -- tooltip lines wrap at this many font sizes

local COL = {
  RED = 0xF26D6DFF, YELLOW = 0xF2C75CFF, GREEN = 0x6FCF8AFF,
  ACCENT = 0x3B82F6FF, ACCENT_HOVER = 0x5B9BFFFF, ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633, HEADING = 0x8DB8FFFF,
  WIN_BG = 0x131518FF, PANEL_BG = 0x1A1C21FF, -- (darker panels: more contrast, as Chart Cue)
  FIELD = 0x2B2F38FF, FIELD_HOVER = 0x333844FF, FIELD_ACTIVE = 0x2C3A55FF,
  BTN = 0x30343EFF, BTN_HOVER = 0x3B404CFF, BTN_ACTIVE = 0x464C5AFF,
  LINE = 0x31353FFF, ROW_HOVER = 0xFFFFFF12, TOGGLE_OFF = 0x4A5060FF,
  TEXT_MAIN = 0xE6E8EEFF, TEXT_DIM = 0x8C93A3FF, TEXT_BRIGHT = 0xEEEEEEFF, WHITE = 0xFFFFFFFF,
  TRANSPARENT = 0x00000000,
  HEADER_HOVER = 0x3B82F655, HEADER_ACTIVE = 0x3B82F677, -- list headers and selectables
  ORANGE = 0xF2994AFF,          -- the status pill "WAITING" / "CHART CUE IN CONTROL"
  TITLE_BG = 0x0F1114FF, TITLE_BG_ACTIVE = 0x1A1C21FF, -- the window title bar (in the theme)
}

-- The themes (gear menu > Light theme): the colours that change. Dark: the values above. Light: light panels, white
-- fields, dark text; the accent stays (the same palette as Chart Cue's light theme).
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
-- Sets the colours of a theme in COL (the style reads COL every frame: no restart).
local function apply_theme(light)
  for k, v in pairs(THEMES[light and "light" or "dark"]) do COL[k] = v end
end

local Util, Project, Setlist, Autostart, UI = {}, {}, {}, {}, {}

-- R: runtime state (not saved). P: the project data (saved in the project). S: settings of this computer.
local R = {
  proj = nil, state_cc = -1, regions = {}, plast_txt = nil, pdirty = false,
  sl_pos = nil,      -- the item of the setlist that plays (or is next, while stopped)
  sl_hold = nil,     -- a pause between songs: { t_end = time } (a timed pause) or {} (waits for Play)
  sl_guard = nil, sl_cursor = nil,
  sl_move = nil, sl_remove = nil,
  frames = 0,
  projfn = "", proj_fp = "", -- the file name and content fingerprint of the project (Close with project)
  hb_t = 0,          -- the last heartbeat (the autostart watcher sees that Segue runs)
}
local P
-- S: the settings of this computer (REAPER's ExtState "Segue", persistent)
local S = {
  split = 0.6,        -- the share of the panel (the grip position)
  settings_open = true, -- the "Setlist settings" section is open
  show_now = true,    -- Settings: the "now playing" area below the list
  show_next = true,   -- Settings: "Next: <song>" in the "now playing" area
  show_times = true,  -- Settings: the set length and the time left in the "now playing" area
  hide_playing = false, -- the toolbar button: the panel is hidden while REAPER plays
  light = false,      -- the gear menu: Light theme (Dark is the default)
  dock = 0,           -- the REAPER docker of the window (0 = floating; a negative number = a REAPER docker)
  close_proj = true,  -- the gear menu: Close with project (Segue closes when its project tab closes or is replaced)
}
local S_BOOLS = { "show_now", "show_next", "show_times", "settings_open", "hide_playing", "light", "close_proj" }
local S_DEFAULTS = {} -- (for "Reset all settings...")
for k, v in pairs(S) do S_DEFAULTS[k] = v end

---------------------------------------------------------------------------
-- REAIMGUI (pinned to 0.9.3 with the official compatibility shim)
---------------------------------------------------------------------------
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("Segue needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end
  else
    r.ShowMessageBox("Segue needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run Segue again.", CFG.TITLE, 0)
  end
end
if not r.ImGui_CreateContext or not r.file_exists(IMGUI_SHIM) then imgui_missing(); return end
if not pcall(function() dofile(IMGUI_SHIM)("0.9.3") end) then imgui_missing(); return end

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
function Util.playing()
  local st = r.GetPlayState()
  return ((st & 1) ~= 0 or (st & 4) ~= 0) and (st & 2) == 0
end
function Util.fmt_mmss(t)
  t = math.max(0, t or 0)
  return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
end
function Util.mark_pdirty() R.pdirty = true end

---------------------------------------------------------------------------
-- PROJECT (regions and the project data)
---------------------------------------------------------------------------
function Project.default() return { setlists = {}, setlist_cur = 1, setlist_on = true, setlist_lock = false } end

-- The key of a region: its GUID (it stays when the region moves or gets a new name); else name and position.
function Project.region_key(guid, name, pos)
  if guid and guid ~= "" then return "g" .. guid:gsub("[^%w%-]", "") end
  return (("n" .. (name or ""):lower() .. "@" .. string.format("%.2f", pos)):gsub("[^%w%-_@%.]", "_"))
end

function Project.scan()
  R.regions = {}
  local proj = R.proj
  local total = r.CountProjectMarkers(proj) or 0
  for i = 0, total - 1 do
    local ok, isrgn, pos, rend, name = r.EnumProjectMarkers3(proj, i)
    if ok and ok > 0 and isrgn then
      local okg, guid = r.GetSetProjectInfo_String(proj, "MARKER_GUID:" .. i, "", false)
      R.regions[#R.regions + 1] = { key = Project.region_key(okg and guid, name, pos), name = name or "", start = pos, stop = rend }
    end
  end
  R.reg_by_key = {}
  for _, rg in ipairs(R.regions) do R.reg_by_key[rg.key] = R.reg_by_key[rg.key] or rg end
end

function Project.region_by_key(key) return R.reg_by_key and R.reg_by_key[key] end

-- The project data, as lines "key=value". Only what differs from the default is written.
function Project.parse(txt)
  local p = Project.default()
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "setlist" then
      p.setlists[#p.setlists + 1] = { name = v, items = {} }
    elseif k == "song" and #p.setlists > 0 then
      local key, ending, skip, nm = v:match("^(.-)\t(.-)\t(.-)\t(.*)$")
      if key and key ~= "" then
        local items = p.setlists[#p.setlists].items
        items[#items + 1] = { key = key, ending = (ending == "continue") and "continue" or "stop", skip = (skip == "1"), name = nm }
      end
    elseif k == "pause" and #p.setlists > 0 then
      local sec, skip = v:match("^(.-)\t(.*)$")
      local items = p.setlists[#p.setlists].items
      items[#items + 1] = { kind = "pause", sec = Util.clamp(math.floor(tonumber(sec) or CFG.PAUSE_SEC), 1, 3600), skip = (skip == "1") }
    elseif k == "setlist_cur" then p.setlist_cur = math.max(1, math.floor(tonumber(v) or 1))
    elseif k == "setlist_on" then p.setlist_on = (v == "1")
    elseif k == "setlist_lock" then p.setlist_lock = (v == "1")
    end
  end
  return p
end

function Project.serialize()
  local t = {}
  local function w(k, v) t[#t + 1] = k .. "=" .. (tostring(v):gsub("[\r\n]", " ")) end
  w("version", 1)
  for _, sl in ipairs(P.setlists) do
    w("setlist", sl.name)
    for _, it in ipairs(sl.items) do
      if it.kind then w("pause", string.format("%d\t%d", it.sec or CFG.PAUSE_SEC, it.skip and 1 or 0))
      else w("song", string.format("%s\t%s\t%d\t%s", it.key, it.ending, it.skip and 1 or 0, ((it.name or ""):gsub("\t", " ")))) end
    end
  end
  if #P.setlists > 0 and P.setlist_cur ~= 1 then w("setlist_cur", P.setlist_cur) end
  if not P.setlist_on then w("setlist_on", 0) end
  if P.setlist_lock then w("setlist_lock", 1) end
  return table.concat(t, "\n")
end

function Project.load()
  local n, txt = r.GetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY)
  if n and n > 0 and txt and txt ~= "" then P = Project.parse(txt); R.plast_txt = txt
  else P = Project.default(); R.plast_txt = Project.serialize() end
  if not P.setlists[P.setlist_cur] then P.setlist_cur = 1 end
  R.sl_pos, R.sl_hold, R.sl_guard, R.sl_cursor, R.sl_undo = nil, nil, nil, nil, nil
  R.cf_t = nil -- (Chart Cue's state belongs to the project: check it again at once)
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

-- The content of a project in short: "Save as" keeps it; another project opened in the same tab changes it.
function Project.fingerprint(proj)
  local nt = r.CountTracks(proj)
  local g1 = nt > 0 and r.GetTrackGUID(r.GetTrack(proj, 0)) or ""
  local _, nm, nr = r.CountProjectMarkers(proj)
  return string.format("%d|%s|%d|%d", nt, g1, nm or 0, nr or 0)
end

-- Close with project (as in Chart Cue and FX Link): true when the project of Segue closed (its tab), or File >
-- Close / New / Open project replaced it in the same tab. Switching tabs and "Save as" are no close.
function Project.closed_or_replaced(proj, fn)
  if R.proj == nil then return false end
  if not r.ValidatePtr2(0, R.proj, "ReaProject*") then return true end
  if proj ~= R.proj or fn == R.projfn then return false end
  if fn == "" then return true end
  local n, txt = r.GetProjExtState(proj, CFG.EXT, CFG.PEXT_KEY)
  if not (n and n > 0) then txt = Project.serialize() end
  return txt ~= R.plast_txt or Project.fingerprint(proj) ~= R.proj_fp
end

-- Every frame: another project tab loads its own data; a project change rescans the regions.
function Project.update()
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if (proj ~= R.proj or fn ~= R.projfn) and Project.closed_or_replaced(proj, fn) then
    R.pdirty = false -- (never write the old setlists into the next project)
    if S.close_proj then R.proj = nil; R.close = true; return end
    R.proj = nil
  end
  if fn ~= R.projfn then R.projfn, R.proj_fp = fn, Project.fingerprint(proj) end
  if proj ~= R.proj then
    Setlist.disarm()
    if R.pdirty then Project.save() end
    R.proj, R.state_cc = proj, -1
    Project.load()
  end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc then
    R.state_cc = cc; Project.scan()
    R.proj_fp = Project.fingerprint(proj) -- (kept up to date: "Save as" later compares with it)
  end
end

---------------------------------------------------------------------------
-- SETLIST (the show order: P.setlists; playback: stop or continue at the end of each song)
---------------------------------------------------------------------------
function Setlist.cur() return P.setlists[P.setlist_cur] end

-- A copy of one row (a song or a pause: every field).
function Setlist.copy_item(it)
  local c = {}
  for k, v in pairs(it) do c[k] = v end
  return c
end

-- Undo of the setlist rows (Ctrl+Z or the undo button): a copy of the rows before each change, at most
-- CFG.UNDO_MAX steps. Cleared when another setlist or project is used.
function Setlist.save_undo(l)
  local u = R.sl_undo
  if not u or u.list ~= l then u = { list = l }; R.sl_undo = u end
  local items = {}
  for i, it in ipairs(l.items) do items[i] = Setlist.copy_item(it) end
  u[#u + 1] = items
  if #u > CFG.UNDO_MAX then table.remove(u, 1) end
end
function Setlist.can_undo(l)
  return R.sl_undo and R.sl_undo.list == l and #R.sl_undo > 0 and not Setlist.locked() and not Util.playing()
end
function Setlist.undo(l)
  if not Setlist.can_undo(l) then return end
  l.items = table.remove(R.sl_undo)
  R.sl_pos = nil; Util.mark_pdirty()
end

-- Another setlist becomes the current one.
function Setlist.pick(i)
  P.setlist_cur = i; R.sl_pos, R.sl_hold = nil, nil; Util.mark_pdirty()
end

-- REAPER's text window for a setlist name (deferred: it is modal). done(name) runs with the new name.
function Setlist.ask_name(title, old, done)
  r.defer(function()
    local ok, txt = r.GetUserInputs(title, 1, "Name:,extrawidth=200,separator=\n", old or "")
    if not ok then return end
    txt = (txt:gsub("[\t\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", ""))
    if txt ~= "" then done(txt) end
  end)
end

-- The "Segue - Next song" action: in setlist order, after a Stop or during a pause it plays (the edit
-- cursor is already at the next song); during a song, and without setlist order, it goes to the next song.
function Setlist.next_cmd()
  local l = Setlist.cur()
  if not l or Setlist.cc_master() then return end -- Chart Cue is master: its own "Next song" action
  if P.setlist_on and (R.sl_hold or not Util.playing()) then
    R.sl_hold = nil; r.OnPlayButton(); R.sl_guard = Util.now() + CFG.SL_GUARD
    return
  end
  Setlist.next_song(l)
end

-- The commands of the action scripts (a queue in the ExtState, read every frame).
function Setlist.read_cmds()
  local q = r.GetExtState(CFG.EXT, "cmd_q")
  if q == "" then return end
  r.SetExtState(CFG.EXT, "cmd_q", "", false)
  for c in q:gmatch("([^,]+)") do
    if c == "nextsong" then Setlist.next_cmd() end
  end
end

-- A new setlist with every region in timeline order.
function Setlist.from_timeline(name)
  local regs = {}
  for _, rg in ipairs(R.regions) do regs[#regs + 1] = rg end
  table.sort(regs, function(a, b) return a.start < b.start end)
  local items = {}
  for _, rg in ipairs(regs) do items[#items + 1] = { key = rg.key, name = rg.name, ending = "stop", skip = false } end
  return { name = name, items = items }
end

-- The region of item i when it plays (a song, not skipped, its region still exists).
function Setlist.region(l, i)
  local it = l.items[i]
  if not it or it.skip or it.kind then return nil end
  return Project.region_by_key(it.key)
end

-- The next song after item i that plays, and its region.
function Setlist.next_from(l, i)
  for j = (i or 0) + 1, #l.items do
    local rg = Setlist.region(l, j)
    if rg then return j, rg end
  end
end

-- The first pause between item i and the next song that plays, or nil.
function Setlist.pause_after(l, i)
  for j = (i or 0) + 1, #l.items do
    local it = l.items[j]
    if not it.skip then
      if it.kind then return it end
      if Project.region_by_key(it.key) then return nil end
    end
  end
end

-- The item that plays at `pos`: first from item `from` on (a region can be in the list more than once).
function Setlist.find(l, pos, from)
  local function inside(j)
    local rg = Setlist.region(l, j)
    return rg and pos >= rg.start - 0.05 and pos < rg.stop
  end
  for j = from or 1, #l.items do if inside(j) then return j end end
  for j = 1, math.min((from or 1) - 1, #l.items) do if inside(j) then return j end end
end

-- The current song from the play cursor (or the edit cursor when stopped).
function Setlist.sync(l)
  local moving = (r.GetPlayState() & 3) ~= 0
  local pos = moving and r.GetPlayPosition() or r.GetCursorPosition()
  local j = Setlist.find(l, pos, R.sl_pos)
  if j then R.sl_pos = j end
end

-- true while Chart Cue is open and plays this project in setlist order ("Chart Cue is master"): then
-- Segue is locked (Setlist.locked) and does nothing at the end of a song, until the user chooses
-- "Use Segue" (UI.draw_conflict). Checked every CFG.CONFLICT_SEC.
-- Segue only reads Chart Cue's heartbeat and its project data; "Use Segue" sends Chart Cue a command.
function Setlist.cc_master()
  local now = Util.now()
  if R.cf_t and now - R.cf_t < CFG.CONFLICT_SEC then return R.cf end
  R.cf_t = now
  local cf = false
  local hb = tonumber(r.GetExtState("ChartCue", "heartbeat"))
  if hb and math.abs(now - hb) < 1.0 then
    local n, txt = r.GetProjExtState(R.proj, "ChartCue", "cfg")
    cf = n > 0 and ("\n" .. txt .. "\n"):find("\nsetlist_on=1\n", 1, true) ~= nil
  end
  R.cf = cf
  return cf
end
-- Both scripts play in setlist order.
function Setlist.conflict() return P.setlist_on and Setlist.cc_master() end
-- The setlist cannot change: Lock setlist (saved), or Chart Cue is master (not saved).
function Setlist.locked() return P.setlist_lock or Setlist.cc_master() end

-- "Use Segue": Chart Cue turns its "Play in setlist order" off (its command queue, like the action
-- scripts), and Segue's is turned on.
function Setlist.take_control()
  local q = r.GetExtState("ChartCue", "cmd_q")
  if #q > 200 then q = "" end
  r.SetExtState("ChartCue", "cmd_q", q .. "setlistoff,", false)
  if not P.setlist_on then P.setlist_on = true; R.sl_pos, R.sl_hold = nil, nil; Util.mark_pdirty() end
  R.cf_t = nil
end

-- REAPER's own exact stop ("armed"). A Stop sent by a script comes too late: REAPER renders up to 200 ms of
-- audio ahead (anticipative FX), so the start of the next song was heard. So during a song that ends with a stop
-- (Stop, a pause after it, or the last song), REAPER's loop points are the song, its option "Stop playback at end
-- of loop if repeat is disabled" (action 41834) is on and Repeat is off: REAPER then stops in its audio engine at
-- the exact end. The loop points, the time selection, the option and Repeat are put back after the stop
-- (Setlist.disarm), also when the script closes.
local ARM_STOP_CMD = 41834
function Setlist.arm(i, rg)
  local a = R.arm
  if a and a.i == i and a.stop == rg.stop then return end
  Setlist.disarm()
  local proj = r.EnumProjects(-1)
  a = { i = i, stop = rg.stop, proj = proj }
  a.ls, a.le = r.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
  a.ts, a.te = r.GetSet_LoopTimeRange2(proj, false, false, 0, 0, false)
  a.opt = r.GetToggleCommandState(ARM_STOP_CMD) == 1
  a.rep = r.GetSetRepeat(-1)
  r.GetSet_LoopTimeRange2(proj, true, true, rg.start, rg.stop, false)
  if not a.opt then r.Main_OnCommand(ARM_STOP_CMD, 0) end
  if a.rep == 1 then r.GetSetRepeat(0) end
  R.arm = a
end

function Setlist.disarm()
  local a = R.arm
  if not a then return end
  R.arm = nil
  if r.ValidatePtr2(0, a.proj, "ReaProject*") then
    r.GetSet_LoopTimeRange2(a.proj, true, true, a.ls, a.le, false)
    r.GetSet_LoopTimeRange2(a.proj, true, false, a.ts, a.te, false)
  end
  if not a.opt and r.GetToggleCommandState(ARM_STOP_CMD) == 1 then r.Main_OnCommand(ARM_STOP_CMD, 0) end
  if a.rep == 1 then r.GetSetRepeat(1) end
end

-- After the stop at the end of item i: the edit cursor goes to the next song; a pause counts down (timed)
-- or waits for Play.
function Setlist.song_ended(l, i, now)
  local j, nrg = Setlist.next_from(l, i)
  if not nrg then return end
  local pause = Setlist.pause_after(l, i)
  R.sl_pos = j; r.SetEditCurPos(nrg.start, true, false)
  R.sl_hold = pause and { t_end = (pause.kind == "pause") and (now + pause.sec) or nil } or {}
end

-- How early the end of a song is handled. REAPER's engine position (GetPlayPosition2) runs ahead of what is
-- heard by the output latency, and a Stop acts only on the next audio block; the setlist is checked once per
-- frame. So the end is handled when the engine is this close to it: 1.5 frames + 1 audio block (measured
-- here every frame). REAPER then stops a few ms before the song end, never in the next song.
function Setlist.lead()
  local now = Util.now()
  local dt = R.sl_tick_t and Util.clamp(now - R.sl_tick_t, 0, 0.2) or 0.033
  R.sl_tick_t = now
  R.sl_dt = Util.clamp((R.sl_dt or 0.033) * 0.9 + dt * 0.1, 0.01, 0.1)
  local blk = Util.clamp(r.GetOutputLatency() or 0.01, 0.002, 0.05)
  return Util.clamp(1.5 * R.sl_dt + blk, CFG.SL_EARLY, 0.15)
end

-- Every frame: while REAPER plays in setlist order, the end of a song stops REAPER (the edit cursor
-- goes to the next song) or goes on with the next song.
function Setlist.tick()
  local lead = Setlist.lead()
  local l = P.setlist_on and Setlist.cur()
  if not l then R.sl_hold = nil; Setlist.disarm(); return end
  if Setlist.cc_master() then R.sl_hold = nil; Setlist.disarm(); return end -- Chart Cue controls the songs until the user chooses
  local now = Util.now()
  -- the armed stop happened (REAPER stopped by itself at the song end): the next song, or a pause
  local a = R.arm
  if a and r.GetPlayState() == 0 then
    Setlist.disarm()
    if a.engine and a.engine >= a.stop - 0.3 then Setlist.song_ended(l, a.i, now) end
  end
  -- a pause between songs (REAPER is stopped, the edit cursor is at the next song): a timed pause
  -- plays on by itself; Play or the "Next song" action end any pause
  local h = R.sl_hold
  if h then
    if Util.playing() then R.sl_hold = nil
    elseif h.t_end and now >= h.t_end then
      R.sl_hold = nil; r.OnPlayButton(); R.sl_guard = now + CFG.SL_GUARD
      return
    end
  end
  if not Util.playing() then
    -- stopped (also while waiting at the next song): follow the edit cursor when it moves; paused: the
    -- pause position is the song, so nothing to follow
    if (r.GetPlayState() & 2) ~= 0 then return end
    local c = r.GetCursorPosition()
    if c ~= R.sl_cursor then R.sl_cursor = c; Setlist.sync(l) end
    return
  end
  if R.sl_guard and now < R.sl_guard then return end
  local pos = r.GetPlayPosition()
  local rg = R.sl_pos and Setlist.region(l, R.sl_pos)
  if not rg or pos < rg.start - 0.05 or pos > rg.stop + 0.1 then
    Setlist.disarm()
    -- a click on the timeline: follow it; outside the songs of the setlist the last song stays current, as
    -- when stopped (previous song goes back to its start, next song to the song after it)
    R.sl_pos = Setlist.find(l, pos, R.sl_pos) or R.sl_pos
    return
  end
  local it = l.items[R.sl_pos]
  local j, nrg = Setlist.next_from(l, R.sl_pos)
  local pause = nrg and Setlist.pause_after(l, R.sl_pos)
  if pause or not (it.ending == "continue" and nrg) then
    Setlist.arm(R.sl_pos, rg) -- REAPER stops by itself at the exact end (see Setlist.arm)
    R.arm.engine = r.GetPlayPosition2()
    return
  end
  Setlist.disarm()
  if r.GetPlayPosition2() < rg.stop - lead then return end -- (the engine position: see Setlist.lead)
  R.sl_pos = j -- Continue
  if math.abs(nrg.start - rg.stop) > 0.01 then -- not directly after it on the timeline: jump
    r.SetEditCurPos(nrg.start, true, true)
    R.sl_guard = now + CFG.SL_GUARD
  end
end

-- The length of the set from item `from` on: all songs and pauses that play (cached for the frame).
function Setlist.length(l, from)
  from = from or 1
  local c = R.sl_len
  if not c or c.frame ~= R.frames or c.list ~= l then c = { frame = R.frames, list = l }; R.sl_len = c end
  if c[from] then return c[from] end
  local s = 0
  for i = from, #l.items do
    local it = l.items[i]
    if not it.skip then
      if it.kind then s = s + it.sec
      else
        local rg = Project.region_by_key(it.key)
        if rg then s = s + (rg.stop - rg.start) end
      end
    end
  end
  c[from] = s
  return s
end

-- The time left in the current song (from the play cursor, or the edit cursor when stopped), or nil.
function Setlist.song_left(l)
  local rg = R.sl_pos and Setlist.region(l, R.sl_pos)
  if not rg then return nil end
  local pos = (r.GetPlayState() & 3) ~= 0 and r.GetPlayPosition() or r.GetCursorPosition()
  return Util.clamp(rg.stop - pos, 0, rg.stop - rg.start)
end

-- The time left in the set: the rest of the current song and everything after it.
function Setlist.time_left(l)
  if not (P.setlist_on and R.sl_pos) then return nil end
  return Setlist.length(l, R.sl_pos + 1) + (Setlist.song_left(l) or 0)
end

function Setlist.name_of(it)
  if it.kind then return "Pause" end
  local rg = Project.region_by_key(it.key)
  if rg then return rg.name ~= "" and rg.name or "(unnamed region)" end
  return ((it.name or "") ~= "" and it.name or "(region)") .. " (missing)"
end

-- Moves the edit cursor (and the play position while playing) to item i.
function Setlist.go(l, i)
  local rg = Project.region_by_key(l.items[i].key or "")
  if not rg then return end
  R.sl_pos, R.sl_hold = i, nil
  r.SetEditCurPos(rg.start, true, Util.playing())
  R.sl_guard = Util.now() + CFG.SL_GUARD
end

function Setlist.prev_song(l)
  Setlist.sync(l)
  -- the play / edit cursor outside the current song (for example moved off the setlist): back to its start
  local rg = R.sl_pos and Setlist.region(l, R.sl_pos)
  local pos = ((r.GetPlayState() & 3) ~= 0) and r.GetPlayPosition() or r.GetCursorPosition()
  if rg and (pos < rg.start - 0.05 or pos >= rg.stop) then Setlist.go(l, R.sl_pos); return end
  for j = (R.sl_pos or 1) - 1, 1, -1 do
    if Setlist.region(l, j) then Setlist.go(l, j); return end
  end
end
function Setlist.next_song(l)
  Setlist.sync(l)
  local j = Setlist.next_from(l, R.sl_pos or 0)
  if j then Setlist.go(l, j) end
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local ctx = ImGui.CreateContext(CFG.TITLE)
local font = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE)
local bold = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE, ImGui.FontFlags_Bold())
local head_font = ImGui.CreateFont("sans-serif", CFG.FONT_SIZE_BOLD, ImGui.FontFlags_Bold())
ImGui.Attach(ctx, font); ImGui.Attach(ctx, bold); ImGui.Attach(ctx, head_font)
local NOW_FONTS = {} -- the fonts of the "now playing" view
for k, s in pairs(CFG.NOW_FONT_SIZES) do
  NOW_FONTS[k] = ImGui.CreateFont("sans-serif", s, CFG.NOW_FONT_BOLD[k] and ImGui.FontFlags_Bold() or 0)
  ImGui.Attach(ctx, NOW_FONTS[k])
end

local HELP_INTRO = "Segue plays your songs in the order of your show. Each song is a REAPER region. "
  .. "Your timeline stays exactly as it is: Segue only changes the order in which the songs play."
-- The Help topics (the "?" button): 1 open at a time.
local HELP_TOPICS = {
  { title = "Getting started", text = [[
1. Make a region for each song (if you have not done it yet).
2. Click "Make a setlist". You get all your songs in timeline order.
3. Put them in the order of your show: drag a row, or use the arrows.
4. Turn on "Play in setlist order" and press Play.

Need a song twice? "Add song..." adds it again at the end. Need a break? "Add pause" adds one.

With "Play in setlist order" off, REAPER plays the timeline as usual and Segue just watches.]] },
  { title = "What happens at the end of a song", text = [[
Each song has an ending:
- Stop: REAPER stops and waits at the start of the next song. Press Play (or your foot pedal) when you are ready.
- Continue: the next song starts right away.

A pause stops REAPER, counts down, and then starts the next song by itself.

Do not want to play a song tonight? Untick it. It stays in the list, but Segue skips it.

Clean stops: when a song ends with a stop, REAPER stops at the exact end of it. You never hear the first notes of the next song. (Segue uses REAPER's loop points and time selection for this, and turns on REAPER's "Stop playback at end of loop" option. When the song is done, or when you stop or move away, you get your own loop points, time selection and option back.)]] },
  { title = "During the show", text = [[
The play buttons: previous song, play / pause, stop (back to the start of the song) and next song.

Hands busy? Give the "Segue - Next song" action a key or a foot pedal in REAPER's Action List. After a stop or during a pause, it starts the next song. During a song, it jumps to the next one.

The "Hide panel when playing" button (right after the play buttons) hides the list while you play, so you only see the big now playing area.

Clicked somewhere on the timeline that is not in the setlist? No problem: Segue remembers the last song. "Previous" goes back to its start, "Next" goes to the song after it.]] },
  { title = "Lock, undo and more setlists", text = [[
Lock setlist: nothing in the list can change, and clicking a song does not jump to it. Good for the show, so a stray click cannot mess things up. The play buttons still work. While REAPER plays, the order is always locked.

Made a mistake? Click the undo arrow or press Ctrl+Z.

Need more than 1 setlist (for example "Friday" and "Festival short")? Pick one in the dropdown. "More..." makes a new one, or copies, renames, resets or deletes the current one.]] },
  { title = "Using Segue with Chart Cue", text = [[
Chart Cue has a setlist too. If Chart Cue is open and its own "Play in setlist order" is on, Chart Cue is in charge of the songs. Segue then locks itself (only Play and Stop work), so the 2 scripts never fight.

Segue shows a notice when this happens. Click "Use Segue" to put Segue in charge instead. If both are on, "Use Chart Cue" turns Segue's off. You can only switch while REAPER is stopped.]] },
  { title = "Now playing area and window", text = [[
Below the list is the now playing area: the current song in large text, the time left, the next song and the time left in the set.

Drag the grip between the list and that area to change their sizes. Double-click the grip to reset it.

The gear button has the settings: what the now playing area shows, Light theme, Open automatically and Close with project, docking, Reset window position, and Back up / Restore / Reset all settings.

Right-click an empty part of the list for a quick menu: Settings, Help, dock and close.]] },
  { title = "Where your stuff is saved", text = [[
In the project: your setlists, which setlist is current, "Play in setlist order" and the lock. Save the project to keep them.

On this computer: the settings and the window. "Back up..." in the gear menu saves them to a file in REAPER's Data\Segue folder.]] },
}

local SL_ENDINGS = { "stop", "continue" }
local SL_ENDING_ITEMS = "Stop\0Continue\0"

function UI.tip(text)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
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

-- Section heading, as in Chart Cue: bold, blue, a full-width blue underline, a "?" at the right.
-- fold: the name of a boolean in S; then an arrow before the title opens / closes the section.
-- Returns open. R.heading_x1 / R.heading_y: the free end of the title line (for a button there).
function UI.heading(text, help, fold)
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
  local open = true
  ImGui.PushFont(ctx, head_font)
  if fold then
    open = S[fold] == true
    local fh = ImGui.GetFrameHeight(ctx)
    local clicked = ImGui.InvisibleButton(ctx, "##fold_" .. fold, 14, fh)
    local hov = ImGui.IsItemHovered(ctx)
    local dl, cx, cy = ImGui.GetWindowDrawList(ctx), sx + 6, sy + fh / 2
    local col = hov and COL.TEXT_MAIN or COL.HEADING
    if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col)
    else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col) end
    ImGui.SameLine(ctx, 0, 2)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, text)
    clicked = clicked or ImGui.IsItemClicked(ctx)
    if hov or ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    if clicked then open = not open; S[fold] = open; R.sdirty = true end
  else
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, text)
  end
  ImGui.PopFont(ctx)
  local _, ty = ImGui.GetItemRectMax(ctx)
  R.heading_x1, R.heading_y = sx + full - (help and CFG.HELP_ICON + 8 or 0), sy
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

-- A toggle with its text at the right (the Settings menu).
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

-- Small square row button with a drawn icon ("up", "down", "undo"); a grey background on hover.
-- lit = false: not available now (faint).
function UI.icon_button(id, size, kind, lit)
  local hit = ImGui.InvisibleButton(ctx, id, size, size)
  local hov = ImGui.IsItemHovered(ctx)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  if hov and lit ~= false then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
    ImGui.DrawList_AddRectFilled(dl, x0 + 2, y0 + 2, x0 + size - 2, y0 + size - 2, COL.BTN_HOVER, 4)
  end
  local cx, cy = math.floor(x0 + size / 2) + 0.5, math.floor(y0 + size / 2) + 0.5
  local col = (lit == false and ((COL.TEXT_DIM & 0xFFFFFF00) | 0x60)) or (hov and COL.TEXT_BRIGHT) or COL.TEXT_MAIN
  if kind == "up" then
    ImGui.DrawList_AddTriangleFilled(dl, cx - 5, cy + 3, cx + 5, cy + 3, cx, cy - 3, col)
  elseif kind == "down" then
    ImGui.DrawList_AddTriangleFilled(dl, cx - 5, cy - 3, cx + 5, cy - 3, cx, cy + 3, col)
  else -- undo: a curved arrow to the left
    ImGui.DrawList_PathArcTo(dl, cx, cy + 2, 5, math.pi, 2 * math.pi)
    ImGui.DrawList_PathStroke(dl, col, 0, 1.6)
    ImGui.DrawList_PathLineTo(dl, cx - 8, cy - 0.5)
    ImGui.DrawList_PathLineTo(dl, cx - 5, cy + 2.5)
    ImGui.DrawList_PathLineTo(dl, cx - 2, cy - 0.5)
    ImGui.DrawList_PathStroke(dl, col, 0, 1.6)
  end
  return hit and lit ~= false
end

-- Transport icons like REAPER's: previous / next song, play, pause, stop.
function UI.draw_transport_icon(dl, cx, cy, kind, col)
  if kind == "play" then
    ImGui.DrawList_AddTriangleFilled(dl, cx - 5, cy - 7, cx - 5, cy + 7, cx + 7, cy, col)
  elseif kind == "pause" then
    ImGui.DrawList_AddRectFilled(dl, cx - 6, cy - 7, cx - 2, cy + 7, col)
    ImGui.DrawList_AddRectFilled(dl, cx + 2, cy - 7, cx + 6, cy + 7, col)
  elseif kind == "stop" then
    ImGui.DrawList_AddRectFilled(dl, cx - 6, cy - 6, cx + 6, cy + 6, col, 1)
  elseif kind == "prev" then
    ImGui.DrawList_AddRectFilled(dl, cx - 7, cy - 6, cx - 5, cy + 6, col)
    ImGui.DrawList_AddTriangleFilled(dl, cx + 6, cy - 6, cx + 6, cy + 6, cx - 4, cy, col)
  else
    ImGui.DrawList_AddRectFilled(dl, cx + 5, cy - 6, cx + 7, cy + 6, col)
    ImGui.DrawList_AddTriangleFilled(dl, cx - 6, cy - 6, cx - 6, cy + 6, cx + 4, cy, col)
  end
end

-- The "Hide panel when playing" icon (as in Chart Cue): a window with an arrow up (on) or down (off).
function UI.draw_hide_icon(dl, cx, cy, on, col)
  ImGui.DrawList_AddRect(dl, cx - 7, cy - 6, cx + 7, cy + 6, col, 2, 0, 1.5)
  ImGui.DrawList_AddLine(dl, cx - 7, cy - 2.5, cx + 7, cy - 2.5, col, 1.5)
  local d = on and 1.5 or -1.5
  ImGui.DrawList_PathLineTo(dl, cx - 3, cy + 1.5 + d)
  ImGui.DrawList_PathLineTo(dl, cx, cy + 1.5 - d)
  ImGui.DrawList_PathLineTo(dl, cx + 3, cy + 1.5 + d)
  ImGui.DrawList_PathStroke(dl, col, 0, 1.5)
end

-- Gear icon (the Settings button): a ring with 8 teeth.
function UI.draw_gear_icon(dl, cx, cy, col)
  for k = 0, 7 do
    local a = k * math.pi / 4
    local c, sn = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * 5, cy + sn * 5, cx + c * 8.5, cy + sn * 8.5, col, 3)
  end
  ImGui.DrawList_AddCircle(dl, cx, cy, 4.5, col, 0, 3)
end

-- The Settings menu (the gear button): what the "now playing" area shows, and docking.
function UI.draw_settings()
  R.settings_open = ImGui.BeginPopup(ctx, "##settings")
  if not R.settings_open then return end
  ImGui.PushFont(ctx, head_font)
  ImGui.TextColored(ctx, COL.HEADING, "Now playing area")
  ImGui.PopFont(ctx)
  local ch
  ch, S.show_now = UI.toggle_line("Show the now playing area", S.show_now,
    "The area below the panel: the current song in large text, the time left and the next song.")
  if ch then R.sdirty = true end
  ImGui.BeginDisabled(ctx, not S.show_now)
  ch, S.show_next = UI.toggle_line("Show the next song", S.show_next)
  if ch then R.sdirty = true end
  ch, S.show_times = UI.toggle_line("Show the set length and the time left", S.show_times)
  if ch then R.sdirty = true end
  ImGui.EndDisabled(ctx)
  local function head(t)
    UI.vgap(8)
    ImGui.PushFont(ctx, head_font)
    ImGui.TextColored(ctx, COL.HEADING, t)
    ImGui.PopFont(ctx)
  end
  head("Look")
  ch, S.light = UI.toggle_line("Light theme", S.light,
    "On: light panels and fields, dark text (for daylight or a light REAPER theme). Off: Dark, for dark stages (the default).")
  if ch then apply_theme(S.light); R.sdirty = true end
  head("Automatic open and close")
  local on = Autostart.installed()
  ch, on = UI.toggle_line("Open automatically", on,
    "Segue opens by itself when you open a project that has Segue setlists. It adds 3 marked lines to REAPER's "
    .. "__startup.lua (with a backup). Needs one REAPER restart after you change it.")
  if ch then
    local msg = on and Autostart.install() or (not on and Autostart.uninstall()) or nil
    if msg then ImGui.CloseCurrentPopup(ctx); UI.notice(msg) end
  end
  ch, S.close_proj = UI.toggle_line("Close with project", S.close_proj,
    "Segue closes when its project tab closes, or when File > Close / New / Open project replaces it. "
    .. "Switching tabs and 'Save as' keep it open.")
  if ch then R.sdirty = true end
  head("Window")
  local docked = R.docked == true
  if UI.toggle_line("Dock in REAPER's docker", docked, "On: Segue is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  local bw = CFG.SETTINGS_BTN_W
  if UI.button("Reset window position", bw) then R.reset_win = true; ImGui.CloseCurrentPopup(ctx) end
  UI.tip("Moves the window back to its default size and place, and undocks it.")
  head("Backup")
  if UI.button("Back up...", bw) then
    local path, err = Util.backup_settings()
    UI.ask(path and ("Backup saved:\n" .. path) or err, nil)
    ImGui.CloseCurrentPopup(ctx)
  end
  UI.tip("Saves a copy of the settings of this computer in " .. Util.backup_dir())
  if UI.button("Restore...", bw) then
    ImGui.CloseCurrentPopup(ctx)
    local okf, path = r.GetUserFileNameForRead(Util.backup_dir() .. "/", "Restore Segue settings", ".txt")
    if okf and path ~= "" then
      UI.ask("Replace the Segue settings of this computer with this backup?\n" .. path, "Replace", function()
        local okr, err = Util.restore_settings(path)
        if not okr then UI.notice(err, true) end
      end)
    end
  end
  UI.tip("Loads a backup. It asks before it replaces anything.")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
  local reset = UI.button("Reset all settings...", bw)
  ImGui.PopStyleColor(ctx)
  UI.tip("Sets the settings of this computer back to the defaults. Your setlists are not changed.")
  if reset then
    ImGui.CloseCurrentPopup(ctx)
    UI.ask("Set all Segue settings of this computer back to the defaults? Your setlists (in the projects) are not "
      .. "changed.", "Yes, reset", Util.reset_settings)
  end
  UI.vgap(8)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Segue " .. CFG.VERSION .. "  -  MIT license")
  ImGui.EndPopup(ctx)
end

-- The right-click menu on an empty part of the panel.
function UI.draw_panel_menu()
  if R.pmenu then ImGui.OpenPopup(ctx, "##panelmenu"); R.pmenu = false end
  if not ImGui.BeginPopup(ctx, "##panelmenu") then return end
  if ImGui.MenuItem(ctx, "Settings...") then R.settings_req = true end
  if ImGui.MenuItem(ctx, "Help") then R.help_open = true end
  ImGui.Separator(ctx)
  local docked = R.docked == true
  if ImGui.MenuItem(ctx, "Dock Segue in Docker", nil, docked) then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if ImGui.MenuItem(ctx, "Close Segue") then R.close = true end
  ImGui.EndPopup(ctx)
end

-- The Help window (a popup in the window).
function UI.draw_help()
  if R.help_open then ImGui.OpenPopup(ctx, "Segue Help##help"); R.help_open = false end
  local vw, vh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowSize(ctx, math.min(520, math.max(260, vw - 40)), math.min(560, math.max(240, vh - 40)),
    ImGui.Cond_Appearing())
  if ImGui.BeginPopupModal(ctx, "Segue Help##help", true) then
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
      ImGui.TextColored(ctx, COL.TEXT_DIM, "Segue " .. CFG.VERSION .. "  -  MIT license")
      ImGui.PopTextWrapPos(ctx)
      ImGui.EndChild(ctx)
    end
    UI.vgap(8)
    if UI.button("Close", 90) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

-- The toolbar (on the dark window background): the 4 play buttons in the centre (previous song,
-- play / pause, stop: back to the song start, next song); the gear and "?" at the right.
function UI.draw_toolbar(l)
  local BW, BH, G = CFG.TRANSPORT_W, CFG.TRANSPORT_H, CFG.TRANSPORT_GAP
  UI.vgap(CFG.SP_EDGE)
  local x0 = ImGui.GetCursorPosX(ctx)
  local y0 = ImGui.GetCursorPosY(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local IW = CFG.TB_ICON_W
  if l then
    local GG = CFG.TB_GROUP_GAP
    ImGui.SetCursorPosX(ctx, x0 + math.max(0, (aw - 2 * IW - 5 * BW - 3 * G - GG) / 2))
    local playing = Util.playing()
    local function btn(id, icon, tip, kind)
      local hit = UI.button("##tp_" .. id, BW, BH, kind)
      local bx0, by0 = ImGui.GetItemRectMin(ctx)
      local bx1, by1 = ImGui.GetItemRectMax(ctx)
      UI.draw_transport_icon(ImGui.GetWindowDrawList(ctx), math.floor((bx0 + bx1) / 2) + 0.5, math.floor((by0 + by1) / 2) + 0.5,
        icon, kind and COL.WHITE or COL.TEXT_MAIN)
      UI.tip(tip)
      return hit
    end
    local master = Setlist.cc_master()
    ImGui.BeginDisabled(ctx, master)
    if btn("prev", "prev", "Previous song") then Setlist.prev_song(l) end
    ImGui.EndDisabled(ctx)
    local function master_tip()
      if master and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
        ImGui.SetTooltip(ctx, "Chart Cue controls the setlist: use its buttons or its 'Next song' action.")
      end
    end
    master_tip()
    ImGui.SameLine(ctx, 0, G)
    if btn("play", playing and "pause" or "play", playing and "Pause" or "Play", playing and "primary" or nil) then
      if playing then r.OnPauseButton() else R.sl_hold = nil; r.OnPlayButton(); R.sl_guard = Util.now() + CFG.SL_GUARD end
    end
    ImGui.SameLine(ctx, 0, G)
    if btn("stop", "stop", "Stop (back to the start of the song)") then
      R.sl_hold = nil; r.OnStopButton()
      local rg = not master and R.sl_pos and Setlist.region(l, R.sl_pos) -- (Chart Cue in control: only stop)
      if rg then r.SetEditCurPos(rg.start, true, false) end
    end
    ImGui.SameLine(ctx, 0, G)
    ImGui.BeginDisabled(ctx, master)
    if btn("next", "next", "Next song (also the 'Segue - Next song' action, for a key or a foot pedal)") then
      Setlist.next_song(l)
    end
    ImGui.EndDisabled(ctx)
    master_tip()
    -- the divider line, then "Hide panel when playing" (blue while on)
    local lx, ly = ImGui.GetItemRectMax(ctx)
    local dlx = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddLine(dlx, lx + GG / 2, ly - BH + 6, lx + GG / 2, ly - 6, COL.LINE, 1)
    ImGui.SameLine(ctx, 0, GG)
    local on = S.hide_playing
    if UI.button("##hidectl", BW, BH, on and "primary" or nil) then S.hide_playing = not on; R.sdirty = true end
    local hx0, hy0 = ImGui.GetItemRectMin(ctx)
    local hx1, hy1 = ImGui.GetItemRectMax(ctx)
    UI.draw_hide_icon(dlx, math.floor((hx0 + hx1) / 2) + 0.5, math.floor((hy0 + hy1) / 2) + 0.5, on,
      on and COL.WHITE or COL.TEXT_MAIN)
    UI.tip(on and "Hide panel when playing: on. During playback the panel is hidden; only the now playing area shows.\nClick to keep it."
      or "Hide panel when playing: off. Click to hide the panel during playback.")
  end
  -- the gear and "?" at the right end (plain icons, a grey background on hover)
  local dl = ImGui.GetWindowDrawList(ctx)
  local function icon(id, x, tip)
    ImGui.SetCursorPos(ctx, x, y0)
    local hit = ImGui.InvisibleButton(ctx, id, IW, BH)
    local hov = ImGui.IsItemHovered(ctx)
    local ix, iy = ImGui.GetItemRectMin(ctx)
    if hov then
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
      ImGui.DrawList_AddRectFilled(dl, ix, iy, ix + IW, iy + BH, COL.BTN_HOVER, 6)
    end
    UI.tip(tip)
    return hit, ix + IW / 2, iy + BH / 2, hov
  end
  -- the gear: the Settings menu drops down below it (right edge in line with the gear; it never covers the gear).
  -- A click on the gear while the menu is open closes it (the click outside closes it at mouse down: not again open).
  local hit, cx, cy, hov = icon("##gear", x0 + aw - 2 * IW, "Settings")
  if ImGui.IsItemActivated(ctx) then R.gear_toggle = R.settings_open end
  local gx1, gy1 = ImGui.GetItemRectMax(ctx)
  if R.settings_open and not hov then ImGui.DrawList_AddRectFilled(dl, gx1 - IW, gy1 - BH, gx1, gy1, COL.BTN_HOVER, 6) end
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
  ImGui.SetCursorPos(ctx, x0, y0 + BH)
  UI.vgap(CFG.SP_EDGE)
end

-- A question with 2 buttons (a popup in the window). UI.ask opens it; UI.draw_ask draws it every frame.
-- (yes = nil: a message with only "OK")
-- A question (yes = the button text): a window. Without a question: a notice at the bottom of the window (as FX Link).
function UI.ask(text, yes, fn)
  if not yes then UI.notice(text); return end
  R.ask = { text = text, yes = yes, fn = fn, open = true }
end
-- The notice below the panel (after it: a cursor move is always followed by the text). ah: the panel height.
function UI.draw_notice(aw, ah)
  local at, n = R.notice_at, R.notice
  if not (at and n) then return end
  ImGui.SetCursorScreenPos(ctx, at[1] + 8, at[2] + ah + 4)
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + aw - 16)
  ImGui.TextColored(ctx, n.warn and COL.ORANGE or COL.TEXT_DIM, n.text)
  ImGui.PopTextWrapPos(ctx)
end
-- A short notice at the bottom of the window (grey; warn: orange); it goes away after CFG.NOTICE_SEC.
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
function UI.draw_ask()
  local a = R.ask
  if not a then return end
  if a.open then ImGui.OpenPopup(ctx, "Segue##ask"); a.open = false end
  -- always in the centre of the window when it opens (a moved question does not keep its place)
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if ImGui.BeginPopupModal(ctx, "Segue##ask", nil, ImGui.WindowFlags_AlwaysAutoResize()) then
    ImGui.PushTextWrapPos(ctx, 360)
    ImGui.Text(ctx, a.text)
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    if a.yes then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
      local yes = UI.button(a.yes, 120)
      ImGui.PopStyleColor(ctx)
      if yes then R.ask = nil; ImGui.CloseCurrentPopup(ctx); a.fn() end
      ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
      if UI.button("Cancel", 90) then R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
    elseif UI.button("OK", 90) then R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  else
    R.ask = nil
  end
end

-- The "More..." menu: new, duplicate, rename, reset or delete a setlist.
function UI.draw_more(l)
  ImGui.SetNextItemWidth(ctx, CFG.MORE_W)
  if not ImGui.BeginCombo(ctx, "##more", "More...") then UI.tip("New, duplicate, rename, reset or delete a setlist."); return end
  if ImGui.Selectable(ctx, "New setlist...") then
    Setlist.ask_name("Segue - New setlist", "Setlist " .. (#P.setlists + 1), function(n)
      P.setlists[#P.setlists + 1] = Setlist.from_timeline(n); Setlist.pick(#P.setlists)
    end)
  end
  if ImGui.Selectable(ctx, "Duplicate...") then
    Setlist.ask_name("Segue - Duplicate setlist", l.name .. " (copy)", function(n)
      local items = {}
      for _, it in ipairs(l.items) do items[#items + 1] = Setlist.copy_item(it) end
      P.setlists[#P.setlists + 1] = { name = n, items = items }; Setlist.pick(#P.setlists)
    end)
  end
  if ImGui.Selectable(ctx, "Rename...") then
    Setlist.ask_name("Segue - Rename setlist", l.name, function(n) l.name = n; Util.mark_pdirty() end)
  end
  ImGui.Separator(ctx)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED) -- the 2 items that remove your work
  local reset, del = ImGui.Selectable(ctx, "Reset to timeline order..."), ImGui.Selectable(ctx, "Delete setlist...")
  ImGui.PopStyleColor(ctx)
  if reset then
    UI.ask("Reset '" .. l.name .. "' to all regions in timeline order? Your order, skipped songs and endings "
      .. "in this setlist are lost (Undo brings them back).", "Yes, reset", function()
        Setlist.save_undo(l)
        l.items = Setlist.from_timeline(l.name).items; R.sl_pos = nil; Util.mark_pdirty()
      end)
  end
  if del then
    UI.ask("Delete the setlist '" .. l.name .. "'? The regions stay in the project.", "Yes, delete", function()
      table.remove(P.setlists, P.setlist_cur)
      Setlist.pick(math.max(1, math.min(P.setlist_cur, #P.setlists)))
    end)
  end
  ImGui.EndCombo(ctx)
end

local SETTINGS_HELP = "The order of the songs in your show. Each song is a region; the timeline does not change.\n\n"
  .. "Play in setlist order: at the end of each song REAPER stops (the edit cursor goes to the next song) "
  .. "or goes on with the next song (Continue).\n\n"
  .. "A region can be in the list more than once. During playback (and with Lock setlist) the order is locked.\n\n"
  .. "Saved in this project."
local LIST_HELP = "The time: all songs and pauses that play (from the current song on: the time left). Click a song "
  .. "to go to it. Drag a row, or use the arrows, to change the order. The tick box: play or skip. The X removes "
  .. "the song from this setlist (or the Delete key on a row). Right-click a row: Go to song, Skip, Move to top / bottom, Remove. "
  .. "The arrow at the right of this title: undo (Ctrl+Z). F2 renames the setlist."

-- Section 1 of the panel, "Setlist settings": the setlist and More..., Lock setlist, Play in setlist order,
-- Add song and Add pause.
function UI.draw_settings_section(l, playing)
  if not UI.heading("Setlist settings", SETTINGS_HELP, "settings_open") then return end
  local ch, nv
  local master = Setlist.cc_master()
  ImGui.BeginDisabled(ctx, master)
  ch, nv = UI.checkbox("Lock setlist", Setlist.locked(), master
    and "On while Chart Cue controls the setlist (not saved). Your own setting comes back after that."
    or ("On: the setlist cannot change (greyed out), and a click on a song does not go to it.\n"
    .. "The play buttons still work. Saved in this project."))
  ImGui.EndDisabled(ctx)
  if ch and not master then P.setlist_lock = nv; Util.mark_pdirty() end
  ImGui.BeginDisabled(ctx, Setlist.locked())
  ch, P.setlist_on = UI.checkbox("Play in setlist order", P.setlist_on,
    "On: at the end of each song REAPER stops or goes on with the next song of the setlist.\n"
    .. "Off: REAPER plays the timeline as usual.")
  if ch then R.sl_pos, R.sl_hold = nil, nil; Util.mark_pdirty() end
  ImGui.EndDisabled(ctx)
  do
    local _, cw = UI.row_start("Current setlist")
    ImGui.BeginDisabled(ctx, playing or Setlist.locked())
    ImGui.SetNextItemWidth(ctx, math.max(80, math.min(CFG.PICK_W, cw - CFG.MORE_W - CFG.CTRL_GAP)))
    if ImGui.BeginCombo(ctx, "##pick", l.name) then
      for i, s in ipairs(P.setlists) do
        if ImGui.Selectable(ctx, s.name .. "##sl" .. i, i == P.setlist_cur) and i ~= P.setlist_cur then Setlist.pick(i) end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("The setlist that plays. A project can have more than 1 setlist.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    UI.draw_more(l)
    ImGui.EndDisabled(ctx)
  end
  do
    local _, cw = UI.row_start("Add song")
    local pw = UI.btn_w("Add pause", CFG.SMALL_BTN_W)
    ImGui.BeginDisabled(ctx, playing or Setlist.locked())
    ImGui.SetNextItemWidth(ctx, math.max(80, math.min(CFG.PICK_W, cw - pw - CFG.CTRL_GAP)))
    if ImGui.BeginCombo(ctx, "##add", "Choose a region...") then
      for i, rg in ipairs(R.regions) do
        if ImGui.Selectable(ctx, (rg.name ~= "" and rg.name or "(unnamed region)") .. "##ra" .. i) then
          Setlist.save_undo(l)
          l.items[#l.items + 1] = { key = rg.key, name = rg.name, ending = "stop", skip = false }; Util.mark_pdirty()
        end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip("Adds the region at the end of the setlist. A region can be in the list more than once.")
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Add pause", pw, nil, "ghost") then
      Setlist.save_undo(l)
      l.items[#l.items + 1] = { kind = "pause", sec = CFG.PAUSE_SEC, skip = false }; Util.mark_pdirty()
    end
    UI.tip("Adds a pause at the end of the setlist (10 seconds; change it in its row). Drag it to its place.\n"
      .. "REAPER stops at the end of the song before it, then plays the next song after the seconds.")
    ImGui.EndDisabled(ctx)
  end
end

-- One row: # | name | length | the end of the song (or the pause seconds) | play / skip | up, down | remove.
-- In a narrow panel the controls go to a 2nd line.
function UI.draw_row(l, i, locked)
  local it = l.items[i]
  ImGui.PushID(ctx, i)
  local x = ImGui.GetCursorPosX(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx) - 4
  local fh = ImGui.GetFrameHeight(ctx)
  local G = CFG.ROW_GAP
  local right_w = CFG.END_W + G + fh + G + 3 * (fh + 2)
  local narrow = (aw - right_w - 30 - 64) < CFG.ROW_NAME_MIN_W
  local line_w = narrow and 0 or (right_w + 8)
  local rg = not it.kind and Project.region_by_key(it.key)
  local here = P.setlist_on and R.sl_pos == i
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local name_area = aw - line_w
  -- the current song: a blue background and a blue bar at the left (as in Chart Cue)
  if here then
    ImGui.DrawList_AddRectFilled(dl, sx - 6, sy - 2, sx + aw, sy + fh + 2, COL.ACTIVE_BG, 4)
    ImGui.DrawList_AddRectFilled(dl, sx - 6, sy - 2, sx - 3, sy + fh + 2, COL.ACCENT, 2)
  end
  -- the row: a click goes to the song; drag it onto another row to move it
  if ImGui.InvisibleButton(ctx, "##row", math.max(1, name_area), fh) and rg and not Setlist.locked() then Setlist.go(l, i) end
  local hovered = ImGui.IsItemHovered(ctx)
  if ImGui.IsItemClicked(ctx, 1) then R.rowmenu, R.rowmenu_open = i, true end -- (the row menu, opened after the rows)
  if hovered and not locked and not ImGui.IsAnyItemActive(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Delete(), false) then
    R.sl_remove = i -- (Delete: Remove from setlist; Ctrl+Z undoes it)
  end
  if hovered then
    ImGui.DrawList_AddRectFilled(dl, sx - 6, sy - 2, sx + name_area, sy + fh + 2, COL.ROW_HOVER, 4)
    if rg and not Setlist.locked() then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    ImGui.SetTooltip(ctx, (it.kind and "A pause: REAPER stops, then plays the next song by itself.")
      or (Setlist.cc_master() and rg and "Chart Cue controls the setlist: clicks do not change the song.")
      or (P.setlist_lock and rg and "Lock setlist is on: clicks do not change the song.")
      or (rg and ("Click to go to this song" .. (Util.playing() and " (playback moves there)." or ".")))
      or "This region is not in the project any more.")
  end
  if not locked and ImGui.BeginDragDropSource(ctx) then
    ImGui.SetDragDropPayload(ctx, "SEGUE_ROW", tostring(i))
    ImGui.Text(ctx, Setlist.name_of(it))
    ImGui.EndDragDropSource(ctx)
  end
  if not locked and ImGui.BeginDragDropTarget(ctx) then
    local ok, payload = ImGui.AcceptDragDropPayload(ctx, "SEGUE_ROW")
    if ok then R.sl_move = { from = tonumber(payload), to = i } end
    ImGui.EndDragDropTarget(ctx)
  end
  -- the texts, drawn over the row
  local ty = UI.text_y(sy)
  local col = (it.kind and COL.YELLOW) or (not rg and COL.YELLOW) or (it.skip and COL.TEXT_DIM)
    or (here and COL.ACCENT) or COL.TEXT_MAIN
  ImGui.DrawList_AddText(dl, sx, ty, COL.TEXT_DIM, tostring(i))
  local len = it.kind and "" or (rg and Util.fmt_mmss(rg.stop - rg.start) or "")
  local lw = (ImGui.CalcTextSize(ctx, len))
  local name = Setlist.name_of(it) .. (it.skip and "  (skipped)" or "")
  local f = here and bold or font
  ImGui.PushFont(ctx, f)
  name = UI.trunc(name, math.max(20, name_area - 30 - lw - 24))
  ImGui.PopFont(ctx)
  ImGui.DrawList_AddTextEx(dl, f, CFG.FONT_SIZE, sx + 30, ty, col, name)
  if len ~= "" then ImGui.DrawList_AddText(dl, sx + name_area - lw - 10, ty, COL.TEXT_DIM, len) end
  -- the controls (narrow: on the 2nd line, at the right)
  if narrow then ImGui.SetCursorPosX(ctx, math.max(x + 30, x + aw - right_w))
  else ImGui.SameLine(ctx, x + aw - right_w) end
  ImGui.SetNextItemWidth(ctx, CFG.END_W)
  ImGui.BeginDisabled(ctx, Setlist.locked())
  if it.kind then
    local ch, sec = ImGui.InputInt(ctx, "##sec", it.sec, 5, 30)
    if ImGui.IsItemActivated(ctx) then Setlist.save_undo(l) end -- one undo step per edit of the field
    if ch then it.sec = Util.clamp(sec, 1, 3600); Util.mark_pdirty() end
    UI.tip("The pause in seconds. Then the next song plays by itself (Play starts it earlier).")
  else
    local ei = (it.ending == "continue") and 1 or 0
    local ch, ni = ImGui.Combo(ctx, "##end", ei, SL_ENDING_ITEMS)
    if ch then Setlist.save_undo(l); it.ending = SL_ENDINGS[ni + 1]; Util.mark_pdirty() end
    UI.tip("At the end of this song: Stop (the edit cursor goes to the next song; press Play to go on)\n"
      .. "or Continue (the next song plays at once). A pause after the song always stops.")
  end
  ImGui.EndDisabled(ctx)
  -- play / skip, up, down, remove (not during playback, so the show order cannot change by mistake)
  ImGui.BeginDisabled(ctx, locked)
  ImGui.SameLine(ctx, 0, G)
  local sch, nv = ImGui.Checkbox(ctx, "##play", not it.skip)
  if sch then Setlist.save_undo(l); it.skip = not nv; Util.mark_pdirty() end
  UI.tip("Ticked: this row plays. Not ticked: it is skipped (it stays in the list).")
  ImGui.SameLine(ctx, 0, G)
  if UI.icon_button("##up", fh, "up", i > 1) then R.sl_move = { from = i, to = i - 1 } end
  UI.tip("Move up")
  ImGui.SameLine(ctx, 0, 2)
  if UI.icon_button("##down", fh, "down", i < #l.items) then R.sl_move = { from = i, to = i + 1 } end
  UI.tip("Move down")
  ImGui.SameLine(ctx, 0, 2)
  if UI.remove_x_button("##rm", fh) then R.sl_remove = i end
  UI.tip("Remove from this setlist (the region stays in the project).")
  ImGui.EndDisabled(ctx)
  ImGui.PopID(ctx)
end

-- Section 2 of the panel: the title "Setlist (n) - time", the undo button and the rows.
-- The changes are made after the list is drawn.
function UI.draw_list_section(l, playing)
  local nsongs = 0
  for _, it in ipairs(l.items) do if not it.kind then nsongs = nsongs + 1 end end
  local left = Setlist.time_left(l)
  local lock_txt = (Setlist.cc_master() and "  -  locked: Chart Cue controls the setlist")
    or (P.setlist_lock and "  -  locked") or (playing and "  -  order locked during playback") or ""
  UI.heading(string.format("Setlist (%d)  -  %s%s%s", nsongs, Util.fmt_mmss(Setlist.length(l)),
    left and ("  (" .. Util.fmt_mmss(left) .. " left)") or "", lock_txt), LIST_HELP)
  -- undo: at the right end of the title line, before the "?"
  do
    local fh = ImGui.GetFrameHeight(ctx)
    local bx, by = ImGui.GetCursorScreenPos(ctx)
    ImGui.SetCursorScreenPos(ctx, R.heading_x1 - fh, R.heading_y)
    local can = Setlist.can_undo(l)
    if UI.icon_button("##undo", fh, "undo", can) then Setlist.undo(l) end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, can and "Undo the last setlist change (Ctrl+Z)." or "Nothing to undo (or the setlist is locked, or REAPER plays).")
    end
    ImGui.SetCursorScreenPos(ctx, bx, by)
  end
  if #l.items == 0 then ImGui.TextColored(ctx, COL.TEXT_DIM, "No songs yet. Add a song above."); return end
  R.sl_move, R.sl_remove = nil, nil
  local locked = playing or Setlist.locked()
  for i = 1, #l.items do UI.draw_row(l, i, locked) end
  -- the right-click menu of a row (as in Chart Cue's Setlist tab)
  if R.rowmenu_open then ImGui.OpenPopup(ctx, "##rowmenu"); R.rowmenu_open = nil end
  if ImGui.BeginPopup(ctx, "##rowmenu") then
    local i = R.rowmenu
    local it = i and l.items[i]
    if it then
      local rg = not it.kind and Project.region_by_key(it.key)
      if ImGui.MenuItem(ctx, "Go to song", nil, false, rg and not Setlist.locked() or false) then Setlist.go(l, i) end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, it.skip and "Play this row" or "Skip this row", nil, false, not locked) then
        Setlist.save_undo(l); it.skip = not it.skip; Util.mark_pdirty()
      end
      if ImGui.MenuItem(ctx, "Move to top", nil, false, not locked and i > 1) then R.sl_move = { from = i, to = 1 } end
      if ImGui.MenuItem(ctx, "Move to bottom", nil, false, not locked and i < #l.items) then R.sl_move = { from = i, to = #l.items } end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, "Remove from setlist", "Del", false, not locked) then R.sl_remove = i end
    else
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.EndPopup(ctx)
  end
  local mv = R.sl_move
  if mv and mv.from and mv.from ~= mv.to and l.items[mv.from] and l.items[mv.to] then
    Setlist.save_undo(l)
    local it = table.remove(l.items, mv.from)
    table.insert(l.items, mv.to, it)
    R.sl_pos = nil; Util.mark_pdirty()
  end
  if R.sl_remove and l.items[R.sl_remove] then
    Setlist.save_undo(l)
    table.remove(l.items, R.sl_remove)
    R.sl_pos = nil; Util.mark_pdirty()
  end
end

-- The notice while Chart Cue is master: a yellow box with the question and its buttons ("Use Chart Cue"
-- only when both play in setlist order). Not during playback: the control does not change during a song.
function UI.draw_conflict()
  if not Setlist.cc_master() then return end
  local both = Setlist.conflict()
  local playing = Util.playing()
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx) - 4
  local fh = ImGui.GetFrameHeight(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.Indent(ctx, 12)
  UI.vgap(10)
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + aw - 24)
  ImGui.PushFont(ctx, bold)
  ImGui.TextColored(ctx, COL.YELLOW, both and "Chart Cue also plays this project in setlist order."
    or "Chart Cue controls the setlist of this project.")
  ImGui.PopFont(ctx)
  ImGui.Text(ctx, (both and "Only 1 script can control the end of each song. Until you choose, Chart Cue keeps control. "
    or "") .. "Segue is locked: it does nothing at the end of a song, and only Play and Stop work here.")
  ImGui.PopTextWrapPos(ctx)
  UI.vgap(6)
  local bw = math.max(UI.btn_w("Use Segue", 120), UI.btn_w("Use Chart Cue", 120))
  local function tip(txt)
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, playing and "Not during playback: stop REAPER first." or txt)
    end
  end
  ImGui.BeginDisabled(ctx, playing)
  if UI.button("Use Segue", bw, fh, "primary") then Setlist.take_control() end
  tip("Chart Cue turns off its \"Play in setlist order\" (in this project), and Segue's is turned on.\n"
    .. "Segue controls the songs.")
  if both then
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Use Chart Cue", bw, fh) then P.setlist_on = false; R.sl_pos, R.sl_hold = nil, nil; Util.mark_pdirty() end
    tip("Segue turns off its \"Play in setlist order\" (in this project). Chart Cue controls the songs.")
  end
  ImGui.EndDisabled(ctx)
  UI.vgap(10)
  ImGui.Unindent(ctx, 12)
  local _, y1 = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRect(dl, x0, y0, x0 + aw, y1 - CFG.SP_ROW, COL.YELLOW, 6, 0, 1.5)
end

-- The panel content: an empty state, or the 2 sections.
function UI.draw_panel_content(l, playing)
  if #R.regions == 0 then
    UI.heading("Setlist")
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No regions yet. Make 1 region for each song in REAPER.")
    return
  end
  if not l then
    UI.heading("Setlist")
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No setlist yet. Make one from the regions of this project, in timeline order.")
    UI.vgap(6)
    if UI.button("Make a setlist", UI.btn_w("Make a setlist", 160), nil, "primary") then
      P.setlists[1] = Setlist.from_timeline("Setlist 1"); P.setlist_cur = 1; Util.mark_pdirty()
    end
    return
  end
  UI.draw_conflict()
  UI.draw_settings_section(l, playing)
  UI.vgap(CFG.SP_SECTION)
  UI.draw_list_section(l, playing)
end

-- The grip between the panel and the "now playing" area (as in Chart Cue): drag it; a double-click resets it.
function UI.draw_grip(total_h)
  local gx, gy = ImGui.GetCursorScreenPos(ctx)
  local aw = math.max(1, ImGui.GetContentRegionAvail(ctx))
  ImGui.InvisibleButton(ctx, "##grip", aw, CFG.SPLIT_H)
  local hov, act = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
  if hov or act then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS()) end
  if act then
    local _, dy = ImGui.GetMouseDelta(ctx)
    if dy ~= 0 then S.split = Util.clamp(S.split + dy / math.max(1, total_h), CFG.SPLIT_MIN, CFG.SPLIT_MAX); R.sdirty = true end
  end
  if hov and ImGui.IsMouseDoubleClicked(ctx, 0) then S.split = CFG.SPLIT_DEFAULT; R.sdirty = true end
  if hov and not act then ImGui.SetTooltip(ctx, "Drag to change the sizes.\nDouble-click: back to the default.") end
  local dl = ImGui.GetWindowDrawList(ctx)
  -- on whole pixels (as in Chart Cue): a half-pixel position draws the pill 1 px thicker
  local cx, cy = math.floor(gx + aw / 2), math.floor(gy + CFG.SPLIT_H / 2)
  if hov or act then ImGui.DrawList_AddLine(dl, gx + 8, cy, gx + aw - 8, cy, COL.ACCENT, 1) end
  ImGui.DrawList_AddRectFilled(dl, cx - 32, cy - 2.5, cx + 32, cy + 2.5, (hov or act) and COL.ACCENT or COL.TEXT_DIM, 3)
end

local NOW_FONT_SIZES = CFG.NOW_FONT_SIZES

-- The "now playing" view, the same design in Chart Cue and Segue, in 3 bands:
-- 1. the status band: a coloured pill (Playing, Ready, Pause, Waiting, Paused) and the set length / time left;
-- 2. the current song: its name (large), the time left in it and a progress bar, and the next song;
-- 3. the setlist: large rows; the current song stays in view. The end of each song is an icon:
--    a red square (Stop) or a green triangle (Continue).
-- A small area drops the list band first, then the progress bar and the next song.
-- Every text uses a font made at its own size (NOW_FONT_SIZES), never a scaled one.
-- (x0, y0, w, h): the area, on the window's draw list; the background is drawn by the caller.
function UI.draw_now_view(l, x0, y0, w, h, small, show_next, show_times)
  local F = NOW_FONTS
  local dl = ImGui.GetWindowDrawList(ctx)
  local PAD = 16
  local playing = Util.playing()
  local paused = (r.GetPlayState() & 2) ~= 0
  local hold = R.sl_hold
  local on = P.setlist_on
  local function tw(fk, txt)
    ImGui.PushFont(ctx, F[fk])
    local x = (ImGui.CalcTextSize(ctx, txt))
    ImGui.PopFont(ctx)
    return x
  end
  -- text whose capital letters are centred on cy (Segoe UI: the middle of the capitals and digits is CFG.NOW_TEXT_MID x the size below the text top)
  local function text(fk, x, cy, col, txt)
    local s = NOW_FONT_SIZES[fk]
    ImGui.DrawList_AddTextEx(dl, F[fk], s, x, math.floor(cy - s * CFG.NOW_TEXT_MID + 0.5), col, txt)
  end
  local memo = R.fit_memo or {} -- the shortened texts (not shortened again every frame)
  R.fit_memo = memo
  local function fit(fk, txt, max_w) -- the text cut with "..." to max_w
    if tw(fk, txt) <= max_w then return txt end
    local key = fk .. "\t" .. math.floor(max_w) .. "\t" .. txt
    if memo[key] then return memo[key] end
    local out = "..."
    local n = utf8.len(txt) or #txt
    while n > 1 do
      n = n - 1
      local c = txt:sub(1, (utf8.offset(txt, n + 1) or (n + 1)) - 1) .. "..."
      if tw(fk, c) <= max_w then out = c; break end
    end
    R.fit_n = (R.fit_memo and R.fit_n or 0) + 1
    if R.fit_n > 300 then R.fit_memo, R.fit_n = nil, 0 end -- (a new window width: start again)
    memo[key] = out
    return out
  end
  local function song_name(it)
    if it.kind then return "Pause" end
    local rg = Project.region_by_key(it.key)
    if rg then return rg.name ~= "" and rg.name or "(unnamed region)" end
    return ((it.name or "") ~= "" and it.name or "(region)") .. " (missing)"
  end
  ImGui.DrawList_PushClipRect(dl, x0, y0, x0 + w, y0 + h, true)
  -- 1. the status band
  local pill_txt, pill_col
  if Setlist.cc_master() then pill_txt, pill_col = "CHART CUE IN CONTROL", COL.ORANGE
  elseif not on then pill_txt, pill_col = "SETLIST ORDER OFF", COL.TEXT_DIM
  elseif hold and hold.t_end then pill_txt, pill_col = "PAUSE", COL.YELLOW
  elseif hold then pill_txt, pill_col = "WAITING  -  PRESS PLAY", COL.ORANGE
  elseif playing then pill_txt, pill_col = "PLAYING", COL.GREEN
  elseif paused then pill_txt, pill_col = "PAUSED", COL.TEXT_DIM
  else pill_txt, pill_col = "READY", COL.ACCENT_HOVER end
  local band_h = 52
  local cy = y0 + band_h / 2
  local ph = 28
  local pw = 12 + 8 + 8 + tw("pill", pill_txt) + 14 -- left padding, dot, gap, text, right padding
  local px = x0 + PAD
  ImGui.DrawList_AddRectFilled(dl, px, cy - ph / 2, px + pw, cy + ph / 2, (pill_col & 0xFFFFFF00) | 0x2E, ph / 2)
  ImGui.DrawList_AddCircleFilled(dl, px + 16, cy, 4, pill_col)
  text("pill", px + 28, cy, pill_col, pill_txt)
  if show_times and l then
    local left = Setlist.time_left(l)
    local x = x0 + w - PAD
    -- the label and the value share one baseline (0.81 x the size below the text top)
    local vs, ls = NOW_FONT_SIZES.stat, NOW_FONT_SIZES.small
    local vy = math.floor(cy - vs * CFG.NOW_TEXT_MID + 0.5)
    local function stat(label, value)
      x = x - tw("stat", value)
      ImGui.DrawList_AddTextEx(dl, F.stat, vs, x, vy, COL.TEXT_BRIGHT, value)
      x = x - tw("small", label) - 8
      ImGui.DrawList_AddTextEx(dl, F.small, ls, x, vy + math.floor((vs - ls) * 0.81 + 0.5), COL.TEXT_DIM, label)
      x = x - 24
    end
    if left then stat("LEFT", Util.fmt_mmss(left)) end
    if x > px + pw + 40 then stat("SET", Util.fmt_mmss(Setlist.length(l))) end
  end
  local y = y0 + band_h
  ImGui.DrawList_AddLine(dl, x0 + PAD, y, x0 + w - PAD, y, COL.LINE, 1)
  if not (l and on) then ImGui.DrawList_PopClipRect(dl); return end
  -- 2. the current song (in a pause: the next song, which is already the current item)
  local cur = R.sl_pos
  local it = cur and l.items[cur]
  local rg = it and not it.kind and Project.region_by_key(it.key)
  local hk = small and "hero_s" or "hero"
  local rk, rbk = small and "row_s" or "row", small and "row_sb" or "row_b"
  local hero_h = NOW_FONT_SIZES[hk] + 16
  local time_h = NOW_FONT_SIZES.time + 14
  local next_h = NOW_FONT_SIZES.next + 14
  local lh = math.floor(NOW_FONT_SIZES[rk] * 1.75)
  local free = y0 + h - y
  local full = free >= hero_h + time_h + next_h + 16
  local with_list = free >= hero_h + time_h + next_h + 32 + 2 * lh
  y = y + 10
  local name = fit(hk, it and song_name(it) or "-", w - 2 * PAD)
  text(hk, x0 + (w - tw(hk, name)) / 2, y + hero_h / 2, hold and COL.YELLOW or COL.TEXT_BRIGHT, name)
  y = y + hero_h
  if free >= hero_h + time_h + 10 then
    -- the time left in the song (or until the pause ends) and its progress
    local left, frac, txt
    if hold and hold.t_end then
      left = math.max(0, hold.t_end - Util.now())
      local tot = 0
      for j = (cur or 1) - 1, 1, -1 do if l.items[j].kind then tot = l.items[j].sec; break end end
      frac = tot > 0 and (1 - left / tot) or 0
      txt = "starts in " .. Util.fmt_mmss(math.ceil(left))
    elseif hold then
      txt = rg and Util.fmt_mmss(rg.stop - rg.start) or ""
    elseif rg then
      local pos = (r.GetPlayState() & 3) ~= 0 and r.GetPlayPosition() or r.GetCursorPosition()
      left = Util.clamp(rg.stop - pos, 0, rg.stop - rg.start)
      frac = (rg.stop > rg.start) and (1 - left / (rg.stop - rg.start)) or 0
      txt = Util.fmt_mmss(left) .. " left"
    end
    local col = hold and COL.YELLOW or COL.ACCENT_HOVER
    local tcy = y + time_h / 2
    if txt and txt ~= "" then
      local bar_w = (frac and full and not small) and math.min(360, w - 2 * PAD - 180) or 0
      local txt_w = tw("time", txt)
      local total = txt_w + (bar_w > 60 and (bar_w + 16) or 0)
      local x = x0 + (w - total) / 2
      text("time", x, tcy, col, txt)
      if bar_w > 60 then
        local bx = x + txt_w + 16
        ImGui.DrawList_AddRectFilled(dl, bx, tcy - 3, bx + bar_w, tcy + 3, COL.TOGGLE_OFF, 3)
        ImGui.DrawList_AddRectFilled(dl, bx, tcy - 3, bx + math.max(6, bar_w * Util.clamp(frac, 0, 1)), tcy + 3, col, 3)
      end
    end
    y = y + time_h
    if show_next and full and not hold then
      local j = Setlist.next_from(l, cur or 0)
      if j then
        local nt = fit("next", "Next: " .. song_name(l.items[j]), w - 2 * PAD)
        text("next", x0 + (w - tw("next", nt)) / 2, y + next_h / 2, COL.TEXT_MAIN, nt)
      end
      y = y + next_h
    end
  end
  -- 3. the setlist
  if with_list then
    y = y + 8
    ImGui.DrawList_AddLine(dl, x0 + PAD, y, x0 + w - PAD, y, COL.LINE, 1)
    y = y + 8
    local fit_n = math.max(1, math.floor((y0 + h - y - 4) / lh))
    local c = cur or 1
    local first = (#l.items <= fit_n) and 1 or Util.clamp(c - 1, 1, #l.items - fit_n + 1)
    local dur_w = tw(rbk, "00:00")
    local ic = math.floor(NOW_FONT_SIZES[rk] * 0.5) -- the size of the end icon
    for i = first, #l.items do
      if y + lh > y0 + h + 2 then break end
      local li = l.items[i]
      local lrg = not li.kind and Project.region_by_key(li.key)
      local here = i == cur
      local col = (li.skip and COL.TEXT_DIM) or (here and COL.ACCENT_HOVER) or (li.kind and COL.YELLOW)
        or ((cur and i < cur) and COL.TEXT_DIM) or COL.TEXT_MAIN
      local rcy = y + lh / 2 -- the row centre: the highlight, the texts and the icon
      if here then
        ImGui.DrawList_AddRectFilled(dl, x0 + 8, rcy - lh / 2 + 2, x0 + w - 8, rcy + lh / 2 - 2, COL.ACTIVE_BG, 6)
        ImGui.DrawList_AddRectFilled(dl, x0 + 8, rcy - lh / 2 + 2, x0 + 11, rcy + lh / 2 - 2, COL.ACCENT, 2)
      end
      local fk = here and rbk or rk
      text(rk, x0 + PAD + 4, rcy, COL.TEXT_DIM, tostring(i))
      local nx = x0 + PAD + 4 + NOW_FONT_SIZES[rk] * 2
      local dx = x0 + w - PAD - dur_w
      local icx = dx - 18 - ic / 2 -- the end icon, centred on the row
      local nm = fit(fk, song_name(li) .. (li.skip and "  (skipped)" or ""), icx - ic - 16 - nx)
      text(fk, nx, rcy, col, nm)
      if not li.kind then
        local half = ic / 2
        if li.ending == "continue" then -- a green play triangle: the next song plays at once
          ImGui.DrawList_AddTriangleFilled(dl, icx - half + 1, rcy - half - 1, icx - half + 1, rcy + half + 1,
            icx + half + 2, rcy, li.skip and COL.TEXT_DIM or COL.GREEN)
        else -- a red square: REAPER stops after this song
          ImGui.DrawList_AddRectFilled(dl, icx - half, rcy - half, icx + half, rcy + half,
            li.skip and COL.TEXT_DIM or COL.RED, 2)
        end
      end
      local dur = li.kind and li.sec or (lrg and (lrg.stop - lrg.start)) or 0
      local dtxt = Util.fmt_mmss(dur)
      text(fk, dx + dur_w - tw(fk, dtxt), rcy, li.kind and COL.YELLOW or (here and COL.ACCENT_HOVER or COL.TEXT_DIM), dtxt)
      y = y + lh
    end
  end
  ImGui.DrawList_PopClipRect(dl)
end

-- The "now playing" area below the panel (the panel colour, rounded).
function UI.draw_now(l, w, h)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  ImGui.Dummy(ctx, w, h)
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), x0, y0, x0 + w, y0 + h, COL.PANEL_BG, 8)
  if l then UI.draw_now_view(l, x0, y0, w, h, false, S.show_next, S.show_times) end
end

-- The window: the toolbar, the panel (a rounded area that scrolls), the grip and the "now playing" area.
function UI.draw_main()
  local playing = Util.playing()
  local l = #R.regions > 0 and Setlist.cur() or nil
  if l and ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) and not ImGui.IsAnyItemActive(ctx)
    and ImGui.IsKeyChordPressed and ImGui.IsKeyChordPressed(ctx, ImGui.Mod_Ctrl() | ImGui.Key_Z()) then
    Setlist.undo(l)
  end
  if l and ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) and not ImGui.IsAnyItemActive(ctx)
    and ImGui.IsKeyPressed(ctx, ImGui.Key_F2(), false) then -- F2: rename the setlist (as FX Link's groups)
    Setlist.ask_name("Segue - Rename setlist", l.name, function(n) l.name = n; Util.mark_pdirty() end)
  end
  UI.draw_toolbar(l)
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  local nh = UI.notice_h(aw - 16)
  ah = ah - CFG.SP_EDGE - nh
  R.notice_at = nh > 0 and { ImGui.GetCursorScreenPos(ctx) } or nil -- (drawn after the panel: UI.draw_notice)
  local show_now = S.show_now and l ~= nil
  if show_now and S.hide_playing and playing then -- only the now playing area
    UI.draw_now(l, aw, ah)
    UI.draw_notice(aw, ah)
    return
  end
  -- the panel, the grip and the area share the height; ImGui's row gap comes after the panel and the grip
  -- (counted here, so the window never needs a scrollbar)
  local split_h = CFG.SPLIT_H + 2 * CFG.GRIP_GAP
  local panel_h = show_now and math.max(CFG.LIST_MIN_H, math.floor((ah - split_h) * S.split)) or ah
  local now_h = ah - panel_h - split_h
  if show_now and now_h < CFG.NOW_MIN_H then panel_h, now_h = ah, 0 end -- too small: only the panel
  if not show_now then now_h = 0 end
  local px, py = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + aw, py + panel_h, COL.PANEL_BG, 8)
  if ImGui.BeginChild(ctx, "##panel", aw, panel_h) then
    ImGui.SetCursorPosY(ctx, CFG.SP_PANEL)
    ImGui.Indent(ctx, 10)
    UI.draw_panel_content(l, playing)
    ImGui.Unindent(ctx, 10)
    ImGui.Dummy(ctx, 0, CFG.SP_PANEL)
    if ImGui.IsMouseClicked(ctx, 1) and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows())
      and not ImGui.IsAnyItemHovered(ctx) and not ImGui.IsPopupOpen(ctx, "##rowmenu") then R.pmenu = true end
    ImGui.EndChild(ctx)
  end
  UI.draw_panel_menu()
  if now_h > 0 then
    UI.vgap(CFG.GRIP_GAP)
    UI.draw_grip(ah - split_h)
    UI.vgap(CFG.GRIP_GAP)
    UI.draw_now(l, aw, now_h)
  end
  UI.draw_notice(aw, ah)
end

---------------------------------------------------------------------------
-- WINDOW (the same resize edges, corner grip and docked-tab triangle as Chart Cue)
---------------------------------------------------------------------------
-- Floating window: the resize edges and corner grip of Chart Cue (ImGui's are about 1 px wide; the window
-- uses WindowFlags_NoResize). R.rs = the running resize: edge flags + start mouse / window.
-- Called before Begin: applies a running resize.
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
local function load_settings()
  local function get(k) return r.GetExtState(CFG.EXT, k) end
  S.split = Util.clamp(tonumber(get("split")) or CFG.SPLIT_DEFAULT, CFG.SPLIT_MIN, CFG.SPLIT_MAX)
  for _, k in ipairs(S_BOOLS) do
    local v = get(k)
    if v ~= "" then S[k] = (v == "1") end
  end
  S.dock = math.floor(tonumber(get("dock")) or 0)
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
local function save_settings()
  r.SetExtState(CFG.EXT, "split", string.format("%.3f", S.split), true)
  for _, k in ipairs(S_BOOLS) do r.SetExtState(CFG.EXT, k, S[k] and "1" or "0", true) end
  r.SetExtState(CFG.EXT, "dock", tostring(S.dock), true)
  R.sdirty = false
end

-- Backup / Restore / Reset all settings (the gear menu)
function Util.backup_dir() return r.GetResourcePath() .. "/Data/Segue" end
local function settings_lines()
  local lines = { "split=" .. string.format("%.3f", S.split), "dock=" .. tostring(S.dock) }
  for _, k in ipairs(S_BOOLS) do lines[#lines + 1] = k .. "=" .. (S[k] and "1" or "0") end
  return lines
end
function Util.backup_settings()
  local dir = Util.backup_dir()
  r.RecursiveCreateDirectory(dir, 0)
  local path = dir .. "/Segue backup " .. os.date("%Y-%m-%d %H-%M") .. ".txt"
  local f = io.open(path, "w")
  if not f then return nil, "The backup file cannot be written: " .. path end
  f:write("Segue backup\n# Segue " .. CFG.VERSION .. ", " .. os.date("%Y-%m-%d %H:%M") .. "\n",
    table.concat(settings_lines(), "\n"), "\n")
  f:close()
  return path
end
local function apply_settings()
  apply_theme(S.light)
  R.dock_req = S.dock
  R.sdirty = true
end
function Util.restore_settings(path)
  local f = io.open(path, "r")
  if not f then return nil, "The file cannot be read." end
  if f:read("l") ~= "Segue backup" then f:close(); return nil, "This is not a Segue backup file." end
  for k, v in pairs(S_DEFAULTS) do S[k] = v end -- (a setting that is not in the backup: its default)
  for line in f:lines() do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "split" then S.split = Util.clamp(tonumber(v) or CFG.SPLIT_DEFAULT, CFG.SPLIT_MIN, CFG.SPLIT_MAX)
    elseif k == "dock" then S.dock = math.floor(tonumber(v) or 0)
    elseif k and type(S_DEFAULTS[k]) == "boolean" then S[k] = (v == "1") end
  end
  f:close()
  apply_settings()
  return true
end
function Util.reset_settings()
  for k, v in pairs(S_DEFAULTS) do S[k] = v end
  S.split = CFG.SPLIT_DEFAULT
  S.dock = R.docked and S.dock or 0 -- (the window stays where it is)
  apply_theme(S.light)
  R.sdirty = true
end

---------------------------------------------------------------------------
-- AUTOSTART: "Open automatically" (as in Chart Cue): Segue opens for every project that has Segue setlists.
-- A small watcher (Data\Segue\autostart.lua) is started from REAPER's __startup.lua. Segue adds ONE marked
-- block at the END of __startup.lua (after a backup) and removes only that block. Your own code never changes.
---------------------------------------------------------------------------
local AUTOSTART_SCRIPT = [=[
-- Segue autostart watcher (written by Segue - do not edit, it is overwritten).
-- Opens Segue when a project that has Segue setlists opens or becomes the active tab.
local r = reaper
local last_proj, last_fn = nil, nil
local next_t, wait_until, pending_until, cooldown_until = 0, 0, 0, 0
local function running()
  local hb = tonumber(r.GetExtState("Segue", "heartbeat"))
  return hb ~= nil and math.abs(r.time_precise() - hb) < 1.0
end
local function tick()
  local t = r.time_precise()
  if t >= next_t then
    next_t = t + 0.1
    local proj, fn = r.EnumProjects(-1)
    fn = fn or ""
    if proj ~= last_proj or fn ~= last_fn then
      last_proj, last_fn = proj, fn
      local n = r.GetProjExtState(proj, "Segue", "cfg")
      if n and n > 0 then wait_until, pending_until = t + 0.5, t + 3.5 else pending_until = 0 end
    end
    if t < pending_until and t >= wait_until and t >= cooldown_until then
      if running() then
        pending_until = 0
      else
        local name = r.GetExtState("Segue", "cmd")
        local id = (name ~= "") and r.NamedCommandLookup(name) or 0
        if id ~= 0 then r.Main_OnCommand(id, 0) end
        cooldown_until, pending_until = t + 3, 0
      end
    end
  end
  r.defer(tick)
end
tick()
]=]

local function read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*a"); f:close()
  return d
end
local function write_all(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data); f:close()
  return true
end

-- The command ID of Segue (the watcher starts it by this name).
function Autostart.command_string()
  local _, _, _, cmd = r.get_action_context()
  if not cmd or cmd == 0 then return nil end
  local named = r.ReverseNamedCommandLookup(cmd)
  if named and named ~= "" then return named:sub(1, 1) == "_" and named or ("_" .. named) end
  return tostring(cmd)
end

-- Reads __startup.lua only when asked to refresh; cached otherwise.
function Autostart.installed(refresh)
  if refresh or R.as_installed == nil then
    local d = read_all(CFG.STARTUP_FILE)
    R.as_installed = (d ~= nil and d:find(CFG.AS_BEGIN, 1, true) ~= nil)
  end
  return R.as_installed
end

function Autostart.write_script()
  r.RecursiveCreateDirectory(CFG.DATA_DIR, 0)
  return write_all(CFG.AUTOSTART_FILE, AUTOSTART_SCRIPT)
end

-- Returns a message for the user.
function Autostart.install()
  if Autostart.installed(true) then return "Open automatically is already on." end
  local ans = r.ShowMessageBox(
    "Segue will add these 3 lines at the END of your REAPER startup script:\n\n"
    .. CFG.STARTUP_FILE .. "\n\n" .. CFG.AS_BLOCK .. "\n"
    .. "Your own code in that file is not changed. A backup is saved as __startup.lua.segue-backup.\n"
    .. "Restart REAPER once after this change.\n\nContinue?", CFG.TITLE, 1)
  if ans ~= 1 then return nil end
  if not Autostart.write_script() then return "Cannot write " .. CFG.AUTOSTART_FILE end
  local old = read_all(CFG.STARTUP_FILE)
  local backup = CFG.STARTUP_FILE .. ".segue-backup"
  if old and not (write_all(backup, old) and read_all(backup) == old) then
    return "Cannot write the backup " .. backup .. ". __startup.lua was not changed."
  end
  local f = io.open(CFG.STARTUP_FILE, "ab")
  if not f then return "Cannot write " .. CFG.STARTUP_FILE end
  if old and old ~= "" and old:sub(-1) ~= "\n" then f:write("\n") end
  f:write("\n", CFG.AS_BLOCK); f:close()
  Autostart.installed(true)
  return "Open automatically is on. Restart REAPER once to start it."
end

function Autostart.uninstall()
  local d = read_all(CFG.STARTUP_FILE)
  if not d then Autostart.installed(true); return nil end
  local a = d:find(CFG.AS_BEGIN, 1, true)
  local b = a and d:find(CFG.AS_END, a, true)
  if not (a and b) then Autostart.installed(true); return nil end
  local stop = b + #CFG.AS_END
  if d:sub(stop, stop) == "\n" then stop = stop + 1 end
  local start = a
  if start > 1 and d:sub(start - 1, start - 1) == "\n" then start = start - 1 end -- (the blank line Segue added)
  if not write_all(CFG.STARTUP_FILE, d:sub(1, start - 1) .. d:sub(stop)) then return "Cannot write " .. CFG.STARTUP_FILE end
  Autostart.installed(true)
  return "Open automatically is off. It stops after the next REAPER restart."
end

local function loop()
  R.frames = R.frames + 1
  local now = Util.now()
  if now - R.hb_t >= CFG.HEARTBEAT then -- the autostart watcher sees that Segue runs
    R.hb_t = now
    r.SetExtState(CFG.EXT, "heartbeat", tostring(now), false)
  end
  Project.update()
  if R.close then return end -- (Close with project: stop now, before anything reads the closed project)
  Setlist.read_cmds()
  Setlist.tick()
  ImGui.SetNextWindowSize(ctx, CFG.DEFAULT_W, CFG.DEFAULT_H, ImGui.Cond_FirstUseEver())
  if R.dock_req then ImGui.SetNextWindowDockID(ctx, R.dock_req); R.dock_req = nil end
  UI.pre_begin()
  if R.reset_win then -- "Reset window position"
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
    -- the docker in use (also after a drag onto a docker): kept for the next start
    local id = ImGui.GetWindowDockID(ctx)
    R.docked = ImGui.IsWindowDocked(ctx)
    if id ~= S.dock then S.dock = id; R.sdirty = true end
    UI.draw_main()
    UI.draw_ask()
    UI.draw_help()
    if not R.docked then UI.edges() else R.rs = nil end -- resize edges: floating only
    ImGui.End(ctx)
  end
  UI.pop_style()
  ImGui.PopFont(ctx)
  if R.pdirty and not ImGui.IsAnyItemActive(ctx) then Project.save() end
  if R.sdirty and not ImGui.IsMouseDown(ctx, 0) then save_settings() end
  if R.close then open = false end
  if open then r.defer(loop) end
end

local function on_exit()
  Setlist.disarm() -- (the loop points and REAPER's options as they were)
  if R.pdirty then Project.save() end
  if R.sdirty then save_settings() end
  r.DeleteExtState(CFG.EXT, "heartbeat", false)
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end

-- tests/segue.lua sets SegueTest: hand it the modules and do not start the UI
local test = rawget(_G, "SegueTest")
if test then
  test.CFG, test.S, test.R, test.Util, test.Project, test.Setlist = CFG, S, R, Util, Project, Setlist
  test.get_P = function() return P end
  test.set_P = function(p) P = p end
  return
end

-- A second start closes the running Segue (REAPER 7: no question).
if r.set_action_options then r.set_action_options(1) end
do
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end
end
load_settings()
apply_theme(S.light)
do -- the autostart watcher finds Segue by its command ID (kept); keep the watcher up to date
  local cs = Autostart.command_string()
  if cs then r.SetExtState(CFG.EXT, "cmd", cs, true) end
  if Autostart.installed(true) then Autostart.write_script() end
end
r.atexit(on_exit)
r.defer(loop)
