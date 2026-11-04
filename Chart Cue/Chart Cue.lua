-- @description Chart Cue: Open PDF Viewer
-- @version 1.3
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   Chart Cue - PDF Viewer for REAPER. Shows PDF charts and scrolls them with markers,
--   cue lists, MIDI CC, mouse wheel or dragging; 1 or 2 PDFs per song. Windows only.
--   Requires: the free ReaImGui extension. Install it first: Extensions > ReaPack >
--   Browse packages > "ReaImGui" > Install, then restart REAPER.
-- @provides
--   [main] Chart Cue - Next page.lua
--   [main] Chart Cue - Previous page.lua
--   [main] Chart Cue - Toggle performance mode.lua
-- @changelog
--   2 PDFs per song (for example lyrics and a bass part), shown together, each with its own cues.
--   2 pages side by side or continuous pages, with a slide-in page turn; folder sync and unused PDFs in the Library.
--   Cleaner Settings and buttons, Redo for cues, right-click menus everywhere, and many fixes.

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

--[[
  Chart Cue: shows PDF charts in a ReaImGui window and scrolls them during playback
  (PDFSCROLL / PDFPAGE markers, cue lists or MIDI CC). One PDF per region.
  Requirements: REAPER 7 or newer on Windows 10 / 11, and ReaImGui 0.9.3 or newer (ReaPack).
  Optional: Poppler (pdftoppm.exe, pdfinfo.exe) as an alternative PDF engine, and the
  "Chart Cue - Next page / Previous page / Toggle performance mode" action scripts.
  Install: with ReaPack (https://github.com/thunderfork/reaper-scripts/raw/main/index.xml), or
  Actions > Show action list > New action... > Load ReaScript... > pick this file.
  Settings are saved in the .rpp (project) and in settings.ini (global).
  See the in-app Help ("?" at the end of the tab strip) for all features.
]]

local r = reaper

---------------------------------------------------------------------------
-- CONFIG (constants; most are also exposed in the UI)
---------------------------------------------------------------------------
local CFG = {}   -- all constants; grouped below (the paths and the rest follow after SEP)
-- Identity
CFG.EXT = "ChartCue"
-- PDF rendering
CFG.BATCH_SIZE = 4              -- pages rendered per pdftoppm call
CFG.MAX_IMAGE_DIM = 4096        -- longest side (px) allowed for a page texture; bigger pages are scaled down
CFG.DEFAULT_DPI = 200
CFG.JOB_TIMEOUT_SEC = 240       -- give up on a render batch after this long
CFG.MAX_CACHED_TEXTURES = 3
CFG.EXEC_NOWAIT = -2            -- ExecProcess timeout value meaning "don't wait"
CFG.PAGE_BG = 0x2B2B2BFF
-- Scrolling, zoom and MIDI
CFG.MIDI_OVERRIDE_SEC = 1.5     -- MIDI/manual scroll overrides playback autoscroll this long
CFG.ABS_SMOOTHING = 0.35        -- 0..1, higher = snappier absolute-mode following
CFG.ZOOM_STEP = 1.15
CFG.MIN_ZOOM = 0.2
CFG.MAX_ZOOM = 8.0
CFG.WHEEL_STEP = 90             -- screen px per mouse-wheel notch
-- Timing
CFG.HEARTBEAT_TIMEOUT = 1.0     -- seconds; single-instance detection
CFG.MARKER_RESCAN_DELAY = 0.25  -- seconds after a project change before markers are rescanned
CFG.DOCK_SETTLE_FRAMES = 30     -- frames to wait before tracking dock changes after startup
CFG.IMPORT_FRAME_BUDGET = 0.004 -- seconds of folder scanning per frame
CFG.MSG_SECONDS = 8             -- how long a message stays in the status bar / its section
CFG.PICKER_TIMEOUT_SEC = 900    -- give up waiting for the folder dialog after this long
CFG.JOB_POLL_SEC = 0.1          -- background jobs (render, page count, folder dialog) are checked at most this often
-- Window and panel layout
CFG.SCROLLBAR_W = 14
CFG.MIN_VIEW_H = 160            -- the PDF view never gets smaller than this
CFG.PANEL_DEFAULT_FRAC = 0.40   -- default panel height as a fraction of the free height
CFG.PANEL_LARGE_FRAC = 0.60     -- panel height after a double-click on the grip (from the default height)
CFG.PANEL_SMALL_FRAC = 0.30     -- a tab click with a smaller panel returns it to the default height
CFG.PANEL_FIT_FRAC = 0.80       -- an opened Settings section / Help topic grows the panel at most to this
CFG.PANEL_MIN_H = 70
CFG.SPLIT_H = 12                -- height of the panel resize grip (its hit area; touch friendly)
CFG.TAB_H = 32                  -- tab strip button height
CFG.TAB_GAP = 4                 -- gap between tabs
CFG.TAB_GROUP_GAP = 12          -- gap between the main tabs and the Settings tab
CFG.LABEL_W = 190               -- label column width in panels
CFG.SORT_W = 170                -- width of the dropdown next to a list search field (Library sort, Regions show)
CFG.DEFAULT_WIN = { 100, 100, 760, 900 }
CFG.WIN_EDGE = 6                -- floating window: width of Chart Cue's resize edges (inside the window)
CFG.WIN_GRIP = 22               -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 300, 200 -- smallest window size when resizing

local SEP = package.config:sub(1, 1)
CFG.TITLE = "Chart Cue"   -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.3"      -- keep equal to @version in the header
CFG.AUTHOR = "Nick Gkogkomitros"
CFG.FEEDBACK_URL = "https://github.com/thunderfork/reaper-scripts/issues" -- Help > About > "Send feedback"
CFG.RES = r.GetResourcePath()
CFG.BASE_DIR = CFG.RES .. SEP .. "Data" .. SEP .. "Chart Cue" -- REAPER's data folder: settings, cache, helper files
CFG.CACHE_ROOT = CFG.BASE_DIR .. SEP .. "cache"
CFG.TMP_DIR = CFG.BASE_DIR .. SEP .. "tmp"
CFG.SETTINGS_FILE = CFG.BASE_DIR .. SEP .. "settings.ini"
-- Files and folders
CFG.PS_ENGINE_FILE = CFG.TMP_DIR .. SEP .. "chartcue_pdf.ps1"
CFG.STARTUP_FILE = CFG.RES .. SEP .. "Scripts" .. SEP .. "__startup.lua"
CFG.AUTOSTART_FILE = CFG.BASE_DIR .. SEP .. "autostart.lua"
CFG.GUIDE_FILE = CFG.BASE_DIR .. SEP .. "Chart Cue Guide.html"
CFG.PDF_SUBDIR = "PDFs"
-- Project data (stored in the .rpp)
CFG.PEXT = "ChartCue"   -- project ExtState section (stored in the .rpp)
CFG.PEXT_KEY = "cfg"
-- PDF engine, cache and copying
CFG.KEY_SAMPLE = 65536
CFG.KEY_MEMO_SEC = 2
CFG.INFO_TIMEOUT_SEC = 60
CFG.COPY_CHUNK = 262144          -- bytes per read/write
CFG.COPY_FRAME_BUDGET = 0.004    -- seconds of copying per frame
-- Zoom
CFG.SCREEN_DPI = 96
-- Cue list
CFG.CUE_SAME_POS = 0.02   -- a new cue this close to an existing one replaces it (beats or seconds)
CFG.CUE_UNDO_MAX = 50      -- undo steps kept for the cue list
CFG.MAX_ERROR_FRAMES = 5    -- this many failed frames in a row: Chart Cue stops (see UI.loop)
-- Autostart block in __startup.lua
CFG.AS_BEGIN = "-- >>> Chart Cue autostart (added by Chart Cue; remove with the Chart Cue option) >>>"
CFG.AS_END = "-- <<< Chart Cue autostart <<<"
CFG.AS_BLOCK = CFG.AS_BEGIN .. "\n"
  .. 'pcall(dofile, reaper.GetResourcePath() .. "/Data/Chart Cue/autostart.lua")\n'
  .. CFG.AS_END .. "\n"
-- Fonts (Segoe UI)
CFG.FONT_SIZE = 14
CFG.FONT_SIZE_BOLD = 15
CFG.TEXT_LIFT = 1            -- px Segoe UI text is raised above true centre, the same in every control (0 = exact centre)
-- Spacing (pixels): { comfortable, compact }. Compact is the default; "Comfortable layout" in
-- Settings > Display > Window uses the first value. Only empty space changes; controls keep their size.
CFG.SP = {
  ROW = { 7, 4 },             -- between rows (ImGui item spacing)
  EDGE = { 8, 4 },            -- window edge, top and bottom (= gap below the toolbar)
  TITLE_BEFORE = { 12, 6 },   -- before a section title
  TITLE_AFTER = { 6, 3 },     -- below a section title's underline
  SECTION = { 4, 0 },         -- extra space between sections
  PANEL = { 4, 2 },           -- inside the settings panel, top and bottom
  LIST = { 4, 2 },            -- above a list / between list blocks
  SEARCH = { 12, 8 },         -- below a list's search row (Library, Regions), before the first row
  CLOSED_TABS = { 6, 3 },     -- below the tab strip when the panel is closed
}
-- Layout sizes (pixels)
CFG.ROW_H = 26   -- height of every control (fields, dropdowns, buttons, list rows); see UI.h
CFG.TB_BTN_W = 34          -- width of the < > - + toolbar buttons
CFG.TB_GAP = 8             -- gap between toolbar items
CFG.TB_GROUP_GAP = 25      -- gap between toolbar groups (a divider line in the middle)
CFG.EXPLORER_BTN_W = 120    -- "Show in Explorer"
CFG.MIN_PATH_W = 80         -- Library: below this width the path is hidden
CFG.REGION_COMBO_W = 280    -- Regions: PDF menu
CFG.DOT_W = 16              -- Regions: status symbol column
CFG.HELP_ICON = 20          -- round "?" icon
CFG.SMALL_BTN_W = 80        -- Browse..., Cancel
CFG.MEDIUM_BTN_W = 100      -- Relocate..., Yes, remove
CFG.FLASH_SEC = 0.7         -- page-turn flash duration
CFG.FLASH_W = 6             -- page-turn flash border width
CFG.CONT_TURN_SEC = 0.35    -- continuous pages: duration of the smooth page turn
CFG.FORM_MAX_W = 360        -- maximum width of the control column in the settings panels
CFG.FORM_MIN_WIDE = 220     -- below label column + this width, labels go above their control
-- Settings reset
CFG.KEEP_ON_RESET = { pdf_path = true, page = true, scroll_y = true, scroll_x = true, tab = true, panel_open = true }

-- Colours (0xRRGGBBAA), by purpose
local COL = {
  -- state
  RED = 0xF26D6DFF,            -- errors, missing files, removals
  YELLOW = 0xF2C75CFF,         -- warnings, needs attention
  GREEN = 0x6FCF8AFF,          -- OK, has a PDF
  GREY = 0x9AA1B0FF,           -- secondary text, ignored
  -- accent
  ACCENT = 0x3B82F6FF,         -- primary buttons, selected tab bar, toggles, underline, "?" icons
  ACCENT_HOVER = 0x5B9BFFFF,
  ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633,      -- active row background (accent, transparent)
  HEADING = 0x8DB8FFFF,        -- section titles
  -- surfaces (flat dark theme)
  WIN_BG = 0x1A1C21FF,         -- window background
  TAB_BG = 0x15171BFF,         -- tab strip background
  PANEL_BG = 0x23262DFF,       -- settings panel (and the selected tab, so they look connected)
  TAB_HOVER = 0x343944FF,
  FIELD = 0x2B2F38FF, FIELD_HOVER = 0x333844FF, FIELD_ACTIVE = 0x2C3A55FF,   -- inputs, dropdowns
  BTN = 0x30343EFF, BTN_HOVER = 0x3B404CFF, BTN_ACTIVE = 0x464C5AFF,          -- secondary buttons
  LINE = 0x31353FFF,           -- borders, separators
  TOGGLE_OFF = 0x4A5060FF,
  SCROLL_TRACK = 0x1A1A1AFF, SCROLL_THUMB = 0x808080FF, SCROLL_THUMB_ACTIVE = 0xC0C0C0FF,
  -- text
  TEXT = 0xDDDDDDFF, TEXT_BRIGHT = 0xEEEEEEFF, WHITE = 0xFFFFFFFF,
  TEXT_MAIN = 0xE6E8EEFF, TEXT_DIM = 0x8C93A3FF,
  TRANSPARENT = 0x00000000,
  ROW_HOVER = 0xFFFFFF12,      -- clickable list row under the mouse
  DANGER_HOVER = 0xF26D6D2E, DANGER_ACTIVE = 0xF26D6D50,  -- red outline buttons (remove all, reset, clear)
}

-- Module tables (declared up front so every function can reference them)
local Util = {}    -- general helper functions
local PDF = {}     -- Poppler, PDF info, rendering, cache
local Project = {} -- project, markers, regions, project config
local Dock = {}    -- docking state and dock-related helpers
local UI = {}       -- ImGui drawing, tabs, toolbar, status, view, main frame
local Nav = {}       -- pages, scrolling, zoom, autoscroll motion
local Midi = {}      -- MIDI input (direct + action-bound)
local Autostart = {} -- open Chart Cue with projects (__startup.lua watcher)
local Msg = {}       -- user messages, errors and the diagnostic log
local Cues = {}      -- cue list: page / scroll changes per region, stored in the project (no markers)
local Pane = {}      -- parts of the page area (pane 1 = the global state; others are swapped in)

---------------------------------------------------------------------------
-- SINGLE-INSTANCE / MIDI FORWARDING
-- A MIDI-triggered launch while Chart Cue runs just forwards its value and exits;
-- a normal second launch closes the running instance.
---------------------------------------------------------------------------
-- get_action_context() returns: is_new, file name, section ID, command ID, mode, resolution, value.
-- resolution is -1 when the action was not started by MIDI.
local is_new, script_file, sect_id, cmd_id, _, act_res, act_val = r.get_action_context()
script_file = script_file or ""
local launched_by_midi = (is_new == true) and act_val ~= nil and act_res ~= nil and act_res > 0
if launched_by_midi and act_res > 127 then act_val = act_val * 127 / act_res end -- 14-bit -> 0..127

local function main_alive()
  local hb = tonumber(r.GetExtState(CFG.EXT, "heartbeat"))
  return hb ~= nil and math.abs(r.time_precise() - hb) < CFG.HEARTBEAT_TIMEOUT
end

if main_alive() then
  if launched_by_midi then
    local q = r.GetExtState(CFG.EXT, "midi_q")
    if #q > 4000 then q = "" end
    r.SetExtState(CFG.EXT, "midi_q", q .. tostring(math.floor(act_val)) .. ",", false)
  else
    r.SetExtState(CFG.EXT, "quit", "1", false)
  end
  return
end

-- ReaImGui API pinned to 0.9.3 with the official compatibility shim, so newer ReaImGui versions
-- behave the same and no version checks are needed in the code.
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
-- ReaImGui missing or too old: with ReaPack, offer to open its package browser on "ReaImGui";
-- without ReaPack, say where to get it. (An extension loads only at REAPER start: a restart is needed.)
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("Chart Cue needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end -- 6 = Yes
  else
    r.ShowMessageBox("Chart Cue needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run Chart Cue again.", CFG.TITLE, 0)
  end
end
if not r.ImGui_CreateContext or not r.file_exists(IMGUI_SHIM) then
  imgui_missing()
  return
end
-- the shim raises an error when the installed ReaImGui is older than 0.9.3
if not pcall(function() dofile(IMGUI_SHIM)("0.9.3") end) then
  imgui_missing()
  return
end

---------------------------------------------------------------------------
-- GLOBAL SETTINGS (persisted to settings.ini; NOT project specific)
---------------------------------------------------------------------------
local S = {
  pdf_path = "", pdftoppm_path = "", dpi = CFG.DEFAULT_DPI,
  engine = "windows",          -- PDF engine: "windows" (built in, no install) or "poppler"
  page = 1, zoom = 1.0, fit_mode = "width", scroll_y = 0, scroll_x = 0,
  cc_abs = 1, cc_rel = 2, mode = "absolute", rel_encoding = 1, rel_invert = false,
  sensitivity = 24.0, direct_midi = false,
  midi_page_turn = false, cc_page_next = 3, cc_page_prev = 4, show_midi_debug = false,
  midi_add_cue = false, cc_add_cue = 5, cc_add_scroll = 6,   -- "Add cues with MIDI"
  scroll_mode = "off",         -- "off" | "marker" | "cues"; default for projects without P.scroll_mode
  keep_last_page = true,       -- during playback, keep the last page when a region has no PDF
  include_subfolders = false,
  hide_controls_playing = true,
  page_layout = "single",      -- pages on screen: "single", "side" (2, side by side) or "stack" (continuous scrolling)
  page_turn = "rolling",       -- side by side: "rolling" (1-2, 2-3: by 1 page) or "book" (1-2, 3-4: by 2 pages)
  cont_turn = "smooth",        -- page turn motion (every layout): the next page slides in ("smooth") or "jump"s
  split_layout = "stack",      -- 2 PDFs on screen (part 1 + part 2): "stack" (top and bottom) or "side" (side by side)
  split_frac = 0.5,            -- 2 PDFs: share of part 1 (the divider position, 0.2 .. 0.8)
  comfortable = false,         -- "Comfortable layout": more empty space (compact is the default)
  dim_page = false, dim_level = 0.65,   -- dim mode: page brightness 0.25..1 (no re-render)
  turn_flash = true,           -- accent border for a moment when the page turns during playback
  close_with_project = true,   -- close Chart Cue when its project closes or is replaced in the same tab
  import_copy = true,          -- copy imported PDFs into <project folder>\PDFs (else link the original)
  tab = 1, panel_open = true,
  tab_ver = 1,                 -- 2 = tab numbers include the Cues tab; 3 = one Settings tab (before 1.0)
  settings_open = "1000",      -- Settings tab sections open (1) or closed (0): Autoscroll, MIDI, Display, General
  folded = ",",                -- closed foldable headings (first section of Library, Regions, Cues): ",id,id,"
  panel_h = 0,                 -- 0 = automatic (~40% of free height); otherwise the user's dragged height
  win_x = CFG.DEFAULT_WIN[1], win_y = CFG.DEFAULT_WIN[2], win_w = CFG.DEFAULT_WIN[3], win_h = CFG.DEFAULT_WIN[4],
  dock_id = 0,
  log_diag = false,            -- "Write diagnostic log" (Settings > General > Troubleshooting)
}
CFG.S_DEFAULTS = {}   -- copy of the defaults (before settings.ini is read), for "Reset all settings"
for k, v in pairs(S) do CFG.S_DEFAULTS[k] = v end

function Util.ensure_dir(p) r.RecursiveCreateDirectory(p, 0) end

function Util.load_settings()
  local f = io.open(CFG.SETTINGS_FILE, "r")
  if not f then return end
  for line in f:lines() do
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k and S[k] ~= nil then
      local t = type(S[k])
      if t == "number" then
        local n = tonumber(v); if n then S[k] = n end
      elseif t == "boolean" then
        S[k] = (v == "1" or v == "true")
      else
        S[k] = v
      end
    end
  end
  f:close()
  Util.validate_settings()
end

-- After settings.ini is read: numbers back into their range, unknown values back to the default
-- (protects against a damaged or hand-edited file). Only values that are out of range change.
function Util.validate_settings()
  local D = CFG.S_DEFAULTS
  local function int(k, lo, hi) S[k] = Util.clamp(math.floor(S[k] + 0.5), lo, hi) end
  local function num(k, lo, hi) if S[k] ~= S[k] then S[k] = D[k] end; S[k] = Util.clamp(S[k], lo, hi) end -- NaN -> default
  local function one_of(k, ...)
    for _, v in ipairs({ ... }) do if S[k] == v then return end end
    S[k] = D[k]
  end
  int("dpi", 50, 600); int("page", 1, 100000); int("tab", 1, 99); int("tab_ver", 1, 99)
  for _, k in ipairs({ "cc_abs", "cc_rel", "cc_page_next", "cc_page_prev", "cc_add_cue", "cc_add_scroll" }) do int(k, 0, 127) end
  int("rel_encoding", 1, 4)
  num("sensitivity", 1, 200); num("dim_level", 0.25, 1); num("zoom", CFG.MIN_ZOOM, CFG.MAX_ZOOM)
  num("scroll_y", 0, math.huge); num("scroll_x", 0, math.huge); num("panel_h", 0, 10000)
  num("win_w", 200, 20000); num("win_h", 150, 20000)
  one_of("engine", "windows", "poppler")
  one_of("mode", "absolute", "relative")
  one_of("scroll_mode", "off", "marker", "cues", "fixed") -- "fixed" (older settings) means off
  one_of("fit_mode", "width", "height", "page", "100", "manual")
  one_of("page_layout", "single", "stack", "side")
  one_of("page_turn", "rolling", "book")
  one_of("cont_turn", "smooth", "jump")
  one_of("split_layout", "stack", "side")
  num("split_frac", 0.2, 0.8)
  if not S.settings_open:match("^[01]+$") then S.settings_open = D.settings_open end
  if S.folded:sub(1, 1) ~= "," then S.folded = "," .. S.folded end
end

function Util.save_settings()
  Util.ensure_dir(CFG.BASE_DIR)
  local f = io.open(CFG.SETTINGS_FILE, "w")
  if not f then return end
  local keys = {}
  for k in pairs(S) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local v = S[k]
    if type(v) == "boolean" then v = v and "1" or "0" end
    f:write(k, "=", (tostring(v):gsub("[\r\n]", " ")), "\n")
  end
  f:close()
end

---------------------------------------------------------------------------
-- RUNTIME STATE
---------------------------------------------------------------------------
local R = {
  ctx = nil, quit = false, dirty = false, last_save = 0, frames = 0,
  error = nil, warn = nil,
  exe = nil, pdfinfo_ok = true,
  total = 0, cache_dir = nil, prefix = nil, scale_to = nil, force_scale = false,
  bstate = {}, job = nil, batches_done = 0, page_paths = {}, images = {}, image_order = {},
  max_x = 0, max_y = 0, view_w = 0, view_h = 0, last_ratio = nil,
  last_cc = nil, abs_target = nil, override_until = 0,
  autoscroll_active = false, last_midi_seq = 0, page_cc_state = {},
  pdf_name = "", dpi_edit = nil,
  dbg = {},
  -- project / markers / regions
  proj = nil, projfn = "", psaveable = false, pdirty = false, plast = 0,
  state_cc = nil, scan_due = nil,
  regions = {}, scroll_pts = {}, page_pts = {}, marker_warns = {},
  cur_region_key = nil, active_region = nil,
  mpage_last = nil, was_playing = false,
  libpages = {}, libexists = {}, libexists_t = 0, lib_scan_t = 0,
  cache_size = nil,
  dock_applied = false, reset_layout = false,
  -- region empty state (current region has no PDF)
  empty_region = nil,          -- the region (table) whose empty state is shown, or nil
  stash_pdf = nil,             -- PDF that was on screen before it was cleared (restored when region switching is turned off)
  cleared_key = nil,           -- key of the region we cleared the display for
  empty_sel = 0, empty_sel_key = nil, choose_existing = false,
  -- UI state
  lib_filter = "", lib_sort = 0, region_filter = 0, region_search = "",
  picker = nil, import = nil, msg = nil,
  ask = nil,                   -- the open inline question (UI.ask / UI.draw_ask)
  dpi_manual = false,          -- "Change" was clicked: the DPI number field is shown
  ext_count = 0, ext_count_t = nil, -- Library: PDFs outside the project folder (counted every 0.5 s)
  lib_name_w = nil, region_name_w = nil, -- widest name in the PDF / region list (column widths)
  region_show = nil,           -- the Regions "Show" menu text (rebuilt when a count changes)
  page_status = nil, page_status_t = 0, -- status line 1 "Next: page ..." text, false = none (rebuilt every 0.1 s)
  no_guid_logged = 0,          -- regions without a GUID in the last diagnostic message
  tab_font = nil, tab_font_big = nil, big_font = nil,
  -- window / docking state
  in_window = false,           -- between Begin() and End() (for error recovery)
  was_visible = nil,           -- last visibility (diagnostic log)
  last_docked = nil, dock_settle = 0,
  hb_t = 0,                    -- last heartbeat write (single-instance detection)
  -- per-frame caches (rebuilt when R.lib_ver / the project / the frame changes)
  lib_ver = 0,                 -- changes on every library / assignment change
  items_cache = nil, order_cache = nil, counts_cache = nil, cue_cache = nil,
  -- PDF engine
  info_job = nil, info_seq = 0, -- background page-count job for opening a PDF
  lib_job = nil,               -- background page-count job for the Library list (Poppler)
  size_job = nil,              -- cache size calculation, spread over frames
  cache_clear_t = nil,         -- time of the last cache clear (its cmd.exe deletes in the background)
  clear_seq = 0,               -- number for the cache clear .bat file names
  page_w_pt = nil,             -- page 1 width in points (for "100%")
  -- copying PDFs into the project
  copyq = {}, copy = nil,      -- pending copy jobs / the running one
  -- project data
  plast_txt = nil,             -- last config text written to the project (skip unchanged writes)
  proj_fp = "",                -- content fingerprint of R.proj (tells "Save as" from "Open project")
  as_installed = nil,          -- cached: autostart block present in __startup.lua
  -- cue list editor
  cue_edit_key = "_all",       -- "_all" (default), nil = current song (play cursor, or edit cursor when stopped), "_project" or a region key
  cue_text = {},               -- text being typed in cue fields (kept while the value is invalid)
  cue_err = {},                -- cue field -> reason the typed value is not accepted (red border)
  help_open = nil,             -- help topic to open once
  -- live-use features
  perf = false, perf_t = 0,    -- performance mode (F): only the page is shown
  perf_btn_over = false,       -- mouse over the performance-mode exit button (no page drag)
  marks_cache = nil,           -- scrollbar marks of the page on screen
  lock = false,                -- lock mode (L): no mouse / keys on the page during playback
  rec = false,                 -- "Record cues" armed (R): C / S keys and MIDI cue CCs add cues; not saved
  kept_key = nil,              -- region key whose empty state is replaced by the last page (playback)
  perf_tap_t = -100,           -- performance mode: time of the last click on the page (shows the exit button)
  flash_t = 0,                 -- time of the last page turn during playback (page-turn flash)
  goto_edit = false, goto_text = "", goto_focus = false, -- "go to page" field in the toolbar
  add2 = {},                   -- Regions: region key -> true: the empty "PDF 2" row is shown ([+] clicked)
  -- modern UI
  ui_font = nil,               -- UI font (see UI.init_fonts)
  theme = nil,                 -- { c = colours pushed, v = style vars pushed } (the font is always pushed)
  anim = {},                   -- id -> 0..1 (hover fades, toggle knobs)
}

-- Project-specific configuration (saved inside the project .rpp, never to settings.ini)
function Project.default_project()
  return {
    pdfs = {},            -- library: ordered list of PDF paths (insertion order = "recently added")
    rel = {},             -- pdf path -> path relative to the project folder ("PDFs/Song A.pdf")
    assign = {},          -- region key -> pdf path (manual assignment)
    ignore = {},          -- region key -> true (ignored permanently)
    names = {},           -- region key -> last known region name (for display)
    auto_switch = true,
    continue_after_end = false, -- not used any more (markers stop at the region end); still read and written, so the saved text stays the same
    active_pdf = "",
    cues = {},            -- region key (or "_project") -> list of { pos, page, scroll }
    cue_unit = "beats",   -- "beats" (quarter notes from the region start) or "seconds"
    scroll_mode = "",     -- autoscroll mode of this project; "" = use the default (S.scroll_mode)
    hint_off = false,     -- "Not now" clicked on the mode hint (status line 2); written only when true
    turn_early = 0,       -- turn pages this many beats before their marker / cue (0 = on time); written only when not 0
    scroll_jump = false,  -- true: jump to each scroll point; false: move smoothly between them; written only when true
    split_off = false,    -- "Split view: Off": always 1 PDF, also for songs with 2 PDFs; written only when true
    assign2 = {},         -- region key -> pdf path: PDF 2 of the song, chosen by hand
    no2 = {},             -- region key -> true: no PDF 2 (the automatic pair was removed with the x)
    pair_off = false,     -- "Pair 2 matching PDFs" is off; written only when true
    folders = {},         -- the folders of "Add from folder" (for "Sync folders"): { path, sub = subfolders }; written only when used
    fixed_start = 0,      -- not used any more (the Fixed speed mode was removed before 1.0); still read and written, so the saved text stays the same
    view = {},            -- pdf path -> { fit = fit mode, zoom = manual zoom } (per-PDF zoom)
  }
end
local P = Project.default_project()

function Util.now() return r.time_precise() end
-- true at most every CFG.JOB_POLL_SEC for `job` (a table): a background job's result file is read
-- only that often, never every frame.
function Util.poll_due(job)
  local now = Util.now()
  if (job.next_poll or 0) > now then return false end
  job.next_poll = now + CFG.JOB_POLL_SEC
  return true
end
function Util.touch_override() R.override_until = Util.now() + CFG.MIDI_OVERRIDE_SEC end
function Util.mark_dirty() R.dirty = true end
-- R.lib_ver changes whenever the project config (library, assignments) may have changed.
-- Per-frame caches (dropdown list, library order) compare it to know when to rebuild.
function Util.mark_pdirty() R.pdirty = true; R.lib_ver = R.lib_ver + 1 end
function Util.bump_lib() R.lib_ver = R.lib_ver + 1 end
-- Stability diagnostics: printed only when "Write diagnostic log" is on.
function Msg.diag(msg)
  if S.log_diag then r.ShowConsoleMsg("[" .. CFG.TITLE .. " diag] " .. msg .. "\n") end
end

function Msg.set_error(msg)
  R.error = msg
  if msg then r.ShowConsoleMsg("[" .. CFG.TITLE .. "] " .. msg .. "\n") end
end

function Util.file_exists(p)
  if not p or p == "" then return false end
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

function Util.read_all(p, maxbytes)
  local f = io.open(p, "rb"); if not f then return nil end
  local d = f:read(maxbytes or "a"); f:close(); return d
end

-- Copies a small file byte for byte (used for the __startup.lua backup). Never touches the source.
function Util.copy_file(src, dst)
  local d = Util.read_all(src)
  if not d then return false end
  local f = io.open(dst, "wb")
  if not f then return false end
  f:write(d); f:close()
  return true
end

function Util.file_size(p)
  local f = io.open(p, "rb"); if not f then return 0 end
  local n = f:seek("end"); f:close(); return n or 0
end

function Util.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function Util.dir_of(p) return (p:match("^(.*)[/\\][^/\\]*$")) end
function Util.name_of(p) return (p:match("([^/\\]*)$")) end
function Util.same_path(a, b)
  if not a or not b then return false end
  return a:lower():gsub("/", "\\") == b:lower():gsub("/", "\\")
end
-- Path of `path` relative to folder `base`, with "/" separators, or nil if it is not inside it.
function Util.rel_path(path, base)
  if not path or not base or base == "" then return nil end
  local np = path:gsub("/", "\\")
  local nb = base:gsub("/", "\\"):gsub("\\+$", "") .. "\\"
  if #np <= #nb or np:sub(1, #nb):lower() ~= nb:lower() then return nil end
  return (np:sub(#nb + 1):gsub("\\", "/"))
end

function Util.join_path(d, n)
  if d:sub(-1) == "\\" or d:sub(-1) == "/" then return d .. n end
  return d .. SEP .. n
end

function Util.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Normalise a region name or PDF filename for matching
function Util.norm_name(s)
  s = Util.trim((s or ""):lower())
  s = s:gsub("%.pdf$", "")
  s = s:gsub("[_%-%s]+", " ")
  return Util.trim(s)
end

-- Name for matching a region to a PDF (NOT for keys: region keys use Util.norm_name, unchanged).
-- Both names get the same cleanup, then they must be equal:
--   "songA" -> "song a", "01 Song A (Bb).pdf" -> "song a", "Song_A - Bass v2.pdf" -> "song a".
-- If the cleanup removes every word (a song named "Bass"), the plain normalized name is used.
local MATCH_DROP = {}
for w in ("bass guitar gtr keys piano drums vocals vox chart charts chords lyrics score part bb eb concert final copy")
    :gmatch("%S+") do MATCH_DROP[w] = true end
function Util.match_name(s)
  s = (s or ""):gsub("%.[Pp][Dd][Ff]$", "")
  local plain = s
  s = s:gsub("%b()", " "):gsub("%b[]", " "):gsub("%b{}", " ")        -- (Bb), [v2], {live}
  s = s:gsub("%f[%w][vV]%d+%f[%W]", " ")                              -- versions: v2, V10
  s = s:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"):gsub("(%d)(%a)", "%1 %2") -- songA, track2
  s = s:lower():gsub("[_%-%.,%s]+", " ")
  s = s:gsub("^%s*%d+%s+(%S)", "%1")                                   -- track number at the start: "01 Song"
  local words = {}
  for w in s:gmatch("%S+") do
    if not MATCH_DROP[w] then words[#words + 1] = w end                -- part words: bass, chords, ...
  end
  local out = table.concat(words, " ")
  if out == "" then return Util.norm_name(plain) end
  return out
end

function Util.fmt_time(t) return string.format("%.1fs", t) end

---------------------------------------------------------------------------
-- POPPLER LOCATION
---------------------------------------------------------------------------
function PDF.find_pdftoppm()
  if S.pdftoppm_path ~= "" and Util.file_exists(S.pdftoppm_path) then return S.pdftoppm_path end
  -- on PATH? (checked by file name, so no process has to run)
  for dir in (os.getenv("PATH") or ""):gmatch("[^;]+") do
    local exe = Util.join_path(Util.trim((dir:gsub('"', ""))), "pdftoppm.exe")
    if Util.file_exists(exe) then return exe end
  end
  local roots = { "C:\\", "C:\\Program Files", "C:\\Program Files (x86)", "C:\\tools", "C:\\Tools" }
  local up = os.getenv("USERPROFILE")
  if up then roots[#roots + 1] = up; roots[#roots + 1] = up .. "\\Downloads"; roots[#roots + 1] = up .. "\\Documents" end
  local suffixes = { "\\Library\\bin\\pdftoppm.exe", "\\bin\\pdftoppm.exe", "\\pdftoppm.exe" }
  for _, root in ipairs(roots) do
    local i = 0
    while true do
      local sub = r.EnumerateSubdirectories(root, i)
      if not sub then break end
      if sub:lower():find("^poppler") then
        local base = root:gsub("[/\\]$", "") .. "\\" .. sub
        local bases = { base }
        local j = 0
        while true do
          local s2 = r.EnumerateSubdirectories(base, j)
          if not s2 then break end
          if s2:lower():find("^poppler") then bases[#bases + 1] = base .. "\\" .. s2 end
          j = j + 1
        end
        for _, b in ipairs(bases) do
          for _, suf in ipairs(suffixes) do
            if Util.file_exists(b .. suf) then return b .. suf end
          end
        end
      end
      i = i + 1
    end
  end
  return nil
end

function PDF.poppler_help()
  return "pdftoppm.exe not found. Install Poppler for Windows (e.g. https://github.com/oschwartz10612/poppler-windows/releases), "
      .. "unzip it, then use Settings > Display > PDF engine = Poppler > 'Browse...' to select  <poppler>\\Library\\bin\\pdftoppm.exe."
end

local POPPLER_PDFINFO_WARN = "pdftoppm.exe was found, but pdfinfo.exe was not found in the same folder. "
    .. "PDF page count and page-size detection may be unreliable. "
    .. "Install the complete Poppler package or select the folder containing both executables."

function PDF.pdfinfo_exe() return Util.dir_of(R.exe) .. SEP .. "pdfinfo.exe" end

function PDF.check_pdfinfo()
  R.pdfinfo_ok = (not R.exe) or Util.file_exists(PDF.pdfinfo_exe())
end

---------------------------------------------------------------------------
-- HASH / CACHE PATHS
---------------------------------------------------------------------------
function Util.hash_str(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) & 0xFFFFFFFF end
  return string.format("%08x", h)
end

-- Second, independent 32-bit hash (sdbm). Used with hash_str for a 64-bit content key.
function Util.hash_str2(s)
  local h = 0
  for i = 1, #s do h = (s:byte(i) + (h << 6) + (h << 16) - h) & 0xFFFFFFFF end
  return string.format("%08x", h)
end

-- Content key of a PDF: file size + hash of the first and last 64 KB. It does not depend on the
-- path or the file name, so a moved, copied or renamed PDF uses the same render cache.
-- (PDF edits are normally appended at the end of the file, so the last 64 KB changes when the
-- PDF changes.) Results are remembered per path and size, so the file is read only once.
PDF.key_memo = {}
-- Modification time via js_ReaScriptAPI when it is installed (REAPER itself has no such API).
function Util.file_mtime(p)
  if not r.JS_File_Stat then return nil end
  local rv, _, _, mtime = r.JS_File_Stat(p)
  if rv == 0 then return mtime end
  return nil
end

-- The memo is reused only while the file is unchanged: same size and same modification time,
-- or (without js_ReaScriptAPI) for CFG.KEY_MEMO_SEC, so a file edited in place gets a new key.
function PDF.content_key(pdf)
  local size, mtime = Util.file_size(pdf), Util.file_mtime(pdf)
  local memo = PDF.key_memo[pdf]
  if memo and memo.size == size then
    if mtime and memo.mtime == mtime then return memo.key end
    if not mtime and Util.now() - memo.t < CFG.KEY_MEMO_SEC then return memo.key end
  end
  local f = io.open(pdf, "rb")
  if not f then return nil end
  local head = f:read(CFG.KEY_SAMPLE) or ""
  local tail = ""
  if size > CFG.KEY_SAMPLE then
    f:seek("set", math.max(CFG.KEY_SAMPLE, size - CFG.KEY_SAMPLE))
    tail = f:read(CFG.KEY_SAMPLE) or ""
  end
  f:close()
  local sample = head .. "|" .. tail
  local key = string.format("pdf_%d_%s%s", size, Util.hash_str(sample), Util.hash_str2(sample))
  PDF.key_memo[pdf] = { size = size, mtime = mtime, t = Util.now(), key = key }
  return key
end

---------------------------------------------------------------------------
-- PDF ENGINES
--   windows: Windows 10/11 built-in PDF renderer (Windows.Data.Pdf) through PowerShell. No install.
--   poppler: pdftoppm.exe + pdfinfo.exe (optional, selectable in Settings > Display).
-- Both write the same files: <cache>\p-<page>.png, job.done (exit code), job.err (message).
-- Page count + page size are cached in <cache root>\<content key>\info.txt, so a PDF that was
-- opened once opens at once (PowerShell needs about 1 s to start).
---------------------------------------------------------------------------
function PDF.engine() return (S.engine == "poppler") and "poppler" or "windows" end


local PS_ENGINE_SCRIPT = [=[
param([string]$JobFile)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$cfg = @{}
foreach ($l in [IO.File]::ReadAllLines($JobFile, $utf8)) {
  $i = $l.IndexOf('=')
  if ($i -gt 0) { $cfg[$l.Substring(0, $i)] = $l.Substring($i + 1) }
}
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
  $null = [Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime]
  $null = [Windows.Data.Pdf.PdfPageRenderOptions,Windows.Data.Pdf,ContentType=WindowsRuntime]
  $null = [Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
  $m = [System.WindowsRuntimeSystemExtensions].GetMethods()
  $asTaskOp = ($m | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
  $asTaskAct = ($m | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
  function AwaitOp($op, [Type]$t) {
    $task = $asTaskOp.MakeGenericMethod($t).Invoke($null, @($op))
    try { $task.Wait() } catch { throw $_.Exception.InnerException.InnerException }
    $task.Result
  }
  function AwaitAct($a) {
    $task = $asTaskAct.Invoke($null, @($a))
    try { $task.Wait() } catch { throw $_.Exception.InnerException.InnerException }
  }
  $file = AwaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($cfg['pdf'])) ([Windows.Storage.StorageFile])
  $doc = AwaitOp ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
  if ($cfg['mode'] -eq 'info') {
    # same text format as pdfinfo.exe (sizes in points = 1/72 inch; the API uses 1/96 inch)
    $pg = $doc.GetPage(0)
    $w = ($pg.Size.Width * 0.75).ToString($inv); $h = ($pg.Size.Height * 0.75).ToString($inv)
    $pg.Dispose()
    [IO.File]::WriteAllText($cfg['out'], "Pages: " + $doc.PageCount + "`nPage size: " + $w + " x " + $h + " pts`n", $utf8)
  } else {
    $first = [int]$cfg['first']; $last = [int]$cfg['last']; $digits = [int]$cfg['digits']
    $dpi = [double]::Parse($cfg['dpi'], $inv); $maxdim = [int]$cfg['maxdim']
    for ($n = $first; $n -le $last; $n++) {
      $page = $doc.GetPage($n - 1)
      $w = $page.Size.Width; $h = $page.Size.Height
      if ($maxdim -gt 0) { $s = $maxdim / [Math]::Max($w, $h) } else { $s = $dpi / 96.0 }
      $opt = New-Object Windows.Data.Pdf.PdfPageRenderOptions
      $opt.DestinationWidth = [uint32][Math]::Max(1, [Math]::Round($w * $s))
      $opt.DestinationHeight = [uint32][Math]::Max(1, [Math]::Round($h * $s))
      $mem = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
      AwaitAct ($page.RenderToStreamAsync($mem, $opt))   # PNG is the default encoder
      $out = $cfg['prefix'] + '-' + $n.ToString('D' + $digits) + '.png'
      $src = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($mem.GetInputStreamAt(0))
      $fs = [IO.File]::Create($out + '.part')
      $src.CopyTo($fs); $fs.Close(); $src.Dispose(); $mem.Dispose(); $page.Dispose()
      if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
      Move-Item -LiteralPath ($out + '.part') -Destination $out
    }
  }
  [IO.File]::WriteAllText($cfg['done'], '0', $utf8)
} catch {
  [IO.File]::WriteAllText($cfg['err'], $_.Exception.Message, $utf8)
  [IO.File]::WriteAllText($cfg['done'], '1', $utf8)
}
# End the process at once. A normal exit lets .NET finalize the Windows Runtime (PDF) objects
# while the runtime shuts down, which can crash powershell.exe ("has stopped working").
# All result files are already written and closed here, so nothing is lost.
[System.Diagnostics.Process]::GetCurrentProcess().Kill()
]=]

-- Written once per session (at start-up, or at the first job if that failed), not before every job.
function PDF.write_engine_script()
  if PDF.engine_written then return true end
  Util.ensure_dir(CFG.TMP_DIR)
  local f = io.open(CFG.PS_ENGINE_FILE, "wb")
  if not f then return false end
  f:write((PS_ENGINE_SCRIPT:gsub("\n", "\r\n"))); f:close()
  PDF.engine_written = true
  return true
end

-- Job parameters go through a UTF-8 file (never the command line): spaces, Unicode and
-- apostrophes in paths are safe.
function PDF.run_engine_job(args_file, t)
  local f = io.open(args_file, "wb")
  if not f then return false end
  for k, v in pairs(t) do f:write(k, "=", tostring(v), "\n") end
  f:close()
  local res = r.ExecProcess('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
    .. CFG.PS_ENGINE_FILE .. '" -JobFile "' .. args_file .. '"', CFG.EXEC_NOWAIT)
  return res ~= nil
end

-- info cache (page count + page size text), stored per PDF content
function PDF.info_cache_file(path)
  local key = PDF.content_key(path)
  return key and (CFG.CACHE_ROOT .. SEP .. key .. SEP .. "info.txt") or nil
end

function PDF.read_info_cache(path)
  local f = PDF.info_cache_file(path)
  local d = f and Util.read_all(f)
  local n = d and tonumber(d:match("Pages:%s*(%d+)"))
  if n and n > 0 then return n, d end
  return nil
end

function PDF.write_info_cache(path, info)
  local f = PDF.info_cache_file(path)
  if not f or not info or not info:match("Pages:%s*%d+") then return end
  Util.ensure_dir(Util.dir_of(f))
  local h = io.open(f, "wb")
  if h then h:write(info); h:close() end
end

-- Reads page count + page size in the background. Windows engine: the PowerShell script.
-- Poppler: pdfinfo.exe from a .bat (the Windows engine is used when pdfinfo.exe is missing).
-- The caller stores the job in R.info_job (opening a PDF) or R.lib_job (Library page count).
function PDF.start_info(path, keep_position)
  R.info_seq = R.info_seq + 1
  local base = CFG.TMP_DIR .. SEP .. "info_" .. R.info_seq
  local job = { path = path, keep = keep_position, started = Util.now(), kind = "ps",
    out_f = base .. ".out", done_f = base .. ".done", err_f = base .. ".err", run_f = base .. ".args" }
  local ok = false
  if PDF.engine() == "poppler" and R.exe and R.pdfinfo_ok then
    job.kind, job.run_f = "pdfinfo", base .. ".bat"
    local f = io.open(job.run_f, "wb")
    if f then
      f:write("@echo off\r\nchcp 65001 >nul\r\n",
        string.format('"%s" "%s" > "%s" 2> "%s"\r\n', PDF.bat_escape(PDF.pdfinfo_exe()), PDF.bat_escape(path),
          PDF.bat_escape(job.out_f), PDF.bat_escape(job.err_f)),
        string.format('echo %%errorlevel%% > "%s"\r\n', PDF.bat_escape(job.done_f)))
      f:close()
      ok = r.ExecProcess('cmd.exe /C "' .. job.run_f .. '"', CFG.EXEC_NOWAIT) ~= nil
    end
  else
    ok = PDF.write_engine_script() and PDF.run_engine_job(job.run_f,
      { mode = "info", pdf = path, out = job.out_f, done = job.done_f, err = job.err_f })
  end
  return ok and job or nil
end

-- nil while running; otherwise ok, output text, error text ("timeout" when it did not answer).
function PDF.poll_info(job)
  if not Util.poll_due(job) then return nil end
  local d = Util.read_all(job.done_f, 32)
  if d and not d:match("%d") then d = nil end -- .done exists but is not written yet: still running
  local timeout = not d and Util.now() - job.started > CFG.INFO_TIMEOUT_SEC
  if not d and not timeout then return nil end
  local out, err = Util.read_all(job.out_f) or "", Util.read_all(job.err_f, 600) or ""
  for _, f in ipairs({ job.out_f, job.done_f, job.err_f, job.run_f }) do os.remove(f) end
  if timeout then return false, "", "timeout" end
  return (tonumber(d:match("%-?%d+")) or 1) == 0, out, (err:gsub("[\r\n]+", " "))
end

-- Page count from the info text, or nil + a message.
function PDF.parse_info(out, err)
  if (out .. " " .. err):lower():find("password", 1, true) then
    return nil, "This PDF is encrypted / password protected and cannot be rendered."
  end
  local n = tonumber(out:match("Pages:%s*(%d+)"))
  if n and n > 0 then return n end
  if err ~= "" then return nil, "Could not read the PDF: " .. err:sub(1, 200) end
  return nil, "Could not determine the page count (invalid PDF)."
end

function PDF.info_tick()
  local job = R.info_job
  if job then
    local ok, out, err = PDF.poll_info(job)
    if ok ~= nil then
      R.info_job = nil
      local engine = (job.kind == "ps") and "Windows PDF engine" or "pdfinfo"
      if err == "timeout" then
        Msg.set_error(engine .. " did not answer. Try again, or select the other PDF engine in Settings > Display."
          .. (job.kind == "ps" and " Antivirus or a company policy can block PowerShell." or ""))
      else
        local n, msg = PDF.parse_info(out, err)
        if n then
          PDF.write_info_cache(job.path, out)
          if Util.same_path(job.path, S.pdf_path) then PDF.finish_open(job.path, job.keep, n, out) end
        else
          Msg.set_error(engine .. ": " .. msg .. " (You can select the other PDF engine in Settings > Display.)")
        end
      end
    end
  end
  local lj = R.lib_job
  if lj then
    local ok, out, err = PDF.poll_info(lj)
    if ok ~= nil then
      R.lib_job = nil
      local n = (err ~= "timeout") and PDF.parse_info(out, err) or nil
      if n then PDF.write_info_cache(lj.path, out) end
      R.libpages[lj.path] = n or false; Util.bump_lib()
    end
  end
end

function PDF.compute_cache_dir(pdf)
  -- content key; a file that cannot be read gets a path key (it cannot be rendered anyway)
  local key = PDF.content_key(pdf) or ("unreadable_" .. Util.hash_str(pdf:lower()))
  local suffix = "dpi" .. S.dpi .. (R.scale_to and ("_max" .. R.scale_to) or "")
    .. (PDF.engine() == "windows" and "_win" or "") -- each engine has its own page images
  return CFG.CACHE_ROOT .. SEP .. key .. SEP .. suffix
end

---------------------------------------------------------------------------
-- PAGE FILE LOOKUP + BATCH RENDERING (non-blocking)
---------------------------------------------------------------------------
function PDF.total_batches() return math.ceil(R.total / CFG.BATCH_SIZE) end
function PDF.batch_of(p) return math.ceil(p / CFG.BATCH_SIZE) end

-- pdftoppm (and the Windows engine) zero-pad the page number to the digit count of the page total
function PDF.find_page_file(p)
  if R.page_paths[p] then return R.page_paths[p] end
  for _, fmt in ipairs({ "%s-%0" .. #tostring(R.total) .. "d.png", "%s-%d.png" }) do
    local path = string.format(fmt, R.prefix, p)
    if Util.file_exists(path) then R.page_paths[p] = path; return path end
  end
  return nil
end

function PDF.batch_range(b)
  local first = (b - 1) * CFG.BATCH_SIZE + 1
  return first, math.min(first + CFG.BATCH_SIZE - 1, R.total)
end

function PDF.batch_status(b)
  local st = R.bstate[b]
  if st then return st end
  if R.job and R.job.batch == b then return "running" end
  local first, last = PDF.batch_range(b)
  for p = first, last do
    if not PDF.find_page_file(p) then R.bstate[b] = "todo"; return "todo" end
  end
  R.bstate[b] = "done"; R.batches_done = R.batches_done + 1
  return "done"
end

function PDF.page_ready(p) return PDF.batch_status(PDF.batch_of(p)) == "done" end
function PDF.bat_escape(s) return (s:gsub("%%", "%%%%")) end

function PDF.start_batch(b)
  local first, last = PDF.batch_range(b)
  local done_f = R.cache_dir .. SEP .. "job.done"
  local err_f = R.cache_dir .. SEP .. "job.err"
  local bat_f = R.cache_dir .. SEP .. "job.bat"
  os.remove(done_f); os.remove(err_f)
  if PDF.engine() == "windows" then
    local ok = PDF.write_engine_script() and PDF.run_engine_job(R.cache_dir .. SEP .. "job.args", {
      mode = "render", pdf = S.pdf_path, first = first, last = last, digits = #tostring(R.total),
      prefix = R.prefix, dpi = S.dpi, maxdim = R.scale_to or 0, done = done_f, err = err_f })
    if not ok then
      Msg.set_error("Could not start the Windows PDF engine (PowerShell). Antivirus or a company policy can block it. "
        .. "Select Poppler in Settings > Display.")
      R.bstate[b] = "failed"; return
    end
    R.job = { batch = b, started = Util.now(), done_f = done_f, err_f = err_f }
    return
  end
  local lines = {
    "@echo off", "chcp 65001 >nul",
    string.format('"%s" -png %s -f %d -l %d "%s" "%s" 2> "%s"',
      PDF.bat_escape(R.exe),
      R.scale_to and ("-scale-to " .. R.scale_to) or ("-r " .. S.dpi),
      first, last, PDF.bat_escape(S.pdf_path), PDF.bat_escape(R.prefix), PDF.bat_escape(err_f)),
    string.format('echo %%errorlevel%% > "%s"', PDF.bat_escape(done_f)),
  }
  local f = io.open(bat_f, "wb")
  if not f then Msg.set_error("Cannot write to cache folder: " .. R.cache_dir); R.bstate[b] = "failed"; return end
  f:write(table.concat(lines, "\r\n"), "\r\n"); f:close()
  local ok = r.ExecProcess('cmd.exe /C "' .. bat_f .. '"', CFG.EXEC_NOWAIT)
  if ok == nil then
    Msg.set_error("Failed to launch pdftoppm (cmd.exe could not start the render job).")
    R.bstate[b] = "failed"; return
  end
  R.job = { batch = b, started = Util.now(), done_f = done_f, err_f = err_f }
end

function PDF.finish_job(code)
  local job = R.job
  local b = job.batch
  R.job = nil
  local first, last = PDF.batch_range(b)
  if code == 0 then
    R.bstate[b] = nil
    for p = first, last do R.page_paths[p] = nil end
    local all = true
    for p = first, last do if not PDF.find_page_file(p) then all = false end end
    if all then R.bstate[b] = "done"; R.batches_done = R.batches_done + 1
    else R.bstate[b] = "failed"; Msg.set_error(string.format("Render finished but pages %d-%d are missing.", first, last)) end
  else
    R.bstate[b] = "failed"
    local err = (Util.read_all(job.err_f, 600) or ""):gsub("[\r\n]+", " ")
    if err:lower():find("password") then err = "PDF is encrypted/password protected. " .. err end
    Msg.set_error(string.format("%s failed (exit %d) on pages %d-%d. %s",
      PDF.engine() == "windows" and "Windows PDF engine" or "pdftoppm", code, first, last, err))
  end
end

function PDF.pick_next_batch()
  local nb = PDF.total_batches()
  if nb == 0 then return nil end
  local cur = PDF.batch_of(S.page)
  local order = { cur, cur + 1 }
  -- all pages are always prepared in the background, the pages near the current page first
  order[#order + 1] = cur - 1
  for b = cur + 2, nb do order[#order + 1] = b end
  for b = cur - 2, 1, -1 do order[#order + 1] = b end
  for _, b in ipairs(order) do
    if b >= 1 and b <= nb and PDF.batch_status(b) == "todo" then return b end
  end
  return nil
end

function PDF.render_tick()
  if R.total == 0 or not R.cache_dir then return end
  if R.job then
    if not Util.poll_due(R.job) then return end
    local d = Util.read_all(R.job.done_f, 32)
    if d and d:match("%d") then PDF.finish_job(tonumber(d:match("%-?%d+")) or 1)
    elseif Util.now() - R.job.started > CFG.JOB_TIMEOUT_SEC then
      R.bstate[R.job.batch] = "failed"; R.job = nil
      Msg.set_error("Render timed out. Check that pdftoppm.exe runs, then press 'Retry rendering'.")
    end
    return
  end
  local b = PDF.pick_next_batch()
  if b then PDF.start_batch(b) end
end

function PDF.retry_failed()
  for b, st in pairs(R.bstate) do if st == "failed" then R.bstate[b] = nil end end
  Msg.set_error(nil)
end

---------------------------------------------------------------------------
-- PROJECT IDENTITY + PER-PROJECT CONFIG
---------------------------------------------------------------------------

-- Text format (one "key=value" per line) shared by the .rpp ExtState.
function Project.parse_cfg(lines_iter)
  local p = Project.default_project()
  for line in lines_iter do
    line = line:gsub("\r$", "")
    -- [%w_]: keys such as scroll_mode and cue_unit contain "_" (%w alone does not match it)
    local k, v = line:match("^([%w_]+)=(.*)$")
    if k == "pdf" then
      p.pdfs[#p.pdfs + 1] = v
    elseif k == "assign" then
      local key, path = v:match("^(.-)\t(.*)$")
      if key then p.assign[key] = path end
    elseif k == "ignore" then
      p.ignore[v] = true
    elseif k == "assign2" then
      local key, pdf = v:match("^(.-)\t(.*)$")
      if key then p.assign2[key] = pdf end
    elseif k == "no2" then
      p.no2[v] = true
    elseif k == "pair_off" then p.pair_off = (v == "1")
    elseif k == "folder" then
      local dir, sub = v:match("^(.-)\t(.*)$")
      if dir and dir ~= "" then p.folders[#p.folders + 1] = { path = dir, sub = (sub == "1") } end
    elseif k == "rname" then
      local key, nm = v:match("^(.-)\t(.*)$")
      if key then p.names[key] = nm end
    elseif k == "auto_switch" then p.auto_switch = (v == "1")
    elseif k == "continue_after_end" then p.continue_after_end = (v == "1")
    elseif k == "active_pdf" then p.active_pdf = v
    elseif k == "cue_unit" then p.cue_unit = (v == "seconds") and "seconds" or "beats"
    elseif k == "scroll_mode" then
      p.scroll_mode = (v == "off" or v == "fixed" or v == "marker" or v == "cues") and v or ""
    elseif k == "hint_off" then p.hint_off = (v == "1")
    elseif k == "turn_early" then p.turn_early = Util.clamp(tonumber(v) or 0, 0, 4)
    elseif k == "scroll_jump" then p.scroll_jump = (v == "1")
    elseif k == "split_off" then p.split_off = (v == "1")
    elseif k == "fixed_start" then p.fixed_start = tonumber(v) or 0
    elseif k == "view" then
      local path, fit, zoom = v:match("^(.-)\t(.-)\t(.*)$")
      if path and fit ~= "" then p.view[path] = { fit = fit, zoom = tonumber(zoom) or 1.0 } end
    elseif k == "cue" then
      local key, pos, pg, sc = v:match("^(.-)\t(.-)\t(.-)\t(.*)$")
      pos = tonumber(pos)
      if key and pos then
        p.cues[key] = p.cues[key] or {}
        table.insert(p.cues[key], { pos = pos, page = tonumber(pg), scroll = tonumber(sc) })
      end
    elseif k == "prel" then
      local path, rel = v:match("^(.-)\t(.*)$")
      if path and rel ~= "" then p.rel[path] = rel end
    end
  end
  return p
end

function Project.serialize_cfg()
  local t = {}
  local function w(k, v) t[#t + 1] = k .. "=" .. (tostring(v):gsub("[\r\n]", " ")) end
  w("version", 1)
  w("auto_switch", P.auto_switch and 1 or 0)
  w("continue_after_end", P.continue_after_end and 1 or 0)
  w("active_pdf", P.active_pdf)
  for _, path in ipairs(P.pdfs) do w("pdf", path) end
  for _, path in ipairs(P.pdfs) do
    if P.rel[path] then w("prel", path .. "\t" .. P.rel[path]) end
  end
  -- sorted keys: an unchanged config always gives the same text (check_project compares the
  -- texts to tell "Save as" from "Open project", and save_project_cfg skips unchanged writes)
  local function sorted(t)
    local k = {}
    for x in pairs(t) do k[#k + 1] = x end
    table.sort(k)
    return k
  end
  for _, key in ipairs(sorted(P.assign)) do w("assign", key .. "\t" .. P.assign[key]) end
  for _, key in ipairs(sorted(P.ignore)) do w("ignore", key) end
  for _, key in ipairs(sorted(P.assign2)) do w("assign2", key .. "\t" .. P.assign2[key]) end -- only when used
  for _, key in ipairs(sorted(P.no2)) do w("no2", key) end
  for _, key in ipairs(sorted(P.names)) do
    -- names are only needed for regions that have a manual choice (keeps the data small)
    if P.assign[key] or P.ignore[key] or P.assign2[key] or P.no2[key] then w("rname", key .. "\t" .. P.names[key]) end
  end
  w("cue_unit", P.cue_unit)
  -- only written when set, so projects that never changed the mode keep the same text
  if P.scroll_mode ~= "" then w("scroll_mode", P.scroll_mode) end
  if P.hint_off then w("hint_off", 1) end -- only when set, so older projects keep the same text
  if P.turn_early ~= 0 then w("turn_early", string.format("%g", P.turn_early)) end -- the same
  if P.scroll_jump then w("scroll_jump", 1) end -- the same
  if P.split_off then w("split_off", 1) end -- the same
  if P.pair_off then w("pair_off", 1) end -- the same
  for _, fo in ipairs(P.folders) do w("folder", fo.path .. "\t" .. (fo.sub and 1 or 0)) end -- only when used
  if P.fixed_start ~= 0 then w("fixed_start", string.format("%.6f", P.fixed_start)) end
  for _, path in ipairs(sorted(P.view)) do
    w("view", string.format("%s\t%s\t%.3f", path, P.view[path].fit, P.view[path].zoom))
  end
  for _, key in ipairs(sorted(P.cues)) do
    for _, c in ipairs(P.cues[key]) do
      w("cue", string.format("%s\t%.4f\t%s\t%s", key, c.pos, c.page and tostring(c.page) or "",
        c.scroll and string.format("%.1f", c.scroll) or ""))
    end
  end
  return table.concat(t, "\n")
end

function Project.valid_proj(proj)
  if not proj then return false end
  local ok, valid = pcall(r.ValidatePtr2, 0, proj, "ReaProject*")
  return ok and valid
end

-- Reads the config from the project's own ExtState (.rpp). Returns config, source ("rpp" | "new").
function Project.load_project_cfg(proj)
  if Project.valid_proj(proj) then
    local n, txt = r.GetProjExtState(proj, CFG.PEXT, CFG.PEXT_KEY)
    if n and n > 0 and txt and txt ~= "" then
      return Project.parse_cfg((txt .. "\n"):gmatch("([^\n]*)\n")), "rpp"
    end
  end
  return Project.default_project(), "new"
end

-- Writes the config into R.proj (the project it belongs to, not necessarily the active tab).
-- Works for unsaved projects too: REAPER writes the ExtState to disk when the project is saved.
function Project.save_project_cfg()
  if not Project.valid_proj(R.proj) then return false end
  local txt = Project.serialize_cfg()
  if txt == R.plast_txt then return true end -- unchanged: do not mark the project modified
  r.SetProjExtState(R.proj, CFG.PEXT, CFG.PEXT_KEY, txt)
  R.plast_txt = txt
  return true
end

---------------------------------------------------------------------------
-- MARKER + REGION SCAN
---------------------------------------------------------------------------
-- The project Chart Cue works on (R.proj, the project of its data); the active tab only before one is set.
-- (A question such as "Remove PDF markers?" runs a moment later: it must still act on this project.)
function Project.cur()
  return Project.valid_proj(R.proj) and R.proj or 0
end

function Project.region_key(guid, name, pos)
  if guid and guid ~= "" then return "g" .. guid:gsub("[^%w%-]", "") end
  return (("n" .. Util.norm_name(name) .. "@" .. string.format("%.2f", pos)):gsub("[^%w%-_@%.]", "_"))
end

function Project.resolve_regions()
  -- a PDF matches when either the plain names (old rule) or the cleaned-up names (Util.match_name) are
  -- equal, so every match that worked before still works
  local norms, matches = {}, {}
  for i, path in ipairs(P.pdfs) do
    local n = Util.name_of(path)
    norms[i], matches[i] = Util.norm_name(n), Util.match_name(n)
  end
  local function by_name(a, b) return Util.name_of(a):lower() < Util.name_of(b):lower() end
  for _, reg in ipairs(R.regions) do
    reg.cands, reg.pdf, reg.pdf2 = {}, nil, nil
    if P.ignore[reg.key] then
      reg.status = "ignored"
    else
      local exact -- a PDF with exactly the song's name ("Song A.pdf"): the main chart
      for i, n in ipairs(norms) do
        if (n ~= "" and n == reg.norm) or (matches[i] ~= "" and matches[i] == reg.match) then
          reg.cands[#reg.cands + 1] = P.pdfs[i]
          if n ~= "" and n == reg.norm then exact = P.pdfs[i] end
        end
      end
      -- exactly 2 matching PDFs, both a part ("Song A lyrics" + "Song A bass"): PDF 1 + PDF 2
      -- ("Pair 2 matching PDFs", unless removed with the x). With "Song A" + "Song A lyrics" the
      -- exact name is the main chart, alone (the + adds the other one).
      local pair = (#reg.cands == 2) and not exact and not P.pair_off and not P.no2[reg.key]
      if #reg.cands == 2 and exact and not P.assign[reg.key] then
        reg.status, reg.pdf = "auto", exact
      end
      if pair then table.sort(reg.cands, by_name) end
      if P.assign[reg.key] then
        reg.status = "assigned"; reg.pdf = P.assign[reg.key]
        if pair then -- PDF 1 chosen by hand: the other match is PDF 2
          if Util.same_path(reg.pdf, reg.cands[1]) then reg.pdf2 = reg.cands[2]
          elseif Util.same_path(reg.pdf, reg.cands[2]) then reg.pdf2 = reg.cands[1] end
        end
      elseif reg.pdf then -- the exact name of 2 matches (set above)
      elseif #reg.cands == 1 then reg.status = "auto"; reg.pdf = reg.cands[1]
      elseif #reg.cands == 0 then reg.status = "unassigned"
      elseif pair then reg.status = "auto"; reg.pdf, reg.pdf2 = reg.cands[1], reg.cands[2]
      else reg.status = "ambiguous" end
      if P.assign2[reg.key] and reg.pdf then reg.pdf2 = P.assign2[reg.key] end -- chosen by hand
      if reg.pdf2 and Util.same_path(reg.pdf2, reg.pdf) then reg.pdf2 = nil end
    end
  end
end

function Project.region_by_key(key)
  for _, reg in ipairs(R.regions) do if reg.key == key then return reg end end
  return nil
end

-- PDF markers: the name starts with PDFPAGE or PDFSCROLL (any case). Regions are never included.
function Project.is_script_marker(name)
  local l = Util.trim((name or ""):lower())
  return l:find("^pdfscroll") ~= nil or l:find("^pdfpage") ~= nil
end

-- Indexes of the PDF markers in [lo, hi), highest index first (safe order for deleting).
function Project.script_markers(lo, hi)
  local idx = {}
  local proj = Project.cur()
  local total = r.CountProjectMarkers(proj) or 0
  for i = total - 1, 0, -1 do
    local ok, isrgn, pos, _, name = r.EnumProjectMarkers3(proj, i)
    if ok and ok > 0 and not isrgn and pos >= lo and pos < hi and Project.is_script_marker(name) then
      idx[#idx + 1] = i
    end
  end
  return idx
end

-- Removes the PDF markers between lo and hi as one undo step (asked first by UI.ask_remove_markers).
function Project.remove_script_markers(lo, hi, where)
  local idx = Project.script_markers(lo, hi)
  if #idx == 0 then return end
  r.Undo_BeginBlock()
  local proj = Project.cur()
  for _, i in ipairs(idx) do r.DeleteProjectMarkerByIndex(proj, i) end
  r.Undo_EndBlock("Chart Cue: remove PDF markers", -1)
  r.UpdateTimeline()
  Project.scan_project()
  Msg.notify(string.format("%d marker(s) removed from %s.", #idx, where), false, "cues")
end

-- "Rescan project" button: scans and reports the result in the section (source = message area).
function Project.rescan(source)
  Project.scan_project()
  Msg.notify(string.format("Rescanned: %d region(s), %d PDFPAGE and %d PDFSCROLL marker(s)%s.",
    #R.regions, #R.page_pts, #R.scroll_pts,
    #R.marker_warns > 0 and string.format(", %d invalid", #R.marker_warns) or ""), false, source)
end

-- Reads every region and PDF marker (PDFSCROLL / PDFPAGE) of the active project.
function Project.scan_project()
  R.regions, R.scroll_pts, R.page_pts, R.marker_warns = {}, {}, {}, {}
  local proj = Project.cur()
  local total = r.CountProjectMarkers(proj) or 0
  local no_guid = 0
  for i = 0, total - 1 do
    local retval, isrgn, pos, rend, name = r.EnumProjectMarkers3(proj, i)
    if retval and retval > 0 then
      name = name or ""
      if isrgn then
        local okg, guid = r.GetSetProjectInfo_String(proj, "MARKER_GUID:" .. i, "", false)
        if not okg or guid == "" then guid = nil; no_guid = no_guid + 1 end
        R.regions[#R.regions + 1] = {
          key = Project.region_key(guid, name, pos), name = name, norm = Util.norm_name(name), match = Util.match_name(name),
          start = pos, stop = rend,
        }
      else
        local lname = Util.trim(name:lower())
        if lname:find("^pdfscroll") then
          local num = tonumber(lname:sub(10):match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
          if num and num >= 0 and num <= 100 then
            R.scroll_pts[#R.scroll_pts + 1] = { t = pos, pct = num, ord = i }
          else
            R.marker_warns[#R.marker_warns + 1] = string.format('Invalid marker "%s" at %s', name, Util.fmt_time(pos))
          end
        elseif lname:find("^pdfpage") then
          local num = tonumber(lname:sub(8):match("^%s*(%d+)%s*$"))
          if num and num >= 1 then
            R.page_pts[#R.page_pts + 1] = { t = pos, page = num, ord = i }
          else
            R.marker_warns[#R.marker_warns + 1] = string.format('Invalid marker "%s" at %s', name, Util.fmt_time(pos))
          end
        end
      end
    end
  end
  -- one log line per change (the scan runs after every project change)
  if no_guid ~= R.no_guid_logged then
    if no_guid > 0 then Msg.diag(string.format("%d region(s) have no GUID; they use name and position as their key.", no_guid)) end
    R.no_guid_logged = no_guid
  end
  local function by_time(a, b) if a.t ~= b.t then return a.t < b.t end return a.ord < b.ord end
  table.sort(R.scroll_pts, by_time)
  table.sort(R.page_pts, by_time)
  table.sort(R.regions, function(a, b) return a.start < b.start end)
  Project.resolve_regions()
  if R.active_region then R.active_region = Project.region_by_key(R.active_region.key) end
end

---------------------------------------------------------------------------
-- OPENING A PDF / LIBRARY
---------------------------------------------------------------------------
-- Page images are attached to the ImGui context, so ReaImGui does not delete them while the
-- window is hidden (for example in an inactive dock tab). Detach them when the cache drops them.
function PDF.release_image(e)
  -- protected: the image may already be invalid
  if e and e.img and R.ctx then pcall(r.ImGui_Detach, R.ctx, e.img) end
end

function PDF.reset_images()
  for _, e in pairs(R.images) do PDF.release_image(e) end
  R.images = {}; R.image_order = {}; R.page_paths = {}
end

-- Forget the open PDF: page count, render jobs, textures, active region.
function PDF.reset_state()
  R.total = 0; R.job = nil; R.bstate = {}; R.batches_done = 0; PDF.reset_images()
  R.active_region = nil; R.mpage_last = nil
  R.info_job = nil -- a running page-count job is ignored when it finishes
end

function PDF.open_pdf(path, keep_position)
  if not Util.same_path(path, S.pdf_path) then R.force_scale = false end -- the cap belongs to one PDF
  Msg.set_error(nil)
  PDF.reset_state()
  if not path or path == "" then return end
  if not Util.file_exists(path) then Msg.set_error("PDF not found: " .. path); return end
  S.pdf_path = path
  R.pdf_name = Util.name_of(path)
  if PDF.engine() == "poppler" then
    if not R.exe then R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo() end
    if not R.exe then Msg.set_error(PDF.poppler_help()); return end
    S.pdftoppm_path = R.exe
  end

  -- page count + size: cache first (instant), otherwise in the background (PDF.info_tick)
  local n, info = PDF.read_info_cache(path)
  if n then return PDF.finish_open(path, keep_position, n, info) end
  R.info_job = PDF.start_info(path, keep_position)
  if not R.info_job then
    Msg.set_error("Could not start the PDF engine. Select the other PDF engine in Settings > Display.")
  end
end

-- Second half of opening a PDF, once the page count and page size are known.
function PDF.finish_open(path, keep_position, n, info)
  if not n or n < 1 then Msg.set_error("Could not determine the page count (invalid PDF)."); return end
  R.total = n
  R.libpages[path] = n; Util.bump_lib()
  if R.replace_check and Util.same_path(path, R.replace_check) then R.replace_check = nil; Project.check_replaced_pages(path, n) end

  -- Cap texture size: if page 1 at the chosen DPI exceeds MAX_IMAGE_DIM, render with -scale-to instead.
  R.scale_to = nil
  local wpt, hpt = (info or ""):match("Page size:%s*([%d%.]+)%s*x%s*([%d%.]+)")
  wpt, hpt = tonumber(wpt), tonumber(hpt) -- nil when the size is missing or not a number (e.g. ".")
  R.page_w_pt = wpt -- page width in points (1/72 inch), used for "100%" = real size
  if wpt and hpt and math.max(wpt, hpt) / 72 * S.dpi > CFG.MAX_IMAGE_DIM then
    R.scale_to = CFG.MAX_IMAGE_DIM
  end
  if R.force_scale then R.scale_to = CFG.MAX_IMAGE_DIM end

  R.cache_dir = PDF.compute_cache_dir(path)
  Util.ensure_dir(R.cache_dir)
  R.prefix = R.cache_dir .. SEP .. "p"
  if not keep_position then S.page = 1; S.scroll_y = 0; S.scroll_x = 0 end
  S.page = Util.clamp(S.page, 1, R.total)
  local view = P.view[path] -- per-PDF zoom
  if view then S.fit_mode, S.zoom = view.fit, Util.clamp(view.zoom, CFG.MIN_ZOOM, CFG.MAX_ZOOM)
  else S.fit_mode, S.zoom = "width", 1.0 end -- no saved zoom: start with "Fit width"
  R.cache_size = nil
  if not R.in_part2 then -- part 2 (the 2nd PDF on screen) is not the project's PDF
    if P.active_pdf ~= path then P.active_pdf = path; Util.mark_pdirty() end
    local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
    if reg and reg.pdf and Util.same_path(reg.pdf, path) then R.active_region = reg end
    R.scan_due = Util.now() -- rescan markers whenever a PDF is opened
  end
  Util.mark_dirty()
end

---------------------------------------------------------------------------
-- PORTABLE PATHS (relative to the project folder) + MISSING-PDF RECOVERY
---------------------------------------------------------------------------
-- Folder of the saved project file, or nil for an unsaved project.
function Project.dir()
  if not R.projfn or R.projfn == "" then return nil end
  return Util.dir_of(R.projfn)
end

-- Replaces library entry `old` with `new` everywhere: library, region assignments, active PDF,
-- relative path and the open PDF. If `new` is already in the library, the two entries merge.
function Project.remap_pdf(old, new)
  if Util.same_path(old, new) then return end
  local has_new = false
  for _, p in ipairs(P.pdfs) do if Util.same_path(p, new) then has_new = true end end
  for i = #P.pdfs, 1, -1 do
    if Util.same_path(P.pdfs[i], old) then
      if has_new then table.remove(P.pdfs, i) else P.pdfs[i] = new; has_new = true end
    end
  end
  for key, p in pairs(P.assign) do if Util.same_path(p, old) then P.assign[key] = new end end
  if Util.same_path(P.active_pdf, old) then P.active_pdf = new end
  P.rel[old] = nil
  P.rel[new] = Util.rel_path(new, Project.dir()) or P.rel[new]
  R.libpages[new] = R.libpages[new] or R.libpages[old]
  R.libexists[new] = Util.file_exists(new)
  if Util.same_path(S.pdf_path, old) then S.pdf_path = new end
  if P.view[old] then P.view[new] = P.view[new] or P.view[old]; P.view[old] = nil end
  Util.mark_pdirty()
end

-- Finds every library PDF: 1) relative path from the current project folder, 2) stored absolute
-- path. Adds a relative path for PDFs inside the project folder (also for old projects).
-- Returns the number of PDFs that were found at their relative path.
function Project.resolve_paths()
  local dir = Project.dir()
  local moved = 0
  local list = {}
  for i, p in ipairs(P.pdfs) do list[i] = p end
  for _, abs in ipairs(list) do
    local rel = P.rel[abs]
    local cand = (dir and rel) and Util.join_path(dir, (rel:gsub("/", "\\"))) or nil
    if cand and Util.file_exists(cand) then
      if not Util.same_path(cand, abs) then Project.remap_pdf(abs, cand); moved = moved + 1 end
    elseif Util.file_exists(abs) then
      local r2 = Util.rel_path(abs, dir)
      if r2 and r2 ~= rel then P.rel[abs] = r2; Util.mark_pdirty() end
    end
  end
  if moved > 0 then Project.resolve_regions() end
  R.libexists_t = 0
  return moved
end

-- Number of regions that currently use `path` (manual or automatic assignment).
function Project.region_use_count(path)
  local n = 0
  for _, reg in ipairs(R.regions) do
    if reg.pdf and Util.same_path(reg.pdf, path) then n = n + 1 end
  end
  return n
end

-- Relocate a missing PDF to `new`, then look in the same folder for the other missing PDFs
-- (by file name). Returns the number of other PDFs found.
function Project.relocate_pdf(old, new)
  Project.remap_pdf(old, new)
  local folder = Util.dir_of(new)
  local found = 0
  local list = {}
  for i, p in ipairs(P.pdfs) do list[i] = p end
  for _, p in ipairs(list) do
    if not Util.file_exists(p) then
      local cand = Util.join_path(folder, Util.name_of(p))
      if Util.file_exists(cand) then Project.remap_pdf(p, cand); found = found + 1 end
    end
  end
  Project.resolve_regions()
  R.libexists_t = 0
  -- reload the region under the play cursor if its PDF just came back
  R.cur_region_key = nil
  return found
end

-- "Replace PDF..." (toolbar / page menu: the PDF on screen; PDF row menu: that PDF): a new file for
-- the library entry `old`. Region choices, zoom and cues stay (cues belong to the song). The new file
-- is copied into the project like any import. PDF.finish_open checks the cue pages (R.replace_check).
function Project.replace_pdf(old)
  local ok, f = r.GetUserFileNameForRead("", "Replace " .. Util.name_of(old), "pdf")
  if not (ok and f and f ~= "") or Util.same_path(f, old) then return end
  local was_open = Util.same_path(old, S.pdf_path) and R.total > 0
  R.libpages[f] = nil -- the old page count does not belong to the new file
  local dst = Project.should_copy(f) and (Project.pdf_dir() .. SEP .. Util.name_of(f)) or f
  R.replace_check = dst
  local res = Project.import_pdf(f, { remap_from = old, open = was_open })
  if res == "queued" then
    Msg.notify("Copying the new PDF into the project folder...", false, "library")
  else
    R.libpages[f] = nil
    Project.resolve_regions(); R.cur_region_key = nil; R.libexists_t = 0
    Msg.notify(string.format("Replaced %s with %s.", Util.name_of(old), Util.name_of(f)), false, "library")
  end
end

-- After "Replace PDF...": the cues of the songs that use `path` with a page above `n` (message only).
function Project.check_replaced_pages(path, n)
  local bad = 0
  for _, reg in ipairs(R.regions) do
    if reg.pdf and Util.same_path(reg.pdf, path) then
      for _, c in ipairs(Cues.list(reg)) do if c.page and c.page > n then bad = bad + 1 end end
    end
  end
  if bad > 0 then
    Msg.notify(string.format("The new PDF has %d page(s); %d cue(s) use a higher page. Check them in the Cues tab.", n, bad),
      true, "library", true)
  end
end

-- The library PDFs that no region uses (as PDF 1 or PDF 2) and that are not on screen:
-- path -> true. Rebuilt when the library or the regions change.
function Project.unused_pdfs()
  local c = R.unused_cache
  local open2 = R.part2 and R.part2.s.pdf_path or nil -- (PDF 2 on screen is not unused either)
  if c and c.ver == R.lib_ver and c.regs == R.regions and c.P == P and c.open == S.pdf_path and c.open2 == open2 then
    return c.set, c.n
  end
  local used = {}
  for _, reg in ipairs(R.regions) do
    if reg.pdf then used[reg.pdf:lower()] = true end
    if reg.pdf2 then used[reg.pdf2:lower()] = true end
  end
  local set = {}
  for _, p in ipairs(P.pdfs) do
    if not used[p:lower()] and not Util.same_path(p, S.pdf_path) and not (R.part2 and Util.same_path(p, R.part2.s.pdf_path)) then
      set[p] = true
    end
  end
  local n = 0
  for _ in pairs(set) do n = n + 1 end
  R.unused_cache = { ver = R.lib_ver, regs = R.regions, P = P, open = S.pdf_path, open2 = open2, set = set, n = n }
  return set, n
end

-- "Remove unused PDFs": off the library; a copy in this project's PDFs folder is deleted too
-- (an original file outside the project is never deleted).
function Project.remove_unused()
  local n, deleted = 0, 0
  local dir = Project.dir() and Project.pdf_dir()
  local list = {}
  for p in pairs(Project.unused_pdfs()) do list[#list + 1] = p end
  for _, p in ipairs(list) do
    Project.remove_from_library(p); n = n + 1
    if dir and Util.same_path(Util.dir_of(p), dir) and Util.file_exists(p) and os.remove(p) then deleted = deleted + 1 end
  end
  R.unused_cache = nil
  Msg.notify(string.format("Removed %d unused PDF(s) from the library%s.", n,
    deleted > 0 and string.format("; %d copy(ies) deleted from the project's PDFs folder", deleted) or ""), false, "library")
end

-- Takes a PDF off the library (the file is not deleted); its region choices are cleared.
function Project.remove_from_library(path)
  for i, p in ipairs(P.pdfs) do
    if Util.same_path(p, path) then table.remove(P.pdfs, i); break end
  end
  for key, p in pairs(P.assign) do if Util.same_path(p, path) then P.assign[key] = nil end end
  if Util.same_path(P.active_pdf, path) then P.active_pdf = "" end
  P.rel[path] = nil; P.view[path] = nil
  R.libpages[path] = nil; R.libexists[path] = nil
  Project.resolve_regions(); Util.mark_pdirty()
end

-- "Remove from library": asks first (inline, in the PDF's row), with the number of region choices.
function UI.ask_remove_pdf(path)
  local n = 0
  for _, p in pairs(P.assign) do if Util.same_path(p, path) then n = n + 1 end end
  UI.ask("lib_remove", n > 0 and string.format("Remove this PDF from the library? %d region assignment(s) will be cleared. "
    .. "The file is not deleted.", n) or "Remove this PDF from the library? The file is not deleted.",
    "Yes, remove", function() Project.remove_from_library(path) end, path)
end

-- PDF 2 of a song: a path (chosen by hand) or nil (removed: also stops an automatic pair).
function Project.set_pdf2(reg, path)
  local key = reg.key
  P.names[key] = reg.name
  if path then P.assign2[key], P.no2[key] = path, nil
  else P.assign2[key], P.no2[key] = nil, true; R.add2[key] = nil end
  Project.resolve_regions(); Util.mark_pdirty()
  if R.cur_region_key == key then R.cur_region_key = nil end -- the song on screen: show the change now
end

-- Returns true if added, false if it was already in the library.
function Project.add_to_library(path, defer_resolve)
  for _, p in ipairs(P.pdfs) do if Util.same_path(p, path) then return false end end
  P.pdfs[#P.pdfs + 1] = path
  P.rel[path] = Util.rel_path(path, Project.dir())
  if not defer_resolve then Project.resolve_regions() end
  Util.mark_pdirty()
  return true
end

function PDF.browse_add_pdf(open_after)
  local ok, f = r.GetUserFileNameForRead("", "Select a PDF", "pdf")
  if ok and f and f ~= "" then
    Project.import_pdf(f, { open = open_after })
  end
end

---------------------------------------------------------------------------
-- COPY PDFs INTO THE PROJECT (<project folder>\PDFs), non-blocking
--
-- Each import is a job in R.copyq. One job runs at a time and copies a few hundred KB per frame,
-- so REAPER and playback never freeze. The file is written to "<name>.pdf.part" and renamed when
-- complete. The source PDF is only read, never changed or moved.
---------------------------------------------------------------------------

-- true when the folder exists and has a file or a subfolder (REAPER has no plain folder check)
function Util.dir_exists(dir)
  return r.EnumerateFiles(dir, 0) ~= nil or r.EnumerateSubdirectories(dir, 0) ~= nil
end

function Project.pdf_dir()
  local d = Project.dir()
  return d and (d .. SEP .. CFG.PDF_SUBDIR) or nil
end

-- true if `path` should be copied: copy mode on, project saved, PDF not already in the project folder
function Project.should_copy(path)
  local d = Project.dir()
  return S.import_copy and d ~= nil and Util.rel_path(path, d) == nil
end

-- Adds a PDF to the library. Copies it into the project first when copy mode is on.
-- opts: open (open when done), region_key (assign to that region when done),
--       remap_from (replace that library entry when done). Returns "queued", true or false.
function Project.import_pdf(src, opts)
  opts = opts or {}
  if not Project.should_copy(src) then
    local added
    if opts.remap_from then Project.remap_pdf(opts.remap_from, src); added = true
    else added = Project.add_to_library(src) end
    if opts.region_key then
      local reg = Project.region_by_key(opts.region_key)
      if reg then Project.assign_region_pdf(reg, src) end
    elseif opts.open then PDF.open_pdf(src, false) end
    return added
  end
  local dst = Project.pdf_dir() .. SEP .. Util.name_of(src)
  for _, j in ipairs(R.copyq) do if Util.same_path(j.dst, dst) then return false end end
  if R.copy and Util.same_path(R.copy.dst, dst) then return false end
  R.copyq[#R.copyq + 1] = { src = src, dst = dst, opts = opts }
  return "queued"
end

function Project.import_for_region(reg, src)
  if Project.should_copy(src) then
    Project.import_pdf(src, { region_key = reg.key })
    R.warn = string.format('Copying "%s" into the project for region "%s"...', Util.name_of(src), reg.name)
  else
    Project.assign_region_pdf(reg, src)
  end
end

-- Library PDFs that are outside the project folder and exist on disk.
-- use_cache: use the existence flags of the Library tab (refreshed every 2 s) instead of
-- opening every file. The Library tab calls this often (every 0.5 s), so it must not touch the disk.
function Project.external_pdfs(use_cache)
  local t, d = {}, Project.dir()
  if not d then return t end
  for _, p in ipairs(P.pdfs) do
    if Util.rel_path(p, d) == nil then
      local exists
      if use_cache then exists = (R.libexists[p] ~= false) else exists = Util.file_exists(p) end
      if exists then t[#t + 1] = p end
    end
  end
  return t
end

function Project.copy_all_into_project()
  local n = 0
  for _, p in ipairs(Project.external_pdfs()) do
    if Project.import_pdf(p, { remap_from = p }) == "queued" then n = n + 1 end
  end
  Msg.notify(string.format("Copying %d PDF(s) into the project folder...", n), false, "library")
end

function Project.copy_pending() return (R.copy and 1 or 0) + #R.copyq end

-- Called when a job is complete; `final` is the path to use (the copy, or the original on failure).
function Project.finish_copy(job, final)
  local o = job.opts
  if o.remap_from then Project.remap_pdf(o.remap_from, final)
  else Project.add_to_library(final, true) end
  Project.resolve_regions(); Util.mark_pdirty(); R.libexists_t = 0
  if o.region_key then
    local reg = Project.region_by_key(o.region_key)
    if reg then Project.assign_region_pdf(reg, final) end
  elseif o.open then
    PDF.open_pdf(final, false)
  end
  -- the region under the play cursor may now be assigned to this PDF: re-evaluate it
  local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
  if reg and reg.pdf and Util.same_path(reg.pdf, final) and not Util.same_path(final, S.pdf_path) then
    R.cur_region_key = nil
  end
  if Project.copy_pending() == 0 and not o.region_key then
    Msg.notify("PDF copy into the project folder is complete.", false, "library")
  end
end

function Project.close_copy(job, remove_part)
  if job.fin then job.fin:close(); job.fin = nil end
  if job.fout then job.fout:close(); job.fout = nil end
  if remove_part and job.part then os.remove(job.part) end
end

-- Cancels every pending and running copy (project change, script exit). Partial files are removed.
function Project.cancel_copies()
  if R.copy then Project.close_copy(R.copy, true) end
  R.copy = nil; R.copyq = {}
end

function Project.files_identical(a, b)
  if Util.file_size(a) ~= Util.file_size(b) then return false end
  return PDF.content_key(a) == PDF.content_key(b)
end

-- Starts the next job. Returns false if the job finished at once (identical / skipped / error).
function Project.start_copy(job)
  if Util.same_path(job.src, job.dst) then Project.finish_copy(job, job.dst); return false end
  if not Util.file_exists(job.src) then
    Msg.notify("Source PDF not found: " .. job.src, true, "library"); return false
  end
  Util.ensure_dir(Util.dir_of(job.dst))
  local sync = job.opts and job.opts.sync and R.sync
  if Util.file_exists(job.dst) then
    if Project.files_identical(job.src, job.dst) then
      if sync then sync.same = sync.same + 1 end
      Project.finish_copy(job, job.dst); return false -- same file already in the project
    end
    if sync then -- "Sync folders": the newer file replaces the copy (safely, see copy_tick)
      sync.updated = sync.updated + 1
      job.replace, job.reopen = true, true
    end
  elseif sync then
    sync.new = sync.new + 1
  end
  if Util.file_exists(job.dst) and not job.replace then
    local ans = r.ShowMessageBox(string.format(
      "A different file with the same name is already in the project folder:\n%s\n\n"
      .. "Yes = replace it with:\n%s\n\nNo = keep the existing copy and use it\n\nCancel = skip this PDF",
      job.dst, job.src), CFG.TITLE, 3)
    if ans == 7 then Project.finish_copy(job, job.dst); return false end -- keep existing
    if ans ~= 6 then return false end                                    -- skip
    job.replace = true
  end
  job.part = job.dst .. ".part"
  job.fin = io.open(job.src, "rb")
  job.fout = job.fin and io.open(job.part, "wb")
  if not (job.fin and job.fout) then
    Project.close_copy(job, true)
    Msg.notify("Cannot copy into the project folder; the original PDF is used: " .. job.src, true, "library", true)
    Project.finish_copy(job, job.src)
    return false
  end
  R.copy = job
  return true
end

function Project.copy_tick()
  Project.sync_done()
  if not R.copy then
    while #R.copyq > 0 do
      local job = table.remove(R.copyq, 1)
      if Project.start_copy(job) then break end
    end
    if not R.copy then return end
  end
  local job = R.copy
  local deadline = Util.now() + CFG.COPY_FRAME_BUDGET
  while Util.now() < deadline do
    local d = job.fin:read(CFG.COPY_CHUNK)
    if not d then
      Project.close_copy(job, false)
      R.copy = nil
      -- replace safely: the old file becomes a backup first, and is deleted only after the new file
      -- is in place; if that fails, the backup is put back (the old file is never lost)
      local bak = job.replace and (job.dst .. ".chartcue-old") or nil
      if bak then
        os.remove(bak) -- a backup left by an earlier, interrupted replacement
        if not os.rename(job.dst, bak) then
          os.remove(job.part)
          Msg.notify("Could not replace the PDF in the project folder (is it open in another program?); "
            .. "the original PDF is used: " .. job.src, true, "library")
          Project.finish_copy(job, job.src)
          return
        end
      end
      local ok = os.rename(job.part, job.dst)
      if ok then
        if bak then os.remove(bak) end
        Project.finish_copy(job, job.dst)
        if job.reopen then -- a synced PDF changed: the new pages (and the cue page check) at once
          R.libpages[job.dst] = nil
          if Util.same_path(S.pdf_path, job.dst) then R.replace_check = job.dst; PDF.open_pdf(job.dst, true) end
          if R.part2 and Util.same_path(R.part2.s.pdf_path, job.dst) then Pane.part2(PDF.open_pdf, job.dst, true) end
        end
      else
        if bak then os.rename(bak, job.dst) end -- put the old file back
        os.remove(job.part)
        Msg.notify("Could not finish the copy (is the file in use?); the original PDF is used: "
          .. job.src, true, "library")
        Project.finish_copy(job, job.src)
      end
      return
    end
    if not job.fout:write(d) then
      Project.close_copy(job, true); R.copy = nil
      Msg.notify("Copy failed (disk full?); the original PDF is used: " .. job.src, true, "library")
      Project.finish_copy(job, job.src)
      return
    end
  end
end

function PDF.browse_exe()
  local ok, f = r.GetUserFileNameForRead("", "Select pdftoppm.exe", "exe")
  if ok and f and f ~= "" then
    S.pdftoppm_path = f; Util.mark_dirty()
    R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo()
    if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  end
end

---------------------------------------------------------------------------
-- REGION EMPTY STATE HELPERS (clear the display / assign a PDF to a region)
---------------------------------------------------------------------------
-- Clears the page on screen and stops rendering for the previous PDF. The previous PDF is
-- remembered so it can be restored if the user turns region switching off.
function Project.clear_pdf_display()
  if R.total > 0 and S.pdf_path ~= "" then R.stash_pdf = S.pdf_path end
  PDF.reset_state()
  R.cache_dir, R.prefix, R.pdf_name = nil, nil, ""
  R.abs_target = nil
  R.max_x, R.max_y = 0, 0; R.autoscroll_active = false
  S.scroll_y, S.scroll_x = 0, 0
end

function Project.restore_stash()
  local p = R.stash_pdf
  R.stash_pdf = nil; R.cleared_key = nil
  if p and p ~= "" and R.total == 0 and Util.file_exists(p) then PDF.open_pdf(p, true) end
end

-- The one place that changes a region's PDF choice.
-- choice: "auto" (match by name), "ignore", or a PDF path (manual assignment).
function Project.set_region_choice(reg, choice)
  P.names[reg.key] = reg.name
  if choice == "auto" then P.assign[reg.key] = nil; P.ignore[reg.key] = nil
  elseif choice == "ignore" then P.assign[reg.key] = nil; P.ignore[reg.key] = true
  else P.assign[reg.key] = choice; P.ignore[reg.key] = nil end
  Project.resolve_regions(); Util.mark_pdirty()
end

-- Assign `path` to region `reg` (adding it to the library), re-run matching and open it now.
function Project.assign_region_pdf(reg, path)
  Project.add_to_library(path, true)
  Project.set_region_choice(reg, path)
  R.stash_pdf = nil; R.cleared_key = nil; R.choose_existing = false
  R.warn = nil
  if Util.file_exists(path) then
    PDF.open_pdf(path, false)
  else
    R.warn = string.format('PDF for region "%s" is missing: %s', reg.name, path)
  end
  Util.mark_dirty()
end

-- Ignoring a region means "no PDF here": the previous PDF is NOT kept on screen. The region shows
-- its empty state (with options to add a PDF or stop ignoring).
function Project.ignore_region(reg)
  Project.set_region_choice(reg, "ignore")
  R.choose_existing = false
  if R.total > 0 then Project.clear_pdf_display() end
  R.cleared_key = reg.key
end

function Project.unignore_region(reg)
  Project.set_region_choice(reg, "auto")
  R.choose_existing = false
  R.cur_region_key = nil -- re-trigger region entry: opens its PDF if matched, else shows the empty state
end

---------------------------------------------------------------------------
-- IMAGES (textures)
---------------------------------------------------------------------------
function PDF.png_size(path)
  local f = io.open(path, "rb"); if not f then return nil end
  local h = f:read(24); f:close()
  if not h or #h < 24 or h:sub(2, 4) ~= "PNG" then return nil end
  local w, hh = string.unpack(">I4I4", h, 17)
  return w, hh
end

function PDF.get_page_image(p)
  if R.total == 0 then return nil end
  -- A texture already in memory stays usable even if its file was removed from the cache.
  local e = R.images[p]
  if e then
    if r.ImGui_ValidatePtr(e.img, "ImGui_Image*") then return e.img, e.w, e.h end
    -- stale handle: drop it and load the page again from the cache file
    Msg.diag("Image for page " .. p .. " failed validation; reloading.")
    R.images[p] = nil
    for i, q in ipairs(R.image_order) do if q == p then table.remove(R.image_order, i); break end end
  end
  if not PDF.page_ready(p) then return nil end
  local path = PDF.find_page_file(p)
  if not path then
    Msg.set_error("Missing cached image for page " .. p .. "; re-rendering.")
    R.bstate[PDF.batch_of(p)] = nil; R.page_paths[p] = nil
    return nil
  end
  local w, h = PDF.png_size(path)
  local too_big = w and (w > CFG.MAX_IMAGE_DIM or h > CFG.MAX_IMAGE_DIM)
  local ok, img
  if not too_big then ok, img = pcall(r.ImGui_CreateImage, path) end
  if too_big or not ok or not img or not w then
    local msg = tostring(img)
    if not R.scale_to and (too_big or msg:lower():find("big", 1, true)) and S.pdf_path ~= "" then
      R.force_scale = true
      PDF.open_pdf(S.pdf_path, true)
      return nil
    end
    Msg.set_error("Failed to load image for page " .. p .. ": " .. msg
      .. (R.scale_to and " (already scaled to max size; try a lower DPI)" or ""))
    return nil
  end
  r.ImGui_Attach(R.ctx, img)
  R.images[p] = { img = img, w = w, h = h }
  table.insert(R.image_order, p)
  while #R.image_order > CFG.MAX_CACHED_TEXTURES + ((Nav.two_pages() or Nav.continuous()) and 3 or 0) do
    local old = table.remove(R.image_order, 1)
    PDF.release_image(R.images[old])
    R.images[old] = nil
  end
  return img, w, h
end

---------------------------------------------------------------------------
-- NAVIGATION / SCROLL LOGIC
---------------------------------------------------------------------------
function Util.playing()
  local st = r.GetPlayState()
  return ((st & 1) ~= 0 or (st & 4) ~= 0) and (st & 2) == 0
end

-- The ONE autoscroll mode state: "off" | "marker" | "cues"
-- Saved per project (P.scroll_mode). A project without one uses the default in settings.ini.
-- "fixed" (Fixed speed, removed before 1.0) can still be saved in older projects: it means "off".
function Nav.scroll_mode()
  local m = (P.scroll_mode ~= "") and P.scroll_mode or S.scroll_mode
  if m == "marker" or m == "cues" then return m end
  return "off"
end

-- Writes only to the project; the settings.ini default does not change.
function Nav.set_scroll_mode(m)
  P.scroll_mode = m
  R.mpage_last = nil
  if m ~= "cues" then R.rec = false end -- recording needs the Cue list mode
  Util.mark_pdirty()
end

-- A region without a PDF blocks page turns, unless its last page is kept on screen (R.kept_key).
function Nav.page_blocked()
  return R.empty_region ~= nil and R.kept_key ~= R.empty_region.key
end

function Nav.go_page(p)
  if R.total == 0 or Nav.page_blocked() then return end
  p = Util.clamp(p, 1, R.total)
  if p == S.page then return end
  -- by 2 pages (book): a page of the pair on screen is already visible: only the number changes
  -- (no flash, no move), e.g. a page turn to page 2 while pages 1-2 show
  if not Nav.changes_view(p) then S.page = p; Util.mark_dirty(); return end
  -- "Page turn motion: Smooth" to the next page: a visual offset that fades out in UI.draw_view
  -- (the page and scroll values change at once). 1 page / continuous: the next page slides up from
  -- below (at most one view height); side by side by 1 page: the pages slide one place to the left.
  R.cont_off, R.side_off = nil, nil
  if S.cont_turn == "smooth" and p == S.page + 1 then
    if Nav.two_pages() then
      if S.page_turn ~= "book" and (R.side_step or 0) > 0 then R.side_off, R.turn_t = R.side_step, Util.now() end
    elseif Nav.cont_step() > 0 then
      R.cont_off, R.turn_t = -math.min(Nav.cont_step() - S.scroll_y, math.max(1, R.view_h)), Util.now()
    end
  end
  S.page = p; S.scroll_y = 0; S.scroll_x = 0; R.abs_target = nil
  if Util.playing() then R.flash_t = Util.now() end -- page-turn flash
  Util.mark_dirty()
end

-- "Pages on screen" (Settings > Display): "side" = 2 pages side by side, one spread;
-- "stack" = continuous: the pages are one long strip, S.page is the page at the top of the view and
-- S.scroll_y the position on it (the same values as with 1 page, so cues and markers do not change).
function Nav.two_pages() return S.page_layout == "side" and R.total > 1 and not R.part2 end
function Nav.continuous() return S.page_layout == "stack" and R.total > 1 and not R.part2 end
-- Continuous: one step = a page height + the gap, in screen px (set by UI.draw_view)
function Nav.cont_step() return R.cont_step or 0 end

-- The pages on screen: first, second (nil with 1 page, or after the last page).
-- Rolling: S.page and the next one. Book: the pair 1-2, 3-4 ... that contains S.page.
function Nav.spread()
  if not Nav.two_pages() then return S.page, nil end
  local first = (S.page_turn == "book") and (S.page - (S.page + 1) % 2) or S.page
  return first, (first + 1 <= R.total) and (first + 1) or nil
end

-- Size of the spread in page-image pixels (one page: w, h). The gap is 2% of the page width.
function Nav.content_dims(w, h)
  if not Nav.two_pages() then return w, h end
  return w * 2 + math.floor(w * 0.02 + 0.5), h
end

-- false when page p is already on screen in the pair of S.page (side by side, by 2 pages).
function Nav.changes_view(p)
  if not (Nav.two_pages() and S.page_turn == "book") then return true end
  return (p - (p + 1) % 2) ~= (S.page - (S.page + 1) % 2)
end

-- Next / previous page (keys, toolbar, actions, MIDI): by 2 in Book mode, else by 1.
function Nav.step(dir)
  if Nav.two_pages() and S.page_turn == "book" then
    local first = Nav.spread()
    local to = first + 2 * dir
    if to >= 1 and to <= R.total then Nav.go_page(to) end
  else
    Nav.go_page(S.page + dir)
  end
end

function Nav.scroll_by(dy)
  if Nav.continuous() and Nav.cont_step() > 0 then
    S.scroll_y = S.scroll_y + dy
    Nav.cont_normalize()
    R.abs_target = nil; Util.touch_override(); Util.mark_dirty()
    return
  end
  S.scroll_y = Util.clamp(S.scroll_y + dy, 0, R.max_y)
  R.abs_target = nil; Util.touch_override(); Util.mark_dirty()
end

-- Continuous: past the bottom of a page the next page becomes the top one (and back), so the
-- scroll goes on without a jump; the first and the last page stop it.
function Nav.cont_normalize()
  local step = Nav.cont_step()
  if step <= 0 then return end
  while S.scroll_y >= step and S.page < R.total do S.page = S.page + 1; S.scroll_y = S.scroll_y - step end
  while S.scroll_y < 0 and S.page > 1 do S.page = S.page - 1; S.scroll_y = S.scroll_y + step end
  S.scroll_y = Util.clamp(S.scroll_y, 0, (S.page < R.total) and step or R.max_y)
end

function Midi.decode_relative(v)
  local d
  local e = S.rel_encoding
  if e == 1 then d = (v < 64) and v or (v - 128)          -- two's complement
  elseif e == 2 then d = v - 64                            -- binary offset
  elseif e == 3 then d = (v < 64) and v or -(v - 64)       -- sign magnitude
  else d = (v > 64 and 1) or (v < 64 and -1) or 0 end      -- direction only
  if S.rel_invert then d = -d end
  return d
end

-- source: "direct MIDI input" or "action-bound MIDI CC"; cc is nil when unknown
function Midi.handle_scroll_value(v, source, cc)
  v = Util.clamp(math.floor(v), 0, 127)
  R.last_cc = v
  Util.touch_override()
  R.dbg.cc, R.dbg.val, R.dbg.src = cc, v, source
  if S.mode == "absolute" then
    R.abs_target = (v / 127) * R.max_y
    R.dbg.decoded = string.format("absolute target %.0f px (%.0f%%)", R.abs_target, v / 127 * 100)
  else
    local d = Midi.decode_relative(v)
    S.scroll_y = Util.clamp(S.scroll_y + d * S.sensitivity, 0, R.max_y)
    R.abs_target = nil
    R.dbg.decoded = string.format("relative %+d tick(s): %s", d, d > 0 and "down" or (d < 0 and "up" or "no movement"))
  end
  Util.mark_dirty()
end

function Midi.handle_page_cc(cc, v)
  if not S.midi_page_turn then return end
  if Nav.page_blocked() or R.total == 0 then return end -- no PDF for this region (and no kept page)
  local prev = R.page_cc_state[cc] or 0
  R.page_cc_state[cc] = v
  if v >= 64 and prev < 64 then
    if cc == S.cc_page_next then Nav.step(1)
    elseif cc == S.cc_page_prev then Nav.step(-1) end
  end
end

function Midi.poll_forwarded_midi()
  local q = r.GetExtState(CFG.EXT, "midi_q")
  if q ~= "" then
    r.SetExtState(CFG.EXT, "midi_q", "", false)
    for n in q:gmatch("(%-?%d+),") do Midi.handle_scroll_value(tonumber(n), "action-bound MIDI CC", nil) end
  end
  -- commands from the small action scripts ("Chart Cue - Next page.lua" etc.). They work when the
  -- Chart Cue window has no focus (keyboard shortcuts, foot pedals, OSC) and, like MIDI, also in lock mode.
  local cq = r.GetExtState(CFG.EXT, "cmd_q")
  if cq ~= "" then
    r.SetExtState(CFG.EXT, "cmd_q", "", false)
    for c in cq:gmatch("(%a+),") do
      if c == "next" then Nav.step(1)
      elseif c == "prev" then Nav.step(-1)
      elseif c == "perf" then UI.toggle_perf() end
    end
  end
  if r.GetExtState(CFG.EXT, "quit") == "1" then
    r.SetExtState(CFG.EXT, "quit", "", false); R.quit = true
  end
end

function Midi.poll_direct_midi()
  if not S.direct_midi or not r.MIDI_GetRecentInputEvent then return end
  local events, idx, newest = {}, 0, nil
  while idx < 256 do
    local seq, buf = r.MIDI_GetRecentInputEvent(idx)
    if not seq or seq == 0 then break end
    if seq <= R.last_midi_seq then break end
    newest = newest or seq
    events[#events + 1] = buf
    idx = idx + 1
  end
  if newest then R.last_midi_seq = newest end
  local cc = (S.mode == "absolute") and S.cc_abs or S.cc_rel
  for i = #events, 1, -1 do
    local b = events[i]
    if #b >= 3 then
      local st, d1, d2 = b:byte(1), b:byte(2), b:byte(3)
      if (st & 0xF0) == 0xB0 then
        if d1 == cc then Midi.handle_scroll_value(d2, "direct MIDI input", d1) end
        if d1 == S.cc_page_next or d1 == S.cc_page_prev then Midi.handle_page_cc(d1, d2) end
        if S.midi_add_cue and (d1 == S.cc_add_cue or d1 == S.cc_add_scroll) then
          local st_key = (d1 == S.cc_add_cue) and "cue_turn" or "cue_scroll"
          local prev = R.page_cc_state[st_key] or 0
          R.page_cc_state[st_key] = d2
          if d2 >= 64 and prev < 64 and UI.can_record() then
            if st_key == "cue_turn" then Cues.add_page_turn() else Cues.add_scroll_point() end
          end
        end
      end
    end
  end
end

-- Page / scroll from time points. Used by the Markers mode (PDFPAGE / PDFSCROLL markers) and by
-- the Cue list mode (page_pts / scroll_pts built from the cue list).
function Nav.timeline_tick(is_play, overriding, page_pts, scroll_pts)
  page_pts, scroll_pts = page_pts or R.page_pts, scroll_pts or R.scroll_pts
  R.autoscroll_active = false
  if not is_play then return end
  local pos = r.GetPlayPosition()
  local reg = R.active_region
  local lo, hi = -math.huge, math.huge
  -- inside a region, its markers / cues work from the region start to the region end
  if reg then
    lo, hi = reg.start, reg.stop
    if pos >= hi or pos < lo then return end
  end

  -- find the page segment containing pos
  local seg_lo, seg_hi, page = lo, hi, nil
  -- "Turn pages early" (P.turn_early beats): a page turn counts as reached that many beats before
  -- its time, so you can read ahead. The new page starts at the top until its scroll points come.
  local pos_page = pos
  if P.turn_early > 0 then pos_page = r.TimeMap2_QNToTime(0, r.TimeMap2_timeToQN(0, pos) + P.turn_early) end
  for _, pp in ipairs(page_pts) do
    if pp.t >= lo and pp.t < hi then
      if pp.t <= pos_page then page = pp.page; seg_lo = pp.t
      else seg_hi = math.min(seg_hi, pp.t); break end
    end
  end
  if page == nil and reg then page = 1 end
  if page ~= R.mpage_last then
    R.mpage_last = page
    if page and page <= R.total and page ~= S.page then Nav.go_page(page) end
  end

  -- interpolate scroll percentage between PDFSCROLL markers inside the segment
  local prev, nxt
  local lower = math.max(seg_lo, lo)
  for _, sp in ipairs(scroll_pts) do
    if sp.t >= lower and sp.t < seg_hi then
      if sp.t <= pos then prev = sp else nxt = sp; break end
    end
  end
  local pct = 0
  if prev then
    if nxt and not P.scroll_jump then pct = prev.pct + (nxt.pct - prev.pct) * (pos - prev.t) / (nxt.t - prev.t)
    else pct = prev.pct end
  end
  -- Jump mode: a new scroll point that moves the page gives the page-turn flash
  -- (R.jump_prev == false: playback just started, no flash for the first point)
  if P.scroll_jump and prev ~= R.jump_prev then
    -- (the new page of a page turn is already at the top: a scroll point there does not flash again,
    -- also when "Turn pages" turned the page a little earlier)
    local cur = (R.max_y > 0) and (S.scroll_y / R.max_y * 100) or 0
    if R.jump_prev ~= false and prev and not overriding and math.abs(prev.pct - cur) > 0.5 then
      R.flash_t = Util.now()
    end
    R.jump_prev = prev
  end
  if not overriding then
    R.autoscroll_active = true
    S.scroll_y = Util.clamp(pct / 100 * R.max_y, 0, R.max_y)
  end
end

function Nav.update_motion()
  local overriding = Util.now() < R.override_until
  if R.abs_target then
    local diff = R.abs_target - S.scroll_y
    if math.abs(diff) < 0.5 then S.scroll_y = R.abs_target; R.abs_target = nil
    else S.scroll_y = S.scroll_y + diff * CFG.ABS_SMOOTHING end
  end
  local is_play = Util.playing()
  if is_play and not R.was_playing then R.mpage_last = nil; R.jump_prev = false end
  R.was_playing = is_play
  R.autoscroll_active = false
  local mode = Nav.scroll_mode()
  -- no PDF for the current region: every autoscroll mode is disabled
  if R.empty_region or R.total == 0 then mode = "off" end
  if R.in_part2 and mode == "marker" then mode = "off" end -- markers belong to PDF 1; PDF 2 follows its cues
  if mode == "marker" then
    Nav.timeline_tick(is_play, overriding)
  elseif mode == "cues" then
    if is_play then
      local pp, sp = Cues.points(Cues.playing_region())
      Nav.timeline_tick(is_play, overriding, pp, sp)
    else
      R.autoscroll_active = false
    end
  end
  -- continuous: the scroll may go on into the next page (Nav.cont_normalize turns it into the next page)
  local top = (Nav.continuous() and S.page < R.total and Nav.cont_step() > 0) and Nav.cont_step() or R.max_y
  S.scroll_y = Util.clamp(S.scroll_y, 0, top)
  S.scroll_x = Util.clamp(S.scroll_x, 0, R.max_x)
end

---------------------------------------------------------------------------
-- REGION TRACKING / PROJECT SWITCHING
---------------------------------------------------------------------------
function Project.time_pos()
  if Util.playing() then return r.GetPlayPosition() end
  return r.GetCursorPosition()
end

function Project.region_at(pos)
  local best
  for _, reg in ipairs(R.regions) do
    if pos >= reg.start and pos < reg.stop then
      if not best or reg.start >= best.start then best = reg end
    end
  end
  return best
end

function Project.on_enter_region(reg)
  R.warn = nil
  R.cleared_key = nil
  R.choose_existing = false
  if not P.auto_switch then return end
  if reg.status == "auto" or reg.status == "assigned" then
    if not Util.file_exists(reg.pdf) then
      R.warn = string.format('PDF for region "%s" is missing: %s', reg.name, reg.pdf)
      return
    end
    R.stash_pdf = nil
    if R.total == 0 or not Util.same_path(reg.pdf, S.pdf_path) then
      PDF.open_pdf(reg.pdf, false)
    end
    S.page = 1; S.scroll_y = 0; S.scroll_x = 0; R.abs_target = nil
    R.active_region = reg
    R.mpage_last = nil
    UI.sync_part2(reg) -- the song's PDF 2, or none
    Util.mark_dirty()
  elseif S.keep_last_page and Util.playing() and R.total > 0 then
    UI.sync_part2(nil)
    -- no PDF here, but the show goes on: keep the last page on screen (a banner says why)
    R.kept_key = reg.key
    R.cleared_key = reg.key
  else
    -- unassigned, ambiguous or ignored: no PDF here, so do not keep showing the previous PDF
    UI.sync_part2(nil)
    Project.clear_pdf_display()
    R.cleared_key = reg.key
  end
end

function Project.region_tick()
  local reg = Project.region_at(Project.time_pos())
  local key = reg and reg.key or nil
  if key ~= R.cur_region_key then
    R.cur_region_key = key
    R.kept_key = nil
    if reg then Project.on_enter_region(reg) elseif R.part2 and P.auto_switch then UI.sync_part2(nil) end
  end
  -- playback starts in a region whose PDF is not on screen (another PDF was opened by hand): open it
  local playing = Util.playing()
  if playing and not R.rt_playing and reg and P.auto_switch and (reg.status == "auto" or reg.status == "assigned")
      and (not Util.same_path(reg.pdf, S.pdf_path) or not UI.part2_matches(reg)) then
    Project.on_enter_region(reg)
  end
  R.rt_playing = playing
  -- kept page: when playback stops (or the option is turned off), show the region's empty state
  if R.kept_key and (not Util.playing() or not S.keep_last_page) then
    R.kept_key = nil
    if reg and R.cleared_key == reg.key then Project.clear_pdf_display() end
  end
  -- the region we showed an empty state for just got a PDF (e.g. added to the library): load it
  if reg and R.cleared_key == reg.key and (reg.status == "auto" or reg.status == "assigned") then
    Project.on_enter_region(reg)
  end
  -- empty state flag for this frame
  if reg and P.auto_switch
      and (reg.status == "unassigned" or reg.status == "ambiguous" or reg.status == "ignored") then
    R.empty_region = reg
  else
    R.empty_region = nil
  end
end

-- Content fingerprint of a project: tracks (count, first / last GUID), markers, regions, length.
-- "Save as" keeps it; opening another project in the same tab changes it.
function Project.fingerprint(proj)
  if not Project.valid_proj(proj) then return "" end
  local nt = r.CountTracks(proj)
  local g1 = nt > 0 and r.GetTrackGUID(r.GetTrack(proj, 0)) or ""
  local g2 = nt > 0 and r.GetTrackGUID(r.GetTrack(proj, nt - 1)) or ""
  local _, nm, nr = r.CountProjectMarkers(proj)
  return string.format("%d|%s|%s|%d|%d|%.3f", nt, g1, g2, nm or 0, nr or 0, r.GetProjectLength(proj))
end

function Project.check_project(force)
  local proj, fn = r.EnumProjects(-1)
  fn = fn or ""
  if not force and proj == R.proj and fn == R.projfn then return end

  -- Did the project we were showing close, or was it replaced in the same tab?
  --   closed:   its project tab was closed (the pointer is no longer valid)
  --   replaced: same tab, but File > Close / New project ("" file name) or File > Open project.
  --             "Save as" (or a first save) keeps both the content fingerprint and the Chart Cue
  --             data; anything else is another project, and the in-memory config never moves to it.
  local closed, replaced = false, false
  if R.proj ~= nil and not force then
    if not Project.valid_proj(R.proj) then
      closed = true
    elseif proj == R.proj and fn ~= R.projfn then
      if fn == "" then
        replaced = true
      else
        local n, txt = r.GetProjExtState(proj, CFG.PEXT, CFG.PEXT_KEY)
        if not (n and n > 0) then txt = "" end
        replaced = (txt ~= (R.plast_txt or "")) or (Project.fingerprint(proj) ~= R.proj_fp)
      end
    end
  end
  if (closed or replaced) and S.close_with_project then
    Msg.diag(closed and "Project tab closed; closing Chart Cue." or "Project replaced; closing Chart Cue.")
    R.proj = nil   -- never write the old config into the next project
    R.quit = true
    return
  end
  if replaced then R.proj = nil end -- option off: load the new project's config, do not save the old one
  if not force and proj == R.proj then
    -- same project, new file name (first save or "Save as"): the config is already in the
    -- project, so keep it in memory; only the file name changes.
    R.projfn = fn
    R.psaveable = (fn ~= "")
    R.proj_fp = Project.fingerprint(proj)
    Project.resolve_paths()
    Project.save_project_cfg()
    R.pdirty = false
    return
  end
  if R.proj ~= nil then Project.save_project_cfg() end -- flush into the project we are leaving
  R.proj, R.projfn = proj, fn
  R.psaveable = (fn ~= "")
  R.proj_fp = Project.fingerprint(proj)
  local src
  P, src = Project.load_project_cfg(proj)
  R.plast_txt = (src == "rpp") and Project.serialize_cfg() or nil
  Project.resolve_paths() -- find PDFs relative to the (possibly moved) project folder
  R.cur_region_key = nil; R.active_region = nil
  R.mpage_last = nil; R.warn = nil; R.import = nil; R.ask = nil
  if R.part2 then UI.close_part2() end -- part 2 belongs to the project we left
  R.empty_region = nil; R.stash_pdf = nil; R.cleared_key = nil; R.choose_existing = false
  Project.cancel_copies() -- pending copies belong to the project we left
  Project.scan_project()
  R.state_cc = r.GetProjectStateChangeCount(0)
  if P.active_pdf ~= "" and Util.file_exists(P.active_pdf) then
    if not Util.same_path(P.active_pdf, S.pdf_path) or R.total == 0 then PDF.open_pdf(P.active_pdf, true) end
  elseif R.total == 0 and S.pdf_path ~= "" and Util.file_exists(S.pdf_path) then
    PDF.open_pdf(S.pdf_path, true)
  end
end

function Project.project_tick()
  Project.check_project(false)
  local cc = r.GetProjectStateChangeCount(0)
  if cc ~= R.state_cc then
    R.state_cc = cc; R.scan_due = R.scan_due or (Util.now() + CFG.MARKER_RESCAN_DELAY)
    R.proj_fp = Project.fingerprint(R.proj) -- kept current, so a later file-name change can be judged
  end
  if R.scan_due and Util.now() >= R.scan_due then R.scan_due = nil; Project.scan_project() end
  if R.pdirty and Util.now() - R.plast > 1.5 then
    if Project.save_project_cfg() then R.pdirty = false end
    R.plast = Util.now()
  end
end

---------------------------------------------------------------------------
-- DIRECTORY HELPERS / CACHE MANAGEMENT
---------------------------------------------------------------------------
function Util.refresh_dir(d) r.EnumerateFiles(d, -1); r.EnumerateSubdirectories(d, -1) end

function Util.list_files(d)
  Util.refresh_dir(d)
  local t, i = {}, 0
  while true do local f = r.EnumerateFiles(d, i); if not f then break end; t[#t + 1] = f; i = i + 1 end
  return t
end

function Util.list_subdirs(d)
  Util.refresh_dir(d)
  local t, i = {}, 0
  while true do local f = r.EnumerateSubdirectories(d, i); if not f then break end; t[#t + 1] = f; i = i + 1 end
  return t
end

-- Cache size, calculated over several frames (CFG.IMPORT_FRAME_BUDGET per frame): R.size_job.
function Util.start_dir_size(root, depth)
  R.size_job = { dirs = { { d = root, depth = depth } }, files = nil, fi = 0, cur = nil, total = 0 }
end

function Util.dir_size_tick()
  local j = R.size_job
  if not j then return end
  local deadline = Util.now() + CFG.IMPORT_FRAME_BUDGET
  while Util.now() < deadline do
    if not j.files then
      local e = table.remove(j.dirs)
      if not e then R.cache_size, R.size_job = j.total, nil; return end
      j.cur, j.files, j.fi = e.d, Util.list_files(e.d), 0
      if e.depth > 0 then
        for _, sd in ipairs(Util.list_subdirs(e.d)) do j.dirs[#j.dirs + 1] = { d = e.d .. SEP .. sd, depth = e.depth - 1 } end
      end
    else
      j.fi = j.fi + 1
      local f = j.files[j.fi]
      if f then j.total = j.total + Util.file_size(j.cur .. SEP .. f) else j.files = nil end
    end
  end
end

-- Deletes all `folders` with ONE cmd.exe (one .bat, started without waiting; the .bat deletes itself).
-- Only folders inside CFG.CACHE_ROOT are deleted.
function PDF.rmdir_all(folders)
  local lines = { "@echo off", "chcp 65001 >nul" }
  for _, path in ipairs(folders) do
    if path:sub(1, #CFG.CACHE_ROOT) == CFG.CACHE_ROOT and #path > #CFG.CACHE_ROOT + 1 then
      lines[#lines + 1] = string.format('rmdir /S /Q "%s"', PDF.bat_escape(path))
    end
  end
  if #lines == 2 then return end
  R.cache_clear_t = Util.now()
  R.clear_seq = R.clear_seq + 1
  local bat = CFG.TMP_DIR .. SEP .. "clear_" .. R.clear_seq .. ".bat"
  lines[#lines + 1] = string.format('del /F /Q "%s"', PDF.bat_escape(bat))
  local f = io.open(bat, "wb")
  if not f then return end
  f:write(table.concat(lines, "\r\n") .. "\r\n"); f:close()
  r.ExecProcess('cmd.exe /C "' .. bat .. '"', CFG.EXEC_NOWAIT)
end

function Util.fmt_bytes(n)
  if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
  return string.format("%.0f KB", n / 1024)
end

-- Clears the cache of the current PDF but never deletes the page currently on screen.
-- Only called by PDF.clear_all_cache, which first checks that no page batch is running.
function PDF.clear_current_cache()
  if not R.cache_dir then return end
  local keep = (R.total > 0) and PDF.find_page_file(S.page) or nil
  local parent = Util.dir_of(R.cache_dir)
  local folders = {}
  for _, sd in ipairs(Util.list_subdirs(parent)) do
    local full = parent .. SEP .. sd
    if full ~= R.cache_dir then folders[#folders + 1] = full end
  end
  PDF.rmdir_all(folders)
  for _, f in ipairs(Util.list_files(R.cache_dir)) do
    local full = R.cache_dir .. SEP .. f
    if full ~= keep then os.remove(full) end
  end
  R.bstate = {}; R.batches_done = 0; R.page_paths = {}
  R.cache_size = nil
end

-- Returns false (with a message) while a page batch is being prepared.
function PDF.clear_all_cache()
  if R.job then
    Msg.notify("Pages are being prepared. Try again in a moment.", true, "display"); return false
  end
  local current_parent = R.cache_dir and Util.dir_of(R.cache_dir) or nil
  local folders = {}
  for _, sd in ipairs(Util.list_subdirs(CFG.CACHE_ROOT)) do
    local full = CFG.CACHE_ROOT .. SEP .. sd
    if full ~= current_parent then folders[#folders + 1] = full end
  end
  PDF.rmdir_all(folders)
  if current_parent then PDF.clear_current_cache() end
  R.cache_size = nil
  return true
end

---------------------------------------------------------------------------
-- FOLDER PICKER (PowerShell FolderBrowserDialog, separate process) + INCREMENTAL IMPORT
--
-- The dialog runs in its own powershell.exe process, launched with "don't wait", so REAPER keeps
-- running (and playing) while it is open. PowerShell writes the chosen folder to a temporary UTF-8
-- file (never through the command line, so spaces / Unicode / apostrophes are safe) and then a
-- ".done" marker ("ok", "cancel" or "error: ..."). Chart Cue checks for the marker every 0.1 s.
---------------------------------------------------------------------------
local PS_PICKER_SCRIPT = [=[
$ErrorActionPreference = 'Stop'
$out  = Join-Path $PSScriptRoot 'folder_pick.txt'
$done = Join-Path $PSScriptRoot 'folder_pick.done'
$utf8 = New-Object System.Text.UTF8Encoding($false)
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $owner = New-Object System.Windows.Forms.Form
  $owner.TopMost = $true
  $owner.ShowInTaskbar = $false
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = 'Select a folder containing PDFs to add to the library'
  $dlg.ShowNewFolderButton = $false
  $result = $dlg.ShowDialog($owner)
  if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    [System.IO.File]::WriteAllText($out, $dlg.SelectedPath, $utf8)
    [System.IO.File]::WriteAllText($done, 'ok', $utf8)
  } else {
    [System.IO.File]::WriteAllText($done, 'cancel', $utf8)
  }
} catch {
  [System.IO.File]::WriteAllText($done, ('error: ' + $_.Exception.Message), $utf8)
}
]=]

-- One message system: a message shows for CFG.MSG_SECONDS in the status bar and, when it has a
-- source ("library", "regions", "cues", "display", "project", "general", "help"), also in that section of the UI.
-- sticky: the message stays until its "x" is clicked or another message replaces it
-- (use it for messages that ask the user to do something).
function Msg.notify(msg, is_err, source, sticky)
  R.msg = { text = msg, err = is_err and true or false, t = Util.now(), src = source, sticky = sticky or nil }
end

-- timed_only: ignore the sticky flag (the status bar has no "x", so it uses the time rule only)
function Msg.recent(source, timed_only)
  local m = R.msg
  local live = (m and m.sticky and not timed_only) or (m and Util.now() - m.t < CFG.MSG_SECONDS)
  if m and live and (source == nil or m.src == source) then return m end
  return nil
end

function Project.start_folder_pick()
  if R.picker or R.import then return end
  Util.ensure_dir(CFG.TMP_DIR)
  local ps1 = CFG.TMP_DIR .. SEP .. "pick_folder.ps1"
  local out_f = CFG.TMP_DIR .. SEP .. "folder_pick.txt"
  local done_f = CFG.TMP_DIR .. SEP .. "folder_pick.done"
  os.remove(out_f); os.remove(done_f)
  local f = io.open(ps1, "wb")
  if not f then Msg.notify("Cannot write the folder-picker script to " .. CFG.TMP_DIR, true, "library"); return end
  f:write((PS_PICKER_SCRIPT:gsub("\n", "\r\n"))); f:close()
  local res = r.ExecProcess('powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. ps1 .. '"',
    CFG.EXEC_NOWAIT)
  if res == nil then
    Msg.notify("Could not start PowerShell. Antivirus or a company policy can block it.", true, "library")
    return
  end
  R.picker = { started = Util.now(), out_f = out_f, done_f = done_f }
  R.msg = nil
end

-- sub: also the subfolders; sync: a "Sync folders" scan (changed copies are replaced, no questions)
function Project.begin_import(folder, sub, sync)
  if sub == nil then sub = S.include_subfolders end
  if not sync then Project.remember_folder(folder, sub) end
  R.import = {
    dirs = { folder }, cur = nil, phase = "files", fi = 0, si = 0,
    added = 0, skipped = 0, scanned = 0, recursive = sub, folder = folder, sync = sync,
  }
  R.msg = nil
end

-- "Add from folder" remembers the folder in the project (for "Sync folders").
function Project.remember_folder(dir, sub)
  for _, fo in ipairs(P.folders) do
    if Util.same_path(fo.path, dir) then
      if fo.sub ~= sub then fo.sub = sub; Util.mark_pdirty() end
      return
    end
  end
  P.folders[#P.folders + 1] = { path = dir, sub = sub }
  Util.mark_pdirty()
end

-- "Sync folders": the remembered folders are checked again, one after the other. New PDFs are added,
-- a changed PDF replaces its copy in the project (link mode: the library already uses the file).
-- PDFs that are no longer in a folder stay in the library. R.sync = the counts and the folders left.
function Project.sync_folders()
  if R.import or R.picker or R.sync then return end
  if #P.folders == 0 then Msg.notify("No folders to sync yet: use 'Add from folder' first.", false, "library"); return end
  R.sync = { new = 0, updated = 0, same = 0, missing = 0, left = {} }
  for i, fo in ipairs(P.folders) do R.sync.left[i] = fo end
  Project.sync_next()
end

function Project.sync_next()
  local s = R.sync
  while #s.left > 0 do
    local fo = table.remove(s.left, 1)
    if Util.dir_exists(fo.path) then Project.begin_import(fo.path, fo.sub, true); return end
    s.missing = s.missing + 1
  end
  s.scanned = true -- all folders scanned; the copies may still run (Project.sync_done)
end

-- Called by copy_tick: once the scans and their copies are done, the result message.
function Project.sync_done()
  local s = R.sync
  if not (s and s.scanned) or R.import or R.copy or #R.copyq > 0 then return end
  R.sync = nil
  Project.resolve_regions(); R.libexists_t = 0
  Msg.notify(string.format("Sync: %d new, %d updated, %d unchanged PDF(s)%s.", s.new, s.updated, s.same,
    s.missing > 0 and string.format("; %d folder(s) not found", s.missing) or ""), false, "library")
end

function Project.pick_tick()
  local pk = R.picker
  if not pk or not Util.poll_due(pk) then return end
  local d = Util.read_all(pk.done_f, 1024)
  if not d then
    if Util.now() - pk.started > CFG.PICKER_TIMEOUT_SEC then
      os.remove(pk.out_f); R.picker = nil
      Msg.notify("Folder selection timed out.", true, "library")
    end
    return
  end
  local out = Util.read_all(pk.out_f, 4096)
  os.remove(pk.done_f); os.remove(pk.out_f)
  R.picker = nil
  d = Util.trim(d)
  if d == "ok" and out then
    if out:sub(1, 3) == "\239\187\191" then out = out:sub(4) end -- strip UTF-8 BOM if present
    out = Util.trim((out:gsub("[\r\n]+", "")))
    if out ~= "" then
      if out:sub(-1) == ":" then out = out .. SEP end
      Project.begin_import(out)
      return
    end
  end
  if d:sub(1, 5) == "error" then Msg.notify("Folder dialog failed: " .. d, true, "library")
  else Msg.notify("Folder selection cancelled.", false, "library") end
end

function Project.finish_import()
  local im = R.import
  if not im then return end
  R.import = nil
  Project.resolve_regions() -- re-run region matching for the whole new library
  Util.mark_pdirty()
  R.libexists_t = 0
  if im.sync then Project.sync_next(); return end -- the next folder; the message comes at the end
  Msg.notify(string.format("Added %d PDF(s), skipped %d duplicate(s).", im.added, im.skipped), false, "library")
  -- If the play cursor sits in a region that just became assigned to a different PDF, trigger the switch.
  local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
  if reg and (reg.status == "auto" or reg.status == "assigned") and not Util.same_path(reg.pdf, S.pdf_path) then
    R.cur_region_key = nil
  end
end

function Project.import_tick()
  local im = R.import
  if not im then return end
  local deadline = Util.now() + CFG.IMPORT_FRAME_BUDGET
  while Util.now() < deadline do
    if not im.cur then
      im.cur = table.remove(im.dirs, 1)
      if not im.cur then Project.finish_import(); return end
      Util.refresh_dir(im.cur); im.fi = 0; im.si = 0; im.phase = "files"
    end
    if im.phase == "files" then
      local f = r.EnumerateFiles(im.cur, im.fi)
      if not f then
        im.phase = im.recursive and "subs" or "done"
      else
        im.fi = im.fi + 1; im.scanned = im.scanned + 1
        if f:lower():match("%.pdf$") then
          local res = Project.import_pdf(Util.join_path(im.cur, f), { sync = im.sync })
          if res then im.added = im.added + 1 else im.skipped = im.skipped + 1 end
          if im.sync and R.sync and res ~= "queued" then -- (copies are counted when they run)
            if res then R.sync.new = R.sync.new + 1 else R.sync.same = R.sync.same + 1 end
          end
        end
      end
    elseif im.phase == "subs" then
      local sd = r.EnumerateSubdirectories(im.cur, im.si)
      if not sd then im.phase = "done"
      else im.si = im.si + 1; im.dirs[#im.dirs + 1] = Util.join_path(im.cur, sd) end
    else
      im.cur = nil
    end
  end
end

---------------------------------------------------------------------------
-- CUE LIST: page / scroll changes per region, stored in the project data (not as markers).
-- A cue = { pos, page, scroll }. pos is measured from the region start (from the project start
-- for "_project"), in quarter-note beats or in seconds (P.cue_unit, chosen per project).
-- During playback the cues become time points for Nav.timeline_tick, exactly like the markers.
---------------------------------------------------------------------------

-- The cue list of a song: its region key (or "_project"). PDF 2 of a song has its own list,
-- key .. "#2": while code runs for part 2 (R.in_part2: playback, recording into the active part)
-- or while the Cues tab edits PDF 2 (R.cue_part_ctx == 2). The cue format is the same.
function Cues.key(reg)
  local k = reg and reg.key or "_project"
  local part = R.cue_part_ctx or (R.in_part2 and 2 or 1) -- the Cues tab chooses; else the part that runs
  if part == 2 then k = k .. "#2" end
  return k
end
-- The region of a cue list key ("<key>" or "<key>#2"); nil for "_project" or a deleted region.
function Cues.region_of_key(key)
  local base = key:gsub("#2$", "")
  if base == "_project" then return nil end
  return Project.region_by_key(base)
end
function Cues.origin(reg) return reg and reg.start or 0 end

-- region used for playback: the region of the open PDF, else the region under the play cursor
function Cues.playing_region()
  return R.active_region or Project.region_at(Project.time_pos())
end

function Cues.list(reg) return P.cues[Cues.key(reg)] or {} end

function Cues.to_time(reg, pos, unit)
  local o = Cues.origin(reg)
  if (unit or P.cue_unit) == "seconds" then return o + pos end
  return r.TimeMap2_QNToTime(0, r.TimeMap2_timeToQN(0, o) + pos)
end

function Cues.from_time(reg, t, unit)
  local o = Cues.origin(reg)
  if (unit or P.cue_unit) == "seconds" then return t - o end
  return r.TimeMap2_timeToQN(0, t) - r.TimeMap2_timeToQN(0, o)
end

function Cues.sort(list) table.sort(list, function(a, b) return a.pos < b.pos end) end

-- Text for the position column: "bar.beat.hundredths" (beats) or "m:ss.hh" from the region start.
function Cues.label(reg, pos)
  if P.cue_unit == "seconds" then
    local sgn = pos < 0 and "-" or ""
    pos = math.abs(pos)
    return string.format("%s%d:%05.2f", sgn, math.floor(pos / 60), pos % 60)
  end
  return r.format_timestr_pos(Cues.to_time(reg, pos), "", 2)
end

function Cues.parse_label(reg, text)
  text = Util.trim(text or "")
  if text == "" then return nil end
  if P.cue_unit == "seconds" then
    local m, sec = text:match("^(%d+):(%d+%.?%d*)$")
    if m then return tonumber(m) * 60 + tonumber(sec) end
    return tonumber(text)
  end
  if not text:match("^[%d%.]+$") then return nil end
  return Cues.from_time(reg, r.parse_timestr_pos(text, 2))
end

-- Time points for playback (cached until the cues, the project or the tempo change).
-- A page point is added only when the page changes, so the scroll moves smoothly between cues.
function Cues.points(reg)
  local key = Cues.key(reg)
  local c = R.cue_cache
  if c and c.P == P and c.key == key and c.ver == R.lib_ver and c.cc == R.state_cc and c.start == Cues.origin(reg) then
    return c.pp, c.sp
  end
  local pp, sp, last_page = {}, {}, nil
  for _, cue in ipairs(Cues.list(reg)) do
    local t = Cues.to_time(reg, cue.pos)
    if cue.page and cue.page ~= last_page then pp[#pp + 1] = { t = t, page = cue.page }; last_page = cue.page end
    if cue.scroll then sp[#sp + 1] = { t = t, pct = cue.scroll } end
  end
  R.cue_cache = { P = P, key = key, ver = R.lib_ver, cc = R.state_cc, start = Cues.origin(reg), pp = pp, sp = sp }
  return pp, sp
end

-- Adds (or replaces) a cue at a position. Returns the cue.
function Cues.put(reg, pos, page, scroll)
  local key = Cues.key(reg)
  P.cues[key] = P.cues[key] or {}
  local list = P.cues[key]
  for _, c in ipairs(list) do
    if math.abs(c.pos - pos) < CFG.CUE_SAME_POS then
      c.page, c.scroll = page or c.page, scroll or c.scroll
      Util.mark_pdirty(); return c
    end
  end
  local c = { pos = pos, page = page, scroll = scroll }
  list[#list + 1] = c
  Cues.sort(list); Util.mark_pdirty()
  return c
end

-- Highest page of the PDF that a region uses (nil if unknown: then no check).
function Cues.max_page(reg)
  local two = (R.cue_part_ctx or (R.in_part2 and 2 or 1)) == 2 -- the cues of PDF 2: checked against PDF 2
  local pdf = (reg and (two and reg.pdf2 or reg.pdf)) or S.pdf_path
  if not pdf or pdf == "" then return nil end
  if Util.same_path(pdf, S.pdf_path) and R.total > 0 then return R.total end
  local n = R.libpages[pdf]
  if type(n) == "number" then return n end
  n = PDF.read_info_cache(pdf)
  if n then R.libpages[pdf] = n; Util.bump_lib() end -- read the cache file only once
  return n
end

-- Page of the last cue before `pos` that has a page (nil if none).
function Cues.page_before(list, pos)
  local pg
  for _, c in ipairs(list) do
    if c.pos < pos - CFG.CUE_SAME_POS then
      if c.page then pg = c.page end
    else break end
  end
  return pg
end

-- Common start for both recording actions. Returns ok, reg, list, pos.
-- The keys and MIDI buttons call the recording actions only in Cue list mode.
function Cues.record_start()
  if R.total == 0 then Msg.notify("Open a PDF first, then add cues.", true, "cues"); return false end
  local t = Project.time_pos()
  local reg = Project.region_at(t)
  local key = Cues.key(reg)
  P.cues[key] = P.cues[key] or {}
  local pos = math.floor(Cues.from_time(reg, t) * 1000 + 0.5) / 1000
  if R.cue_edit_key ~= "_all" then R.cue_edit_key = nil end -- the editor shows this song
  return true, reg, P.cues[key], pos
end

-- "Add page turn" (C key, MIDI): the page after the cue before it (first page turn = page 2),
-- at the top of the page. Following cues are renumbered when the new page would repeat.
function Cues.add_page_turn()
  local ok, reg, list, pos = Cues.record_start()
  if not ok then return end
  local page = (Cues.page_before(list, pos) or 1) + 1
  local maxp = Cues.max_page(reg)
  if maxp and page > maxp then
    Msg.notify(string.format("No page turn added: this PDF has only %d page(s).", maxp), true, "cues"); return
  end
  Cues.save_undo()
  local replacing = false
  for _, c in ipairs(list) do if math.abs(c.pos - pos) < CFG.CUE_SAME_POS then replacing = true end end
  if not replacing then
    local clash = false
    for _, c in ipairs(list) do if c.pos > pos and c.page == page then clash = true end end
    if clash then -- renumber the following page cues (5 -> 6, 6 -> 7 ...)
      for _, c in ipairs(list) do
        if c.pos > pos and c.page then c.page = maxp and math.min(c.page + 1, maxp) or (c.page + 1) end
      end
    end
  end
  Cues.put(reg, pos, page, 0)
  if not Util.playing() then Nav.go_page(page) end
  Msg.notify(string.format("Page turn added at %s: page %d%s.", Cues.label(reg, pos), page,
    reg and (' in "' .. reg.name .. '"') or ""), false, "cues")
end

-- "Add scroll point" (S key, MIDI): the page of the cue before it, with the current scroll position.
function Cues.add_scroll_point()
  local ok, reg, list, pos = Cues.record_start()
  if not ok then return end
  local page = Cues.page_before(list, pos) or S.page
  local scroll = Cues.view_scroll()
  Cues.save_undo()
  Cues.put(reg, pos, page, scroll)
  Msg.notify(string.format("Scroll point added at %s: page %d, scroll %d%%%s.", Cues.label(reg, pos), page,
    math.floor(scroll + 0.5), reg and (' in "' .. reg.name .. '"') or ""), false, "cues")
end
-- Removes all cues of one song (key), or of all songs (key == "_all").
function Cues.remove_all(key)
  Cues.save_undo()
  if key == "_all" then P.cues = {} else P.cues[key] = nil end
  Util.mark_pdirty()
end

function Cues.remove(reg, index)
  local list = P.cues[Cues.key(reg)]
  if list and list[index] then Cues.save_undo(); table.remove(list, index); Util.mark_pdirty() end
  if list and #list == 0 then P.cues[Cues.key(reg)] = nil end
end

-- Undo for cue changes (Chart Cue's own: REAPER's undo does not cover the project data).
-- A copy of all cues before each change; up to CFG.CUE_UNDO_MAX steps, for the current project only.
function Cues.copy()
  local t = {}
  for key, list in pairs(P.cues) do
    local l = {}
    for i, c in ipairs(list) do l[i] = { pos = c.pos, page = c.page, scroll = c.scroll } end
    t[key] = l
  end
  return t
end

function Cues.save_undo(snap)
  if not R.cue_undo or R.cue_undo.P ~= P then R.cue_undo = { P = P } end
  local u = R.cue_undo
  u[#u + 1] = snap or Cues.copy()
  if #u > CFG.CUE_UNDO_MAX then table.remove(u, 1) end
  if not R.cue_redo_keep then R.cue_redo = nil end -- a new change: the undone steps cannot come back
end

function Cues.can_redo() return R.cue_redo ~= nil and R.cue_redo.P == P and #R.cue_redo > 0 end

-- Redo (Ctrl+Shift+Z): the change that Undo took back.
function Cues.redo()
  if not Cues.can_redo() then Msg.notify("Nothing to redo in the cue list.", false, "cues"); return end
  R.cue_redo_keep = true; Cues.save_undo(); R.cue_redo_keep = nil
  P.cues = table.remove(R.cue_redo)
  R.cue_err, R.cue_text = {}, {}
  Util.mark_pdirty()
  Msg.notify("Cue change redone.", false, "cues")
end

function Cues.can_undo() return R.cue_undo ~= nil and R.cue_undo.P == P and #R.cue_undo > 0 end

function Cues.undo()
  if not Cues.can_undo() then Msg.notify("Nothing to undo in the cue list.", false, "cues"); return end
  if not R.cue_redo or R.cue_redo.P ~= P then R.cue_redo = { P = P } end
  R.cue_redo[#R.cue_redo + 1] = Cues.copy() -- for Redo
  P.cues = table.remove(R.cue_undo)
  R.cue_err, R.cue_text = {}, {}
  Util.mark_pdirty()
  Msg.notify("Cue change undone.", false, "cues")
end

-- Current scroll position of the view, in percent (0.1 steps), like "Add scroll point".
function Cues.view_scroll()
  return (R.max_y > 0) and (math.floor(S.scroll_y / R.max_y * 1000 + 0.5) / 10) or 0
end

-- "Use current view": the cue gets the page and the scroll position shown now.
function Cues.use_view(c)
  if R.total == 0 then Msg.notify("Open a PDF first.", true, "cues"); return end
  Cues.save_undo()
  c.page, c.scroll = S.page, Cues.view_scroll()
  Util.mark_pdirty()
end

local CUE_START_POINT = { pos = 0, page = 1, scroll = 0 }
-- "+" on a row (i = 0: the Start row): a scroll point after cue i, halfway to the next cue (1 bar / 2 s after the last one).
-- Page of cue i; scroll from the view when it shows that page, else a copy of cue i's scroll.
function Cues.add_below(reg, list, i)
  local c, nxt = list[i] or CUE_START_POINT, list[i + 1] -- i = 0: the Start row
  local step = (P.cue_unit == "seconds") and 2 or 4
  local pos = nxt and (c.pos + nxt.pos) / 2 or (c.pos + step)
  pos = math.floor(pos * 1000 + 0.5) / 1000
  if nxt and math.abs(nxt.pos - pos) < CFG.CUE_SAME_POS or math.abs(c.pos - pos) < CFG.CUE_SAME_POS then
    Msg.notify("No room between these two cues.", true, "cues"); return
  end
  local page = c.page or Cues.page_before(list, c.pos + 2 * CFG.CUE_SAME_POS) or S.page
  local scroll = (R.total > 0 and S.page == page) and Cues.view_scroll() or c.scroll or 0
  Cues.save_undo()
  Cues.put(reg, pos, page, scroll)
  R.cue_err, R.cue_text = {}, {}
  Msg.notify(string.format("Scroll point added at %s: page %d, scroll %d%%.", Cues.label(reg, pos), page,
    math.floor(scroll + 0.5)), false, "cues")
end

-- Switch beats <-> seconds for this project; every cue keeps its time in the project.
function Cues.set_unit(unit)
  if unit == P.cue_unit then return end
  R.cue_undo, R.cue_redo = nil, nil -- the saved steps are in the old unit
  local old = P.cue_unit
  for key, list in pairs(P.cues) do
    local reg = Cues.region_of_key(key) -- (also the "#2" lists of PDF 2)
    if key:gsub("#2$", "") == "_project" or reg then
      for _, c in ipairs(list) do
        c.pos = Cues.from_time(reg, Cues.to_time(reg, c.pos, old), unit)
      end
    end
  end
  P.cue_unit = unit
  Util.mark_pdirty()
end

-- "Copy markers into cues" (Cues tab > More actions, toolbar menu): all songs, or one song `reg`.
-- One undo step; the result is a message.
function Cues.copy_markers(all, reg)
  Cues.save_undo()
  local n = 0
  if all then
    for _, rg in ipairs(R.regions) do n = n + Cues.convert_markers(rg) end
    if #R.regions == 0 then n = Cues.convert_markers(nil) end
  else
    n = Cues.convert_markers(reg)
  end
  if n > 0 then
    Msg.notify(string.format("%d cue(s) made from markers. You can now remove the PDF markers.", n), false, "cues")
  else
    Msg.notify("No PDFPAGE or PDFSCROLL markers found.", false, "cues")
  end
end

-- Copies the PDFPAGE / PDFSCROLL markers inside a region (or the whole project) into its cue list.
-- The markers are not changed. Returns the number of cues created or updated.
function Cues.convert_markers(reg)
  local lo, hi = -math.huge, math.huge
  if reg then lo, hi = reg.start, reg.stop end
  local at = {}
  local function slot(t)
    for _, a in ipairs(at) do if math.abs(a.t - t) < 0.001 then return a end end
    local a = { t = t }; at[#at + 1] = a; return a
  end
  for _, pp in ipairs(R.page_pts) do if pp.t >= lo and pp.t < hi then slot(pp.t).page = pp.page end end
  for _, sp in ipairs(R.scroll_pts) do if sp.t >= lo and sp.t < hi then slot(sp.t).scroll = sp.pct end end
  for _, a in ipairs(at) do
    local pos = math.floor(Cues.from_time(reg, a.t) * 1000 + 0.5) / 1000
    -- a page marker alone starts the page at the top (same rule as the Markers mode)
    Cues.put(reg, pos, a.page, a.scroll or (a.page and 0) or nil)
  end
  return #at
end

---------------------------------------------------------------------------
-- PANES (parts of the page area): each pane shows its own PDF page, with its own page, scroll,
-- zoom, page images and render jobs. Pane 1 IS the global state (S / R), so all existing code works
-- unchanged. Another pane keeps its values in its own table; Pane.swap(p) exchanges them with the
-- globals, the code then runs for that pane, and Pane.swap(p) again puts everything back.
-- Shared values (project, regions, markers, settings, messages, counters) are never swapped.
-- (Used from the next step, 2 PDFs per region; today only the tests use Pane.new and Pane.run.)
---------------------------------------------------------------------------
Pane.R_FIELDS = { "total", "cache_dir", "prefix", "scale_to", "force_scale", "bstate", "job", "batches_done",
  "page_paths", "images", "image_order", "max_x", "max_y", "view_w", "view_h", "last_ratio", "abs_target",
  "override_until", "pdf_name", "info_job", "page_w_pt", "marks_cache", "mpage_last", "autoscroll_active",
  "jump_prev", "flash_t", "active_region", "cont_off", "side_off", "turn_t", "side_step", "cont_step", "cue_cache" }
Pane.S_FIELDS = { "pdf_path", "page", "zoom", "fit_mode", "scroll_y", "scroll_x" }

-- A new pane with nothing open (the same start values as R and S).
function Pane.new()
  return {
    r = { total = 0, bstate = {}, batches_done = 0, page_paths = {}, images = {}, image_order = {},
      max_x = 0, max_y = 0, view_w = 0, view_h = 0, override_until = 0, pdf_name = "", force_scale = false,
      autoscroll_active = false, flash_t = 0 },
    s = { pdf_path = "", page = 1, zoom = 1.0, fit_mode = "width", scroll_y = 0, scroll_x = 0 },
  }
end

-- Runs fn(...) as part 2 (R.part2: the 2nd PDF on screen), with R.in_part2 set, so the code can
-- skip what belongs to part 1 only (the project's PDF, region empty states, markers). Without part 2: nothing.
function Pane.part2(fn, ...)
  if not R.part2 then return end
  R.in_part2 = true
  local ok, a, b, c = pcall(Pane.run, R.part2, fn, ...)
  R.in_part2 = false
  if not ok then error(a, 0) end
  return a, b, c
end

-- Runs fn(...) in the active part (R.active_part): keys, toolbar, menus, MIDI and actions act on it.
function Pane.active(fn, ...)
  if R.part2 and R.active_part == 2 then return Pane.part2(fn, ...) end
  return fn(...)
end

-- Exchanges the pane's values with the global ones (call it twice: in, then out).
function Pane.swap(p)
  for _, k in ipairs(Pane.R_FIELDS) do R[k], p.r[k] = p.r[k], R[k] end
  for _, k in ipairs(Pane.S_FIELDS) do S[k], p.s[k] = p.s[k], S[k] end
end

-- Runs fn(...) with pane p as the global state; the globals are restored also after an error.
-- (at most 3 results: enough for every caller; no table is made, so it is cheap every frame)
function Pane.run(p, fn, ...)
  Pane.swap(p)
  local ok, a, b, c = pcall(fn, ...)
  Pane.swap(p)
  if not ok then error(a, 0) end
  return a, b, c
end

---------------------------------------------------------------------------
-- UI HELPERS
---------------------------------------------------------------------------
local ImGui = {}
setmetatable(ImGui, { __index = function(_, k) return r["ImGui_" .. k] end }) -- plain passthrough
-- EndCombo also draws the selected text of a UI.combo whose list was open (R.combo_text)
function ImGui.EndCombo(ctx)
  r.ImGui_EndCombo(ctx)
  local c = R.combo_text
  if c then
    R.combo_text = nil
    r.ImGui_DrawList_AddText(r.ImGui_GetWindowDrawList(ctx), c.x, c.y, COL.TEXT_MAIN, c.txt)
  end
end

-- Buttons: zero vertical padding + a per-button text alignment, so the label sits exactly
-- CFG.TEXT_LIFT px above centre on a whole pixel, whatever the button height.
function UI.button(ctx, label, w, h)
  if not h or h <= 0 then h = r.ImGui_GetFrameHeight(ctx) end
  local fs = r.ImGui_GetFontSize(ctx)
  local free = h - fs
  local ay = 0.5
  -- + 2 px: without it ImGui draws a button label about 2 px above the centre and above its row
  -- label (UI.text_y). Measured on screenshots: + 2 is the closest to the exact centre
  -- (+ 3 is 2 px low, + 1 is 2 px high). + 0.25: ImGui floors free * ay (5/12 * 12 = 4.999)
  if free > 0 then ay = Util.clamp((math.floor(free / 2) - CFG.TEXT_LIFT + 2.25) / free, 0, 1) end
  local px = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
  r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), px, 0)
  r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ButtonTextAlign(), 0.5, ay)
  local hit = r.ImGui_Button(ctx, label, w or 0, h)
  r.ImGui_PopStyleVar(ctx, 2) -- always paired with the 2 pushes above
  return hit
end

local MODE_ITEMS = "Absolute (knob or fader)\0Relative (endless encoder)\0"
local REL_ITEMS = "Relative 1 - two's complement (1=+1, 127=-1)\0Relative 2 - binary offset (65=+1, 63=-1)\0Relative 3 - sign-magnitude (1=+1, 65=-1)\0Direction only (>64 down, <64 up)\0"
local SCROLL_ITEMS = "Off\0Markers\0Cue list\0"
local SCROLL_TOOLBAR_LABELS = { "Scroll: Off", "Scroll: Markers", "Scroll: Cue list" } -- same order as SCROLL_MODES
local MODE_LOCKED_TIP = "Stop playback to change the autoscroll mode."
local PAGE_LAYOUTS = { "single", "side", "stack" } -- "Pages on screen" (S.page_layout)
local PAGE_LAYOUT_LABELS = { "1 page", "2 pages, side by side", "Continuous (scroll through all pages)" }
local PAGE_LAYOUT_ITEMS = table.concat(PAGE_LAYOUT_LABELS, "\0") .. "\0"
local PAGE_LAYOUT_INDEX = { single = 0, side = 1, stack = 2 }
local PLAYING_TIP = "Not available during playback."
local AUTOSCROLL_TIP = "Autoscroll mode (saved in this project)\n"
  .. "Off: the page moves only when you scroll it.\n"
  .. "Markers: PDFPAGE and PDFSCROLL markers in the project turn and scroll the page.\n"
  .. "Cue list: the cues in the Cues tab turn and scroll the page."
local FIT_ITEMS = { { "width", "Fit width" }, { "height", "Fit height" }, { "page", "Fit page" }, { "100", "100%" } }
local SCROLL_MODES = { "off", "marker", "cues" }
local SORT_ITEMS = "Sort: Name\0Sort: Page count\0Sort: Recently added\0Sort: Unused first\0"
local TAB_NAMES = { "Library", "Regions", "Cues", "Settings" }
local TAB_REGIONS = 2
local TAB_CUES = 3
local TAB_FIRST_SETTING = 4      -- the Settings tab (Autoscroll, MIDI, Display, General sections)
local TAB_HELP = #TAB_NAMES + 1   -- the "?" button at the end of the tab strip

function Nav.effective_scale(iw, ih, view_w, view_h)
  iw, ih = Nav.content_dims(iw, ih) -- 2 pages: the fit modes fit the whole spread
  local fit_w = view_w / iw
  if S.fit_mode == "height" then return view_h / ih end
  if S.fit_mode == "page" then return math.min(fit_w, view_h / ih) end
  return fit_w * S.zoom
end

function Nav.set_zoom_from_scale(scale, iw, view_w)
  iw = Nav.content_dims(iw, 1)
  S.fit_mode = "manual"
  S.zoom = Util.clamp(scale / (view_w / iw), CFG.MIN_ZOOM, CFG.MAX_ZOOM)
  Util.mark_dirty(); Nav.remember_view()
end

-- Per-PDF zoom: stores the fit mode and zoom of the open PDF in the project.
function Nav.remember_view()
  if S.pdf_path == "" or R.total == 0 then return end
  local v = P.view[S.pdf_path]
  if v and v.fit == S.fit_mode and v.zoom == S.zoom then return end
  P.view[S.pdf_path] = { fit = S.fit_mode, zoom = S.zoom }
  Util.mark_pdirty()
end

function Nav.zoom_by(factor)
  local e = R.images[S.page]
  if not e then return end
  Nav.set_zoom_from_scale(Nav.effective_scale(e.w, e.h, R.view_w, R.view_h) * factor, e.w, R.view_w)
end
-- Screen scale for "100%" = the real page size (96 screen units per inch, as Windows uses).
-- If the page size is unknown (no pdfinfo.exe), 100% = one image pixel per screen pixel.
function Nav.actual_scale(iw)
  if not R.page_w_pt or R.page_w_pt <= 0 or not iw or iw <= 0 then return 1.0 end
  local render_dpi = iw / (R.page_w_pt / 72)  -- also correct when pages are capped (-scale-to)
  return CFG.SCREEN_DPI / render_dpi
end

-- Current zoom in percent of the real page size (all fit modes), or nil if no page is shown.
function Nav.zoom_pct()
  local e = R.images[S.page]
  if not e or R.view_w <= 0 then return nil end
  return Nav.effective_scale(e.w, e.h, R.view_w, R.view_h) / Nav.actual_scale(e.w) * 100
end

function Nav.zoom_100()
  local e = R.images[S.page]
  if e then Nav.set_zoom_from_scale(Nav.actual_scale(e.w), e.w, R.view_w) end
end
function Nav.fit_width() S.zoom = 1.0; S.fit_mode = "width"; S.scroll_x = 0; Util.mark_dirty(); Nav.remember_view() end
function Nav.fit_height() S.fit_mode = "height"; S.scroll_x = 0; S.scroll_y = 0; Util.mark_dirty(); Nav.remember_view() end
function Nav.fit_page() S.fit_mode = "page"; S.scroll_x = 0; S.scroll_y = 0; Util.mark_dirty(); Nav.remember_view() end

function Autostart.command_string()
  if cmd_id and cmd_id ~= 0 then
    local named = r.ReverseNamedCommandLookup(cmd_id)
    if named and named ~= "" then
      if named:sub(1, 1) ~= "_" then named = "_" .. named end
      return named
    end
    return tostring(cmd_id)
  end
  return nil
end

---------------------------------------------------------------------------
-- AUTOSTART: open Chart Cue for every project that contains Chart Cue data.
-- A small watcher (Data\Chart Cue\autostart.lua) is started from REAPER's __startup.lua.
-- Chart Cue adds ONE marked block at the END of __startup.lua (after a backup) and removes only
-- that block when the option is turned off. The user's own code is never changed.
---------------------------------------------------------------------------

local AUTOSTART_SCRIPT = [=[
-- Chart Cue autostart watcher (written by Chart Cue - do not edit, it is overwritten).
-- Opens Chart Cue when a project that contains Chart Cue data opens or becomes the active tab.
--   * waits 0.5 s after a project change, so a closing Chart Cue acts first
--   * then tries for up to 3 s until Chart Cue runs
--   * after a start it waits 3 s before it starts Chart Cue again (prevents a double start)
local r = reaper
local last_proj, last_fn = nil, nil
local next_t, wait_until, pending_until, cooldown_until = 0, 0, 0, 0
local function chart_cue_running()
  local hb = tonumber(r.GetExtState("ChartCue", "heartbeat"))
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
      local n = r.GetProjExtState(proj, "ChartCue", "cfg")
      if n and n > 0 then
        wait_until, pending_until = t + 0.5, t + 3.5
      else
        pending_until = 0
      end
    end
    if t < pending_until and t >= wait_until and t >= cooldown_until then
      if chart_cue_running() then
        pending_until = 0                       -- already open: nothing to do
      else
        local name = r.GetExtState("ChartCue", "cmd")
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

-- Reads __startup.lua only when asked to refresh (start-up, install, uninstall); cached otherwise.
function Autostart.installed(refresh)
  if refresh or R.as_installed == nil then
    local d = Util.read_all(CFG.STARTUP_FILE)
    R.as_installed = (d ~= nil and d:find(CFG.AS_BEGIN, 1, true) ~= nil)
  end
  return R.as_installed
end

function Autostart.write_script()
  Util.ensure_dir(CFG.BASE_DIR)
  local f = io.open(CFG.AUTOSTART_FILE, "wb")
  if not f then return false end
  f:write(AUTOSTART_SCRIPT); f:close()
  return true
end

function Autostart.install()
  -- the block is already in __startup.lua: never add a second one
  if Autostart.installed(true) then
    Msg.notify("Automatic open is already ON.", false, "project"); return
  end
  local ans = r.ShowMessageBox(
    "Chart Cue will add these 3 lines at the END of your REAPER startup script:\n\n"
    .. CFG.STARTUP_FILE .. "\n\n" .. CFG.AS_BLOCK .. "\n"
    .. "Your own code in that file is not changed. A backup is saved as __startup.lua.chartcue-backup.\n"
    .. "Restart REAPER once after this change.\n\nContinue?", CFG.TITLE, 1)
  if ans ~= 1 then return end
  if not Autostart.write_script() then
    Msg.notify("Cannot write " .. CFG.AUTOSTART_FILE, true, "project"); return
  end
  local old = Util.read_all(CFG.STARTUP_FILE)
  local backup = CFG.STARTUP_FILE .. ".chartcue-backup"
  if old and not (Util.copy_file(CFG.STARTUP_FILE, backup) and Util.read_all(backup) == old) then
    Msg.notify("Cannot write the backup " .. backup .. ". __startup.lua was not changed.", true, "project"); return
  end
  local f = io.open(CFG.STARTUP_FILE, "ab")
  if not f then Msg.notify("Cannot write " .. CFG.STARTUP_FILE, true, "project"); return end
  if old and old ~= "" and old:sub(-1) ~= "\n" then f:write("\n") end
  f:write("\n", CFG.AS_BLOCK); f:close()
  Autostart.installed(true)
  Msg.notify("Automatic open is ON. Restart REAPER once to start it.", false, "project", true)
end

function Autostart.uninstall()
  local d = Util.read_all(CFG.STARTUP_FILE)
  if not d then return end
  local a = d:find(CFG.AS_BEGIN, 1, true)
  local b = a and d:find(CFG.AS_END, a, true)
  if not (a and b) then return end
  local stop = b + #CFG.AS_END
  if d:sub(stop, stop) == "\n" then stop = stop + 1 end
  local start = a
  if start > 1 and d:sub(start - 1, start - 1) == "\n" then start = start - 1 end -- blank line we added
  local f = io.open(CFG.STARTUP_FILE, "wb")
  if not f then Msg.notify("Cannot write " .. CFG.STARTUP_FILE, true, "project"); return end
  f:write(d:sub(1, start - 1), d:sub(stop)); f:close()
  Autostart.installed(true)
  Msg.notify("Automatic open is OFF. It stops after the next REAPER restart.", false, "project", true)
end

function UI.pdf_items_string()
  local c = R.items_cache
  if c and c.ver == R.lib_ver and c.P == P then return c.str end
  local t = {}
  for _, p in ipairs(P.pdfs) do t[#t + 1] = Util.name_of(p) .. "\0" end
  R.items_cache = { ver = R.lib_ver, P = P, str = table.concat(t) }
  return R.items_cache.str
end

function UI.autoscroll_state_text()
  local mode = Nav.scroll_mode()
  if mode == "off" then return "Off" end
  local names = { marker = "Markers", cues = "Cue list" }
  -- words, not colour only: "moving" while the page is moved, "ready" while REAPER does not play
  return names[mode] .. (R.autoscroll_active and " (moving)" or " (ready)")
end

function UI.midi_in_use() return S.direct_midi or R.last_cc ~= nil end

function UI.region_counts()
  if R.counts_cache and R.counts_cache.frame == R.frames then return R.counts_cache end -- once per frame
  local c = { all = #R.regions, need = 0, assigned = 0, ignored = 0, frame = R.frames }
  for _, reg in ipairs(R.regions) do
    local s = reg.status
    if s == "unassigned" or s == "ambiguous" then c.need = c.need + 1
    elseif s == "auto" or s == "assigned" then c.assigned = c.assigned + 1
    elseif s == "ignored" then c.ignored = c.ignored + 1 end
  end
  R.counts_cache = c
  return c
end

function UI.attention_count() return UI.region_counts().need end

-- Truncate text with "..." so it fits in max_w pixels
function UI.trunc_text(ctx, s, max_w)
  if max_w < 20 then return "" end
  local w = ImGui.CalcTextSize(ctx, s)
  if w <= max_w then return s end
  local n = utf8.len(s) or #s
  n = math.max(1, math.floor(n * (max_w / w)))
  while n > 1 do
    local cut = (utf8.offset(s, n + 1) or (n + 1)) - 1
    local cand = s:sub(1, cut) .. "..."
    if (ImGui.CalcTextSize(ctx, cand)) <= max_w then return cand end
    n = n - 1
  end
  return "..."
end

-- Truncate from the START with "..." so the end of a path (the file name) stays visible.
function UI.trunc_left(ctx, s, max_w)
  if max_w < 20 then return "" end
  if (ImGui.CalcTextSize(ctx, s)) <= max_w then return s end
  local n = utf8.len(s) or #s
  for k = 2, n do
    local start = utf8.offset(s, k) or k
    local cand = "..." .. s:sub(start)
    if (ImGui.CalcTextSize(ctx, cand)) <= max_w then return cand end
  end
  return "..."
end

-- Fonts: normal, bold (tabs), larger bold (selected tab), big (empty states).
function UI.init_fonts(ctx)
  -- "sans-serif" is Segoe UI on Windows
  local function make(size, flags)
    local f = r.ImGui_CreateFont("sans-serif", size, flags)
    r.ImGui_Attach(ctx, f)
    return f
  end
  local bold = r.ImGui_FontFlags_Bold()
  R.ui_font = make(CFG.FONT_SIZE, 0)
  R.tab_font = make(CFG.FONT_SIZE_BOLD, bold)
  R.tab_font_big = make(CFG.FONT_SIZE_BOLD + 1, bold) -- the selected tab
  R.big_font = make(30, bold)
  R.label_font = make(CFG.FONT_SIZE, bold) -- row labels: bold, the same size as the normal text
end

-- A row label (the label column of the settings rows): bold. The last item is the label (for clicks).
function UI.label(ctx, text)
  UI.push_font(ctx, R.label_font)
  UI.row_text(ctx, text)
  UI.pop_font(ctx)
end
function UI.push_font(ctx, font) ImGui.PushFont(ctx, font) end
function UI.push_bold_font(ctx, larger) UI.push_font(ctx, larger and R.tab_font_big or R.tab_font) end
function UI.push_big_font(ctx) UI.push_font(ctx, R.big_font) end
function UI.pop_font(ctx) r.ImGui_PopFont(ctx) end

-- Panel layout helpers: one primary control per row, consistent label column, uniform buttons.
-- Round "?" icon. Hovering shows `text` in a wrapped tooltip.
function UI.help_icon(ctx, id, text)
  local d = CFG.HELP_ICON
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##help_" .. id, d, d)
  local hov = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy = x + d / 2, y + d / 2
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, d / 2, hov and COL.ACCENT_HOVER or COL.ACCENT)
  local tw, th = ImGui.CalcTextSize(ctx, "?")
  ImGui.DrawList_AddText(dl, cx - tw / 2, cy - th / 2, COL.WHITE, "?")
  if hov then
    if ImGui.BeginTooltip(ctx) then
      ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 32)
      ImGui.Text(ctx, text)
      ImGui.PopTextWrapPos(ctx)
      ImGui.EndTooltip(ctx)
    end
  end
end

-- The scope of a heading goes into its "?" text (not on screen, so the panel stays clean).
-- Built once per help text, not every frame.
local SCOPE_HELP = {
  project = { line = "Saved in this project.", memo = {} },
  computer = { line = "Saved on this computer (the same for all your projects).", memo = {} },
}

-- Section heading: bold, accent colour, full-width accent underline, optional "?" help on the right.
-- With `fold` (an id): an arrow before the title, and a click on the arrow or
-- the title opens / closes the section. Returns open (always true without `fold`) and clicked.
-- The closed sections are saved in S.folded (",id,id,"). `fold` can also be a boolean: then the
-- caller keeps the state (open = fold) and saves it itself (Settings tab: one section at a time).
-- big: the larger bold font, for the Settings tab sections (one level above the normal headings).
function UI.heading(ctx, text, help, scope, fold, big)
  local sc = scope and SCOPE_HELP[scope]
  if sc then
    local k = help or ""
    if not sc.memo[k] then sc.memo[k] = help and (help .. "\n\n" .. sc.line) or sc.line end
    help = sc.memo[k]
  end
  UI.vgap(ctx, UI.sp("TITLE_BEFORE"))
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, UI.panel_w(ctx) - 12)
  local open, clicked = true, false
  local ext = (type(fold) == "boolean") -- state kept by the caller
  if fold ~= nil then
    if ext then open = fold else open = not S.folded:find("," .. fold .. ",", 1, true) end
    local fh = ImGui.GetFrameHeight(ctx)
    clicked = ImGui.InvisibleButton(ctx, "##fold_" .. (ext and text or fold), 14, fh)
    local hov = ImGui.IsItemHovered(ctx)
    -- the arrow: pointing right when closed, down when open
    local dl, cx, cy = ImGui.GetWindowDrawList(ctx), sx + 6, sy + fh / 2
    local col = hov and COL.TEXT_MAIN or COL.HEADING
    if open then ImGui.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, col)
    else ImGui.DrawList_AddTriangleFilled(dl, cx - 2, cy - 4, cx - 2, cy + 4, cx + 3, cy, col) end
    ImGui.SameLine(ctx, 0, 2)
    UI.push_bold_font(ctx, big)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, text)
    UI.pop_font(ctx)
    clicked = clicked or ImGui.IsItemClicked(ctx)
    if hov or ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    if clicked then
      open = not open
      if not ext then
        S.folded = open and S.folded:gsub("," .. fold .. ",", ",") or (S.folded .. fold .. ",")
        if S.folded:sub(1, 1) ~= "," then S.folded = "," .. S.folded end
        Util.mark_dirty()
      end
    end
  else
    UI.push_bold_font(ctx, big)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, text)
    UI.pop_font(ctx)
  end
  local tx, ty = ImGui.GetItemRectMax(ctx)
  -- the title line's free space (between the title and the "?"), for UI.heading_msg
  local hr = R.heading_row or {}
  R.heading_row = hr
  hr.x0, hr.x1, hr.y = tx + 12, sx + full - (help and CFG.HELP_ICON + 8 or 0), sy
  if help then
    ImGui.SameLine(ctx)
    ImGui.SetCursorScreenPos(ctx, sx + full - CFG.HELP_ICON, sy)
    UI.help_icon(ctx, text, help)
    local _, hy = ImGui.GetItemRectMax(ctx)
    ty = math.max(ty, hy)
  end
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddLine(dl, sx, ty + 3, sx + full, ty + 3, COL.ACCENT, 1.5)
  ImGui.Dummy(ctx, 0, 3)                -- room for the underline
  UI.vgap(ctx, UI.sp("TITLE_AFTER"))
  return open, clicked
end

-- Space between sections (the heading underline replaces the old separator line).
function UI.group_sep(ctx)
  local g = UI.sp("SECTION")
  if g > 0 then ImGui.Dummy(ctx, 0, g) end
end

-- Text that wraps to the AVAILABLE content width (never a fixed pixel width), optionally coloured.
function UI.wrapped(ctx, text, col)
  local aw = ImGui.GetContentRegionAvail(ctx)
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + math.max(60, aw - 14))
  if col then ImGui.TextColored(ctx, col, text) else ImGui.Text(ctx, text) end
  ImGui.PopTextWrapPos(ctx)
end


-- List rows: every frame item (button, combo) is ROW_H tall; text uses UI.row_text.
-- Height of every control in the current row: the frame height (font + 2 x frame padding).
-- Buttons use it too, so buttons, fields, dropdowns and row text always have the same height.
function UI.h(ctx) return ImGui.GetFrameHeight(ctx) end

-- Frame padding that gives a frame height of CFG.ROW_H for the current font.
function UI.pad_y(ctx) return math.max(1, math.floor((CFG.ROW_H - ImGui.GetFontSize(ctx)) / 2)) end

function UI.push_row_style(ctx)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 8, UI.pad_y(ctx))
end
function UI.pop_row_style(ctx) ImGui.PopStyleVar(ctx, 1) end

-- Highlight for the "current" row (active PDF, current region): accent background + left bar.
function UI.row_highlight(ctx, aw)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local h = ImGui.GetFrameHeight(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, sx - 6, sy - 2, sx + aw - 10, sy + h + 2, COL.ACTIVE_BG, 4)
  ImGui.DrawList_AddRectFilled(dl, sx - 6, sy - 2, sx - 3, sy + h + 2, COL.ACCENT, 2)
end

-- Opens Explorer in the foreground with the file selected (or its folder if the file is missing).
function Util.show_in_explorer(path)
  if not path or path == "" then return end
  local exists = Util.file_exists(path)
  local dir = Util.dir_of(path)
  local args
  if exists then args = '/select,"' .. path .. '"'
  elseif dir then args = '"' .. dir .. '"'
  else return end
  r.ExecProcess('cmd.exe /C start "" explorer.exe ' .. args, CFG.EXEC_NOWAIT)
end

function Util.fmt_mmss(t)
  t = math.max(0, t or 0)
  return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
end

function UI.tip(ctx, text)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
end


function UI.fit_label()
  if S.fit_mode == "manual" then
    local pct = Nav.zoom_pct()
    return pct and string.format("%d%%", math.floor(pct + 0.5)) or "Zoom"
  end
  for _, f in ipairs(FIT_ITEMS) do if f[1] == S.fit_mode then return f[2] end end
  return "Fit"
end


-- One rule for all text in a row of controls (buttons, dropdowns, plain text, tabs):
-- text top = row top + floor((height - font) / 2) - CFG.TEXT_LIFT
function UI.text_y(ctx, top, h)
  h = h or ImGui.GetFrameHeight(ctx)
  return top + math.floor((h - ImGui.GetFontSize(ctx)) / 2) - CFG.TEXT_LIFT
end

-- Plain text in a row of buttons / fields: drawn at the shared text position, laid out as a
-- full-height item, so SameLine neighbours and the next row line up without cursor tricks.
function UI.row_text(ctx, text, col)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.Dummy(ctx, (ImGui.CalcTextSize(ctx, text)), ImGui.GetFrameHeight(ctx))
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, UI.text_y(ctx, y), col or COL.TEXT_MAIN, text)
end

-- Dropdown whose preview text uses the shared text position (UI.text_y). Returns true while open
-- (then call ImGui.EndCombo, exactly like BeginCombo).
function UI.combo(ctx, id, preview, w)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local h = ImGui.GetFrameHeight(ctx)
  local px = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
  local txt = UI.trunc_text(ctx, preview, w - h - 2 * px)
  local ty = UI.text_y(ctx, y)
  ImGui.SetNextItemWidth(ctx, w)
  local open = ImGui.BeginCombo(ctx, id, "") -- preview drawn below, on the window's draw list
  if open then
    -- the list window is current now (ReaImGui's draw list would draw into it): draw the text at
    -- EndCombo, back in the window of the dropdown (see ImGui.EndCombo below)
    R.combo_text = { x = x + px, y = ty, txt = txt }
  else
    ImGui.DrawList_AddText(dl, x + px, ty, COL.TEXT_MAIN, txt)
  end
  return open
end

-- Toolbar dropdowns: the width of the longest choice + the arrow (measured once, in the toolbar style).
function UI.tb_combo_w(ctx, kind)
  R.tb_combo_w = R.tb_combo_w or {}
  local w = R.tb_combo_w[kind]
  if w then return w end
  local labels = {}
  if kind == "fit" then
    for _, fi in ipairs(FIT_ITEMS) do labels[#labels + 1] = fi[2] end
    labels[#labels + 1] = "888%" -- a manual zoom shows its percentage
  else
    labels = SCROLL_TOOLBAR_LABELS
  end
  w = 0
  for _, l in ipairs(labels) do w = math.max(w, UI.btn_w(ctx, l, 0)) end
  w = w + UI.h(ctx) + 4 -- + the arrow button
  R.tb_combo_w[kind] = w
  return w
end

-- Toolbar items: { w = width, g = group, draw = function(ctx, w) }. Groups: 1 navigate,
-- 2 view (zoom), 3 playback. Whole groups are packed into rows that fit the window width,
-- with a divider line between groups, and every row is centred. The order never changes.
function UI.toolbar_items(ctx)
  local items = {}
  local g = 1
  local name_item -- the grey PDF name (it gives way first in a narrow window)
  local function add(w, draw) items[#items + 1] = { w = w, g = g, draw = draw } end
  local bw = CFG.TB_BTN_W
  if R.pdf_name ~= "" then
    local avail = (ImGui.GetContentRegionAvail(ctx)) - 12
    local nw = math.min((ImGui.CalcTextSize(ctx, R.pdf_name)), 220, math.max(40, avail))
    add(nw, function(_, w) UI.row_text(ctx, UI.trunc_text(ctx, R.pdf_name, w), COL.GREY); UI.tip(ctx, S.pdf_path) end)
    name_item = items[#items]
  end
  add(bw, function() if UI.icon_button(ctx, "##prev", bw, "prev") then Nav.step(-1) end
    UI.tip(ctx, "Previous page (Left arrow / Page Up)") end)
  local p1, p2 = Nav.spread()
  local ptxt = (R.total == 0) and "No PDF open"
    or (p2 and string.format("%d-%d / %d", p1, p2, R.total)) or string.format("%d / %d", p1, R.total)
  if R.total > 0 then
    -- "go to page": click the page number to type a page
    UI.push_font(ctx, R.label_font) -- the page number is bold (measured in that font)
    local pw = UI.btn_w(ctx, ptxt, 0)
    UI.pop_font(ctx)
    add(pw, function()
      if R.goto_edit then
        ImGui.SetNextItemWidth(ctx, pw)
        if not R.goto_focus then ImGui.SetKeyboardFocusHere(ctx); R.goto_focus = true end
        local enter
        enter, R.goto_text = ImGui.InputText(ctx, "##goto", R.goto_text,
          ImGui.InputTextFlags_EnterReturnsTrue() | ImGui.InputTextFlags_AutoSelectAll() | ImGui.InputTextFlags_CharsDecimal())
        if enter then
          local n = tonumber(R.goto_text)
          if n then Nav.go_page(math.floor(n)) end
          R.goto_edit = false
        elseif ImGui.IsItemDeactivated(ctx) then
          R.goto_edit = false -- Esc or click elsewhere
        end
      else
        UI.push_font(ctx, R.label_font)
        local go = UI.row_button(ctx, ptxt .. "##gotobtn", pw, "ghost")
        UI.pop_font(ctx)
        if go then R.goto_edit, R.goto_text, R.goto_focus = true, tostring(S.page), false end
        UI.tip(ctx, "Page. Click to go to a page.")
      end
    end)
  else
    add((ImGui.CalcTextSize(ctx, ptxt)), function() UI.row_text(ctx, ptxt) end)
  end
  add(bw, function() if UI.icon_button(ctx, "##next", bw, "next") then Nav.step(1) end
    UI.tip(ctx, "Next page (Right arrow / Page Down)") end)
  g = 2
  add(bw, function() if UI.icon_button(ctx, "##zoomout", bw, "minus") then Nav.zoom_by(1 / CFG.ZOOM_STEP) end
    UI.tip(ctx, "Zoom out (Ctrl and -, Ctrl + mouse wheel)") end)
  local fit_w = UI.tb_combo_w(ctx, "fit")
  add(fit_w, function()
    if UI.combo(ctx, "##fit", UI.fit_label(), fit_w) then
      for _, f in ipairs(FIT_ITEMS) do
        local sel = (f[1] == S.fit_mode)
        if f[1] == "100" then
          local pct = Nav.zoom_pct()
          sel = (S.fit_mode == "manual" and pct ~= nil and math.abs(pct - 100) < 0.5)
        end
        if ImGui.Selectable(ctx, f[2], sel) then
          if f[1] == "width" then Nav.fit_width()
          elseif f[1] == "height" then Nav.fit_height()
          elseif f[1] == "page" then Nav.fit_page()
          else Nav.zoom_100() end
        end
      end
      ImGui.EndCombo(ctx)
    end
    UI.tip(ctx, "Fit mode (Ctrl and 0: fit the page width). 100% = the real page size.")
  end)
  add(bw, function() if UI.icon_button(ctx, "##zoomin", bw, "plus") then Nav.zoom_by(CFG.ZOOM_STEP) end
    UI.tip(ctx, "Zoom in (Ctrl and +, Ctrl + mouse wheel)") end)
  g = 3
  -- autoscroll: during playback (full and small toolbar) the state as text, since the mode is locked
  -- then (the page would jump); when stopped, the dropdown
  if Util.playing() then
    local st = "Autoscroll: " .. UI.autoscroll_state_text()
    add((ImGui.CalcTextSize(ctx, st)), function()
      UI.row_text(ctx, st)
      UI.tip(ctx, MODE_LOCKED_TIP .. "\n\n" .. AUTOSCROLL_TIP)
    end)
  else
    local scroll_w = UI.tb_combo_w(ctx, "scroll")
    add(scroll_w, function()
      local labels = SCROLL_TOOLBAR_LABELS
      local cur = 1
      for i, m in ipairs(SCROLL_MODES) do if m == Nav.scroll_mode() then cur = i end end
      if UI.combo(ctx, "##scrollmode", labels[cur] or "", scroll_w) then
        for i, m in ipairs(SCROLL_MODES) do
          if ImGui.Selectable(ctx, labels[i], i == cur) then Nav.set_scroll_mode(m) end
        end
        ImGui.EndCombo(ctx)
      end
      UI.tip(ctx, AUTOSCROLL_TIP)
    end)
  end
  -- record cues: a square icon button, the same size as the lock button (only in the Cue list mode)
  if Nav.scroll_mode() == "cues" then add(bw, function()
    local nc, nv = UI.push_kind(ctx, R.rec and "danger" or nil)
    local hit = UI.button(ctx, "##rec", bw, 0)
    UI.pop_kind(ctx, nc, nv)
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1, y1 = ImGui.GetItemRectMax(ctx)
    UI.draw_rec_icon(ImGui.GetWindowDrawList(ctx), (x0 + x1) / 2, (y0 + y1) / 2, R.rec)
    if hit then UI.toggle_rec() end
    UI.tip(ctx, "Record cues (R): while on, the C and S keys and the MIDI cue buttons add cues.\n"
      .. "Only in the Cue list autoscroll mode. Lock mode blocks it during playback.")
  end) end
  -- lock: a square icon button, the same size as the other icon buttons
  add(bw, function()
    local nc, nv = UI.push_kind(ctx, R.lock and "primary" or nil)
    local hit = UI.button(ctx, "##lock", bw, 0)
    UI.pop_kind(ctx, nc, nv)
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1, y1 = ImGui.GetItemRectMax(ctx)
    UI.draw_lock_icon(ImGui.GetWindowDrawList(ctx), (x0 + x1) / 2, (y0 + y1) / 2, R.lock,
      R.lock and COL.WHITE or COL.TEXT_MAIN)
    if hit then UI.toggle_lock() end
    UI.tip(ctx, "Lock (L): during playback the page ignores the mouse wheel, dragging and the keys.\n"
      .. "MIDI and autoscroll still work. Click again or press L to unlock.")
  end)
  -- hide panel when playing (S.hide_controls_playing, the same as in Settings > Display)
  add(bw, function()
    local on = S.hide_controls_playing
    local nc, nv = UI.push_kind(ctx, on and "primary" or nil)
    local hit = UI.button(ctx, "##hidectl", bw, 0)
    UI.pop_kind(ctx, nc, nv)
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1, y1 = ImGui.GetItemRectMax(ctx)
    UI.draw_tb_icon(ImGui.GetWindowDrawList(ctx), math.floor((x0 + x1) / 2) + 0.5, math.floor((y0 + y1) / 2) + 0.5,
      on and "hide" or "show", on and COL.WHITE or COL.TEXT_MAIN)
    if hit then S.hide_controls_playing = not on; Util.mark_dirty() end
    UI.tip(ctx, on and "Hide panel when playing: on. During playback the tabs and the panel are hidden.\nClick to keep them."
      or "Hide panel when playing: off. Click to hide the tabs and the panel during playback.")
  end)
  -- a narrow window: the grey PDF name gets shorter, and then goes, before anything else wraps
  if name_item then
    local avail = math.max(1, (ImGui.GetContentRegionAvail(ctx)))
    local total, last_g = 0, nil
    for i, it in ipairs(items) do
      total = total + it.w + ((i == 1) and 0 or ((it.g ~= last_g) and CFG.TB_GROUP_GAP or CFG.TB_GAP))
      last_g = it.g
    end
    if total > avail then
      name_item.w = name_item.w - (total - avail)
      if name_item.w < 40 then
        for i, it in ipairs(items) do if it == name_item then table.remove(items, i); break end end
      end
    end
  end
  return items
end

-- menu texts (built once)
local MENU_SCROLL_LABELS = { "Off", "Markers", "Cue list" } -- order of SCROLL_MODES
local MENU_BRIGHTNESS = { { 25, "25%" }, { 50, "50%" }, { 75, "75%" }, { 100, "100%" } }

-- Right-click menus. A right-click only asks for a menu (R.menu_req = { kind = ... }); UI.context_menus
-- opens and draws it once per frame at the window level, so a menu never depends on where it was asked.
--   main: toolbar and page;  pdf: a Library row;  region: a Regions row;  cue: a Cues row.
-- ty: screen y of the toolbar top; call right after UI.draw_centered_toolbar.
function UI.toolbar_menu(ctx, ty)
  local _, by = ImGui.GetCursorScreenPos(ctx)
  local _, my = ImGui.GetMousePos(ctx)
  if ImGui.IsMouseClicked(ctx, 1) and my >= ty and my < by and ImGui.IsWindowHovered(ctx,
      ImGui.HoveredFlags_RootAndChildWindows() | ImGui.HoveredFlags_AllowWhenBlockedByPopup()) then
    R.menu_req = { kind = "main" }
  end
end

-- true while the mouse is over the row that starts at screen (sx, sy), `w` wide, one control high.
function UI.mouse_in_row(ctx, sx, sy, w)
  local mx, my = ImGui.GetMousePos(ctx)
  return mx >= sx - 6 and mx < sx + w and my >= sy - 2 and my < sy + UI.h(ctx) + 2
    and ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_RootAndChildWindows() | ImGui.HoveredFlags_AllowWhenBlockedByPopup())
end

local function menu_sep(ctx) UI.vgap(ctx, 3); ImGui.Separator(ctx); UI.vgap(ctx, 3) end

-- Opens the asked menu (R.menu_req) and draws the open one. Call once per frame, inside the window.
function UI.context_menus(ctx)
  if R.menu_req then
    R.menu = R.menu_req; R.menu_req = nil; R.menu_frame = R.frames
    ImGui.OpenPopup(ctx, "##ctxmenu")
  end
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding(), 0, 4)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(), 0, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding(), 0)
  local open = ImGui.BeginPopup(ctx, "##ctxmenu")
  ImGui.PopStyleVar(ctx, 3)
  if not open then R.menu = nil; return end
  -- a click outside Chart Cue (REAPER's own windows) takes the focus away: close the menu then
  if R.frames > (R.menu_frame or 0) + 2 and not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow()) then
    ImGui.CloseCurrentPopup(ctx)
  end
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(), 0, 0)
  local m = R.menu or { kind = "main" }
  if m.kind == "pdf" then UI.pdf_menu(ctx, m.path)
  elseif m.kind == "region" then UI.region_menu(ctx, m.key)
  elseif m.kind == "cue" then
    R.cue_part_ctx = m.part -- the list of the row (PDF 1 or PDF 2)
    local ok, err = pcall(UI.cue_menu, ctx, m)
    R.cue_part_ctx = nil
    if not ok then error(err, 0) end
  else UI.main_menu(ctx) end
  ImGui.PopStyleVar(ctx, 1)
  ImGui.EndPopup(ctx)
end

-- "Pages on screen" (Settings > Display and the menu); the view starts at the top of the page.
function UI.set_page_layout(l)
  if l == S.page_layout then return end
  S.page_layout = l; S.scroll_x, S.scroll_y = 0, 0; R.cont_off, R.side_off = nil, nil; Util.mark_dirty()
end

-- Toolbar and page menu.
function UI.main_menu(ctx)
  local has_pdf = S.pdf_path ~= "" and R.total > 0
  if UI.menu_item(ctx, "Add PDF...") then PDF.browse_add_pdf(false) end
  if UI.menu_item(ctx, "Add from folder...") then Project.start_folder_pick() end
  if UI.menu_item(ctx, "Sync folders", nil, false, #P.folders == 0 or R.import ~= nil) then Project.sync_folders() end
  if UI.menu_item(ctx, "Replace PDF...", nil, false, not has_pdf or Util.playing()) then Project.replace_pdf(S.pdf_path) end
  if R.part2 and UI.menu_item(ctx, "Close PDF 2", nil, false, Util.playing()) then UI.close_part2() end
  menu_sep(ctx)
  if UI.menu_item(ctx, "Hide panel when playing", nil, S.hide_controls_playing) then
    S.hide_controls_playing = not S.hide_controls_playing; Util.mark_dirty()
  end
  if UI.menu_item(ctx, "Show panel", nil, S.panel_open) then S.panel_open = not S.panel_open; Util.mark_dirty() end
  if UI.menu_item(ctx, "Lock", "L", R.lock) then UI.toggle_lock() end
  if UI.menu_item(ctx, "Performance mode", "F") then UI.toggle_perf() end
  menu_sep(ctx)
  local mode = Nav.scroll_mode()
  if UI.menu_sub(ctx, "Autoscroll", Util.playing()) then
    for i, sm in ipairs(SCROLL_MODES) do
      if UI.menu_item(ctx, MENU_SCROLL_LABELS[i], nil, mode == sm) then Nav.set_scroll_mode(sm) end
    end
    UI.menu_sub_end(ctx)
  end
  if UI.menu_item(ctx, "Record cues", "R", R.rec, mode ~= "cues") then UI.toggle_rec() end
  if UI.menu_item(ctx, "Copy markers into cues", nil, false, #R.page_pts + #R.scroll_pts == 0) then
    Cues.copy_markers(true)
  end
  menu_sep(ctx)
  if UI.menu_sub(ctx, "Page brightness") then
    local pct = S.dim_page and math.floor(S.dim_level * 100 + 0.5) or 100
    for _, b in ipairs(MENU_BRIGHTNESS) do
      if UI.menu_item(ctx, b[2], nil, pct == b[1]) then
        S.dim_page, S.dim_level = b[1] < 100, b[1] / 100; Util.mark_dirty()
      end
    end
    UI.menu_sub_end(ctx)
  end
  if UI.menu_sub(ctx, "Pages on screen") then
    for i, l in ipairs(PAGE_LAYOUTS) do
      if UI.menu_item(ctx, PAGE_LAYOUT_LABELS[i], nil, S.page_layout == l) then UI.set_page_layout(l) end
    end
    UI.menu_sub_end(ctx)
  end
  if UI.menu_item(ctx, "Match DPI to current view", nil, false, not PDF.can_match_dpi()) then PDF.match_dpi() end
  menu_sep(ctx)
  if UI.menu_item(ctx, "Settings") then S.tab = TAB_FIRST_SETTING; S.panel_open = true; Util.mark_dirty() end
  if UI.menu_item(ctx, "Help") then S.tab = TAB_HELP; S.panel_open = true; Util.mark_dirty() end
  menu_sep(ctx)
  -- like REAPER's own windows: one "Dock ... in Docker" item, ticked while docked
  if UI.menu_item(ctx, "Dock Chart Cue in Docker", nil, R.last_docked) then
    R.dock_req = R.last_docked and 0 or (R.last_dock_id or -1) -- the last docker used, else the first
  end
  if UI.menu_item(ctx, "Close Chart Cue") then R.quit = true end
end

-- Library row menu: this PDF.
function UI.pdf_menu(ctx, path)
  local missing = (R.libexists[path] == false)
  local playing = Util.playing() -- the PDF on screen belongs to the song during playback
  if UI.menu_item(ctx, "Open", nil, false, missing or playing) then PDF.open_pdf(path, false) end
  if UI.menu_item(ctx, "Show as PDF 2", nil, false, missing or playing) then UI.show_part2(path) end
  if UI.menu_item(ctx, "Replace PDF...", nil, false, playing) then Project.replace_pdf(path) end
  if UI.menu_item(ctx, "Show in Explorer") then Util.show_in_explorer(path) end
  menu_sep(ctx)
  if UI.menu_item(ctx, "Remove from library...") then UI.ask_remove_pdf(path) end
end

-- Regions row menu: this region.
function UI.region_menu(ctx, key)
  local reg = Project.region_by_key(key)
  if not reg then ImGui.CloseCurrentPopup(ctx); return end
  if UI.menu_item(ctx, "Go to region start", nil, false, Util.playing()) then r.SetEditCurPos(reg.start, true, false) end
  menu_sep(ctx)
  if UI.menu_item(ctx, "Choose PDF file...") then
    local ok, f = r.GetUserFileNameForRead("", "Select a PDF for region \"" .. reg.name .. "\"", "pdf")
    if ok and f and f ~= "" then Project.import_for_region(reg, f) end
  end
  if UI.menu_item(ctx, "Auto-match by name", nil, not P.assign[key] and not P.ignore[key]) then
    Project.set_region_choice(reg, "auto"); R.cur_region_key = nil
  end
  if reg.pdf2 then
    if UI.menu_item(ctx, "Swap PDF 1 and PDF 2") then
      local a, b = reg.pdf, reg.pdf2
      P.assign[key], P.assign2[key], P.no2[key] = b, a, nil; P.names[key] = reg.name
      Project.resolve_regions(); Util.mark_pdirty(); R.cur_region_key = nil
    end
    if UI.menu_item(ctx, "Remove PDF 2") then Project.set_pdf2(reg, nil) end
  end
  if UI.menu_item(ctx, "Ignore this region", nil, P.ignore[key] == true) then
    Project.set_region_choice(reg, P.ignore[key] and "auto" or "ignore"); R.cur_region_key = nil
  end
end

-- Cues row menu: this cue (i = 0: the Start row). The row number is looked up again, so the menu
-- still acts on the right cue when the list changed while it was open.
function UI.cue_menu(ctx, m)
  local list, idx = Cues.list(m.reg), 0
  for j, c in ipairs(list) do if c == m.c then idx = j end end
  local start = (m.i == 0)
  if not start and idx == 0 then ImGui.CloseCurrentPopup(ctx); return end
  if UI.menu_item(ctx, "Go to cue", nil, false, Util.playing()) then r.SetEditCurPos(Cues.to_time(m.reg, m.c.pos), true, false) end
  if UI.menu_item(ctx, "Use current view", nil, false, R.total == 0) then
    if start then Cues.save_undo(); Cues.put(m.reg, 0, S.page, Cues.view_scroll())
    else Cues.use_view(m.c) end
    R.cue_err, R.cue_text = {}, {}
  end
  if UI.menu_item(ctx, "Add scroll point below") then
    Cues.add_below(m.reg, P.cues[Cues.key(m.reg)] or list, start and 0 or idx); R.cue_err, R.cue_text = {}, {}
  end
  menu_sep(ctx)
  if UI.menu_item(ctx, "Remove cue", nil, false, start) then Cues.remove(m.reg, idx); R.cue_err, R.cue_text = {}, {} end
end

-- Submenu row ("Label  >"), in the same height and indent as UI.menu_item. Returns true while the
-- submenu is open; then draw its items and call UI.menu_sub_end. ImGui's menu row is the text height
-- plus the item spacing, centred on the text: the cursor moves down by `half` first and back after.
function UI.menu_sub(ctx, label, disabled)
  local fs = ImGui.GetFontSize(ctx)
  local h = math.floor(fs + 10)
  local half = math.floor((h - fs) / 2)
  -- the label is ImGui's own (it stays visible while the submenu is open), moved into the text
  -- column with leading spaces (measured once)
  if not R.menu_indent then
    R.menu_indent = string.rep(" ", math.max(1, math.floor(26 / math.max(1, (ImGui.CalcTextSize(ctx, " "))) + 0.5)))
  end
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  ImGui.SetCursorScreenPos(ctx, sx, sy + half)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(), 0, h - fs)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding(), 0, 4)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding(), 0)
  ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered(), COL.BTN_HOVER)
  ImGui.PushStyleColor(ctx, ImGui.Col_Header(), COL.BTN_HOVER)
  local open = ImGui.BeginMenu(ctx, R.menu_indent .. label .. "##sub", not disabled)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 3)
  if open then
    R.menu_sub_half = half
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(), 0, 0)
  else
    ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - half)
  end
  return open
end
function UI.menu_sub_end(ctx)
  ImGui.PopStyleVar(ctx, 1)
  ImGui.EndMenu(ctx)
  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - (R.menu_sub_half or 0)) -- back in the parent menu
end
-- One item of a REAPER-style menu: a tick column on the left, the label, the key (grey) on the
-- right; the whole row highlights on hover. Returns true when clicked (the menu then closes).
-- disabled: grey text, no hover, no click (like REAPER's unavailable items).
function UI.menu_item(ctx, label, key, checked, disabled)
  local LEFT, RIGHT, GAP = 26, 14, 40
  local h = math.floor(ImGui.GetFontSize(ctx) + 10)
  local lw = ImGui.CalcTextSize(ctx, label)
  local kw = key and ImGui.CalcTextSize(ctx, key) or 0
  local w = math.max(ImGui.GetContentRegionAvail(ctx), LEFT + lw + (key and GAP + kw or 0) + RIGHT, 240)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local hit = ImGui.InvisibleButton(ctx, "##mi" .. label, w, h) and not disabled
  local dl = ImGui.GetWindowDrawList(ctx)
  local tc = disabled and COL.TEXT_DIM or COL.TEXT_MAIN
  if ImGui.IsItemHovered(ctx) and not disabled then ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, COL.BTN_HOVER) end
  local ty = y + math.floor((h - ImGui.GetFontSize(ctx)) / 2) - CFG.TEXT_LIFT
  if checked then -- tick: two lines
    local cx, cy = x + 13, y + h / 2
    ImGui.DrawList_PathLineTo(dl, cx - 4, cy)
    ImGui.DrawList_PathLineTo(dl, cx - 1, cy + 3)
    ImGui.DrawList_PathLineTo(dl, cx + 5, cy - 4)
    ImGui.DrawList_PathStroke(dl, tc, 0, 1.6)
  end
  ImGui.DrawList_AddText(dl, x + LEFT, ty, tc, label)
  if key then ImGui.DrawList_AddText(dl, x + w - RIGHT - kw, ty, COL.TEXT_DIM, key) end
  if hit then ImGui.CloseCurrentPopup(ctx) end
  return hit
end

function UI.draw_centered_toolbar(ctx)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 8, UI.pad_y(ctx)) -- the same height as all controls
  local items = UI.toolbar_items(ctx)
  local avail = math.max(1, (ImGui.GetContentRegionAvail(ctx)))
  local x0 = ImGui.GetCursorPosX(ctx)
  local gap, ggap = CFG.TB_GAP, CFG.TB_GROUP_GAP
  local groups = {}
  for _, it in ipairs(items) do
    local gr = groups[#groups]
    if not gr or gr.g ~= it.g then gr = { g = it.g, items = {}, w = 0 }; groups[#groups + 1] = gr end
    gr.w = (#gr.items == 0) and it.w or (gr.w + gap + it.w)
    gr.items[#gr.items + 1] = it
  end
  -- rows of { it, sep }; a whole group moves to the next row, unless it is wider than the window
  local rows, row, row_w = {}, {}, 0
  local function put(it, sep, w)
    row[#row + 1] = { it = it, sep = sep and #row > 0 }; row_w = w
  end
  for _, gr in ipairs(groups) do
    local need = (#row == 0) and gr.w or (row_w + ggap + gr.w)
    if #row > 0 and need > avail then rows[#rows + 1] = { items = row, w = row_w }; row = {}; row_w = 0 end
    for j, it in ipairs(gr.items) do
      local sp = (j == 1) and ggap or gap
      local w = (#row == 0) and it.w or (row_w + sp + it.w)
      if #row > 0 and w > avail then rows[#rows + 1] = { items = row, w = row_w }; row = {}; w = it.w end
      put(it, j == 1, w)
    end
  end
  if #row > 0 then rows[#rows + 1] = { items = row, w = row_w } end
  local dl, fh = ImGui.GetWindowDrawList(ctx), ImGui.GetFrameHeight(ctx)
  for _, rw in ipairs(rows) do -- every item is one frame high, so SameLine keeps one top edge
    for j, e in ipairs(rw.items) do
      if j == 1 then ImGui.SetCursorPosX(ctx, x0 + math.max(0, math.floor((avail - rw.w) / 2)))
      else ImGui.SameLine(ctx, 0, e.sep and ggap or gap) end
      if e.sep then
        local sx, sy = ImGui.GetCursorScreenPos(ctx)
        local lx = math.floor(sx - ggap / 2) + 0.5
        ImGui.DrawList_AddLine(dl, lx, sy + 4, lx, sy + fh - 4, COL.TOGGLE_OFF, 1)
      end
      e.it.draw(ctx, e.it.w)
    end
  end
  ImGui.PopStyleVar(ctx, 1)
end

---------------------------------------------------------------------------
-- LAYOUT SYSTEM for the settings panels (every tab uses these, so all sections look the same)
--   * two columns: label column (CFG.LABEL_W) + control column (max CFG.FORM_MAX_W)
--   * every dropdown, input, slider and button fills the control column
--   * 3 button types: single (full column), pair (2 equal halves), row action (fixed, in lists)
--   * checkboxes, notes and messages start in the control column
--   * dangerous actions: red outline, last in their section
--   * narrow panel: labels go above their control, button pairs stack
---------------------------------------------------------------------------
-- Available width in the settings panel, always measured as if its scrollbar were shown.
-- Without this, a list that becomes short enough to lose the scrollbar (for example the
-- "needs PDF" view) makes the panel wider and every button in it resizes.
function UI.panel_w(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  if ImGui.GetScrollMaxY(ctx) <= 0 then
    aw = aw - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize())
  end
  return aw
end

-- Spacing value for the current layout (CFG.SP entry: comfortable / compact).
function UI.sp(key) return CFG.SP[key][S.comfortable and 1 or 2] end

-- Exact vertical gap of `px` pixels after the previous item. ImGui adds its row spacing on its
-- own, so it is subtracted here; every gap in the UI is set with this, so top and bottom match.
function UI.vgap(ctx, px)
  local _, sy = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
  ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - (sy or 0) + px)
end

-- Returns row start x, control column x, control column width, wide (labels left of controls).
-- With `label`: a label wider than the label column puts its control on the next row (no overlap).
function UI.form(ctx, label)
  local x0 = ImGui.GetCursorPosX(ctx)
  local aw = UI.panel_w(ctx)
  local wide = aw >= CFG.LABEL_W + CFG.FORM_MIN_WIDE
  if wide and label then -- measured in the bold label font
    UI.push_font(ctx, R.label_font)
    local lw = ImGui.CalcTextSize(ctx, label)
    UI.pop_font(ctx)
    if lw > CFG.LABEL_W - 8 then wide = false end
  end
  local cx = wide and (x0 + CFG.LABEL_W) or x0
  local cw = math.max(100, math.min(CFG.FORM_MAX_W, aw - (cx - x0) - 12))
  return x0, cx, cw, wide
end

-- Label + the next widget in the control column (call the widget right after this).
function UI.field(ctx, label)
  local _, cx, cw, wide = UI.form(ctx, label)
  UI.label(ctx, label)
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, cx)
  ImGui.SetNextItemWidth(ctx, cw)
end

-- Checkbox row: the label in the label column (clickable), the box in the control column.
function UI.checkbox(ctx, label, v)
  local _, cx, _, wide = UI.form(ctx, label)
  UI.label(ctx, label)
  local label_clicked = ImGui.IsItemClicked(ctx)
  if ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, cx)
  local ch, nv = UI.toggle(ctx, "##cb_" .. label, v)
  if label_clicked then ch, nv = true, not v end
  return ch, nv
end

-- Starts a row: optional label in the label column, cursor in the control column.
-- Returns the control column x and width.
function UI.row_start(ctx, row_label)
  local _, cx, cw, wide = UI.form(ctx, row_label)
  if row_label then
    UI.label(ctx, row_label)
    if wide then ImGui.SameLine(ctx) end
  end
  ImGui.SetCursorPosX(ctx, cx)
  return cx, cw
end

-- Read-only "label: value" row (value wraps inside the control column).
function UI.value(ctx, label, text, col)
  local cx, cw = UI.row_start(ctx, label)
  -- one line: at the shared text position, so it lines up with its label (and with path rows)
  if (ImGui.CalcTextSize(ctx, text)) <= cw then UI.row_text(ctx, text, col or COL.GREY); return end
  ImGui.PushTextWrapPos(ctx, cx + cw)
  ImGui.TextColored(ctx, col or COL.GREY, text)
  ImGui.PopTextWrapPos(ctx)
end
-- Wrapped text in the control column (notes, status lines, messages).
function UI.note(ctx, text, col)
  local _, cx, cw = UI.form(ctx)
  ImGui.SetCursorPosX(ctx, cx)
  ImGui.PushTextWrapPos(ctx, cx + cw)
  if col then ImGui.TextColored(ctx, col, text) else ImGui.Text(ctx, text) end
  ImGui.PopTextWrapPos(ctx)
end

-- Inline confirmation (in place of a message box): UI.ask() arms it, UI.draw_ask() shows the
-- question with a red "Yes, ..." and a "Cancel" button at the place where it was asked.
-- `key` (optional): what the question is about, e.g. the song; draw_ask closes the question when
-- its key changes, so an old question never stays open for a different song.
function UI.ask(id, text, yes_label, run, key)
  R.ask = { id = id, text = text, yes = yes_label, run = run, key = key }
end

function UI.draw_ask(ctx, id, key)
  local a = R.ask
  if not a or a.id ~= id then return end
  if a.key ~= key then R.ask = nil; return end
  UI.note(ctx, a.text, COL.YELLOW)
  ImGui.PushID(ctx, "ask_" .. id)
  local _, cw = UI.row_start(ctx)
  local hw = math.floor((cw - 8) / 2)
  local yes = UI.row_button(ctx, a.yes, hw, true)
  ImGui.SameLine(ctx, 0, 8)
  local no = UI.button(ctx, "Cancel", cw - hw - 8, UI.h(ctx))
  ImGui.PopID(ctx) -- always paired with PushID above
  if yes then R.ask = nil; a.run() elseif no then R.ask = nil end
end

-- "Remove PDF markers...": asks first, with the number of markers and where they are.
function UI.ask_remove_markers(id, lo, hi, where, key)
  local n = #Project.script_markers(lo, hi)
  if n == 0 then
    Msg.notify("There are no PDF markers in " .. where .. ".", false, "cues"); return
  end
  UI.ask(id, string.format("Remove %d PDF marker(s) in %s? Only PDF markers (PDFPAGE / PDFSCROLL) are removed. "
    .. "Regions and other markers are not changed. Edit > Undo (Ctrl+Z) brings them back.", n, where),
    "Yes, remove", function() Project.remove_script_markers(lo, hi, where) end, key)
end

-- The message of `source` in the free space of the last heading's title line (right aligned, cut
-- to fit, fading out at the end), so the rows below never move. The full text is its tooltip.
function UI.heading_msg(ctx, source)
  local m, hr = Msg.recent(source, true), R.heading_row
  if not m or not hr then return end
  local w = hr.x1 - hr.x0
  if w < 40 then return end
  local txt = UI.trunc_text(ctx, m.text, w)
  local tw = ImGui.CalcTextSize(ctx, txt)
  local left = CFG.MSG_SECONDS - (Util.now() - m.t)
  local a = math.floor(255 * Util.clamp(left / 0.6, 0, 1))
  local col = ((m.err and COL.RED or COL.GREEN) & 0xFFFFFF00) | a
  local x = hr.x1 - tw
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, UI.text_y(ctx, hr.y), col, txt)
  local mx, my = ImGui.GetMousePos(ctx)
  if txt ~= m.text and mx >= x and mx <= hr.x1 and my >= hr.y and my <= hr.y + UI.h(ctx) then
    ImGui.SetTooltip(ctx, m.text)
  end
end

-- The message area of a section: the latest message of `source`, always under its buttons.
function UI.section_msg(ctx, source)
  local m = Msg.recent(source)
  if not m then return end
  UI.note(ctx, m.text, m.err and COL.RED or COL.GREEN)
  if m.sticky then
    -- small "x" to close it, at the end of the note
    ImGui.SameLine(ctx, 0, 6)
    if UI.button(ctx, "x##closemsg", UI.h(ctx), UI.h(ctx)) then R.msg = nil end
    UI.tip(ctx, "Close this message")
  end
end

---------------------------------------------------------------------------
-- MODERN THEME: flat dark colours, rounded corners, roomier padding, Segoe UI.
-- Pushed ONCE per frame before Begin() and popped after End(); the counts are stored in R.theme,
-- so the pops always match the pushes (also after an error, see UI.loop).
---------------------------------------------------------------------------
function UI.push_theme(ctx)
  local nc, nv = 0, 0
  local function col(fn, c) ImGui.PushStyleColor(ctx, fn(), c); nc = nc + 1 end
  local function var(fn, a, b)
    if b then ImGui.PushStyleVar(ctx, fn(), a, b) else ImGui.PushStyleVar(ctx, fn(), a) end
    nv = nv + 1
  end
  col(ImGui.Col_WindowBg, COL.WIN_BG)
  col(ImGui.Col_ChildBg, COL.TRANSPARENT)
  col(ImGui.Col_PopupBg, COL.PANEL_BG)
  col(ImGui.Col_Border, COL.LINE)
  col(ImGui.Col_FrameBg, COL.FIELD)
  col(ImGui.Col_FrameBgHovered, COL.FIELD_HOVER)
  col(ImGui.Col_FrameBgActive, COL.FIELD_ACTIVE)
  col(ImGui.Col_Button, COL.BTN)
  col(ImGui.Col_ButtonHovered, COL.BTN_HOVER)
  col(ImGui.Col_ButtonActive, COL.BTN_ACTIVE)
  col(ImGui.Col_Header, COL.ACTIVE_BG)
  col(ImGui.Col_HeaderHovered, 0x3B82F655)
  col(ImGui.Col_HeaderActive, 0x3B82F677)
  col(ImGui.Col_CheckMark, COL.ACCENT)
  col(ImGui.Col_SliderGrab, COL.ACCENT)
  col(ImGui.Col_SliderGrabActive, COL.ACCENT_HOVER)
  col(ImGui.Col_Text, COL.TEXT_MAIN)
  col(ImGui.Col_TextDisabled, COL.TEXT_DIM)
  col(ImGui.Col_Separator, COL.LINE)
  col(ImGui.Col_ScrollbarBg, COL.TRANSPARENT)
  col(ImGui.Col_ScrollbarGrab, COL.BTN_HOVER)
  col(ImGui.Col_ScrollbarGrabHovered, COL.BTN_ACTIVE)
  col(ImGui.Col_ScrollbarGrabActive, COL.TOGGLE_OFF)
  col(ImGui.Col_TextSelectedBg, 0x3B82F666)
  var(ImGui.StyleVar_FrameRounding, 6)
  var(ImGui.StyleVar_GrabRounding, 6)
  var(ImGui.StyleVar_PopupRounding, 6)
  var(ImGui.StyleVar_ScrollbarRounding, 6)
  var(ImGui.StyleVar_ChildRounding, 8)
  -- all fields, dropdowns and buttons are CFG.ROW_H high (text centred in the same box)
  var(ImGui.StyleVar_FramePadding, 10, math.max(2, math.floor((CFG.ROW_H - CFG.FONT_SIZE) / 2)))
  var(ImGui.StyleVar_ItemSpacing, 8, UI.sp("ROW"))
  var(ImGui.StyleVar_WindowPadding, 8, UI.sp("EDGE"))
  var(ImGui.StyleVar_ScrollbarSize, 12)
  var(ImGui.StyleVar_FrameBorderSize, 0)
  UI.push_font(ctx, R.ui_font)
  R.theme = { c = nc, v = nv }
end

-- The pops are protected because pop_theme also runs after an error inside a frame (UI.loop).
function UI.pop_theme(ctx)
  local t = R.theme
  if not t then return end
  R.theme = nil
  pcall(r.ImGui_PopFont, ctx)
  if t.v > 0 then pcall(ImGui.PopStyleVar, ctx, t.v) end
  if t.c > 0 then pcall(ImGui.PopStyleColor, ctx, t.c) end
end

-- Smoothly moves an animation value (0..1) towards `target` (hover fades, toggle knobs).
function UI.anim(id, target, speed)
  local v = R.anim[id] or target
  local dt = 1 / 60
  if R.ctx then dt = ImGui.GetDeltaTime(R.ctx) end
  v = v + (target - v) * math.min(1, dt * (speed or 14))
  if math.abs(v - target) < 0.002 then v = target end
  R.anim[id] = v
  return v
end

function Util.lerp_col(a, b, t)
  local function ch(c, sh) return (c >> sh) & 0xFF end
  local out = 0
  for _, sh in ipairs({ 24, 16, 8, 0 }) do
    out = out | (math.floor(ch(a, sh) + (ch(b, sh) - ch(a, sh)) * t + 0.5) << sh)
  end
  return out
end

-- Toggle switch (replaces the checkbox). Returns changed, new value.
function UI.toggle(ctx, id, v)
  local h = math.floor(ImGui.GetFrameHeight(ctx))
  local th = math.min(20, h - 4)
  local tw = math.floor(th * 1.8)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, id, tw, h)
  local hov, clk = ImGui.IsItemHovered(ctx), ImGui.IsItemClicked(ctx)
  if clk then v = not v end
  local t = UI.anim("tg" .. id, v and 1 or 0, 16)
  local ty = y + math.floor((h - th) / 2)
  local dl = ImGui.GetWindowDrawList(ctx)
  local track = Util.lerp_col(COL.TOGGLE_OFF, COL.ACCENT, t)
  if hov then track = Util.lerp_col(track, COL.WHITE, 0.12) end
  ImGui.DrawList_AddRectFilled(dl, x, ty, x + tw, ty + th, track, th / 2)
  local rad = th / 2 - 3
  ImGui.DrawList_AddCircleFilled(dl, x + th / 2 + t * (tw - th), ty + th / 2, rad, COL.WHITE)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  return clk, v
end

-- Button kinds: "primary" (filled accent), "danger" or true (red outline), "ghost" (text only).
-- Returns the counts to pop with UI.pop_kind.
function UI.push_kind(ctx, kind)
  if kind == true or kind == "danger" then -- red outline
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.DANGER_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.DANGER_ACTIVE)
    ImGui.PushStyleColor(ctx, ImGui.Col_Border(), COL.RED)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize(), 1)
    return 5, 1
  end
  if kind == "primary" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.ACCENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ACCENT_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACCENT_ACTIVE)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.WHITE)
    return 4, 0
  end
  if kind == "ghost" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ROW_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACTIVE_BG)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.ACCENT_HOVER)
    return 4, 0
  end
  return 0, 0
end
function UI.pop_kind(ctx, nc, nv)
  if nv > 0 then ImGui.PopStyleVar(ctx, nv) end
  if nc > 0 then ImGui.PopStyleColor(ctx, nc) end
end

-- Single action: the full control column. kind: nil, "primary", "danger"/true, "ghost".
-- row_label = the name of the row in the label column (only when the button needs it).
-- The standard button width: the widest of the usual action labels (measured once). Every action
-- button uses it, so they all have the same size; a longer label gets just its own width, and a
-- narrow panel makes them smaller (avail). "Show in Explorer" and the small row buttons keep theirs.
local STD_LABELS = { "Add PDF", "Add from folder", "Add page turn", "Add scroll point", "Use Cue list mode",
  "Match DPI to current view", "Rescan project", "Reset window position", "Reset all settings...",
  "GitHub Issues", "REAPER forum" }
function UI.std_w(ctx, label, avail)
  if not R.std_btn_w then
    local w = 0
    for _, l in ipairs(STD_LABELS) do w = math.max(w, UI.btn_w(ctx, l, 0) + 16) end
    R.std_btn_w = w
  end
  local w = math.max(R.std_btn_w, UI.btn_w(ctx, label, 0) + 16)
  return math.floor(avail and math.min(w, avail) or w)
end

function UI.full_button(ctx, label, kind, row_label)
  local _, cw = UI.row_start(ctx, row_label)
  local nc, nv = UI.push_kind(ctx, kind)
  local hit = UI.button(ctx, label, UI.std_w(ctx, label, cw), UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  return hit
end
function UI.danger_button(ctx, label, row_label) return UI.full_button(ctx, label, true, row_label) end

-- Width a button needs for its text: text + horizontal padding on both sides (+2 px for the
-- red outline), but never less than `min_w`. Used so a fixed-width button never clips its text.
function UI.btn_w(ctx, label, min_w)
  local px = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
  local tw = ImGui.CalcTextSize(ctx, (label:gsub("##.*$", "")))
  return math.max(min_w or 0, math.ceil(tw + 2 * px + 2))
end

-- Row action button in a list. kind: nil, "primary", "danger"/true, "ghost".
-- The width grows when the text needs more space, so the label never clips.
function UI.row_button(ctx, label, w, kind)
  w = UI.btn_w(ctx, label, w)
  local nc, nv = UI.push_kind(ctx, kind)
  local hit = UI.button(ctx, label, w, UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  return hit
end

-- Clickable area for a list row (call at the row start, then draw the row content on top).
-- Returns clicked, hovered. Shows a light highlight and a hand cursor on hover.
function UI.row_click_area(ctx, id, w)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local h = ImGui.GetFrameHeight(ctx)
  ImGui.InvisibleButton(ctx, id, math.max(1, w), h)
  local hov, clk = ImGui.IsItemHovered(ctx), ImGui.IsItemClicked(ctx)
  if hov then
    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), sx - 6, sy - 2, sx + w, sy + h + 2, COL.ROW_HOVER, 4)
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end
  ImGui.SetCursorScreenPos(ctx, sx, sy)
  return clk, hov
end

-- Title row for a song's cue list: name (bold) + time range (normal text), centred on one line.
function UI.song_title(ctx, name, rg)
  UI.vgap(ctx, UI.sp("TITLE_BEFORE"))
  UI.push_bold_font(ctx)
  UI.row_text(ctx, name, COL.HEADING)
  UI.pop_font(ctx)
  if rg then
    ImGui.SameLine(ctx, 0, 12)
    UI.row_text(ctx, Util.fmt_mmss(rg.start) .. " - " .. Util.fmt_mmss(rg.stop), COL.TEXT)
  end
end

-- Pair of actions: 2 equal halves of the control column. The pair stacks when the column is
-- narrow or when a label does not fit in its half (so a button text never clips).
function UI.button_pair(ctx, la, lb, kind, row_label)
  return UI.button_pair2(ctx, la, kind, lb, kind, nil, nil, row_label)
end

-- Like UI.button_pair, but each button has its own kind (e.g. blue "primary" next to red "danger")
-- and its own optional tooltip (ta, tb).
function UI.button_pair2(ctx, la, ka, lb, kb, ta, tb, row_label)
  local cx, cw = UI.row_start(ctx, row_label)
  local w = math.max(UI.std_w(ctx, la), UI.std_w(ctx, lb)) -- the standard width (both the same)
  local stack = (2 * w + 8 > cw)
  if stack then w = math.min(w, cw) end
  local nc, nv = UI.push_kind(ctx, ka)
  local a = UI.button(ctx, la, w, UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  if ta then UI.tip(ctx, ta) end
  if stack then ImGui.SetCursorPosX(ctx, cx) else ImGui.SameLine(ctx, 0, 8) end
  nc, nv = UI.push_kind(ctx, kb)
  local b = UI.button(ctx, lb, w, UI.h(ctx))
  UI.pop_kind(ctx, nc, nv)
  if tb then UI.tip(ctx, tb) end
  return a, b
end

-- Search field + dropdown above a list (Library: sort, Regions: show), the same in every list.
-- In a very narrow panel the dropdown wraps below the field. Returns the new text and index.
function UI.search_row(ctx, id, text, hint, sel, items)
  local aw = UI.panel_w(ctx)
  local narrow = aw < CFG.SORT_W + 150
  ImGui.SetNextItemWidth(ctx, narrow and -12 or (aw - CFG.SORT_W - 8 - 12))
  local _, nt = ImGui.InputTextWithHint(ctx, "##" .. id .. "search", hint, text)
  if not narrow then ImGui.SameLine(ctx) end
  ImGui.SetNextItemWidth(ctx, narrow and -12 or CFG.SORT_W)
  local _, ns = ImGui.Combo(ctx, "##" .. id .. "menu", sel, items)
  UI.vgap(ctx, UI.sp("SEARCH")) -- more room before the list, so the search row stands apart
  return nt, ns
end

-- Column titles above a list (the Help topics; the cue list draws its own aligned columns).
function UI.list_header(ctx, cols)
  for i, c in ipairs(cols) do
    if i > 1 then ImGui.SameLine(ctx, c[2]) end
    ImGui.TextDisabled(ctx, c[1])
  end
end

---------------------------------------------------------------------------
-- UI: TAB CONTENTS
---------------------------------------------------------------------------
function UI.library_order()
  local oc = R.order_cache
  if oc and oc.ver == R.lib_ver and oc.P == P and oc.n == #P.pdfs and oc.filter == R.lib_filter
      and oc.sort == R.lib_sort and (R.lib_sort ~= 3 or oc.unused == Project.unused_pdfs()) then
    return oc.idx
  end
  local idx, f = {}, R.lib_filter:lower()
  for i, path in ipairs(P.pdfs) do
    if f == "" or Util.name_of(path):lower():find(f, 1, true) or path:lower():find(f, 1, true) then idx[#idx + 1] = i end
  end
  if R.lib_sort == 0 then
    table.sort(idx, function(a, b)
      local na, nb = Util.name_of(P.pdfs[a]):lower(), Util.name_of(P.pdfs[b]):lower()
      if na ~= nb then return na < nb end
      return a < b
    end)
  elseif R.lib_sort == 1 then
    table.sort(idx, function(a, b)
      local pa, pb = R.libpages[P.pdfs[a]] or math.huge, R.libpages[P.pdfs[b]] or math.huge
      if pa ~= pb then return pa < pb end
      return a < b
    end)
  elseif R.lib_sort == 3 then -- unused first, then by name
    local un = Project.unused_pdfs()
    table.sort(idx, function(a, b)
      local ua, ub = un[P.pdfs[a]] and 0 or 1, un[P.pdfs[b]] and 0 or 1
      if ua ~= ub then return ua < ub end
      local na, nb = Util.name_of(P.pdfs[a]):lower(), Util.name_of(P.pdfs[b]):lower()
      if na ~= nb then return na < nb end
      return a < b
    end)
  else
    table.sort(idx, function(a, b) return a > b end) -- newest first
  end
  R.order_cache = { ver = R.lib_ver, P = P, n = #P.pdfs, filter = R.lib_filter, sort = R.lib_sort, idx = idx,
    unused = (R.lib_sort == 3) and Project.unused_pdfs() or nil }
  return idx
end

function UI.draw_library_tab(ctx)
  local ch
  if not R.psaveable then
    UI.note(ctx, "Project not saved yet: the library and region assignments are stored in the project and are written to disk when you save it.", COL.YELLOW)
  end

  if UI.heading(ctx, "Add PDFs", "Copy into project ON: imported PDFs are copied into <project folder>\\PDFs\\. "
    .. "The original files are only read. The project is portable.\n\n"
    .. "Copy into project OFF (link mode): the library points to the original PDFs. The project is not portable.\n\n"
    .. "The PDFs you add are saved in this project; the two options below are for this computer.", nil, "lib_add") then
    -- row 1: "Add PDF"; row 2: "Add from folder" | sync icon | the folder (grey, cut at the left) |
    -- Show in Explorer at the right end. The 2 buttons share one width that follows the panel width.
    do
      local fh = UI.h(ctx)
      local x0 = ImGui.GetCursorPosX(ctx)
      local aw = UI.panel_w(ctx)
      local _, cx = UI.form(ctx) -- the buttons start in the control column, like the toggles below
      local bw = UI.std_w(ctx, "Add from folder", aw - (cx - x0) - fh - 24)
      local nc, nv = UI.push_kind(ctx, "primary")
      ImGui.SetCursorPosX(ctx, cx)
      if UI.button(ctx, "Add PDF", bw, fh) then PDF.browse_add_pdf(false) end
      UI.tip(ctx, "Adds one PDF file to the library.")
      ImGui.SetCursorPosX(ctx, cx)
      if UI.button(ctx, "Add from folder", bw, fh) then Project.start_folder_pick() end
      UI.tip(ctx, "Adds all PDFs of a folder. The folder is remembered for the sync button next to it.")
      UI.pop_kind(ctx, nc, nv)
      ImGui.SameLine(ctx, 0, 8)
      local can_sync = #P.folders > 0 and not R.import and not R.sync
      ImGui.BeginDisabled(ctx, not can_sync)
      if UI.row_icon_button(ctx, "##syncfolders", fh, "sync", can_sync) and can_sync then Project.sync_folders() end
      ImGui.EndDisabled(ctx)
      if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
        ImGui.SetTooltip(ctx, (#P.folders == 0) and "Sync folders: use 'Add from folder' first; its folder is remembered."
          or string.format("Sync folders (%d): adds new PDFs, and replaces the copies of changed PDFs.\n"
            .. "PDFs that are no longer in a folder stay in the library.", #P.folders))
      end
      -- the folder of the last "Add from folder" (more folders: in the tooltip), like the PDF paths
      local last = P.folders[#P.folders]
      if last then
        local exp_w = UI.btn_w(ctx, "Show in Explorer", CFG.EXPLORER_BTN_W)
        local bx = x0 + aw - exp_w - 14
        ImGui.SameLine(ctx, 0, 10)
        if bx - ImGui.GetCursorPosX(ctx) - 12 < CFG.MIN_PATH_W then -- no room: own line, under the buttons
          ImGui.NewLine(ctx); ImGui.SetCursorPosX(ctx, cx)
          if bx < cx then bx = cx end
        end
        local path_w = bx - ImGui.GetCursorPosX(ctx) - 12 -- from here to "Show in Explorer"
        if path_w >= CFG.MIN_PATH_W then
          UI.row_text(ctx, UI.trunc_left(ctx, last.path, path_w), COL.TEXT_DIM)
          if ImGui.IsItemHovered(ctx) then
            local all = {}
            for i, fo in ipairs(P.folders) do all[i] = fo.path .. (fo.sub and "  (with subfolders)" or "") end
            ImGui.SetTooltip(ctx, "Folders of 'Add from folder' (Sync checks them all):\n" .. table.concat(all, "\n"))
          end
        end
        if path_w >= CFG.MIN_PATH_W then ImGui.SameLine(ctx, bx) else ImGui.SetCursorPosX(ctx, bx) end
        if UI.row_button(ctx, "Show in Explorer##folder", exp_w, "ghost") then Util.show_in_explorer(last.path) end
        UI.tip(ctx, "Opens this folder in Windows Explorer.")
      end
    end
    ch, S.import_copy = UI.checkbox(ctx, "Copy into project", S.import_copy)
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "On: imported PDFs are copied into <project folder>\\PDFs\\ (portable project).\nOff: the library links to the original files.")
    ch, S.include_subfolders = UI.checkbox(ctx, "Include subfolders", S.include_subfolders)
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "Used by 'Add from folder' and the sync button")
    if S.import_copy and not Project.dir() then
      UI.note(ctx, "Project not saved: imported PDFs are linked to their original location for now. "
        .. "Save the project, then use 'Copy all PDFs into the project'.", COL.YELLOW)
    end
    -- count of PDFs outside the project folder: rebuilt at most every 0.5 s, not every frame
    if not R.ext_count_t or Util.now() - R.ext_count_t > 0.5 then
      R.ext_count = Project.dir() and #Project.external_pdfs(true) or 0
      R.ext_count_t = Util.now()
    end
    local ext = R.ext_count
    if ext > 0 and not R.copy and #R.copyq == 0 then
      if UI.full_button(ctx, string.format("Copy all PDFs into the project (%d)", ext)) then
        Project.copy_all_into_project()
      end
      UI.tip(ctx, string.format("%d PDF(s) of the library are outside the project folder. "
        .. "This copies them into <project folder>\\PDFs\\.", ext))
    end
    -- remove the PDFs that no song uses (asks first)
    local _, nun = Project.unused_pdfs()
    if nun > 0 and not R.copy and #R.copyq == 0 and not R.import then
      if UI.full_button(ctx, string.format("Remove unused PDFs (%d)...", nun), true) then
        UI.ask("lib_unused", string.format("Remove %d unused PDF(s) from the library? Copies in this project's "
          .. "PDFs folder are deleted too; original files outside the project are never deleted.", nun),
          "Yes, remove", Project.remove_unused, "unused")
      end
      UI.tip(ctx, "Unused: no region uses it (as PDF 1 or PDF 2) and it is not on screen. Their names are grey.\n"
        .. "'Sort: Unused first' shows them at the top.")
    end
    UI.draw_ask(ctx, "lib_unused", "unused")
    if R.copy or #R.copyq > 0 then
      UI.note(ctx, string.format("Copying into the project... %d PDF(s) left%s", Project.copy_pending(),
        R.copy and (": " .. Util.name_of(R.copy.src)) or ""), COL.YELLOW)
    end
    if R.picker then
      UI.note(ctx, "Waiting for the folder dialog (it may be behind REAPER)...", COL.YELLOW)
    elseif R.import then
      UI.note(ctx, string.format("Scanning... %d files checked, %d added, %d duplicates skipped",
        R.import.scanned, R.import.added, R.import.skipped), COL.YELLOW)
    else
      UI.section_msg(ctx, "library")
    end
  end -- "Add PDFs" open

  UI.group_sep(ctx)
  UI.heading(ctx, string.format("PDF list (%d)", #P.pdfs), "Click a PDF to open it. The first column shows the name "
    .. "and the number of pages; the second column shows where the file is (starting with the project folder "
    .. "for PDFs inside it).\nMove the mouse over a PDF to see its full path.", "project")

  -- search + sort, above the list
  R.lib_filter, R.lib_sort = UI.search_row(ctx, "lib", R.lib_filter, "Search PDFs...", R.lib_sort, SORT_ITEMS)

  -- refresh existence flags every 2 s; fetch one missing page count per 0.3 s
  if Util.now() - R.libexists_t > 2 then
    for _, path in ipairs(P.pdfs) do R.libexists[path] = Util.file_exists(path) end
    R.libexists_t = Util.now()
  end
  if not R.lib_job and Util.now() - R.lib_scan_t > 0.3 then
    for _, path in ipairs(P.pdfs) do
      if R.libpages[path] == nil and R.libexists[path] ~= false then
        R.lib_scan_t = Util.now()
        local n = PDF.read_info_cache(path)
        if n then
          R.libpages[path] = n
        elseif PDF.engine() == "poppler" and R.exe and R.pdfinfo_ok then
          R.lib_job = PDF.start_info(path) -- result arrives in PDF.info_tick
          if not R.lib_job then R.libpages[path] = false end
        else
          R.libpages[path] = false -- Windows engine: known once the PDF is opened
        end
        Util.bump_lib()
        break
      end
    end
  end

  if #P.pdfs == 0 then ImGui.TextDisabled(ctx, "No PDFs in this project's library yet.") end
  -- name column width: the widest "name (pages)", measured only when the library changes
  if not R.lib_name_w or R.lib_name_w.ver ~= R.lib_ver then
    local w = 0
    for _, p in ipairs(P.pdfs) do
      local pg = R.libpages[p]
      w = math.max(w, (ImGui.CalcTextSize(ctx, Util.name_of(p) .. (pg and string.format("  (%d pp)", pg) or ""))))
    end
    R.lib_name_w = { ver = R.lib_ver, w = w }
  end
  local relocate_path
  local shown = 0
  -- measured once, so the buttons are wide enough for their text and the right edge stays aligned
  local BTN_W = UI.h(ctx) -- the round red X (the same as in the cue list)
  local EXP_W = UI.btn_w(ctx, "Show in Explorer", CFG.EXPLORER_BTN_W)
  local MIN_PATH_W = CFG.MIN_PATH_W   -- below this the path is hidden (the tooltip still shows it)
  UI.push_row_style(ctx)
  for _, i in ipairs(UI.library_order()) do
    shown = shown + 1
    local path = P.pdfs[i]
    ImGui.PushID(ctx, "lib" .. i)
    local active = Util.same_path(path, S.pdf_path) and R.total > 0
    local missing = (R.libexists[path] == false)
    local x = ImGui.GetCursorPosX(ctx)
    local aw = UI.panel_w(ctx)
    local rsx, rsy = ImGui.GetCursorScreenPos(ctx)
    local btns_x = x + aw - (EXP_W + BTN_W + 8) - 14
    if active then UI.row_highlight(ctx, aw) end
    -- one line: filename (pages) | path | Show in Explorer / red X (all on the same frame height)
    -- a click anywhere on the name / path area opens the PDF
    local pg = R.libpages[path]
    local label = Util.name_of(path) .. (pg and string.format("  (%d pp)", pg) or "")
    local space = btns_x - x - 8
    local clicked, hovered = UI.row_click_area(ctx, "##open", space)
    -- during playback the PDF on screen belongs to the song: a click does not open another one
    if clicked and not missing and not Util.playing() then Pane.active(PDF.open_pdf, path, false) end
    if hovered then
      ImGui.SetTooltip(ctx, missing and ("MISSING: " .. path)
        or (Util.playing() and (PLAYING_TIP .. "\n" .. path)) or ("Click to open\n" .. path))
    end
    -- two columns: the names share one width (at most half the space), so every path starts at the same x
    local col_w = math.min(R.lib_name_w.w, space) -- the name first; the path gets what is left (or hides)
    local txt = UI.trunc_text(ctx, label, math.max(20, col_w))
    UI.row_text(ctx, txt, (missing and COL.RED) or (Project.unused_pdfs()[path] and COL.TEXT_DIM) or nil) -- grey = unused
    local rel = P.rel[path]
    local pdir = Project.dir()
    local inside = rel and pdir and Util.rel_path(path, pdir)
    local path_w = space - col_w - 16
    if path_w >= MIN_PATH_W then
      -- inside the project folder: "<project folder name>/PDFs/file.pdf"; else the full path
      local path_txt = inside and ((Util.name_of((pdir:gsub("[/\\]+$", ""))) or "") .. "/" .. rel) or path
      ImGui.SameLine(ctx, x + col_w + 16)
      UI.row_text(ctx, UI.trunc_left(ctx, path_txt, path_w), COL.TEXT_DIM)
    end
    ImGui.SameLine(ctx, btns_x)
    if UI.row_button(ctx, "Show in Explorer", EXP_W, "ghost") then Util.show_in_explorer(path) end
    UI.tip(ctx, "Opens the folder of this PDF in Windows Explorer.")
    ImGui.SameLine(ctx)
    if UI.remove_x_button(ctx, "##remove", BTN_W) then UI.ask_remove_pdf(path) end
    -- right-click anywhere on the row: the PDF menu
    if ImGui.IsMouseClicked(ctx, 1) and UI.mouse_in_row(ctx, rsx, rsy, aw) then R.menu_req = { kind = "pdf", path = path } end
    UI.tip(ctx, "Remove this PDF from the library (asks first). The file is not deleted.")
    if missing then
      local dir, mrel = Project.dir(), P.rel[path]
      if dir and mrel then
        UI.wrapped(ctx, "Expected: " .. Util.join_path(dir, (mrel:gsub("/", "\\"))), COL.GREY)
      end
      UI.wrapped(ctx, "Old location: " .. path, COL.GREY)
      UI.wrapped(ctx, string.format("Used by %d region(s).", Project.region_use_count(path)), COL.YELLOW)
      if UI.button(ctx, "Relocate...", CFG.MEDIUM_BTN_W, 0) then relocate_path = path end
    end
    if R.ask and R.ask.key == path then UI.draw_ask(ctx, "lib_remove", path) end
    ImGui.PopID(ctx)
  end
  UI.pop_row_style(ctx)
  if #P.pdfs > 0 and shown == 0 then ImGui.TextDisabled(ctx, "No PDFs match the search.") end
  if relocate_path then
    local ok, f = r.GetUserFileNameForRead("", "Locate " .. Util.name_of(relocate_path), "pdf")
    if ok and f and f ~= "" then
      local found = Project.relocate_pdf(relocate_path, f)
      Msg.notify(string.format("Relocated %s.%s", Util.name_of(relocate_path),
        found > 0 and string.format(" Also found %d other missing PDF(s) in the same folder.", found) or ""), false, "library")
    end
  end

end

function UI.region_passes_filter(reg)
  local s = R.region_search
  if s and s ~= "" and not reg.name:lower():find(s:lower(), 1, true) then return false end
  local f = R.region_filter
  if f == 0 then return true
  elseif f == 1 then return reg.status == "unassigned" or reg.status == "ambiguous"
  elseif f == 2 then return reg.status == "auto" or reg.status == "assigned"
  else return reg.status == "ignored" end
end

-- Status of a region: label for the dropdown preview, dot colour, name colour, tooltip word.
function UI.region_look(reg)
  local st = reg.status
  if st == "auto" then
    return Util.name_of(reg.pdf) .. " (auto)", COL.GREEN, nil, "Auto-matched by name"
  elseif st == "assigned" then
    return Util.name_of(reg.pdf), COL.GREEN, nil, "Assigned"
  elseif st == "ignored" then
    return "(ignored)", COL.GREY, COL.GREY, "Ignored - no PDF"
  elseif st == "ambiguous" then
    return "(several PDFs match)", COL.YELLOW, COL.YELLOW, "Needs a PDF - several PDFs match"
  end
  return "(no PDF)", COL.YELLOW, COL.YELLOW, "Needs a PDF - no PDF yet"
end

-- One region row:  o Name  0:12 - 3:45            [ Song One.pdf (auto)  v ]
function UI.draw_region_row(ctx, i, reg)
  ImGui.PushID(ctx, "rg" .. i)
  local COMBO_W, DOT_W = CFG.REGION_COMBO_W, CFG.DOT_W
  local x = ImGui.GetCursorPosX(ctx)
  local aw = UI.panel_w(ctx)
  local rsx, rsy = ImGui.GetCursorScreenPos(ctx)
  if ImGui.IsMouseClicked(ctx, 1) and UI.mouse_in_row(ctx, rsx, rsy, aw) then R.menu_req = { kind = "region", key = reg.key } end
  if R.cur_region_key == reg.key then UI.row_highlight(ctx, aw) end
  local preview, dot_col, name_col, word = UI.region_look(reg)
  -- narrow panel: the time range goes first, then the "PDF 1" / "PDF 2" labels; the name stays
  -- (room for the labels on every row, so all dropdowns align; only while the full name still fits)
  local base_w = aw - DOT_W - COMBO_W - 24
  local name_w = R.region_name_w and R.region_name_w.w or 0
  local LBL_W = (base_w - UI.pdf_label_w(ctx) >= math.min(name_w, 160)) and UI.pdf_label_w(ctx) or 0
  local inline = (base_w - LBL_W) >= 90

  -- the whole row (except the PDF menu) is one click area: moves the edit cursor to the region
  local clicked, hovered = UI.row_click_area(ctx, "##rowsel", inline and (aw - COMBO_W - LBL_W - 24) or (aw - 14))
  if clicked and not Util.playing() then r.SetEditCurPos(reg.start, true, false) end
  if hovered then
    ImGui.SetTooltip(ctx, word .. "\n" .. (Util.playing() and PLAYING_TIP or "Click to move the edit cursor to the region start."))
  end

  -- status dot (every row has one, so all names stay aligned)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local fh = ImGui.GetFrameHeight(ctx)
  ImGui.Dummy(ctx, DOT_W, fh)
  -- shape + colour, so the state is clear also without colour vision:
  -- filled circle = has a PDF, ring = needs a PDF, dash = ignored
  local sdl, dcx, dcy = ImGui.GetWindowDrawList(ctx), sx + 5, sy + fh / 2
  if reg.status == "auto" or reg.status == "assigned" then
    ImGui.DrawList_AddCircleFilled(sdl, dcx, dcy, 4, dot_col)
  elseif reg.status == "ignored" then
    ImGui.DrawList_AddLine(sdl, dcx - 4, dcy, dcx + 4, dcy, dot_col, 2)
  else
    ImGui.DrawList_AddCircle(sdl, dcx, dcy, 4, dot_col, 0, 2)
  end

  -- name + time range; the dropdown goes to the next line in a narrow panel
  local text_w = inline and (aw - DOT_W - COMBO_W - LBL_W - 24) or (aw - DOT_W - 14)
  -- two columns: the names share one width, so every time range starts at the same x (left aligned)
  local times = Util.fmt_mmss(reg.start) .. " - " .. Util.fmt_mmss(reg.stop)
  local tw = ImGui.CalcTextSize(ctx, times)
  local show_times = name_w + tw + 16 <= text_w -- only when the whole name fits next to it
  local col_w = show_times and name_w or text_w
  local name = UI.trunc_text(ctx, reg.name ~= "" and reg.name or "(unnamed region)",
    math.max(20, show_times and col_w or text_w))
  ImGui.SameLine(ctx, 0, 0)
  UI.row_text(ctx, name, name_col)
  if show_times then
    ImGui.SameLine(ctx, x + DOT_W + col_w + 16)
    UI.row_text(ctx, times, COL.TEXT_DIM)
  end

  -- dropdown: always shows the result for this region; [+] after it adds the "PDF 2" row
  local two = reg.pdf2 ~= nil or R.add2[reg.key]
  local cx = inline and (x + aw - COMBO_W - 14) or (x + DOT_W + LBL_W) -- (the label room is left of cx)
  local cw = (inline and COMBO_W or (aw - DOT_W - LBL_W - 14)) - fh - 4
  if two and LBL_W > 0 then -- "PDF 1" / "PDF 2" left of the dropdowns (not in a narrow panel); same width
    if inline then ImGui.SameLine(ctx, cx - LBL_W) else ImGui.SetCursorPosX(ctx, cx - LBL_W) end
    UI.row_text(ctx, "PDF 1", COL.TEXT_DIM)
    ImGui.SameLine(ctx, cx)
  elseif inline then ImGui.SameLine(ctx, cx) else ImGui.SetCursorPosX(ctx, cx) end
  if UI.combo(ctx, "##assign", preview, cw) then
    local choice
    if ImGui.Selectable(ctx, "(auto-match by name)", not P.assign[reg.key] and not P.ignore[reg.key]) then choice = 0 end
    if ImGui.Selectable(ctx, "(ignore this region)", P.ignore[reg.key] == true) then choice = 1 end
    for _, j in ipairs(UI.pdfs_by_name()) do
      local p = P.pdfs[j]
      if not (reg.pdf2 and Util.same_path(p, reg.pdf2)) then -- PDF 2 is not offered as PDF 1
        local sel = P.assign[reg.key] and Util.same_path(p, P.assign[reg.key]) or false
        if ImGui.Selectable(ctx, Util.name_of(p) .. "##pdf" .. j, sel) then choice = j + 1 end
      end
    end
    ImGui.EndCombo(ctx)
    if choice then
      Project.set_region_choice(reg, (choice == 0 and "auto") or (choice == 1 and "ignore") or P.pdfs[choice - 1])
      if R.cur_region_key == reg.key then R.cur_region_key = nil end
    end
  end
  if reg.pdf then UI.tip(ctx, reg.pdf) end
  ImGui.SameLine(ctx, 0, 4)
  if two or not reg.pdf then
    ImGui.Dummy(ctx, fh, fh) -- keeps the column; [+] needs a PDF 1 first
  else
    if UI.row_icon_button(ctx, "##add2", fh, "plus") then
      -- 2 matching PDFs: the other one at once; else an empty row to choose from
      local other
      if #reg.cands == 2 then other = Util.same_path(reg.cands[1], reg.pdf) and reg.cands[2] or reg.cands[1] end
      if other and not Util.same_path(other, reg.pdf) then Project.set_pdf2(reg, other) else R.add2[reg.key] = true end
    end
    UI.tip(ctx, "Add a 2nd PDF for this song (for example a bass part next to the lyrics).\n"
      .. "Both are shown together during the song (Settings > Display > Split view).")
  end
  if two then UI.draw_pdf2_row(ctx, reg, cx, cw, fh, LBL_W) end
  ImGui.PopID(ctx)
end

-- Width of the "PDF 1" / "PDF 2" labels before the region dropdowns (measured once).
function UI.pdf_label_w(ctx)
  if not R.pdf_label_w then R.pdf_label_w = math.floor((ImGui.CalcTextSize(ctx, "PDF 2")) + 10) end
  return R.pdf_label_w
end

-- The library indexes sorted by file name (for the region dropdowns); rebuilt when the library changes.
function UI.pdfs_by_name()
  local c = R.pdfs_sorted
  if c and c.ver == R.lib_ver and c.P == P then return c.idx end
  local idx = {}
  for j = 1, #P.pdfs do idx[j] = j end
  table.sort(idx, function(a, b) return Util.name_of(P.pdfs[a]):lower() < Util.name_of(P.pdfs[b]):lower() end)
  R.pdfs_sorted = { ver = R.lib_ver, P = P, idx = idx }
  return idx
end

-- The "PDF 2" row under a region: its dropdown and an x that removes PDF 2 from the song.
function UI.draw_pdf2_row(ctx, reg, cx, cw, fh, lbl_w)
  if lbl_w > 0 then -- the label (not in a narrow panel)
    ImGui.SetCursorPosX(ctx, cx - lbl_w)
    UI.row_text(ctx, "PDF 2", COL.TEXT_DIM)
    ImGui.SameLine(ctx, cx)
  else ImGui.SetCursorPosX(ctx, cx) end
  local name = reg.pdf2 and Util.name_of(reg.pdf2) or "(choose a PDF)"
  if UI.combo(ctx, "##assign2", name, cw) then
    local pick
    for _, j in ipairs(UI.pdfs_by_name()) do
      local p = P.pdfs[j]
      if not (reg.pdf and Util.same_path(p, reg.pdf)) then -- PDF 1 is not offered as PDF 2
        local sel = reg.pdf2 and Util.same_path(p, reg.pdf2) or false
        if ImGui.Selectable(ctx, Util.name_of(p) .. "##pdf2_" .. j, sel) then pick = p end
      end
    end
    ImGui.EndCombo(ctx)
    if pick then Project.set_pdf2(reg, pick) end
  end
  if reg.pdf2 then UI.tip(ctx, reg.pdf2) end
  ImGui.SameLine(ctx, 0, 4)
  if UI.remove_x_button(ctx, "##rm2", fh) then Project.set_pdf2(reg, nil) end
  UI.tip(ctx, "Remove PDF 2 from this song (the file is not deleted)")
end

function UI.draw_regions_tab(ctx)
  local ch

  if UI.heading(ctx, "Region settings", "Switch PDF at regions: the PDF changes when the play cursor "
    .. "(or the edit cursor while stopped) enters a region that has a PDF.\n\n"
    .. "Saved in this project, except 'Keep last page': saved on this computer (the same for all your projects).", nil, "rgn_settings") then
    ch, P.auto_switch = UI.checkbox(ctx, "Switch PDF at regions", P.auto_switch)
    if ch then
      Util.mark_pdirty()
      if P.auto_switch then R.cur_region_key = nil -- re-evaluate the region under the play cursor
      else Project.restore_stash() end
    end
    UI.tip(ctx, "The PDF changes when the play cursor enters a region that has a PDF.")
    ch, P.pair_off = UI.checkbox(ctx, "Pair 2 matching PDFs", not P.pair_off)
    P.pair_off = not P.pair_off
    if ch then
      if not P.pair_off then P.no2 = {} end -- turned on: also for the songs where PDF 2 was removed
      Util.mark_pdirty(); Project.resolve_regions(); R.cur_region_key = nil
    end
    UI.tip(ctx, "When exactly 2 PDFs match a song (for example \"Song A lyrics\" and \"Song A bass\"),\n"
      .. "both are used: PDF 1 and PDF 2, shown together. Not when one has exactly the song's name\n"
      .. "(\"Song A\" + \"Song A lyrics\"): that one is the main chart; + adds the other. Saved in this project.")
    ch, S.keep_last_page = UI.checkbox(ctx, "Keep last page", S.keep_last_page)
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "During playback, a region without a PDF keeps the last page on screen, with a yellow note at the top.\n"
      .. "When playback stops, the region's buttons (add a PDF, choose, ignore) are shown.")
    UI.section_msg(ctx, "regions")
  end -- "Region settings" open

  UI.group_sep(ctx)
  UI.heading(ctx, string.format("Region list (%d)", #R.regions), "A region gets the PDF with the same name, for example \"Song One\" and \"01 Song One (Bb).pdf\". "
    .. "The full rules are in Help > Regions.\n\n"
    .. "Symbol: green filled circle = has a PDF, yellow ring = needs a PDF, grey dash = ignored.\n"
    .. "Blue row = the region at the play cursor (edit cursor when stopped).\n"
    .. "Click a row to move the edit cursor to the region start.", "project")
  if #R.regions == 0 then ImGui.TextDisabled(ctx, "No regions in this project."); return end
  -- search + "Show" menu, the same row as in the Library (menu text rebuilt only when a count changes)
  local c = UI.region_counts()
  local ck = c.all .. "," .. c.need .. "," .. c.assigned .. "," .. c.ignored
  if not R.region_show or R.region_show.key ~= ck then
    R.region_show = { key = ck, items = string.format("Show: all (%d)\0Show: needs PDF (%d)\0Show: assigned (%d)\0Show: ignored (%d)\0",
      c.all, c.need, c.assigned, c.ignored) }
  end
  R.region_search, R.region_filter = UI.search_row(ctx, "rgn", R.region_search, "Search regions...",
    R.region_filter, R.region_show.items)
  -- name column width: the widest region name, measured only when the region list changes
  -- (Project.scan_project makes a new R.regions table)
  if not R.region_name_w or R.region_name_w.regs ~= R.regions then
    local w = 0
    for _, rg in ipairs(R.regions) do
      w = math.max(w, (ImGui.CalcTextSize(ctx, rg.name ~= "" and rg.name or "(unnamed region)")))
    end
    R.region_name_w = { regs = R.regions, w = w }
  end
  UI.push_row_style(ctx)
  for i, reg in ipairs(R.regions) do
    if UI.region_passes_filter(reg) then UI.draw_region_row(ctx, i, reg) end
  end
  UI.pop_row_style(ctx)
end
-- Red border around the last item, with the reason as its tooltip.
function UI.mark_invalid(ctx, reason)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  ImGui.DrawList_AddRect(ImGui.GetWindowDrawList(ctx), x0, y0, x1, y1, COL.RED, 4, 0, 1.5)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, reason .. "\nType a correct value, or press Esc to keep the old one.") end
end

-- Small round remove button: a red ring with a red X; filled red with a white X on hover.
-- Drawn with lines (not a font glyph), so it looks the same with every font.
function UI.remove_x_button(ctx, id, size)
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

-- Small square row button with a drawn icon ("plus", or "view": a page with the visible part filled);
-- a grey background on hover, like the remove button's hover.
function UI.row_icon_button(ctx, id, size, kind, lit)
  local hit = ImGui.InvisibleButton(ctx, id, size, size)
  local hov = ImGui.IsItemHovered(ctx)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  if hov then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
    ImGui.DrawList_AddRectFilled(dl, x0 + 2, y0 + 2, x0 + size - 2, y0 + size - 2, COL.BTN_HOVER, 4)
  end
  local cx, cy = math.floor(x0 + size / 2) + 0.5, math.floor(y0 + size / 2) + 0.5
  local col = hov and COL.TEXT_BRIGHT or (lit and COL.TEXT_MAIN) or COL.TEXT_DIM
  if lit == false then col = (COL.TEXT_DIM & 0xFFFFFF00) | 0x60 end -- not available now: faint
  if kind == "sync" then -- the usual refresh symbol: a circular arrow (3/4 of a circle) with one head
    local rad, a0, a1 = 5.5, math.pi * -0.35, math.pi * 1.25
    ImGui.DrawList_PathArcTo(dl, cx, cy, rad, a0, a1)
    ImGui.DrawList_PathStroke(dl, col, 0, 1.7)
    -- the head at the end of the arc, pointing on along the circle (clockwise on screen)
    local ex, ey = cx + math.cos(a1) * rad, cy + math.sin(a1) * rad
    local tx, ty = -math.sin(a1), math.cos(a1) -- direction of the arc at its end
    local nx, ny = math.cos(a1), math.sin(a1)  -- outwards
    ImGui.DrawList_AddTriangleFilled(dl, ex + tx * 3.5, ey + ty * 3.5,
      ex - tx * 1 + nx * 3, ey - ty * 1 + ny * 3, ex - tx * 1 - nx * 3, ey - ty * 1 - ny * 3, col)
  elseif kind == "undo" or kind == "redo" then -- a curved arrow (to the left for undo, to the right for redo)
    local d = (kind == "undo") and -1 or 1
    ImGui.DrawList_PathArcTo(dl, cx, cy + 2, 5, math.pi, 2 * math.pi)
    ImGui.DrawList_PathStroke(dl, col, 0, 1.6)
    local ex = cx + d * 5 -- the arrow head: left end (undo) or right end (redo)
    ImGui.DrawList_PathLineTo(dl, ex - 3, cy - 0.5)
    ImGui.DrawList_PathLineTo(dl, ex, cy + 2.5)
    ImGui.DrawList_PathLineTo(dl, ex + 3, cy - 0.5)
    ImGui.DrawList_PathStroke(dl, col, 0, 1.6)
  elseif kind == "view" then
    ImGui.DrawList_AddRect(dl, cx - 5, cy - 6.5, cx + 5, cy + 6.5, col, 1.5, 0, 1.5)
    ImGui.DrawList_AddRectFilled(dl, cx - 3, cy - 2, cx + 3, cy + 2, col)
  else
    UI.draw_tb_icon(dl, cx, cy, kind, col)
  end
  return hit
end

local CUE_START = { pos = 0, page = 1, scroll = 0 } -- the fixed Start row (never changed)

-- Rows of one cue list (shared by the single-song view and the "(all songs)" view).
-- first: the number of the first row (in "(all songs)" the numbers run on across the songs);
-- total: the highest number in the whole view, so every song's "#" column has the same width
function UI.draw_cue_rows(ctx, reg, list, first, total)
  local POS_W, NUM_W = 120, 70
  first = first or 1
  local key = Cues.key(reg)
  -- the cue that plays now (blue row)
  local now_i
  if Util.playing() and Cues.key(Cues.playing_region()) == key then
    local p = Cues.from_time(reg, r.GetPlayPosition())
    now_i = 0 -- before the first cue: the Start row
    for i, c in ipairs(list) do if c.pos <= p + 1e-6 then now_i = i end end
  end
  -- columns, like an event list: # at the left | Position, Page, Scroll %, view, + centred | X at the right
  -- (x relative to x0; the rows use the full panel width, like the other lists)
  local IDX_W = math.max(28, (ImGui.CalcTextSize(ctx, tostring(total or (first + #list - 1)))) + 14)
  local fh = UI.h(ctx)
  local G = 12 -- the same gap between all columns
  local MID_W = POS_W + NUM_W * 2 + 3 * G + 2 * fh + 2
  local TABLE_W = math.max(IDX_W + MID_W + fh + 16, UI.panel_w(ctx) - 12)
  local POS_X = math.max(IDX_W, math.floor((TABLE_W - MID_W) / 2))
  local PAGE_X = POS_X + POS_W + G
  local SCROLL_X = PAGE_X + NUM_W + G
  local VIEW_X = SCROLL_X + NUM_W + G
  local ADD_X, DEL_X = VIEW_X + fh + 2, TABLE_W - fh
  local x0 = ImGui.GetCursorPosX(ctx)
  UI.row_text(ctx, "#", COL.TEXT_DIM)
  ImGui.SameLine(ctx, x0 + POS_X); UI.row_text(ctx, "Position", COL.TEXT_DIM)
  UI.tip(ctx, P.cue_unit == "seconds" and "Time from the song start (m:ss)." or "Bar.beat from the song start.")
  ImGui.SameLine(ctx, x0 + PAGE_X); UI.row_text(ctx, "Page", COL.TEXT_DIM)
  ImGui.SameLine(ctx, x0 + SCROLL_X); UI.row_text(ctx, "Scroll %", COL.TEXT_DIM)
  if first == 1 then ImGui.SameLine(ctx, x0 + VIEW_X); UI.draw_undo_redo(ctx) end -- once, above the first list
  local remove_i, below_i, moved
  -- One cue field. `apply(raw)` saves a valid value and returns nil, or returns the reason it is
  -- not accepted: then the typed text stays, with a red border (no silent revert). Esc keeps the old value.
  local function cue_field(k, label, w, shown, apply)
    ImGui.SetNextItemWidth(ctx, w)
    local ch, txt = ImGui.InputText(ctx, label, R.cue_err[k] and R.cue_text[k] or shown)
    if ch then R.cue_text[k] = txt end
    if ImGui.IsItemDeactivated(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape(), false) then
      R.cue_err[k], R.cue_text[k] = nil, nil
    elseif ImGui.IsItemDeactivatedAfterEdit(ctx) then
      local snap = Cues.copy()
      local e = apply(Util.trim(R.cue_text[k] or ""))
      if e then R.cue_err[k] = e else R.cue_err[k], R.cue_text[k] = nil, nil; Cues.save_undo(snap) end
    end
    if R.cue_err[k] then UI.mark_invalid(ctx, R.cue_err[k]) end
  end
  -- the fixed "Start" row (index 0): page 1 at the top from the song start; shown when no cue is at
  -- the start. It is not saved; a change in it adds a real cue at the start.
  local has_start = list[1] and math.abs(list[1].pos) < CFG.CUE_SAME_POS
  local shift = has_start and 0 or 1 -- the Start row takes number `first`; the cues follow
  local function row(i, c)
    local is_start = (i == 0)
    ImGui.PushID(ctx, "cue" .. key .. i)
    ImGui.SetCursorPosX(ctx, x0)
    if i == now_i then UI.row_highlight(ctx, TABLE_W + 16) end
    local id = key .. ":" .. i
    -- the whole row is a click area (under the fields and buttons): moves the edit cursor to the cue
    do
      local sx, sy = ImGui.GetCursorScreenPos(ctx)
      if ImGui.IsMouseClicked(ctx, 1) and UI.mouse_in_row(ctx, sx, sy, TABLE_W) then -- right-click: the cue menu
        R.menu_req = { kind = "cue", reg = reg, list = list, i = i, c = c, part = R.cue_part_ctx }
      end
      ImGui.SetNextItemAllowOverlap(ctx)
      if ImGui.InvisibleButton(ctx, "##rowsel", TABLE_W, fh) and not Util.playing() then
        r.SetEditCurPos(Cues.to_time(reg, c.pos), true, false)
      end
      if ImGui.IsItemHovered(ctx) then
        ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), sx - 6, sy - 2, sx + TABLE_W + 6, sy + fh + 2, COL.ROW_HOVER, 4)
        ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
        ImGui.SetTooltip(ctx, Util.playing() and PLAYING_TIP
          or (is_start and "Song start: page 1, at the top. Click to move the edit cursor here.")
          or "Click to move the edit cursor to this cue.")
      end
      ImGui.SetCursorScreenPos(ctx, sx, sy)
    end
    -- number of the row in this list (the Start row is number 1 when it is shown)
    UI.row_text(ctx, tostring(first + i - 1 + shift), COL.TEXT_DIM)
    -- position (the Start row: a fixed label)
    ImGui.SameLine(ctx, x0 + POS_X)
    if is_start then
      UI.row_text(ctx, "Start", COL.TEXT_DIM)
    else
      cue_field(id .. "p", "##pos", POS_W, Cues.label(reg, c.pos), function(raw)
        local v = Cues.parse_label(reg, raw)
        if not v then return "Position not understood. Use bar.beat (e.g. 9.1.00) or m:ss (e.g. 0:24.5)." end
        c.pos = v; Cues.sort(list); Util.mark_pdirty(); moved = true
      end)
    end
    -- page (checked against the page count of this song's PDF)
    ImGui.SameLine(ctx, x0 + PAGE_X)
    cue_field(id .. "g", "##page", NUM_W, c.page and tostring(c.page) or "", function(raw)
      if raw == "" then
        if is_start then return "The start needs a page." end
        c.page = nil; Util.mark_pdirty(); return
      end
      local v, maxp = tonumber(raw), Cues.max_page(reg)
      if not v or v < 1 then return "The page must be a number from 1." end
      if maxp and v > maxp then return string.format("This PDF has only %d page(s).", maxp) end
      if is_start then Cues.put(reg, 0, math.floor(v), c.scroll); moved = true; return end
      c.page = math.floor(v); Util.mark_pdirty()
    end)
    UI.tip(ctx, is_start and "Page at the song start. Change it to add a cue at the start."
      or "Page to show from this cue. Empty = keep the page.")
    -- scroll (an empty field removes the scroll point; a wrong value never does)
    ImGui.SameLine(ctx, x0 + SCROLL_X)
    cue_field(id .. "s", "##scroll", NUM_W, c.scroll and string.format("%g", c.scroll) or "", function(raw)
      if raw == "" then
        if is_start then return "The start needs a scroll position (0 = top)." end
        c.scroll = nil; Util.mark_pdirty(); return
      end
      local v = tonumber((raw:gsub("%%$", "")))
      if not v or v < 0 or v > 100 then return "Scroll must be a number from 0 to 100." end
      if is_start then Cues.put(reg, 0, c.page, v); moved = true; return end
      c.scroll = v; Util.mark_pdirty()
    end)
    UI.tip(ctx, "Scroll position at this cue: 0 = top, 100 = bottom. Empty = no scroll point.\n"
      .. "Between two scroll points the page moves smoothly, or jumps (Settings > Autoscroll > Scroll).")
    -- use current view | add a scroll point below | remove (not for the Start row)
    ImGui.SameLine(ctx, x0 + VIEW_X)
    if UI.row_icon_button(ctx, "##view", fh, "view") then
      if is_start then
        if R.total > 0 then Cues.save_undo(); Cues.put(reg, 0, S.page, Cues.view_scroll()); moved = true end
      else Cues.use_view(c) end
    end
    UI.tip(ctx, "Use current view: this cue gets the page and the scroll position shown now.")
    ImGui.SameLine(ctx, x0 + ADD_X)
    if UI.row_icon_button(ctx, "##below", fh, "plus") then below_i = i end
    UI.tip(ctx, "Add a scroll point below: halfway to the next cue, on this cue's page,\n"
      .. "with the scroll position shown now. Then correct its values if needed.")
    if not is_start then
      ImGui.SameLine(ctx, x0 + DEL_X)
      if UI.remove_x_button(ctx, "##del", fh) then remove_i = i end
      UI.tip(ctx, "Remove this cue")
    end
    ImGui.PopID(ctx)
  end
  UI.push_row_style(ctx)
  if not has_start then row(0, CUE_START) end
  for i, c in ipairs(list) do row(i, c) end
  UI.pop_row_style(ctx)
  if remove_i then Cues.remove(reg, remove_i)
  elseif below_i then Cues.add_below(reg, P.cues[key] or list, below_i) end
  -- rows changed place: field states are stored by row number, so they would point to other cues
  if remove_i or below_i or moved then R.cue_err, R.cue_text = {}, {} end
  return #list + shift -- rows shown
end

-- Bar above the cue list: Record (R) in the label column | toggle | Add page turn | Add scroll point.
-- Only usable in the Cue list mode.
function UI.draw_cue_bar(ctx)
  local can = Nav.scroll_mode() == "cues"
  local function tip(t)
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, can and t or "Works only in the Cue list mode (toolbar or 'Use Cue list mode' above).")
    end
  end
  -- "Record (R)" in the label column (like "Count time in"); the toggle and the buttons after it
  local label = (R.part2 and R.active_part == 2) and "Record (R) -> PDF 2" or "Record (R)"
  local _, cx, _, wide = UI.form(ctx, "Record (R) -> PDF 2") -- the same column for both texts
  ImGui.BeginDisabled(ctx, not can)
  UI.label(ctx, label)
  if can and ImGui.IsItemClicked(ctx) then UI.toggle_rec() end
  tip("Record cues: while on, the C and S keys and the MIDI cue buttons add cues.\nNot saved: it is off when Chart Cue starts.")
  if wide then ImGui.SameLine(ctx) end
  ImGui.SetCursorPosX(ctx, cx)
  local ch, nv = UI.toggle(ctx, "##cuerec", R.rec)
  if ch and nv ~= R.rec then UI.toggle_rec() end
  tip("Record cues: while on, the C and S keys and the MIDI cue buttons add cues.\nNot saved: it is off when Chart Cue starts.")
  ImGui.EndDisabled(ctx)
  -- the add buttons: only while Record is on (greyed out otherwise), like the C and S keys
  local on = can and R.rec
  ImGui.SameLine(ctx, 0, 12)
  -- the 2 add buttons: the standard width (smaller only in a narrow panel)
  local abw = UI.std_w(ctx, "Add scroll point", math.floor((UI.panel_w(ctx) - 12 - 8) / 2))
  ImGui.BeginDisabled(ctx, not on)
  local pnc, pnv = UI.push_kind(ctx, "primary")
  if UI.button(ctx, "Add page turn", abw, UI.h(ctx)) and on then UI.record_cue(Cues.add_page_turn) end
  local function add_tip(t)
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, (not can and "Works only in the Cue list mode (toolbar or 'Use Cue list mode' above).")
        or (not on and "Turn on Record first.") or t)
    end
  end
  add_tip("Add page turn (C key): the next page after the cue before it, at the top.\n"
    .. "Added at the play cursor, in the current song.")
  ImGui.SameLine(ctx, 0, 8)
  if UI.button(ctx, "Add scroll point", abw, UI.h(ctx)) and on then UI.record_cue(Cues.add_scroll_point) end
  add_tip("Add scroll point (S key): the same page as the cue before it, at the current scroll position.\n"
    .. "Added at the play cursor, in the current song.")
  UI.pop_kind(ctx, pnc, pnv)
  ImGui.EndDisabled(ctx)
end

-- Undo / redo of cue changes: at the right end of the cue list's column titles (above the row icons).
function UI.draw_undo_redo(ctx)
  local fh = UI.h(ctx)
  local u = Cues.can_undo()
  ImGui.BeginDisabled(ctx, not u)
  if UI.row_icon_button(ctx, "##undo", fh, "undo", u) and u then Cues.undo() end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, u and "Undo: takes back the last cue change (Ctrl+Z in the Chart Cue window)." or "Nothing to undo.")
  end
  ImGui.SameLine(ctx, 0, 2)
  local rd = Cues.can_redo()
  ImGui.BeginDisabled(ctx, not rd)
  if UI.row_icon_button(ctx, "##redo", fh, "redo", rd) and rd then Cues.redo() end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, rd and "Redo: brings back the change that Undo took back (Ctrl+Shift+Z)." or "Nothing to redo.")
  end
end

-- The add buttons record into the active part, like the C / S keys (not into the list the tab shows).
function UI.record_cue(fn)
  local keep = R.cue_part_ctx
  R.cue_part_ctx = nil
  local ok, err = pcall(Pane.active, fn)
  R.cue_part_ctx = keep
  if not ok then error(err, 0) end
end

-- Cues tab: "Cue settings" (unit, song, tools) and the "Cue list" with its bar.
function UI.draw_cue_list(ctx)
  local ch
  -- section 1: cue settings (unit, song, tools; can be closed); section 2 below: the cue list itself
  local open = UI.heading(ctx, "Cue settings", "A cue list does the same as PDF markers (PDFPAGE / PDFSCROLL), but it is stored in the project "
    .. "data, not as markers. Use it when another program (for example a setlist program) must not see extra markers.\n\n"
    .. "Easiest way: turn on 'Record' (R), play the song and press 'Add page turn' (C key) at each page turn, and 'Add scroll point' "
    .. "(S key) where the page must move. A MIDI button can do the same (Settings > MIDI).\n\n"
    .. "Each song (region) has its own cues. The times are counted from the region start, so the cues move with the region.\n"
    .. "Beats: a cue stays on its bar and beat when the tempo changes. Seconds: a cue stays at its time.", "project", "cue_settings")
  if open then -- fold block 1: mode note, unit, song menu
    -- not in the Cue list mode: say so first, with a one-click fix (blue, like the other main buttons)
    if Nav.scroll_mode() ~= "cues" then
      UI.note(ctx, "The autoscroll mode is not Cue list. The cues do not move the page.", COL.YELLOW)
      ImGui.BeginDisabled(ctx, Util.playing())
      if UI.full_button(ctx, "Use Cue list mode", "primary") and not Util.playing() then Nav.set_scroll_mode("cues") end
      ImGui.EndDisabled(ctx)
      if Util.playing() and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
        ImGui.SetTooltip(ctx, MODE_LOCKED_TIP)
      end
    end

    -- unit (per project)
    UI.field(ctx, "Count time in")
    local ui = (P.cue_unit == "seconds") and 1 or 0
    ch, ui = ImGui.Combo(ctx, "##cueunit", ui, "Beats (bar.beat)\0Seconds\0")
    if ch then Cues.set_unit(ui == 1 and "seconds" or "beats") end
    UI.tip(ctx, "Saved with this project. Existing cues keep their place when you switch.")

    -- which song: (all songs), (current song), each region, (whole project) when needed.
    -- "Current song" = the region at the play cursor during playback, at the edit cursor when stopped
    -- (REAPER's names for the two cursors), see Project.time_pos.
    local entries = { { label = "(all songs)", key = "_all" }, { label = "(current song)", key = nil } }
    for _, rg in ipairs(R.regions) do
      entries[#entries + 1] = { label = (rg.name ~= "" and rg.name or "(unnamed region)"), key = rg.key, reg = rg }
    end
    local proj_cues = P.cues["_project"] and #P.cues["_project"] > 0
    if #R.regions == 0 or proj_cues then
      entries[#entries + 1] = { label = "(whole project, no region)", key = "_project" }
    end
    local sel, labels = 1, {}
    for i, e in ipairs(entries) do
      labels[i] = e.label
      if e.key == R.cue_edit_key then sel = i - 1 end
    end
    UI.field(ctx, "Song")
    ch, sel = ImGui.Combo(ctx, "##cuereg", sel, table.concat(labels, "\0") .. "\0")
    if ch then R.cue_edit_key = entries[sel + 1].key end
    UI.tip(ctx, "(current song): the song at the play cursor during playback, at the edit cursor when stopped.\n"
      .. "(all songs) shows the cues of every song, with the song name above each list.\n"
      .. "(whole project, no region) is only for projects without regions.")
    -- "(current song)": which song that is, next to the menu (below it when there is no room)
    if R.cue_edit_key == nil then
      local cur = Project.region_at(Project.time_pos())
      local txt = "Editing: " .. (cur and (cur.name ~= "" and cur.name or "(unnamed region)") or "whole project (no region)")
      local free = ImGui.GetWindowPos(ctx) + ImGui.GetWindowWidth(ctx) - 12 - (ImGui.GetItemRectMax(ctx) + 10)
      if free >= 80 then
        ImGui.SameLine(ctx, 0, 10)
        UI.row_text(ctx, UI.trunc_text(ctx, txt, free), COL.TEXT_DIM)
      else
        UI.note(ctx, txt, COL.TEXT_DIM)
      end
    end
  end -- fold block 1

  -- the song shown below: worked out also when "Cue settings" is closed
  local all = (R.cue_edit_key == "_all")
  local reg
  if not all then
    if R.cue_edit_key == nil then
      reg = Project.region_at(Project.time_pos())
    elseif R.cue_edit_key ~= "_project" then
      reg = Project.region_by_key(R.cue_edit_key)
      if not reg then R.cue_edit_key = "_all" end -- the region was deleted: back to the default
    end
  end
  if open then -- fold block 2: recording, tools, questions, messages
    -- the rare tools in one menu: markers (copy | remove) first, then the most dangerous action last
    local song = all and "_all" or Cues.key(reg) -- an open question closes when the song changes
    local c1, c2, c3
    local _, _, more_w = UI.form(ctx, "More actions")
    UI.field(ctx, "More actions")
    if UI.combo(ctx, "##cuemore", "Choose...", more_w) then
      c1 = ImGui.Selectable(ctx, "Copy markers into cues")
      UI.tip(ctx, all and "Copies the PDF markers of every song into its cue list."
        or "Copies the PDF markers of this song into its cue list.")
      ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
      c3 = ImGui.Selectable(ctx, "Remove PDF markers...")
      UI.tip(ctx, (all and "All songs: " or "This song: ")
        .. "removes only markers named PDFPAGE ... or PDFSCROLL ... (one undo step).\n"
        .. "Use it after 'Copy markers into cues', so a setlist program sees no extra markers.")
      c2 = ImGui.Selectable(ctx, "Remove all cues...")
      ImGui.PopStyleColor(ctx) -- always paired with PushStyleColor above
      ImGui.EndCombo(ctx)
    end
    if c1 then Cues.copy_markers(all, reg) end
    if c2 then
      local key = song
      local count = 0
      if all then for _, l in pairs(P.cues) do count = count + #l end else count = #Cues.list(reg) end
      if count == 0 then
        Msg.notify("There are no cues to remove.", false, "cues")
      else
        local what = all and "all songs" or (reg and ('"' .. reg.name .. '"') or "the whole project")
        UI.ask("cues_all", string.format("Remove all %d cue(s) of %s? Undo can bring them back.", count, what),
          "Yes, remove", function()
            Cues.remove_all(key)
            Msg.notify(string.format("%d cue(s) removed.", count), false, "cues")
          end, song)
      end
    end
    -- remove the PDF markers of this song (or of all songs) - e.g. after copying them into cues
    if c3 then
      if all or not reg then UI.ask_remove_markers("cue_markers", -math.huge, math.huge, "the whole project", song)
      else UI.ask_remove_markers("cue_markers", reg.start, reg.stop, '"' .. reg.name .. '"', song) end
    end
    UI.draw_ask(ctx, "cues_all", song)
    UI.draw_ask(ctx, "cue_markers", song)
  end -- fold block 2

  -- section 2: the cue list, with its own heading
  UI.group_sep(ctx)
  -- the cues shown below: this song, or every song for "(all songs)" (only songs that still exist,
  -- so the count matches the rows; cues of a deleted region are not shown)
  -- a song with 2 PDFs: the list of PDF 1 or PDF 2 (R.cue_edit_part, the "PDF" dropdown below)
  -- PDF 2 on screen: the list follows the active part (a click on a part changes both)
  local edit_part = (R.part2 and (R.active_part or 1)) or (R.cue_edit_part or 1)
  R.cue_part_ctx = (not all and reg and reg.pdf2 and edit_part == 2) and 2 or 1
  -- (the count includes the Start row of each song that shows one, like the row numbers)
  local function rows_of(rg, always)
    local l = Cues.list(rg)
    if #l == 0 and not always then return 0 end
    return #l + ((l[1] and math.abs(l[1].pos) < CFG.CUE_SAME_POS) and 0 or 1)
  end
  local ncues = 0
  if all then
    for _, rg in ipairs(R.regions) do ncues = ncues + rows_of(rg) end
    ncues = ncues + rows_of(nil)
  else
    ncues = rows_of(reg, true)
  end
  UI.heading(ctx, string.format("Cue list (%d)", ncues), "Type a new position, page or scroll value to change a cue; click the red X to remove it.\n"
    .. "A red border means the value is not accepted: move the mouse over it to see why, then correct it or press Esc.\n"
    .. "Blue row = the cue that plays now. Click a row to move the edit cursor to its cue.\n"
    .. "Page icon: the cue gets the page and scroll position shown now. +: adds a scroll point below the cue.\n\n"
    .. "Record (R): while on, the C and S keys and the MIDI cue buttons add cues.\n"
    .. "The two add buttons do the same as C and S; they work while Record is on.\n"
    .. "Undo (Ctrl+Z in the Chart Cue window) takes back the last cue change.\n"
    .. "Start row: each song starts on page 1 at the top. Change it, and it becomes a cue.", "project")
  UI.heading_msg(ctx, "cues") -- in the title line, so the list never moves
  UI.draw_cue_bar(ctx)

  if all then
    local shown, num = 0, 1 -- num: the number of the next cue (runs on across the songs)
    local function block(rg, title)
      local list = Cues.list(rg)
      if #list == 0 then return end
      shown = shown + 1
      UI.song_title(ctx, title, rg)
      num = num + UI.draw_cue_rows(ctx, rg, list, num, ncues)
    end
    for _, rg in ipairs(R.regions) do block(rg, rg.name ~= "" and rg.name or "(unnamed region)") end
    block(nil, "(whole project, no region)")
    if shown == 0 then
      UI.note(ctx, "No cues yet. Turn on Record, play a song and press 'Add page turn' (C) at each page turn.", COL.GREY)
    end
    return
  end
  local list = Cues.list(reg)
  UI.song_title(ctx, reg and (reg.name ~= "" and reg.name or "(unnamed region)") or "(whole project, no region)", reg)
  if reg and reg.pdf2 then -- a song with 2 PDFs: which one's cues, in the title line
    ImGui.SameLine(ctx, 0, 16) -- (the title row has the control height: the dropdown lines up)
    local pdf_w = math.min(260, math.max(120, UI.panel_w(ctx) - (ImGui.GetCursorPosX(ctx)) - 12))
    if UI.combo(ctx, "##cuepart", (R.cue_part_ctx == 2) and ("PDF 2: " .. Util.name_of(reg.pdf2)) or ("PDF 1: " .. Util.name_of(reg.pdf)), pdf_w) then
      local pick
      if ImGui.Selectable(ctx, "PDF 1: " .. Util.name_of(reg.pdf), R.cue_part_ctx ~= 2) then pick = 1 end
      if ImGui.Selectable(ctx, "PDF 2: " .. Util.name_of(reg.pdf2), R.cue_part_ctx == 2) then pick = 2 end
      ImGui.EndCombo(ctx)
      if pick then
        R.cue_edit_part = pick; R.cue_err, R.cue_text = {}, {}
        if R.part2 then R.active_part = pick end -- on screen: that PDF becomes the active part too
      end
    end
    UI.tip(ctx, "This song has 2 PDFs: each one has its own cues. Record (C, S) adds cues to the\n"
      .. "PDF with the blue frame (click it on the page). Markers move only PDF 1.")
  end
  -- also without cues: the Start row. PDF 2 on screen: its rows run as part 2 ("Use current view" = its view)
  if R.cue_part_ctx == 2 and R.part2 then Pane.part2(UI.draw_cue_rows, ctx, reg, list)
  else UI.draw_cue_rows(ctx, reg, list) end
  if #list == 0 then
    UI.note(ctx, "No cues yet. Turn on Record, play the song and press 'Add page turn' (C) at each page turn, "
      .. "and 'Add scroll point' (S) where the page must move.", COL.GREY)
  end
end
function UI.draw_autoscroll_tab(ctx)
  local ch
  UI.heading(ctx, "Mode", "The autoscroll mode is in the toolbar ('Scroll: ...'). It is saved in this project, "
    .. "like Turn pages and Scroll.\n"
    .. "Default for new projects: saved on this computer (the mode of a project where you have not chosen one).\n\n"
    .. "Turn pages: show the next page a little before its page turn (PDFPAGE marker or page-turn cue), "
    .. "so you can read ahead.\n"
    .. "Scroll: Smooth moves the page slowly from one scroll point to the next; Jump goes to each scroll point at its time.\n\n"
    .. "Markers mode: PDFPAGE n turns to page n, at the top. PDFSCROLL 0..100 sets the scroll position "
    .. "(0 = top, 100 = bottom). "
    .. "At the same time, PDFSCROLL wins. Marker names are case-insensitive. "
    .. "The markers inside a region work from the region start to the region end.")
  -- the mode itself is chosen in the toolbar
  local mode = Nav.scroll_mode()
  -- default for projects that have no mode of their own (S.scroll_mode), saved on this computer
  local di = 0
  for i, m in ipairs(SCROLL_MODES) do if m == S.scroll_mode then di = i - 1 end end
  UI.field(ctx, "Default for new projects")
  ch, di = ImGui.Combo(ctx, "##ascrolldef", di, SCROLL_ITEMS)
  if ch then S.scroll_mode = SCROLL_MODES[di + 1]; Util.mark_dirty() end
  UI.tip(ctx, "The mode of a project where you have not chosen a mode yet.")
  -- turn pages early (Markers and Cue list), saved in this project like the mode; greyed out when off
  local EARLY = { 0, 0.5, 1, 2 }
  local ei = 0
  for i, v in ipairs(EARLY) do if math.abs(P.turn_early - v) < 1e-6 then ei = i - 1 end end
  ImGui.BeginDisabled(ctx, mode == "off")
  UI.field(ctx, "Turn pages")
  local ech
  ech, ei = ImGui.Combo(ctx, "##turnearly", ei, "On time\0Half a beat early\0One beat early\0Two beats early\0")
  if ech then P.turn_early = EARLY[ei + 1]; Util.mark_pdirty() end
  ImGui.EndDisabled(ctx)
  local off_tip = (mode == "off") and "Autoscroll is off: choose a mode in the toolbar first.\n" or ""
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, off_tip .. "Shows the next page a little before its page turn, so you can read ahead.\n"
      .. "The new page starts at the top. Saved in this project.")
  end
  -- scroll between scroll points: smooth (default) or a jump at each point; saved in this project
  ImGui.BeginDisabled(ctx, mode == "off")
  UI.field(ctx, "Scroll")
  local si = P.scroll_jump and 1 or 0
  local sch
  sch, si = ImGui.Combo(ctx, "##scrolljump", si, "Smooth, between scroll points\0Jump at each scroll point\0")
  if sch then P.scroll_jump = (si == 1); Util.mark_pdirty() end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, off_tip .. "Smooth: the page moves slowly from one scroll point to the next.\n"
      .. "Jump: the page goes to the scroll position at the time of each scroll point and stays there.\n"
      .. "For PDFSCROLL markers and cues. Saved in this project.")
  end
  -- status of the mode
  if mode == "off" then
    UI.value(ctx, "Status", "Off. Choose a mode in the toolbar.")
  elseif mode == "marker" then
    local nwarn = #R.marker_warns
    UI.value(ctx, "Markers found", string.format("%d PDFPAGE, %d PDFSCROLL", #R.page_pts, #R.scroll_pts), COL.TEXT_MAIN)
    if nwarn > 0 then
      UI.value(ctx, "Invalid markers", tostring(nwarn), COL.YELLOW)
      for i, w in ipairs(R.marker_warns) do
        if i > 5 then UI.note(ctx, string.format("... and %d more invalid markers", nwarn - 5), COL.YELLOW); break end
        UI.note(ctx, w, COL.YELLOW)
      end
    end
  end
end

function UI.draw_midi_tab(ctx)
  local ch

  -- the input switch first: most options below need it
  UI.heading(ctx, "Input", "MIDI control is optional. Ignore this section if you do not use a controller.\n\n"
    .. "'Read MIDI directly' uses the CC numbers below. "
    .. "Leave it off if the script is bound to a CC in the Action List.\n\n"
    .. "Turn pages and add cues with buttons on your controller (direct input only). "
    .. "A CC value of 64 or more counts as a button press.", "computer")
  ch, S.direct_midi = UI.checkbox(ctx, "Read MIDI directly", S.direct_midi)
  UI.tip(ctx, "Reads the CC numbers below directly from your MIDI inputs (no Action List binding needed).")
  if ch then
    Util.mark_dirty()
    if S.direct_midi and r.MIDI_GetRecentInputEvent then
      R.last_midi_seq = (r.MIDI_GetRecentInputEvent(0)) or 0
    end
  end
  -- controller buttons (direct input only): shown under the switch, only while it is on
  local function cc_row(label, id, v)
    UI.field(ctx, label)
    local c, nv = ImGui.InputInt(ctx, id, v, 1, 8)
    if c then Util.mark_dirty(); return Util.clamp(nv, 0, 127) end
    return v
  end
  if S.direct_midi then
    ch, S.midi_page_turn = UI.checkbox(ctx, "Turn pages with MIDI", S.midi_page_turn)
    UI.tip(ctx, "A CC value of 64 or more counts as a button press.")
    if ch then Util.mark_dirty() end
    if S.midi_page_turn then
      S.cc_page_next = cc_row("Next-page CC #", "##ccnext", S.cc_page_next)
      S.cc_page_prev = cc_row("Previous-page CC #", "##ccprev", S.cc_page_prev)
    end
    ch, S.midi_add_cue = UI.checkbox(ctx, "Add cues with MIDI", S.midi_add_cue)
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "Same as 'Add page turn' and 'Add scroll point' in the Cues tab.\n"
      .. "A value of 64 or more counts as a press.")
    if S.midi_add_cue then
      S.cc_add_cue = cc_row("Page turn CC #", "##ccaddcue", S.cc_add_cue)
      S.cc_add_scroll = cc_row("Scroll point CC #", "##ccaddscroll", S.cc_add_scroll)
    end
  end

  UI.group_sep(ctx)
  UI.heading(ctx, "Scroll", "Absolute: a knob/fader position (0-127) sets the scroll position.\n"
    .. "Relative: an endless encoder moves the page up or down. Pick the encoding your controller sends.", "computer")
  UI.field(ctx, "Knob type")
  local mi = (S.mode == "absolute") and 0 or 1
  ch, mi = ImGui.Combo(ctx, "##midimode", mi, MODE_ITEMS)
  if ch then S.mode = (mi == 0) and "absolute" or "relative"; Util.mark_dirty() end
  -- only the rows of the chosen MIDI mode
  if S.mode == "absolute" then
    UI.field(ctx, "Absolute CC #")
    ch, S.cc_abs = ImGui.InputInt(ctx, "##ccabs", S.cc_abs, 1, 8)
    if ch then S.cc_abs = Util.clamp(S.cc_abs, 0, 127); Util.mark_dirty() end
  else
    UI.field(ctx, "Relative CC #")
    ch, S.cc_rel = ImGui.InputInt(ctx, "##ccrel", S.cc_rel, 1, 8)
    if ch then S.cc_rel = Util.clamp(S.cc_rel, 0, 127); Util.mark_dirty() end
    UI.field(ctx, "Relative encoding")
    local ri = S.rel_encoding - 1
    ch, ri = ImGui.Combo(ctx, "##relenc", ri, REL_ITEMS)
    if ch then S.rel_encoding = ri + 1; Util.mark_dirty() end
    ch, S.rel_invert = UI.checkbox(ctx, "Invert direction", S.rel_invert)
    if ch then Util.mark_dirty() end
    UI.field(ctx, "Scroll speed")
    ch, S.sensitivity = ImGui.SliderDouble(ctx, "##sens", S.sensitivity, 1, 200, "%.0f")
    if ch then Util.mark_dirty() end
    UI.tip(ctx, "How far the page moves for each step of the encoder (pixels).")
  end
  UI.draw_midi_debug(ctx)
end

-- "Show MIDI debug" (Troubleshooting, end of the MIDI section): the last CC that Chart Cue received.
function UI.draw_midi_debug(ctx)
  local ch
  UI.group_sep(ctx)
  UI.heading(ctx, "Troubleshooting", nil, "computer")
  ch, S.show_midi_debug = UI.checkbox(ctx, "Show MIDI debug", S.show_midi_debug)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Shows the last CC number and value that Chart Cue received. Use it to find the CC number of your knob.")
  if S.show_midi_debug then
    local d = R.dbg
    UI.note(ctx, string.format("Last raw CC number: %s", d.cc and tostring(d.cc) or "unknown (action-bound)"))
    UI.note(ctx, string.format("Last raw CC value: %s", d.val and tostring(d.val) or "-"))
    UI.note(ctx, "Decoded: " .. (d.decoded or "-"))
    UI.note(ctx, "Knob type: " .. S.mode .. (S.mode == "relative" and (" (encoding " .. S.rel_encoding .. ")") or ""))
    UI.note(ctx, "Source: " .. (d.src or "-"))
  end
end

-- Poppler path + status. Shown inside "Page quality", only when the PDF engine is Poppler.
function UI.draw_poppler_settings(ctx)
  local ch
  local _, _, fw = UI.form(ctx) -- measure at the row start, before the label moves the cursor
  UI.field(ctx, "pdftoppm.exe")
  ImGui.SetNextItemWidth(ctx, math.max(60, fw - CFG.SMALL_BTN_W - 8))
  ch, S.pdftoppm_path = ImGui.InputText(ctx, "##exe", S.pdftoppm_path)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Poppler for Windows: select pdftoppm.exe. pdfinfo.exe must be in the same folder.")
  local edited = ImGui.IsItemDeactivatedAfterEdit(ctx)
  ImGui.SameLine(ctx, 0, 8)
  if UI.button(ctx, "Browse...", CFG.SMALL_BTN_W, 0) then PDF.browse_exe() end
  if edited then
    R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo()
    if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  end
  if not R.exe then UI.note(ctx, "pdftoppm.exe not found. Select it, or use the Windows engine.", COL.RED)
  elseif not R.pdfinfo_ok then UI.note(ctx, POPPLER_PDFINFO_WARN, COL.YELLOW)
  else UI.note(ctx, "OK - pdftoppm.exe and pdfinfo.exe found.", COL.GREEN) end
end

-- "Match DPI to current view" (Settings > Display and the toolbar menu): the DPI that fits the zoom.
-- Only possible while a page is shown (R.last_ratio) and below the largest page size (R.scale_to).
function PDF.can_match_dpi() return R.last_ratio ~= nil and not R.scale_to end
function PDF.match_dpi()
  if not PDF.can_match_dpi() then return end
  local target = Util.clamp(math.floor(S.dpi * R.last_ratio * 1.25 / 10 + 0.5) * 10, 72, 600)
  if target ~= S.dpi then
    S.dpi = target; R.dpi_edit = target; Util.mark_dirty()
    if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
    Msg.notify(string.format("Page sharpness set to %d DPI.", target), false, "display")
  else
    Msg.notify(string.format("Page sharpness already fits the view (%d DPI).", S.dpi), false, "display")
  end
end

-- "Reset all settings": back to the defaults copied before settings.ini was read (asked first, inline).
function UI.reset_all_settings()
  for k, v in pairs(CFG.S_DEFAULTS) do
    if not CFG.KEEP_ON_RESET[k] then S[k] = v end
  end
  R.dpi_edit = S.dpi; R.exe = nil; R.force_scale = false
  R.reset_layout = true
  Util.save_settings(); R.dirty = false
  if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  Msg.notify("All settings were reset to the defaults.", false, "general")
end

-- Split view rows (Display > Page layout): 2 PDFs on screen when a song has 2 (PDF 1 + PDF 2),
-- for example lyrics and a bass part.
function UI.draw_split_rows(ctx)
  local ch
  UI.field(ctx, "Split view")
  local oi = P.split_off and 1 or 0
  ch, oi = ImGui.Combo(ctx, "##splitoff", oi, "On, when a song has 2 PDFs\0Off, always 1 PDF\0")
  if ch then
    P.split_off = (oi == 1); Util.mark_pdirty()
    if P.split_off then UI.close_part2()
    else UI.sync_part2(R.cur_region_key and Project.region_by_key(R.cur_region_key)) end -- PDF 2 at once
  end
  UI.tip(ctx, "Off: only PDF 1 is shown, also for songs with 2 PDFs. Saved in this project.")
  ImGui.BeginDisabled(ctx, P.split_off)
  UI.field(ctx, "Split layout")
  local si = (S.split_layout == "side") and 1 or 0
  ch, si = ImGui.Combo(ctx, "##splitlayout", si, "Top and bottom\0Side by side\0")
  if ch then S.split_layout = (si == 1) and "side" or "stack"; Util.mark_dirty() end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, "How the 2 PDFs share the page area. Saved on this computer.")
  end
end

-- Display: sorted by what you do (PDF viewer on stage, Page quality with the cache, Window).
function UI.draw_display_tab(ctx)
  local ch
  UI.heading(ctx, "Page layout", "What you see in the page area.\n\n"
    .. "Pages on screen: 1 page, 2 pages side by side (they zoom and scroll together), or continuous "
    .. "(the pages are one long strip: scroll through the whole PDF without jumps).\n"
    .. "Page turn, side by side: by 1 page (1-2, then 2-3: the next page is always visible) "
    .. "or by 2 pages, like a book (1-2, then 3-4).\nPage turn motion: the next page slides in (Smooth) or appears at once (Jump).\n\n"
    .. "Split view: when a song has 2 PDFs (PDF 1 and PDF 2), both are shown, top and bottom or side by side; "
    .. "each one shows 1 page and has its own cues. Off: only PDF 1. Drag the line between them to change "
    .. "their sizes; double-click it for the same size.\n\n"
    .. "Saved on this computer, except Split view On / Off: saved in this project.")
  -- pages on screen + page turn (S.page_layout, S.page_turn)
  UI.field(ctx, "Pages on screen")
  local li = PAGE_LAYOUT_INDEX[S.page_layout] or 0
  ch, li = ImGui.Combo(ctx, "##pagelayout", li, PAGE_LAYOUT_ITEMS)
  if ch then UI.set_page_layout(PAGE_LAYOUTS[li + 1]) end
  UI.tip(ctx, "2 pages side by side: the next page of the same PDF is shown too.\n"
    .. "Continuous: the pages are one long strip; scroll through the whole PDF without jumps.")
  -- side by side: by 1 or 2 pages (greyed out for the other layouts)
  ImGui.BeginDisabled(ctx, S.page_layout ~= "side")
  UI.field(ctx, "Page turn")
  local ti = (S.page_turn == "book") and 1 or 0
  ch, ti = ImGui.Combo(ctx, "##pageturn", ti, "By 1 page (1-2, 2-3)\0By 2 pages, like a book (1-2, 3-4)\0")
  if ch then S.page_turn = (ti == 1) and "book" or "rolling"; Util.mark_dirty() end
  ImGui.EndDisabled(ctx)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    ImGui.SetTooltip(ctx, (S.page_layout ~= "side") and "Only with 2 pages side by side."
      or "By 1 page: the next page is always visible. By 2 pages: the next 2 pages, like turning a book page.")
  end
  -- motion of a page turn to the next page, for every layout (S.cont_turn)
  UI.field(ctx, "Page turn motion")
  local mi = (S.cont_turn == "jump") and 1 or 0
  ch, mi = ImGui.Combo(ctx, "##contturn", mi, "Smooth (the next page slides in)\0Jump (the next page appears at once)\0")
  if ch then S.cont_turn = (mi == 1) and "jump" or "smooth"; Util.mark_dirty() end
  UI.tip(ctx, "Smooth: at a page turn to the next page, the page slides in, so you see where the music goes on.\n"
    .. "1 page and continuous: from below. Side by side (by 1 page): from the right. By 2 pages: always a jump.")
  UI.draw_split_rows(ctx)

  UI.group_sep(ctx)
  UI.heading(ctx, "PDF viewer", "How the page looks during playback.\n\n"
    .. "Page brightness: lower than 100% makes the white paper darker for dark stages. The page is not prepared again.\n\n"
    .. "Page-turn flash: a short blue frame around the page when it turns during playback.", "computer")
  -- one slider: 100% = not dimmed (S.dim_page stays in settings.ini, set from the slider)
  UI.field(ctx, "Page brightness")
  local pct = S.dim_page and math.floor(S.dim_level * 100 + 0.5) or 100
  ch, pct = ImGui.SliderInt(ctx, "##dimlevel", pct, 25, 100, "%d%%")
  if ch then S.dim_page = pct < 100; S.dim_level = pct / 100; Util.mark_dirty() end
  UI.tip(ctx, "Lower than 100% makes the white paper darker for dark stages.")
  ch, S.turn_flash = UI.checkbox(ctx, "Page-turn flash", S.turn_flash)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "A short blue frame around the page when it turns during playback.")

  UI.group_sep(ctx)
  UI.heading(ctx, "Page quality", "Page sharpness (DPI) sets how sharp the page images are. Higher = sharper, but slower and more disk space.\n\n"
    .. "'Match DPI to current view' sets the DPI for the current zoom.\n\n"
    .. "Page cache: the pages are stored on disk so a PDF opens fast the next time. "
    .. "Clearing it never deletes the page on screen; pages are prepared again when needed.", "computer")
  UI.heading_msg(ctx, "display") -- the messages of this section: in the title line, so the rows never move
  -- page quality of the current view: a short word (in the DPI row) and the advice (its tooltip)
  local q, qcol, qtip
  if R.last_ratio then
    if R.last_ratio > 1.05 then q, qcol, qtip = "Blurry", COL.YELLOW, "Blurry: raise the DPI."
    elseif R.last_ratio < 0.6 then q, qcol, qtip = "Soft", COL.YELLOW, "Soft: lower the DPI or zoom in."
    else q, qcol, qtip = "Sharp", COL.GREEN, "Sharp: the DPI fits the view." end
    qtip = qtip .. string.format("\nImage scale on screen: %.2fx (1.00 = pixel-perfect)", R.last_ratio)
  end
  -- the DPI number: shown as text with the quality and "Change"; the field appears only when you want
  -- to type a value (or when no PDF is open yet, so there is no quality and no "Match DPI" button)
  -- One row in both states: the value (text, or a small number field after "Change"), the quality
  -- word, and "Change" / "Done". Without an open PDF there is no quality: the field is shown.
  do
    UI.row_start(ctx, "Page sharpness (DPI)")
    local edit = R.dpi_manual or not R.last_ratio
    if edit then
      ImGui.SetNextItemWidth(ctx, 140)
      ch, R.dpi_edit = ImGui.InputInt(ctx, "##dpi", R.dpi_edit or S.dpi, 25, 50)
      if ImGui.IsItemDeactivatedAfterEdit(ctx) or ch then
        local d = Util.clamp(R.dpi_edit, 50, 600)
        R.dpi_edit = d
        if ImGui.IsItemDeactivatedAfterEdit(ctx) or not ImGui.IsItemActive(ctx) then -- typed + Enter, or - / +
          if d ~= S.dpi then S.dpi = d; Util.mark_dirty(); if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end end
        end
      end
      UI.tip(ctx, "Page sharpness in DPI (50 - 600). Type a number and press Enter, or use - and +.")
    else
      UI.row_text(ctx, string.format("%d DPI", S.dpi))
    end
    if q then
      ImGui.SameLine(ctx, 0, 12)
      UI.row_text(ctx, q, qcol)
      UI.tip(ctx, qtip)
    end
    if R.last_ratio then
      ImGui.SameLine(ctx, 0, 12)
      if R.dpi_manual then
        if UI.row_button(ctx, "Done##dpi", UI.btn_w(ctx, "Change", CFG.SMALL_BTN_W), "ghost") then R.dpi_manual = false end
        UI.tip(ctx, "Back to the short view of the DPI.")
      else
        if UI.row_button(ctx, "Change##dpi", UI.btn_w(ctx, "Change", CFG.SMALL_BTN_W), "ghost") then R.dpi_manual = true; R.dpi_edit = S.dpi end
        UI.tip(ctx, "Type the DPI by hand. Usually 'Match DPI to current view' below is enough.")
      end
    end
  end
  if R.last_ratio then
    if R.scale_to then
      UI.note(ctx, "Maximum page size reached.", COL.GREY)
      UI.tip(ctx, string.format("This PDF already has the largest page size (%d px). A higher DPI does not make it sharper.", R.scale_to))
    elseif UI.full_button(ctx, "Match DPI to current view", "primary") then
      PDF.match_dpi()
    end
  end

  -- the PDF engine: after the sharpness, because few people change it
  UI.field(ctx, "PDF engine")
  local ei = (PDF.engine() == "poppler") and 1 or 0
  ch, ei = ImGui.Combo(ctx, "##engine", ei, "Windows (built in)\0Poppler (pdftoppm.exe)\0")
  UI.tip(ctx, "Windows (built in): no extra software (Windows 10/11).\nPoppler: optional; select pdftoppm.exe below.")
  if ch then
    S.engine = (ei == 1) and "poppler" or "windows"; Util.mark_dirty()
    if S.engine == "poppler" and not R.exe then R.exe = PDF.find_pdftoppm(); PDF.check_pdfinfo() end
    Msg.set_error(nil)
    if S.pdf_path ~= "" then PDF.open_pdf(S.pdf_path, true) end
  end
  if PDF.engine() == "poppler" then UI.draw_poppler_settings(ctx) end

  -- page cache: one row "<size>  [Clear...]". The size is calculated in the background when this
  -- section is shown and no size is known yet (never every frame: the job runs once, then the result stays).
  local clearing = R.cache_clear_t and Util.now() - R.cache_clear_t < 2 -- wait for the delete to run
  if not R.cache_size and not R.size_job and not clearing then Util.start_dir_size(CFG.CACHE_ROOT, 3) end
  do
    local cx = UI.row_start(ctx, "Page cache")
    local bw = UI.btn_w(ctx, "Clear...", CFG.SMALL_BTN_W)
    local size_txt = (R.size_job or clearing or not R.cache_size) and "Calculating..." or Util.fmt_bytes(R.cache_size)
    UI.row_text(ctx, size_txt, COL.TEXT_DIM)
    UI.tip(ctx, "Total size of the page cache of all PDFs.\nFolder: " .. (R.cache_dir or CFG.CACHE_ROOT))
    -- the button at the right end of the control column (after the text when the column is narrow)
    ImGui.SameLine(ctx, cx + (ImGui.CalcTextSize(ctx, size_txt)) + 12) -- right after the size
    if UI.row_button(ctx, "Clear...", bw, true) then
      UI.ask("cache_clear", "Delete the whole page cache? The page on screen is kept; pages are prepared again when needed.",
        "Yes, delete", function()
          if PDF.clear_all_cache() then Msg.notify("Page cache cleared.", false, "display") end
        end)
    end
  end
  UI.draw_ask(ctx, "cache_clear")
  -- (the messages of this section show in the "Page quality" title line, see above)

  UI.group_sep(ctx)
  UI.heading(ctx, "Window", "Hide panel when playing: during playback the tabs and the panel are hidden; only the toolbar and the page show. "
    .. "The status bar shows only when there is an error.\n\n"
    .. "Comfortable layout: more empty space between rows and sections. Buttons, fields and tabs keep their size.", "computer")
  ch, S.hide_controls_playing = UI.checkbox(ctx, "Hide panel when playing", S.hide_controls_playing)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "While REAPER plays, only a small toolbar shows, so the music gets more space.\n"
    .. "The status bar shows only when there is an error.")
  ch, S.comfortable = UI.checkbox(ctx, "Comfortable layout", S.comfortable)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "More empty space between rows and sections. Buttons, fields and tabs keep their size.")
end

-- Troubleshooting for all of Chart Cue (end of Settings > General).
function UI.draw_general_troubleshooting(ctx)
  local ch
  UI.group_sep(ctx)
  UI.heading(ctx, "Troubleshooting", "Write diagnostic log: writes technical events (visibility, docking, recovered errors) "
    .. "to the REAPER console. Use it only to report a problem.\n\n"
    .. "Reset window position: moves the window back to its default size and place, for example when it is off-screen.\n\n"
    .. "Reset all settings: sets the settings of this computer back to the defaults. "
    .. "Your projects (library, regions, cues) are not changed.", "computer")
  ch, S.log_diag = UI.checkbox(ctx, "Write diagnostic log", S.log_diag)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Writes technical events to the REAPER console.")
  if UI.full_button(ctx, "Rescan project") then Project.rescan("general") end
  UI.tip(ctx, "Reads the regions and the markers again. They are read automatically after each project change;\n"
    .. "use this only if something looks wrong.")
  if UI.full_button(ctx, "Reset window position") then
    R.reset_layout = true
    Msg.notify("Window position reset.", false, "general")
  end
  UI.tip(ctx, "Moves the window back to its default size and place, and undocks it.")
  if UI.danger_button(ctx, "Reset all settings...") then
    UI.ask("reset_all", "Reset all Chart Cue settings on this computer to the defaults? This resets the PDF engine, "
      .. "page sharpness, window, MIDI and autoscroll settings. Your projects (library, regions, cues) are not changed.",
      "Yes, reset", UI.reset_all_settings)
  end
  UI.draw_ask(ctx, "reset_all")
  UI.section_msg(ctx, "general")
end

-- Path row: label | path (cut at the left) | "Show in Explorer" right-aligned, across the full panel width.
-- An empty path shows `empty` with the tooltip `empty_tip`, and the button is disabled.
-- Used by Settings > General > Current project (Project file) and Help > About > Installed in.
function UI.path_row(ctx, label, path, empty, empty_tip)
  local x0 = ImGui.GetCursorPosX(ctx)
  local aw = UI.panel_w(ctx)
  local bw = UI.btn_w(ctx, "Show in Explorer", CFG.EXPLORER_BTN_W)
  local btn_x = x0 + aw - bw - 14
  local has = (path ~= "")
  local _, cx, _, wide = UI.form(ctx)
  UI.label(ctx, label)
  if wide then ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, cx) end
  local tw = math.max(40, btn_x - ImGui.GetCursorPosX(ctx) - 8)
  UI.row_text(ctx, UI.trunc_left(ctx, has and path or empty, tw), COL.GREY)
  UI.tip(ctx, has and path or empty_tip)
  ImGui.SameLine(ctx, btn_x)
  if not has then ImGui.BeginDisabled(ctx, true) end
  local hit = UI.row_button(ctx, "Show in Explorer##" .. label, bw, "ghost")
  if not has then ImGui.EndDisabled(ctx) end -- always paired with BeginDisabled above
  if hit and has then Util.show_in_explorer(path) end
end

function UI.draw_project_tab(ctx)
  local ch
  UI.heading(ctx, "Current project", "The REAPER project file that holds the Chart Cue data of this project.", "project")
  UI.path_row(ctx, "Project file", R.projfn, "(not saved yet)",
    "Chart Cue settings are saved with the project when you save it.")

  UI.group_sep(ctx)
  UI.heading(ctx, "Automatic open and close",
    "Open automatically: Chart Cue opens when you open (or switch to) any project that contains Chart Cue data. "
    .. "It adds 3 marked lines to REAPER's __startup.lua (with a backup) and needs one REAPER restart.\n\n"
    .. "Close: Chart Cue closes when you close the project tab, or when File > Close / New / Open project "
    .. "replaces the project in the same tab. Switching tabs and 'Save as' keep it open.", "computer")

  -- main method: automatic open for all Chart Cue projects
  local on = Autostart.installed()
  ch, on = UI.checkbox(ctx, "Open automatically", on)
  if ch then
    if on then Autostart.install() else Autostart.uninstall() end
  end
  UI.tip(ctx, "Chart Cue opens by itself when you open a project that uses it.\nNeeds one REAPER restart after you change it.")
  UI.section_msg(ctx, "project")

  -- close
  ch, S.close_with_project = UI.checkbox(ctx, "Close with project", S.close_with_project)
  if ch then Util.mark_dirty() end
  UI.tip(ctx, "Chart Cue closes when its project tab closes, or when File > Close / New / Open project replaces it.")
  UI.draw_general_troubleshooting(ctx)
end

---------------------------------------------------------------------------
-- HELP: one text for the Help panel ("?" at the end of the tab strip) and the browser guide.
--   text = simple words, shown in the panel AND the guide
--   more = extra details, shown only in the browser guide
-- Format: blank line = new paragraph, "- " = bullet, "1. " = numbered step.
---------------------------------------------------------------------------
local HELP_TOPICS = {
  { title = "Getting started", text = [==[
Chart Cue shows your sheet music or chord charts (PDF files) inside REAPER. It can also move the page for you while the song plays.

1. Click the Library tab, then click "Add PDF" and pick a PDF file.
2. Click the PDF in the list. The first page appears.
3. Use the arrow buttons at the top to go to the previous or next page. Use the minus and plus buttons to make the page smaller or bigger.
4. Optional: in REAPER, make a region with the same name as the PDF. For example, a region named "Song One" for the file "Song One.pdf". Chart Cue then opens that PDF by itself when the song plays.
5. Optional: choose an autoscroll mode in the toolbar ("Scroll: Off"), so the page moves by itself while REAPER plays.

Click a tab to open it. Click the same tab again to hide it and get more space for the music. The Settings tab (the gear icon) has 4 sections: Autoscroll, MIDI, Display, and General. Click a section name to open or close it. Only one section is open at a time. The first section of the Library, Regions and Cues tabs can also be closed with the arrow before its name.]==],
    more = [==[
- You can dock the Chart Cue window like any other REAPER window. Chart Cue remembers where it was.
- The first time a PDF opens, Chart Cue prepares the pages in the background ("Loading PDF" and "Preparing page"). After that, the PDF opens at once.
- The status bar at the bottom shows the scroll position, the current region and, in the Cue list and Markers modes, the next page turn ("Next: page 3 at 17.1.00"). Its second line shows the most important message, for example an error or a hint. When there is no message, it shows the keyboard shortcuts. Move the mouse over them to see the full list.
- Most settings have a round "?" icon. Move the mouse over it for a short explanation.]==] },

  { title = "Library: your PDFs", text = [==[
The Library is the list of PDFs in this project.

- "Add PDF" adds one file. "Add from folder" adds all PDFs in a folder, and the project remembers that folder (shown next to it in grey): the sync button next to it checks the folders again later, adds new PDFs and replaces the copies of changed PDFs (for example a new version of a chart). PDFs that are no longer in the folder stay in the library.
- Unused PDFs (no region uses them, as PDF 1 or PDF 2, and not on screen) have a grey name; "Sort: Unused first" shows them at the top. "Remove unused PDFs..." takes them off the library (it asks first): their copies in this project's PDFs folder are deleted too, but original files outside the project are never deleted.
- When "Copy into project" is on, Chart Cue copies each PDF into a folder named "PDFs" next to your project file. Your original file is not changed. The project then also works on another computer.
- Click a PDF in the list to show it. "Show in Explorer" opens its folder. The red X takes it off the list (it asks first); the file itself is not deleted.
- The blue row is the PDF that is on the screen now.
- A red name means that the file cannot be found. Click "Relocate..." and pick the file again.
- Right-click a PDF for: Open, Show as PDF 2, Replace PDF..., Show in Explorer and Remove from library.... "Show as PDF 2" shows that PDF next to the one on screen (for example lyrics and a bass part): the page area splits in 2 (Settings > Display > Page layout > Split view). Click a part to make it the active part (blue frame): the keys, the toolbar, the mouse wheel, MIDI and the actions act on it. Drag the line between the 2 parts to change their sizes; double-click it for the same size. Right-click > Close PDF 2 returns to 1 PDF. A PDF 2 shown this way is not saved, and markers move only PDF 1. "Replace PDF..." swaps the file (for example a new version of the chart) and keeps the region choices, the zoom and the cues. If the new file has fewer pages, a message tells you how many cues use a missing page.
- Use the search box and the sort menu above the list to find a PDF quickly.]==],
    more = [==[
- "Include subfolders" makes "Add from folder" also look in all folders inside the chosen folder.
- Copies run in the background, so REAPER and playback do not stop. The status bar shows how many are left.
- If a file with the same name is already in the PDFs folder: an identical file is used as it is. A different file opens a question: Yes = replace it, No = keep the existing copy, Cancel = skip this PDF.
- "Copy all PDFs into the project" copies the PDFs that are still outside the project folder. Use it one time for older projects.
- In a project that is not saved yet, there is no project folder. Chart Cue then uses the original files. Save the project and use "Copy all PDFs into the project".
- PDFs inside the project folder are stored with a short path (for example PDFs/Song One.pdf). If you move the whole project folder, Chart Cue still finds them.
- After "Relocate...", Chart Cue also looks in the same folder for the other missing PDFs, by file name.
- The page count shows after a PDF was opened one time.
- Turn off "Copy into project" to use the original files directly (link mode). The project is then not portable.]==] },

  { title = "Regions: one PDF per song", text = [==[
If your project contains several songs, each song can have its own PDF. Mark each song with a REAPER region.

- If the region has the same name as a PDF, Chart Cue connects them by itself. Capital letters, ".pdf", hyphens and underscores do not matter.
- You can also choose the PDF for a region in the menu on the right of the region.
- The symbol shows the state: green filled circle = has a PDF, yellow ring = needs a PDF, grey dash = ignored.
- The blue row is the region where the play cursor is now.
- Click a region row to move the edit cursor to the start of that region. Right-click it for: Go to region start, Choose PDF file..., Auto-match by name and Ignore this region.
- When the play cursor enters a region without a PDF, the page area shows buttons: add a PDF, choose a PDF from the list, or ignore the region.
- "Keep last page" (Regions tab, on by default): when a song has no PDF, during playback the last page stays on screen with a yellow note at the top. The buttons show when playback stops.
- "Switch PDF at regions" turns this whole function on or off.
- 2 PDFs for one song (for example lyrics and a bass part): click [+] after the region's PDF to add a "PDF 2" row, and choose the 2nd PDF there; the x removes it. When exactly 2 PDFs match a song, both are used automatically (PDF 1 = first by name; "Pair 2 matching PDFs" in Region settings turns this off); not when one of them has exactly the song's name: that one is the main chart, and [+] adds the other with one click. If you choose one of the 2 as PDF 1, the other one becomes PDF 2. Right-click the region for "Swap PDF 1 and PDF 2" and "Remove PDF 2". During the song both are shown together (Settings > Display > Split view); while REAPER is stopped, each part shows a "PDF 1" or "PDF 2" tag.]==],
    more = [==[
- Joined words are split: "songA" matches "Song A - Bass.pdf".
- Matching example: region "Song One" matches "song one.pdf", "Song_One.pdf", "song-one.PDF", "SongOne.pdf", "01 Song One.pdf", "Song One (Bb).pdf", "Song One v2.pdf" and "Song One - Bass.pdf".
- Chart Cue ignores a track number at the start, text in brackets, versions (v2) and part words (bass, guitar, gtr, keys, piano, drums, vocals, vox, chart, chords, lyrics, score, part, Bb, Eb, concert, final, copy). If 2 or more PDFs match one song (for example a bass and a guitar part), choose one in the region's menu; Chart Cue remembers it.
- If several PDFs match the same region, the dot is yellow and the menu shows "(several PDFs match)". Choose the correct one.
- The menu choices: "(auto-match by name)" uses the name rule, "(ignore this region)" shows no PDF there, or a PDF name assigns that PDF.
- Above the list: a search field (region name) and the "Show" menu: all, needs PDF, assigned, ignored.
- While REAPER is stopped, Chart Cue uses the edit cursor instead of the play cursor.
- If regions overlap, the region that starts last is used.
- Regions and markers are read again automatically after each change in the project. "Rescan project" (Settings > General > Troubleshooting) does it by hand.]==] },

  { title = "Autoscroll: the page moves by itself", text = [==[
Autoscroll moves the page while REAPER plays. Choose the mode in the toolbar ("Scroll: ..."). Settings > Autoscroll has the options of each mode. Each project saves its own mode. During playback the mode is locked, so the page cannot jump; stop playback to change it.

- Off: the page moves only when you scroll it.
- Markers: you put markers in your REAPER project that tell Chart Cue what to show.
- Cue list: the same as markers, but Chart Cue keeps the list itself. No markers are added to your project. Use this if another program (for example a setlist program) must not see extra markers.

Marker names for the "Markers" mode:
- PDFPAGE 2 means: from here, show page 2.
- PDFSCROLL 50 means: here, show the middle of the page. 0 is the top, 100 is the bottom. Between two PDFSCROLL markers, the page moves smoothly, or jumps (Settings > Autoscroll > Scroll).

How to make a cue list (Cues tab):
1. Choose "Cue list" as the autoscroll mode, or click "Use Cue list mode" in the Cues tab.
2. Turn on "Record" (or press R), then play the song.
3. At each page turn, click "Add page turn" or press the C key. Chart Cue chooses the next page by itself.
4. Where the page must move down, scroll it by hand and click "Add scroll point" or press the S key.
5. To change a cue, type a new position, page or scroll value in the list. To delete it, click the red X at the end of its row. A red border means the value is not accepted: move the mouse over it to see why, then correct it or press Esc.
6. To take back the last cue change, click the Undo arrow at the right end of the column titles (or press Ctrl+Z in the Chart Cue window); the Redo arrow (Ctrl+Shift+Z) brings it back.

Songs with 2 PDFs (Regions tab): each PDF has its own cues. Click a part on the page to make it active (blue frame): Record (C, S), the add buttons and the MIDI cue buttons add cues to that PDF. In the Cues tab, the "PDF" dropdown chooses which list you see and edit. Markers move only PDF 1; "Copy markers into cues" and "Remove all cues..." work on PDF 1.

If you scroll by hand during playback, autoscroll waits a moment and then continues.]==],
    more = [==[
- Example for a 2-page song: PDFPAGE 1 at the start, PDFSCROLL 0 at bar 1, PDFSCROLL 100 at bar 16, PDFPAGE 2 at bar 17, PDFSCROLL 0 at bar 17, PDFSCROLL 100 at bar 32.
- Marker names are not case-sensitive ("pdfpage 2" works). Markers with a wrong number are ignored and listed as a warning.
- A PDFPAGE marker always starts the page at the top. If a PDFSCROLL marker is at exactly the same time, the PDFSCROLL marker wins.
- "Turn pages" (Settings > Autoscroll): "One beat early" shows the next page one beat before its PDFPAGE marker or page-turn cue, so you can read ahead. It is saved in the project.
- The smooth movement never continues past a PDFPAGE marker.
- With regions, the markers inside a region control the PDF of that region. They work from the region start to the region end.
- Manual scrolling (wheel, drag, MIDI) pauses autoscroll for 1.5 seconds.
- Cue list: each song (region) has its own cues, counted from the region start. If you move a region, its cues move with it. Without regions, the cues count from the project start ("whole project").
- Cue list: "Count time in" is chosen per project. Beats: a cue stays on its bar and beat when the tempo changes. Seconds: a cue stays at the same time. Switching keeps every cue at its current place.
- Cue list: a cue has a page, a scroll position, or both. Between two scroll points the page moves smoothly, or jumps (Settings > Autoscroll > Scroll). A new cue at the same place replaces the old one.
- Cue list: the first row ("Start") shows that each song starts on page 1 at the top. Change it, and it becomes a cue.
- Cue list: click a row to move the edit cursor to its cue. The page icon gives the cue the page and scroll position shown now. The + adds a scroll point halfway to the next cue. Right-click a row for: Go to cue, Use current view, Add scroll point below and Remove cue.
- "Add page turn" uses the page after the cue before it (the first page turn gives page 2), at the top of the page. If you add a page turn between existing cues, the following page numbers go up by one.
- "Add scroll point" uses the page of the cue before it and the current scroll position.
- A page number higher than the last page of the song's PDF is not accepted.
- "(current song)" in the Song menu is the song at the play cursor during playback, or at the edit cursor when REAPER is stopped.
- "(all songs)" in the Song menu shows the cues of every song, with the song name above each list. "Remove all cues..." asks before it deletes, and Undo brings the cues back.
- "(whole project, no region)" is only for projects without regions. Its times count from the project start.
- "More actions" > "Copy markers into cues" copies the PDF markers (PDFPAGE / PDFSCROLL) of the song into its cue list. The markers stay.
- "Remove PDF markers..." then removes them (for this song, or for all songs with "(all songs)" in the Song menu). Only PDF markers are removed; regions and other markers are not changed. It is one undo step, so Edit > Undo (Ctrl+Z) brings them back.
- The cue list is saved in the project, like the library. Save the project after changes.]==] },

  { title = "MIDI controller", text = [==[
You can scroll the page with a knob, fader or endless encoder on a MIDI controller. This is optional.

1. Open Settings > MIDI.
2. Tick "Read MIDI directly".
3. Set "Knob type" and the CC number that your knob sends.

- Absolute: the knob position is the page position. Use this for normal knobs and faders.
- Relative: turning moves the page up or down. Use this for endless encoders. If the page moves the wrong way or jumps, try another "Relative encoding", or tick "Invert direction".
- Turn pages with MIDI: two buttons on your controller can go to the next and previous page.
- Add cues with MIDI: one button adds a page turn, another one adds a scroll point (Cues tab).
- These two options show only when "Read MIDI directly" is on. The tab shows only the rows of the chosen MIDI mode.]==],
    more = [==[
- Another way: bind the Chart Cue action to a knob in REAPER's Action List (Add shortcut, then move the knob). When REAPER asks about the running script, choose "New instance" and "Remember my answer". The new instance only sends the value to the open Chart Cue.
- With an Action List binding, do NOT tick "Read MIDI directly".
- "Scroll speed" sets how far the page moves for each step of a relative encoder.
- "Show MIDI debug" (Troubleshooting, at the end of Settings > MIDI) shows the last CC number and value that Chart Cue received. Use it to find the CC number of your knob.
- Page turning works with direct MIDI input. A value of 64 or more counts as a button press.]==] },

  { title = "Display", text = [==[
- Page brightness (PDF viewer): lower than 100% makes the white paper darker for dark stages. 100% = not dimmed.
- Page-turn flash (PDF viewer): a short blue frame when the page turns during playback.
- Pages on screen (PDF viewer, or right-click > Pages on screen): 1 page; 2 pages side by side, which zoom and scroll together (the toolbar shows "3-4 / 12"); or continuous: the pages are one long strip, and you scroll through the whole PDF without jumps (the toolbar shows the page at the top). Page turn, side by side: by 1 page (1-2, then 2-3), so the next page is always visible, or by 2 pages like a book (1-2, then 3-4); a page turn to page 4 then shows pages 3-4, and a page turn to a page that is already on screen does nothing. Page turn motion (every layout): Smooth slides the next page in (from below, or from the right side by side), Jump shows it at once; turning by 2 pages always jumps. Cues and markers do not change.
- Page sharpness (DPI): a higher number gives sharper pages, but the first preparation takes longer. "Page quality" tells you if the page looks sharp.
- PDF engine: "Windows (built in)" needs no extra software. "Poppler" is an optional alternative.
- Hide panel when playing (Window, or the button at the right of the toolbar): while REAPER plays, the tabs and the panel are hidden and only the toolbar and the page show, so the music gets more space. If there is an error, one red line is shown.
- Comfortable layout (Window): more empty space between rows and sections; buttons, fields and tabs keep their size.
- Page cache (Page quality): Chart Cue keeps the pages on your disk, so PDFs open fast. Its size is shown next to "Clear...", which clears it at any time. It is filled again when needed.]==],
    more = [==[
- "Match DPI to current view" sets the DPI that fits your current zoom.
- Chart Cue prepares all pages of a PDF in the background. The pages near the current page come first.
- Very large pages are limited to 4096 pixels. Then the DPI cannot go higher for that PDF.
- The Windows engine uses Windows PowerShell in the background. The first time a PDF opens, this takes about 1 second.
- Poppler: choose "Poppler (pdftoppm.exe)" as the engine, then select pdftoppm.exe. pdfinfo.exe must be in the same folder.
- Each engine and each DPI has its own cache folder.
- "Write diagnostic log" (Settings > General > Troubleshooting) writes technical events to the REAPER console. Use it only to report a problem.
- "Reset all settings..." (Settings > General > Troubleshooting) sets the settings of this computer back to the defaults. Your projects are not changed.
- "Reset window position" (Settings > General > Troubleshooting) moves the window back to its default size and place, for example when it is off-screen.]==] },

  { title = "Project: saving, opening, closing", text = [==[
Chart Cue saves the library and the region choices inside your REAPER project. They move with the project when you copy it or use "Save as". Save the project after changes, as with any other change.

The round "?" next to a heading tells you where its settings are saved: in this project, or on this computer (the same for all your projects). If a setting is saved in a different place than the rest of its section, the "?" text says so.

- "Open automatically": Chart Cue opens by itself when you open a project that uses it. Restart REAPER one time after you turn this on.
- "Close with project": Chart Cue closes together with its project.]==],
    more = [==[
- Saved in the project (.rpp): the library, region choices, ignored regions, "Switch PDF at regions", the autoscroll mode and the PDF on screen.
- Saved for your computer (Data\Chart Cue\settings.ini in the REAPER resource folder): the PDF engine, DPI, window and dock place, MIDI settings and the default autoscroll mode (used by projects that have no mode yet).
- Automatic open adds 3 marked lines at the end of REAPER's Scripts\__startup.lua. A backup is saved first (__startup.lua.chartcue-backup). Turning the option off removes only these 3 lines.
- Chart Cue closes when you close the project tab, or when File > Close project, New project or Open project replaces the project in the same tab. Switching tabs and "Save as" keep it open.]==] },

  { title = "Keyboard and mouse", text = [==[
- Left arrow or Page Up: previous page
- Right arrow or Page Down: next page
- Home: go to the top of the page
- F: performance mode (only the page is shown). F or Esc goes back.
- L: lock (during playback the page ignores the mouse and the keys; MIDI and autoscroll still work). The lock button is in the toolbar.
- R: record cues on / off (Cue list mode only; the red dot button in the toolbar and "Record" in the Cues tab do the same). REC shows on the page while it is on.
- C: add a page turn at the play cursor (only while Record cues is on)
- S: add a scroll point at the play cursor (only while Record cues is on)
- Ctrl and +: zoom in. Ctrl and -: zoom out. Ctrl and 0: fit the page width.
- Ctrl and Z: undo the last cue change; Ctrl, Shift and Z: redo it (while the Cues tab is open).
- Mouse wheel: scroll the page. Ctrl and mouse wheel: zoom.
- Right-click the toolbar or the page for a menu with the most used options: Add PDF, Replace PDF (the PDF on screen), hide the panel when playing, show the panel, lock, performance mode, the autoscroll mode, Record cues, Copy markers into cues (all songs), page brightness, Match DPI, Settings, Help, Dock Chart Cue in Docker (ticked while docked) and Close Chart Cue. Grey items are not available now. In lock mode during playback, a right-click on the page does nothing.
- Right-click a row in the Library, Regions or Cues list for the options of that PDF, region or cue.
- Drag the page with the mouse to move it.
- Drag the bar on the right of the page to scroll.
- Drag the thin line under the settings panel to change its height. Double-click it for a larger panel, or to go back to the default height.

The keys work when the Chart Cue window is active. Click on it first.

To turn pages when the Chart Cue window is not active (for example with a foot pedal, or a key while you work in REAPER), use these actions in REAPER's Action List: "Chart Cue - Next page", "Chart Cue - Previous page" and "Chart Cue - Toggle performance mode". Load them once with "New action > Load ReaScript...", then give them a shortcut. They also work in lock mode.]==],
    more = [==[
- The fit menu at the top has: Fit width, Fit height, Fit page and 100% (the real size of the page). Each PDF remembers its own fit and zoom (saved in the project).
- Click the page number ("3 / 12") in the toolbar to type a page number, then press Enter.
- In performance mode, move the mouse to the top-right corner of the page for an exit button.
- A horizontal mouse wheel or tilt wheel moves the page left and right when it is wider than the window.
- There is no key to close Chart Cue, so it cannot close by mistake during a performance. Use the X of the window, run the Chart Cue action again, or close the project.]==] },

  { title = "Problems and solutions", text = [==[
- "No PDF open": open a PDF in the Library tab.
- "Loading PDF" or "Preparing page" stays for a long time: wait a moment. Large PDFs need more time the first time. If nothing changes, click "Retry rendering" in the status bar.
- A PDF name is red: the file was moved or renamed. Click "Relocate..." in the Library tab.
- The page looks blurry: click "Match DPI to current view" in Settings > Display > Page quality (or "Change" to type a higher DPI).
- The wrong PDF opens for a song: check the menu of that region in the Regions tab.
- Chart Cue opens twice, or REAPER asks about a running script: use only one way to open Chart Cue automatically (Settings > General).
- Nothing helps: change the PDF engine in Settings > Display and try again.]==],
    more = [==[
- Password-protected PDFs cannot be shown. Save a copy without a password.
- "Marker warning" in the status bar: a PDFPAGE or PDFSCROLL marker has a wrong number. The message shows its name and time.
- "Marker autoscroll is on but no PDFSCROLL or PDFPAGE markers were found": add markers, or choose another autoscroll mode.
- PDFs on network drives or in online-only cloud folders can be slow or not found. Copy them into the project (Library tab).
- To report a problem: turn on "Write diagnostic log" (Settings > General > Troubleshooting), repeat the problem, and copy the text from the REAPER console.]==] },
}

HELP_TOPICS[#HELP_TOPICS + 1] = { title = "Remove Chart Cue", guide_only = true, text = [==[
To remove Chart Cue completely from this computer:

1. Settings > General: turn off "Open automatically". This removes the 3 Chart Cue lines from __startup.lua.
2. Close Chart Cue. In REAPER's Action List, find "Script: Chart Cue.lua", right-click it and choose "Remove".
3. Delete the folder Data\Chart Cue in the REAPER resource folder (Options > Show REAPER resource path). It contains the settings, the page cache, the guide and the helper scripts.
4. Delete the file Chart Cue.lua.]==],
  more = [==[
- Your projects are not damaged. They only contain a small Chart Cue data section, which REAPER ignores without Chart Cue.
- The PDFs folders next to your projects contain your own copies of the PDFs. Keep them or delete them, as you like.
- If Chart Cue changed __startup.lua, a backup of the earlier version is in Scripts\__startup.lua.chartcue-backup.]==] }


local function html_esc(t)
  return (t:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- Converts the help text format (paragraphs, "- " bullets, "1. " steps) to HTML.
local function help_to_html(text)
  local out, list = {}, nil
  local function close_list() if list then out[#out + 1] = "</" .. list .. ">"; list = nil end end
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local bullet = line:match("^%- (.*)$")
    local step = line:match("^%d+%. (.*)$")
    if bullet or step then
      local want = bullet and "ul" or "ol"
      if list ~= want then close_list(); out[#out + 1] = "<" .. want .. ">"; list = want end
      out[#out + 1] = "<li>" .. html_esc(bullet or step) .. "</li>"
    elseif line:match("^%s*$") then
      close_list()
    else
      close_list(); out[#out + 1] = "<p>" .. html_esc(line) .. "</p>"
    end
  end
  close_list()
  return table.concat(out, "\n")
end

function UI.write_guide()
  local h = {}
  h[#h + 1] = [==[<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Chart Cue Guide</title>
<style>
:root { --bg:#ffffff; --fg:#1d1f24; --muted:#5b6170; --accent:#3b82f6; --card:#f4f6fa; --line:#dfe3ea; }
@media (prefers-color-scheme: dark) { :root { --bg:#16181d; --fg:#e6e8ee; --muted:#9aa1b0; --card:#1f2128; --line:#2f333d; } }
body { background:var(--bg); color:var(--fg); font:16px/1.6 "Segoe UI", system-ui, sans-serif; margin:0; }
main { max-width:820px; margin:0 auto; padding:32px 20px 64px; }
h1 { font-size:30px; margin:0 0 4px; } .sub { color:var(--muted); margin:0 0 28px; }
nav { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:14px 20px; margin-bottom:32px; }
nav ol { margin:6px 0 0; padding-left:22px; } nav a { color:var(--accent); text-decoration:none; }
section { border-top:2px solid var(--accent); padding-top:8px; margin-top:36px; }
h2 { font-size:22px; margin:6px 0 12px; } h3 { font-size:16px; color:var(--muted); margin:22px 0 6px; text-transform:uppercase; letter-spacing:.04em; }
.more { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:4px 18px 8px; }
li { margin:4px 0; } a.top { font-size:13px; color:var(--muted); }
@media print { nav, a.top { display:none; } section { break-inside:avoid-page; } }
</style></head><body><main>
<h1>Chart Cue Guide</h1><p class="sub">PDF charts and sheet music inside REAPER &middot; Version VERSION_HERE</p>
<nav><strong>Contents</strong><ol>]==]
  for i, t in ipairs(HELP_TOPICS) do
    h[#h + 1] = string.format('<li><a href="#t%d">%s</a></li>', i, html_esc(t.title))
  end
  h[1] = h[1]:gsub("VERSION_HERE", CFG.VERSION)
  h[#h + 1] = "</ol></nav>"
  for i, t in ipairs(HELP_TOPICS) do
    h[#h + 1] = string.format('<section id="t%d"><h2>%d. %s</h2>', i, i, html_esc(t.title))
    h[#h + 1] = help_to_html(t.text)
    if t.more then
      h[#h + 1] = '<h3>More details</h3><div class="more">' .. help_to_html(t.more) .. "</div>"
    end
    h[#h + 1] = '<p><a class="top" href="#">Back to top</a></p></section>'
  end
  h[#h + 1] = string.format('<p class="sub" style="margin-top:40px">Chart Cue %s &middot; %s &middot; MIT License</p>',
    html_esc(CFG.VERSION), html_esc(CFG.AUTHOR))
  h[#h + 1] = "</main></body></html>"
  Util.ensure_dir(CFG.BASE_DIR)
  local f = io.open(CFG.GUIDE_FILE, "wb")
  if not f then return false end
  f:write(table.concat(h, "\n")); f:close()
  return true
end

function UI.open_guide()
  if UI.write_guide() then
    r.ExecProcess('cmd.exe /C start "" "' .. CFG.GUIDE_FILE .. '"', CFG.EXEC_NOWAIT)
  else
    Msg.notify("Cannot write the guide to " .. CFG.GUIDE_FILE, true, "help")
  end
end

-- Help panel (opened with the "?" button at the end of the tab strip)
function UI.draw_help_tab(ctx)
  UI.heading(ctx, "Help")
  do -- the guide button, centred in the panel
    local label = "Open the full guide in your browser"
    local bw = UI.btn_w(ctx, label, 0) + 40
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, (UI.panel_w(ctx) - bw) / 2))
    if UI.button(ctx, label, bw, UI.h(ctx)) then UI.open_guide() end
  end
  UI.tip(ctx, "Opens a longer guide with more details, a table of contents and a print option.")
  UI.section_msg(ctx, "help")
  UI.vgap(ctx, UI.sp("LIST"))
  UI.list_header(ctx, { { "Topics - click a topic to open it", 0 } })
  -- one topic open at a time (R.help_cur); R.help_open opens a topic from elsewhere (e.g. "Getting started")
  if R.help_open then R.help_cur = R.help_open; R.help_open = nil end
  for i, t in ipairs(HELP_TOPICS) do
    if t.guide_only then goto continue end
    ImGui.SetNextItemOpen(ctx, R.help_cur == i)
    local open = ImGui.CollapsingHeader(ctx, t.title .. "##help" .. i)
    if open ~= (R.help_cur == i) then
      R.help_cur = open and i or nil
      UI.panel_restore(); if open then R.fit_req = true end -- fit the opened topic
    end
    if open then
      ImGui.Indent(ctx, 8)
      UI.wrapped(ctx, t.text)
      ImGui.Unindent(ctx, 8)
      UI.vgap(ctx, UI.sp("LIST"))
    end
    ::continue::
  end

  UI.group_sep(ctx)
  UI.heading(ctx, "About")
  UI.value(ctx, "Version", CFG.VERSION)
  UI.value(ctx, "Author", CFG.AUTHOR)
  UI.value(ctx, "License", "MIT")
  UI.path_row(ctx, "Installed in", script_file, "(unknown)", "")
  -- feedback: GitHub Issues now; the REAPER forum button is disabled until there is a forum thread
  do
    local _, cw = UI.row_start(ctx, "Send feedback")
    local hw = UI.std_w(ctx, "GitHub Issues", math.floor((cw - 8) / 2))
    local nc, nv = UI.push_kind(ctx, "primary")
    if UI.button(ctx, "GitHub Issues", hw, UI.h(ctx)) then
      r.ExecProcess('cmd.exe /C start "" "' .. CFG.FEEDBACK_URL .. '"', CFG.EXEC_NOWAIT)
    end
    UI.pop_kind(ctx, nc, nv)
    UI.tip(ctx, "Opens the Chart Cue page for problems and ideas on GitHub, in your browser.")
    ImGui.SameLine(ctx, 0, 8)
    ImGui.BeginDisabled(ctx, true)
    UI.button(ctx, "REAPER forum", hw, UI.h(ctx))
    ImGui.EndDisabled(ctx) -- always paired with BeginDisabled above
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then ImGui.SetTooltip(ctx, "Coming soon.") end
    UI.note(ctx, "For a problem, add the diagnostic log (Settings > General > Troubleshooting).", COL.GREY)
  end
end

-- Cues tab: the cue list; a note and a mode button when the mode is not Cue list.
function UI.draw_cues_tab(ctx)
  UI.draw_cue_list(ctx) -- the "Use Cue list mode" note is the first row of its "Cue settings" section
  R.cue_part_ctx = nil -- the PDF 2 list context ends with the Cues tab (playback must not see it)
end

-- Settings tab: one collapsible section per area. The open section is saved (S.settings_open).
local SETTINGS_SECTIONS = {
  { "Autoscroll", UI.draw_autoscroll_tab },
  { "MIDI", UI.draw_midi_tab },
  { "Display", UI.draw_display_tab },
  { "General", UI.draw_project_tab }, -- project file, open/close, troubleshooting
}
-- One section open at a time (or none): a click on a section closes the open one.
-- The section bars look like the Help topics (collapsing headers).
function UI.draw_settings_tab(ctx)
  local cur = S.settings_open:find("1", 1, true) or 0 -- the open section (older settings may list several: the first wins)
  for i, sec in ipairs(SETTINGS_SECTIONS) do
    ImGui.SetNextItemOpen(ctx, cur == i)
    local open = ImGui.CollapsingHeader(ctx, sec[1] .. "##settings" .. i)
    if open ~= (cur == i) then
      cur = open and i or 0
      UI.panel_restore(); if open then R.fit_req = true end -- fit the opened section
      local t = {}
      for j = 1, #SETTINGS_SECTIONS do t[j] = (j == cur) and "1" or "0" end
      S.settings_open = table.concat(t)
      Util.mark_dirty()
    end
    if open then
      ImGui.Indent(ctx, 8)
      ImGui.PushID(ctx, sec[1]) -- the sections share one panel: keep their widget IDs apart
      sec[2](ctx)
      ImGui.PopID(ctx)          -- always paired with PushID above
      ImGui.Unindent(ctx, 8)
      UI.vgap(ctx, UI.sp("LIST"))
    end
  end
end

local TAB_DRAW = { UI.draw_library_tab, UI.draw_regions_tab, UI.draw_cues_tab, UI.draw_settings_tab, UI.draw_help_tab }

---------------------------------------------------------------------------
-- UI: TOOLBAR, TAB STRIP, PANEL, STATUS, VIEW
---------------------------------------------------------------------------
-- Tab strip: the selected tab is taller, in the panel colour, with an accent bar on top, and it
-- merges into the panel below it. Other tabs are text only, with a soft hover fade.
function UI.draw_tab_strip(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  local n = TAB_FIRST_SETTING - 1        -- text tabs; Settings (gear) and Help ("?") are icon tabs
  local gap, h = CFG.TAB_GAP, CFG.TAB_H
  local lift = 6                         -- the selected tab is this much taller
  local help_w = h
  local tab_w = math.floor((aw - 2 * help_w - gap * (n + 1) - CFG.TAB_GROUP_GAP - 8) / n)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local strip_b = y0 + h + lift          -- bottom of the strip = top of the panel
  local open = S.panel_open
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + aw, strip_b, COL.TAB_BG, 8,
    open and ImGui.DrawFlags_RoundCornersTop() or ImGui.DrawFlags_RoundCornersAll())

  local attn = UI.attention_count()
  local clicked
  local function tab(i, label, w, x)
    local active = (S.tab == i)
    local merged = active and open
    -- the selected tab starts at the top of the strip, so the gap below the toolbar (UI.sp "EDGE")
    -- is the same as the gap above it; other tabs are lower by `lift`
    local top = merged and y0 or (y0 + lift)
    local bottom = merged and (strip_b + 1) or (strip_b - 4)
    ImGui.SetCursorScreenPos(ctx, x, top)
    ImGui.InvisibleButton(ctx, "##tab" .. i, w, bottom - top)
    local hov = ImGui.IsItemHovered(ctx)
    if ImGui.IsItemClicked(ctx) then clicked = i end
    if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    local hv = UI.anim("tab" .. i, hov and 1 or 0)
    if merged then
      ImGui.DrawList_AddRectFilled(dl, x, top, x + w, bottom, COL.PANEL_BG, 8, ImGui.DrawFlags_RoundCornersTop())
      ImGui.DrawList_AddRectFilled(dl, x + 8, top, x + w - 8, top + 3, COL.ACCENT, 2)
    else
      if hv > 0 then
        ImGui.DrawList_AddRectFilled(dl, x, top, x + w, bottom, Util.lerp_col(COL.TAB_BG, COL.TAB_HOVER, hv), 7)
      end
      if active then ImGui.DrawList_AddRect(dl, x, top, x + w, bottom, COL.ACCENT, 7, 0, 1.5) end
    end
    local col = merged and COL.TEXT_MAIN or Util.lerp_col(COL.TEXT_DIM, COL.TEXT_MAIN, hv)
    if i == TAB_REGIONS and attn > 0 and not merged then col = COL.YELLOW end
    if i == TAB_FIRST_SETTING then
      UI.draw_gear_icon(dl, x + w / 2, (top + bottom) / 2, col)
      return
    end
    UI.push_bold_font(ctx, merged)
    local tw = ImGui.CalcTextSize(ctx, label)
    ImGui.DrawList_AddText(dl, x + math.floor((w - tw) / 2), UI.text_y(ctx, top, bottom - top), col, label)
    UI.pop_font(ctx)
  end

  local x = x0 + 4
  for i = 1, n do
    local name = TAB_NAMES[i]
    local label = name
    if i == TAB_REGIONS and attn > 0 then
      -- use the longest badge variant that fits the tab width
      UI.push_bold_font(ctx)
      local variants = { string.format("%s (%d need a PDF)", name, attn), string.format("%s (%d)", name, attn), name .. "!" }
      label = variants[#variants]
      for _, v in ipairs(variants) do
        if (ImGui.CalcTextSize(ctx, v)) <= tab_w - 16 then label = v; break end
      end
      UI.pop_font(ctx)
    end
    tab(i, label, tab_w, x)
    if i == TAB_REGIONS and attn > 0 and ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, (attn == 1 and "1 region needs a PDF." or string.format("%d regions need a PDF.", attn))
        .. "\nClick to see the region list.")
    end
    x = x + tab_w + gap
  end
  x = x + CFG.TAB_GROUP_GAP
  tab(TAB_FIRST_SETTING, "", help_w, x)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Settings") end
  x = x + help_w + gap
  tab(TAB_HELP, "?", help_w, x)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, "Help: how Chart Cue works") end

  local below = open and 0 or UI.sp("CLOSED_TABS")
  ImGui.SetCursorScreenPos(ctx, x0, strip_b + below)
  ImGui.Dummy(ctx, 0, 0)
  ImGui.SetCursorScreenPos(ctx, x0, strip_b + below)

  if clicked then
    R.ask = nil -- an open question belongs to the tab it was asked in
    if S.tab == clicked then S.panel_open = not S.panel_open -- active tab again: collapse / expand
    else S.tab = clicked; S.panel_open = true end
    UI.panel_on_tab_click()
    Util.mark_dirty()
  end
end

-- Panel height help (only on a click, never during playback):
--   a section / topic that grew the panel gives the space back when it closes or the tab changes;
--   a tab click with a panel below CFG.PANEL_SMALL_FRAC returns it to the default height.
function UI.panel_restore()
  if R.panel_prev ~= nil then S.panel_h = R.panel_prev; R.panel_prev = nil; Util.mark_dirty() end
end
function UI.panel_on_tab_click()
  UI.panel_restore()
  if Util.playing() or not R.panel_ph or not R.panel_total_h or R.panel_total_h <= 0 then return end
  if S.panel_h > 0 and R.panel_ph < R.panel_total_h * CFG.PANEL_SMALL_FRAC then S.panel_h = 0; Util.mark_dirty() end
end

-- The open tab's panel: a child window whose bottom edge can be dragged to resize.
-- The child scrolls vertically when its content is taller than the panel.
function UI.draw_panel(ctx, status_h)
  local _, free_h = ImGui.GetContentRegionAvail(ctx)
  local max_h = math.max(CFG.PANEL_MIN_H, free_h - status_h - CFG.MIN_VIEW_H - CFG.SPLIT_H - 6)
  local want = (S.panel_h > 0) and S.panel_h or math.floor((free_h - status_h) * CFG.PANEL_DEFAULT_FRAC)
  local ph = Util.clamp(want, CFG.PANEL_MIN_H, max_h)
  -- a Settings section or Help topic was opened (last frame): grow the panel to fit it, at most to
  -- CFG.PANEL_FIT_FRAC of the free height; the height before is kept in R.panel_prev (UI.panel_restore)
  local total_h = free_h - status_h
  if R.fit_req and R.panel_content_h then
    R.fit_req = nil
    local need = math.ceil(R.panel_content_h)
    if need > ph and not Util.playing() then
      if R.panel_prev == nil then R.panel_prev = S.panel_h end
      S.panel_h = Util.clamp(need, CFG.PANEL_MIN_H, math.min(max_h, math.floor(total_h * CFG.PANEL_FIT_FRAC)))
      ph = Util.clamp(S.panel_h, CFG.PANEL_MIN_H, max_h); Util.mark_dirty()
    end
  end
  R.panel_ph, R.panel_total_h = ph, total_h -- for UI.panel_on_tab_click

  -- panel background drawn here: square top (joins the selected tab), rounded bottom
  do
    local px, py = ImGui.GetCursorScreenPos(ctx)
    local pw = ImGui.GetContentRegionAvail(ctx)
    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + pw, py + ph, COL.PANEL_BG, 8,
      ImGui.DrawFlags_RoundCornersBottom())
  end
  local vis = ImGui.BeginChild(ctx, "##panel" .. S.tab, 0, ph)
  if vis then
    ImGui.SetCursorPosY(ctx, UI.sp("PANEL")) -- exact top gap (no row spacing above the first item)
    ImGui.Indent(ctx, 10)
    TAB_DRAW[S.tab](ctx)
    ImGui.Unindent(ctx, 10)
    ImGui.Dummy(ctx, 0, UI.sp("PANEL")) -- same gap at the bottom
    R.panel_content_h = ImGui.GetCursorPosY(ctx) -- the height its content needs (for the fit above)
    ImGui.EndChild(ctx)
  end

  -- resize grip under the panel
  local gx, gy = ImGui.GetCursorScreenPos(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  aw = math.max(1, aw)
  ImGui.InvisibleButton(ctx, "##panelgrip", aw, CFG.SPLIT_H)
  local hov, act = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
  if hov or act then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS()) end
  if act then
    local _, dy = ImGui.GetMouseDelta(ctx)
    if dy ~= 0 then S.panel_h = Util.clamp(ph + dy, CFG.PANEL_MIN_H, max_h); R.panel_prev = nil; Util.mark_dirty() end -- your height counts
  end
  -- double-click: default height -> large; any other height -> default (0 = default height)
  if hov and ImGui.IsMouseDoubleClicked(ctx, 0) then
    R.panel_prev = nil
    S.panel_h = (S.panel_h == 0) and Util.clamp(math.floor((free_h - status_h) * CFG.PANEL_LARGE_FRAC), CFG.PANEL_MIN_H, max_h) or 0
    Util.mark_dirty()
  end
  if hov and not act then ImGui.SetTooltip(ctx, "Drag to change the panel height.\nDouble-click: larger panel, or back to the default height.") end
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx = gx + aw / 2
  local cy = gy + CFG.SPLIT_H / 2
  local col = (hov or act) and COL.ACCENT or COL.TEXT_DIM
  if hov or act then ImGui.DrawList_AddLine(dl, gx + 8, cy, gx + aw - 8, cy, COL.ACCENT, 1) end
  ImGui.DrawList_AddRectFilled(dl, cx - 32, cy - 2.5, cx + 32, cy + 2.5, col, 3)
end

-- Status line 2 with a PDF open: "Page 2 / 5", plus "Next: page 3 at <time>" in the Cue list
-- (time in the project's cue unit) and Markers modes. Rebuilt at most every 0.1 s.
-- "Next: page 3 at 17.1.00" (Markers and Cue list modes), or nil when no page turn follows.
function UI.next_turn_text()
  local now = Util.now()
  if R.page_status ~= nil and now - R.page_status_t < 0.1 then return R.page_status or nil end
  local txt
  local mode, t = Nav.scroll_mode(), Project.time_pos()
  if R.total > 0 and mode == "cues" then
    local reg = Cues.playing_region()
    local p = Cues.from_time(reg, t)
    for _, c in ipairs(Cues.list(reg)) do
      if c.page and c.pos > p + 1e-6 and Nav.changes_view(c.page) then
        txt = string.format("Next: page %d at %s", c.page, Cues.label(reg, c.pos)); break
      end
    end
  elseif R.total > 0 and mode == "marker" then
    for _, m in ipairs(R.page_pts) do
      if m.t > t + 1e-6 and Nav.changes_view(m.page) then
        txt = string.format("Next: page %d at %s", m.page, r.format_timestr_pos(m.t, "", 2)); break
      end
    end
  end
  R.page_status, R.page_status_t = txt or false, now
  return txt
end

-- Shortcut list for status line 2: the most useful keys first (the end is cut off in a narrow window).
-- C and S work only while Record cues is on, so they show only then.
local SHORTCUTS = "Left/Right page  |  Home top  |  Ctrl+wheel zoom  |  F performance  |  L lock  |  R record cues"
local SHORTCUTS_REC = "C page turn  |  S scroll point  |  " .. SHORTCUTS
local SHORTCUTS_TIP = "Left arrow / Page Up: previous page\nRight arrow / Page Down: next page\nHome: top of the page\n"
  .. "Ctrl + mouse wheel, Ctrl and + / -: zoom.  Ctrl and 0: fit the page width\nF: performance mode (F or Esc goes back)\n"
  .. "L: lock\nR: record cues on / off (Cue list mode)\nC: add a page turn, S: add a scroll point (while Record cues is on)\n\n"
  .. "The keys work when the Chart Cue window is active."

-- The project has cues or PDF markers that the current mode does not use:
-- returns message, mode to switch to, button label (or nil).
function UI.mode_hint()
  if P.hint_off then return nil end -- "Not now" for this project
  local mode = Nav.scroll_mode()
  local ncues = 0
  for _, list in pairs(P.cues) do ncues = ncues + #list end
  local nmark = #R.page_pts + #R.scroll_pts
  if ncues > 0 and mode ~= "cues" and not (mode == "marker" and nmark > 0) then
    return string.format("This project has %d cue(s).", ncues), "cues", "Switch to Cue list"
  end
  if nmark > 0 and ncues == 0 and mode ~= "marker" then
    return string.format("This project has %d PDF marker(s).", nmark), "marker", "Switch to Markers"
  end
  return nil
end

function UI.draw_status(ctx)
  local pct = (R.max_y > 0) and (S.scroll_y / R.max_y * 100) or 0
  local reg = R.cur_region_key and Project.region_by_key(R.cur_region_key)
  local parts = {}
  parts[#parts + 1] = string.format("Scroll %.0f%%", pct)
  if reg then parts[#parts + 1] = "Region: " .. reg.name end
  local nxt = UI.next_turn_text()
  if nxt then parts[#parts + 1] = nxt end
  if UI.midi_in_use() then
    parts[#parts + 1] = string.format("MIDI %s%s", S.mode, R.last_cc and (" CC=" .. R.last_cc) or "")
  end
  local aw = ImGui.GetContentRegionAvail(ctx)
  ImGui.Text(ctx, UI.trunc_text(ctx, table.concat(parts, "  |  "), aw - 6))

  -- line 2, by priority: errors > import progress > region has no PDF > warnings > normal
  local needs = R.empty_region
  local recent = Msg.recent(nil, true)
  local hint_txt, hint_mode, hint_lbl = UI.mode_hint() -- once per frame (it counts every cue)
  if R.error then
    UI.row_text(ctx, UI.trunc_text(ctx, R.error, aw - 140), COL.RED)
    ImGui.SameLine(ctx)
    if UI.button(ctx, "Retry rendering") then PDF.retry_failed() end
  elseif PDF.engine() == "poppler" and R.exe == nil then
    ImGui.TextColored(ctx, COL.RED, UI.trunc_text(ctx, PDF.poppler_help(), aw - 6))
  elseif R.picker then
    ImGui.TextColored(ctx, COL.YELLOW, "Waiting for the folder dialog...")
  elseif R.import then
    ImGui.TextColored(ctx, COL.YELLOW, string.format("Importing folder... %d PDF(s) added so far", R.import.added))
  elseif R.copy or #R.copyq > 0 then
    ImGui.TextColored(ctx, COL.YELLOW, string.format("Copying PDFs into the project... %d left", Project.copy_pending()))
  elseif needs then
    ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, string.format(
      needs.status == "ignored" and 'Region "%s" is ignored (no PDF).' or 'No PDF assigned to region "%s".', needs.name), aw - 6))
  elseif recent then
    ImGui.TextColored(ctx, recent.err and COL.RED or COL.GREEN, UI.trunc_text(ctx, recent.text, aw - 6))
  elseif PDF.engine() == "poppler" and not R.pdfinfo_ok then
    ImGui.TextColored(ctx, COL.YELLOW, "pdfinfo.exe missing next to pdftoppm.exe - see Settings > Display.")
  elseif R.warn then
    ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, R.warn, aw - 6))
  elseif #R.marker_warns > 0 then
    ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, string.format("Marker warning: %s%s", R.marker_warns[1],
      #R.marker_warns > 1 and string.format(" (+%d more)", #R.marker_warns - 1) or ""), aw - 6))
  elseif hint_txt then
    UI.row_text(ctx, UI.trunc_text(ctx, hint_txt, aw - 230), COL.YELLOW)
    ImGui.SameLine(ctx)
    ImGui.BeginDisabled(ctx, Util.playing())
    if UI.button(ctx, hint_lbl .. "##modehint") and not Util.playing() then Nav.set_scroll_mode(hint_mode) end
    ImGui.EndDisabled(ctx)
    if Util.playing() and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, MODE_LOCKED_TIP)
    end
    ImGui.SameLine(ctx)
    if UI.button(ctx, "Not now##modehint") then P.hint_off = true; Util.mark_pdirty() end
    UI.tip(ctx, "Hides this hint for this project. It is saved with the project.")
  elseif Nav.scroll_mode() == "cues" and R.total > 0 and #Cues.list(Cues.playing_region()) == 0 then
    ImGui.TextColored(ctx, COL.YELLOW, "Cue list is on, but this song has no cues yet (Cues tab).")
  elseif Nav.scroll_mode() == "marker" and #R.scroll_pts == 0 and #R.page_pts == 0 then
    ImGui.TextColored(ctx, COL.YELLOW, "Marker autoscroll is on but no PDFSCROLL or PDFPAGE markers were found.")
  else
    ImGui.TextDisabled(ctx, UI.trunc_text(ctx, R.rec and SHORTCUTS_REC or SHORTCUTS, aw - 6))
    UI.tip(ctx, SHORTCUTS_TIP)
  end
end

-- Only the error line of the status bar (used while controls are hidden during playback).
function UI.draw_error_line(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx)
  UI.row_text(ctx, UI.trunc_text(ctx, R.error, aw - 140), COL.RED)
  ImGui.SameLine(ctx)
  if UI.button(ctx, "Retry rendering") then PDF.retry_failed() end
end

-- Lock icon (drawn, no icon font): body + shackle; the shackle is lifted and open when unlocked.
function UI.draw_lock_icon(dl, cx, cy, closed, col)
  local bw, bh = 12, 9                 -- body
  local bx0, by0 = cx - bw / 2, cy - 1
  ImGui.DrawList_AddRectFilled(dl, bx0, by0, bx0 + bw, by0 + bh, col, 2)
  local rr = 3.5                       -- shackle radius
  local sx = closed and cx or (cx + 3) -- open: moved right
  local sy = closed and (by0 - 1) or (by0 - 3)
  ImGui.DrawList_PathArcTo(dl, sx, sy - 2, rr, math.pi, 2 * math.pi)
  ImGui.DrawList_PathLineTo(dl, sx + rr, sy + (closed and 1 or 0))
  ImGui.DrawList_PathStroke(dl, col, 0, 2)
  ImGui.DrawList_AddLine(dl, sx - rr, sy - 2, sx - rr, closed and (sy + 1) or (sy - 0.5), col, 2)
end

function UI.toggle_lock()
  R.lock = not R.lock
  Msg.notify(R.lock and "Locked: the page ignores the mouse and the keys during playback (L to unlock)."
    or "Unlocked.", false)
end

function UI.locked() return R.lock and Util.playing() end

-- Record cues (R): only in the Cue list mode, never while locked.
function UI.toggle_rec()
  if not R.rec and Nav.scroll_mode() ~= "cues" then
    -- R key in another mode: a hint, not an error (the Record button is hidden in that mode)
    Msg.notify("Record cues works only in the Cue list autoscroll mode.", false); return
  end
  R.rec = not R.rec
  Msg.notify(R.rec and "Record cues on: C, S and the MIDI cue buttons add cues (R to stop)."
    or "Record cues off.", false)
end

-- C / S keys and the MIDI cue CCs add cues only when this is true.
function UI.can_record() return R.rec and Nav.scroll_mode() == "cues" and not UI.locked() end

-- Record icon: a filled circle; full red when armed, dim red when off.
function UI.draw_rec_icon(dl, cx, cy, armed)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, 5.5, armed and COL.RED or ((COL.RED & 0xFFFFFF00) | 0x80))
end

-- Toolbar icons (drawn, the same line weight as the lock): "prev", "next", "minus", "plus",
-- "hide" / "show" (a window with a top bar and a chevron: up = controls fold away when playing, down = they stay).
function UI.draw_tb_icon(dl, cx, cy, kind, col)
  if kind == "hide" or kind == "show" then
    ImGui.DrawList_AddRect(dl, cx - 7, cy - 6, cx + 7, cy + 6, col, 2, 0, 1.5)
    ImGui.DrawList_AddLine(dl, cx - 7, cy - 2.5, cx + 7, cy - 2.5, col, 1.5)
    local d = (kind == "hide") and 1.5 or -1.5 -- up or down
    ImGui.DrawList_PathLineTo(dl, cx - 3, cy + 1.5 + d)
    ImGui.DrawList_PathLineTo(dl, cx, cy + 1.5 - d)
    ImGui.DrawList_PathLineTo(dl, cx + 3, cy + 1.5 + d)
    ImGui.DrawList_PathStroke(dl, col, 0, 1.5)
  elseif kind == "prev" or kind == "next" then
    local d = (kind == "prev") and 1 or -1
    ImGui.DrawList_PathLineTo(dl, cx + d * 2.5, cy - 5)
    ImGui.DrawList_PathLineTo(dl, cx - d * 2.5, cy)
    ImGui.DrawList_PathLineTo(dl, cx + d * 2.5, cy + 5)
    ImGui.DrawList_PathStroke(dl, col, 0, 2)
  else
    ImGui.DrawList_AddLine(dl, cx - 5.5, cy, cx + 5.5, cy, col, 2)
    if kind == "plus" then ImGui.DrawList_AddLine(dl, cx, cy - 5.5, cx, cy + 5.5, col, 2) end
  end
end

-- Square toolbar button with a drawn icon; returns true when clicked.
function UI.icon_button(ctx, id, w, kind)
  local hit = UI.button(ctx, id, w, 0)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  UI.draw_tb_icon(ImGui.GetWindowDrawList(ctx), math.floor((x0 + x1) / 2) + 0.5,
    math.floor((y0 + y1) / 2) + 0.5, kind, COL.TEXT_MAIN)
  return hit
end

-- Gear icon (the Settings tab): a ring with 8 teeth.
function UI.draw_gear_icon(dl, cx, cy, col)
  for k = 0, 7 do
    local a = k * math.pi / 4
    local c, s = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * 5, cy + s * 5, cx + c * 8.5, cy + s * 8.5, col, 3)
  end
  ImGui.DrawList_AddCircle(dl, cx, cy, 4.5, col, 0, 3)
end

function UI.toggle_perf()
  R.perf = not R.perf
  R.perf_t = Util.now()
end

function UI.handle_keys(ctx)
  if not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_RootAndChildWindows()) or ImGui.IsAnyItemActive(ctx) then return end
  local K = function(name) return r["ImGui_Key_" .. name]() end
  local ctrl = (ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl()) ~= 0
  -- these keys always work, also in lock mode (so you can never lock yourself out)
  if not ctrl and ImGui.IsKeyPressed(ctx, K("F"), false) then UI.toggle_perf() end
  if R.perf and ImGui.IsKeyPressed(ctx, K("Escape"), false) then UI.toggle_perf() end
  if not ctrl and ImGui.IsKeyPressed(ctx, K("L"), false) then UI.toggle_lock() end
  if UI.locked() then return end
  if ImGui.IsKeyPressed(ctx, K("LeftArrow")) or ImGui.IsKeyPressed(ctx, K("PageUp")) then Nav.step(-1) end
  if ImGui.IsKeyPressed(ctx, K("RightArrow")) or ImGui.IsKeyPressed(ctx, K("PageDown")) then Nav.step(1) end
  if not ctrl and ImGui.IsKeyPressed(ctx, K("R"), false) then UI.toggle_rec() end
  if not ctrl and UI.can_record() then
    if ImGui.IsKeyPressed(ctx, K("C"), false) then Cues.add_page_turn() end
    if ImGui.IsKeyPressed(ctx, K("S"), false) then Cues.add_scroll_point() end
  end
  if ImGui.IsKeyPressed(ctx, K("Home"), false) then
    S.scroll_y = 0; R.abs_target = nil; Util.touch_override(); Util.mark_dirty()
  end
  if ctrl then
    if ImGui.IsKeyPressed(ctx, K("Equal")) then Nav.zoom_by(CFG.ZOOM_STEP) end
    if ImGui.IsKeyPressed(ctx, K("Minus")) then Nav.zoom_by(1 / CFG.ZOOM_STEP) end
    if ImGui.IsKeyPressed(ctx, K("0"), false) then Nav.fit_width() end
    if ImGui.IsKeyPressed(ctx, K("Z"), false) and S.tab == TAB_CUES and S.panel_open then
      if (ImGui.GetKeyMods(ctx) & ImGui.Mod_Shift()) ~= 0 then Cues.redo() else Cues.undo() end -- Ctrl+Shift+Z: redo
    end
  end
end

-- First start (the library is empty): a welcome with 3 steps above the add buttons.
local WELCOME_STEPS = {
  "1.  Add your PDF charts.",
  "2.  Chart Cue gives each region the PDF with the same song name. For other regions, choose a PDF in the Regions tab.",
  "3.  Choose an autoscroll mode, then press Play.",
}

-- Centered empty state when no PDF is loaded; its buttons are the Library tab's actions.
-- With an empty library it is the welcome (also inside a region without a PDF).
function UI.draw_empty_state(ctx, x0, y0, area_w, view_h, dl)
  local cx, cy = x0 + area_w / 2, y0 + view_h / 2
  local welcome = #P.pdfs == 0
  local top = welcome and (cy - 140) or (cy - 54)
  UI.push_bold_font(ctx)
  local msg = welcome and "Welcome to Chart Cue" or "No PDF open"
  local tw = ImGui.CalcTextSize(ctx, msg)
  ImGui.DrawList_AddText(dl, cx - tw / 2, top, COL.TEXT_BRIGHT, msg)
  UI.pop_font(ctx)
  local by = cy - 20
  if welcome then
    local text_w = math.floor(math.max(120, math.min(440, area_w - 40)))
    local c = R.welcome_wrap
    if not c or c.w ~= text_w then -- word wrap, cached per width; continued lines are indented
      c = { w = text_w }
      local indent = ImGui.CalcTextSize(ctx, "1. ") -- gmatch joins the words with 1 space
      for _, step in ipairs(WELCOME_STEPS) do
        local line, ind = "", 0
        for word in step:gmatch("%S+") do
          local try = (line == "") and word or (line .. " " .. word)
          if line ~= "" and ind + ImGui.CalcTextSize(ctx, try) > text_w then
            c[#c + 1] = { ind, line }; line, ind = word, indent
          else
            line = try
          end
        end
        c[#c + 1] = { ind, line }
      end
      R.welcome_wrap = c
    end
    local sx, lh = cx - text_w / 2, ImGui.GetTextLineHeightWithSpacing(ctx)
    local ly = top + 38
    for i, l in ipairs(c) do
      if i > 1 and l[1] == 0 then ly = ly + 6 end -- a small gap between the steps
      ImGui.DrawList_AddText(dl, sx + l[1], ly, COL.TEXT_MAIN, l[2])
      ly = ly + lh
    end
    by = ly + 16
  end
  local b1, b2 = "Add PDF...", "Add from folder..."
  local bw = UI.std_w(ctx, b2, area_w - 40)
  ImGui.SetCursorScreenPos(ctx, cx - bw / 2, by)
  local nc, nv = UI.push_kind(ctx, "primary")
  local hit1 = UI.button(ctx, b1, bw, 30)
  UI.pop_kind(ctx, nc, nv)
  if hit1 then PDF.browse_add_pdf(true) end
  ImGui.SetCursorScreenPos(ctx, cx - bw / 2, by + 38)
  if UI.button(ctx, b2, bw, 30) then Project.start_folder_pick() end
  -- link-style button to the "Getting started" help topic
  local link = welcome and "Open 'Getting started'" or "New to Chart Cue? Read 'Getting started'"
  local lw = ImGui.CalcTextSize(ctx, link) + 16
  ImGui.SetCursorScreenPos(ctx, cx - lw / 2, by + 78)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.TRANSPARENT)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ACTIVE_BG)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACTIVE_BG)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.ACCENT_HOVER)
  if UI.button(ctx, link, lw, 0) then
    S.tab = TAB_HELP; S.panel_open = true; R.help_open = 1; Util.mark_dirty()
  end
  ImGui.PopStyleColor(ctx, 4)
end

-- Empty state for a region with no assigned PDF: large region name, message, one big central action
-- and smaller secondary actions. Works while playing or stopped, with controls shown or hidden.
function UI.draw_region_empty_state(ctx, x0, y0, area_w, view_h, reg)
  local cx = x0 + area_w / 2
  local inner_w = math.max(120, area_w - 40)
  local ambiguous = (reg.status == "ambiguous")

  -- keep the dropdown selection in sync with the region (ambiguous: preselect the first match)
  if R.empty_sel_key ~= reg.key then
    R.empty_sel_key = reg.key; R.empty_sel = 0; R.choose_existing = false
    if ambiguous and reg.cands[1] then
      for j, p in ipairs(P.pdfs) do if Util.same_path(p, reg.cands[1]) then R.empty_sel = j - 1 end end
    end
  end
  R.empty_sel = Util.clamp(R.empty_sel, 0, math.max(0, #P.pdfs - 1))
  local show_combo = (ambiguous or R.choose_existing)
  local lib_empty = (#P.pdfs == 0)
  local use_assign = show_combo and not lib_empty -- main button assigns the selected PDF

  -- sizes (compact when the PDF area is short so nothing spills outside the view)
  local compact = view_h < (show_combo and 215 or 185)
  local main_h, sec_h, name_h = compact and 30 or 44, compact and 24 or 26, compact and 20 or 38
  local gap = compact and 6 or 10
  local total = name_h + gap + 20 + gap + (show_combo and (26 + gap) or 0) + main_h + gap + sec_h
  local y = y0 + math.max(2, math.floor((view_h - total) / 2))

  -- region name (large)
  if not compact then UI.push_big_font(ctx) end
  local label = UI.trunc_text(ctx, reg.name ~= "" and reg.name or "(unnamed region)", inner_w)
  local nw = ImGui.CalcTextSize(ctx, label)
  ImGui.SetCursorScreenPos(ctx, cx - nw / 2, y)
  ImGui.Text(ctx, label)
  if not compact then UI.pop_font(ctx) end
  y = y + name_h + gap

  -- message
  local ignored = (reg.status == "ignored")
  local msg = ambiguous and "Several PDFs match this region's name. Choose one."
      or (ignored and "This region is ignored. No PDF is shown." or "No PDF assigned to this region.")
  local mw = ImGui.CalcTextSize(ctx, msg)
  ImGui.SetCursorScreenPos(ctx, cx - math.min(mw, inner_w) / 2, y)
  ImGui.TextColored(ctx, COL.YELLOW, UI.trunc_text(ctx, msg, inner_w))
  y = y + 20 + gap

  -- dropdown (ambiguous regions, or "Choose from library")
  local btn_w = math.min(inner_w, 360)
  if show_combo then
    ImGui.SetCursorScreenPos(ctx, cx - btn_w / 2, y)
    if lib_empty then
      ImGui.TextColored(ctx, COL.GREY, "The PDF library is empty.")
    else
      ImGui.SetNextItemWidth(ctx, btn_w)
      _, R.empty_sel = ImGui.Combo(ctx, "##emptypdf", R.empty_sel, UI.pdf_items_string())
    end
    y = y + 26 + gap
  end

  -- main action
  ImGui.SetCursorScreenPos(ctx, cx - btn_w / 2, y)
  if use_assign then
    local pnc, pnv = UI.push_kind(ctx, "primary")
    local assign_hit = UI.button(ctx, "Assign selected PDF", btn_w, main_h)
    UI.pop_kind(ctx, pnc, pnv)
    if assign_hit then
      Project.assign_region_pdf(reg, P.pdfs[R.empty_sel + 1]); return
    end
  else
    local pnc, pnv = UI.push_kind(ctx, "primary")
    local add_hit = UI.button(ctx, "+ Add PDF for this region", btn_w, main_h)
    UI.pop_kind(ctx, pnc, pnv)
    if add_hit then
      local ok, f = r.GetUserFileNameForRead("", "Select a PDF for region \"" .. reg.name .. "\"", "pdf")
      if ok and f and f ~= "" then Project.import_for_region(reg, f); return end
    end
  end
  y = y + main_h + gap

  -- secondary actions
  local sec_total = math.min(inner_w, 440)
  local hw = math.floor((sec_total - 8) / 2)
  ImGui.SetCursorScreenPos(ctx, cx - sec_total / 2, y)
  local sec1 = (ambiguous or R.choose_existing) and "+ Add PDF for this region" or "Choose from library"
  if UI.button(ctx, sec1 .. "##sec1", hw, sec_h) then
    if ambiguous or R.choose_existing then
      local ok, f = r.GetUserFileNameForRead("", "Select a PDF for region \"" .. reg.name .. "\"", "pdf")
      if ok and f and f ~= "" then Project.import_for_region(reg, f); return end
    else
      R.choose_existing = true
    end
  end
  ImGui.SameLine(ctx, 0, 8)
  if ignored then
    if UI.button(ctx, "Stop ignoring##sec2", hw, sec_h) then Project.unignore_region(reg); return end
  else
    if UI.button(ctx, "Ignore this region##sec2", hw, sec_h) then Project.ignore_region(reg); return end
  end
end

-- Page tint: white, or grey in dim mode (ImGui multiplies the image colours by this value).
function UI.page_tint()
  if not S.dim_page then return COL.WHITE end
  local v = math.floor(255 * Util.clamp(S.dim_level, 0.25, 1) + 0.5)
  return (v << 24) | (v << 16) | (v << 8) | 0xFF
end

-- Scroll points (0..100) that belong to the page on screen, in Markers or Cue list mode.
function UI.scroll_marks()
  local mode = Nav.scroll_mode()
  local reg_key = (mode == "cues") and Cues.key(Cues.playing_region())
    or (R.active_region and R.active_region.key) or ""
  local c = R.marks_cache
  if c and c.mode == mode and c.reg == reg_key and c.page == S.page and c.ver == R.lib_ver
      and c.cc == R.state_cc and c.P == P then
    return c.out
  end
  local out = UI.scroll_marks_build(mode)
  R.marks_cache = { mode = mode, reg = reg_key, page = S.page, ver = R.lib_ver, cc = R.state_cc, P = P, out = out }
  return out
end

function UI.scroll_marks_build(mode)
  local pp, sp
  if mode == "cues" then
    pp, sp = Cues.points(Cues.playing_region())
  elseif mode == "marker" then
    pp, sp = R.page_pts, R.scroll_pts
    local reg = R.active_region
    if reg then -- only the markers of the song on screen
      local fp, fs = {}, {}
      for _, p in ipairs(pp) do if p.t >= reg.start and p.t < reg.stop then fp[#fp + 1] = p end end
      for _, q in ipairs(sp) do if q.t >= reg.start and q.t < reg.stop then fs[#fs + 1] = q end end
      pp, sp = fp, fs
    end
  else
    return {}
  end
  local out = {}
  for _, q in ipairs(sp) do
    local page = 1
    for _, p in ipairs(pp) do if p.t <= q.t then page = p.page else break end end
    if page == S.page then out[#out + 1] = q.pct end
  end
  return out
end

-- Part 2: a 2nd PDF on screen next to part 1 (Library > right-click > "Show as PDF 2").
-- Not saved; it closes with "Close PDF 2" or when the project changes.
function UI.show_part2(path)
  if P.split_off then Msg.notify("Split view is off for this project (Settings > Display > Page layout).", false); return end
  if not R.part2 then R.part2 = Pane.new() end
  Pane.part2(PDF.open_pdf, path, false)
  R.active_part = 2
end

-- The song's PDF 2 in part 2 (region switching): opened, kept, or closed when the song has none
-- (or Split view is off). It starts at the top of page 1, like PDF 1.
function UI.sync_part2(reg)
  local p2 = reg and reg.pdf2
  if not p2 or P.split_off or not Util.file_exists(p2) then UI.close_part2(); return end
  if not R.part2 then R.part2 = Pane.new() end
  if R.part2.r.total == 0 or not Util.same_path(R.part2.s.pdf_path, p2) then Pane.part2(PDF.open_pdf, p2, false) end
  R.part2.s.page, R.part2.s.scroll_y, R.part2.s.scroll_x = 1, 0, 0
  R.part2.r.active_region, R.part2.r.mpage_last = reg, nil -- its cues work inside this region
end

-- true when part 2 shows what the region needs (its PDF 2, or nothing)
function UI.part2_matches(reg)
  local p2 = (not P.split_off) and reg.pdf2 or nil
  if not p2 then return R.part2 == nil end
  return R.part2 ~= nil and Util.same_path(R.part2.s.pdf_path, p2)
end

function UI.close_part2()
  if not R.part2 then return end
  Pane.part2(PDF.reset_state) -- releases its page images
  R.part2, R.active_part = nil, 1
end

-- One part of the split view, drawn as that part (UI.draw_parts runs it with Pane.part2 for part 2).
function UI.draw_part_view(ctx, w, h)
  R.view_w, R.view_h = w - CFG.SCROLLBAR_W - 4, h
  UI.draw_view(ctx, w, h)
end

-- The "PDF 1" / "PDF 2" tag at the top right of a part (the active one in the accent colour).
function UI.part_tag(ctx, dl, txt, px, py, pw, active)
  local tw, th = ImGui.CalcTextSize(ctx, txt)
  local tx = px + pw - CFG.SCROLLBAR_W - 14 - tw
  ImGui.DrawList_AddRectFilled(dl, tx - 6, py + 6, tx + tw + 6, py + th + 14, active and COL.ACCENT or 0x000000AA, 6)
  ImGui.DrawList_AddText(dl, tx, py + 10, active and COL.WHITE or COL.TEXT_DIM, txt)
end

-- The page area: part 1 alone, or part 1 and part 2 with a draggable divider between them
-- (S.split_layout: top and bottom or side by side; S.split_frac: the share of part 1).
function UI.draw_parts(ctx, aw, vh)
  local sbw = CFG.SCROLLBAR_W
  if not R.part2 then
    R.view_w, R.view_h = aw - sbw - 4, vh
    UI.draw_view(ctx, aw, vh)
    return
  end
  local side = (S.split_layout == "side")
  local D = CFG.SPLIT_H -- divider thickness (the same hit area as the panel grip)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local total = (side and aw or vh) - D
  local a = math.floor(total * Util.clamp(S.split_frac, 0.2, 0.8) + 0.5)
  local b = total - a
  local w1, h1 = side and a or aw, side and vh or a
  local w2, h2 = side and b or aw, side and vh or b
  local x2, y2 = side and (x0 + a + D) or x0, side and y0 or (y0 + a + D)
  -- part 1
  ImGui.PushID(ctx, "part1")
  R.view_w, R.view_h = w1 - sbw - 4, h1
  UI.draw_view(ctx, w1, h1)
  ImGui.PopID(ctx)
  -- divider: drag = sizes, double-click = 50 / 50
  local dx, dy = side and (x0 + a) or x0, side and y0 or (y0 + a)
  ImGui.SetCursorScreenPos(ctx, dx, dy)
  ImGui.InvisibleButton(ctx, "##partsplit", side and D or aw, side and vh or D)
  local hov, act = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
  if hov or act then ImGui.SetMouseCursor(ctx, side and ImGui.MouseCursor_ResizeEW() or ImGui.MouseCursor_ResizeNS()) end
  if not ImGui.IsMouseDown(ctx, 0) then R.split_hold = nil end
  if act and not R.split_hold then -- (after a double-click: no drag until the mouse is released)
    local mx, my = ImGui.GetMousePos(ctx)
    local pos = side and (mx - x0 - D / 2) or (my - y0 - D / 2)
    local fr = Util.clamp(pos / math.max(1, total), 0.2, 0.8)
    if math.abs(fr - S.split_frac) > 0.001 then S.split_frac = fr; Util.mark_dirty() end
  end
  if hov and ImGui.IsMouseDoubleClicked(ctx, 0) then S.split_frac = 0.5; R.split_hold = true; Util.mark_dirty() end
  if hov and not act then ImGui.SetTooltip(ctx, "Drag to change the sizes of the 2 PDFs.\nDouble-click: the same size.") end
  local dl = ImGui.GetWindowDrawList(ctx)
  -- the same look as the panel grip: a pill, and a blue line on hover
  local gc = (hov or act) and COL.ACCENT or COL.TEXT_DIM
  if side then
    local cx, cy = dx + D / 2, dy + vh / 2
    if hov or act then ImGui.DrawList_AddLine(dl, cx, dy + 8, cx, dy + vh - 8, COL.ACCENT, 1) end
    ImGui.DrawList_AddRectFilled(dl, cx - 2.5, cy - 32, cx + 2.5, cy + 32, gc, 3)
  else
    local cx, cy = dx + aw / 2, dy + D / 2
    if hov or act then ImGui.DrawList_AddLine(dl, dx + 8, cy, dx + aw - 8, cy, COL.ACCENT, 1) end
    ImGui.DrawList_AddRectFilled(dl, cx - 32, cy - 2.5, cx + 32, cy + 2.5, gc, 3)
  end
  -- part 2
  ImGui.SetCursorScreenPos(ctx, x2, y2)
  ImGui.PushID(ctx, "part2")
  Pane.part2(UI.draw_part_view, ctx, w2, h2)
  ImGui.PopID(ctx)
  -- the active part: a 2 px accent frame
  local ax, ay, aw2, ah2 = x0, y0, w1, h1
  if R.active_part == 2 then ax, ay, aw2, ah2 = x2, y2, w2, h2 end
  ImGui.DrawList_AddRect(dl, ax + 1, ay + 1, ax + aw2 - sbw - 5, ay + ah2 - 1, COL.ACCENT, 3, 0, 2)
  -- "PDF 1" / "PDF 2" tags (top right of each part) while REAPER is stopped: which PDF is where
  if not Util.playing() then
    UI.part_tag(ctx, dl, "PDF 1", x0, y0, w1, R.active_part ~= 2)
    UI.part_tag(ctx, dl, "PDF 2", x2, y2, w2, R.active_part == 2)
  end
  ImGui.SetCursorScreenPos(ctx, x0, y0 + vh) -- below the page area (the status bar follows)
  ImGui.Dummy(ctx, 0, 0)
end

function UI.draw_view(ctx, view_w, view_h)
  local sbw = CFG.SCROLLBAR_W
  local area_w = math.max(1, view_w - sbw - 4)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- a region without a PDF shows its empty state instead of whatever PDF was open before
  -- (during playback the last page can stay: R.kept_key, with a banner)
  local part1 = not R.in_part2 -- region states, banners and badges belong to part 1
  local kept = part1 and R.empty_region and R.kept_key == R.empty_region.key
  local blocked = part1 and (not kept) and R.empty_region or nil
  local img, iw, ih
  local first, second = Nav.spread()
  local img2
  if not blocked then
    img, iw, ih = PDF.get_page_image(first)
    if second then img2 = PDF.get_page_image(second) end
  end
  local scale, disp_w, disp_h = 1, 1, 1
  if img then
    scale = Nav.effective_scale(iw, ih, area_w, view_h)
    R.last_ratio = scale -- screen px per image px (1.0 = pixel-perfect)
    local cw, ch = Nav.content_dims(iw, ih) -- 2 pages: the whole spread
    disp_w, disp_h = math.floor(cw * scale + 0.5), math.floor(ch * scale + 0.5)
    R.cont_step = disp_h + math.floor(iw * 0.02 * scale + 0.5) -- continuous: page + gap
    R.max_y = math.max(0, disp_h - view_h)
    R.max_x = math.max(0, disp_w - area_w)
  else
    R.max_y, R.max_x = 0, 0
  end

  local hovered, active = false, false
  local locked = UI.locked()
  if img then
    ImGui.InvisibleButton(ctx, "##pageview", area_w, view_h)
    hovered, active = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
    -- 2 PDFs: a click (left or right) on a part makes it the active part, and acts at once
    if R.part2 and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByPopup())
        and (ImGui.IsMouseClicked(ctx, 0) or ImGui.IsMouseClicked(ctx, 1)) then
      R.active_part = R.in_part2 and 2 or 1
    end
    if locked then hovered, active = false, false end -- lock mode: no wheel, no dragging, no menu
    -- the toolbar menu (also when a menu is open: a second right-click opens it again at the mouse)
    if not locked and ImGui.IsMouseClicked(ctx, 1) and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByPopup()) then
      R.menu_req = { kind = "main" }
    end
  else
    -- No page image (empty states): a plain Dummy keeps the layout but, unlike an InvisibleButton,
    -- it does not capture hover/clicks, so the empty-state buttons drawn on top are clickable.
    ImGui.Dummy(ctx, area_w, view_h)
  end
  if hovered then
    local wv, wh = ImGui.GetMouseWheel(ctx)
    if wv ~= 0 or wh ~= 0 then
      local ctrl = (ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl()) ~= 0
      if ctrl and img then
        Nav.set_zoom_from_scale(scale * (wv > 0 and CFG.ZOOM_STEP or 1 / CFG.ZOOM_STEP), iw, area_w)
      else
        if wv ~= 0 then Nav.scroll_by(-wv * CFG.WHEEL_STEP) end
        if wh ~= 0 then S.scroll_x = Util.clamp(S.scroll_x - wh * CFG.WHEEL_STEP, 0, R.max_x); Util.mark_dirty() end
      end
    end
  end
  if active and not R.perf_btn_over then -- a click on the performance-mode exit button is not a drag
    local dx, dy = ImGui.GetMouseDelta(ctx)
    if dy ~= 0 then Nav.scroll_by(-dy) end
    if dx ~= 0 then S.scroll_x = Util.clamp(S.scroll_x - dx, 0, R.max_x); Util.mark_dirty() end
  end

  ImGui.SetCursorScreenPos(ctx, x0 + area_w + 4, y0)
  ImGui.InvisibleButton(ctx, "##vscroll", sbw, view_h)
  local sb_active = ImGui.IsItemActive(ctx) and not locked
  local thumb_h = (disp_h > 0) and Util.clamp(view_h * view_h / disp_h, 24, view_h) or view_h
  if sb_active and R.max_y > 0 then
    local _, my = ImGui.GetMousePos(ctx)
    local frac = Util.clamp((my - y0 - thumb_h / 2) / math.max(1, view_h - thumb_h), 0, 1)
    S.scroll_y = frac * R.max_y; R.abs_target = nil; Util.touch_override(); Util.mark_dirty()
  end

  Nav.update_motion()

  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + area_w, y0 + view_h, CFG.PAGE_BG)
  if img then
    -- snap to whole screen pixels so the texture is never sampled at half-pixel offsets (blur)
    local dw = math.floor(math.min(disp_w, area_w) + 0.5)
    local dh = math.floor(math.min(disp_h, view_h) + 0.5)
    local ox = math.floor(x0 + (area_w - dw) / 2 + 0.5)
    local oy = math.floor(y0 + 0.5)
    local sx, sy = math.floor(S.scroll_x + 0.5), math.floor(S.scroll_y + 0.5)
    if Nav.two_pages() then
      -- 2 pages: both at full size, moved by the scroll and clipped to the view (the last page of a
      -- PDF with an odd page count stays alone, at its own size)
      local pw, ph = math.floor(iw * scale + 0.5), math.floor(ih * scale + 0.5)
      R.side_step = disp_w - pw -- one page + the gap (the smooth page turn moves by this)
      local xoff = 0
      if R.side_off then
        local k = (Util.now() - R.turn_t) / CFG.CONT_TURN_SEC
        if k >= 1 then R.side_off = nil else xoff = R.side_off * (1 - k) * (1 - k) end
      end
      local bx, by = ox - sx + xoff, oy - sy
      local x2, y2 = bx + R.side_step, by
      ImGui.DrawList_PushClipRect(dl, ox, oy, ox + dw, oy + dh, true)
      if xoff > 0 and first > 1 then -- the page that slides out on the left
        local prev = PDF.get_page_image(first - 1)
        if prev then ImGui.DrawList_AddImage(dl, prev, bx - R.side_step, by, bx - R.side_step + pw, by + ph, 0, 0, 1, 1, UI.page_tint()) end
      end
      ImGui.DrawList_AddImage(dl, img, bx, by, bx + pw, by + ph, 0, 0, 1, 1, UI.page_tint())
      if not second then -- nothing after the last page
      elseif img2 then
        ImGui.DrawList_AddImage(dl, img2, x2, y2, x2 + pw, y2 + ph, 0, 0, 1, 1, UI.page_tint())
      else
        ImGui.DrawList_AddText(dl, x2 + 20, y2 + 20, COL.TEXT, string.format("Preparing page %d...", second))
      end
      ImGui.DrawList_PopClipRect(dl)
    elseif Nav.continuous() or R.cont_off then -- (1 page: only while its smooth page turn runs)
      -- continuous: the pages one below the other, from the top page down (the page above it too
      -- while the smooth page turn still shows it); clipped to the view
      local step = Nav.cont_step()
      local off = 0
      if R.cont_off then
        local k = (Util.now() - R.turn_t) / CFG.CONT_TURN_SEC
        if k >= 1 then R.cont_off = nil else off = R.cont_off * (1 - k) * (1 - k) end
      end
      local p, y = S.page, oy - (sy + off)
      while y > oy and p > 1 do p = p - 1; y = y - step end
      local bx = ox - sx
      ImGui.DrawList_PushClipRect(dl, x0, oy, x0 + area_w, oy + view_h, true)
      while p <= R.total and y < oy + view_h do
        local im = (p == first) and img or PDF.get_page_image(p)
        if im then
          ImGui.DrawList_AddImage(dl, im, bx, y, bx + disp_w, y + disp_h, 0, 0, 1, 1, UI.page_tint())
        else
          ImGui.DrawList_AddText(dl, bx + 20, y + 20, COL.TEXT, string.format("Preparing page %d...", p))
        end
        p, y = p + 1, y + step
      end
      ImGui.DrawList_PopClipRect(dl)
    else
      local u0, u1 = sx / disp_w, (sx + dw) / disp_w
      local v0, v1 = sy / disp_h, (sy + dh) / disp_h
      ImGui.DrawList_AddImage(dl, img, ox, oy, ox + dw, oy + dh, u0, v0, u1, v1, UI.page_tint())
    end
  elseif blocked and (#P.pdfs > 0 or R.total > 0) then -- an empty library shows the welcome instead
    UI.draw_region_empty_state(ctx, x0, y0, area_w, view_h, blocked)
  elseif R.info_job then
    ImGui.DrawList_AddText(dl, x0 + 20, y0 + 20, COL.TEXT, "Loading PDF...")
  elseif R.total == 0 and not part1 then
    ImGui.DrawList_AddText(dl, x0 + 20, y0 + 20, COL.TEXT_DIM, "PDF 2: no PDF.")
  elseif R.total == 0 then
    UI.draw_empty_state(ctx, x0, y0, area_w, view_h, dl)
  else
    ImGui.DrawList_AddText(dl, x0 + 20, y0 + 20, COL.TEXT, string.format("Preparing page %d...", S.page))
    if not R.error then
      ImGui.SetCursorScreenPos(ctx, x0 + 20, y0 + 44)
      ImGui.ProgressBar(ctx, R.batches_done / math.max(1, PDF.total_batches()), 260, 0,
        string.format("%d / %d batches", R.batches_done, PDF.total_batches()))
    end
  end

  local sx = x0 + area_w + 4
  ImGui.DrawList_AddRectFilled(dl, sx, y0, sx + sbw, y0 + view_h, COL.SCROLL_TRACK, 4)
  local ty = y0 + ((R.max_y > 0) and (S.scroll_y / R.max_y) or 0) * (view_h - thumb_h)
  ImGui.DrawList_AddRectFilled(dl, sx, ty, sx + sbw, ty + thumb_h, sb_active and COL.SCROLL_THUMB_ACTIVE or COL.SCROLL_THUMB, 4)
  -- scroll points of this page (Markers / Cue list) as small marks on the scrollbar: a help for editing,
  -- so only while REAPER is stopped (during playback they would only distract)
  if img and R.max_y > 0 and not Util.playing() and part1 then -- (the points belong to part 1)
    for _, pct in ipairs(UI.scroll_marks()) do
      local my = y0 + thumb_h / 2 + (pct / 100) * (view_h - thumb_h)
      ImGui.DrawList_AddRectFilled(dl, sx - 3, my - 1, sx + sbw + 3, my + 1, COL.ACCENT_HOVER, 1)
    end
  end
  -- page-turn flash
  if S.turn_flash and img then
    local t = Util.now() - R.flash_t
    if t >= 0 and t < CFG.FLASH_SEC then
      local a = math.floor(255 * (1 - t / CFG.FLASH_SEC))
      local c = (COL.ACCENT & 0xFFFFFF00) | a
      local hw = CFG.FLASH_W / 2
      ImGui.DrawList_AddRect(dl, x0 + hw, y0 + hw, x0 + area_w - hw, y0 + view_h - hw, c, 6, 0, CFG.FLASH_W)
    end
  end
  -- banner: kept page (region without a PDF during playback); does not block the page
  local badge_y = y0 + 10
  if kept then
    local reg = R.empty_region
    local txt = UI.trunc_text(ctx, string.format('No PDF for "%s" - showing the last page. Autoscroll paused.',
      reg.name ~= "" and reg.name or "(unnamed region)"), area_w - 24)
    local _, th = ImGui.CalcTextSize(ctx, txt)
    ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + area_w, y0 + th + 10, 0x3A3200E6)
    ImGui.DrawList_AddText(dl, x0 + 10, y0 + 5, COL.YELLOW, txt)
    badge_y = y0 + th + 18
  end
  -- badges (top left): lock, record cues; with 2 PDFs in the active part (Record goes there)
  if (not R.part2) or ((R.active_part == 2) == (not part1)) then
    local bx = x0 + 10
    local function badge(txt, col)
      local tw, th = ImGui.CalcTextSize(ctx, txt)
      ImGui.DrawList_AddRectFilled(dl, bx - 6, badge_y - 4, bx + tw + 6, badge_y + th + 4, 0x000000AA, 6)
      ImGui.DrawList_AddText(dl, bx, badge_y, col, txt)
      bx = bx + tw + 20
    end
    if R.lock then badge(locked and "LOCKED" or "Lock on (active during playback)", locked and COL.YELLOW or COL.GREY) end
    if R.rec and Nav.scroll_mode() == "cues" then badge("REC", COL.RED) end
  end
  if not part1 then ImGui.SetCursorScreenPos(ctx, x0, y0 + view_h); return end -- part 2: no performance-mode button
  -- performance mode: a hint after entering, and an exit button in the top-right corner on hover
  R.perf_btn_over = false
  if R.perf then
    local mx, my = ImGui.GetMousePos(ctx)
    local lbl = "Exit performance mode (F / Esc)"
    local tw, th = ImGui.CalcTextSize(ctx, lbl)
    local bx1, by0 = x0 + area_w - 10, y0 + 10
    local bx0, by1 = bx1 - tw - 20, by0 + th + 12
    local near = mx >= x0 + area_w - 260 and mx <= x0 + area_w and my >= y0 and my <= y0 + 60
    -- a click / tap on the page also shows the button (touch screens have no hover)
    if ImGui.IsMouseClicked(ctx, 0) and mx >= x0 and mx <= x0 + area_w and my >= y0 and my <= y0 + view_h then
      if not near then R.perf_tap_t = Util.now() end
    end
    if near or Util.now() - R.perf_t < 2.5 or Util.now() - R.perf_tap_t < 3 then
      local over = mx >= bx0 and mx <= bx1 and my >= by0 and my <= by1
      R.perf_btn_over = over
      ImGui.DrawList_AddRectFilled(dl, bx0, by0, bx1, by1, over and COL.ACCENT or 0x000000BB, 6)
      ImGui.DrawList_AddText(dl, bx0 + 10, by0 + 6, COL.WHITE, lbl)
      if over and ImGui.IsMouseClicked(ctx, 0) then UI.toggle_perf() end
    end
  end

  ImGui.SetCursorScreenPos(ctx, x0, y0 + view_h + 2)
end

---------------------------------------------------------------------------
-- DOCKING
---------------------------------------------------------------------------
-- "Reset window position": float the window at the default position/size.
function Dock.reset(ctx)
  ImGui.SetNextWindowPos(ctx, CFG.DEFAULT_WIN[1], CFG.DEFAULT_WIN[2], ImGui.Cond_Always())
  ImGui.SetNextWindowSize(ctx, CFG.DEFAULT_WIN[3], CFG.DEFAULT_WIN[4], ImGui.Cond_Always())
  ImGui.SetNextWindowDockID(ctx, 0, ImGui.Cond_Always())
  S.dock_id = 0; S.panel_h = 0; R.reset_layout = false; Util.mark_dirty()
end

-- Restore the saved dock once at startup.
function Dock.apply(ctx)
  if not R.dock_applied then
    R.dock_applied = true
    if type(S.dock_id) ~= "number" or S.dock_id ~= S.dock_id then S.dock_id = 0 end
    if S.dock_id ~= 0 then ImGui.SetNextWindowDockID(ctx, S.dock_id, ImGui.Cond_Once()) end
  end
end

-- Track dock id and (when floating) window position/size. Call between Begin and End.
function Dock.track(ctx)
  local docked = ImGui.IsWindowDocked(ctx) and true or false
  if docked ~= R.last_docked then
    if R.last_docked ~= nil then Msg.diag(docked and "Window docked." or "Window undocked.") end
    R.last_docked = docked
    R.dock_settle = R.frames + CFG.DOCK_SETTLE_FRAMES -- wait before saving a new dock state
  end
  if R.frames > CFG.DOCK_SETTLE_FRAMES and R.frames > (R.dock_settle or 0) then
    local did = 0
    if docked then
      did = ImGui.GetWindowDockID(ctx)
      R.last_dock_id = did -- for "Dock in REAPER docker" in the toolbar menu
    end
    if did ~= S.dock_id then S.dock_id = did; Util.mark_dirty() end
  end
  if not docked then
    local wx, wy = ImGui.GetWindowPos(ctx)
    local ww, wh = ImGui.GetWindowSize(ctx)
    if wx ~= S.win_x or wy ~= S.win_y or ww ~= S.win_w or wh ~= S.win_h then
      S.win_x, S.win_y, S.win_w, S.win_h = wx, wy, ww, wh; Util.mark_dirty()
    end
  end
end

-- Floating window: Chart Cue's own resize edges and corner grip (ImGui's are about 1 px wide; the
-- window uses WindowFlags_NoResize). R.rs = the running resize: edge flags + start mouse / window.
-- Called before Begin: applies a running resize, and keeps the full size while the window is collapsed
-- (so it always opens again at its full size).
function Dock.pre_begin(ctx)
  local rs = R.rs
  if rs then
    if not ImGui.IsMouseDown(ctx, 0) then R.rs = nil; return end
    local mx, my = ImGui.GetMousePos(ctx)
    local dx, dy = mx - rs.mx, my - rs.my
    local x, w, h = rs.x, rs.w, rs.h
    if rs.l then w = math.max(CFG.WIN_MIN_W, rs.w - dx); x = rs.x + rs.w - w end
    if rs.r then w = math.max(CFG.WIN_MIN_W, rs.w + dx) end
    if rs.b then h = math.max(CFG.WIN_MIN_H, rs.h + dy) end
    ImGui.SetNextWindowPos(ctx, x, rs.y, ImGui.Cond_Always())
    ImGui.SetNextWindowSize(ctx, w, h, ImGui.Cond_Always())
  elseif R.collapsed then
    ImGui.SetNextWindowSize(ctx, S.win_w, S.win_h, ImGui.Cond_Always())
  end
end

-- Called between Begin and End of the floating window: hover zones, cursor, grip, start of a resize.
function Dock.edges(ctx)
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
  local hot = z and z.r and z.b
  local col = hot and COL.ACCENT or COL.TOGGLE_OFF
  for k = 1, 3 do
    local d = k * 5
    ImGui.DrawList_AddLine(dl, x1 - 3 - d, y1 - 3, x1 - 3, y1 - 3 - d, col, 2)
  end
  ImGui.DrawList_PopClipRect(dl)
end

---------------------------------------------------------------------------
-- FRAME
---------------------------------------------------------------------------
function UI.frame()
  local ctx = R.ctx
  R.cue_part_ctx, R.combo_text = nil, nil -- (also after an error inside the Cues tab or a dropdown)
  Pane.active(Midi.poll_forwarded_midi) -- MIDI and the actions act on the active part
  Pane.active(Midi.poll_direct_midi)
  Project.project_tick()
  Project.region_tick()
  Project.pick_tick()
  Project.import_tick()
  Project.copy_tick()
  PDF.info_tick()
  PDF.render_tick()
  Pane.part2(PDF.info_tick)
  if not R.job then Pane.part2(PDF.render_tick) end -- the parts take turns: one batch at a time
  Util.dir_size_tick()
  if Util.now() - (R.hb_t or 0) >= 0.25 then -- single-instance heartbeat (timeout is 1 s)
    R.hb_t = Util.now()
    r.SetExtState(CFG.EXT, "heartbeat", tostring(R.hb_t), false)
  end
  R.frames = R.frames + 1

  -- window placement / docking
  if R.reset_layout then
    Dock.reset(ctx)
  else
    Dock.apply(ctx)
    ImGui.SetNextWindowPos(ctx, S.win_x, S.win_y, ImGui.Cond_FirstUseEver())
    ImGui.SetNextWindowSize(ctx, S.win_w, S.win_h, ImGui.Cond_FirstUseEver())
    if R.dock_req then -- toolbar menu: Dock in REAPER docker / Undock (at the last floating place)
      ImGui.SetNextWindowDockID(ctx, R.dock_req, ImGui.Cond_Always())
      if R.dock_req == 0 then
        ImGui.SetNextWindowPos(ctx, S.win_x, S.win_y, ImGui.Cond_Always())
        ImGui.SetNextWindowSize(ctx, S.win_w, S.win_h, ImGui.Cond_Always())
      end
      R.dock_req = nil
    end
    Dock.pre_begin(ctx)
  end

  -- ReaImGui rule (differs from Dear ImGui C++): call End() ONLY when Begin() returned true.
  -- Begin() returns false when the window is in an inactive dock tab or collapsed.
  UI.push_theme(ctx) -- popped after End() below (and by UI.loop after an error)
  -- docked: ImGui's small corner triangle (show the dock tab bar) uses the button colours: accent here
  local tri = R.last_docked and 3 or 0
  if tri > 0 then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button(), COL.ACCENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered(), COL.ACCENT_HOVER)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive(), COL.ACCENT_ACTIVE)
  end
  local visible, open = ImGui.Begin(ctx, CFG.TITLE, true, ImGui.WindowFlags_NoResize())
  if tri > 0 then ImGui.PopStyleColor(ctx, tri) end
  -- floating and Begin() false = collapsed (docked and false = an inactive dock tab)
  R.collapsed = not visible and R.last_docked == false
  if R.collapsed then R.rs = nil end
  if visible ~= R.was_visible then
    Msg.diag(visible and "Chart Cue is visible." or "Chart Cue is hidden.")
    R.was_visible = visible
  end
  if visible then
    R.in_window = true
    Dock.track(ctx)
    if not R.part2 then R.active_part = 1 end
    Pane.active(UI.handle_keys, ctx)

    local perf = R.perf -- performance mode: only the page
    local hide = perf or (S.hide_controls_playing and Util.playing())
    -- while hidden, the status bar shows only one red line when there is an error
    local status_h = ImGui.GetTextLineHeightWithSpacing(ctx) + ImGui.GetFrameHeightWithSpacing(ctx) + 4
    if hide then status_h = R.error and (ImGui.GetFrameHeightWithSpacing(ctx) + 2) or 6 end
    if perf then
      -- nothing above the page
    elseif hide then
      local _, ty = ImGui.GetCursorScreenPos(ctx)
      Pane.active(UI.draw_centered_toolbar, ctx)  -- the same toolbar, without the tabs and panel, while playing
      UI.toolbar_menu(ctx, ty)
      UI.vgap(ctx, UI.sp("EDGE"))
    else
      local _, ty = ImGui.GetCursorScreenPos(ctx)
      Pane.active(UI.draw_centered_toolbar, ctx) -- the toolbar shows the active part
      UI.toolbar_menu(ctx, ty)
      UI.vgap(ctx, UI.sp("EDGE")) -- same gap below the toolbar as above it
      UI.draw_tab_strip(ctx)
      if S.panel_open then UI.draw_panel(ctx, status_h) end
    end

    local aw, ah = ImGui.GetContentRegionAvail(ctx)
    local vh = math.max(60, ah - status_h)
    UI.draw_parts(ctx, aw, vh)
    if not hide then UI.draw_status(ctx)
    elseif R.error then UI.draw_error_line(ctx)
    else
      -- draw_view ends with SetCursorScreenPos(); ImGui requires an item after it before End()
      ImGui.Dummy(ctx, 0, 0)
    end
    Pane.active(UI.context_menus, ctx) -- right-click menus (toolbar, page, list rows), for the active part
    if not R.last_docked then Dock.edges(ctx) else R.rs = nil end -- resize edges: floating only
    R.in_window = false
    ImGui.End(ctx)
  end
  UI.pop_theme(ctx)
  if not open then R.quit = true end

  if R.dirty and Util.now() - R.last_save > 2 then Util.save_settings(); R.dirty = false; R.last_save = Util.now() end
end

---------------------------------------------------------------------------
-- MAIN LOOP / LIFECYCLE
---------------------------------------------------------------------------
function UI.cleanup()
  Project.cancel_copies()
  Util.save_settings()
  Project.save_project_cfg()
  r.SetExtState(CFG.EXT, "heartbeat", "", false)
  r.SetExtState(CFG.EXT, "midi_q", "", false)
  r.SetExtState(CFG.EXT, "cmd_q", "", false)
  if R.picker then os.remove(R.picker.out_f); os.remove(R.picker.done_f) end
  if sect_id and cmd_id and cmd_id ~= 0 then
    r.SetToggleCommandState(sect_id, cmd_id, 0); r.RefreshToolbar2(sect_id, cmd_id)
  end
  R.ctx = nil
end

function UI.loop()
  local ok, err = pcall(UI.frame)
  if ok then R.err_streak = 0 else
    R.err_streak = (R.err_streak or 0) + 1
    r.ShowConsoleMsg("[" .. CFG.TITLE .. "] Error: " .. tostring(err) .. "\n")
    Msg.set_error("Internal error: " .. tostring(err))
    if not r.ImGui_ValidatePtr(R.ctx, "ImGui_Context*") then
      -- the context is gone: stop cleanly instead of using a dead context
      r.ShowConsoleMsg("[" .. CFG.TITLE .. "] ImGui context is no longer valid; Chart Cue stopped.\n")
      R.ctx = nil; R.quit = true
    elseif R.in_window then
      -- the error happened between Begin() and End(): close the window so the stack stays balanced
      pcall(r.ImGui_End, R.ctx) -- protected: the window stack may be unbalanced after the error
      Msg.diag("Recovered from an ImGui error inside the window.")
    end
    R.in_window = false
    if R.ctx then UI.pop_theme(R.ctx) end -- remove the theme pushes of the failed frame
    -- one error is recovered (the show goes on); the same failure in every frame means the window
    -- state could not be repaired: stop cleanly instead of failing forever
    if R.err_streak >= CFG.MAX_ERROR_FRAMES and not R.quit then
      r.ShowConsoleMsg("[" .. CFG.TITLE .. "] Stopped after " .. R.err_streak .. " failed frames in a row. "
        .. "Start Chart Cue again; if it happens again, please report it with the lines above.\n")
      R.quit = true
    end
  end
  if R.quit then UI.cleanup(); return end
  r.defer(UI.loop)
end

function UI.init()
  Util.ensure_dir(CFG.CACHE_ROOT); Util.ensure_dir(CFG.TMP_DIR)
  r.SetExtState(CFG.EXT, "quit", "", false) -- a flag left by an instance that stopped before reading it
  r.SetExtState(CFG.EXT, "cmd_q", "", false) -- old action commands must not run now
  Util.load_settings()
  if S.tab_ver < 3 then
    if S.tab_ver < 2 and S.tab >= TAB_CUES then S.tab = S.tab + 1 end -- old numbers had no Cues tab
    -- v2 numbers: 4..7 = Autoscroll, MIDI, Display, Project (now one Settings tab), 8 = Help
    if S.tab >= 8 then S.tab = TAB_HELP elseif S.tab >= 4 then S.tab = TAB_FIRST_SETTING end
    S.tab_ver = 3; Util.mark_dirty()
  end
  S.tab = Util.clamp(math.floor(S.tab), 1, TAB_HELP)
  R.ctx = r.ImGui_CreateContext(CFG.TITLE)
  -- the window moves only by its title bar, so a drag on Chart Cue's resize edges never moves it
  r.ImGui_SetConfigVar(R.ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
  UI.init_fonts(R.ctx)
  R.dpi_edit = S.dpi
  if r.MIDI_GetRecentInputEvent then R.last_midi_seq = (r.MIDI_GetRecentInputEvent(0)) or 0 end
  if sect_id and cmd_id and cmd_id ~= 0 then
    r.SetToggleCommandState(sect_id, cmd_id, 1); r.RefreshToolbar2(sect_id, cmd_id)
  end
  r.atexit(UI.cleanup)
  -- the autostart watcher finds Chart Cue by this named command ID (persisted)
  local cs = Autostart.command_string()
  if cs then r.SetExtState(CFG.EXT, "cmd", cs, true) end
  if Autostart.installed(true) then Autostart.write_script() end -- keep the watcher up to date

  PDF.write_engine_script()
  for _, f in ipairs(Util.list_files(CFG.TMP_DIR)) do -- leftovers of cancelled page-count jobs
    if f:match("^info_%d+%.") then os.remove(CFG.TMP_DIR .. SEP .. f) end
  end
  if PDF.engine() == "poppler" then -- the Poppler search runs only when Poppler is used
    R.exe = PDF.find_pdftoppm()
    if not R.exe then Msg.set_error(PDF.poppler_help()) else PDF.check_pdfinfo() end
  end

  -- Same startup path whether launched manually, from the Action List or by the autostart watcher:
  -- load the project's config, rescan markers/regions, reopen its active PDF.
  -- Playback-linked autoscroll never starts on its own (it only moves while REAPER is playing).
  Project.check_project(true)
  if launched_by_midi then Midi.handle_scroll_value(act_val, "action-bound MIDI CC", nil) end
  UI.loop()
end

-- tests/run.lua sets ChartCueTest: hand it the modules and do not start the UI
local test = rawget(_G, "ChartCueTest")
if test then
  test.CFG, test.S, test.R, test.Util, test.PDF, test.Project, test.Nav, test.Midi, test.UI, test.Msg, test.Cues, test.Pane =
    CFG, S, R, Util, PDF, Project, Nav, Midi, UI, Msg, Cues, Pane
  test.get_P = function() return P end
  return
end
UI.init()
