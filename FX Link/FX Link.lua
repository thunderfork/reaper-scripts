-- @description FX Link: link plugin instances across tracks
-- @version 1.1.1
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   FX Link - move a knob in one plugin, and the same knob moves in the other plugins of its link group.
--   Put instances of the same plugin (for example FabFilter Pro-Q 3 on 4 guitar tracks) in a group.
--   Exact: all instances get the same value. Relative: all instances get the same change.
--   Link all parameters or only the ones you pick (Learn, or a list with search). Match, Link bypass,
--   Show / Hide plugins, Add all in project. The groups are saved in the project.
--   The links work while the FX Link window is open (docked or floating); it can open and close by itself.
--   Requires: the free ReaImGui extension (ReaPack).
-- @provides
--   [main] FX Link - Show plugins.lua
--   [main] FX Link - Toggle group.lua
--   [main] FX Link - Group focused plugin on selected tracks.lua
-- @changelog
--   Automation and LFOs are no longer copied; Pause 1 plugin; Snapshots A / B with Compare, without false "differ".
--   "+ Add" menus: a new group from the focused plugin on the selected tracks (also an action); empty groups ask which plugin.
--   Right-click a plugin row, F2 / Delete keys; short notices instead of OK windows.

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
CFG.TITLE = "FX Link"          -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.1.1"           -- keep equal to @version in the header
CFG.EXT = "FX Link"            -- ExtState section (this computer) and the project data section
CFG.PEXT_KEY = "cfg"           -- the project data key
CFG.DEFAULT_W, CFG.DEFAULT_H = 460, 560
CFG.WIN_EDGE = 6               -- floating window: width of the resize edges (inside the window), as in Chart Cue
CFG.WIN_GRIP = 22              -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 300, 220
CFG.FONT_SIZE = 14             -- the same sizes as Chart Cue
CFG.FONT_SIZE_BOLD = 15        -- section titles
CFG.TEXT_LIFT = 1              -- px the text is raised above the true centre in every control
CFG.HELP_ICON = 20             -- the round "?" icon
CFG.LABEL_W = 130              -- the label column of Link settings (Mode, Parameters, Link bypass)
CFG.FORM_MAX_W = 300           -- the widest control column
CFG.FORM_MIN_WIDE = 180        -- below the label column + this width, the labels go above their control
CFG.CTRL_GAP = 8               -- between 2 controls side by side
CFG.SP_ROW, CFG.SP_EDGE, CFG.SP_PANEL = 7, 8, 4 -- spacing (pixels; the same gaps as Chart Cue)
CFG.SP_TITLE_BEFORE, CFG.SP_TITLE_AFTER = 12, 6
CFG.ROW_H = 26
CFG.X_BTN = 22                 -- the round remove button
CFG.MODE_W = 130               -- the Mode and Parameters dropdowns
CFG.PICK_H = 260               -- the parameter list in the picker
CFG.EPS = 1e-7                 -- a smaller change of a normalized value is no change
CFG.SYNC_SEC = 0.5             -- the out-of-sync check: 1 group every 0.5 s
CFG.SYNC_EPS = 1e-3            -- a smaller difference is no difference (out of sync; plugins round a little)
CFG.VERIFY_SEC = 0.25          -- after a copy: check the copied knobs again after 0.25 s (plugins apply late,
CFG.VERIFY_TRIES = 3           -- and turning a band on can reset its other knobs); at most 3 times
CFG.SYNC_QUIET = 1.0           -- no out-of-sync check until 1 s after the last copy (plugins report late)
CFG.ACT_SEC = 0.4              -- the activity dot of a group shows this long after a copy
CFG.SLOW_FRAMES = 10           -- the last touched plugin with a closed window: read every 10th frame
CFG.UNDO_WAIT = 0.6            -- s without a linked change before FX Link makes its undo point
CFG.TB_ICON_W = 32             -- the gear and "?" in the toolbar
CFG.SETTINGS_BTN_W = 200       -- the buttons in the Settings menu
CFG.NOTICE_SEC = 4             -- a notice at the bottom of the window shows this long
CFG.FLASH_SEC = 1.5            -- a new linked parameter flashes blue this long
CFG.DATA_DIR = r.GetResourcePath() .. "/Data/FX Link" -- the backups and the autostart watcher
CFG.STARTUP_FILE = r.GetResourcePath() .. "/Scripts/__startup.lua"
CFG.AUTOSTART_FILE = CFG.DATA_DIR .. "/autostart.lua"
CFG.AS_BEGIN = "-- >>> FX Link autostart (added by FX Link; remove with the FX Link option) >>>"
CFG.AS_END = "-- <<< FX Link autostart <<<"
CFG.AS_BLOCK = CFG.AS_BEGIN .. "\n"
  .. 'pcall(dofile, reaper.GetResourcePath() .. "/Data/FX Link/autostart.lua")\n'
  .. CFG.AS_END .. "\n"
CFG.HEARTBEAT = 0.25           -- s between the "FX Link runs" signals for the autostart watcher
CFG.TIP_DELAY = 0.5            -- seconds on an item before its tooltip shows (as in Chart Cue)
CFG.TIP_WRAP_EM = 32           -- tooltip lines wrap at this many font sizes

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

-- The themes (right-click menu > Light theme): the same palettes as Chart Cue.
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

local Util, Project, Fx, Link, Autostart, UI = {}, {}, {}, {}, {}, {}

-- R: runtime state (not saved). P: the project data. S: settings of this computer.
local R = {
  proj = nil, state_cc = -1, plast_txt = nil, pdirty = false, sdirty = false,
  frames = 0,
  loc = {},          -- fx GUID -> { track, idx } of every track FX in the project (Fx.scan)
  rt = {},           -- member -> its runtime data (track, idx, labels, val / virt snapshots)
  by_num = {},       -- track number -> fx index -> member (the last touched FX -> its member)
  group_of = {},     -- member -> its group
  learn = nil,       -- the group that learns (Learn button) and the last touched FX when it started
  undo_due = nil,    -- the time of the undo point after linked changes
  undo_txt = false, redo_txt = false, -- REAPER's undo and redo texts (to see that undo or redo ran)
  plists = {},       -- group -> its sorted linked parameters (Link.plist; cleared by Link.group_changed)
  chosen = {},       -- group -> its sorted chosen parameters (Link.chosen)
  act = {},          -- group -> the time of its last copy (the activity dot)
  last_src = {},     -- group -> the plugin that was moved last (the reference of the out-of-sync check)
  noset = {},        -- group -> { [param] = true }: knobs that do not take a set value (not checked)
  snap_verify = {},  -- group -> { sn, t, tries }: a recalled snapshot to check again
  snap_cur = {},     -- group -> "A" or "B": the snapshot recalled or stored last (the ring; Compare goes to the other)
  verify = {},       -- group -> { t, src, ps = { [param] = true } or nil (all), tries }: the copy to check again
  search = "", search_low = "", -- the toolbar search
  projfn = "", proj_fp = "", -- the file name and content fingerprint of the project (Close with project)
  as_installed = nil, -- cached: the autostart block is in __startup.lua
  hb_t = 0,          -- the last heartbeat (the autostart watcher sees that FX Link runs)
  flash = nil,       -- the parameter that was just added: { g, p, t } (it flashes in Linked parameters)
}
local P
local S = {
  light = false,     -- Light theme (Dark is the default)
  dock = 0,          -- the REAPER docker of the window (0 = floating)
  closed = {},       -- the folded sections: id -> true ("groups", "settings", "params", "plugins")
  close_proj = true, -- Close with project: FX Link closes when its project tab closes or is replaced
  backup_dir = "",   -- the folder of Back up / Restore ("" = REAPER's Data\FX Link)
}

---------------------------------------------------------------------------
-- REAIMGUI (pinned to 0.9.3 with the official compatibility shim)
---------------------------------------------------------------------------
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("FX Link needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end
  else
    r.ShowMessageBox("FX Link needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run FX Link again.", CFG.TITLE, 0)
  end
end
local TESTING = rawget(_G, "FxLinkTest") ~= nil
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
function Util.mark_pdirty() R.pdirty = true end
function Util.clean(s) return ((s or ""):gsub("[\t\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")) end

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

-- REAPER's text window for a name (deferred: it is modal). done(name) runs with the new name.
function Util.ask_name(title, old, done)
  r.defer(function()
    local ok, txt = r.GetUserInputs(title, 1, "Name:,extrawidth=200,separator=\n", old or "")
    if not ok then return end
    txt = Util.clean(txt)
    if txt ~= "" then done(txt) end
  end)
end

---------------------------------------------------------------------------
-- PROJECT (the link groups, saved in the project)
---------------------------------------------------------------------------
-- A group: { name, on, mode = "exact" | "rel", all = true | false, except = true | false,
--   params = { [index] = true } (Picked: the linked ones; All except: the ones not linked),
--   ident = the plugin (REAPER's fx_ident), plug = its short name,
--   members = { { guid = fx GUID, tname = track name, fname = plugin name }, ... },
--   sort = "track" | "name" (the Plugins list), bypass = true: the plugins are turned on / off together,
--   snap = { A = { t = "14:02", vals = { [fx GUID] = { [param] = value } } }, B = ... } (the snapshots) }
function Project.default() return { groups = {}, cur = 1 } end
function Project.new_group(name)
  return { name = name, on = true, mode = "exact", all = true, except = false, params = {}, ident = "", plug = "",
    members = {}, sort = "track", bypass = false, snap = {} }
end

-- The project data, as lines "key=value". Only what differs from the default is written.
function Project.parse(txt)
  local p = Project.default()
  local snap -- (the snapshot that the "sv" lines belong to)
  for line in (txt .. "\n"):gmatch("([^\n]*)\n") do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "group" then
      local on, mode, params, ident, plug, name = v:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
      if on then
        local g = Project.new_group(name ~= "" and name or ("Group " .. (#p.groups + 1)))
        g.on, g.mode, g.ident, g.plug = (on ~= "0"), (mode == "rel") and "rel" or "exact", ident, plug
        if params ~= "all" then
          g.except = params:sub(1, 1) == "x"
          g.all = g.except
          for n in params:gmatch("%d+") do g.params[tonumber(n)] = true end
        end
        p.groups[#p.groups + 1] = g
        snap = nil
      end
    elseif k == "fx" and #p.groups > 0 and v ~= "" then
      local guid, tname, fname = v:match("^([^\t]*)\t?([^\t]*)\t?(.*)$")
      local ms = p.groups[#p.groups].members
      if guid and guid ~= "" then ms[#ms + 1] = { guid = guid, tname = tname or "", fname = fname or "" } end
    elseif k == "fx_off" and #p.groups > 0 then
      local ms = p.groups[#p.groups].members
      if ms[#ms] then ms[#ms].off = true end
    elseif k == "g_snap" and #p.groups > 0 then
      local slot, t = v:match("^([AB])\t(.*)$")
      if slot then snap = { t = t, vals = {} }; p.groups[#p.groups].snap[slot] = snap end
    elseif k == "sv" and snap then
      local guid, list = v:match("^([^\t]+)\t(.*)$")
      if guid then
        local vals = {}
        for pp, vv in list:gmatch("(%d+):([%d%.%-e]+)") do vals[tonumber(pp)] = tonumber(vv) end
        snap.vals[guid] = vals
      end
    elseif k == "g_sort" and #p.groups > 0 then p.groups[#p.groups].sort = (v == "name") and "name" or "track"
    elseif k == "g_bypass" and #p.groups > 0 then p.groups[#p.groups].bypass = (v == "1")
    elseif k == "cur" then p.cur = math.max(1, math.floor(tonumber(v) or 1))
    end
  end
  if not p.groups[p.cur] then p.cur = 1 end
  return p
end

function Project.params_text(g)
  if g.all and not g.except then return "all" end
  local t = {}
  for n in pairs(g.params) do t[#t + 1] = n end
  table.sort(t)
  for i, n in ipairs(t) do t[i] = tostring(n) end
  return (g.except and "x" or "") .. table.concat(t, ",")
end

function Project.serialize()
  local t = {}
  local function w(k, v) t[#t + 1] = k .. "=" .. (tostring(v):gsub("[\r\n]", " ")) end
  w("version", 1)
  for _, g in ipairs(P.groups) do
    w("group", table.concat({ g.on and "1" or "0", g.mode, Project.params_text(g), Util.clean(g.ident),
      Util.clean(g.plug), Util.clean(g.name) }, "\t"))
    if g.sort ~= "track" then w("g_sort", g.sort) end
    if g.bypass then w("g_bypass", 1) end
    for _, m in ipairs(g.members) do
      w("fx", m.guid .. "\t" .. Util.clean(m.tname) .. "\t" .. Util.clean(m.fname))
      if m.off then w("fx_off", 1) end
    end
    for _, slot in ipairs({ "A", "B" }) do
      local sn = g.snap[slot]
      if sn then
        w("g_snap", slot .. "\t" .. Util.clean(sn.t))
        local guids = {}
        for guid in pairs(sn.vals) do guids[#guids + 1] = guid end
        table.sort(guids)
        for _, guid in ipairs(guids) do
          local ps, parts = {}, {}
          for pp in pairs(sn.vals[guid]) do ps[#ps + 1] = pp end
          table.sort(ps)
          for i, pp in ipairs(ps) do parts[i] = pp .. ":" .. string.format("%.6f", sn.vals[guid][pp]) end
          w("sv", guid .. "\t" .. table.concat(parts, ","))
        end
      end
    end
  end
  if #P.groups > 0 and P.cur ~= 1 then w("cur", P.cur) end
  return table.concat(t, "\n")
end

-- The content of a project in short: "Save as" keeps it; another project opened in the same tab changes it.
function Project.fingerprint(proj)
  local nt = r.CountTracks(proj)
  local g1 = nt > 0 and r.GetTrackGUID(r.GetTrack(proj, 0)) or ""
  local g2 = nt > 0 and r.GetTrackGUID(r.GetTrack(proj, nt - 1)) or ""
  return string.format("%d|%s|%s", nt, g1, g2)
end

-- Close with project (as in Chart Cue): true when the project of FX Link closed (its tab), or File > Close / New /
-- Open project replaced it in the same tab. Switching tabs and "Save as" are no close.
function Project.closed_or_replaced(proj, fn)
  if R.proj == nil then return false end
  if not r.ValidatePtr2(0, R.proj, "ReaProject*") then return true end
  if proj ~= R.proj or fn == R.projfn then return false end
  if fn == "" then return true end
  local n, txt = r.GetProjExtState(proj, CFG.EXT, CFG.PEXT_KEY)
  if not (n and n > 0) then txt = Project.serialize() end
  return txt ~= R.plast_txt or Project.fingerprint(proj) ~= R.proj_fp
end

function Project.load()
  local n, txt = r.GetProjExtState(R.proj, CFG.EXT, CFG.PEXT_KEY)
  if n and n > 0 and txt and txt ~= "" then P = Project.parse(txt); R.plast_txt = txt
  else P = Project.default(); R.plast_txt = Project.serialize() end
  R.learn, R.undo_due, R.plists = nil, nil, {}
  R.verify, R.noset, R.act, R.last_src, R.differ, R.differ_seen, R.snap_cur, R.snap_verify = {}, {}, {}, {}, {}, {}, {}, {} -- (the old project's groups)
  Fx.resolve(true)
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

-- Every frame: another project tab loads its own data; a project change checks the instances again.
function Project.update()
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if (proj ~= R.proj or fn ~= R.projfn) and Project.closed_or_replaced(proj, fn) then
    R.pdirty = false -- (never write the old groups into the next project)
    if S.close_proj then R.proj = nil; R.close = true; return end
    R.proj = nil
  end
  if proj ~= R.proj then
    if R.pdirty then Project.save() end
    R.proj, R.state_cc = proj, -1
    Project.load()
  end
  if fn ~= R.projfn then R.projfn, R.proj_fp = fn, Project.fingerprint(proj) end
  local cc = r.GetProjectStateChangeCount(proj)
  if cc ~= R.state_cc then
    R.state_cc = cc
    R.proj_fp = Project.fingerprint(proj) -- (kept up to date: "Save as" later compares with it)
    -- undo ran (the old undo step is now the redo step) or redo ran (the reverse): read the values again.
    -- A new step (it clears the redo) does not: its change is still to be copied.
    local undo, redo = r.Undo_CanUndo2(proj) or false, r.Undo_CanRedo2(proj) or false
    local fresh = (redo and redo == R.undo_txt) or (undo and undo == R.redo_txt) or false
    R.undo_txt, R.redo_txt = undo, redo
    Fx.resolve(fresh)
  end
end

---------------------------------------------------------------------------
-- FX (find the plugin instances of the groups in the project)
---------------------------------------------------------------------------
function Fx.track(num) -- the track of a track number (0 = master)
  if num == 0 then return r.GetMasterTrack(R.proj) end
  return r.GetTrack(R.proj, num - 1)
end

function Fx.track_num(tr)
  if tr == r.GetMasterTrack(R.proj) then return 0 end
  return math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
end

-- The plugin of an instance: its identity (the same plugin in 2 instances: the same text) and short name.
function Fx.ident(tr, idx)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, idx, "fx_ident")
  local okn, full = r.TrackFX_GetNamedConfigParm(tr, idx, "fx_name")
  if not okn or full == "" then full = select(2, r.TrackFX_GetFXName(tr, idx, "")) end
  if not ok or id == "" then id = full end
  return id, Fx.short_name(full)
end

-- The identity of a track FX, cached by its GUID (it never changes for one FX).
function Fx.ident_cached(tr, idx)
  local guid = r.TrackFX_GetFXGUID(tr, idx)
  if not guid then return nil end
  R.idents = R.idents or {}
  local id = R.idents[guid]
  if not id then id = Fx.ident(tr, idx); R.idents[guid] = id end
  return id
end

-- "VST3: Pro-Q 3 (FabFilter)" -> "Pro-Q 3"
function Fx.short_name(full)
  local s = (full or ""):gsub("^[%w%s]+:%s*", "", 1):gsub("%s*%([^%(%)]*%)%s*$", "")
  return s ~= "" and s or (full or "")
end

-- The parameters that a link copies: all, without REAPER's own Bypass, Wet and Delta at the end.
function Fx.num_params(tr, idx)
  local n = r.TrackFX_GetNumParams(tr, idx)
  for _ = 1, 3 do
    if n <= 0 then break end
    local _, nm = r.TrackFX_GetParamName(tr, idx, n - 1, "")
    if nm == "Bypass" or nm == "Wet" or nm == "Delta" then n = n - 1 else break end
  end
  return n
end

-- Calls fn(address) for every FX of a track: the FX chain and the FX inside FX Containers (REAPER 7; their
-- address is REAPER's container address). fn returns true to stop. Returns true when stopped.
function Fx.each(tr, fn)
  local function walk(addr)
    if fn(addr) then return true end
    local ok, n = r.TrackFX_GetNamedConfigParm(tr, addr, "container_count")
    n = ok and tonumber(n) or 0
    for k = 0, n - 1 do
      local ok2, a = r.TrackFX_GetNamedConfigParm(tr, addr, "container_item." .. k)
      a = ok2 and tonumber(a)
      if a and walk(a) then return true end
    end
    return false
  end
  for i = 0, r.TrackFX_GetCount(tr) - 1 do
    if walk(i) then return true end
  end
  return false
end

-- The place of an FX for the labels: "slot 3", or "in container".
function Fx.slot_text(idx)
  return idx >= 0x2000000 and "in container" or ("slot " .. (idx + 1))
end

-- Every track FX of the project by its GUID.
function Fx.scan()
  local loc = {}
  local function add(tr)
    Fx.each(tr, function(i)
      local g = r.TrackFX_GetFXGUID(tr, i)
      if g then loc[g] = { track = tr, idx = i } end
    end)
  end
  add(r.GetMasterTrack(R.proj))
  for t = 0, r.CountTracks(R.proj) - 1 do add(r.GetTrack(R.proj, t)) end
  R.loc = loc
end

-- Reads every linked parameter of a member (its snapshot: the values that FX Link knows).
function Fx.snapshot(rt)
  rt.val, rt.virt = {}, {}
  rt.enabled = r.TrackFX_GetEnabled(rt.track, rt.idx)
  rt.uvirt = {} -- (Relative in real units: the unclamped value in dB / ms / %)
  for p = 0, rt.nparams - 1 do
    local v = r.TrackFX_GetParamNormalized(rt.track, rt.idx, p)
    rt.val[p], rt.virt[p] = v, v
  end
end

-- Finds the track and slot of each member (after a project change). A member whose slot still has its GUID
-- keeps its data; else the project is scanned once. fresh: read every snapshot again.
function Fx.resolve(fresh)
  if not P then return end
  local scanned = false
  local old = R.rt
  R.rt, R.by_num, R.group_of, R.plists, R.chosen = {}, {}, {}, {}, {}
  for _, g in ipairs(P.groups) do
    for _, m in ipairs(g.members) do
      R.group_of[m] = g
      local rt = old[m]
      local ok = rt and r.ValidatePtr2(R.proj, rt.track, "MediaTrack*") and r.TrackFX_GetFXGUID(rt.track, rt.idx) == m.guid
      if not ok then
        if not scanned then Fx.scan(); scanned = true end
        local l = R.loc[m.guid]
        if l then
          rt = { track = l.track, idx = l.idx }
          rt.nparams = Fx.num_params(l.track, l.idx)
          Fx.snapshot(rt)
        else rt = nil end
      elseif fresh then
        Fx.snapshot(rt)
      end
      if rt then
        rt.num = Fx.track_num(rt.track)
        local _, tname = r.GetTrackName(rt.track)
        local _, fname = r.TrackFX_GetFXName(rt.track, rt.idx, "")
        rt.track_label = rt.num == 0 and "Master" or (rt.num .. "  " .. tname)
        rt.fx_label = Fx.short_name(fname)
        local gi, copies = g.ident, 0
        if gi ~= "" then
          Fx.each(rt.track, function(f)
            if Fx.ident_cached(rt.track, f) == gi then copies = copies + 1 end
          end)
        end
        if copies > 1 or rt.idx >= 0x2000000 then rt.fx_label = rt.fx_label .. "  (" .. Fx.slot_text(rt.idx) .. ")" end
        -- the names for Find again and the Missing text (saved in the project; written when they change)
        local short = Fx.short_name(fname)
        if m.tname ~= tname or m.fname ~= short then m.tname, m.fname = tname, short; Util.mark_pdirty() end
        rt.tname_low, rt.track_low = tname:lower(), rt.track_label:lower()
        R.rt[m] = rt
        R.by_num[rt.num] = R.by_num[rt.num] or {}
        R.by_num[rt.num][rt.idx] = m
      end
    end
  end
  UI.labels_dirty()
end

-- The member of a track FX (nil: not in a group).
function Fx.member_at(tr, idx)
  local guid = r.TrackFX_GetFXGUID(tr, idx)
  for _, g in ipairs(P.groups) do
    for _, m in ipairs(g.members) do if m.guid == guid then return m, g end end
  end
end

-- Adds a track FX to a group. Returns nil and a message when it cannot.
function Fx.add(g, tr, idx)
  if idx >= 0x1000000 and idx < 0x2000000 then
    return nil, "Input FX and monitoring FX cannot be linked: use a plugin in the normal FX chain."
  end
  local guid = r.TrackFX_GetFXGUID(tr, idx)
  if not guid then return nil, "This plugin was not found." end
  local m0, g0 = Fx.member_at(tr, idx)
  if m0 then
    if g0 == g then return nil, "This plugin is already in this group." end
    return nil, "This plugin is already in the group \"" .. g0.name .. "\". A plugin can be in 1 group only."
  end
  local id, short = Fx.ident(tr, idx)
  if #g.members > 0 and g.ident ~= "" and id ~= g.ident then
    return nil, "This group links " .. g.plug .. ". You can only add instances of the same plugin."
  end
  if #g.members == 0 or g.ident == "" then g.ident, g.plug = id, short end
  local _, tname = r.GetTrackName(tr)
  g.members[#g.members + 1] = { guid = guid, tname = tname, fname = short }
  Util.mark_pdirty()
  Fx.resolve(false)
  return true
end

-- The focused plugin window (or else the plugin that was touched last): its track and slot.
function Fx.focused()
  if r.GetFocusedFX2 then
    local ret, tn, item, fx = r.GetFocusedFX2()
    if ret and (ret & 1) ~= 0 and item < 0 then return Fx.track(tn), fx end
    if ret and (ret & 2) ~= 0 then return nil, nil, "This is an item (take) FX. FX Link links track FX only." end
  end
  local ok, tn, fx = r.GetLastTouchedFX()
  if ok and (tn >> 16) == 0 then return Fx.track(tn & 0xFFFF), fx end
  return nil, nil, "Open a plugin window first (click it), then click this button."
end

-- The plugins on these tracks, by identity: { { ident, plug, n = copies }, ... } sorted by name (for an empty
-- group: "Which plugin?"). tracks = nil: every track of the project and the master.
function Fx.plugin_list(tracks)
  if not tracks then
    tracks = { r.GetMasterTrack(R.proj) }
    for i = 0, r.CountTracks(R.proj) - 1 do tracks[#tracks + 1] = r.GetTrack(R.proj, i) end
  end
  local list, seen = {}, {}
  for _, tr in ipairs(tracks) do
    Fx.each(tr, function(f)
      local id, short = Fx.ident(tr, f)
      local e = seen[id]
      if e then e.n = e.n + 1
      else e = { ident = id, plug = short, n = 1 }; seen[id] = e; list[#list + 1] = e end
    end)
  end
  table.sort(list, function(a, b) return a.plug:lower() < b.plug:lower() end)
  return list
end
function Fx.selected_tracks()
  local list = {}
  for i = 0, r.CountSelectedTracks(R.proj) - 1 do list[#list + 1] = r.GetSelectedTrack(R.proj, i) end
  return list
end

-- Adds the first instance of the group's plugin on each of these tracks. Returns added, skipped (messages).
function Fx.add_tracks(g, tracks)
  local added, skipped = 0, {}
  for _, tr in ipairs(tracks) do
    local found
    Fx.each(tr, function(f)
      if (Fx.ident(tr, f)) == g.ident then found = f; return true end
    end)
    local _, tname = r.GetTrackName(tr)
    if found then
      local ok, err = Fx.add(g, tr, found)
      if ok then added = added + 1 else skipped[#skipped + 1] = tname .. ": " .. err end
    else
      skipped[#skipped + 1] = tname .. ": no " .. g.plug .. " on this track."
    end
  end
  return added, skipped
end
function Fx.add_selected(g) return Fx.add_tracks(g, Fx.selected_tracks()) end

-- The folder tracks of the project (Add from folder): { { track, name }, ... }.
function Fx.folders()
  local list = {}
  for t = 0, r.CountTracks(R.proj) - 1 do
    local tr = r.GetTrack(R.proj, t)
    if r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
      local _, nm = r.GetTrackName(tr)
      list[#list + 1] = { track = tr, name = nm }
    end
  end
  return list
end
-- Every track inside a folder (all levels).
function Fx.folder_tracks(folder)
  local list, depth = {}, 1
  local i = math.floor(r.GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")) -- (the next track, 0-based)
  while depth > 0 and i < r.CountTracks(R.proj) do
    local tr = r.GetTrack(R.proj, i)
    list[#list + 1] = tr
    depth = depth + r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
    i = i + 1
  end
  return list
end

-- Find again: a missing plugin is looked for on a track with the same name (a free copy of the group's plugin).
function Fx.find_again(g, m)
  if (m.tname or "") == "" then return nil, "FX Link does not know the track of this plugin." end
  local want = m.tname:lower()
  for t = 0, r.CountTracks(R.proj) - 1 do
    local tr = r.GetTrack(R.proj, t)
    local _, nm = r.GetTrackName(tr)
    if nm:lower() == want then
      local found
      Fx.each(tr, function(f)
        if (Fx.ident(tr, f)) == g.ident and not Fx.member_at(tr, f) then found = f; return true end
      end)
      if found then
        Fx.set_guid(g, m, r.TrackFX_GetFXGUID(tr, found))
        Util.mark_pdirty()
        Fx.resolve(false)
        return true
      end
    end
  end
  return nil, "No track \"" .. m.tname .. "\" with a free " .. g.plug .. " was found."
end

-- The copies of the group's plugin on a track: { { idx, label, guid }, ... } (for the dropdown of a plugin row).
function Fx.copies(g, tr)
  local t = {}
  Fx.each(tr, function(f)
    if (Fx.ident(tr, f)) == g.ident then
      local _, nm = r.TrackFX_GetFXName(tr, f, "")
      t[#t + 1] = { idx = f, label = Fx.short_name(nm) .. "  (" .. Fx.slot_text(f) .. ")", guid = r.TrackFX_GetFXGUID(tr, f) }
    end
  end)
  return t
end

-- Links another copy (on the same track) in place of a member. Returns nil and a message when it cannot.
function Fx.replace(g, m, guid)
  if guid == m.guid then return true end
  for _, g2 in ipairs(P.groups) do
    for _, m2 in ipairs(g2.members) do
      if m2.guid == guid then
        return nil, g2 == g and "This copy is already in this group."
          or ("This copy is already in the group \"" .. g2.name .. "\". A plugin can be in 1 group only.")
      end
    end
  end
  Fx.set_guid(g, m, guid)
  Util.mark_pdirty()
  Fx.resolve(false)
  return true
end

-- A member links another plugin (Find, another copy): its snapshot values move along.
function Fx.set_guid(g, m, guid)
  for _, sn in pairs(g.snap) do
    if sn.vals[m.guid] then sn.vals[guid], sn.vals[m.guid] = sn.vals[m.guid], nil end
  end
  m.guid = guid
end

-- Selects the tracks of these members in REAPER (only these), and scrolls them into view.
function Fx.select_tracks(members)
  local first
  for _, m in ipairs(members) do first = first or R.rt[m] end
  if not first then return end
  r.PreventUIRefresh(1)
  r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  for _, m in ipairs(members) do
    local rt = R.rt[m]
    if rt then r.SetTrackSelected(rt.track, true) end
  end
  r.Main_OnCommand(40913, 0) -- Track: Vertical scroll selected tracks into view
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
end

-- Adds every instance of the group's plugin in the project. Returns added, in_other (in another group).
function Fx.add_all(g)
  local added, other = 0, 0
  local function try(tr)
    Fx.each(tr, function(f)
      if (Fx.ident(tr, f)) == g.ident then
        local m0, g0 = Fx.member_at(tr, f)
        if not m0 then
          if Fx.add(g, tr, f) then added = added + 1 end
        elseif g0 ~= g then other = other + 1 end
      end
    end)
  end
  try(r.GetMasterTrack(R.proj))
  for t = 0, r.CountTracks(R.proj) - 1 do try(r.GetTrack(R.proj, t)) end
  return added, other
end

---------------------------------------------------------------------------
-- LINK (copy a change of one instance to the other instances of its group)
---------------------------------------------------------------------------
-- The new value of another instance. Exact: the same value. Relative: the same change; virt is the value
-- before the range end cuts it, so a knob that went past the end comes back with its old difference.
function Link.target(mode, v, d, other_virt)
  if mode == "exact" then return v, v end
  local virt = other_virt + d
  return Util.clamp(virt, 0, 1), virt
end

-- The sorted list of the group's chosen parameters (Picked: linked; All except: not linked). Cached.
function Link.chosen(g)
  local t = R.chosen[g]
  if not t then
    t = {}
    for n in pairs(g.params) do t[#t + 1] = n end
    table.sort(t)
    R.chosen[g] = t
  end
  return t
end

-- The sorted list of the linked parameters (cached; nil: all of them).
function Link.plist(g)
  if g.all and not g.except then return nil end
  if not g.except then return Link.chosen(g) end
  local t = R.plists[g]
  if not t then
    local n = 0
    for _, m in ipairs(g.members) do
      local rt = R.rt[m]
      if rt then n = math.max(n, rt.nparams) end
    end
    t = {}
    for p = 0, n - 1 do if not g.params[p] then t[#t + 1] = p end end
    R.plists[g] = t
  end
  return t
end

-- Relative in real units: the value of a parameter in dB, ms or % (from the plugin's own display), or nil when
-- the plugin does not show such a number (then Relative uses the knob's range). Hz is not used: frequency knobs
-- are already logarithmic, so the same knob change is the same musical step.
function Link.unit_value(tr, idx, p, v)
  local ok, txt = r.TrackFX_FormatParamValueNormalized(tr, idx, p, v, "")
  if not ok or not txt then return nil end
  local num, unit = txt:match("([-+]?%d*%.?%d+)%s*([%a%%]*)")
  num = tonumber(num)
  if not num then return nil end
  unit = unit:lower()
  if unit == "db" or unit == "%" or unit == "ms" then return num end
  if unit == "s" or unit == "sec" then return num * 1000 end
  return nil
end

-- The knob position (0-1) that shows the real value target (a search; the display must go one way only).
-- Returns nil when it cannot (then the knob's range is used).
function Link.find_unit(tr, idx, p, target)
  local lo, hi = Link.unit_value(tr, idx, p, 0), Link.unit_value(tr, idx, p, 1)
  if not lo or not hi or lo == hi then return nil end
  local up = hi > lo
  if (up and target <= lo) or (not up and target >= lo) then return 0 end
  if (up and target >= hi) or (not up and target <= hi) then return 1 end
  local a, b = 0, 1
  for _ = 1, 24 do
    local mid = (a + b) / 2
    local mv = Link.unit_value(tr, idx, p, mid)
    if not mv then return nil end
    if (mv < target) == up then a = mid else b = mid end
  end
  return (a + b) / 2
end

-- After a change of a group's switch, mode or parameters: its instances are read again (so changes made while a
-- parameter was not linked are not copied later), and the cached lists are cleared.
function Link.group_changed(g)
  R.plists[g], R.chosen[g], R.picked_cache = nil, nil, nil
  if R.differ then R.differ[g] = nil end
  for _, m in ipairs(g.members) do
    local rt = R.rt[m]
    if rt then Fx.snapshot(rt) end
  end
  Util.mark_pdirty()
end

-- Compares the source instance with its snapshot and copies every change to the other members.
-- Returns the number of changed parameters.
-- A knob that automation or parameter modulation moves (not the user): its changes are not copied.
-- Automation: during playback, or any knob other than the touched one (a seek while stopped).
-- Only called for a changed knob (not every frame for every knob).
function Link.driven(rt, p, touched)
  local _, mod = r.TrackFX_GetNamedConfigParm(rt.track, rt.idx, "param." .. p .. ".mod.active")
  if mod == "1" then return true end
  if r.GetFXEnvelope(rt.track, rt.idx, p, false) then
    return p ~= touched or (r.GetPlayState() & 1) == 1
  end
  return false
end

-- A plugin that follows its group (not paused, and found): its runtime data, else nil.
function Link.live(m) return not m.off and R.rt[m] or nil end

-- Pause / resume 1 plugin. On resume its values are read again (no jump: the changes made while paused stay).
function Link.set_paused(m, off)
  m.off = off or nil
  if not off and R.rt[m] then Fx.snapshot(R.rt[m]) end
  Util.mark_pdirty()
end

function Link.sync(g, src, touched)
  local srt = R.rt[src]
  if not srt then return 0 end
  local list = Link.plist(g)
  local count = list and #list or srt.nparams
  local changed = 0
  for k = 1, count do
    local p = list and list[k] or (k - 1)
    if p < srt.nparams then
      local v = r.TrackFX_GetParamNormalized(srt.track, srt.idx, p)
      local old = srt.val[p]
      if old == nil then srt.val[p], srt.virt[p] = v, v
      elseif math.abs(v - old) > CFG.EPS and Link.driven(srt, p, touched) then
        srt.val[p], srt.virt[p], srt.uvirt[p] = v, v, nil -- (automation or modulation moved it: not copied)
      elseif math.abs(v - old) > CFG.EPS then
        local d = v - old
        -- Relative: the change in dB / ms / % when the plugin shows it
        local du
        if g.mode == "rel" then
          local un = Link.unit_value(srt.track, srt.idx, p, v)
          local uo = un and Link.unit_value(srt.track, srt.idx, p, old)
          if un and uo then du = un - uo end
        end
        srt.val[p], srt.virt[p], srt.uvirt[p] = v, v, nil
        for _, m in ipairs(g.members) do
          local ort = m ~= src and Link.live(m)
          if ort and p < ort.nparams then
            local nv, virt, uv
            if du then
              local base = ort.uvirt[p] or Link.unit_value(ort.track, ort.idx, p, ort.val[p] or v)
              if base then
                uv = base + du
                nv = Link.find_unit(ort.track, ort.idx, p, uv)
              end
            end
            if nv then virt = nil
            else uv = nil; nv, virt = Link.target(g.mode, v, d, ort.virt[p] or ort.val[p] or v) end
            r.TrackFX_SetParamNormalized(ort.track, ort.idx, p, nv)
            ort.val[p] = r.TrackFX_GetParamNormalized(ort.track, ort.idx, p)
            ort.virt[p] = virt or ort.val[p]
            ort.uvirt[p] = uv
          end
        end
        changed = changed + 1
        if g.mode == "exact" then Link.verify_later(g, src, p) end
      end
    end
  end
  return changed
end

-- Check the copied knobs again a moment later (Exact): plugins apply a value late, and turning a band on can
-- reset its other knobs after FX Link set them. p = nil: every linked knob (after Match).
function Link.verify_later(g, src, p)
  local v = R.verify[g]
  if not v or v.src ~= src then v = { src = src, ps = {}, tries = 0 }; R.verify[g] = v end
  if p == nil then v.ps = nil elseif v.ps then v.ps[p] = true end
  v.t, v.tries = Util.now() + CFG.VERIFY_SEC, 0
end
function Link.verify_tick()
  local now = Util.now()
  for g, v in pairs(R.verify) do
    if now >= v.t then
      local srt = R.rt[v.src]
      local fixed = false
      if srt and g.on and g.mode == "exact" then
        local list = Link.plist(g)
        for _, m in ipairs(g.members) do
          local ort = m ~= v.src and Link.live(m)
          if ort then
            local function check(pp)
              if pp < srt.nparams and pp < ort.nparams then
                local want = r.TrackFX_GetParamNormalized(srt.track, srt.idx, pp)
                if math.abs(r.TrackFX_GetParamNormalized(ort.track, ort.idx, pp) - want) > CFG.SYNC_EPS then
                  if v.tries + 1 >= CFG.VERIFY_TRIES then Link.mark_noset(g, pp) -- (it does not follow: leave it out)
                  else r.TrackFX_SetParamNormalized(ort.track, ort.idx, pp, want); fixed = true end
                end
                ort.val[pp] = r.TrackFX_GetParamNormalized(ort.track, ort.idx, pp)
                ort.virt[pp] = ort.val[pp]
              end
            end
            if v.ps then
              for pp in pairs(v.ps) do check(pp) end
            else
              local cnt = list and #list or math.min(srt.nparams, ort.nparams)
              for k = 1, cnt do check(list and list[k] or (k - 1)) end
            end
          end
        end
      end
      v.tries = v.tries + 1
      if fixed and v.tries < CFG.VERIFY_TRIES then
        v.t = now + CFG.VERIFY_SEC
        R.act[g] = now -- (the out-of-sync check waits)
      else
        R.verify[g] = nil
      end
    end
  end
end

-- Every frame: the plugin that was touched last is the source of its group.
function Link.tick()
  if not P or #P.groups == 0 then return end
  local ok, tn, fx, prm = r.GetLastTouchedFX()
  local m = ok and R.by_num[tn] and R.by_num[tn][fx]
  local g = m and R.group_of[m]
  if R.learn and (R.learn.g ~= P.groups[P.cur] or (R.learn.g.all and not R.learn.g.except)) then
    R.learn = nil -- (not shown: stop)
  end
  if R.learn then
    local L = R.learn
    if ok and (tn ~= L.tn or fx ~= L.fx or prm ~= L.prm) then
      L.tn, L.fx, L.prm = tn, fx, prm
      if g == L.g and R.rt[m] and prm < R.rt[m].nparams and not L.g.params[prm] then
        L.g.params[prm] = true
        Link.group_changed(L.g)
        R.flash = { g = L.g, p = prm, t = Util.now() }
      end
    end
  end
  if g and g.on and not m.off and #g.members > 1 and not R.snap_verify[g] then
    -- its window open: every frame; closed (a control surface, the FX chain list): about 3 times per second
    local rt = R.rt[m]
    local due = rt and (r.TrackFX_GetOpen(rt.track, rt.idx) or R.frames % CFG.SLOW_FRAMES == 0)
    if due and Link.sync(g, m, prm) > 0 then
      R.undo_due = Util.now() + CFG.UNDO_WAIT
      R.act[g], R.last_src[g] = Util.now(), m
      if R.differ then R.differ[g] = nil end -- (checked again soon)
    end
  end
  if Link.bypass_tick() then R.undo_due = Util.now() + CFG.UNDO_WAIT end
  Link.verify_tick()
  Link.snap_tick()
  Link.check_sync()
  if R.undo_due and Util.now() > R.undo_due then
    R.undo_due = nil
    if not (R.proj and r.ValidatePtr2(0, R.proj, "ReaProject*")) then return end
    r.Undo_OnStateChangeEx2(R.proj, "FX Link: linked plugin change", 2, -1) -- 2: the FX of all tracks
  end
end

-- Link bypass: a plugin of the group that was turned on or off turns the others the same way.
-- Returns true when it changed something. (A few calls per frame: 1 per plugin of these groups.)
function Link.bypass_tick()
  local done = false
  for _, g in ipairs(P.groups) do
    if g.on and g.bypass and #g.members > 1 then
      for _, m in ipairs(g.members) do
        local rt = Link.live(m)
        local e = rt and r.TrackFX_GetEnabled(rt.track, rt.idx)
        if rt and e ~= rt.enabled then
          rt.enabled = e
          for _, o in ipairs(g.members) do
            local ort = o ~= m and Link.live(o)
            if ort and ort.enabled ~= e then r.TrackFX_SetEnabled(ort.track, ort.idx, e); ort.enabled = e end
          end
          R.act[g] = Util.now()
          done = true
          break
        end
      end
    end
  end
  return done
end

-- A knob that does not take the value that FX Link sets (a meter, or a value that the plugin controls itself):
-- the out-of-sync check leaves it out.
function Link.mark_noset(g, p)
  R.noset[g] = R.noset[g] or {}
  R.noset[g][p] = true
end

-- Out of sync (Exact groups): which plugins differ from the reference (the plugin moved last, else the first).
-- 1 group per call, every CFG.SYNC_SEC. R.differ[g] = { n = count, m = { [member] = { up to 3 params } } } or nil.
function Link.check_sync()
  local now = Util.now()
  if now < (R.sync_t or 0) or #P.groups == 0 then return end
  R.sync_t = now + CFG.SYNC_SEC
  R.sync_i = (R.sync_i or 0) % #P.groups + 1
  local g = P.groups[R.sync_i]
  R.differ, R.differ_seen = R.differ or {}, R.differ_seen or {}
  if R.act[g] and now - R.act[g] < CFG.SYNC_QUIET then return end -- (busy: the plugins may report late)
  R.differ[g] = nil
  if not (g.on and g.mode == "exact" and #g.members > 1) then R.differ_seen[g] = nil; return end
  local ref = R.last_src[g]
  if not (ref and Link.live(ref) and R.group_of[ref] == g) then
    ref = nil
    for _, m in ipairs(g.members) do if Link.live(m) then ref = m; break end end
  end
  local rr = ref and R.rt[ref]
  if not rr then return end
  local list = Link.plist(g)
  local diff, n = nil, 0
  for _, m in ipairs(g.members) do
    local rt = m ~= ref and Link.live(m)
    if rt then
      local cnt = list and #list or math.min(rr.nparams, rt.nparams)
      local noset = R.noset[g]
      local ps
      for k = 1, cnt do
        local p = list and list[k] or (k - 1)
        if p < rr.nparams and p < rt.nparams and not (noset and noset[p])
            and math.abs(r.TrackFX_GetParamNormalized(rr.track, rr.idx, p)
            - r.TrackFX_GetParamNormalized(rt.track, rt.idx, p)) > CFG.SYNC_EPS then
          ps = ps or {}
          ps[#ps + 1] = p
          if #ps >= 3 then break end
        end
      end
      if ps then
        diff = diff or {}
        diff[m], n = ps, n + 1
      end
    end
  end
  -- the badge shows only when 2 checks in a row find a difference (a short difference during a change: no badge)
  if n > 0 and R.differ_seen[g] then R.differ[g] = { n = n, m = diff } end
  R.differ_seen[g] = n > 0 or nil
end

-- Snapshots A / B: store the linked knobs of every plugin of the group; recall them (1 undo step).
function Link.snap_store(g, slot)
  local list = Link.plist(g)
  local sn = { t = os.date("%H:%M"), vals = {} }
  for _, m in ipairs(g.members) do
    local rt = R.rt[m]
    if rt then
      local t = {}
      local cnt = list and #list or rt.nparams
      for k = 1, cnt do
        local p = list and list[k] or (k - 1)
        if p < rt.nparams then t[p] = r.TrackFX_GetParamNormalized(rt.track, rt.idx, p) end
      end
      sn.vals[m.guid] = t
    end
  end
  g.snap[slot] = sn
  Util.mark_pdirty()
end
function Link.snap_recall(g, slot)
  local sn = g.snap[slot]
  if not sn then return end
  R.snap_cur[g] = slot
  r.Undo_BeginBlock2(R.proj)
  Link.snap_apply(g, sn)
  r.Undo_EndBlock2(R.proj, "FX Link: recall snapshot " .. slot, -1)
  Link.group_changed(g)
  -- plugins apply some values late, and turning a band on resets its other knobs: check again soon
  R.snap_verify[g] = { sn = sn, t = Util.now() + CFG.VERIFY_SEC, tries = 0 }
  R.act[g] = Util.now()
end
-- Sets every plugin to its values of the snapshot, in parameter order (always the same order: a band's
-- "on" before its frequency). Returns true when a knob had to be set.
function Link.snap_apply(g, sn)
  local set = false
  for _, m in ipairs(g.members) do
    local rt, vals = Link.live(m), sn.vals[m.guid]
    if rt and vals then
      local ps = {}
      for p in pairs(vals) do if p < rt.nparams then ps[#ps + 1] = p end end
      table.sort(ps)
      for _, p in ipairs(ps) do
        if math.abs(r.TrackFX_GetParamNormalized(rt.track, rt.idx, p) - vals[p]) > CFG.EPS then
          r.TrackFX_SetParamNormalized(rt.track, rt.idx, p, vals[p])
          set = true
        end
      end
    end
  end
  return set
end
-- After a recall: set the knobs again that did not take (at most CFG.VERIFY_TRIES times), then read the plugins.
function Link.snap_tick()
  local now = Util.now()
  for g, v in pairs(R.snap_verify) do
    if now >= v.t then
      v.tries = v.tries + 1
      local again = Link.snap_apply(g, v.sn)
      if again and v.tries < CFG.VERIFY_TRIES then
        v.t = now + CFG.VERIFY_SEC
      else
        R.snap_verify[g] = nil
        Link.group_changed(g) -- (the new values are the start for the next change)
      end
      R.act[g] = now -- (the out-of-sync check waits)
    end
  end
end

-- Match: the other plugins of the group become equal to src (the linked parameters; with Link bypass also
-- on / off). 1 undo step.
function Link.match(g, src)
  local srt = R.rt[src]
  if not srt then return end
  local list = Link.plist(g)
  r.Undo_BeginBlock2(R.proj)
  for _, m in ipairs(g.members) do
    local ort = m ~= src and Link.live(m)
    if ort then
      local n = list and #list or math.min(srt.nparams, ort.nparams)
      for k = 1, n do
        local p = list and list[k] or (k - 1)
        if p < srt.nparams and p < ort.nparams then
          r.TrackFX_SetParamNormalized(ort.track, ort.idx, p, r.TrackFX_GetParamNormalized(srt.track, srt.idx, p))
        end
      end
      if g.bypass then r.TrackFX_SetEnabled(ort.track, ort.idx, r.TrackFX_GetEnabled(srt.track, srt.idx)) end
    end
  end
  r.Undo_EndBlock2(R.proj, "FX Link: match plugins", -1) -- -1: the whole state (the FX of all tracks)
  Link.group_changed(g)
  if g.mode == "exact" then
    Link.verify_later(g, src, nil)
    R.act[g], R.last_src[g] = Util.now(), src
  end
end

-- Show plugins: is a plugin window of the group open; open (and bring to the front) or close them all.
function Link.any_open(g)
  for _, m in ipairs(g.members) do
    local rt = R.rt[m]
    if rt and r.TrackFX_GetOpen(rt.track, rt.idx) then return true end
  end
  return false
end
function Link.show(g, on)
  for _, m in ipairs(g.members) do
    local rt = R.rt[m]
    if rt then r.TrackFX_Show(rt.track, rt.idx, on and 3 or 2) end -- 3: show floating, 2: hide floating
  end
end

-- The actions "FX Link - Show plugins", "FX Link - Toggle group" (the selected group) and
-- "FX Link - Group focused plugin on selected tracks" (a new group).
function Link.read_cmds()
  local q = r.GetExtState(CFG.EXT, "cmd_q")
  if q == "" then return end
  r.SetExtState(CFG.EXT, "cmd_q", "", false)
  if not P then return end
  for c in q:gmatch("([^,]+)") do
    local g = P.groups[P.cur]
    if c == "quick" then Link.quick_group()
    elseif not g then -- (no group yet: nothing to show or toggle)
    elseif c == "show" then Link.show(g, not Link.any_open(g))
    elseif c == "toggle" then g.on = not g.on; Link.group_changed(g) end
  end
end

-- Quick group (an action): a new group of the focused plugin and the same plugin on every selected track.
-- Tracks without it (or with it in another group) are skipped; a message names them.
function Link.quick_group()
  local tr, idx, err = Fx.focused()
  if not tr then UI.notice(err, true); return end
  local g = Project.new_group("")
  local ok, e2 = Fx.add(g, tr, idx)
  if not ok then UI.notice(e2, true); return end
  g.name = g.plug
  P.groups[#P.groups + 1] = g
  P.cur = #P.groups
  local others = {}
  for i = 0, r.CountSelectedTracks(R.proj) - 1 do
    local t = r.GetSelectedTrack(R.proj, i)
    if t ~= tr then others[#others + 1] = t end
  end
  local _, skipped = Fx.add_tracks(g, others)
  Util.mark_pdirty(); Fx.resolve(false)
  local msg
  if #g.members < 2 then
    msg = "New group \"" .. g.name .. "\" with 1 plugin. Select the other tracks that have " .. g.plug
      .. " and run it again, or use \"+ Add\" > Selected tracks."
  elseif #skipped > 0 then
    msg = "New group \"" .. g.name .. "\" with " .. #g.members .. " plugins.\nSkipped:\n" .. table.concat(skipped, "\n")
  end
  if msg then UI.ask(msg, nil) end
end

-- Starts or stops Learn for a group (Learn adds each parameter that you move in its plugins).
function Link.learn(g)
  if R.learn and R.learn.g == g then R.learn = nil; return end
  local _, tn, fx, prm = r.GetLastTouchedFX()
  R.learn = { g = g, tn = tn, fx = fx, prm = prm }
end

---------------------------------------------------------------------------
-- AUTOSTART: "Open automatically" (as in Chart Cue): FX Link opens for every project that has FX Link groups.
-- A small watcher (Data\FX Link\autostart.lua) is started from REAPER's __startup.lua. FX Link adds ONE marked
-- block at the END of __startup.lua (after a backup) and removes only that block. Your own code never changes.
---------------------------------------------------------------------------
local AUTOSTART_SCRIPT = [=[
-- FX Link autostart watcher (written by FX Link - do not edit, it is overwritten).
-- Opens FX Link when a project that has FX Link groups opens or becomes the active tab.
local r = reaper
local last_proj, last_fn = nil, nil
local next_t, wait_until, pending_until, cooldown_until = 0, 0, 0, 0
local function running()
  local hb = tonumber(r.GetExtState("FX Link", "heartbeat"))
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
      local n = r.GetProjExtState(proj, "FX Link", "cfg")
      if n and n > 0 then wait_until, pending_until = t + 0.5, t + 3.5 else pending_until = 0 end
    end
    if t < pending_until and t >= wait_until and t >= cooldown_until then
      if running() then
        pending_until = 0
      else
        local name = r.GetExtState("FX Link", "cmd")
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

-- The command ID of FX Link (the watcher starts it by this name).
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
    local d = Util.read_all(CFG.STARTUP_FILE)
    R.as_installed = (d ~= nil and d:find(CFG.AS_BEGIN, 1, true) ~= nil)
  end
  return R.as_installed
end

function Autostart.write_script()
  r.RecursiveCreateDirectory(CFG.DATA_DIR, 0)
  return Util.write_all(CFG.AUTOSTART_FILE, AUTOSTART_SCRIPT)
end

-- Returns a message for the user.
function Autostart.install()
  if Autostart.installed(true) then return "Open automatically is already on." end
  local ans = r.ShowMessageBox(
    "FX Link will add these 3 lines at the END of your REAPER startup script:\n\n"
    .. CFG.STARTUP_FILE .. "\n\n" .. CFG.AS_BLOCK .. "\n"
    .. "Your own code in that file is not changed. A backup is saved as __startup.lua.fxlink-backup.\n"
    .. "Restart REAPER once after this change.\n\nContinue?", CFG.TITLE, 1)
  if ans ~= 1 then return nil end
  if not Autostart.write_script() then return "Cannot write " .. CFG.AUTOSTART_FILE end
  local old = Util.read_all(CFG.STARTUP_FILE)
  local backup = CFG.STARTUP_FILE .. ".fxlink-backup"
  if old and not (Util.write_all(backup, old) and Util.read_all(backup) == old) then
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
  local d = Util.read_all(CFG.STARTUP_FILE)
  if not d then Autostart.installed(true); return nil end
  local a = d:find(CFG.AS_BEGIN, 1, true)
  local b = a and d:find(CFG.AS_END, a, true)
  if not (a and b) then Autostart.installed(true); return nil end
  local stop = b + #CFG.AS_END
  if d:sub(stop, stop) == "\n" then stop = stop + 1 end
  local start = a
  if start > 1 and d:sub(start - 1, start - 1) == "\n" then start = start - 1 end -- (the blank line FX Link added)
  if not Util.write_all(CFG.STARTUP_FILE, d:sub(1, start - 1) .. d:sub(stop)) then return "Cannot write " .. CFG.STARTUP_FILE end
  Autostart.installed(true)
  return "Open automatically is off. It stops after the next REAPER restart."
end

---------------------------------------------------------------------------
-- SETTINGS of this computer: load, save, Back up / Restore / Reset all settings (the gear menu)
---------------------------------------------------------------------------
local S_DEFAULTS = { light = false, dock = 0, closed = "", close_proj = true, backup_dir = "" }
function Util.settings_lines()
  local t = {}
  for id in pairs(S.closed) do t[#t + 1] = id end
  table.sort(t)
  return { "light=" .. (S.light and "1" or "0"), "dock=" .. tostring(S.dock), "closed=" .. table.concat(t, ","),
    "close_proj=" .. (S.close_proj and "1" or "0"), "backup_dir=" .. S.backup_dir }
end
function Util.apply_setting(k, v)
  if k == "light" then S.light = (v == "1")
  elseif k == "dock" then S.dock = math.floor(tonumber(v) or 0)
  elseif k == "close_proj" then S.close_proj = (v ~= "0")
  elseif k == "backup_dir" then S.backup_dir = Util.clean(v)
  elseif k == "closed" then
    S.closed = {}
    for id in v:gmatch("[%w_]+") do S.closed[id] = true end
  end
end
function Util.reset_s()
  for k, v in pairs(S_DEFAULTS) do Util.apply_setting(k, type(v) == "boolean" and (v and "1" or "0") or tostring(v)) end
end
function Util.load_settings()
  Util.reset_s()
  for k in pairs(S_DEFAULTS) do
    local v = r.GetExtState(CFG.EXT, k)
    if v ~= "" or k == "closed" then Util.apply_setting(k, v) end
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
-- The backup folder (Windows separators, for Explorer and the file windows).
function Util.backup_dir()
  return ((S.backup_dir ~= "" and S.backup_dir or CFG.DATA_DIR):gsub("/", "\\"))
end
-- The newest backup file in the backup folder (the Restore window opens with it; nil: none).
function Util.newest_backup()
  local dir, best = Util.backup_dir(), nil
  local i = 0
  while true do
    local f = r.EnumerateFiles(dir, i)
    if not f then break end
    if f:match("^FX Link backup .*%.txt$") and (not best or f > best) then best = f end -- (the date in the name sorts)
    i = i + 1
  end
  return best and (dir .. "\\" .. best)
end
-- Opens the backup folder in Explorer (in the foreground).
function Util.show_backup_dir()
  local dir = Util.backup_dir()
  r.RecursiveCreateDirectory(dir, 0)
  r.ExecProcess('cmd.exe /C start "" explorer.exe "' .. dir .. '"', -1)
end
function Util.backup_settings()
  r.RecursiveCreateDirectory(Util.backup_dir(), 0)
  local path = Util.backup_dir() .. "\\FX Link backup " .. os.date("%Y-%m-%d %H-%M") .. ".txt"
  local ok = Util.write_all(path, "FX Link backup\n# FX Link " .. CFG.VERSION .. ", " .. os.date("%Y-%m-%d %H:%M") .. "\n"
    .. table.concat(Util.settings_lines(), "\n") .. "\n")
  if not ok then return nil, "The backup file cannot be written: " .. path end
  return path
end
function Util.restore_settings(path)
  local d = Util.read_all(path)
  if not d then return nil, "The file cannot be read." end
  if d:sub(1, 14) ~= "FX Link backup" then return nil, "This is not an FX Link backup file." end
  Util.reset_s() -- (a setting that is not in the backup: its default)
  for line in d:gmatch("[^\r\n]+") do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k and S_DEFAULTS[k] ~= nil then Util.apply_setting(k, v) end
  end
  apply_theme(S.light)
  R.dock_req, R.sdirty = S.dock, true
  return true
end
function Util.reset_settings()
  local dock = S.dock
  Util.reset_s()
  S.dock = R.docked and dock or 0 -- (the window stays where it is)
  apply_theme(S.light)
  R.sdirty = true
end

---------------------------------------------------------------------------
-- TESTS: tests/fxlink.lua sets FxLinkTest: hand it the modules and do not start the UI
---------------------------------------------------------------------------
if TESTING then
  function UI.labels_dirty() end
  local test = rawget(_G, "FxLinkTest")
  test.CFG, test.S, test.R, test.Util, test.Project, test.Fx, test.Link = CFG, S, R, Util, Project, Fx, Link
  test.Autostart = Autostart
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

local HELP_INTRO = "FX Link links plugins across tracks. Put the same plugin from a few tracks in a link group, "
  .. "move a knob in one of them, and the same knob moves in all the others."
-- The Help topics (the "?" button): 1 open at a time.
local HELP_TOPICS = {
  { title = "Getting started", text = [[
1. Open the plugin on 1 of your guitar tracks (for example Pro-Q 3) and click its window.
2. Select your guitar tracks, then click "+ Add" (Link groups) > "From focused plugin + selected tracks".
3. Move a knob in any of those plugins. The others follow.

More later? Click "+ Add" below the plugins: the focused plugin, the selected tracks, the same plugin in the whole project or in a folder.

Want to tweak one plugin on its own? Turn the group off with its switch, tweak, and turn it back on. Changes you made while it was off are not copied.]] },
  { title = "Exact or Relative", text = [[
Exact: every plugin gets the same value. Set the gain to +3 dB in one, and all of them are at +3 dB.

Relative: every plugin gets the same change. Add 2 dB in one, and each one gets 2 dB more than it had. When a knob hits the end of its range it stops there, and gets its old difference back when you move back.

Need them all equal right now? Click "Match" next to the plugin that has the right settings: the others copy it.

Automation: if a linked knob has automation on one of the tracks, the automation wins during playback (REAPER sets the knob from it). FX Link does not copy what automation or parameter modulation (LFO) does: only what you move yourself.]] },
  { title = "Only some knobs", text = [[
Set Parameters to "Picked". Then the "Linked parameters" section shows which knobs are linked.

Or set Parameters to "All except": everything is linked except the knobs in "Not linked parameters" (for example the output gain, so every track keeps its own level).

Learn: click it, move the knobs that you want in one of the plugins, and click Done. Each knob you move shows up in the list right away (it flashes blue).

Pick...: a list of all the knobs of the plugin with a search box. The linked ones are at the top.

Click the X next to a parameter to unlink it.]] },
  { title = "Plugins, Match and bypass", text = [[
The Plugins section lists every plugin of the group: the track and the plugin. Sort it by track order or by track name.

"+ Add" opens a menu:
- Focused plugin: click the plugin window first, then this.
- Selected tracks: the same plugin from every selected track (the first one, if a track has 2).
- Same plugin in whole project: every copy of this plugin in the project. Remove the ones you do not want with their X.
- Same plugin in folder...: the plugin from every track of a folder (for example "Drums").
In an empty group, they first ask which plugin (with the number of copies).

Plugins inside FX Containers work too: the row says "(in container)".

Link bypass (in Link settings): turn one plugin off or on (its bypass), and the others follow. It does not pause the link: to move one plugin alone, turn the group off with its switch.

Show plugins (in the toolbar): opens all the plugin windows of the group and brings them to the front. Then the button says "Hide plugins": click it to close them.

Click a group: its tracks are selected in REAPER. Click a plugin row: its track is selected.
Click the plugin name in a row: pick another copy of the plugin on that track (when it has 2 or more), or open its window.]] },
  { title = "Search, order and the window", text = [[
The search field filters the groups by group name, plugin name or track name.

Drag a group by its handle (the 3 lines) to change the order, or click "Sort" to put them in A to Z order.

Click the arrow before a heading to fold or open that section.

The dot before a group name flashes blue each time FX Link copies a change. "2 differ" (orange) means that 2 plugins of an Exact group are not equal to the one you moved last.

The links only work while the FX Link window is open (docked is fine).]] },
  { title = "Keys and toolbar buttons", text = [[
3 actions in REAPER's Action List (FX Link must be open):
- "FX Link - Show plugins": opens or closes the plugin windows of the selected group.
- "FX Link - Toggle group": turns the link of the selected group on or off.
- "FX Link - Group focused plugin on selected tracks": click a plugin window, select its tracks, run it: a new group with that plugin on every selected track. Tracks without the plugin are skipped.

Give them a key or a toolbar button in the Action List.]] },
  { title = "Where your stuff is saved", text = [[
In the project: your groups, their plugins and settings. Save the project to keep them.

On this computer: the Light theme, the window dock, the folded sections and Close with project. "Back up..." in the gear menu saves them to a file in the backup folder (REAPER's Data\FX Link folder, or the one you pick with "Change..."). "Show" opens that folder.]] },
  { title = "Open and close by itself", text = [[
In the gear menu:
- Open automatically: FX Link opens by itself when you open (or switch to) a project that has FX Link groups. It adds 3 marked lines to REAPER's __startup.lua (with a backup). Restart REAPER once after you turn it on.
- Close with project: FX Link closes when you close its project tab, or when File > Close / New / Open project replaces it. Switching tabs and "Save as" keep it open.]] },
}
local HELP_GROUPS = [[A link group holds the same plugin from a few tracks, for example Pro-Q 3 on your 4 guitar tracks. Move a knob in one, and the same knob moves in all the others.

Click a group to see and change it below (its tracks are selected in REAPER). Its switch turns the link on or off. Drag the 3 lines to change the order. Right-click a group to rename it.

The groups are saved in the project.]]
local HELP_SETTINGS = [[Mode:
- Exact: every plugin gets the same value.
- Relative: every plugin gets the same change, and keeps its own setting.

Parameters: All, only the ones in "Linked parameters" (Picked), or All except the ones in "Not linked parameters".

Link bypass: turn one plugin off or on (its bypass), and the others follow.

Only changes are copied: a plugin that you add keeps its settings until you move a knob (or click Match).

Relative uses real units when the plugin shows them (dB, ms, %): +2 dB is +2 dB on every plugin.

Snapshots: the disk next to A or B stores the linked knobs of all the plugins there; A or B sets them back (Ctrl+Z undoes it). The arrows switch between A and B to compare 2 versions (store your changes first). The ring shows the snapshot you are on. They are saved in the project.]]
local HELP_EXCEPT = [[The knobs that this group does NOT link (Parameters: All except). Every other knob is linked.

Good for the output gain or pan: the same EQ curve on every track, but each keeps its own level.

Learn: click it, move the knobs that you want to leave out in one of the plugins, then click Done.
Pick...: all the knobs of the plugin, with a search box.

The X links a knob again.]]
local HELP_PARAMS = [[The knobs that this group links.

Learn: click it, move the knobs that you want in one of the plugins, then click Done.
Pick...: all the knobs of the plugin, with a search box.

The X unlinks a knob.]]
local HELP_PLUGINS = [[The plugins of this group: the track and the plugin.

Switch at the left: pause this plugin. A paused plugin does not follow the group, and its changes are not copied. Turn it on again and it keeps its own settings (click Match to make it equal).
Click a row: its track is selected in REAPER.
Click the plugin name: pick another copy of the plugin on that track, or open its window.

Match: the other plugins copy this one (all linked knobs). Ctrl+Z undoes it.
Orange track name: this plugin is not equal to the plugin moved last (Exact groups; the group row says "2 differ").
Missing: the plugin was deleted, or the track came from a template. Find looks for it again on a track with the same name.
Right-click a row: Open plugin window, Select track, Pause, Remove.
X (or the Delete key on a row): removes it from the group (the plugin and its settings stay as they are).
F2: rename the selected group.]]

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
-- fold: the id of a section that folds (S.closed); an arrow before the title opens / closes it. Returns open.
-- reserve: the room for the heading buttons at the right (UI.heading_button, from right to left).
function UI.heading(text, help, id, fold, reserve)
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
  local fh = ImGui.GetFrameHeight(ctx)
  local open = true
  ImGui.PushFont(ctx, head_font)
  local maxw = math.max(30, full - (help and CFG.HELP_ICON + 8 or 0) - (reserve or 0) - (fold and 16 or 0) - 8)
  if fold then
    open = not S.closed[fold]
    local clicked = ImGui.InvisibleButton(ctx, "##fold_" .. fold, 14, fh)
    local hov = ImGui.IsItemHovered(ctx)
    local dl, cx, cy = ImGui.GetWindowDrawList(ctx), sx + 6, sy + fh / 2
    local col = hov and COL.TEXT_MAIN or COL.HEADING
    if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col)
    else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col) end
    ImGui.SameLine(ctx, 0, 2)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, UI.trunc(text, maxw))
    clicked = clicked or ImGui.IsItemClicked(ctx)
    if hov or ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    if clicked then open = not open; S.closed[fold] = (not open) or nil; R.sdirty = true end
  else
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, UI.trunc(text, maxw))
  end
  ImGui.PopFont(ctx)
  local _, ty = ImGui.GetItemRectMax(ctx)
  R.heading_x1, R.heading_y = sx + full - (help and CFG.HELP_ICON + 8 or 0), sy
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
  return open
end

-- A button on the line of the last heading, right-aligned (each next one goes left of the one before).
-- "+ Add" (the template of all 4 scripts): a ghost button on the heading line that opens a dropdown menu.
UI.ADD = "+ Add"
function UI.add_w() return UI.btn_w(UI.ADD) end

function UI.heading_button(label, tip, kind, w)
  w = w or UI.btn_w(label)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  R.heading_x1 = R.heading_x1 - w
  ImGui.SetCursorScreenPos(ctx, R.heading_x1, R.heading_y)
  local hit = UI.button(label, w, nil, kind or "ghost")
  if tip then UI.tip(tip) end
  R.heading_x1 = R.heading_x1 - 4
  ImGui.SetCursorScreenPos(ctx, x, y)
  return hit
end

-- The label column: returns the control column x and wide (the label is left of its control).
function UI.row_start(label)
  local x0 = ImGui.GetCursorPosX(ctx)
  local wide = ImGui.GetContentRegionAvail(ctx) >= CFG.LABEL_W + CFG.FORM_MIN_WIDE
  ImGui.PushFont(ctx, bold)
  UI.row_text(label)
  ImGui.PopFont(ctx)
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, wide and (x0 + CFG.LABEL_W) or x0)
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

-- A question with 2 buttons (a popup in the window). yes = nil: a message with only "OK".
-- A question (yes = the button text): a window. Without a question: a notice at the bottom of the window.
function UI.ask(text, yes, fn)
  if not yes then UI.notice(text); return end
  R.ask = { text = text, yes = yes, fn = fn, open = true }
end
-- A short notice at the bottom of the window (grey; warn: orange); it goes away after CFG.NOTICE_SEC (+1 s per
-- extra line). Line breaks become ", " (1 paragraph).
function UI.notice(text, warn)
  text = tostring(text or ""):gsub("\n\n", " "):gsub(":\n", ": "):gsub("\n", ", ")
  local _, lines = text:gsub(", ", "")
  R.notice = { text = text, warn = warn, t = Util.now() + CFG.NOTICE_SEC + math.min(6, lines) }
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
  if a.open then ImGui.OpenPopup(ctx, "FX Link##ask"); a.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if ImGui.BeginPopupModal(ctx, "FX Link##ask", nil, ImGui.WindowFlags_AlwaysAutoResize()) then
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

-- Small icons drawn on the last item (a square button): a disk (store) and 2 arrows (compare).
function UI.draw_disk(dl, col)
  local x1, y1 = ImGui.GetItemRectMin(ctx)
  local x2, y2 = ImGui.GetItemRectMax(ctx)
  local cx, cy = math.floor((x1 + x2) / 2), math.floor((y1 + y2) / 2)
  local r0 = 6
  ImGui.DrawList_AddRect(dl, cx - r0, cy - r0, cx + r0, cy + r0, col, 2, 0, 1.5)
  ImGui.DrawList_AddRectFilled(dl, cx - 3, cy - r0, cx + 3, cy - 2, col)
  ImGui.DrawList_AddRect(dl, cx - 4, cy + 1, cx + 4, cy + r0, col, 0, 0, 1)
end
function UI.draw_swap(dl, col)
  local x1, y1 = ImGui.GetItemRectMin(ctx)
  local x2, y2 = ImGui.GetItemRectMax(ctx)
  local cx, cy = math.floor((x1 + x2) / 2), math.floor((y1 + y2) / 2)
  ImGui.DrawList_AddLine(dl, cx - 6, cy - 3, cx + 5, cy - 3, col, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, cx + 7, cy - 3, cx + 3, cy - 6, cx + 3, cy, col)
  ImGui.DrawList_AddLine(dl, cx + 6, cy + 3, cx - 5, cy + 3, col, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, cx - 7, cy + 3, cx - 3, cy, cx - 3, cy + 6, col)
end

function UI.draw_gear_icon(dl, cx, cy, col)
  for k = 0, 7 do
    local a = k * math.pi / 4
    local c, sn = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * 5, cy + sn * 5, cx + c * 8.5, cy + sn * 8.5, col, 3)
  end
  ImGui.DrawList_AddCircle(dl, cx, cy, 4.5, col, 0, 3)
end

-- The cached labels and lists (rebuilt after a change of the groups or the project, not every frame).
function UI.labels_dirty() R.labels, R.picked_cache, R.vis, R.order, R.pn = nil, nil, nil, nil, nil end
function UI.labels()
  if R.labels then return R.labels end
  local L = {}
  for _, g in ipairs(P.groups) do
    local found = 0
    for _, m in ipairs(g.members) do if R.rt[m] then found = found + 1 end end
    local n = #g.members
    local txt = n == 0 and "empty" or (n .. "  " .. (g.plug ~= "" and g.plug or "plugin"))
    if found < n then txt = txt .. "  (" .. (n - found) .. " missing)" end
    L[g] = txt
  end
  R.labels = L
  return L
end

-- Search: the group name or plugin matches (whole group), or one of its tracks matches.
function UI.name_match(g)
  local q = R.search_low
  return q == "" or g.name:lower():find(q, 1, true) ~= nil or g.plug:lower():find(q, 1, true) ~= nil
end
function UI.visible(g)
  if R.search_low == "" then return true end
  R.vis = R.vis or {}
  local v = R.vis[g]
  if v == nil then
    v = UI.name_match(g)
    if not v then
      for _, m in ipairs(g.members) do
        local rt = R.rt[m]
        if rt and rt.track_low:find(R.search_low, 1, true) then v = true; break end
      end
    end
    R.vis[g] = v
  end
  return v
end

-- The plugins of a group in the order of its sort (cached; missing plugins last).
function UI.order(g)
  R.order = R.order or {}
  local t = R.order[g]
  if t then return t end
  t = {}
  for _, m in ipairs(g.members) do t[#t + 1] = m end
  local by_name = g.sort == "name"
  table.sort(t, function(a, b)
    local ra, rb = R.rt[a], R.rt[b]
    if not ra or not rb then return ra ~= nil and rb == nil end
    if by_name and ra.tname_low ~= rb.tname_low then return ra.tname_low < rb.tname_low end
    if ra.num ~= rb.num then return ra.num < rb.num end
    return ra.idx < rb.idx
  end)
  R.order[g] = t
  return t
end

-- The name of a parameter of a group's plugin (cached).
function UI.pname(g, p)
  R.pn = R.pn or {}
  local t = R.pn[g]
  if not t then t = {}; R.pn[g] = t end
  if t[p] == nil then
    local first
    for _, m in ipairs(g.members) do first = first or R.rt[m] end
    if not first then return "Parameter " .. (p + 1) end
    t[p] = select(2, r.TrackFX_GetParamName(first.track, first.idx, p, ""))
  end
  return t[p]
end

-- The groups list: a row per group (drag handle, switch, name, plugin and count, remove).
function UI.draw_groups()
  local reserve = UI.add_w() + UI.btn_w("Sort") + 8
  local open = UI.heading("Link groups", HELP_GROUPS, "groups", "groups", reserve)
  local ng_hit = UI.heading_button(UI.ADD .. "##newgroup", "Make a new link group.", "ghost", UI.add_w())
  if ng_hit then ImGui.OpenPopup(ctx, "##newgroup") end
  local ngx, ngy = ImGui.GetItemRectMax(ctx)
  ImGui.SetNextWindowPos(ctx, ngx, ngy + 4, ImGui.Cond_Appearing(), 1, 0) -- (drops down below the button, right-aligned)
  if ImGui.BeginPopup(ctx, "##newgroup") then
    if ImGui.MenuItem(ctx, "From focused plugin + selected tracks") then Link.quick_group() end
    UI.tip("Click a plugin window, select its tracks, then this: a new group with that plugin on every selected track.")
    if ImGui.MenuItem(ctx, "Empty group...") then
      Util.ask_name("FX Link - New group", "Group " .. (#P.groups + 1), function(n)
        P.groups[#P.groups + 1] = Project.new_group(n)
        P.cur = #P.groups
        Util.mark_pdirty(); Fx.resolve(false)
      end)
    end
    ImGui.EndPopup(ctx)
  end
  if #P.groups > 1 and UI.heading_button("Sort", "Sort the groups by name (A to Z).") then
    local cur = P.groups[P.cur]
    table.sort(P.groups, function(a, b) return a.name:lower() < b.name:lower() end)
    for i, g in ipairs(P.groups) do if g == cur then P.cur = i end end
    Util.mark_pdirty()
  end
  if not open then return end
  if #P.groups == 0 then
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No groups yet. Click \"+ Add\" to make one.")
    return
  end
  local L = UI.labels()
  local aw = ImGui.GetContentRegionAvail(ctx)
  local can_drag = R.search_low == ""
  local _, my = ImGui.GetMousePos(ctx)
  local del, target, shown = nil, nil, 0
  for i, g in ipairs(P.groups) do
    if UI.visible(g) then
      shown = shown + 1
      ImGui.PushID(ctx, i)
      local x, y = ImGui.GetCursorScreenPos(ctx)
      local h = ImGui.GetFrameHeight(ctx)
      local dl = ImGui.GetWindowDrawList(ctx)
      -- the drag handle (3 lines)
      ImGui.InvisibleButton(ctx, "##drag", 14, h)
      local hh = ImGui.IsItemHovered(ctx)
      if can_drag and ImGui.IsItemActivated(ctx) then R.gdrag = g end
      if can_drag and (hh or R.gdrag == g) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS()) end
      UI.tip(can_drag and "Drag to change the order." or "Clear the search to change the order.")
      local lc = (R.gdrag == g and COL.ACCENT) or (hh and can_drag and COL.TEXT_MAIN) or COL.TEXT_DIM
      local cy = math.floor(y + h / 2) + 0.5
      for k = -1, 1 do ImGui.DrawList_AddLine(dl, x + 2, cy + k * 4, x + 12, cy + k * 4, lc, 1.5) end
      if R.gdrag and R.gdrag ~= g and my >= y and my < y + h then target = i end
      ImGui.SameLine(ctx, 0, 6)
      local ch, nv = UI.toggle("##on", g.on)
      UI.tip(g.on and "On: this group links its plugins. Click to turn it off." or "Off: this group links nothing. Click to turn it on.")
      if ch then g.on = nv; Link.group_changed(g) end
      ImGui.SameLine(ctx, 0, 8)
      local rx = ImGui.GetCursorScreenPos(ctx)
      local rw = math.max(40, x + aw - rx - CFG.X_BTN - 8)
      local sel = (P.cur == i)
      if ImGui.InvisibleButton(ctx, "##row", rw, h) then P.cur = i; Util.mark_pdirty(); Fx.select_tracks(g.members) end
      local hov = ImGui.IsItemHovered(ctx)
      if ImGui.IsItemClicked(ctx, 1) then P.cur = i; R.gmenu = g end
      if sel or hov then ImGui.DrawList_AddRectFilled(dl, rx, y, rx + rw, y + h, sel and COL.ACTIVE_BG or COL.ROW_HOVER, 6) end
      -- the activity dot: blue for a moment after each copy
      local a = R.act[g] and 1 - (Util.now() - R.act[g]) / CFG.ACT_SEC
      local dcx, dcy = rx + 12, math.floor(y + h / 2) + 0.5
      if a and a > 0 then
        ImGui.DrawList_AddCircleFilled(dl, dcx, dcy, 4, (COL.ACCENT_HOVER & 0xFFFFFF00) | math.floor(0x40 + 0xBF * a))
      else
        ImGui.DrawList_AddCircle(dl, dcx, dcy, 3.5, g.on and COL.TOGGLE_OFF or COL.LINE, 0, 1.2)
      end
      -- the out-of-sync badge (Exact groups): "2 differ" in orange at the right of the row
      local df = R.differ and R.differ[g]
      local badge = df and (df.n .. " differ") or nil
      local bw = badge and ((ImGui.CalcTextSize(ctx, badge)) + 12) or 0
      if badge then
        ImGui.DrawList_AddText(dl, rx + rw - bw + 4, UI.text_y(y), COL.ORANGE, badge)
        if hov and ImGui.IsMouseHoveringRect(ctx, rx + rw - bw, y, rx + rw, y + h) then
          ImGui.SetTooltip(ctx, df.n .. " plugin(s) of this group are not equal to the plugin moved last. "
            .. "They are marked orange in Plugins: click Match on the one with the right settings.")
        end
      end
      local info = L[g] or ""
      local iw = (ImGui.CalcTextSize(ctx, info))
      local tx = rx + 24
      local tw_room = rw - 24 - bw
      ImGui.PushFont(ctx, bold)
      local name = UI.trunc(g.name, math.max(20, tw_room - iw - 16))
      ImGui.DrawList_AddText(dl, tx, UI.text_y(y), g.on and COL.TEXT_MAIN or COL.TEXT_DIM, name)
      local nw = (ImGui.CalcTextSize(ctx, name))
      ImGui.PopFont(ctx)
      ImGui.DrawList_AddText(dl, tx + nw + 12, UI.text_y(y), COL.TEXT_DIM, UI.trunc(info, math.max(10, tw_room - nw - 20)))
      ImGui.SameLine(ctx, 0, 8)
      ImGui.SetCursorScreenPos(ctx, x + aw - CFG.X_BTN, y + (h - CFG.X_BTN) / 2)
      if UI.remove_x_button("##del", CFG.X_BTN) then del = i end
      UI.tip("Delete this group (the plugins and their settings do not change).")
      ImGui.SetCursorScreenPos(ctx, x, y + h)
      ImGui.Dummy(ctx, 0, 0)
      ImGui.PopID(ctx)
    end
  end
  if shown == 0 then ImGui.TextColored(ctx, COL.TEXT_DIM, "No group matches the search.") end
  -- a drag moves the group to the row under the mouse
  if R.gdrag then
    if not ImGui.IsMouseDown(ctx, 0) then R.gdrag = nil
    elseif target then
      local from
      for i, g in ipairs(P.groups) do if g == R.gdrag then from = i end end
      if from and from ~= target then
        local cur = P.groups[P.cur]
        table.remove(P.groups, from)
        table.insert(P.groups, target, R.gdrag)
        for i, g in ipairs(P.groups) do if g == cur then P.cur = i end end
        Util.mark_pdirty()
      end
    end
  end
  if del then
    local g = P.groups[del]
    UI.ask("Delete the group \"" .. g.name .. "\"? The plugins and their settings do not change.", "Delete", function()
      for i, g2 in ipairs(P.groups) do
        if g2 == g then table.remove(P.groups, i); break end
      end
      if R.learn and R.learn.g == g then R.learn = nil end
      P.cur = Util.clamp(P.cur, 1, math.max(1, #P.groups))
      Util.mark_pdirty(); Fx.resolve(false)
    end)
  end
  -- the right-click menu of a group row
  if R.gmenu then ImGui.OpenPopup(ctx, "##gmenu"); R.gmenu_g = R.gmenu; R.gmenu = nil end
  if ImGui.BeginPopup(ctx, "##gmenu") then
    local g = R.gmenu_g
    if g and ImGui.MenuItem(ctx, "Rename...") then
      Util.ask_name("FX Link - Rename group", g.name, function(n) g.name = n; Util.mark_pdirty(); UI.labels_dirty() end)
    end
    ImGui.EndPopup(ctx)
  end
end

-- The parameter picker (a popup): a search box and a tick box per parameter; the linked ones at the top.
function UI.picker_sort(g)
  table.sort(R.pnames, function(a, b)
    local pa, pb = g.params[a.p] and 1 or 0, g.params[b.p] and 1 or 0
    if pa ~= pb then return pa > pb end
    return a.p < b.p
  end)
end
function UI.draw_picker(g)
  if R.pick_open then
    ImGui.OpenPopup(ctx, "##picker"); R.pick_open = nil
    local first
    for _, m in ipairs(g.members) do first = first or R.rt[m] end
    R.pnames = {}
    if first then
      for p = 0, first.nparams - 1 do
        local _, nm = r.TrackFX_GetParamName(first.track, first.idx, p, "")
        R.pnames[#R.pnames + 1] = { p = p, name = nm, low = nm:lower() }
      end
    end
    UI.picker_sort(g)
    R.pick_search = ""
  end
  if not ImGui.BeginPopup(ctx, "##picker") then return end
  ImGui.SetNextItemWidth(ctx, 280)
  if ImGui.IsWindowAppearing(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
  local chs, txt = ImGui.InputTextWithHint(ctx, "##search", "Search parameters", R.pick_search)
  if chs then R.pick_search = txt end
  local q = R.pick_search:lower()
  local resort = false
  if ImGui.BeginChild(ctx, "##plist", 280, CFG.PICK_H) then
    if #R.pnames == 0 then ImGui.TextColored(ctx, COL.TEXT_DIM, "Add a plugin to this group first.") end
    for _, e in ipairs(R.pnames) do
      if q == "" or e.low:find(q, 1, true) then
        local on = g.params[e.p] == true
        local ch, nv = ImGui.Checkbox(ctx, e.name .. "##p" .. e.p, on)
        if ch then
          g.params[e.p] = nv or nil; Link.group_changed(g); resort = true
          if nv then R.flash = { g = g, p = e.p, t = Util.now() } end
        end
      end
    end
    ImGui.EndChild(ctx)
  end
  if resort then UI.picker_sort(g) end
  if UI.button("Clear all", 100) then g.params = {}; Link.group_changed(g); UI.picker_sort(g) end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Close", 90) then ImGui.CloseCurrentPopup(ctx) end
  ImGui.EndPopup(ctx)
end

-- Link settings: Mode, Parameters, Link bypass.
function UI.draw_settings_section(g)
  if not UI.heading("Link settings: " .. g.name, HELP_SETTINGS, "settings", "settings") then return end
  UI.row_start("Mode")
  ImGui.SetNextItemWidth(ctx, CFG.MODE_W)
  if ImGui.BeginCombo(ctx, "##mode", g.mode == "exact" and "Exact" or "Relative") then
    if ImGui.Selectable(ctx, "Exact", g.mode == "exact") then g.mode = "exact"; Link.group_changed(g) end
    UI.tip("Every plugin gets the same value.")
    if ImGui.Selectable(ctx, "Relative", g.mode == "rel") then g.mode = "rel"; Link.group_changed(g) end
    UI.tip("Every plugin gets the same change, and keeps its own setting.")
    ImGui.EndCombo(ctx)
  end
  UI.row_start("Parameters")
  ImGui.SetNextItemWidth(ctx, CFG.MODE_W)
  local pm = g.except and "All except" or (g.all and "All" or "Picked")
  local function pmode(all, except)
    if g.all ~= all or g.except ~= except then
      if g.except ~= except then g.params = {} end -- (the list means the other thing now: start empty)
      g.all, g.except = all, except
      Link.group_changed(g)
    end
  end
  if ImGui.BeginCombo(ctx, "##params", pm) then
    if ImGui.Selectable(ctx, "All", pm == "All") then pmode(true, false) end
    UI.tip("Every parameter of the plugin is linked.")
    if ImGui.Selectable(ctx, "Picked", pm == "Picked") then pmode(false, false) end
    UI.tip("Only the parameters in 'Linked parameters'.")
    if ImGui.Selectable(ctx, "All except", pm == "All except") then pmode(true, true) end
    UI.tip("Every parameter except the ones in 'Not linked parameters' (for example the output gain).")
    ImGui.EndCombo(ctx)
  end
  UI.row_start("Link bypass")
  local ch, nv = UI.toggle("##bypass", g.bypass)
  UI.tip("On: turn one plugin of this group off or on (its bypass), and the others follow. This does not pause the link: for that, turn the group off with its switch.")
  if ch then g.bypass = nv; Link.group_changed(g) end
  -- Snapshots: [A][disk] [B][disk] [swap]; A / B recall, the disk stores, swap recalls the other one
  UI.row_start("Snapshots")
  local h = math.floor(ImGui.GetFrameHeight(ctx))
  local can = #g.members > 0
  local cur = R.snap_cur[g]
  local dl = ImGui.GetWindowDrawList(ctx)
  for k, slot in ipairs({ "A", "B" }) do
    ImGui.PushID(ctx, slot)
    if k == 2 then ImGui.SameLine(ctx, 0, 10) end
    local sn = g.snap[slot]
    local on = cur == slot and sn
    if on then ImGui.PushFont(ctx, bold) end
    ImGui.BeginDisabled(ctx, not sn)
    if UI.button(slot, h, h) then Link.snap_recall(g, slot) end
    ImGui.EndDisabled(ctx)
    if on then
      ImGui.PopFont(ctx)
      local x1, y1 = ImGui.GetItemRectMin(ctx)
      local x2, y2 = ImGui.GetItemRectMax(ctx)
      ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, COL.TEXT_MAIN, 6, 0, 1.5) -- (the current snapshot: a ring)
    end
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, sn and ("Recall snapshot " .. slot .. " (stored " .. sn.t .. "). Ctrl+Z undoes it.")
        or ("Snapshot " .. slot .. " is empty. Click the disk next to it to store it."))
    end
    ImGui.SameLine(ctx, 0, 2)
    ImGui.BeginDisabled(ctx, not can)
    local hit = UI.button("##store", h, h)
    ImGui.EndDisabled(ctx)
    UI.draw_disk(dl, can and COL.TEXT_MAIN or COL.TEXT_DIM)
    if hit then Link.snap_store(g, slot); R.snap_cur[g] = slot end
    UI.tip("Store the linked knobs of all the plugins as snapshot " .. slot .. (sn and " (replaces the one from " .. sn.t .. ")." or "."))
    ImGui.PopID(ctx)
  end
  ImGui.SameLine(ctx, 0, 10)
  local both = g.snap.A and g.snap.B
  ImGui.BeginDisabled(ctx, not both)
  local sw_hit = UI.button("##swap", h, h)
  ImGui.EndDisabled(ctx)
  UI.draw_swap(dl, both and COL.TEXT_MAIN or COL.TEXT_DIM)
  if sw_hit then Link.snap_recall(g, cur == "A" and "B" or "A") end
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, both and "Compare: switch between A and B. Changes since the last recall or store are not kept: store them first."
      or "Compare: store both A and B first.")
  end
end

-- Linked parameters (Picked) or Not linked parameters (All except): a row per parameter; Learn and Pick... on
-- the heading line.
function UI.draw_params(g)
  local list = Link.chosen(g)
  local learning = R.learn and R.learn.g == g
  local ex = g.except
  local open = UI.heading((ex and "Not linked parameters (" or "Linked parameters (") .. #list .. ")",
    ex and HELP_EXCEPT or HELP_PARAMS, "params", "params", UI.btn_w("Pick...") + 74 + 8)
  if UI.heading_button(learning and "Done" or "Learn", learning and "Click when you are ready."
      or "Click, then move the knobs that you want in one of the plugins. Each one is added.",
      learning and "primary" or nil, 70) then
    Link.learn(g)
  end
  if UI.heading_button("Pick...", "All the parameters of the plugin, with a search box.") then R.pick_open = true end
  UI.draw_picker(g)
  if not open then return end
  ImGui.PushTextWrapPos(ctx, 0)
  if learning then
    ImGui.TextColored(ctx, COL.ACCENT_HOVER, ex
      and "Learning: move the knobs that you do NOT want linked in one of the plugins. Click Done when you are ready."
      or "Learning: move the knobs that you want in one of the plugins. Click Done when you are ready.")
  elseif #list == 0 then
    ImGui.TextColored(ctx, COL.TEXT_DIM, ex and "None yet: every parameter is linked. Click Learn or Pick... to leave some out."
      or "None yet. Click Learn or Pick... to add parameters.")
  end
  ImGui.PopTextWrapPos(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local now = Util.now()
  local rm
  for _, p in ipairs(list) do
    ImGui.PushID(ctx, p)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local h = ImGui.GetFrameHeight(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.Dummy(ctx, aw - CFG.X_BTN - 8, h)
    local f = R.flash
    if f and f.g == g and f.p == p then
      local a = 1 - (now - f.t) / CFG.FLASH_SEC
      if a > 0 then
        ImGui.DrawList_AddRectFilled(dl, x, y, x + aw - CFG.X_BTN - 8, y + h, (COL.ACCENT & 0xFFFFFF00) | math.floor(0x70 * a), 6)
      else R.flash = nil end
    end
    ImGui.DrawList_AddText(dl, x + 8, UI.text_y(y), COL.TEXT_MAIN, UI.trunc(UI.pname(g, p), aw - CFG.X_BTN - 24))
    ImGui.SameLine(ctx, 0, 8)
    ImGui.SetCursorScreenPos(ctx, x + aw - CFG.X_BTN, y + (h - CFG.X_BTN) / 2)
    if UI.remove_x_button("##rp", CFG.X_BTN) then rm = p end
    UI.tip(ex and "Link this parameter again (remove it from this list)." or "Unlink this parameter.")
    ImGui.SetCursorScreenPos(ctx, x, y + h)
    ImGui.Dummy(ctx, 0, 0)
    ImGui.PopID(ctx)
  end
  if rm then g.params[rm] = nil; Link.group_changed(g) end
end

-- Plugins: a row per plugin (track, plugin, Match, remove), the sort on the heading line, the add buttons.
-- Remove a plugin from its group, after a question (the Delete key and the row's right-click menu).
function UI.ask_remove_member(g, m)
  local who = R.rt[m] and R.rt[m].track_label or ((m.tname or "") ~= "" and m.tname or "this plugin")
  UI.ask("Remove " .. who .. " from the group \"" .. g.name .. "\"?\n(The plugin and its settings do not change.)",
    "Remove", function()
      for i, o in ipairs(g.members) do if o == m then table.remove(g.members, i); break end end
      if #g.members == 0 then g.ident, g.plug = "", "" end
      Util.mark_pdirty(); Fx.resolve(false)
    end)
end

function UI.draw_plugins(g)
  local sort_label = g.sort == "name" and "Sort: track name" or "Sort: track order"
  local df = R.differ and R.differ[g]
  local open = UI.heading("Plugins (" .. #g.members .. (df and (", " .. df.n .. " differ") or "") .. ")", HELP_PLUGINS, "plugins", "plugins",
    UI.btn_w("Sort: track order") + 8)
  if UI.heading_button(sort_label, "How this list is sorted.") then ImGui.OpenPopup(ctx, "##psort") end
  if ImGui.BeginPopup(ctx, "##psort") then
    if ImGui.Selectable(ctx, "Track order", g.sort == "track") then g.sort = "track"; Util.mark_pdirty(); R.order = nil end
    if ImGui.Selectable(ctx, "Track name", g.sort == "name") then g.sort = "name"; Util.mark_pdirty(); R.order = nil end
    ImGui.EndPopup(ctx)
  end
  if not open then R.hover_m = nil; return end
  if #g.members == 0 then
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No plugins yet. Click \"+ Add\" below to add them.")
  end
  local aw = ImGui.GetContentRegionAvail(ctx)
  local mw = UI.btn_w("Match")
  local tgl_w = math.floor(math.min(20, ImGui.GetFrameHeight(ctx) - 4) * 1.8) + 6 -- (the pause switch)
  local col_w = math.floor((aw - tgl_w - CFG.X_BTN - mw - 24) * 0.55)
  local filter = R.search_low ~= "" and not UI.name_match(g)
  local del, match, hover_m
  if #g.members > 0 then -- the column labels
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    ImGui.PushFont(ctx, bold)
    ImGui.DrawList_AddText(dl, x + tgl_w + 8, y, COL.TEXT_DIM, "Track")
    ImGui.DrawList_AddText(dl, x + tgl_w + col_w, y, COL.TEXT_DIM, "Plugin")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, ImGui.GetFontSize(ctx) - 2)
  end
  for i, m in ipairs(UI.order(g)) do
    local rt = R.rt[m]
    if not filter or (rt and rt.track_low:find(R.search_low, 1, true)) then
      ImGui.PushID(ctx, i)
      local x0, y = ImGui.GetCursorScreenPos(ctx)
      local x = x0 + tgl_w
      local h = ImGui.GetFrameHeight(ctx)
      local dl = ImGui.GetWindowDrawList(ctx)
      local row_w = aw - tgl_w - CFG.X_BTN - mw - 16
      if rt then
        local tch, tv = UI.toggle("##live", not m.off)
        if tch then Link.set_paused(m, not tv) end
        UI.tip(m.off and "Paused: this plugin does not follow the group. Click to link it again."
          or "Linked. Click to pause this plugin (it stops following the group).")
        ImGui.SetCursorScreenPos(ctx, x, y)
        -- the track part selects the track; the plugin name opens the dropdown (and selects the track too)
        local sel_hit = ImGui.InvisibleButton(ctx, "##sel", col_w - 4, h)
        local hov1 = ImGui.IsItemHovered(ctx)
        UI.tip("Select this track in REAPER.")
        ImGui.SameLine(ctx, 0, 4)
        local fx_w = math.max(20, row_w - col_w)
        local fx_hit = ImGui.InvisibleButton(ctx, "##fx", fx_w, h)
        local hov2 = ImGui.IsItemHovered(ctx)
        UI.tip("Pick another copy of the plugin on this track, or open its window.")
        if hov1 or hov2 then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()); hover_m = m end
        if r.IsTrackSelected(rt.track) or hov1 or hov2 then
          ImGui.DrawList_AddRectFilled(dl, x, y, x + row_w, y + h, (hov1 or hov2) and COL.ROW_HOVER or COL.ACTIVE_BG, 6)
        end
        if sel_hit or fx_hit then Fx.select_tracks({ m }) end
        if fx_hit then
          R.slot_m, R.slot_g = m, g
          R.slot_list = Fx.copies(g, rt.track)
          R.slot_open = true -- (opened below, outside the row ID: the same ID as BeginPopup)
        end
        local odd = df and df.m[m]
        ImGui.DrawList_AddText(dl, x + 8, UI.text_y(y), m.off and COL.TEXT_DIM or odd and COL.ORANGE or COL.TEXT_MAIN,
          UI.trunc(rt.track_label, col_w - 12))
        local fl = UI.trunc(rt.fx_label, fx_w - 24)
        ImGui.DrawList_AddText(dl, x + col_w, UI.text_y(y), hov2 and COL.TEXT_MAIN or COL.TEXT_DIM, fl)
        local ax = x + col_w + (ImGui.CalcTextSize(ctx, fl)) + 8
        local ay = math.floor(y + h / 2) + 0.5
        ImGui.DrawList_AddTriangleFilled(dl, ax, ay - 2, ax + 7, ay - 2, ax + 3.5, ay + 2.5, hov2 and COL.TEXT_MAIN or COL.TEXT_DIM)
        ImGui.SameLine(ctx, 0, 8)
        ImGui.SetCursorScreenPos(ctx, x0 + aw - CFG.X_BTN - 8 - mw, y)
        if UI.button("Match", mw, h, "ghost") then match = m end
        if ImGui.IsItemHovered(ctx) then
          local t = "The other plugins of this group copy this one (all linked parameters). Ctrl+Z undoes it."
          if odd then
            local names = {}
            for k, pp in ipairs(odd) do names[k] = UI.pname(g, pp) end
            t = t .. "\n\nOrange: not equal to the plugin moved last. Different: " .. table.concat(names, ", ")
              .. (#odd >= 3 and ", ..." or "")
          end
          ImGui.SetTooltip(ctx, t)
        end
      else
        ImGui.Dummy(ctx, row_w, h)
        local who = (m.tname or "") ~= "" and (m.tname .. ", " .. (m.fname ~= "" and m.fname or g.plug)) or "the plugin was deleted"
        ImGui.DrawList_AddText(dl, x + 8, UI.text_y(y), COL.TEXT_DIM, UI.trunc("Missing (" .. who .. ")", row_w - 16))
        ImGui.SameLine(ctx, 0, 8)
        ImGui.SetCursorScreenPos(ctx, x0 + aw - CFG.X_BTN - 8 - mw, y)
        if UI.button("Find", mw, h, "ghost") then
          local ok, err = Fx.find_again(g, m)
          if not ok then UI.notice(err, true) end
        end
        UI.tip("Find again: look for a free " .. g.plug .. " on a track with the same name (for example after a track template).")
      end
      ImGui.SameLine(ctx, 0, 8)
      ImGui.SetCursorScreenPos(ctx, x0 + aw - CFG.X_BTN, y + (h - CFG.X_BTN) / 2)
      if UI.remove_x_button("##rm", CFG.X_BTN) then del = m end
      UI.tip("Remove from the group (the plugin and its settings do not change).")
      local mx, my = ImGui.GetMousePos(ctx)
      if ImGui.IsMouseClicked(ctx, 1) and mx >= x0 and mx < x0 + aw and my >= y and my < y + h
          and ImGui.IsWindowHovered(ctx) then
        R.rowmenu = m; R.rowmenu_open = true -- (the right-click menu of this row, opened below)
      end
      ImGui.SetCursorScreenPos(ctx, x0, y + h)
      ImGui.Dummy(ctx, 0, 0)
      ImGui.PopID(ctx)
    end
  end
  -- the right-click menu of a plugin row
  if R.rowmenu_open then ImGui.OpenPopup(ctx, "##rowmenu"); R.rowmenu_open = nil end
  if ImGui.BeginPopup(ctx, "##rowmenu") then
    local m = R.rowmenu
    local rt = m and R.rt[m]
    if m and R.group_of[m] == g then
      if ImGui.MenuItem(ctx, "Open plugin window", nil, false, rt ~= nil) then r.TrackFX_Show(rt.track, rt.idx, 3) end
      if ImGui.MenuItem(ctx, "Select track", nil, false, rt ~= nil) then Fx.select_tracks({ m }) end
      if ImGui.MenuItem(ctx, m.off and "Resume (link again)" or "Pause", nil, false, rt ~= nil) then Link.set_paused(m, not m.off) end
      ImGui.Separator(ctx)
      if ImGui.MenuItem(ctx, "Remove from group...", "Del") then UI.ask_remove_member(g, m) end
    end
    ImGui.EndPopup(ctx)
  end
  R.hover_m, R.hover_g = hover_m, g -- (the Delete key removes this row)
  -- the dropdown of a plugin name: the copies of the plugin on that track, and Open plugin window
  if R.slot_open then ImGui.OpenPopup(ctx, "##slots"); R.slot_open = nil end
  if ImGui.BeginPopup(ctx, "##slots") then
    local m, srt = R.slot_m, R.slot_m and R.rt[R.slot_m]
    if m and srt and R.slot_g == g then
      for k, e in ipairs(R.slot_list or {}) do
        if ImGui.Selectable(ctx, e.label .. "##slot" .. k, e.guid == m.guid) and e.guid ~= m.guid then
          local ok, err = Fx.replace(g, m, e.guid)
          if not ok then UI.notice(err, true) end
        end
      end
      if #(R.slot_list or {}) < 2 then ImGui.TextColored(ctx, COL.TEXT_DIM, "This track has no other copy of " .. g.plug .. ".") end
      ImGui.Separator(ctx)
      if ImGui.Selectable(ctx, "Open plugin window") then r.TrackFX_Show(srt.track, srt.idx, 3) end
    end
    ImGui.EndPopup(ctx)
  end
  if del then
    for i, m in ipairs(g.members) do if m == del then table.remove(g.members, i); break end end
    if #g.members == 0 then g.ident, g.plug = "", "" end -- (empty: the group forgets its plugin)
    Util.mark_pdirty(); Fx.resolve(false)
  end
  if match then
    local others = #g.members - 1
    UI.ask("Make the other " .. others .. " plugin(s) of \"" .. g.name .. "\" equal to " .. R.rt[match].track_label .. "?\n"
      .. ((g.all and not g.except) and "All parameters are copied." or "The linked parameters are copied.") .. " Ctrl+Z undoes it.",
      "Match", function() Link.match(g, match) end)
  end
  UI.vgap(CFG.SP_ROW + 4)
  -- 1 "+ Add" button with a menu; the items that need a plugin in the group first are grey
  local add_hit = UI.button(UI.ADD .. "##addplug", UI.add_w())
  if add_hit then ImGui.OpenPopup(ctx, "##addmenu") end
  local adx = ImGui.GetItemRectMin(ctx)
  local _, ady = ImGui.GetItemRectMax(ctx)
  ady = ady + 4 -- (the menus of "+ Add" and their lists drop down below the button, all at the same place)
  UI.tip("Add plugins to this group: the focused plugin, the selected tracks, the whole project or a folder.")
  local open_plug, open_folder
  ImGui.SetNextWindowPos(ctx, adx, ady, ImGui.Cond_Appearing())
  if ImGui.BeginPopup(ctx, "##addmenu") then
    local empty = #g.members == 0 or g.ident == ""
    if ImGui.MenuItem(ctx, "Focused plugin") then
      local tr, idx, err = Fx.focused()
      if tr then
        local ok, e2 = Fx.add(g, tr, idx)
        if not ok then UI.notice(e2, true) end
      else UI.notice(err, true) end
    end
    UI.tip("The plugin window you clicked last.")
    if ImGui.MenuItem(ctx, "Selected tracks") then
      if r.CountSelectedTracks(R.proj) == 0 then
        UI.ask("Select the tracks first (click their names in the track panel).", nil)
      elseif empty then
        R.plug_tracks, R.plug_folder = Fx.selected_tracks(), nil
        R.plug_menu = Fx.plugin_list(R.plug_tracks)
        if #R.plug_menu == 0 then UI.ask("The selected tracks have no plugins.", nil) else open_plug = true end
      else
        local added, skipped = Fx.add_selected(g)
        if #skipped > 0 then UI.ask("Added: " .. added .. "\n\nNot added:\n" .. table.concat(skipped, "\n"), nil) end
      end
    end
    UI.tip(empty and "A plugin from every selected track. You pick the plugin from a list."
      or (g.plug .. " from every selected track (the first one, if a track has 2)."))
    if ImGui.MenuItem(ctx, "Same plugin in whole project") then
      if empty then
        R.plug_tracks, R.plug_folder = nil, nil -- (the whole project)
        R.plug_menu = Fx.plugin_list(nil)
        if #R.plug_menu == 0 then UI.ask("This project has no plugins.", nil) else open_plug = true end
      else
        local added, other = Fx.add_all(g)
        UI.ask("Added: " .. added .. " " .. g.plug .. "." .. (other > 0 and ("\n" .. other .. " more are in other groups (a plugin can be in 1 group only).") or ""), nil)
      end
    end
    UI.tip(empty and "Every copy of a plugin in the project. You pick the plugin from a list." or ("Every " .. g.plug .. " in the project."))
    if ImGui.MenuItem(ctx, "Same plugin in folder...") then
      R.folder_menu = Fx.folders()
      if #R.folder_menu == 0 then UI.ask("This project has no folder tracks.", nil) else open_folder = true end
    end
    UI.tip(empty and "A plugin from every track of a folder (for example 'Drums'). You pick the folder, then the plugin."
      or (g.plug .. " from every track of a folder (for example 'Drums'). You pick the folder from a list."))
    ImGui.EndPopup(ctx)
  end
  if open_plug then ImGui.OpenPopup(ctx, "##plugmenu") end -- (opened here: the same ID as their BeginPopup)
  if open_folder then ImGui.OpenPopup(ctx, "##foldermenu") end
  ImGui.SetNextWindowPos(ctx, adx, ady, ImGui.Cond_Appearing())
  if ImGui.BeginPopup(ctx, "##foldermenu") then
    ImGui.TextColored(ctx, COL.TEXT_DIM, "Which folder?")
    for i, e in ipairs(R.folder_menu or {}) do
      local hit = ImGui.Selectable(ctx, e.name .. "##fo" .. i) and r.ValidatePtr2(R.proj, e.track, "MediaTrack*")
      if hit and (#g.members == 0 or g.ident == "") then -- (an empty group: which plugin of this folder?)
        R.plug_tracks, R.plug_folder = Fx.folder_tracks(e.track), true
        R.plug_menu = Fx.plugin_list(R.plug_tracks)
        if #R.plug_menu == 0 then UI.ask("The tracks of \"" .. e.name .. "\" have no plugins.", nil) else R.plug_open = true end
      elseif hit then
        local added, skipped = Fx.add_tracks(g, Fx.folder_tracks(e.track))
        local miss = {}
        for _, sk in ipairs(skipped) do if not sk:find(": no ", 1, true) then miss[#miss + 1] = sk end end
        UI.ask("Added: " .. added .. " " .. g.plug .. " from \"" .. e.name .. "\"."
          .. (#miss > 0 and ("\n\nNot added:\n" .. table.concat(miss, "\n")) or ""), nil)
      end
    end
    ImGui.EndPopup(ctx)
  end
  if R.plug_open then ImGui.OpenPopup(ctx, "##plugmenu"); R.plug_open = nil end -- (from the folder list)
  ImGui.SetNextWindowPos(ctx, adx, ady, ImGui.Cond_Appearing())
  if ImGui.BeginPopup(ctx, "##plugmenu") then
    ImGui.TextColored(ctx, COL.TEXT_DIM, "Which plugin?")
    for i, e in ipairs(R.plug_menu or {}) do
      if ImGui.Selectable(ctx, e.plug .. " (" .. e.n .. ")##pl" .. i) then
        g.ident, g.plug = e.ident, e.plug
        local added, skipped, other = 0, {}, 0
        if R.plug_tracks then added, skipped = Fx.add_tracks(g, R.plug_tracks)
        else added, other = Fx.add_all(g) end
        if added == 0 then g.ident, g.plug = "", "" end
        local miss = {}
        for _, sk in ipairs(skipped) do if not (R.plug_folder and sk:find(": no ", 1, true)) then miss[#miss + 1] = sk end end
        if #miss > 0 or other > 0 then
          UI.ask("Added: " .. added .. " " .. e.plug .. "." .. (#miss > 0 and ("\n\nNot added:\n" .. table.concat(miss, "\n")) or "")
            .. (other > 0 and ("\n" .. other .. " more are in other groups (a plugin can be in 1 group only).") or ""), nil)
        end
        Util.mark_pdirty(); UI.labels_dirty()
      end
    end
    ImGui.EndPopup(ctx)
  end
end

-- The toolbar (on the window background): Show plugins and the search at the left, the gear and "?" at the right.
function UI.draw_toolbar()
  UI.vgap(CFG.SP_EDGE)
  local x0, y0 = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local IW, H = CFG.TB_ICON_W, ImGui.GetFrameHeight(ctx)
  local g = P.groups[P.cur]
  local can = g ~= nil and #g.members > 0
  local is_open = can and Link.any_open(g)
  local sw = UI.btn_w("Show plugins") -- (the same width for "Hide plugins": the search does not jump)
  ImGui.BeginDisabled(ctx, not can)
  if UI.button(is_open and "Hide plugins##showhide" or "Show plugins##showhide", sw, H, is_open and "primary" or nil) then
    Link.show(g, not is_open)
  end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, not can and "Select a group with plugins first."
      or (is_open and "Close the plugin windows of the selected group."
      or "Open the plugin windows of the selected group and bring them to the front."))
  end
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.SetNextItemWidth(ctx, math.max(60, aw - sw - 2 * CFG.CTRL_GAP - 2 * IW))
  local ch, txt = ImGui.InputTextWithHint(ctx, "##search", "Search groups, plugins, tracks", R.search)
  if ch then R.search, R.search_low, R.vis = txt, txt:lower(), nil end
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
  -- the gear: the Settings menu drops down below it (right edge in line with the gear; it never covers the gear).
  -- A click on the gear while the menu is open closes it (the click outside closes it at mouse down: not again open).
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

-- The Settings menu (the gear button): Look, Automatic open and close, Window, Backup (the order of the other scripts).
function UI.draw_settings()
  R.settings_open = ImGui.BeginPopup(ctx, "##settings")
  if not R.settings_open then return end
  local function head(t, first)
    if not first then UI.vgap(8) end
    ImGui.PushFont(ctx, head_font)
    ImGui.TextColored(ctx, COL.HEADING, t)
    ImGui.PopFont(ctx)
  end
  head("Look", true)
  local ch
  ch, S.light = UI.toggle_line("Light theme", S.light,
    "On: light panels and fields, dark text. Off: Dark (the default).")
  if ch then apply_theme(S.light); R.sdirty = true end
  head("Automatic open and close")
  local on = Autostart.installed()
  ch, on = UI.toggle_line("Open automatically", on,
    "FX Link opens by itself when you open a project that has FX Link groups. It adds 3 marked lines to REAPER's "
    .. "__startup.lua (with a backup). Needs one REAPER restart after you change it.")
  if ch then
    local msg = on and Autostart.install() or (not on and Autostart.uninstall()) or nil
    if msg then ImGui.CloseCurrentPopup(ctx); UI.ask(msg, nil) end
  end
  ch, S.close_proj = UI.toggle_line("Close with project", S.close_proj,
    "FX Link closes when its project tab closes, or when File > Close / New / Open project replaces it. "
    .. "Switching tabs and 'Save as' keep it open.")
  if ch then R.sdirty = true end
  head("Window")
  local docked = R.docked == true
  if UI.toggle_line("Dock in REAPER's docker", docked, "On: FX Link is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if UI.button("Reset window position", CFG.SETTINGS_BTN_W) then R.reset_win = true; ImGui.CloseCurrentPopup(ctx) end
  UI.tip("Moves the window back to its default size and place, and undocks it.")
  head("Backup")
  local bw = CFG.SETTINGS_BTN_W
  local dir = Util.backup_dir()
  UI.row_text("Folder: " .. UI.trunc(dir, 260), COL.TEXT_DIM)
  UI.tip(dir)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  if UI.button("Show", UI.btn_w("Show")) then Util.show_backup_dir() end
  UI.tip("Opens the backup folder in Explorer.")
  ImGui.SameLine(ctx, 0, 4)
  if UI.button("Change...", UI.btn_w("Change...")) then
    ImGui.CloseCurrentPopup(ctx)
    local okf, path = r.GetUserFileNameForRead(dir .. "\\", "Pick any file in the new backup folder", "")
    local nd = okf and path:match("^(.*)[/\\][^/\\]*$")
    if nd and nd ~= "" then
      S.backup_dir = (nd:gsub("/", "\\") == CFG.DATA_DIR:gsub("/", "\\")) and "" or nd
      R.sdirty = true
    end
  end
  UI.tip("Pick another backup folder: REAPER's file window opens; pick any file in the folder that you want.\n"
    .. "(Reset all settings sets it back to " .. CFG.DATA_DIR:gsub("/", "\\") .. ".)")
  if UI.button("Back up...", bw) then
    local path, err = Util.backup_settings()
    ImGui.CloseCurrentPopup(ctx)
    UI.ask(path and ("Backup saved:\n" .. path) or err, nil)
  end
  UI.tip("Saves a copy of the settings of this computer in the backup folder.")
  if UI.button("Restore...", bw) then
    ImGui.CloseCurrentPopup(ctx)
    local okf, path = r.GetUserFileNameForRead(Util.newest_backup() or (Util.backup_dir() .. "\\"), "Restore FX Link settings", ".txt")
    if okf and path ~= "" then
      UI.ask("Replace the FX Link settings of this computer with this backup?\n" .. path, "Replace", function()
        local okr, err = Util.restore_settings(path)
        if not okr then UI.notice(err, true) end
      end)
    end
  end
  UI.tip("Loads a backup. It asks before it replaces anything.")
  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
  local reset = UI.button("Reset all settings...", bw)
  ImGui.PopStyleColor(ctx)
  UI.tip("Sets the settings of this computer back to the defaults. Your groups (in the projects) do not change.")
  if reset then
    ImGui.CloseCurrentPopup(ctx)
    UI.ask("Set all FX Link settings of this computer back to the defaults? Your groups (in the projects) do not "
      .. "change. (Open automatically stays as it is.)", "Yes, reset", Util.reset_settings)
  end
  UI.vgap(8)
  ImGui.TextColored(ctx, COL.TEXT_DIM, "FX Link " .. CFG.VERSION .. "  -  MIT license")
  ImGui.EndPopup(ctx)
end

-- The Help window (a popup in the window), in topics as in Segue.
function UI.draw_help()
  if R.help_open then ImGui.OpenPopup(ctx, "FX Link Help##help"); R.help_open = false end
  local vw, vh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowSize(ctx, math.min(520, math.max(260, vw - 40)), math.min(560, math.max(240, vh - 40)),
    ImGui.Cond_Appearing())
  if ImGui.BeginPopupModal(ctx, "FX Link Help##help", true) then
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
      ImGui.TextColored(ctx, COL.TEXT_DIM, "FX Link " .. CFG.VERSION .. "  -  MIT license")
      ImGui.PopTextWrapPos(ctx)
      ImGui.EndChild(ctx)
    end
    UI.vgap(8)
    if UI.button("Close", 90) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

-- The right-click menu on an empty part of the panel (as in Segue).
function UI.draw_panel_menu()
  if R.pmenu then ImGui.OpenPopup(ctx, "##panelmenu"); R.pmenu = false end
  if not ImGui.BeginPopup(ctx, "##panelmenu") then return end
  if ImGui.MenuItem(ctx, "Settings...") then R.settings_req = true end
  if ImGui.MenuItem(ctx, "Help") then R.help_open = true end
  ImGui.Separator(ctx)
  local docked = R.docked == true
  if ImGui.MenuItem(ctx, "Dock FX Link in Docker", nil, docked) then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  if ImGui.MenuItem(ctx, "Close FX Link") then R.close = true end
  ImGui.EndPopup(ctx)
end

-- The window: the toolbar, then one panel (a rounded area that scrolls) with the groups and the selected group.
function UI.draw_main()
  UI.draw_toolbar()
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  local nh = UI.notice_h(aw - 16)
  ah = ah - CFG.SP_EDGE - nh
  local px, py = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + aw, py + ah, COL.PANEL_BG, 8)
  if ImGui.BeginChild(ctx, "##panel", aw, ah) then
    ImGui.SetCursorPosY(ctx, CFG.SP_PANEL)
    ImGui.Indent(ctx, 10)
    local saw = ImGui.GetContentRegionAvail(ctx)
    ImGui.PushItemWidth(ctx, saw - 10)
    UI.draw_groups()
    local g = P.groups[P.cur]
    if g then
      UI.draw_settings_section(g)
      if not g.all or g.except then UI.draw_params(g) end
      UI.draw_plugins(g)
    end
    ImGui.PopItemWidth(ctx)
    ImGui.Unindent(ctx, 10)
    ImGui.Dummy(ctx, 0, CFG.SP_PANEL)
    if ImGui.IsMouseClicked(ctx, 1) and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_ChildWindows())
      and not ImGui.IsAnyItemHovered(ctx) and not ImGui.IsPopupOpen(ctx, "##rowmenu") then R.pmenu = true end
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
  local now = Util.now()
  if now - R.hb_t >= CFG.HEARTBEAT then -- the autostart watcher sees that FX Link runs
    R.hb_t = now
    r.SetExtState(CFG.EXT, "heartbeat", tostring(now), false)
  end
  Project.update()
  if R.close then return end -- (Close with project: stop now, before anything reads the closed project)
  Link.read_cmds()
  Link.tick()
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
    -- the window takes the keys while it has the focus: pass Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y on to REAPER
    if ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) and not ImGui.IsAnyItemActive(ctx) then
      local C, SH = ImGui.Mod_Ctrl(), ImGui.Mod_Shift()
      if ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Z()) then r.Main_OnCommand(40029, 0) -- Edit: Undo
      elseif ImGui.IsKeyChordPressed(ctx, C | SH | ImGui.Key_Z()) or ImGui.IsKeyChordPressed(ctx, C | ImGui.Key_Y()) then
        r.Main_OnCommand(40030, 0) -- Edit: Redo
      elseif ImGui.IsKeyPressed(ctx, ImGui.Key_F2(), false) and P and P.groups[P.cur] then
        local g = P.groups[P.cur]
        Util.ask_name("FX Link - Rename group", g.name, function(n) g.name = n; Util.mark_pdirty(); UI.labels_dirty() end)
      elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Delete(), false) and R.hover_m and R.rt[R.hover_m] then
        UI.ask_remove_member(R.hover_g, R.hover_m)
      end
    end
    UI.draw_main()
    UI.draw_ask()
    UI.draw_help()
    if not R.docked then UI.edges() else R.rs = nil end -- resize edges: floating only
    ImGui.End(ctx)
  end
  UI.pop_style()
  ImGui.PopFont(ctx)
  if R.pdirty and not ImGui.IsAnyItemActive(ctx) then Project.save() end
  if R.sdirty and not ImGui.IsMouseDown(ctx, 0) then Util.save_settings() end
  if R.close then open = false end
  if open then r.defer(loop) end
end

local function on_exit()
  if R.pdirty then Project.save() end
  if R.sdirty then Util.save_settings() end
  r.DeleteExtState(CFG.EXT, "heartbeat", false)
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end

-- A second start closes the running FX Link (REAPER 7: no question).
if r.set_action_options then r.set_action_options(1) end
do
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end
end
Util.load_settings()
apply_theme(S.light)
do -- the autostart watcher finds FX Link by its command ID (kept); keep the watcher up to date
  local cs = Autostart.command_string()
  if cs then r.SetExtState(CFG.EXT, "cmd", cs, true) end
  if Autostart.installed(true) then Autostart.write_script() end
end
r.atexit(on_exit)
r.defer(loop)
