-- @description Session Prep: clean up a multitrack import (names, colors, folders)
-- @version 1.0
-- @author Nick Gkogkomitros
-- @license MIT
-- @about
--   Session Prep - clean up the tracks of a multitrack that you got from a client, in one step.
--   Scan reads the track names (and the audio) and shows a preview: the new name, the folder, the color and notes.
--   Nothing changes until you click Apply; one Ctrl+Z undoes everything.
--   Rename from rules (a built-in list of short names: kik, sn, oh, gtr, vox...), remove a shared prefix or suffix,
--   color, put the tracks in folders and in order, pan L / R tracks, find fake stereo and silent tracks.
--   Rule presets are saved on this computer (export and import them as files).
--   Requires: the free ReaImGui extension (ReaPack).
-- @changelog
--   First release: Prep (Scan, preview, Apply) and Rules (presets, rules with match words, name, color, folder).

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
CFG.TITLE = "Session Prep"     -- keep stable: REAPER uses it to restore docking (ASCII only)
CFG.VERSION = "1.0"            -- keep equal to @version in the header
CFG.EXT = "Session Prep"       -- ExtState section (this computer)
CFG.DEFAULT_W, CFG.DEFAULT_H = 620, 560
CFG.WIN_EDGE = 6               -- floating window: width of the resize edges (inside the window), as in Chart Cue
CFG.WIN_GRIP = 22              -- floating window: size of the bottom-right resize corner
CFG.WIN_MIN_W, CFG.WIN_MIN_H = 380, 260
CFG.FONT_SIZE = 14             -- the same sizes as Chart Cue
CFG.FONT_SIZE_BOLD = 15        -- section titles
CFG.TEXT_LIFT = 1              -- px the text is raised above the true centre in every control
CFG.HELP_ICON = 20             -- the round "?" icon
CFG.CTRL_GAP = 8               -- between 2 controls side by side
CFG.SP_ROW, CFG.SP_EDGE, CFG.SP_PANEL = 7, 8, 4 -- spacing (pixels; the same gaps as Chart Cue)
CFG.SP_TITLE_BEFORE, CFG.SP_TITLE_AFTER = 12, 6
CFG.ROW_H = 26
CFG.X_BTN = CFG.ROW_H          -- the round remove button: the row height (as in Chart Cue: in line with the row)
CFG.MS_W = 26                  -- the Pan, M and S buttons of the Prep table
CFG.WIDTH_W = 64               -- the Width column of the Prep table (Settings > Prep > Pan width)
CFG.LABEL_W = 190              -- the label column of the Settings rows (as in MIDI Pilot)
CFG.RETURNS_FOLDER = "FX Returns" -- the folder of the new FX returns
CFG.OTHER = "Other"            -- the folder of click, guide, talkback (Settings > Prep > Other: no master output)
CFG.PREP_KEY = "P_EXT:SessionPrep" -- a prepped track: its date (in the track, so Ctrl+Z of Apply removes it)
CFG.TAB_H = 32                 -- the tab strip, as in Chart Cue
CFG.TAB_GAP = 4
CFG.TAB_GROUP_GAP = 12         -- between the text tabs and the Settings / Help tabs
CFG.TAB_LIFT = 6               -- the selected tab is this much taller
CFG.PRESET_W = 200             -- the preset dropdown
CFG.MORE_W = 110               -- the "More..." dropdown of the preset (as Chart Cue's setlist "More...")
CFG.NOTICE_SEC = 4             -- a notice at the bottom of the window shows this long
CFG.STRIP_MIN = 4              -- a shared prefix / suffix is removed only when it has 4 or more letters or digits
CFG.AUDIO_SR = 11025           -- the audio check reads the tracks at this sample rate
CFG.AUDIO_BLOCK = 2048         -- frames per read
CFG.AUDIO_MAX_BLOCKS = 120     -- at most this many reads per track (spread over the whole track)
CFG.SILENT = 0.001             -- a peak below -60 dBFS is silence
CFG.FAKE_DIFF = 0.001          -- L and R differ less than 0.1 % of the peak: fake stereo
CFG.GATE = 0.00316             -- gain staging: a read below -50 dBFS RMS is a pause (not in the average)
CFG.UNDO_STEPS = 30            -- the Undo buttons (Rules, Buses, FX Returns): the last 30 changes of each section
CFG.UNDO_MERGE = 0.7           -- changes closer than 0.7 s (a color drag, typing) are 1 step
CFG.PEAK_MARGIN = 1            -- gain staging: 1 dB more room under the peak limit (the fast read can miss a peak)
CFG.SCAN_BUDGET = 0.03         -- Scan: at most 30 ms of audio reading per frame (the window stays responsive)
CFG.GAIN_W = 84                -- the Gain column of the Prep table
CFG.DATA_DIR = r.GetResourcePath() .. "/Data/Session Prep" -- the exported presets
CFG.TIP_DELAY = 0.5            -- seconds on an item before its tooltip shows (as in Chart Cue)
CFG.TIP_WRAP_EM = 32           -- tooltip lines wrap at this many font sizes

local COL = {
  RED = 0xF26D6DFF, YELLOW = 0xF2C75CFF, GREEN = 0x6FCF8AFF,
  ACCENT = 0x3B82F6FF, ACCENT_HOVER = 0x5B9BFFFF, ACCENT_ACTIVE = 0x2F6FE0FF,
  ACTIVE_BG = 0x3B82F633, HEADING = 0x8DB8FFFF,
  WIN_BG = 0x131518FF, PANEL_BG = 0x1A1C21FF, TAB_BG = 0x0F1114FF, TAB_HOVER = 0x343944FF,
  CARD_BG = 0x22252BFF, -- a card (1 step lighter than the panel, as in MIDI Pilot)
  CHIP_FOLDER = 0x2C3A55FF, CHIP_FOLDER_HOV = 0x34466AFF, -- a folder chip (blue-grey; a track chip is grey)
  PAN = 0x6FB8B0FF,     -- a Pan button that pans (L / C / R; "-" stays grey)
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
  WIN_BG = 0xDDE1E7FF, PANEL_BG = 0xF4F5F7FF, TAB_BG = 0xD0D5DDFF, TAB_HOVER = 0xC4CAD3FF, CARD_BG = 0xE9ECF0FF,
  CHIP_FOLDER = 0xD6E2F7FF, CHIP_FOLDER_HOV = 0xC6D6F2FF, PAN = 0x4FA59CFF,
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

local Util, Rules, Prep, Audio, UI = {}, {}, {}, {}, {}

-- R: runtime state (not saved). S: settings of this computer (Session Prep has no project data).
local R = {
  frames = 0, sdirty = false,
  scan = nil,        -- the last Scan: { tracks = { { tr, guid, name, idx, audio } }, scope, folders_ok }
  rows = nil,        -- the preview rows (Prep.plan of the scan with the current preset)
  comp = nil,        -- the compiled rules of the current preset (Rules.compile; nil after a change)
  summary = nil,     -- the cached footer text of the preview
}
local S = {
  light = false,     -- Light theme (Dark is the default)
  dock = 0,          -- the REAPER docker of the window (0 = floating)
  tab = 1,           -- 1 Prep, 2 Rules, 3 Settings, 4 Help
  preset = 1,        -- the current preset (index in S.presets)
  folders = true,    -- Apply puts the tracks in folders and in order
  pairs = true,      -- Apply pans the tracks with an L / R word hard left / hard right ("Gtr 1 R")
  audio = true,      -- Scan checks the audio (fake stereo, one side silent, silent tracks)
  color = false,     -- Apply colors the tracks and folders (off by default; SWS Auto Color wins when it is on)
  spacer = true,     -- Apply puts a spacer above each folder track (except the first)
  disarm = true,     -- Apply turns off record arm and input monitoring on the ticked tracks
  pan_w_on = false,  -- Pan width: a Width column in the Prep table (each L / R track's width; off: hard L / R)
  other_off = true,  -- the Other folder (click, guide, talkback) gets no master output (it never reaches the mix)
  caps = "all",      -- Capital letters: "all" (tracks, folders, buses), "fb" (folders and buses), "buses", "none"
  color_win = false, -- Colors win over SWS: Apply turns SWS Auto Color off, then colors
  settings_open = 2, -- the open Settings section (1 Appearance, 2 Prep, 3 Gain staging, 4 Window; 0 none)
  returns = false,   -- Apply makes the FX returns of the preset and the sends to them (off by default)
  closed = {},       -- the folded sections: id -> true
  gain = false,      -- Gain staging: Scan measures the level, Apply sets the item gain (off by default)
  gain_rms = -18,    -- the target average level (dBFS RMS)
  gain_peak = -6,    -- the gain never takes a peak above this (dBFS)
  gain_by_peak = false, -- Target: Peak (every track's peak to gain_ptarget) in place of RMS
  gain_ptarget = -10, -- the target peak (dBFS) of Target: Peak
  presets = {},      -- { { name, strip, rules = { { match, name, folder, color = 0xRRGGBB } }, fx = { [folder] = path } } }
}

---------------------------------------------------------------------------
-- REAIMGUI (pinned to 0.9.3 with the official compatibility shim)
---------------------------------------------------------------------------
local IMGUI_SHIM = r.GetResourcePath() .. "/Scripts/ReaTeam Extensions/API/imgui.lua"
local function imgui_missing()
  if r.ReaPack_BrowsePackages then
    local ok = r.ShowMessageBox("Session Prep needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "Open ReaPack now to install or update it?\n\n"
      .. "In the ReaPack window: right-click ReaImGui > Install, click OK, then restart REAPER.", CFG.TITLE, 4)
    if ok == 6 then r.ReaPack_BrowsePackages("ReaImGui") end
  else
    r.ShowMessageBox("Session Prep needs the ReaImGui extension (version 0.9.3 or newer).\n\n"
      .. "1. Install ReaPack from https://reapack.com and restart REAPER.\n"
      .. "2. Extensions > ReaPack > Browse packages > search 'ReaImGui' > Install.\n"
      .. "3. Restart REAPER and run Session Prep again.", CFG.TITLE, 0)
  end
end
local TESTING = rawget(_G, "SessionPrepTest") ~= nil
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
function Util.mark_sdirty() R.sdirty = true end

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
    txt = Rules.safe(txt)
    if txt ~= "" then done(txt) end
  end)
end

---------------------------------------------------------------------------
-- RULES (the presets: saved on this computer)
---------------------------------------------------------------------------
-- A rule: match = the words, separated by commas ("kik, kick, bd"); name = the new track name; folder = the folder
-- ("" = none); color = 0xRRGGBB. The first rule that matches wins (the order of the list).
-- pol: flip the polarity of the tracks of this rule: "" no, "*" all, or a word (only the tracks with that word,
-- for example "Btm": Snare Btm).
local function rule(match, name, folder, color, pol)
  return { match = match, name = name, folder = folder, color = color, pol = pol or "" }
end
-- A preset: name, strip (remove a shared prefix / suffix), rules, order (the folders from top to bottom),
-- fx = { [folder or bus] = chain }, tfx = { [rule name] = chain } (Track FX),
-- returns = { { name, chain, color, src = "t" (the tracks send) / "f" (the folder track sends), db (the send level),
-- out = "m" (master) / "f:<folder>" / "b:<bus>" } }, sends = { [folder] = { [return name] = true } },
-- buses = { { name, on, color, members = { { kind = "f" (a folder) or "t" (a track name), name } } } }.
-- The built-in presets: the names and the order that most engineers use (drums first: kick, snare, hats, toms,
-- overheads, room; then bass, guitars, keys, vocals; the click and guide at the bottom; the FX returns last).
function Rules.default_presets()
  local DR, PC, BS, GT, KY, ST, BR, VX, OT = 0xD9534F, 0xD07AC8, 0xE8913A, 0x5BBF6A, 0xE8C547, 0x9B7FE6,
    0xC9A227, 0x4A8BE8, 0x8C8C9A
  local function rules()
    return {
      rule("click, clk, metronome, met", "Click", "Other", OT),
      rule("guide, gde, scratch, guide vox, scratch vox, guide gtr", "Guide", "Other", OT),
      rule("talkback, tb, talk back", "Talkback", "Other", OT),
      rule("kick sub, subkick, sub kick, kicksub, sub kik", "Kick Sub", "Drums", DR),
      rule("kick, kik, kck, bd, bassdrum, bass drum, kick drum, kd", "Kick", "Drums", DR),
      rule("snare, snr, sn, sd, snare drum, snares", "Snare", "Drums", DR, "Btm"),
      rule("hi hat, hihat, hh, hat, hats, hi-hat", "Hi-Hat", "Drums", DR),
      rule("floor tom, floortom, floor, ft, flr tom", "Floor Tom", "Drums", DR),
      rule("tom, tm, rack, rack tom, toms", "Tom", "Drums", DR),
      rule("ride, ride cym", "Ride", "Drums", DR),
      rule("overhead, overheads, oh, ohs, ovh, cymbal, cymbals, cym, cyms", "OH", "Drums", DR),
      rule("room, rooms, rm, amb, ambience, ambient, mono room", "Room", "Drums", DR),
      rule("perc, percussion, shaker, shk, tamb, tambo, tambourine, conga, congas, bongo, bongos, cowbell, "
        .. "clap, claps, cajon, guiro, triangle, timbale, timbales", "Perc", "Perc", PC),
      rule("synth bass, synthbass, sub bass, subbass, moog bass", "Synth Bass", "Bass", BS),
      rule("bass, bs, bas, bass gtr, bass guitar, b gtr, upright bass", "Bass", "Bass", BS),
      rule("acoustic, acoustic guitar, ac gtr, agtr, acg, acous, ac, nylon, steel gtr", "Ac Gtr", "Guitars", GT),
      rule("lead gtr, lead guitar, gtr lead, guitar lead, ld gtr, gtr ld, solo gtr, gtr solo, guitar solo, solo guitar",
        "Lead Gtr", "Guitars", GT),
      rule("gtr, guitar, guitars, gt, egtr, elec, electric, el gtr, eg, rhythm, rhy, rtm, gtr rtm, gtr rhythm, "
        .. "rhythm gtr, crunch, clean gtr, dist gtr", "Gtr", "Guitars", GT),
      rule("piano, pianos, pno, grand, upright, upright piano", "Piano", "Keys", KY),
      rule("organ, hammond, org, leslie", "Organ", "Keys", KY),
      rule("lead synth, synth lead, synth solo, ld synth", "Lead Synth", "Keys", KY),
      rule("synth, synths, syn, pad, pads, arp, poly", "Synth", "Keys", KY),
      rule("keys, key, rhodes, wurli, wurlitzer, ep, e piano, epiano, clav, mellotron", "Keys", "Keys", KY),
      rule("strings, string, str, violin, violins, vln, vlns, viola, vla, cello, cellos, vc, quartet", "Strings",
        "Strings", ST),
      rule("brass, horns, horn, trumpet, trumpets, tpt, trp, trombone, tbn, tbone, sax, saxophone", "Brass",
        "Brass", BR),
      rule("bv, bvs, bgv, bgvs, bvox, bgvox, backing, backings, backing vocals, harm, harmony, harmonies, choir, "
        .. "oohs, aahs", "BV", "Vocals", VX),
      rule("vox, vocal, vocals, voc, lead vox, lead vocal, main vox, lead, ld, lv, voice, singer", "Lead Vox",
        "Vocals", VX),
    }
  end
  local RT = 0x5E9C96 -- (the returns: 1 color)
  local function returns() -- the 4 standard FX returns and who sends to them
    local function ret(name, db, out) return { name = name, chain = "", color = RT, src = "t", db = db, out = out } end
    -- (the reverbs and the delay: -12 dB to the master; Drum Crush: 0 dB (parallel compression) into the drum sum)
    return { ret("Room Verb", -12, "m"), ret("Hall Verb", -12, "m"), ret("Delay", -12, "m"),
      ret("Drum Crush", 0, "f:Drums") }, {
      Drums = { ["Room Verb"] = true, ["Drum Crush"] = true },
      Guitars = { ["Hall Verb"] = true }, Keys = { ["Hall Verb"] = true },
      Vocals = { ["Hall Verb"] = true, ["Delay"] = true },
    }
  end
  local function buses() -- the 3 buses (off): the music, the vocals, the lead instruments
    local function f(n) return { kind = "f", name = n } end
    local function t(n) return { kind = "t", name = n } end
    return {
      { name = "Instrument Bus", on = false, color = 0x7A8699,
        members = { f("Drums"), f("Perc"), f("Bass"), f("Guitars"), f("Keys"), f("Strings"), f("Brass") } },
      { name = "Vocal Bus", on = false, color = VX, members = { t("Lead Vox"), t("BV") } },
      { name = "Lead Bus", on = false, color = 0xE07B39, members = { t("Lead Gtr"), t("Lead Synth") } },
    }
  end
  local function preset(name, order)
    local ret, sends = returns()
    return { name = name, strip = true, rules = rules(), order = order, fx = {}, tfx = {}, returns = ret,
      sends = sends, buses = buses() }
  end
  local list = {
    preset("Default", { "Drums", "Perc", "Bass", "Guitars", "Keys", "Strings", "Brass", "Vocals", "Other" }),
    preset("Vocals first", { "Vocals", "Drums", "Perc", "Bass", "Guitars", "Keys", "Strings", "Brass", "Other" }),
  }
  for _, pr in ipairs(list) do -- (Reset to original: the built-in settings; they are saved as they are)
    pr.orig = Rules.serialize(pr)
    pr.saved = pr.orig
    Rules.update_dirty(pr)
  end
  return list
end
-- The original of a built-in preset by its name (nil: not a built-in name).
function Rules.builtin_orig(name)
  for _, d in ipairs(Rules.default_presets()) do if d.name == name then return d.orig end end
end
-- The settings of a preset text into p (its name stays). Returns true when the text was a preset.
function Rules.apply_text(p, text)
  local o = p and text and Rules.parse(text)
  if not o then return false end
  p.strip, p.rules, p.order, p.fx, p.tfx = o.strip, o.rules, o.order, o.fx, o.tfx
  p.returns, p.sends, p.buses = o.returns, o.sends, o.buses
  R.edit_rule, R.folder_buf_rule = nil, nil
  return true
end
-- Reset to original: the preset gets the settings of its original again (its name stays). Returns true when done.
function Rules.reset(p)
  if not Rules.apply_text(p, p and p.orig) then return false end
  Rules.changed()
  return true
end
-- Save: the edits of a preset wait for Save (p.saved: its text at the last Save). p.dirty: it has unsaved edits
-- (the name does not count); p.label: the name with a dot when dirty (the dropdown).
local function preset_body(text) return (text or ""):match("^[^|]*|(.*)$") or "" end
function Rules.update_dirty(p)
  p.dirty = p.saved ~= nil and preset_body(Rules.serialize(p)) ~= preset_body(p.saved)
  p.label = p.dirty and (p.name .. "  \u{2022}") or p.name
end
function Rules.save(p)
  p.saved = Rules.serialize(p)
  Rules.update_dirty(p)
  Util.mark_sdirty()
end
-- Revert to saved: the settings of the last Save again.
function Rules.revert(p)
  if not Rules.apply_text(p, p.saved) then return false end
  Rules.changed()
  return true
end
-- The separators of the saved text (removed from the names and words that you type).
function Rules.safe(s) return (Util.clean(s):gsub("[|;~%^]", "")) end
-- The text of a preset (9 parts with "|"): name|strip|rules|folder fx|track fx|order|returns|sends|buses.
-- In a part: entries with ";", fields with "~", a list in a field with "^". A map is sorted: the same preset gives
-- the same text.
local function map_text(m)
  local t = {}
  for k, v in pairs(m or {}) do t[#t + 1] = Rules.safe(k) .. "~" .. Rules.safe(v) end
  table.sort(t)
  return table.concat(t, ";")
end
function Rules.serialize(p)
  local t = {}
  for _, ru in ipairs(p.rules) do
    t[#t + 1] = table.concat({ Rules.safe(ru.match), Rules.safe(ru.name), Rules.safe(ru.folder),
      string.format("%06X", (ru.color or 0) & 0xFFFFFF), Rules.safe(ru.pol or "") }, "~")
  end
  local order = {}
  for _, f in ipairs(p.order or {}) do order[#order + 1] = Rules.safe(f) end
  local ret = {}
  for _, rt in ipairs(p.returns or {}) do
    ret[#ret + 1] = table.concat({ Rules.safe(rt.name), Rules.safe(rt.chain or ""),
      string.format("%06X", (rt.color or 0) & 0xFFFFFF), rt.src == "f" and "f" or "t",
      string.format("%.1f", rt.db or -12), Rules.safe(rt.out or "m") }, "~")
  end
  local buses = {}
  for _, b in ipairs(p.buses or {}) do
    local m = {}
    for _, mb in ipairs(b.members) do m[#m + 1] = mb.kind .. ":" .. Rules.safe(mb.name) end
    buses[#buses + 1] = table.concat({ Rules.safe(b.name), b.on and "1" or "0",
      string.format("%06X", (b.color or 0) & 0xFFFFFF), table.concat(m, "^") }, "~")
  end
  local sends = {}
  for f, set in pairs(p.sends or {}) do
    local names = {}
    for n in pairs(set) do names[#names + 1] = Rules.safe(n) end
    table.sort(names)
    if #names > 0 then sends[#sends + 1] = Rules.safe(f) .. "~" .. table.concat(names, "~") end
  end
  table.sort(sends)
  return table.concat({ Rules.safe(p.name), p.strip and "1" or "0", table.concat(t, ";"), map_text(p.fx),
    map_text(p.tfx), table.concat(order, ";"), table.concat(ret, ";"), table.concat(sends, ";"),
    table.concat(buses, ";") }, "|")
end
function Rules.parse(txt)
  local parts = {}
  for part in ((txt or "") .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = part end
  if #parts ~= 9 or parts[1] == "" or not parts[2]:match("^[01]$") then return nil end
  local p = { name = parts[1], strip = parts[2] == "1", rules = {}, fx = {}, tfx = {}, order = {}, returns = {},
    sends = {}, buses = {} }
  for part in parts[3]:gmatch("[^;]+") do
    local m, n, f, c, pol = part:match("^([^~]*)~([^~]*)~([^~]*)~(%x+)~([^~]*)$")
    if m then p.rules[#p.rules + 1] = rule(m, n, f, tonumber(c, 16), pol) end
  end
  for part in parts[9]:gmatch("[^;]+") do
    local n, on, c, list = part:match("^([^~]+)~([01])~(%x+)~(.*)$")
    if n then
      local b = { name = n, on = on == "1", color = tonumber(c, 16), members = {} }
      for kind, mn in list:gmatch("([ft]):([^%^]+)") do b.members[#b.members + 1] = { kind = kind, name = mn } end
      p.buses[#p.buses + 1] = b
    end
  end
  for key, i in pairs({ fx = 4, tfx = 5 }) do
    for part in parts[i]:gmatch("[^;]+") do
      local k, path = part:match("^([^~]+)~(.+)$")
      if k then p[key][k] = path end
    end
  end
  for f in parts[6]:gmatch("[^;]+") do p.order[#p.order + 1] = f end
  for part in parts[7]:gmatch("[^;]+") do
    local n, chain, c, src, db, out = part:match("^([^~]+)~([^~]*)~(%x+)~([tf])~([^~]+)~([^~]+)$")
    if n then
      p.returns[#p.returns + 1] = { name = n, chain = chain, color = tonumber(c, 16), src = src,
        db = tonumber(db) or -12, out = out }
    end
  end
  for part in parts[8]:gmatch("[^;]+") do
    local f, rest = part:match("^([^~]+)~(.+)$")
    if f then
      p.sends[f] = {}
      for n in rest:gmatch("[^~]+") do p.sends[f][n] = true end
    end
  end
  return p
end
-- The folders of a preset from top to bottom: the folder order (p.order) first (only the folders that a rule uses), then the
-- other folders of the rules (cached until a rule changes: R.folder_list).
function Rules.folders(p)
  if R.folder_list and R.folder_list_p == p then return R.folder_list end
  local used, list, seen = {}, {}, {}
  for _, ru in ipairs(p.rules) do
    local f = Util.clean(ru.folder)
    if f ~= "" then used[f] = true end
  end
  for _, f in ipairs(p.order or {}) do
    if used[f] and not seen[f] then seen[f] = true; list[#list + 1] = f end
  end
  for _, ru in ipairs(p.rules) do
    local f = Util.clean(ru.folder)
    if f ~= "" and not seen[f] then seen[f] = true; list[#list + 1] = f end
  end
  R.folder_list, R.folder_list_p = list, p
  return list
end
-- The place of a folder in the order (1 = top); a track without a folder: after all folders.
function Rules.folder_rank(p, folder)
  for i, f in ipairs(Rules.folders(p)) do if f == folder then return i end end
  return 1e6
end
function Rules.cur() return S.presets[S.preset] end
-- A folder (kind "folder") or a rule name (kind "name") was renamed in a rule: when no rule uses the old name any
-- more, its settings go to the new name (Folder FX, sends, bus membership, the place in the folder order; Track FX
-- and bus membership of a rule name). A setting that the new name already has stays.
function Rules.rename(p, kind, old, new)
  old, new = Util.clean(old), Util.clean(new)
  if old == "" or new == "" or old == new then return end
  local key = kind == "folder" and "folder" or "name"
  for _, ru in ipairs(p.rules) do if Util.clean(ru[key]) == old then return end end
  local mk = kind == "folder" and "f" or "t"
  local fxmap = kind == "folder" and p.fx or p.tfx
  if fxmap[old] and not fxmap[new] then fxmap[new] = fxmap[old] end
  fxmap[old] = nil
  for _, b in ipairs(p.buses or {}) do
    for _, mb in ipairs(b.members) do if mb.kind == mk and mb.name == old then mb.name = new end end
  end
  for _, rt in ipairs(kind == "folder" and p.returns or {}) do -- (a return's output into that folder)
    if rt.out == "f:" .. old then rt.out = "f:" .. new end
  end
  if kind == "folder" then
    if p.sends[old] and not p.sends[new] then p.sends[new] = p.sends[old] end
    p.sends[old] = nil
    local has = false
    for _, f in ipairs(p.order) do if f == new then has = true end end
    for i = #p.order, 1, -1 do
      if p.order[i] == old then
        if has then table.remove(p.order, i) else p.order[i] = new end
      end
    end
  end
end
-- The Undo of each section of the current preset (its button on the section's heading): "rules" (the rules and the
-- folder order), "buses", "returns" (the returns, the sends and the send level). R.hist[section] holds the text of
-- the preset before each change of that section (the last CFG.UNDO_STEPS; changes within CFG.UNDO_MERGE are 1 step);
-- R.snap is the text now. A switch, new or deleted preset clears the history; a setting is no step.
local UNDO_PARTS = { rules = { 3, 6 }, buses = { 9 }, returns = { 7, 8 } } -- (the parts of Rules.serialize)
function Rules.snapshot()
  local p = Rules.cur()
  local text = p and Rules.serialize(p) or ""
  local parts = {}
  for part in (text .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = part end
  local sec = {}
  for name, idx in pairs(UNDO_PARTS) do
    local t = {}
    for k, i in ipairs(idx) do t[k] = parts[i] or "" end
    sec[name] = table.concat(t, "|")
  end
  return { text = text, sec = sec, idx = S.preset, n = #S.presets }
end
function Rules.record()
  local now = Util.now()
  local snap = Rules.snapshot()
  local old = R.snap
  R.hist = R.hist or {}
  if not old or old.idx ~= snap.idx or old.n ~= snap.n then -- (another preset: a new history)
    R.hist, R.hist_t = {}, {}
  else
    R.hist_t = R.hist_t or {}
    for name in pairs(UNDO_PARTS) do
      if old.sec[name] ~= snap.sec[name] then
        local h = R.hist[name] or {}
        R.hist[name] = h
        if not (R.hist_t[name] and now - R.hist_t[name] < CFG.UNDO_MERGE and #h > 0) then
          h[#h + 1] = old.text
          if #h > CFG.UNDO_STEPS then table.remove(h, 1) end
        end
        R.hist_t[name] = now
      end
    end
  end
  R.snap = snap
end
function Rules.undo_count(section) return R.hist and R.hist[section] and #R.hist[section] or 0 end
function Rules.undo(section)
  local h = R.hist and R.hist[section]
  local text = h and table.remove(h)
  local p = Rules.cur()
  if not text or not p then return end
  local old = Rules.parse(text)
  if not old then return end
  if section == "rules" then p.rules, p.order = old.rules, old.order
  elseif section == "buses" then p.buses = old.buses
  else p.returns, p.sends = old.returns, old.sends end
  R.hist_t = {}
  R.edit_rule, R.folder_buf_rule = nil, nil
  R.comp, R.folder_list = nil, nil
  R.snap = Rules.snapshot()
  Util.mark_sdirty()
  if R.scan then R.rows = Prep.keep_edits(R.rows, Prep.plan(R.scan)) end
end
-- A rule or preset changed: save the settings, compile the rules again, and plan the preview again.
function Rules.changed()
  Rules.record()
  if Rules.cur() then Rules.update_dirty(Rules.cur()) end
  R.comp, R.folder_list = nil, nil
  Util.mark_sdirty()
  if R.scan then R.rows = Prep.keep_edits(R.rows, Prep.plan(R.scan)) end
end
-- The compiled rules: the match words in lower case ({ terms = { "kik", "kick" }, rule }).
function Rules.compile(p)
  local out = {}
  for i, ru in ipairs(p and p.rules or {}) do
    local terms = {}
    for w in (ru.match or ""):gmatch("[^,]+") do
      w = Util.clean(w):lower():gsub("[^%w ]", " "):gsub("%s+", " ")
      w = Util.clean(w)
      if w ~= "" then terms[#terms + 1] = w end
    end
    out[#out + 1] = { idx = i, terms = terms, rule = ru }
  end
  return out
end
function Rules.compiled()
  if not R.comp then R.comp = Rules.compile(Rules.cur()) end
  return R.comp
end
-- A name that is not used by another preset ("Default 2").
function Rules.free_name(name)
  local used = {}
  for _, p in ipairs(S.presets) do used[p.name] = true end
  if not used[name] then return name end
  local n = 2
  while used[name .. " " .. n] do n = n + 1 end
  return name .. " " .. n
end
function Rules.copy(p)
  return Rules.parse(Rules.serialize(p)) -- (the text has every part: a full copy)
end
-- Export: a text file in the data folder. Returns the path, or nil + the error.
function Rules.export(p)
  r.RecursiveCreateDirectory(CFG.DATA_DIR, 0)
  local path = (CFG.DATA_DIR .. "/" .. p.name:gsub("[\\/:%*%?\"<>|]", "_") .. ".txt"):gsub("/", "\\")
  if not Util.write_all(path, "Session Prep preset\n" .. Rules.serialize(p) .. "\n") then
    return nil, "The file cannot be written: " .. path
  end
  return path
end
function Rules.import(path)
  local d = Util.read_all(path)
  if not d then return nil, "The file cannot be read." end
  local head, body = d:match("^(Session Prep preset)\r?\n([^\r\n]*)")
  local p = head and Rules.parse(body)
  if not p then return nil, "This is not a Session Prep preset file." end
  p.name = Rules.free_name(p.name)
  p.orig = Rules.serialize(p) -- (its original and saved version: as it was imported)
  p.saved = p.orig
  Rules.update_dirty(p)
  S.presets[#S.presets + 1] = p
  S.preset = #S.presets
  Rules.changed()
  return p
end

---------------------------------------------------------------------------
-- PREP (the names: clean, match, plan; Apply)
---------------------------------------------------------------------------
-- The words that stay after the new name ("Kik In" -> "Kick In"); L / R mark the pan side.
local QUAL = {
  l = "L", left = "L", lt = "L", r = "R", right = "R", rt = "R",
  ["in"] = "In", out = "Out", top = "Top", bot = "Btm", btm = "Btm", bottom = "Btm", up = "Up", down = "Dn", dn = "Dn",
  di = "DI", amp = "Amp", mic = "Mic", close = "Close", far = "Far", hi = "Hi", high = "Hi", lo = "Lo", low = "Lo",
  dbl = "Dbl", double = "Dbl", main = "Main", sub = "Sub", mono = "Mono", st = "St", stereo = "St", mid = "Mid",
  side = "Side", front = "Front", back = "Back", rear = "Back", ribbon = "Ribbon", talk = "Talk", fx = "FX",
}
-- The order of the extra words in a folder: In / Top first, then Out / Btm (Kick In, Kick Out; Snare Top, Snare Btm).
local QUAL_RANK = { In = 1, Top = 1, Out = 2, Btm = 2, Sub = 3 }
-- The name without the file extension, "Audio 1_" / "Audio1-" and a leading track number ("01 ", "03_").
function Prep.base_clean(name)
  local s = Util.clean(name)
  s = s:gsub("%.[Ww][Aa][Vv][Ee]?$", ""):gsub("%.[Aa][Ii][Ff][Ff]?$", ""):gsub("%.[Ff][Ll][Aa][Cc]$", "")
  s = s:gsub("^[Aa]udio%s*%d*[%s_%-%.]+", ""):gsub("^[Aa]udio%s*%d+$", "")
  s = s:gsub("^%d+[%s_%-%.]+", "")
  return Util.clean(s)
end
-- The words of a name, in lower case: "KikIn_01" -> { "kik", "in", "01" } (letters and digits apart).
function Prep.tokens(s)
  s = s:gsub("(%l)(%u)", "%1 %2"):lower():gsub("(%a)(%d)", "%1 %2"):gsub("(%d)(%a)", "%1 %2")
  local t = {}
  for w in s:gmatch("%w+") do t[#t + 1] = w end
  return t
end
-- The first rule that matches the words (the order of the rules): its compiled rule and the matched word(s).
-- A word of 4 or more letters also matches inside a longer word ("kick" in "subkick"); shorter ones only alone.
function Prep.match(toks, comp)
  local norm = " " .. table.concat(toks, " ") .. " "
  for _, c in ipairs(comp) do
    for _, term in ipairs(c.terms) do
      if term:find(" ", 1, true) then
        if norm:find(" " .. term .. " ", 1, true) then return c, term end
      else
        for _, tk in ipairs(toks) do
          if tk == term or (#term >= 4 and tk:find(term, 1, true)) then return c, term end
        end
      end
    end
  end
end
local function common_prefix(list)
  local p = list[1]
  for i = 2, #list do
    local s, n = list[i], 0
    while n < #p and n < #s and p:byte(n + 1) == s:byte(n + 1) do n = n + 1 end
    p = p:sub(1, n)
  end
  return p
end
-- Removes the prefix and the suffix that all the names share (at a word border, 4 or more letters or digits,
-- and not a word of a rule: "Kick In" and "Kick Out" keep "Kick").
function Prep.strip_common(names, comp)
  if #names < 2 then return names end
  local function usable(part)
    local _, n = part:gsub("%w", "")
    return n >= CFG.STRIP_MIN and not Prep.match(Prep.tokens(part), comp)
  end
  local p = common_prefix(names):match("^(.*[%s_%-%.])") or ""
  local rev = {}
  for i, s in ipairs(names) do rev[i] = s:reverse() end
  local q = (common_prefix(rev):match("^(.*[%s_%-%.])") or ""):reverse()
  if not usable(p) then p = "" end
  if not usable(q) then q = "" end
  local out = {}
  for i, s in ipairs(names) do
    local t = s
    if #p > 0 and #t > #p then t = t:sub(#p + 1) end
    if #q > 0 and #t > #q then t = t:sub(1, #t - #q) end
    t = t:gsub("^[%s_%-%.]+", ""):gsub("[%s_%-%.]+$", "")
    out[i] = t ~= "" and t or s
  end
  return out
end
-- The new name of 1 track: the rule's name and the extra words ("In", "L", "2"); side = "L" / "R" / nil.
function Prep.new_name(clean, comp)
  local toks = Prep.tokens(clean)
  local c, term = Prep.match(toks, comp)
  if not c then return nil end
  local used = {}
  for w in term:gmatch("%S+") do used[w] = true end
  local in_name = {}
  for w in (c.rule.name or ""):lower():gmatch("%w+") do in_name[w] = true end
  local quals, side = {}, nil
  for _, tk in ipairs(toks) do
    if not used[tk] then
      local q = QUAL[tk] or (tk:match("^%d+$") and tostring(tonumber(tk)))
      if q and not in_name[q:lower()] then
        if q == "L" or q == "R" then side = q end
        quals[#quals + 1] = q
      end
    end
  end
  local name = Util.clean(c.rule.name or "")
  if name == "" then name = clean end
  if #quals > 0 then name = name .. " " .. table.concat(quals, " ") end
  return name, c, side, quals
end

-- The tracks of the Scan: the selected tracks, or all tracks when none is selected (all: always all tracks).
function Prep.scan_tracks(all)
  local list, n = {}, all and 0 or r.CountSelectedTracks(0)
  local scope = n > 0 and "selected" or "all"
  local count = n > 0 and n or r.CountTracks(0)
  -- (the tracks that Session Prep made or prepped have its mark: they are left out, a client's own "Delay" is not)
  local skipped, date = 0, nil
  local inlist = {}
  for i = 0, count - 1 do
    local tr = n > 0 and r.GetSelectedTrack(0, i) or r.GetTrack(0, i)
    local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    local _, label = r.GetTrackName(tr)
    local _, mark = r.GetSetMediaTrackInfo_String(tr, CFG.PREP_KEY, "", false)
    if mark ~= "" then -- (prepped before: left out; Ctrl+Z of that Apply removes the mark)
      skipped, date = skipped + 1, mark
    else
      inlist[tr] = true
      list[#list + 1] = { tr = tr, guid = r.GetTrackGUID(tr), name = Util.clean(name), label = label,
        idx = math.floor(r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")) }
    end
  end
  -- the names of the other tracks of the project (a new name that is already there gets a number)
  local others = {}
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    if not inlist[tr] then
      local _, nm = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      if nm ~= "" then others[Util.clean(nm):upper()] = true end
    end
  end
  return list, scope, skipped, date, others
end
-- Scan: reads the tracks (and their audio when Settings > Prep > Check audio is on). Changes nothing.
-- Prep.scan_begin starts it, Prep.scan_step reads the audio for at most budget seconds per frame (R.scanning: the
-- Prep tab shows "Scanning 12 / 64"); Prep.scan does it all at once.
function Prep.scan_begin(all)
  local list, scope, skipped, date, others = Prep.scan_tracks(all)
  local srate = r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, false) == 0 then -- (no project rate: the audio device's rate)
    local okd, dev = r.GetAudioDeviceInfo("SRATE")
    srate = okd and tonumber(dev) or 0
  end
  R.scanning = { tracks = list, i = 0, scope = scope, folders_ok = true, audio = S.audio, gain = S.gain,
    proj = r.EnumProjects(-1), skipped = skipped, date = date, others = others, srate = srate }
  R.rows, R.scan, R.tc = nil, nil, nil -- (the cut texts of the old rows go)
end
function Prep.scan_step(budget)
  local sc = R.scanning
  if not sc then return true end
  local t0 = r.time_precise()
  while sc.i < #sc.tracks do
    sc.i = sc.i + 1
    local t = sc.tracks[sc.i]
    if r.ValidatePtr2(0, t.tr, "MediaTrack*") then
      local depth = r.GetMediaTrackInfo_Value(t.tr, "I_FOLDERDEPTH")
      if (sc.audio or sc.gain) and depth ~= 1 then -- (a folder track has no audio of its own)
        local verdict, rms, peak = Audio.check(t.tr)
        if sc.audio then t.audio = verdict end
        t.rms, t.peak = rms, peak
      end
      if depth ~= 0 or r.GetParentTrack(t.tr) then sc.folders_ok = false end
      Prep.file_check(t, sc.srate)
      -- (a pan that is already set: the client's mix; the Pan button starts at "-")
      t.pan = r.GetMediaTrackInfo_Value(t.tr, "D_PAN")
      t.panned = math.abs(t.pan) > 0.005
      local mode = r.GetMediaTrackInfo_Value(t.tr, "I_PANMODE")
      if mode == 6 or mode == -1 then -- (dual pan, or the project default: that can be dual pan)
        local dual = r.GetMediaTrackInfo_Value(t.tr, "D_DUALPANL") > -0.995 or r.GetMediaTrackInfo_Value(t.tr, "D_DUALPANR") < 0.995
        if mode == 6 then t.panned, t.pan = dual, nil
        elseif dual and not t.panned then t.panned, t.pan = true, nil end
      end
    end
    if budget and r.time_precise() - t0 > budget then return false end
  end
  R.scanning = nil
  sc.i = nil
  for _, t in ipairs(sc.tracks) do -- (the earliest start of all items: a track that starts later gets a note)
    if t.start and (not sc.min_start or t.start < sc.min_start) then sc.min_start = t.start end
  end
  R.scan = sc
  R.rows = Prep.plan(R.scan)
  return true
end
function Prep.scan(all)
  Prep.scan_begin(all)
  Prep.scan_step(nil)
end
-- The file check of 1 track: t.start (its first item), t.srate (a file whose sample rate is not the project's).
function Prep.file_check(t, srate)
  for i = 0, r.CountTrackMediaItems(t.tr) - 1 do
    local it = r.GetTrackMediaItem(t.tr, i)
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    if not t.start or pos < t.start then t.start = pos end
    local tk = r.GetActiveTake(it)
    if tk and not r.TakeIsMIDI(tk) then
      local fr = r.GetMediaSourceSampleRate(r.GetMediaItemTake_Source(tk))
      if fr and fr > 0 and srate and srate > 0 and math.abs(fr - srate) > 1 then t.srate = fr end
    end
  end
end

-- What the audio check found: the note, the fix and its default.
local AUDIO_NOTE = {
  -- { note, fix, tag (short), tag tooltip }
  empty = { "empty", "delete", "empty", "No items on this track. Click Delete to remove it at Apply." },
  silent = { "silent", nil, "silent", "No audio (below -60 dBFS). Use M to mute it." },
  fake = { "fake stereo", "mono", "fake st", "Both sides are the same: a mono recording in a stereo file. Click Mono." },
  only_l = { "only left side", "mono L", "L only", "Only the left side has audio. Click Mono: it plays only the left side." },
  only_r = { "only right side", "mono R", "R only", "Only the right side has audio. Click Mono: it plays only the right side." },
}
-- The preview rows of a scan with the current preset (no REAPER calls: the tests run it on plain names).
function Prep.plan(scan)
  local comp = Rules.compiled()
  local p = Rules.cur()
  local cleaned, named, idx = {}, {}, {}
  for i, t in ipairs(scan.tracks) do
    cleaned[i] = Prep.base_clean(t.name)
    if cleaned[i] ~= "" then named[#named + 1] = cleaned[i]; idx[#idx + 1] = i end
  end
  if p and p.strip then -- (only the tracks with a name: an unnamed one has no prefix)
    local stripped = Prep.strip_common(named, comp)
    for k, i in ipairs(idx) do cleaned[i] = stripped[k] end
  end
  -- the natural order in a folder: a rule whose name starts with another rule's name in the same folder ("Kick Sub",
  -- "Kick") sorts after it; then In / Top before Out / Btm (QUAL_RANK)
  local base_of = {}
  for i, ru in ipairs(p and p.rules or {}) do
    local nm = Util.clean(ru.name):lower()
    for j, o in ipairs(p.rules) do
      local on = Util.clean(o.name):lower()
      if j ~= i and on ~= "" and o.folder == ru.folder and nm:sub(1, #on + 1) == on .. " " then base_of[i] = j end
    end
  end
  local rows = {}
  for i, t in ipairs(scan.tracks) do
    local old = t.name ~= "" and t.name or (t.label or "")
    local name, c, side, quals = Prep.new_name(cleaned[i], comp)
    if name then name = Prep.caps(name, "track")
    elseif cleaned[i] ~= "" then name = Prep.caps(cleaned[i], "track")
    else name = old end -- (unnamed and no rule: it stays as it is)
    local row = { t = t, old = old, new = name, on = true, side = side, order = i, pan = S.pairs and side or nil }
    -- the file notes (orange in Notes): another sample rate, a later start than the other tracks
    local fn = {}
    if t.srate then fn[#fn + 1] = string.format("%g kHz", math.floor(t.srate / 100 + 0.5) / 10) end
    if t.start and scan.min_start and t.start > scan.min_start + 0.05 then
      fn[#fn + 1] = string.format("starts at %d:%02d", math.floor(t.start / 60), math.floor(t.start % 60))
    end
    if #fn > 0 then row.fnote = table.concat(fn, ", ") end
    row.tags = {}
    if t.srate then
      local k = math.floor(t.srate / 100 + 0.5) / 10
      row.tags[#row.tags + 1] = { text = string.format("%gk", k), tip = string.format("This track's file is %g kHz; the "
        .. "project is %g kHz. Session Prep does not change it: check it before you mix.", k,
        math.floor((scan.srate or 0) / 100 + 0.5) / 10) }
    end
    if t.start and scan.min_start and t.start > scan.min_start + 0.05 then
      row.tags[#row.tags + 1] = { text = "late", tip = string.format("Its first item starts at %d:%02d, later than the "
        .. "other tracks. Check that the files line up.", math.floor(t.start / 60), math.floor(t.start % 60)) }
    end
    if c then
      row.rule_idx = c.idx
      row.base_idx = base_of[c.idx] or c.idx
      row.qrank = 9
      for _, q in ipairs(quals or {}) do if QUAL_RANK[q] then row.qrank = math.min(row.qrank, QUAL_RANK[q]) end end
      local pol = c.rule.pol or ""
      if pol == "*" then row.pol = true
      elseif pol ~= "" then
        for _, q in ipairs(quals or {}) do if q:lower() == pol:lower() then row.pol = true end end
      end
      row.rname = Util.clean(c.rule.name or "")
      row.color = c.rule.color
      row.folder = Util.clean(c.rule.folder or "")
    else
      row.folder = ""
    end
    local a = t.audio and AUDIO_NOTE[t.audio]
    if a then
      row.note, row.fix, row.fix_on = a[1], a[2], false
      row.tags[#row.tags + 1] = { text = a[3], tip = a[4] }
    end
    if t.panned then -- (already panned: kept; the Pan button starts at "-")
      row.pan = nil
      row.pnote = t.pan and string.format("kept pan %d%s", math.floor(math.abs(t.pan) * 100 + 0.5), t.pan < 0 and "L" or "R")
        or "kept pan"
      row.tags[#row.tags + 1] = { text = row.pnote:gsub("^kept pan", "kept"), dim = true,
        tip = "This track was already panned (for example in the client's project): the Pan button starts at \"-\" "
          .. "and Apply keeps the pan. Click Pan to change it." }
    end
    if S.gain then row.gain = Prep.gain_for(t.rms, t.peak); row.gain_meas = row.gain end
    rows[#rows + 1] = row
  end
  -- the same new name 2 or more times, or a name that another track of the project has: "Gtr 1", "Gtr 2" (in
  -- track order; a number that another track has is skipped)
  local others = scan.others or {}
  local count, seen = {}, {}
  for _, row in ipairs(rows) do count[row.new] = (count[row.new] or 0) + 1 end
  for _, row in ipairs(rows) do
    if count[row.new] > 1 or others[row.new:upper()] then
      local base = row.new
      local n = (seen[base] or 0) + 1
      while others[(base .. " " .. n):upper()] do n = n + 1 end
      seen[base] = n
      row.new = base .. " " .. n
    end
  end
  R.summary = nil
  return rows
end

-- Gain staging: the change in dB that brings the average level (RMS) to the target, without a peak above the
-- peak limit; Target: Peak: the peak to the target peak (rounded to 0.1 dB). nil: no audio.
function Prep.gain_for(rms, peak)
  if not rms or rms <= 0 or not peak or peak <= 0 then return nil end
  local function db(v) return 20 * math.log(v, 10) end
  local g
  if S.gain_by_peak then g = S.gain_ptarget - db(peak) -- (Target: Peak)
  else g = math.min(S.gain_rms - db(rms), S.gain_peak - CFG.PEAK_MARGIN - db(peak)) end
  return math.floor(g * 10 + 0.5) / 10
end

-- After a new plan (a rule or setting changed): the edits of the old rows stay (the tick, the Mono fix, and the
-- name, pan and gain that you changed by hand). Returns the new rows.
function Prep.keep_edits(old_rows, rows)
  local old = {}
  for _, row in ipairs(old_rows or {}) do old[row.t] = row end
  for _, row in ipairs(rows) do
    local o = old[row.t]
    if o then
      row.on = o.on
      if row.fix then row.fix_on = o.fix_on end
      if o.edited then row.new, row.edited = o.new, true end
      if o.pan_edited then row.pan, row.pan_edited = o.pan, true end
      if o.pol_edited then row.pol, row.pol_edited = o.pol, true end
      if o.width_edited then row.width, row.width_edited = o.width, true end
      if o.gain_edited and row.gain then row.gain, row.gain_edited = o.gain, true end
    end
  end
  return rows
end

-- The folder color: the color of the first rule with that folder.
function Prep.folder_color(folder)
  for _, ru in ipairs(Rules.cur() and Rules.cur().rules or {}) do
    if Util.clean(ru.folder) == folder then return ru.color end
  end
end
local function native(c) return r.ColorToNative((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF) | 0x1000000 end
-- SWS Auto Color is on (SWS installed and its "Enable auto coloring" toggle on): SWS colors the tracks, not Session Prep.
function Prep.sws_autocolor()
  local id = r.NamedCommandLookup("_SWSAUTOCOLOR_ENABLE")
  return id ~= 0 and r.GetToggleCommandState(id) == 1
end
function Prep.color_on() return S.color and (S.color_win or not Prep.sws_autocolor()) end

-- Adds an FX chain file (.RfxChain) to a track, after the FX that it has: the chain text goes at the end of the
-- track's FX chain block (made when the track has none). (REAPER's TrackFX_AddByName does not load chain files.)
-- Returns true when the track has more FX after it.
function Prep.add_chain(tr, path)
  local text = Util.read_all(path)
  if not text then return false end
  text = text:gsub("^\239\187\191", ""):gsub("\r\n", "\n"):gsub("\n+$", "")
  if text == "" then return false end
  local before = r.TrackFX_GetCount(tr)
  local ok, chunk = r.GetTrackStateChunk(tr, "", false)
  if not ok then return false end
  local lines = {}
  for line in (chunk .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
  -- the end of the FX chain block: its own ">" (the blocks inside it open with "<" and close with ">")
  local start, close
  for i, line in ipairs(lines) do
    if line:match("^%s*<FXCHAIN") then start = i; break end
  end
  if start then
    local depth = 0
    for i = start, #lines do
      local l = lines[i]:match("^%s*(.-)%s*$")
      if l:sub(1, 1) == "<" then depth = depth + 1
      elseif l == ">" then
        depth = depth - 1
        if depth == 0 then close = i; break end
      end
    end
    if not close then return false end
    table.insert(lines, close, text)
  else -- no FX chain block: a new one before the track's own ">" (the last line that is ">")
    local last
    for i = #lines, 1, -1 do
      if lines[i]:match("^%s*>%s*$") then last = i; break end
    end
    if not last then return false end
    table.insert(lines, last, "<FXCHAIN\nSHOW 0\nLASTSEL 0\nDOCKED 0\n" .. text .. "\n>")
  end
  r.SetTrackStateChunk(tr, table.concat(lines, "\n"), false)
  return r.TrackFX_GetCount(tr) > before
end

-- Puts the ticked rows with a folder in folders (new folder tracks) in the folder order (p.order), at the place of
-- the first scanned track. Only when the scanned tracks are not in folders yet. Returns the number of new folder
-- tracks; R.folder_tracks = { [folder] = its track } (the Instrument Bus routing uses them).
function Prep.make_folders(rows)
  local list, base = {}, math.huge
  for _, row in ipairs(rows) do
    if r.ValidatePtr2(0, row.t.tr, "MediaTrack*") then
      base = math.min(base, math.floor(r.GetMediaTrackInfo_Value(row.t.tr, "IP_TRACKNUMBER")) - 1)
      if row.on and row.folder ~= "" then list[#list + 1] = row end
    end
  end
  if #list == 0 then return 0 end
  local pr = Rules.cur()
  local rank = {}
  for _, row in ipairs(list) do rank[row.folder] = rank[row.folder] or Rules.folder_rank(pr, row.folder) end
  table.sort(list, function(a, b) -- the folder order (p.order), the base rule, its own rule after, In / Out, the track
    if rank[a.folder] ~= rank[b.folder] then return rank[a.folder] < rank[b.folder] end
    local ab, bb = a.base_idx or a.rule_idx or 1e9, b.base_idx or b.rule_idx or 1e9
    if ab ~= bb then return ab < bb end
    local asub, bsub = (a.rule_idx ~= ab) and 1 or 0, (b.rule_idx ~= bb) and 1 or 0
    if asub ~= bsub then return asub < bsub end
    if (a.qrank or 9) ~= (b.qrank or 9) then return (a.qrank or 9) < (b.qrank or 9) end
    return a.order < b.order
  end)
  -- the tree: { name, kids } = a folder track, { tr } = a track
  local order, by = {}, {}
  for _, row in ipairs(list) do
    if not by[row.folder] then by[row.folder] = {}; order[#order + 1] = row.folder end
    table.insert(by[row.folder], { tr = row.t.tr })
  end
  local top = {}
  for _, f in ipairs(order) do top[#top + 1] = { name = f, kids = by[f] } end
  local seq, made = {}, 0
  local function emit(node)
    if node.tr then seq[#seq + 1] = { tr = node.tr, depth = 0 }; return end
    r.InsertTrackAtIndex(base, true)
    local ft = r.GetTrack(0, base)
    r.GetSetMediaTrackInfo_String(ft, "P_NAME", Prep.caps(node.name, "folder"), true)
    local c = Prep.folder_color(node.name)
    if c and Prep.color_on() then r.SetMediaTrackInfo_Value(ft, "I_CUSTOMCOLOR", native(c)) end
    local chain = pr and pr.fx and pr.fx[node.name]
    if chain and r.file_exists(chain) and Prep.add_chain(ft, chain) then R.chains = R.chains + 1 end
    R.created[#R.created + 1] = ft
    R.folder_tracks[node.name] = ft
    if node.name == CFG.OTHER and S.other_off then r.SetMediaTrackInfo_Value(ft, "B_MAINSEND", 0) end
    made = made + 1
    seq[#seq + 1] = { tr = ft, depth = 1, folder = true }
    for _, kid in ipairs(node.kids) do emit(kid) end
    seq[#seq].depth = seq[#seq].depth - 1 -- (the last track closes this folder)
  end
  for _, node in ipairs(top) do emit(node) end
  for k, it in ipairs(seq) do -- each track to its place, from the top (the ones above are already placed)
    r.SetOnlyTrackSelected(it.tr)
    r.ReorderSelectedTracks(base + k - 1, 0)
  end
  -- the depths, then the spacers (after the moves: a move can take a spacer along): above each folder track, but
  -- not the first one and not right below its parent folder track
  for k, it in ipairs(seq) do
    r.SetMediaTrackInfo_Value(it.tr, "I_FOLDERDEPTH", it.depth)
    if it.folder then
      local below_parent = k > 1 and seq[k - 1].folder
      r.SetMediaTrackInfo_Value(it.tr, "I_SPACER", (S.spacer and k > 1 and not below_parent) and 1 or 0)
    end
  end
  return made
end

-- After a prep: a new track (an overdub) joins the folder of its rule that Session Prep made before (at its end).
function Prep.join_folders(rows)
  for _, row in ipairs(rows) do
    local tr = row.t.tr
    local ft = row.on and row.folder ~= "" and Prep.find_track(Prep.caps(row.folder, "folder"))
    if ft and r.ValidatePtr2(0, tr, "MediaTrack*") and r.GetParentTrack(tr) ~= ft and Prep.move_into(ft, tr) then
      R.folder_tracks[row.folder] = ft
      R.joined = R.joined + 1
    end
  end
end
-- Moves a track to the end of a folder track's folder. Returns true when done (ft is a folder track).
function Prep.move_into(ft, tr)
  if r.GetMediaTrackInfo_Value(ft, "I_FOLDERDEPTH") ~= 1 then return false end
  local fi = math.floor(r.GetMediaTrackInfo_Value(ft, "IP_TRACKNUMBER")) - 1
  local level, last = 1, fi
  for j = fi + 1, r.CountTracks(0) - 1 do -- (the last track of the folder: where the depth sum ends)
    last = j
    level = level + r.GetMediaTrackInfo_Value(r.GetTrack(0, j), "I_FOLDERDEPTH")
    if level <= 0 then break end
  end
  local nxt = r.GetTrack(0, last + 1) -- (the track after the folder: its spacer must stay with it)
  local nxt_sp = nxt and nxt ~= tr and r.GetMediaTrackInfo_Value(nxt, "I_SPACER") or 0
  r.SetOnlyTrackSelected(tr)
  r.ReorderSelectedTracks(last + 1, 2) -- (2: after the last track of a folder = into that folder)
  -- (a move can take the spacer along: the moved track gets none, the next track gets its own back)
  r.SetMediaTrackInfo_Value(tr, "I_SPACER", 0)
  if nxt and nxt ~= tr and r.ValidatePtr2(0, nxt, "MediaTrack*") then r.SetMediaTrackInfo_Value(nxt, "I_SPACER", nxt_sp) end
  return true
end

-- A post-fader send from src to d at level (linear), when there is none yet (found in d's AUXRECV lines: the
-- source track index from 0; P_DESTTRACK gives a number, not the track). R.recv caches the lines during Apply.
-- Returns true when a new send was made.
function Prep.send(src, d, level)
  local rc = R.recv[d]
  if not rc then
    rc = {}
    local ok, chunk = r.GetTrackStateChunk(d, "", false)
    if ok then for idx in chunk:gmatch("\nAUXRECV (%d+) ") do rc[tonumber(idx)] = true end end
    R.recv[d] = rc
  end
  local si = math.floor(r.GetMediaTrackInfo_Value(src, "IP_TRACKNUMBER")) - 1
  if rc[si] then return false end
  local i = r.CreateTrackSend(src, d)
  if i < 0 then return false end
  r.SetTrackSendInfo_Value(src, 0, i, "D_VOL", level)
  r.SetTrackSendInfo_Value(src, 0, i, "I_SENDMODE", 0) -- post-fader
  rc[si] = true
  return true
end

-- A track that Session Prep made before (it has the prep mark), by its name in any case ("Instrument Bus" =
-- "INSTRUMENT BUS"; nil: none). A client's own track with that name is never used.
function Prep.find_track(name)
  local up = name:upper()
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local _, n = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if n:upper() == up then
      local _, mark = r.GetSetMediaTrackInfo_String(tr, CFG.PREP_KEY, "", false)
      if mark ~= "" then return tr end
    end
  end
end

-- Capital letters (Settings > Appearance): kind = "track", "folder" or "bus" (buses and returns).
function Prep.caps(name, kind)
  local c = S.caps
  if c == "all" or (c == "fb" and kind ~= "track") or (c == "buses" and kind == "bus") then return name:upper() end
  return name
end

-- The buses of the preset that are on (Buses tab): a bus track each at the end of the project (a bus that Session
-- Prep made before is used again). Its members send to it at 0 dB, post-fader, and their own output to the parent / master is
-- turned off: the bus controls them. A folder member: the folder track (when Apply made the folders), else its
-- tracks. A track member (a rule name): its tracks (they stay in their folder). Returns the number of new buses.
function Prep.make_buses(rows)
  local pr = Rules.cur()
  local made, first = 0, true
  local claimed = {} -- the tracks of a track member (they do not go to a bus through their folder)
  for _, b in ipairs(pr and pr.buses or {}) do
    if b.on then
      for _, mb in ipairs(b.members) do
        if mb.kind == "t" then
          for _, row in ipairs(rows) do if row.rname == mb.name then claimed[row] = true end end
        end
      end
    end
  end
  for _, b in ipairs(pr and pr.buses or {}) do
    if b.on then
      local srcs, seen = {}, {}
      local function add(tr) if tr and not seen[tr] then seen[tr] = true; srcs[#srcs + 1] = tr end end
      for _, mb in ipairs(b.members) do
        for _, row in ipairs(rows) do
          if row.on and r.ValidatePtr2(0, row.t.tr, "MediaTrack*") then
            if mb.kind == "t" and row.rname == mb.name then add(row.t.tr)
            elseif mb.kind == "f" and row.folder == mb.name and not claimed[row] then
              add(R.folder_tracks[mb.name] or row.t.tr)
            end
          end
        end
      end
      if #srcs > 0 then
        local bt = Prep.find_track(b.name)
        if not bt then
          local n0 = r.CountTracks(0)
          r.InsertTrackAtIndex(n0, true)
          bt = r.GetTrack(0, n0)
          r.GetSetMediaTrackInfo_String(bt, "P_NAME", Prep.caps(b.name, "bus"), true)
          if S.spacer and first then r.SetMediaTrackInfo_Value(bt, "I_SPACER", 1) end
          if b.color and Prep.color_on() then r.SetMediaTrackInfo_Value(bt, "I_CUSTOMCOLOR", native(b.color)) end
          local chain = pr.fx and pr.fx[b.name]
          if chain and r.file_exists(chain) and Prep.add_chain(bt, chain) then R.chains = R.chains + 1 end
          R.created[#R.created + 1] = bt
          made = made + 1
        end
        first = false
        for _, src in ipairs(srcs) do
          if src ~= bt then
            Prep.send(src, bt, 1)
            r.SetMediaTrackInfo_Value(src, "B_MAINSEND", 0) -- (only through the bus)
          end
        end
      end
    end
  end
  return made
end

-- The FX returns of the preset (a return that Session Prep made before is used again; new ones go to the end, in
-- an "FX Returns" folder when Folders is on) and the sends of the ticked rows to them (post-fader, the preset's
-- send level; a send that is already there is not made again). Returns the number of new returns and new sends.
function Prep.make_returns(rows)
  local p = Rules.cur()
  if not p or not p.returns or #p.returns == 0 then return 0, 0 end
  local dest, new = {}, {}
  for _, rt in ipairs(p.returns) do
    local tr = Prep.find_track(rt.name) -- (only a return that Session Prep made before)
    if tr then dest[rt.name] = tr else new[#new + 1] = rt end
  end
  local rfold = S.folders and #new > 0 and Prep.find_track(Prep.caps(CFG.RETURNS_FOLDER, "bus")) or nil
  if #new > 0 then
    if S.folders and not rfold then -- (an FX Returns folder that is there: the new returns join it, below)
      local n0 = r.CountTracks(0)
      r.InsertTrackAtIndex(n0, true)
      local ft = r.GetTrack(0, n0)
      r.GetSetMediaTrackInfo_String(ft, "P_NAME", Prep.caps(CFG.RETURNS_FOLDER, "bus"), true)
      R.created[#R.created + 1] = ft
      r.SetMediaTrackInfo_Value(ft, "I_FOLDERDEPTH", 1)
      if S.spacer then r.SetMediaTrackInfo_Value(ft, "I_SPACER", 1) end
    end
    for k, rt in ipairs(new) do
      local n0 = r.CountTracks(0)
      r.InsertTrackAtIndex(n0, true)
      local tr = r.GetTrack(0, n0)
      r.GetSetMediaTrackInfo_String(tr, "P_NAME", Prep.caps(rt.name, "bus"), true)
      if rt.color and Prep.color_on() then r.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", native(rt.color)) end
      if S.folders and not rfold and k == #new then r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", -1) end
      if rt.chain ~= "" and r.file_exists(rt.chain) and Prep.add_chain(tr, rt.chain) then R.chains = R.chains + 1 end
      if rfold then Prep.move_into(rfold, tr) end
      dest[rt.name] = tr
      R.created[#R.created + 1] = tr
    end
  end
  local sends = 0
  local ftr_cache = {}
  local function folder_tr(f) -- (each folder track found once)
    if ftr_cache[f] == nil then ftr_cache[f] = R.folder_tracks[f] or Prep.find_track(Prep.caps(f, "folder")) or false end
    return ftr_cache[f] or nil
  end
  for _, rt in ipairs(p.returns) do
    local d = dest[rt.name]
    if d then
      local level = 10 ^ ((rt.db or -12) / 20)
      local out = rt.out or "m"
      for _, row in ipairs(rows) do
        local set = row.on and row.folder ~= "" and p.sends and p.sends[row.folder]
        if set and set[rt.name] and r.ValidatePtr2(0, row.t.tr, "MediaTrack*") then
          local src = row.t.tr
          local ftr = folder_tr(row.folder)
          if rt.src == "f" and ftr then src = ftr end -- (the folder track sends: 1 send for the folder)
          if src == ftr and out == "f:" .. row.folder then
            R.loops = R.loops + 1 -- (the folder would feed its own return: a feedback loop; no send)
          elseif src ~= d and Prep.send(src, d, level) then sends = sends + 1 end
        end
      end
      -- the output of the return: the master, or a send into a folder or bus track (its master output off)
      local target
      if out:sub(1, 2) == "f:" then
        target = folder_tr(out:sub(3))
      elseif out:sub(1, 2) == "b:" then
        target = Prep.find_track(out:sub(3))
      end
      if target and target ~= d then
        Prep.send(d, target, 1)
        r.SetMediaTrackInfo_Value(d, "B_MAINSEND", 0)
      end
    end
  end
  return #new, sends
end

-- Apply: the ticked rows get their new name, color and pan (L / R); the ticked fixes; then the folders.
-- 1 undo point. Returns the text of the notice.
function Prep.apply(rows)
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  local ok, res = pcall(Prep.apply_rows, rows)
  r.PreventUIRefresh(-1)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
  r.Undo_EndBlock("Session Prep: apply", -1)
  if not ok then return "Apply stopped by an error (Ctrl+Z undoes the part that was done): " .. tostring(res) end
  return res
end
function Prep.apply_rows(rows)
  local renamed, colored, panned, fixed, gained = 0, 0, 0, 0, 0
  R.chains, R.created, R.sws_off, R.folder_tracks, R.recv, R.flipped, R.joined, R.loops = 0, {}, false, {}, {}, 0, 0, 0
  if S.color and S.color_win and Prep.sws_autocolor() then -- (Colors win over SWS: SWS Auto Color off first)
    r.Main_OnCommand(r.NamedCommandLookup("_SWSAUTOCOLOR_ENABLE"), 0)
    R.sws_off = not Prep.sws_autocolor()
  end
  for _, row in ipairs(rows) do
    local tr = row.t.tr
    if r.ValidatePtr2(0, tr, "MediaTrack*") then
      if row.on then
        local new = Util.clean(row.new)
        if new ~= "" and new ~= row.old then r.GetSetMediaTrackInfo_String(tr, "P_NAME", new, true); renamed = renamed + 1 end
        if row.color and Prep.color_on() then r.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", native(row.color)); colored = colored + 1 end
        local tchain = row.rname and Rules.cur().tfx and Rules.cur().tfx[row.rname]
        if tchain and r.file_exists(tchain) and r.TrackFX_GetCount(tr) == 0 and Prep.add_chain(tr, tchain) then
          R.chains = R.chains + 1 -- (Track FX: only on a track without FX, so a 2nd Apply does not add it again)
        end
        if row.pol then r.SetMediaTrackInfo_Value(tr, "B_PHASE", 1); R.flipped = R.flipped + 1 end
        if S.disarm then -- (a client's session: no armed track, no input monitoring in the mix)
          r.SetMediaTrackInfo_Value(tr, "I_RECARM", 0)
          r.SetMediaTrackInfo_Value(tr, "I_RECMON", 0)
        end
        if row.pan then
          local w = S.pan_w_on and Util.clamp(row.width or 100, 10, 100) / 100 or 1 -- (Pan width: off = hard L / R)
          local pan = row.pan == "L" and -w or (row.pan == "R" and w or 0)
          r.SetMediaTrackInfo_Value(tr, "D_PAN", pan)
          -- (dual pan mode, also as the project default, uses its own 2 knobs: L / R both to that side;
          -- C: the full width, left knob left and right knob right)
          r.SetMediaTrackInfo_Value(tr, "D_DUALPANL", pan ~= 0 and pan or -1)
          r.SetMediaTrackInfo_Value(tr, "D_DUALPANR", pan ~= 0 and pan or 1)
          panned = panned + 1
        end
      end
      if row.on and S.gain and row.gain and math.abs(row.gain) >= 0.05 then -- the item (clip) gain of every item
        local f = 10 ^ (row.gain / 20)
        for i = 0, r.CountTrackMediaItems(tr) - 1 do
          local it = r.GetTrackMediaItem(tr, i)
          r.SetMediaItemInfo_Value(it, "D_VOL", r.GetMediaItemInfo_Value(it, "D_VOL") * f)
        end
        gained = gained + 1
      end
      if row.fix and row.fix_on and row.fix ~= "delete" then -- (Delete: at the end of Apply)
        local mode = row.fix == "mono R" and 4 or 3 -- the take channel mode (3 = left, 4 = right; fake stereo: left)
        for i = 0, r.CountTrackMediaItems(tr) - 1 do
          local tk = r.GetActiveTake(r.GetTrackMediaItem(tr, i))
          if tk then r.SetMediaItemTakeInfo_Value(tk, "I_CHANMODE", mode) end
        end
        fixed = fixed + 1
      end
    end
  end
  local folders = 0
  -- (new tracks in a prepped project stay where they are: no 2nd set of folders)
  if S.folders and R.scan and R.scan.folders_ok and (R.scan.skipped or 0) == 0 then folders = Prep.make_folders(rows)
  elseif S.folders and R.scan and (R.scan.skipped or 0) > 0 then Prep.join_folders(rows) end
  if S.other_off and not R.folder_tracks[CFG.OTHER] then -- (no Other folder track: its tracks themselves)
    for _, row in ipairs(rows) do
      if row.on and row.folder == CFG.OTHER and r.ValidatePtr2(0, row.t.tr, "MediaTrack*") and not r.GetParentTrack(row.t.tr) then
        r.SetMediaTrackInfo_Value(row.t.tr, "B_MAINSEND", 0)
      end
    end
  end
  local buses, made, sends = 0, 0, 0
  buses = Prep.make_buses(rows) -- (before the returns: the returns stay at the bottom)
  if S.returns then made, sends = Prep.make_returns(rows) end
  -- the prepped tracks: the ticked rows and the new tracks (left out of the next Scan)
  local date = os.date("%Y-%m-%d")
  for _, row in ipairs(rows) do
    if row.on and r.ValidatePtr2(0, row.t.tr, "MediaTrack*") then r.GetSetMediaTrackInfo_String(row.t.tr, CFG.PREP_KEY, date, true) end
  end
  for _, tr in ipairs(R.created) do
    if r.ValidatePtr2(0, tr, "MediaTrack*") then r.GetSetMediaTrackInfo_String(tr, CFG.PREP_KEY, date, true) end
  end
  -- the empty tracks with Delete on (last: the other steps used their places)
  local deleted = 0
  for _, row in ipairs(rows) do
    if row.fix == "delete" and row.fix_on and r.ValidatePtr2(0, row.t.tr, "MediaTrack*") then
      r.DeleteTrack(row.t.tr); deleted = deleted + 1
    end
  end
  R.deleted = deleted
  r.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
  for _, row in ipairs(rows) do
    if r.ValidatePtr2(0, row.t.tr, "MediaTrack*") then r.SetTrackSelected(row.t.tr, true) end
  end
  local t = {}
  if renamed > 0 then t[#t + 1] = renamed .. " renamed" end
  if colored > 0 then t[#t + 1] = colored .. " colored" end
  if folders > 0 then t[#t + 1] = folders .. (folders == 1 and " folder" or " folders") end
  if R.chains > 0 then t[#t + 1] = R.chains .. (R.chains == 1 and " FX chain" or " FX chains") end
  if panned > 0 then t[#t + 1] = panned .. " panned" end
  if gained > 0 then t[#t + 1] = gained .. " gain staged" end
  if buses > 0 then t[#t + 1] = buses .. (buses == 1 and " bus" or " buses") end
  if made > 0 then t[#t + 1] = made .. (made == 1 and " return" or " returns") end
  if sends > 0 then t[#t + 1] = sends .. (sends == 1 and " send" or " sends") end
  if R.sws_off then t[#t + 1] = "SWS Auto Color turned off" end
  if R.flipped > 0 then t[#t + 1] = R.flipped .. " polarity flipped" end
  if (R.deleted or 0) > 0 then t[#t + 1] = R.deleted .. " empty deleted" end
  if R.joined > 0 then t[#t + 1] = R.joined .. " joined their folder" end
  if R.loops > 0 then t[#t + 1] = R.loops .. " send skipped (a return into its own source folder would loop)" end
  if fixed > 0 then t[#t + 1] = fixed .. " fixed" end
  if #t == 0 then return "Nothing to change." end
  return "Done: " .. table.concat(t, ", ") .. ". Ctrl+Z undoes it."
end

---------------------------------------------------------------------------
-- AUDIO (the check of Scan: silent, fake stereo, one side silent)
---------------------------------------------------------------------------
-- Returns the verdict ("empty", "silent", "fake", "only_l", "only_r" or nil: normal or MIDI), the average level
-- (RMS, linear; only the reads that are not a pause) and the peak (linear; nil: no audio).
function Audio.check(tr)
  local n = r.CountTrackMediaItems(tr)
  if n == 0 then return "empty" end
  local stereo = true
  for i = 0, n - 1 do
    local tk = r.GetActiveTake(r.GetTrackMediaItem(tr, i))
    if not tk or r.TakeIsMIDI(tk) then return nil end
    local src = r.GetMediaItemTake_Source(tk)
    if r.GetMediaSourceNumChannels(src) ~= 2 or r.GetMediaItemTakeInfo_Value(tk, "I_CHANMODE") ~= 0 then stereo = false end
  end
  local acc = r.CreateTrackAudioAccessor(tr)
  if not acc then return nil end
  local t0, t1 = r.GetAudioAccessorStartTime(acc), r.GetAudioAccessorEndTime(acc)
  local SR, N = CFG.AUDIO_SR, CFG.AUDIO_BLOCK
  local buf = r.new_array(N * 2)
  local step = math.max(N / SR, (t1 - t0) / CFG.AUDIO_MAX_BLOCKS)
  local pl, pr, diff = 0, 0, 0
  local ms_l, ms_r, ms_n = 0, 0, 0
  local abs = math.abs
  local gate = CFG.GATE * CFG.GATE
  local t = t0
  while t < t1 do
    buf.clear()
    if r.GetAudioAccessorSamples(acc, SR, 2, t, N, buf) == 1 then
      local a = buf.table()
      local sql, sqr = 0, 0
      for k = 1, N * 2, 2 do
        local x, y = a[k], a[k + 1]
        local L, Rv = abs(x), abs(y)
        if L > pl then pl = L end
        if Rv > pr then pr = Rv end
        local d = abs(x - y)
        if d > diff then diff = d end
        sql, sqr = sql + x * x, sqr + y * y
      end
      if (sql + sqr) * 0.5 / N > gate then ms_l, ms_r, ms_n = ms_l + sql / N, ms_r + sqr / N, ms_n + 1 end
    end
    t = t + step
  end
  r.DestroyAudioAccessor(acc)
  local verdict = Audio.verdict(pl, pr, diff, stereo)
  return verdict, Audio.rms(ms_l, ms_r, ms_n, verdict), math.max(pl, pr)
end
-- The average level (RMS) from the sums of the reads of L and R: both sides, or only the live side of a one-sided
-- file (with the silent side in it, the level would be 3 dB low, and the gain 3 dB too high after Mono).
function Audio.rms(ms_l, ms_r, n, verdict)
  if n <= 0 then return nil end
  if verdict == "only_l" then return math.sqrt(ms_l / n) end
  if verdict == "only_r" then return math.sqrt(ms_r / n) end
  return math.sqrt((ms_l + ms_r) * 0.5 / n)
end
-- The verdict from the peaks of L and R and the largest L - R difference (the tests call it directly).
function Audio.verdict(pl, pr, diff, stereo)
  local peak = math.max(pl, pr)
  if peak < CFG.SILENT then return "silent" end
  if not stereo then return nil end
  if diff <= peak * CFG.FAKE_DIFF then return "fake" end
  if pr < CFG.SILENT then return "only_l" end
  if pl < CFG.SILENT then return "only_r" end
  return nil
end

---------------------------------------------------------------------------
-- SETTINGS of this computer: load, save
---------------------------------------------------------------------------
local S_KEYS = { "light", "dock", "tab", "preset", "folders", "pairs", "audio", "color", "spacer", "returns", "closed",
  "other_off", "disarm", "pan_w_on",
  "caps", "color_win", "settings_open",
  "gain", "gain_rms", "gain_peak", "gain_by_peak", "gain_ptarget" }
local S_BOOL = { light = true, folders = true, pairs = true, audio = true, gain = true, gain_by_peak = true,
  color = true, spacer = true, returns = true, color_win = true, other_off = true, disarm = true, pan_w_on = true }
local S_STR = { caps = { all = true, fb = true, buses = true, none = true } } -- (a text setting: its valid values)
local S_FLOAT = { gain_rms = true, gain_peak = true, gain_ptarget = true }
local S_DEFAULTS = { light = false, dock = 0, tab = 1, preset = 1, folders = true, pairs = true, audio = true,
  color = false, spacer = true, returns = false, caps = "all", color_win = false, settings_open = 2, other_off = true, disarm = true, pan_w_on = false,
  gain = false, gain_rms = -18, gain_peak = -6, gain_by_peak = false, gain_ptarget = -10 }
-- The folded sections: S.closed (id -> true) is saved as "id,id" in the key "closed".
local function closed_text()
  local t = {}
  for id in pairs(S.closed) do t[#t + 1] = id end
  table.sort(t)
  return table.concat(t, ",")
end
function Util.load_settings()
  for k, v in pairs(S_DEFAULTS) do S[k] = v end
  S.closed = {}
  for _, k in ipairs(S_KEYS) do
    local v = r.GetExtState(CFG.EXT, k)
    if v ~= "" then
      if k == "closed" then
        for id in v:gmatch("[%w_]+") do S.closed[id] = true end
      elseif S_STR[k] then S[k] = S_STR[k][v] and v or S_DEFAULTS[k]
      elseif S_BOOL[k] then S[k] = (v == "1")
      elseif S_FLOAT[k] then S[k] = tonumber(v) or S_DEFAULTS[k]
      else S[k] = math.floor(tonumber(v) or 0) end
    end
  end
  S.presets = {}
  local n = math.floor(tonumber(r.GetExtState(CFG.EXT, "presets_n")) or 0)
  for i = 1, n do
    local p = Rules.parse(r.GetExtState(CFG.EXT, "preset_" .. i))
    if p then
      local o = r.GetExtState(CFG.EXT, "preset_orig_" .. i)
      p.orig = o ~= "" and o or Rules.builtin_orig(p.name)
      local sv = r.GetExtState(CFG.EXT, "preset_saved_" .. i)
      p.saved = sv ~= "" and sv or Rules.serialize(p)
      Rules.update_dirty(p)
      S.presets[#S.presets + 1] = p
    end
  end
  if #S.presets == 0 then S.presets = Rules.default_presets() end
  R.snap, R.hist, R.hist_t = Rules.snapshot(), {}, {}
  S.preset = Util.clamp(S.preset, 1, #S.presets)
  S.tab = Util.clamp(S.tab, 1, 6)
  S.gain_rms = Util.clamp(S.gain_rms, -40, -6)
  S.gain_peak = Util.clamp(S.gain_peak, -24, 0)
  S.gain_ptarget = Util.clamp(S.gain_ptarget, -30, 0)
  R.dock_req = S.dock -- the window opens where it was (floating or in its docker)
end
-- Saves only what differs from the default (the presets: only when they are not the built-in ones).
function Util.save_settings()
  for _, k in ipairs(S_KEYS) do
    if k == "closed" then -- (a table, saved as text; no entry in S_DEFAULTS)
      local txt = closed_text()
      if txt == "" then r.DeleteExtState(CFG.EXT, k, true) else r.SetExtState(CFG.EXT, k, txt, true) end
    else
      local v, d = S[k], S_DEFAULTS[k]
      if v == d then r.DeleteExtState(CFG.EXT, k, true)
      else r.SetExtState(CFG.EXT, k, S_BOOL[k] and (v and "1" or "0") or tostring(v), true) end
    end
  end
  local old_n = math.floor(tonumber(r.GetExtState(CFG.EXT, "presets_n")) or 0)
  local def = Rules.default_presets()
  local same = #S.presets == #def
  for i = 1, #def do
    same = same and S.presets[i] and not S.presets[i].dirty and Rules.serialize(S.presets[i]) == Rules.serialize(def[i])
  end
  local n = same and 0 or #S.presets
  for i = 1, n do
    local pr = S.presets[i]
    r.SetExtState(CFG.EXT, "preset_" .. i, Rules.serialize(pr), true)
    if pr.orig and pr.orig ~= Rules.builtin_orig(pr.name) then r.SetExtState(CFG.EXT, "preset_orig_" .. i, pr.orig, true)
    else r.DeleteExtState(CFG.EXT, "preset_orig_" .. i, true) end
    if pr.dirty and pr.saved then r.SetExtState(CFG.EXT, "preset_saved_" .. i, pr.saved, true)
    else r.DeleteExtState(CFG.EXT, "preset_saved_" .. i, true) end
  end
  for i = n + 1, math.max(old_n, n) do
    r.DeleteExtState(CFG.EXT, "preset_" .. i, true)
    r.DeleteExtState(CFG.EXT, "preset_orig_" .. i, true)
    r.DeleteExtState(CFG.EXT, "preset_saved_" .. i, true)
  end
  if n > 0 then r.SetExtState(CFG.EXT, "presets_n", tostring(n), true) else r.DeleteExtState(CFG.EXT, "presets_n", true) end
  R.sdirty = false
end

---------------------------------------------------------------------------
-- TESTS: tests/sessionprep.lua sets SessionPrepTest: hand it the modules and do not start the UI
---------------------------------------------------------------------------
if TESTING then
  local test = rawget(_G, "SessionPrepTest")
  test.CFG, test.S, test.R, test.Util, test.Rules, test.Prep, test.Audio = CFG, S, R, Util, Rules, Prep, Audio
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

local TAB_NAMES = { "Prep", "Rules", "FX Chains", "Buses" } -- then Settings (gear) and Help ("?")
local TAB_PREP, TAB_RULES, TAB_FX, TAB_BUSES, TAB_SETTINGS, TAB_HELP = 1, 2, 3, 4, 5, 6
local PAN_NEXT = { L = "C", C = "R", R = nil, ["-"] = "L" } -- the Pan button: L -> C -> R -> - -> L
-- (a title: text, or { text, "c" } centered over its column, or { text, px } moved right: over the field's text)
-- (the 4 title rows: with or without Gain, with or without Width)
local HEAD = {}
for _, g in ipairs({ false, true }) do
  for _, w in ipairs({ false, true }) do
    local t = { "", "Old name", { "New name", 28 }, "Folder", "Notes" }
    if g then t[#t + 1] = { "Gain", "c" } end
    t[#t + 1] = { "\u{00D8}", "c" }
    t[#t + 1] = { "Pan", "c" }
    if w then t[#t + 1] = { "Width", "c" } end
    t[#t + 1] = { "M", "c" }
    t[#t + 1] = { "S", "c" }
    HEAD[(g and 2 or 0) + (w and 1 or 0)] = t
  end
end
local SETTINGS_SECTIONS -- (filled after the Settings functions)

local HELP_INTRO = "Session Prep cleans up the tracks of a multitrack that you got from a client: names, colors, "
  .. "folders, L / R pans and silent or fake stereo tracks. You see everything first; nothing changes until you click Apply."
local HELP_TOPICS = {
  { title = "Getting started", text = [[
1. Import the multitrack (or open the client's project).
2. Select the tracks that you want to clean up. Select none (or click "Scan all") to do all the tracks.
3. Prep tab: pick a preset and click Scan. The table shows the old name, the new name, the folder and notes. Nothing has changed yet.
4. Untick the rows that you want to leave alone. Click a new name to change it.
5. Click Apply. One Ctrl+Z undoes all of it.]] },
  { title = "How the names work", text = [[
Each rule has match words, for example "kik, kick, bd". The first rule (from the top) that matches a track wins.

Short words (3 letters or less, like "sn" or "oh") match only a whole word. Longer words also match inside a word: "kick" finds "SubKick".

Words like In, Out, Top, Btm, L, R, DI and numbers stay: "Audio 3_Kik in" becomes "Kick In".

Two tracks with the same new name get a number: "Gtr 1", "Gtr 2".

"Trim prefix / suffix" (Rules tab): when all the names start or end the same way ("MySong_Kick", "MySong_Snare"), that part goes. "Audio 1_", track numbers and ".wav" always go.]] },
  { title = "Folders, pans and checks", text = [[
Folders: the tracks of each folder go together in a new folder track, in the order of the rules, where the first scanned track was. The folder gets the color of its first rule. When the tracks are already in folders, Session Prep leaves the folders alone.

Pan: the Pan button of a row. A track with L or R in its name ("OH L", "Gtr 1 R") starts at L or R, the others at "-". L / R are hard left / right; with Settings > Prep > Pan width on (off by default), the Width column sets each track's width. A track that is already panned (a client's project) starts at "-" and keeps its pan: Notes says "kept pan". Click it to go to the next: L, C (center), R, - (leave the pan as it is). Apply sets it.

M and S: the track's own mute and solo, as in REAPER. They act at once (not at Apply): solo a track to listen to it while you prep.

Checks (Scan reads the audio):
- empty: no items. Click "Delete" (orange = on): Apply deletes the track (Ctrl+Z brings it back).
- silent: no audio. Use M to mute the track.
- fake stereo: both sides are the same. Click "Mono" (orange = on): Apply plays only the left side.
- only left side / only right side: one side is silent. "Mono" plays only the side with audio.
Mono changes only how the item plays (its channel mode), not the file.

Turn folders, the pans or the audio check off in the Settings tab.

Buses (Buses tab, each off by default): Instrument Bus (the instrument folders, drums too), Vocal Bus (Lead Vox, BV) and Lead Bus (Lead Gtr, Lead Synth). Apply makes a bus track at the bottom for each bus that is on; its members send to it (0 dB, post-fader) and their own output to the folder / master is turned off, so the bus fader controls them. Put FX on the buses in the FX Chains tab (Folder FX).

Spacer (Settings > Appearance): a small gap above each new folder. Colors (Settings > Appearance) are off by default; when SWS Auto Color is on, SWS colors the tracks (or turn on "Colors win over SWS").]] },
  { title = "FX, buses and returns", text = [[
The FX Chains tab (saved in the preset):
- Folder FX: an FX chain for each new folder track (for example your drum bus chain), and for each bus that is on.
- Track FX: an FX chain for each track name (Kick, Lead Vox...), added to tracks that have no FX yet.

The Buses tab (saved in the preset):
- Buses: Instrument Bus, Vocal Bus, Lead Bus. Each has a switch (off by default), a color and its members (+ Add: a folder or a track name; a member goes to 1 bus only).
- FX Returns: Room Verb, Hall Verb, Delay, Drum Crush, each with a color and an FX chain, and which folders send to them (post-fader). Off until you turn on "Make FX returns and sends".]] },
  { title = "Gain staging", text = [[
Off by default: turn it on in Settings > Gain staging.

Scan measures the average level (RMS) of each track, without the pauses. The Gain column shows the change that brings it to the target (default -18 dBFS RMS), never with a peak above the peak limit (default -6 dBFS). With -18 dBFS RMS, the peaks of most tracks are around -10 dBFS: that is normal.

Target: Peak (in Settings) brings the peak of every track to the target peak (default -10 dBFS) in place of the average.

Apply changes the item gain (clip gain) of the items on the track. The faders stay where they are, and Ctrl+Z undoes it.

Change one value: drag it, or double-click and type. 0 dB = no change for that track. Right-click: the measured value again.

The level is measured fast (parts of the audio at a low sample rate): the average is good, the peak is close but not exact (Session Prep keeps 1 dB more room under the peak limit). Item and take envelopes are not measured, and every item of the track gets the same gain: made for raw client files.]] },
  { title = "Rules and presets", text = [[
Rules tab: the rules are grouped by folder. Each line shows the name and the match words; click it to change its color, folder, name and match words (with commas). The color square of a folder colors all its rules. Drag the 3 lines of a folder header to move the folder (top to bottom = the order in the project).

The built-in presets use the names that most engineers use: Kick In / Out, Kick Sub, Snare Top / Btm, Hi-Hat, Tom, Floor Tom, OH, Room, Bass DI / Amp, Gtr, Ac Gtr, Piano, Organ, Synth, Keys, Lead Vox, BV...

Drag the 3 lines of a rule to change the order (the higher rule wins). "+ Rule" adds one to that folder; the x at the right of a rule deletes it.

The default folder order is the one most engineers use: drums first, then percussion, bass, guitars, keys, strings, brass, vocals, and the click / guide at the bottom. The preset "Vocals first" puts the vocals on top. The FX returns and buses always go to the bottom.

Your changes are kept, but they wait for Save: the preset name shows a dot and the disk icon turns blue; click the disk to save them. "Save as..." saves them as a new preset (the old one keeps its last saved version).
More...: Rename, Export (a file in REAPER's Data\Session Prep folder), Import; Revert to saved (back to the last Save), Reset to original (a built-in preset: its built-in settings; your own preset: as you made it), Delete preset. The red ones ask first. Export writes the preset to a file in REAPER's Data\Session Prep folder; Import reads one.]] },
  { title = "Where your stuff is saved", text = [[
In the project: only a mark on each prepped track, so a 2nd Scan leaves it out (Ctrl+Z of the Apply removes the mark).
On this computer: the presets (with their folder FX chains), the Light theme, the window dock and the Settings (also the gain staging targets).
Session Prep saves nothing in the project: Apply only changes the tracks (and Ctrl+Z undoes it).]] },
}
local HELP_PREP = [[Scan reads the selected tracks (or all tracks when none is selected) and shows what Apply will do. Nothing changes until you click Apply.

Tick: Apply changes this track. Click the old name: select the track in REAPER. Click the new name to change it.
Notes: what the audio check found ("Mono": a fix that Apply makes; orange = on).
Pan: click to go L, C, R, - (- = leave it). M / S: the track's mute and solo, at once (as in REAPER).
Gain (Settings > Gain staging on): the item gain that Apply adds; drag or type; 0 dB = no change.
Scan all: every track of the project, also when some are selected.
Keys: Enter = Apply; in the Rules tab, Delete removes the open rule; F2 renames the preset.]]
local HELP_TRACK_FX = [[An FX chain for each track name of the rules (Kick, Snare, Lead Vox...). Apply adds it to every track with that name, only when the track has no FX yet (a 2nd Apply does not add it again).

Make a chain: put the plugins on a track, then in its FX window: FX > Save chain.]]
local HELP_BUSES = [[Buses that control a group of tracks with 1 fader (and 1 FX chain: FX Chains tab > Folder FX):
- Instrument Bus: the music (the instrument folders, drums too).
- Vocal Bus: the vocals (Lead Vox, BV).
- Lead Bus: the lead instruments (Lead Gtr, Lead Synth).

Each bus is off by default: turn it on with its switch. + Add: a folder or a track name. A member goes to 1 bus only.
Click a bus name to rename it; its x deletes it (it asks first). "+ Bus" adds your own (for example a Drum Bus).

Apply makes a bus track at the bottom for each bus that is on (a track with the same name is used again). Its members send to it at 0 dB, post-fader, and their own output to the folder / master is turned off. A track member stays in its folder.]]
local HELP_RETURNS = [[Shared effects, as in most mix templates: a short reverb (Room Verb), a long reverb (Hall Verb), a Delay and a parallel drum compression (Drum Crush).

Make FX returns and sends (off by default): Apply makes the return tracks in an "FX Returns" folder at the bottom (a track with the same name is used again) and adds their FX chains.

Sends: tick which folders send to which return. Each return has its own routing (its 2nd line):
- Source: Tracks (every ticked track sends) or Folder (the folder track sends once).
- Level: the send level (post-fader); a parallel compressor usually gets 0 dB.
- Out: the master, or into a folder or a bus, so the return follows that fader (Drum Crush goes into the drum folder by default). A return into the folder that feeds it with Source Folder would loop: Apply skips that send.
A send that is already there is not made again.

Everything here is saved in the preset.]]
local HELP_FOLDER_FX = [[An FX chain for each folder. When Apply makes a folder track (for example Drums), it adds this FX chain to it.

Make a chain in REAPER: put the plugins on a track, then in its FX window: FX > Save chain (REAPER's FXChains folder). From one of your track templates: insert it, open its FX window, FX > Save chain.

The FX chains are saved in the preset.]]
local HELP_RULES = [[The first rule from the top that matches a track name wins.

The rules are grouped by folder. Click a rule to change it: Color, Folder (empty: no folder), Name (the new track name), Match (words with commas, "kik, kick, bd"; 3 letters or less match only a whole word).

Drag the 3 lines of a rule to change the rule order, or of a folder header to move the folder. The x at the right deletes a rule. Your changes wait for Save (the disk icon in Preset).]]

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
-- A tooltip from a format and its values: the text is built only while the mouse is on the item.
function UI.tipf(fmt, ...)
  if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, string.format(fmt, ...)) end
end
-- UI.trunc, kept per text until the width changes (the rows of the tables: not cut again every frame).
function UI.trunc_c(text, w)
  R.tc = R.tc or {}
  local e = R.tc[text]
  if e and e.w == w then return e.s end
  local cut = UI.trunc(text, w)
  R.tc[text] = { w = w, s = cut }
  return cut
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
-- fold: the id of a section that folds (S.closed); an arrow before the title opens / closes it. Returns open.
function UI.heading(text, help, id, fold)
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local full = math.max(60, ImGui.GetContentRegionAvail(ctx) - 4)
  local fh = ImGui.GetFrameHeight(ctx)
  local open = true
  ImGui.PushFont(ctx, head_font)
  local maxw = math.max(30, full - (help and CFG.HELP_ICON + 8 or 0) - (fold and 16 or 0) - 8)
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
    if clicked then open = not open; S.closed[fold] = (not open) or nil; Util.mark_sdirty() end
  else
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, COL.HEADING, UI.trunc(text, maxw))
  end
  ImGui.PopFont(ctx)
  local _, ty = ImGui.GetItemRectMax(ctx)
  R.head_x1, R.head_y = sx + full - (help and CFG.HELP_ICON + 8 or 0), sy
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
-- The Undo button on the line of the last heading (left of its "?"): undoes the last change of its section only
-- (Rules.undo: "rules", "buses" or "returns").
UI.UNDO_WHAT = { rules = "the rules and the folder order", buses = "the buses", returns = "the FX returns and sends" }
function UI.undo_button(id, section)
  local cx0, cy0 = ImGui.GetCursorScreenPos(ctx)
  local fh = ImGui.GetFrameHeight(ctx)
  local w = 26
  local n = Rules.undo_count(section)
  ImGui.SetCursorScreenPos(ctx, R.head_x1 - w, R.head_y)
  if ImGui.InvisibleButton(ctx, id, w, fh) and n > 0 then Rules.undo(section) end
  local hov = ImGui.IsItemHovered(ctx)
  if hov then
    if n > 0 then UI.tipf("Undo the last change of %s (%d %s).", UI.UNDO_WHAT[section], n, n == 1 and "step" or "steps")
    else UI.tipf("Nothing to undo in %s.", UI.UNDO_WHAT[section]) end
    if n > 0 then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  end
  local x, y = ImGui.GetItemRectMin(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  if hov and n > 0 then ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + fh, COL.BTN_HOVER, 6) end
  local col = n > 0 and (hov and COL.TEXT_BRIGHT or COL.TEXT_MAIN) or COL.TOGGLE_OFF
  local cx, cy, rad = x + w / 2 + 1, y + fh / 2 + 1, 5.5 -- a curved arrow to the left
  ImGui.DrawList_PathArcTo(dl, cx, cy, rad, math.pi * 1.15, math.pi * 2.25)
  ImGui.DrawList_PathStroke(dl, col, 0, 1.6)
  local ax, ay = cx + rad * math.cos(math.pi * 1.15), cy + rad * math.sin(math.pi * 1.15)
  ImGui.DrawList_AddTriangleFilled(dl, ax - 4, ay + 1, ax + 3, ay - 3, ax + 2, ay + 4, col)
  ImGui.SetCursorScreenPos(ctx, cx0, cy0)
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
-- A question with 2 buttons (a popup in the window). Without a question: a notice at the bottom of the window.
function UI.ask(text, yes, fn)
  if not yes then UI.notice(text); return end
  R.ask = { text = text, yes = yes, fn = fn, open = true }
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
function UI.draw_ask()
  local a = R.ask
  if not a then return end
  if a.open then ImGui.OpenPopup(ctx, "Session Prep##ask"); a.open = false end
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)
  ImGui.SetNextWindowPos(ctx, wx + ww / 2, wy + wh / 2, ImGui.Cond_Appearing(), 0.5, 0.5)
  if ImGui.BeginPopupModal(ctx, "Session Prep##ask", nil, ImGui.WindowFlags_AlwaysAutoResize()) then
    ImGui.PushTextWrapPos(ctx, 360)
    ImGui.Text(ctx, a.text)
    ImGui.PopTextWrapPos(ctx)
    UI.vgap(8)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED)
    local yes = UI.button(a.yes, 120)
    ImGui.PopStyleColor(ctx)
    if yes then R.ask = nil; ImGui.CloseCurrentPopup(ctx); a.fn() end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    if UI.button("Cancel", 90) then R.ask = nil; ImGui.CloseCurrentPopup(ctx) end
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
-- The 3 lines of a drag handle, drawn on the last item.
function UI.draw_handle(col)
  local x1, y1 = ImGui.GetItemRectMin(ctx)
  local x2, y2 = ImGui.GetItemRectMax(ctx)
  local cx, cy = math.floor((x1 + x2) / 2), math.floor((y1 + y2) / 2)
  local dl = ImGui.GetWindowDrawList(ctx)
  for k = -1, 1 do ImGui.DrawList_AddLine(dl, cx - 6, cy + k * 4, cx + 6, cy + k * 4, col, 1.5) end
end
-- A color swatch of 0xRRGGBB at the cursor (nil: an empty ring).
function UI.swatch(c, size)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local fh = ImGui.GetFrameHeight(ctx)
  ImGui.Dummy(ctx, size, fh)
  local dl = ImGui.GetWindowDrawList(ctx)
  local top = y + math.floor((fh - size) / 2)
  if c then ImGui.DrawList_AddRectFilled(dl, x, top, x + size, top + size, (c << 8) | 0xFF, 3)
  else ImGui.DrawList_AddRect(dl, x, top, x + size, top + size, COL.TOGGLE_OFF, 3) end
end

UI.ADD = "+ Add" -- (the "+ Add" template of the 4 scripts: a ghost button that opens a menu)

-- The titles of a table as plain text (TableHeadersRow makes them clickable).
function UI.plain_headers(names)
  ImGui.TableNextRow(ctx, ImGui.TableRowFlags_Headers())
  for _, n in ipairs(names) do
    ImGui.TableNextColumn(ctx)
    local text, how = n, nil
    if type(n) == "table" then text, how = n[1], n[2] end
    if how == "c" then
      ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, (ImGui.GetContentRegionAvail(ctx) - (ImGui.CalcTextSize(ctx, text))) / 2))
    elseif how then
      ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + how)
    end
    ImGui.TextColored(ctx, COL.TEXT_DIM, text)
  end
end

-- A short note tag (orange: look at this; dim: information) with its full text as a tooltip.
function UI.tag(text, tip, dim)
  local fh = ImGui.GetFrameHeight(ctx)
  local tw = ImGui.CalcTextSize(ctx, text)
  local w = tw + 12
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##tag", w, fh)
  local dl = ImGui.GetWindowDrawList(ctx)
  local col = dim and COL.TEXT_DIM or COL.ORANGE
  ImGui.DrawList_AddRectFilled(dl, x, y + 4, x + w, y + fh - 4, dim and COL.ROW_HOVER or ((COL.ORANGE & ~0xFF) | 0x30), 4)
  ImGui.DrawList_AddText(dl, x + 6, UI.text_y(y), col, text)
  if tip then UI.tip(tip) end
end

-- A small button with a state, as REAPER's M / S: grey when off, filled with on_col (dark text) when on.
function UI.state_button(id, label, w, on, on_col)
  local fh = ImGui.GetFrameHeight(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local hit = ImGui.InvisibleButton(ctx, id, w, fh)
  local hov = ImGui.IsItemHovered(ctx)
  if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  local dl = ImGui.GetWindowDrawList(ctx)
  local bg = on and on_col or (hov and COL.BTN_HOVER or COL.BTN)
  ImGui.DrawList_AddRectFilled(dl, x, y + 2, x + w, y + fh - 2, bg, 5)
  if on and hov then ImGui.DrawList_AddRectFilled(dl, x, y + 2, x + w, y + fh - 2, 0xFFFFFF22, 5) end
  local tw = ImGui.CalcTextSize(ctx, label)
  ImGui.DrawList_AddText(dl, x + math.floor((w - tw) / 2), UI.text_y(y), on and 0x1E2127FF or COL.TEXT_MAIN, label)
  return hit
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
  tab(TAB_HELP, h, x, "Help: how Session Prep works")
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
  ImGui.Dummy(ctx, 0, 0)
  ImGui.SetCursorScreenPos(ctx, x0, strip_b)
end

-- The preset dropdown (Prep and Rules tabs).
function UI.preset_combo(id, w)
  ImGui.SetNextItemWidth(ctx, w)
  local cur = Rules.cur()
  if ImGui.BeginCombo(ctx, id, cur and (cur.label or cur.name) or "") then
    for i, p in ipairs(S.presets) do
      if ImGui.Selectable(ctx, (p.label or p.name) .. "##p" .. i, i == S.preset) and i ~= S.preset then
        S.preset = i; Rules.changed()
      end
    end
    ImGui.EndCombo(ctx)
  end
end

-- The footer text of the preview (cached until the rows change).
function UI.summary()
  if R.summary then return R.summary end
  local n, ren, notes, pans, gains = #R.rows, 0, 0, 0, 0
  for _, row in ipairs(R.rows) do
    if row.on and Util.clean(row.new) ~= "" and row.new ~= row.old then ren = ren + 1 end
    if row.note then notes = notes + 1 end
    if row.on and row.pan then pans = pans + 1 end
    if row.on and S.gain and row.gain and math.abs(row.gain) >= 0.05 then gains = gains + 1 end
  end
  local t = { (R.scan.scope == "selected" and (n .. " selected tracks") or (n .. " tracks")), ren .. " renamed" }
  if pans > 0 then t[#t + 1] = pans .. " panned" end
  if gains > 0 then t[#t + 1] = gains .. " gain staged" end
  if notes > 0 then t[#t + 1] = notes .. (notes == 1 and " note" or " notes") end
  R.summary = table.concat(t, ", ")
  return R.summary
end

-- The Prep tab: the preset, Scan, the preview table, Apply.
function UI.draw_prep()
  UI.vgap(CFG.SP_TITLE_BEFORE)
  local rx0 = ImGui.GetCursorPosX(ctx)
  local raw = ImGui.GetContentRegionAvail(ctx) - 4
  UI.row_text("Preset:")
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  UI.preset_combo("##prep_preset", CFG.PRESET_W)
  ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
  ImGui.BeginDisabled(ctx, R.scanning ~= nil)
  if UI.button("Scan", UI.btn_w("Scan", 80), nil, "primary") then Prep.scan_begin() end
  if ImGui.IsItemHovered(ctx) then
    local nsel = r.CountSelectedTracks(0)
    if nsel > 0 then UI.tipf("Reads the %d selected tracks. Nothing changes until you click Apply.", nsel)
    else UI.tip("No track is selected: reads all the tracks. Nothing changes until you click Apply.") end
  end
  ImGui.SameLine(ctx, 0, 4)
  if UI.button("Scan all", UI.btn_w("Scan all")) then Prep.scan_begin(true) end
  UI.tip("Reads every track of the project (the selection does not matter). Nothing changes until you click Apply.")
  ImGui.EndDisabled(ctx)
  ImGui.SameLine(ctx, 0, 0) -- the "?" at the right end of the row
  ImGui.SetCursorPosX(ctx, rx0 + raw - CFG.HELP_ICON)
  local hx, hy = ImGui.GetCursorScreenPos(ctx)
  ImGui.SetCursorScreenPos(ctx, hx, hy + (ImGui.GetFrameHeight(ctx) - CFG.HELP_ICON) / 2)
  UI.help_icon("prep", HELP_PREP)
  if R.scanning then
    UI.vgap(12)
    ImGui.TextColored(ctx, COL.TEXT_DIM, string.format("Scanning %d / %d tracks...", R.scanning.i, #R.scanning.tracks))
    return
  end
  if not R.rows then
    UI.vgap(12)
    ImGui.PushTextWrapPos(ctx, 0)
    ImGui.TextColored(ctx, COL.TEXT_DIM, "Select the tracks of the multitrack (or none for all the tracks), "
      .. "then click Scan. You see the new names, folders and notes first. Nothing changes until you click Apply.")
    ImGui.PopTextWrapPos(ctx)
    return
  end
  if #R.rows == 0 then
    UI.vgap(12)
    ImGui.PushTextWrapPos(ctx, 0)
    if (R.scan.skipped or 0) > 0 then
      ImGui.TextColored(ctx, COL.TEXT_DIM, "All " .. R.scan.skipped .. " tracks are prepped (" .. (R.scan.date or "")
        .. "). Add new tracks (for example overdubs) and Scan again: only they are read. Ctrl+Z of the Apply frees the tracks.")
    else
      ImGui.TextColored(ctx, COL.TEXT_DIM, "No tracks.")
    end
    ImGui.PopTextWrapPos(ctx)
    return
  end
  UI.vgap(10)
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  aw = aw - 10 -- (the same margin at the right as the indent at the left)
  local fh = ImGui.GetFrameHeight(ctx)
  local notes = UI.foot_notes()
  local table_h = math.max(80, ah - fh - 2 * CFG.SP_ROW - 4 - (notes and (ImGui.GetTextLineHeight(ctx) + CFG.SP_ROW) or 0))
  local flags = ImGui.TableFlags_BordersInnerH() | ImGui.TableFlags_ScrollY()
    | ImGui.TableFlags_SizingStretchProp()
  local gain_col = S.gain and R.scan.gain
  local col_on = Prep.color_on()
  local width_col = S.pan_w_on
  if ImGui.BeginTable(ctx, "##preview", 9 + (gain_col and 1 or 0) + (width_col and 1 or 0), flags, aw, table_h) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed(), 24)
    ImGui.TableSetupColumn(ctx, "Old name", ImGui.TableColumnFlags_WidthStretch(), 3)
    ImGui.TableSetupColumn(ctx, "New name", ImGui.TableColumnFlags_WidthStretch(), 3)
    ImGui.TableSetupColumn(ctx, "Folder", ImGui.TableColumnFlags_WidthStretch(), 2)
    ImGui.TableSetupColumn(ctx, "Notes", ImGui.TableColumnFlags_WidthStretch(), 3)
    if gain_col then ImGui.TableSetupColumn(ctx, "Gain", ImGui.TableColumnFlags_WidthFixed(), CFG.GAIN_W) end
    ImGui.TableSetupColumn(ctx, "Pol", ImGui.TableColumnFlags_WidthFixed(), CFG.MS_W)
    ImGui.TableSetupColumn(ctx, "Pan", ImGui.TableColumnFlags_WidthFixed(), CFG.MS_W)
    if width_col then ImGui.TableSetupColumn(ctx, "Width", ImGui.TableColumnFlags_WidthFixed(), CFG.WIDTH_W) end
    ImGui.TableSetupColumn(ctx, "M", ImGui.TableColumnFlags_WidthFixed(), CFG.MS_W)
    ImGui.TableSetupColumn(ctx, "S", ImGui.TableColumnFlags_WidthFixed(), CFG.MS_W)
    UI.plain_headers(HEAD[(gain_col and 2 or 0) + (width_col and 1 or 0)])
    for i, row in ipairs(R.rows) do
      ImGui.PushID(ctx, i)
      ImGui.TableNextRow(ctx, 0, fh)
      ImGui.TableNextColumn(ctx)
      local ch, v = ImGui.Checkbox(ctx, "##on", row.on)
      if ch then row.on = v; R.summary = nil end
      UI.tip("Apply changes this track (name, color, folder, pan).")
      ImGui.TableNextColumn(ctx)
      local cw = ImGui.GetContentRegionAvail(ctx)
      local dim = not row.on and COL.TEXT_DIM or nil
      if ImGui.InvisibleButton(ctx, "##sel", math.max(1, cw), fh) and r.ValidatePtr2(0, row.t.tr, "MediaTrack*") then
        r.SetOnlyTrackSelected(row.t.tr)
        r.SetMixerScroll(row.t.tr)
      end
      UI.tip("Click: select this track in REAPER.")
      local x1, y1 = ImGui.GetItemRectMin(ctx)
      local odl = ImGui.GetWindowDrawList(ctx)
      if ImGui.IsItemHovered(ctx) then -- (a click selects the track: the row shows it on hover)
        ImGui.DrawList_AddRectFilled(odl, x1 - 4, y1, x1 + cw, y1 + fh, COL.ROW_HOVER, 5)
        ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
      end
      ImGui.DrawList_AddText(odl, x1, UI.text_y(y1), dim or COL.TEXT_DIM, UI.trunc_c(row.old, cw))
      ImGui.TableNextColumn(ctx)
      UI.swatch(row.on and col_on and row.color or nil, 12)
      ImGui.SameLine(ctx, 0, 6)
      ImGui.SetNextItemWidth(ctx, -1)
      local chn, txt = ImGui.InputText(ctx, "##new", row.new)
      if chn then row.new, row.edited = txt, true; R.summary = nil end
      UI.tip("Click to change the new name. Empty: the track keeps its name.")
      ImGui.TableNextColumn(ctx)
      UI.row_text(row.folder ~= "" and UI.trunc_c(row.folder, ImGui.GetContentRegionAvail(ctx)) or "-",
        (row.folder == "" or not row.on) and COL.TEXT_DIM or nil)
      ImGui.TableNextColumn(ctx)
      -- the notes: short tags (the full text in their tooltip); the fix button at the right of the cell
      local nx0 = ImGui.GetCursorPosX(ctx)
      local nw = ImGui.GetContentRegionAvail(ctx)
      for k, tg in ipairs(row.tags) do
        if k > 1 then ImGui.SameLine(ctx, 0, 4) end
        ImGui.PushID(ctx, k)
        UI.tag(tg.text, tg.tip, tg.dim)
        ImGui.PopID(ctx)
      end
      if #row.tags == 0 and not row.fix then UI.row_text("") end
      if row.note then
        if row.fix then
          local fl = row.fix == "delete" and "Delete" or "Mono"
          local flw = UI.btn_w(fl)
          if #row.tags > 0 then ImGui.SameLine(ctx, 0, 0) end
          ImGui.SetCursorPosX(ctx, nx0 + math.max(0, nw - flw))
          if UI.state_button("##fix", fl, flw, row.fix_on, COL.PAN) then row.fix_on = not row.fix_on end
          if row.fix == "delete" then
            UI.tip(row.fix_on and "On: Apply deletes this empty track (Ctrl+Z brings it back). Click: off."
              or "Click: Apply deletes this empty track (Ctrl+Z brings it back).")
          else
            UI.tipf("%s: Apply plays only the %s side (the item channel mode; the file stays as it is).",
              row.fix_on and "On" or "Off", row.fix == "mono R" and "right" or "left")
          end
        end
      end
      if gain_col then
        ImGui.TableNextColumn(ctx)
        if row.gain then
          ImGui.SetNextItemWidth(ctx, CFG.GAIN_W)
          local chg, g = ImGui.DragDouble(ctx, "##gain", row.gain, 0.1, -40, 40, "%+.1f dB")
          if chg then row.gain, row.gain_edited = math.floor(g * 10 + 0.5) / 10, true; R.summary = nil end
          if ImGui.IsItemClicked(ctx, 1) then row.gain, row.gain_edited = row.gain_meas, false; R.summary = nil end
          UI.tipf("The item gain that Apply adds (measured: %+.1f dB).\n"
            .. "Drag, or double-click to type. 0 dB: no change. Right-click: the measured value again.", row.gain_meas)
        else
          UI.row_text("-", COL.TEXT_DIM)
          UI.tip("No audio to measure.")
        end
      end
      ImGui.TableNextColumn(ctx)
      if UI.state_button("##pol", "\u{00D8}", CFG.MS_W, row.pol == true, COL.PAN) then
        row.pol, row.pol_edited = not row.pol, true
      end
      UI.tip(row.pol and "Apply flips the polarity of this track (\u{00D8} on). Click: off."
        or "Click: Apply flips the polarity of this track (for example a snare bottom mic).")
      ImGui.TableNextColumn(ctx)
      local plabel = row.pan or "-"
      if UI.state_button("##pan", plabel, CFG.MS_W, row.pan ~= nil, COL.PAN) then
        row.pan, row.pan_edited = PAN_NEXT[row.pan or "-"], true; R.summary = nil
      end
      UI.tip(row.pan == "L" and "Apply pans this track left. Click: C (center)."
        or (row.pan == "C" and "Apply pans this track to the center. Click: R."
        or (row.pan == "R" and "Apply pans this track right. Click: - (leave the pan)."
        or "Apply leaves the pan as it is. Click: L.")))
      if width_col then -- the width of this track's L / R pan (100 % = hard)
        ImGui.TableNextColumn(ctx)
        if row.pan == "L" or row.pan == "R" then
          ImGui.SetNextItemWidth(ctx, CFG.WIDTH_W)
          local chw, wv = ImGui.DragInt(ctx, "##width", row.width or 100, 1, 10, 100, "%d %%")
          if chw then row.width, row.width_edited = Util.clamp(wv, 10, 100), true end
          UI.tip("How far this track pans to its side (100 % = hard). Drag, or double-click to type.")
        else
          UI.row_text("-", COL.TEXT_DIM)
        end
      end
      local valid = r.ValidatePtr2(0, row.t.tr, "MediaTrack*")
      ImGui.TableNextColumn(ctx)
      local muted = valid and r.GetMediaTrackInfo_Value(row.t.tr, "B_MUTE") ~= 0
      if UI.state_button("##m", "M", CFG.MS_W, muted, COL.RED) and valid then
        r.Undo_BeginBlock()
        r.CSurf_OnMuteChangeEx(row.t.tr, muted and 0 or 1, false)
        r.Undo_EndBlock("Session Prep: mute track", -1)
      end
      UI.tip("Mute (now, as in REAPER).")
      ImGui.TableNextColumn(ctx)
      local solo = valid and r.GetMediaTrackInfo_Value(row.t.tr, "I_SOLO") ~= 0
      if UI.state_button("##s", "S", CFG.MS_W, solo, COL.YELLOW) and valid then
        r.Undo_BeginBlock()
        r.CSurf_OnSoloChangeEx(row.t.tr, solo and 0 or 1, false)
        r.Undo_EndBlock("Session Prep: solo track", -1)
      end
      UI.tip("Solo (now, as in REAPER).")
      ImGui.PopID(ctx)
    end
    ImGui.EndTable(ctx)
  end
  -- the footer: the summary and Apply; the notes on a 2nd grey line
  local aw_w = UI.btn_w("Apply", 90)
  local x_left = ImGui.GetCursorPosX(ctx)
  UI.row_text(UI.trunc_c(UI.summary(), math.max(40, aw - aw_w - CFG.CTRL_GAP - 4)), COL.TEXT_DIM)
  ImGui.SameLine(ctx, 0, 0)
  ImGui.SetCursorPosX(ctx, x_left + aw - aw_w)
  if UI.button("Apply", aw_w, nil, "primary") then UI.apply_now() end
  UI.tip("Makes all the ticked changes (key: Enter). One Ctrl+Z undoes all of them.")
  if notes then
    ImGui.PushTextWrapPos(ctx, x_left + aw)
    ImGui.TextColored(ctx, COL.TEXT_DIM, notes)
    ImGui.PopTextWrapPos(ctx)
  end
end

-- Apply the rows of the Prep table (the Apply button and the Enter key).
function UI.apply_now()
  if not R.rows or #R.rows == 0 or R.scanning then return end
  local msg = Prep.apply(R.rows)
  R.rows, R.scan = nil, nil
  UI.notice(msg)
end

-- The notes under the Prep table (nil: none); made again only when they change.
function UI.foot_notes()
  local sc = R.scan
  if not sc then return nil end
  local a = S.folders and not sc.folders_ok and (sc.skipped or 0) == 0
  local b, c, k = sc.audio ~= S.audio, S.gain and not sc.gain, sc.skipped or 0
  local f = R.foot
  if f and f.a == a and f.b == b and f.c == c and f.k == k then return f.text end
  local t = {}
  if a then t[#t + 1] = "The tracks are already in folders: no new folders." end
  if k > 0 then t[#t + 1] = k .. " prepped tracks left out; new tracks stay where they are." end
  if b then t[#t + 1] = "Scan again for the audio check." end
  if c then t[#t + 1] = "Scan again for gain staging." end
  R.foot = { a = a, b = b, c = c, k = k, text = #t > 0 and table.concat(t, " ") or nil }
  return R.foot.text
end

-- The keys while the window has the focus (no field is active): Delete removes the open rule (Rules tab), F2
-- renames the preset, Enter runs Apply (Prep tab).
function UI.keys()
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Delete(), false) and S.tab == TAB_RULES and R.edit_rule then
    local p = Rules.cur()
    for i, ru in ipairs(p.rules) do
      if ru == R.edit_rule then table.remove(p.rules, i); R.edit_rule = nil; Rules.changed(); break end
    end
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_F2(), false) then
    local p = Rules.cur()
    Util.ask_name("Session Prep - Rename preset", p.name, function(name)
      if name ~= p.name then p.name = Rules.free_name(name); Rules.changed() end
    end)
  elseif (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter(), false) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter(), false))
      and S.tab == TAB_PREP then
    UI.apply_now()
  end
end

-- The Rules tab: Preset, Rules, Order (each folds).
function UI.draw_rules()
  local p = Rules.cur()
  if UI.heading("Preset", nil, "preset", "preset") then UI.draw_preset(p) end
  local open = UI.heading("Rules", HELP_RULES, "rules", "rules")
  UI.undo_button("##undo_rules", "rules")
  if open then UI.draw_rule_table(p) end
end

-- The preset: the dropdown, Save as / Rename / Delete, the strip switch, Export / Import.
function UI.draw_preset(p)
  UI.preset_combo("##rules_preset", CFG.PRESET_W)
  ImGui.SameLine(ctx, 0, 4)
  -- Save: a disk icon (blue: unsaved changes)
  local fh = ImGui.GetFrameHeight(ctx)
  ImGui.BeginDisabled(ctx, not p.dirty)
  local save = UI.button("##save", fh, fh, p.dirty and "primary" or nil)
  ImGui.EndDisabled(ctx)
  UI.draw_disk(ImGui.GetWindowDrawList(ctx), p.dirty and COL.WHITE or COL.TOGGLE_OFF)
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
    UI.tip(p.dirty and "Save the changes of this preset (the dot after its name goes)."
      or "Saved: this preset has no unsaved changes.")
  end
  if save then Rules.save(p) end
  ImGui.SameLine(ctx, 0, 4)
  if UI.button("Save as...", UI.btn_w("Save as...")) then
    Util.ask_name("Session Prep - Save preset as", Rules.free_name(p.name), function(name)
      local c = Rules.copy(p) -- (the new preset gets the changes; this one goes back to its last Save)
      if not c then return end
      c.name = Rules.free_name(name)
      c.orig = Rules.serialize(c)
      c.saved = c.orig
      Rules.update_dirty(c)
      if p.dirty then Rules.apply_text(p, p.saved); Rules.update_dirty(p) end
      S.presets[#S.presets + 1] = c
      S.preset = #S.presets
      Rules.changed()
    end)
  end
  UI.tip("Saves this preset with your changes as a new preset (this one keeps its last saved version).")
  ImGui.SameLine(ctx, 0, 4)
  ImGui.SetNextItemWidth(ctx, CFG.MORE_W)
  if ImGui.BeginCombo(ctx, "##more", "More...") then
    if ImGui.Selectable(ctx, "Rename...") then
      Util.ask_name("Session Prep - Rename preset", p.name, function(name)
        if name ~= p.name then p.name = Rules.free_name(name); Rules.update_dirty(p); Rules.changed() end
      end)
    end
    if ImGui.Selectable(ctx, "Export...") then
      local path, err = Rules.export(p)
      UI.notice(path and ("Preset exported: " .. path) or err, not path)
    end
    if ImGui.Selectable(ctx, "Import...") then
      r.RecursiveCreateDirectory(CFG.DATA_DIR, 0)
      local okf, path = r.GetUserFileNameForRead(CFG.DATA_DIR:gsub("/", "\\") .. "\\", "Import Session Prep preset", ".txt")
      if okf and path ~= "" then
        local np, err = Rules.import(path)
        UI.notice(np and ("Preset imported: " .. np.name) or err, not np)
      end
    end
    ImGui.Separator(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text(), COL.RED) -- (the items that remove your work)
    ImGui.BeginDisabled(ctx, not p.dirty)
    local revert = ImGui.Selectable(ctx, "Revert to saved...")
    ImGui.EndDisabled(ctx)
    ImGui.BeginDisabled(ctx, p.orig == nil)
    local reset = ImGui.Selectable(ctx, "Reset to original...")
    ImGui.EndDisabled(ctx)
    ImGui.BeginDisabled(ctx, #S.presets < 2)
    local del = ImGui.Selectable(ctx, "Delete preset...")
    ImGui.EndDisabled(ctx)
    ImGui.PopStyleColor(ctx)
    if revert then
      UI.ask("Revert the preset \"" .. p.name .. "\" to its last saved version? Your unsaved changes go.", "Revert",
        function() Rules.revert(p) end)
    end
    if reset then
      UI.ask("Reset the preset \"" .. p.name .. "\" to its original settings (built-in: the built-in settings; your "
        .. "own preset: as you made it)? Save afterwards to keep it.", "Reset", function() Rules.reset(p) end)
    end
    if del then
      UI.ask("Delete the preset \"" .. p.name .. "\"?", "Delete", function()
        table.remove(S.presets, S.preset)
        S.preset = Util.clamp(S.preset, 1, #S.presets)
        Rules.changed()
      end)
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Rename, export or import a preset; revert to saved, reset to original or delete it.")
  local ch, v = UI.form_toggle("Trim prefix / suffix", p.strip,
    "On: when all the names start or end the same way, that part goes (\"MySong_Kick\", \"MySong_Snare\" -> Kick, Snare).")
  if ch then p.strip = v; Rules.changed() end
end

-- A disk icon on the last item (a square button): Save.
function UI.draw_disk(dl, col)
  local x1, y1 = ImGui.GetItemRectMin(ctx)
  local x2, y2 = ImGui.GetItemRectMax(ctx)
  local cx, cy = math.floor((x1 + x2) / 2), math.floor((y1 + y2) / 2)
  local r0 = 6
  ImGui.DrawList_AddRect(dl, cx - r0, cy - r0, cx + r0, cy + r0, col, 2, 0, 1.5)
  ImGui.DrawList_AddRectFilled(dl, cx - 3, cy - r0, cx + 3, cy - 2, col)
  ImGui.DrawList_AddRect(dl, cx - 4, cy + 1, cx + 4, cy + r0, col, 0, 0, 1)
end

-- The rules table (drag the 3 lines to change the order; the first rule that matches wins).
function UI.draw_rule_table(p)
  R.hdr_hov_last, R.hdr_hov = R.hdr_hov, nil
  local list = Rules.folders(p)
  local any_free = false
  for _, ru in ipairs(p.rules) do if Util.clean(ru.folder) == "" then any_free = true; break end end
  R.rule_move, R.rule_remove, R.folder_move = nil, nil, nil
  for gi, f in ipairs(list) do UI.rule_group(p, f, f, gi) end
  if any_free then UI.rule_group(p, "", "No folder", 0) end
  if R.rule_move and R.rule_move[1] ~= R.rule_move[2] and R.rule_move[1] + 1 ~= R.rule_move[2] then
    UI.move_before(p.rules, R.rule_move[1], R.rule_move[2])
    Rules.changed()
  end
  local fm = R.folder_move
  if fm and fm[1] ~= fm[2] and fm[1] + 1 ~= fm[2] then -- (a folder header was dragged: the folder order)
    local new = {}
    for i, f in ipairs(list) do new[i] = f end
    UI.move_before(new, fm[1], fm[2])
    p.order = new
    Rules.changed()
  end
  if R.rule_remove then
    if p.rules[R.rule_remove] == R.edit_rule then R.edit_rule = nil end
    table.remove(p.rules, R.rule_remove)
    Rules.changed()
  end
  UI.vgap(8)
  if UI.button("+ Rule (no folder)", UI.btn_w("+ Rule (no folder)"), nil, "ghost") then
    p.rules[#p.rules + 1] = rule("", "", "", 0x808080)
    R.edit_rule = p.rules[#p.rules]
    Rules.changed()
  end
  UI.tip("Adds an empty rule at the end. Give it a folder in its fields.")
end

-- A drop place on the last item: while a drag of this kind is over it, a blue line above or below it shows where the
-- dragged item goes (no drop target: ImGui's yellow box stays away). Returns the payload (when the mouse is released
-- over it) and below (true: after the item). idx: the index of this item; no line where the drop would not move the
-- dragged item (its own place and the gaps next to it). no_below: only "before this item" (an open folder: "after"
-- it is after its rules, not right below its header).
function UI.drop_line(kind, x1, x2, idx, no_below)
  local ok, ptype, payload = ImGui.GetDragDropPayload(ctx)
  if not ok or ptype ~= kind then return end
  if not ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByActiveItem()) then return end
  local _, y1 = ImGui.GetItemRectMin(ctx)
  local _, y2 = ImGui.GetItemRectMax(ctx)
  local _, my = ImGui.GetMousePos(ctx)
  local below = not no_below and my > (y1 + y2) / 2
  local from, before = tonumber(payload), below and idx + 1 or idx
  if from == before or from + 1 == before then return end -- (it would stay where it is)
  local ly = below and (y2 + CFG.SP_ROW / 2) or (y1 - CFG.SP_ROW / 2)
  ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), x1, ly, x2, ly, COL.ACCENT, 2)
  if ImGui.IsMouseReleased(ctx, 0) then return payload, below end
  return nil, below
end
-- Moves list[from] so that it ends up before the item that was at index before (before = #list + 1: the end).
function UI.move_before(list, from, before)
  local item = table.remove(list, from)
  if before > from then before = before - 1 end
  table.insert(list, before, item)
end

-- 1 folder of the Rules list: its header (fold arrow, color of the folder, name, "+ Rule"), then 1 quiet line per
-- rule (drag handle, name, match words); a click opens the rule's fields below it.
function UI.rule_group(p, f, label, gi)
  ImGui.PushID(ctx, "rg" .. gi)
  local fh = ImGui.GetFrameHeight(ctx)
  local x0 = ImGui.GetCursorPosX(ctx)
  local aw = ImGui.GetContentRegionAvail(ctx) - 10
  local first
  for _, ru in ipairs(p.rules) do if Util.clean(ru.folder) == f then first = ru; break end end
  R.group_ids = R.group_ids or {}
  local id = R.group_ids[f]
  if not id then id = "rf_" .. (f ~= "" and f:gsub("[^%w]", "_") or "none"); R.group_ids[f] = id end
  -- the header: 2 parts that act the same (the handle + arrow, and the name up to "+ Rule"; the color square is
  -- between them): a click opens / closes the folder, a drag moves it ("No folder" stays at the end)
  local open = not S.closed[id]
  local dl = ImGui.GetWindowDrawList(ctx)
  local hx, hy = ImGui.GetCursorScreenPos(ctx)
  local add_w = UI.btn_w("+ Rule")
  local function header_part(pid, w)
    if ImGui.InvisibleButton(ctx, pid, w, fh) then
      open = not open; S.closed[id] = (not open) or nil; Util.mark_sdirty()
    end
    if ImGui.IsItemHovered(ctx) then R.hdr_hov = id; ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
    UI.tip(gi > 0 and "Click: open / close. Drag: move this folder (top to bottom = the order in the project)."
      or "Click: open / close.")
    if gi > 0 then
      if ImGui.BeginDragDropSource(ctx) then
        ImGui.SetDragDropPayload(ctx, "SP_FOLDER", tostring(gi))
        ImGui.Text(ctx, label)
        ImGui.EndDragDropSource(ctx)
      end
      local pl, below = UI.drop_line("SP_FOLDER", hx, hx + aw, gi, open)
      if pl then R.folder_move = { tonumber(pl), below and gi + 1 or gi } end
    end
  end
  local hov = R.hdr_hov_last == id
  if hov then ImGui.DrawList_AddRectFilled(dl, hx, hy, hx + aw - add_w - 4, hy + fh, COL.ROW_HOVER, 5) end
  header_part("##hl", 38)
  local icol = hov and COL.TEXT_MAIN or COL.TEXT_DIM
  if gi > 0 then -- the 3 lines (only a sign: the whole header drags)
    local cx, cy = hx + 9, hy + fh / 2
    for k = -1, 1 do ImGui.DrawList_AddLine(dl, cx - 6, cy + k * 4, cx + 6, cy + k * 4, icol, 1.5) end
  end
  local ax, ay = hx + 28, hy + fh / 2
  if open then ImGui.DrawList_AddTriangleFilled(dl, ax - 4, ay - 2, ax + 4, ay - 2, ax, ay + 3, icol)
  else ImGui.DrawList_AddTriangleFilled(dl, ax - 2, ay - 4, ax - 2, ay + 4, ax + 3, ay, icol) end
  ImGui.SameLine(ctx, 0, 4)
  if first then
    local chc, c = ImGui.ColorEdit3(ctx, "##fc", first.color or 0x808080,
      ImGui.ColorEditFlags_NoInputs() | ImGui.ColorEditFlags_NoLabel())
    if chc then
      for _, ru in ipairs(p.rules) do if Util.clean(ru.folder) == f then ru.color = c end end
      Rules.changed()
    end
    UI.tipf("The color of every rule in %s.", label)
    ImGui.SameLine(ctx, 0, 8)
  end
  local nx, ny = ImGui.GetCursorScreenPos(ctx)
  header_part("##hn", math.max(20, x0 + aw - add_w - 4 - ImGui.GetCursorPosX(ctx)))
  ImGui.PushFont(ctx, bold)
  ImGui.DrawList_AddText(dl, nx, UI.text_y(ny), COL.TEXT_MAIN, label)
  ImGui.PopFont(ctx)
  ImGui.SameLine(ctx, 0, 0)
  ImGui.SetCursorPosX(ctx, x0 + aw - add_w)
  if UI.button("+ Rule", add_w, nil, "ghost") then
    local at = #p.rules + 1
    for i, ru in ipairs(p.rules) do if Util.clean(ru.folder) == f then at = i + 1 end end
    table.insert(p.rules, at, rule("", "", f, first and first.color or 0x808080))
    R.edit_rule = p.rules[at]
    S.closed[id] = nil
    Rules.changed()
  end
  UI.tipf("Adds a rule to %s.", label)
  if open then
    local dl = ImGui.GetWindowDrawList(ctx)
    for i, ru in ipairs(p.rules) do
      if Util.clean(ru.folder) == f then
        ImGui.PushID(ctx, i)
        ImGui.SetCursorPosX(ctx, x0 + 38)
        local rsx = ImGui.GetCursorScreenPos(ctx)
        ImGui.InvisibleButton(ctx, "##drag", 18, fh)
        local hov = ImGui.IsItemHovered(ctx)
        if hov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS()) end
        UI.draw_handle(hov and COL.TEXT_MAIN or COL.TEXT_DIM)
        UI.tip("Drag to change the order (the higher rule wins).")
        if ImGui.BeginDragDropSource(ctx) then
          ImGui.SetDragDropPayload(ctx, "SP_RULE", tostring(i))
          ImGui.Text(ctx, (ru.name ~= "" and ru.name or ru.match))
          ImGui.EndDragDropSource(ctx)
        end
        local function drop_target()
          local pl, below = UI.drop_line("SP_RULE", rsx, rsx + aw - 38, i)
          if pl then R.rule_move = { tonumber(pl), below and i + 1 or i } end
        end
        drop_target()
        ImGui.SameLine(ctx, 0, 4)
        local lx, ly = ImGui.GetCursorScreenPos(ctx)
        local lw = math.max(40, x0 + aw - ImGui.GetCursorPosX(ctx) - CFG.X_BTN - 6)
        local editing = R.edit_rule == ru
        if ImGui.InvisibleButton(ctx, "##line", lw, fh) then R.edit_rule = (not editing) and ru or nil end
        if ImGui.BeginDragDropSource(ctx) then -- (the whole line drags, as the 3 lines)
          ImGui.SetDragDropPayload(ctx, "SP_RULE", tostring(i))
          ImGui.Text(ctx, (ru.name ~= "" and ru.name or ru.match))
          ImGui.EndDragDropSource(ctx)
        end
        drop_target()
        local lhov = ImGui.IsItemHovered(ctx)
        if editing or lhov then
          ImGui.DrawList_AddRectFilled(dl, lx, ly, lx + lw, ly + fh, editing and COL.ACTIVE_BG or COL.ROW_HOVER, 5)
        end
        if lhov then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
        local name_w = math.min(150, lw * 0.35)
        ImGui.PushFont(ctx, bold)
        ImGui.DrawList_AddText(dl, lx + 8, UI.text_y(ly), COL.TEXT_MAIN, UI.trunc(ru.name ~= "" and ru.name or "(no name)", name_w - 12))
        ImGui.PopFont(ctx)
        ImGui.DrawList_AddText(dl, lx + name_w, UI.text_y(ly), COL.TEXT_DIM, UI.trunc(ru.match, lw - name_w - 8))
        ImGui.SameLine(ctx, 0, 6)
        if UI.remove_x_button("##x", CFG.X_BTN) then R.rule_remove = i end
        UI.tip("Deletes this rule.")
        if editing then UI.rule_editor(ru, x0 + 60, aw - 60) end
        ImGui.PopID(ctx)
      end
    end
  end
  UI.vgap(4)
  ImGui.PopID(ctx)
end

-- The fields of 1 rule (below its line): Color, Folder, Name, Match.
function UI.rule_editor(ru, x, w)
  local lab = 70
  local function row(label)
    ImGui.SetCursorPosX(ctx, x)
    UI.row_text(label, COL.TEXT_DIM)
    ImGui.SameLine(ctx, 0, 0)
    ImGui.SetCursorPosX(ctx, x + lab)
  end
  local function field(key, hint, fw)
    ImGui.SetNextItemWidth(ctx, fw)
    local folder = key == "folder" -- (kept in R.folder_buf until you leave the field: the rule stays in its group)
    if folder and R.folder_buf_rule ~= ru then R.folder_buf, R.folder_buf_rule = ru.folder, ru end
    local chg, txt = ImGui.InputTextWithHint(ctx, "##" .. key, hint, folder and R.folder_buf or ru[key])
    if ImGui.IsItemActivated(ctx) then R.field_old = ru[key] end -- (the name before the edit: Rules.rename)
    if chg then
      txt = txt:gsub("[|;~%^]", "")
      if folder then R.folder_buf = txt
      else ru[key] = txt; R.comp, R.folder_list = nil, nil; Util.mark_sdirty() end
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
      if folder then ru.folder = Util.clean(R.folder_buf); R.folder_buf_rule = nil end
      if folder or key == "name" then Rules.rename(Rules.cur(), key, R.field_old or "", ru[key]) end
      Rules.changed()
    end
  end
  UI.vgap(4)
  row("Color")
  local chc, c = ImGui.ColorEdit3(ctx, "##color", ru.color or 0x808080,
    ImGui.ColorEditFlags_NoInputs() | ImGui.ColorEditFlags_NoLabel())
  if chc then ru.color = c; Rules.changed() end
  row("Folder"); field("folder", "none (no folder)", math.min(220, w - lab))
  row("Name"); field("name", "Kick", math.min(220, w - lab))
  row("Match"); field("match", "kik, kick, bd (commas)", math.max(80, w - lab - 10))
  row("Polarity")
  local on = (ru.pol or "") ~= ""
  local chp, nv = ImGui.Checkbox(ctx, "Flip##pol", on)
  if chp then ru.pol = nv and "*" or ""; Rules.changed() end
  UI.tip("Flip the polarity of the tracks of this rule at Apply (the \u{00D8} button of the row starts on).")
  if on then
    ImGui.SameLine(ctx, 0, 10)
    UI.row_text("only with the word", COL.TEXT_DIM)
    ImGui.SameLine(ctx, 0, 6)
    ImGui.SetNextItemWidth(ctx, 90)
    local chw, word = ImGui.InputTextWithHint(ctx, "##polword", "any", ru.pol == "*" and "" or ru.pol)
    if chw then
      word = Util.clean((word:gsub("[|;~%^]", "")))
      ru.pol = word ~= "" and word or "*"
      Util.mark_sdirty()
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then Rules.changed() end
    UI.tip("Only the tracks with this extra word, for example Btm: Snare Btm flips, Snare Top does not. Empty: every track.")
  end
  UI.vgap(8)
end

-- A row with a name and an FX chain file: the file name, "..." (pick) and X (none). set(path or nil).
function UI.chain_row(id, label, path, what)
  local changed, value = false, nil
  ImGui.PushID(ctx, id)
  local aw = ImGui.GetContentRegionAvail(ctx) - 10
  local name_w = 110
  local x0 = ImGui.GetCursorPosX(ctx)
  ImGui.PushFont(ctx, bold)
  UI.row_text(UI.trunc_c(label, name_w))
  ImGui.PopFont(ctx)
  ImGui.SameLine(ctx, 0, 0)
  ImGui.SetCursorPosX(ctx, x0 + name_w + CFG.CTRL_GAP)
  if path == "" then path = nil end
  local file = path and path:match("([^/\\]+)$") or "(none)"
  local pick_w = UI.btn_w("...")
  local text_w = math.max(40, aw - name_w - CFG.CTRL_GAP * 2 - pick_w - (path and CFG.X_BTN + 4 or 0))
  UI.row_text(UI.trunc_c(file, text_w), path and COL.TEXT_MAIN or COL.TEXT_DIM)
  if path and ImGui.IsItemHovered(ctx) then UI.tip(r.file_exists(path) and path or ("Not found: " .. path)) end
  ImGui.SameLine(ctx, 0, 0)
  ImGui.SetCursorPosX(ctx, x0 + aw - pick_w - (path and CFG.X_BTN + 4 or 0))
  if UI.button("...", pick_w) then
    local dir = (r.GetResourcePath() .. "/FXChains/"):gsub("/", "\\")
    local okf, pick = r.GetUserFileNameForRead(path or dir, "FX chain for " .. label, ".RfxChain")
    if okf and pick ~= "" then changed, value = true, Rules.safe(pick) end
  end
  if ImGui.IsItemHovered(ctx) then UI.tipf("Pick an FX chain (.RfxChain): Apply adds it to " .. what .. ".", label) end
  if path then
    ImGui.SameLine(ctx, 0, 4)
    if UI.remove_x_button("##x", CFG.X_BTN) then changed, value = true, nil end
    UI.tip("No FX chain.")
  end
  ImGui.PopID(ctx)
  return changed, value
end

-- The grey line "Preset: <name> (the ... are saved in the preset)" (made again only when the preset or tab changes).
function UI.preset_note(p, what)
  local c = R.pnote
  if not c or c.name ~= p.name or c.what ~= what then
    c = { name = p.name, what = what, text = "Preset: " .. p.name .. " (the " .. what .. " are saved in the preset)" }
    R.pnote = c
  end
  return c.text
end

-- The FX Chains tab: Folder FX (with the buses that are on), Track FX (grouped by folder; each group folds,
-- closed by default).
function UI.draw_fx()
  local p = Rules.cur()
  ImGui.TextColored(ctx, COL.TEXT_DIM, UI.preset_note(p, "FX chains"))
  if UI.heading("Folder FX", HELP_FOLDER_FX, "folderfx", "folderfx") then
    local list = Rules.folders(p)
    if #list == 0 then
      ImGui.TextColored(ctx, COL.TEXT_DIM, "No folders yet. Give a rule a folder (Rules tab).")
    end
    for i, f in ipairs(list) do
      local ch, v = UI.chain_row(i, f, p.fx[f], "the new %s folder track")
      if ch then p.fx[f] = v; Rules.changed() end
    end
    for i, b in ipairs(p.buses) do
      if b.on then
        local ch, v = UI.chain_row(1000 + i, b.name, p.fx[b.name], "the new %s track")
        if ch then p.fx[b.name] = v; Rules.changed() end
      end
    end
  end
  if UI.heading("Track FX", HELP_TRACK_FX, "trackfx", "trackfx") then
    local groups = Rules.folders(p)
    local any = false
    R.tf_seen = {}
    for g = 1, #groups + 1 do
      if UI.track_fx_group(p, groups[g] or "", g) then any = true end
    end
    if not any then ImGui.TextColored(ctx, COL.TEXT_DIM, "No rules with a name yet (Rules tab).") end
  end
end

-- 1 folder of the Track FX: a header (click: open / close; closed by default; the number of chains), then a chain
-- row per rule name. Returns true when the folder has a rule with a name.
function UI.track_fx_group(p, f, g)
  local seen = R.tf_seen
  local n, set = 0, 0
  for _, ru in ipairs(p.rules) do
    local name = Util.clean(ru.name)
    if Util.clean(ru.folder) == f and name ~= "" and not seen[name] then
      n = n + 1
      if p.tfx[name] then set = set + 1 end
    end
  end
  if n == 0 then return false end
  R.tf_ids = R.tf_ids or {}
  local id = R.tf_ids[f]
  if not id then id = "tfo_" .. (f ~= "" and f:gsub("[^%w]", "_") or "none"); R.tf_ids[f] = id end
  local open = S.closed[id] == true -- (S.closed holds the open ones here: closed by default)
  ImGui.PushID(ctx, "tfg" .. g)
  local fh = ImGui.GetFrameHeight(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx) - 10
  if ImGui.InvisibleButton(ctx, "##h", w, fh) then
    open = not open; S.closed[id] = open or nil; Util.mark_sdirty()
  end
  local hov = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  if hov then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + fh, COL.ROW_HOVER, 5)
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand())
  end
  local ax, ay = x + 7, y + fh / 2
  local icol = hov and COL.TEXT_MAIN or COL.TEXT_DIM
  if open then ImGui.DrawList_AddTriangleFilled(dl, ax - 4, ay - 2, ax + 4, ay - 2, ax, ay + 3, icol)
  else ImGui.DrawList_AddTriangleFilled(dl, ax - 2, ay - 4, ax - 2, ay + 4, ax + 3, ay, icol) end
  ImGui.PushFont(ctx, bold)
  ImGui.DrawList_AddText(dl, x + 20, UI.text_y(y), COL.HEADING, f ~= "" and f or "No folder")
  local tw = ImGui.CalcTextSize(ctx, f ~= "" and f or "No folder")
  ImGui.PopFont(ctx)
  if set > 0 then
    R.chain_txt = R.chain_txt or {}
    local ct = R.chain_txt[set]
    if not ct then ct = set == 1 and "1 chain" or (set .. " chains"); R.chain_txt[set] = ct end
    ImGui.DrawList_AddText(dl, x + 30 + tw, UI.text_y(y), COL.TEXT_DIM, ct)
  end
  if open then
    ImGui.Indent(ctx, 20)
    for i, ru in ipairs(p.rules) do
      local name = Util.clean(ru.name)
      if Util.clean(ru.folder) == f and name ~= "" and not seen[name] then
        seen[name] = true
        local ch, v = UI.chain_row(i, name, p.tfx[name], "every %s track (only a track without FX)")
        if ch then p.tfx[name] = v; Rules.changed() end
      end
    end
    ImGui.Unindent(ctx, 20)
  else
    for _, ru in ipairs(p.rules) do
      local name = Util.clean(ru.name)
      if Util.clean(ru.folder) == f and name ~= "" then seen[name] = true end
    end
  end
  ImGui.PopID(ctx)
  return true
end

-- A card: a rounded box (1 step lighter than the panel) around the items between card_begin and card_end. The box
-- is drawn first, with the height that its items had in the frame before (R.card_h[id]; ReaImGui 0.9 has no draw
-- channels), so it fits them.
function UI.card_begin(id)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local c = { id = id, x = x, y = y, w = ImGui.GetContentRegionAvail(ctx) - 10 }
  R.card_h = R.card_h or {}
  local h = R.card_h[id]
  if h then ImGui.DrawList_AddRectFilled(dl, x, y, x + c.w, y + h, COL.CARD_BG, 8) end
  UI.vgap(CFG.SP_ROW + 6)
  ImGui.Indent(ctx, 10)
  return c
end
function UI.card_end(c)
  ImGui.Unindent(ctx, 10)
  local _, y2 = ImGui.GetCursorScreenPos(ctx)
  R.card_h[c.id] = y2 - CFG.SP_ROW + 6 - c.y
  UI.vgap(CFG.SP_ROW + 8)
end

local WAVE = { 1, 3, 5, 2, 4, 1 } -- (the half heights of the waveform mark of a track chip)
local CHIP = { pad = 10, icon = 12, gap = 7, xgap = 10 } -- (a chip: pad, icon, gap, text, xgap, x, pad)
-- A member chip of a bus: [folder mark] name x. Returns true when its x was clicked.
function UI.chip(id, label, folder, w)
  local fh = ImGui.GetFrameHeight(ctx)
  local h = fh - 4
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, id, w, fh)
  local hov = ImGui.IsItemHovered(ctx)
  local mx = ImGui.GetMousePos(ctx)
  local on_x = hov and mx > x + w - 20
  local dl = ImGui.GetWindowDrawList(ctx)
  local bg = folder and (hov and COL.CHIP_FOLDER_HOV or COL.CHIP_FOLDER) or (hov and COL.BTN_HOVER or COL.BTN)
  ImGui.DrawList_AddRectFilled(dl, x, y + 2, x + w, y + 2 + h, bg, h / 2)
  local ty = UI.text_y(y)
  local cy = math.floor(y + fh / 2) + 1.5 -- (the center line of the text: the icon and x too)
  local tx = x + CHIP.pad
  if folder then -- a folder mark (12 x 9)
    ImGui.DrawList_AddRectFilled(dl, tx, cy - 3, tx + 12, cy + 5, COL.HEADING, 1)
    ImGui.DrawList_AddRectFilled(dl, tx, cy - 5, tx + 5, cy - 2, COL.HEADING, 1)
  else -- a track mark: a waveform (12 wide)
    for k, a in ipairs(WAVE) do
      local wx = tx + k * 2 - 1
      ImGui.DrawList_AddLine(dl, wx, cy - a, wx, cy + a, COL.TEXT_MAIN, 1.2)
    end
  end
  ImGui.DrawList_AddText(dl, tx + CHIP.icon + CHIP.gap, ty, COL.TEXT_MAIN, label)
  local d = 3.5
  local cx = x + w - CHIP.pad - d
  local xc = on_x and COL.RED or COL.TEXT_DIM
  ImGui.DrawList_AddLine(dl, cx - d, cy - d, cx + d, cy + d, xc, 1.6)
  ImGui.DrawList_AddLine(dl, cx - d, cy + d, cx + d, cy - d, xc, 1.6)
  if on_x then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand()) end
  return on_x and ImGui.IsItemClicked(ctx)
end
function UI.chip_w(label)
  return CHIP.pad + CHIP.icon + CHIP.gap + math.ceil((ImGui.CalcTextSize(ctx, label))) + CHIP.xgap + 7 + CHIP.pad
end

-- The Buses tab: the buses (Inst, Vocal, Lead) and the FX returns (each section folds).
function UI.draw_buses()
  local p = Rules.cur()
  ImGui.TextColored(ctx, COL.TEXT_DIM, UI.preset_note(p, "buses and returns"))
  local bopen = UI.heading("Buses", HELP_BUSES, "buses", "buses")
  UI.undo_button("##undo_buses", "buses")
  if bopen then
    R.bus_remove = nil
    for i, b in ipairs(p.buses) do UI.draw_bus(p, i, b) end
    if R.bus_remove then
      local b = p.buses[R.bus_remove]
      UI.ask("Delete the bus \"" .. b.name .. "\"? (Its members and its FX chain go too.)", "Delete", function()
        for i, ob in ipairs(p.buses) do
          if ob == b then table.remove(p.buses, i); p.fx[b.name] = nil; Rules.changed(); break end
        end
      end)
    end
    if UI.button("+ Bus", UI.btn_w("+ Bus"), nil, "ghost") then
      local n, used = 1, {}
      for _, b in ipairs(p.buses) do used[b.name:upper()] = true end
      while used[("Bus " .. n):upper()] do n = n + 1 end
      p.buses[#p.buses + 1] = { name = "Bus " .. n, on = true, color = 0x8C8C9A, members = {} }
      Rules.changed()
    end
    UI.tip("Adds your own bus (for example a Drum Bus or a Parallel Bus). Click its name to rename it.")
  end
  local ropen = UI.heading("FX Returns", HELP_RETURNS, "returns", "returns")
  UI.undo_button("##undo_returns", "returns")
  if ropen then UI.draw_returns(p) end
end

-- 1 bus, as a card: its switch, color, name, member count and "+ Add"; then its members as chips (x removes one).
function UI.draw_bus(p, i, b)
  ImGui.PushID(ctx, "bus" .. i)
  local c = UI.card_begin("bus" .. i)
  local x0 = ImGui.GetCursorPosX(ctx)
  local right = x0 + c.w - 20
  local ch, v = UI.toggle("##on", b.on)
  UI.tipf("On: Apply makes the %s track and routes its members to it.", b.name)
  if ch then b.on = v; Rules.changed() end
  ImGui.SameLine(ctx, 0, 8)
  local chc, col = ImGui.ColorEdit3(ctx, "##col", b.color or 0x808080,
    ImGui.ColorEditFlags_NoInputs() | ImGui.ColorEditFlags_NoLabel())
  if chc then b.color = col; Rules.changed() end
  UI.tipf("The color of the %s track (when Settings > Appearance > Colors is on).", b.name)
  ImGui.SameLine(ctx, 0, 10)
  -- the name: a field without a frame (click to rename; an empty or used name goes back)
  ImGui.PushFont(ctx, bold)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg(), COL.TRANSPARENT)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text(), b.on and COL.TEXT_MAIN or COL.TEXT_DIM)
  ImGui.SetNextItemWidth(ctx, math.max(80, (ImGui.CalcTextSize(ctx, b.name)) + 24))
  local chn, txt = ImGui.InputText(ctx, "##name", b.name)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopFont(ctx)
  if ImGui.IsItemHovered(ctx) and not ImGui.IsItemActive(ctx) then -- (it looks editable: an underline, a text cursor)
    local ix1, iy1 = ImGui.GetItemRectMin(ctx)
    local _, iy2 = ImGui.GetItemRectMax(ctx)
    ImGui.PushFont(ctx, bold)
    local nw = ImGui.CalcTextSize(ctx, b.name)
    ImGui.PopFont(ctx)
    local ux = ix1 + 10 -- (the field's left padding)
    ImGui.DrawList_AddLine(ImGui.GetWindowDrawList(ctx), ux, iy2 - 4, ux + nw, iy2 - 4, COL.TEXT_DIM, 1)
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_TextInput())
    local _ = iy1
  end
  if ImGui.IsItemActivated(ctx) then R.bus_old = b.name end
  if chn then b.name = (txt:gsub("[|;~%^]", "")) end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then
    local new, old = Util.clean(b.name), R.bus_old or b.name
    local taken = false
    for _, ob in ipairs(p.buses) do if ob ~= b and ob.name:upper() == new:upper() then taken = true end end
    if new == "" or taken then b.name = old
    else
      b.name = new
      if p.fx[old] and not p.fx[new] then p.fx[new] = p.fx[old] end
      for _, rt in ipairs(p.returns) do if rt.out == "b:" .. old then rt.out = "b:" .. new end end
      if old ~= new then p.fx[old] = nil end
    end
    Rules.changed()
  end
  UI.tip("Click to rename this bus.")
  ImGui.SameLine(ctx, 0, 6)
  local n = #b.members
  R.count_txt = R.count_txt or {}
  local ct = R.count_txt[n]
  if not ct then ct = n == 1 and "1 member" or (n .. " members"); R.count_txt[n] = ct end
  UI.row_text(ct, COL.TEXT_DIM)
  local add_w = UI.btn_w(UI.ADD)
  ImGui.SameLine(ctx, 0, 0)
  ImGui.SetCursorPosX(ctx, right - add_w - CFG.X_BTN - 4)
  if UI.button(UI.ADD, add_w, nil, "ghost") then ImGui.OpenPopup(ctx, "##add") end
  UI.tipf("Adds a folder or a track to the %s. A folder or track goes to 1 bus only.", b.name)
  ImGui.SameLine(ctx, 0, 4)
  if UI.remove_x_button("##del", CFG.X_BTN) then R.bus_remove = i end
  UI.tip("Deletes this bus (it asks first).")
  if ImGui.BeginPopup(ctx, "##add") then UI.bus_menu(p, b); ImGui.EndPopup(ctx) end
  -- the members: chips that wrap
  local remove
  local sx = x0 + 26
  if n == 0 then
    ImGui.SetCursorPosX(ctx, sx)
    ImGui.TextColored(ctx, COL.TEXT_DIM, "No members yet. Click + Add.")
  end
  local line_x = sx
  for j, mb in ipairs(b.members) do
    local folder = mb.kind == "f"
    local w = UI.chip_w(mb.name)
    if j > 1 and line_x + w <= right then
      ImGui.SameLine(ctx, 0, 6)
    else
      ImGui.SetCursorPosX(ctx, sx); line_x = sx
    end
    if UI.chip("##m" .. j, mb.name, folder, w) then remove = j end
    UI.tipf(folder and "Folder: the %s folder. Click x to take it out of the %s." or
      "Track: every %s track. Click x to take it out of the %s.", mb.name, b.name)
    line_x = line_x + w + 6
  end
  if remove then table.remove(b.members, remove); Rules.changed() end
  UI.card_end(c)
  ImGui.PopID(ctx)
end
-- The "+ Add" menu of a bus: the folders, then the tracks in a submenu per folder (a tick: already in this bus;
-- "in ...": in another bus, it moves).
function UI.bus_menu(p, b)
  local function other(kind, name)
    for _, ob in ipairs(p.buses) do
      if ob ~= b and UI.bus_has(ob, kind, name) then return ob.name end
    end
  end
  ImGui.TextDisabled(ctx, "Folders")
  for k, f in ipairs(Rules.folders(p)) do
    local has, o = UI.bus_has(b, "f", f), other("f", f)
    if ImGui.Selectable(ctx, f .. (o and ("   (in " .. o .. ")") or "") .. "##f" .. k, has) and not has then
      UI.bus_add(p, b, "f", f)
    end
  end
  ImGui.Separator(ctx)
  ImGui.TextDisabled(ctx, "Tracks")
  local groups = Rules.folders(p)
  for k = 1, #groups + 1 do
    local f = groups[k] or ""
    local any = false
    for _, ru in ipairs(p.rules) do if Util.clean(ru.folder) == f and Util.clean(ru.name) ~= "" then any = true; break end end
    if any and ImGui.BeginMenu(ctx, (f ~= "" and f or "No folder") .. "##g" .. k) then
      local seen = {}
      for q, ru in ipairs(p.rules) do
        local nm = Util.clean(ru.name)
        if Util.clean(ru.folder) == f and nm ~= "" and not seen[nm] then
          seen[nm] = true
          local has, o = UI.bus_has(b, "t", nm), other("t", nm)
          if ImGui.Selectable(ctx, nm .. (o and ("   (in " .. o .. ")") or "") .. "##t" .. q, has) and not has then
            UI.bus_add(p, b, "t", nm)
          end
        end
      end
      ImGui.EndMenu(ctx)
    end
  end
end
function UI.bus_has(b, kind, name)
  for _, mb in ipairs(b.members) do if mb.kind == kind and mb.name == name then return true end end
  return false
end
-- Adds a member to a bus, and takes it out of the other buses (a track or folder goes to 1 bus only).
function UI.bus_add(p, b, kind, name)
  for _, ob in ipairs(p.buses) do
    for j = #ob.members, 1, -1 do
      if ob.members[j].kind == kind and ob.members[j].name == name then table.remove(ob.members, j) end
    end
  end
  b.members[#b.members + 1] = { kind = kind, name = name }
  Rules.changed()
end

-- The FX returns of the preset (name, FX chain), the sends matrix (folder -> return) and the send level.
function UI.draw_returns(p)
  local ch, v = UI.form_toggle("Make FX returns and sends", S.returns,
    "On: Apply makes these return tracks (in an \"FX Returns\" folder at the bottom) and the sends to them. "
    .. "A track with the same name is used again. Off by default.")
  if ch then S.returns = v; Util.mark_sdirty() end
  ImGui.BeginDisabled(ctx, not S.returns)
  local remove
  local card = UI.card_begin("returns")
  local rx0 = ImGui.GetCursorPosX(ctx)
  local right = rx0 + card.w - 20
  for i, rt in ipairs(p.returns) do
    ImGui.PushID(ctx, "rt" .. i)
    local chc, c = ImGui.ColorEdit3(ctx, "##col", rt.color or 0x808080,
      ImGui.ColorEditFlags_NoInputs() | ImGui.ColorEditFlags_NoLabel())
    if chc then rt.color = c; Rules.changed() end
    UI.tip("The color of this return (when Settings > Appearance > Colors is on).")
    ImGui.SameLine(ctx, 0, 8)
    ImGui.SetNextItemWidth(ctx, 110)
    local chn, txt = ImGui.InputText(ctx, "##name", rt.name)
    if chn then
      local new = (txt:gsub("[|;~%^]", ""))
      for _, set in pairs(p.sends) do
        if set[rt.name] then set[rt.name] = nil; set[new] = true end
      end
      rt.name = new; Util.mark_sdirty()
    end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then Rules.changed() end
    ImGui.SameLine(ctx, 0, CFG.CTRL_GAP)
    local file = rt.chain ~= "" and rt.chain:match("([^/\\]+)$") or "(no FX chain)"
    local pick_w = UI.btn_w("...")
    local pick_x = right - CFG.X_BTN - 4 - pick_w
    UI.row_text(UI.trunc(file, math.max(40, pick_x - ImGui.GetCursorPosX(ctx) - 8)),
      (rt.chain ~= "" and r.file_exists(rt.chain)) and COL.TEXT_MAIN or COL.TEXT_DIM)
    if rt.chain ~= "" then UI.tip(rt.chain) end
    ImGui.SameLine(ctx, 0, 0)
    ImGui.SetCursorPosX(ctx, pick_x)
    if UI.button("...", pick_w) then
      local dir = (r.GetResourcePath() .. "/FXChains/"):gsub("/", "\\")
      local okf, pick = r.GetUserFileNameForRead(rt.chain ~= "" and rt.chain or dir, "FX chain for " .. rt.name, ".RfxChain")
      if okf and pick ~= "" then rt.chain = Rules.safe(pick); Rules.changed() end
    end
    UI.tip("Pick the FX chain of this return (for example your plate reverb). Apply adds it to a new return track.")
    ImGui.SameLine(ctx, 0, 4)
    if UI.remove_x_button("##x", CFG.X_BTN) then remove = i end
    UI.tip("Removes this return.")
    UI.return_routing(p, rt, rx0 + 32)
    UI.vgap(10)
    ImGui.PopID(ctx)
  end
  if remove then
    local name = p.returns[remove].name
    table.remove(p.returns, remove)
    for _, set in pairs(p.sends) do set[name] = nil end
    Rules.changed()
  end
  if UI.button("+ Return", UI.btn_w("+ Return"), nil, "ghost") then
    local n, used = 1, {}
    for _, rt in ipairs(p.returns) do used[rt.name] = true end
    while used["Return " .. n] do n = n + 1 end
    p.returns[#p.returns + 1] = { name = "Return " .. n, chain = "", color = 0x5E9C96, src = "t", db = -12, out = "m" }
    Rules.changed()
  end
  UI.tip("Adds a return (for example a 2nd delay).")
  UI.card_end(card)
  -- the sends: a folder (row) sends to a return (column)
  local folders = Rules.folders(p)
  if #folders > 0 and #p.returns > 0 then
    UI.vgap(10)
    local aw = ImGui.GetContentRegionAvail(ctx) - 10
    local flags = ImGui.TableFlags_BordersInnerH() | ImGui.TableFlags_SizingStretchSame()
    if ImGui.BeginTable(ctx, "##sends", #p.returns + 1, flags, aw) then
      ImGui.TableSetupColumn(ctx, "Sends", ImGui.TableColumnFlags_WidthFixed(), 90)
      for _, rt in ipairs(p.returns) do ImGui.TableSetupColumn(ctx, rt.name, ImGui.TableColumnFlags_WidthStretch(), 1) end
      ImGui.TableNextRow(ctx, ImGui.TableRowFlags_Headers()) -- (plain titles: not clickable)
      ImGui.TableNextColumn(ctx)
      ImGui.TextColored(ctx, COL.TEXT_DIM, "Sends")
      for _, rt in ipairs(p.returns) do
        ImGui.TableNextColumn(ctx)
        ImGui.TextColored(ctx, COL.TEXT_DIM, UI.trunc(rt.name, ImGui.GetContentRegionAvail(ctx)))
      end
      for i, f in ipairs(folders) do
        ImGui.PushID(ctx, "sd" .. i)
        ImGui.TableNextRow(ctx, 0, ImGui.GetFrameHeight(ctx))
        ImGui.TableNextColumn(ctx)
        UI.row_text(f)
        for j, rt in ipairs(p.returns) do
          ImGui.TableNextColumn(ctx)
          local on = p.sends[f] and p.sends[f][rt.name] or false
          local chb, nv = ImGui.Checkbox(ctx, "##s" .. j, on)
          if chb then
            p.sends[f] = p.sends[f] or {}
            p.sends[f][rt.name] = nv or nil
            Rules.changed()
          end
          UI.tip("Every " .. f .. " track sends to " .. rt.name .. " (post-fader).")
        end
        ImGui.PopID(ctx)
      end
      ImGui.EndTable(ctx)
    end
  end
  ImGui.EndDisabled(ctx)
end

-- The routing of 1 return (its 2nd line): Source (the tracks or the folder track send), Level (the send level, post-
-- fader), Out (the master, a folder or a bus; a folder that feeds the return itself would loop: Apply skips it).
local RET_SRC = { t = "Tracks", f = "Folder" }
function UI.return_routing(p, rt, x)
  ImGui.SetCursorPosX(ctx, x)
  UI.row_text("Source", COL.TEXT_DIM)
  ImGui.SameLine(ctx, 0, 6)
  ImGui.SetNextItemWidth(ctx, 90)
  if ImGui.BeginCombo(ctx, "##src", RET_SRC[rt.src] or "Tracks") then
    for _, k in ipairs({ "t", "f" }) do
      if ImGui.Selectable(ctx, RET_SRC[k], rt.src == k) and rt.src ~= k then rt.src = k; Rules.changed() end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Tracks: every ticked track sends (post-fader). Folder: the folder track sends once (for example a parallel "
    .. "compressor fed by the whole drum folder).")
  ImGui.SameLine(ctx, 0, 12)
  UI.row_text("Level", COL.TEXT_DIM)
  ImGui.SameLine(ctx, 0, 6)
  ImGui.SetNextItemWidth(ctx, 80)
  local chd, db = ImGui.DragDouble(ctx, "##db", rt.db or -12, 0.1, -40, 6, "%.1f dB")
  if chd then rt.db = math.floor(db * 10 + 0.5) / 10; Util.mark_sdirty() end
  if ImGui.IsItemDeactivatedAfterEdit(ctx) then Rules.changed() end
  UI.tip("The level of the sends to this return (post-fader). A parallel compressor: usually 0 dB. Drag, or double-click to type.")
  ImGui.SameLine(ctx, 0, 12)
  UI.row_text("Out", COL.TEXT_DIM)
  ImGui.SameLine(ctx, 0, 6)
  ImGui.SetNextItemWidth(ctx, 140)
  local out = rt.out or "m"
  local label = out == "m" and "Master" or out:sub(3)
  if ImGui.BeginCombo(ctx, "##out", label) then
    if ImGui.Selectable(ctx, "Master", out == "m") and out ~= "m" then rt.out = "m"; Rules.changed() end
    ImGui.Separator(ctx)
    ImGui.TextDisabled(ctx, "Folders")
    for k, f in ipairs(Rules.folders(p)) do
      if ImGui.Selectable(ctx, f .. "##of" .. k, out == "f:" .. f) then rt.out = "f:" .. f; Rules.changed() end
    end
    ImGui.Separator(ctx)
    ImGui.TextDisabled(ctx, "Buses")
    for k, b in ipairs(p.buses) do
      if ImGui.Selectable(ctx, b.name .. "##ob" .. k, out == "b:" .. b.name) then rt.out = "b:" .. b.name; Rules.changed() end
    end
    ImGui.EndCombo(ctx)
  end
  UI.tip("Where the return goes: the master, or into a folder or a bus (so it follows that fader: for example Drum "
    .. "Crush into the drum folder). A return into the folder that feeds it with Source Folder would loop: Apply skips that send.")
end

-- A Settings row as in MIDI Pilot: the bold label in the label column, the control at the right of it (narrow
-- window: below it). Returns the x of the control.
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

-- The Settings tab: Appearance, Prep, Gain staging, Window (collapsing sections, 1 open at a time, as in MIDI Pilot).
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
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Session Prep " .. CFG.VERSION .. "  -  MIT license")
end

local CAPS = { { "all", "All" }, { "fb", "Folders and buses" }, { "buses", "Buses only" }, { "none", "None" } }
function UI.draw_settings_appearance()
  local ch
  ch, S.light = UI.form_toggle("Light theme", S.light, "On: light panels and fields, dark text. Off: Dark (the default).")
  if ch then apply_theme(S.light); Util.mark_sdirty() end
  ch, S.color = UI.form_toggle("Colors", S.color,
    "On: Apply colors the tracks, folders, buses and returns with the colors of the rules, buses and returns. Off by default.")
  if ch then Util.mark_sdirty() end
  ImGui.BeginDisabled(ctx, not S.color)
  ch, S.color_win = UI.form_toggle("Colors win over SWS", S.color_win,
    "Off (default): when SWS Auto Color is on, SWS colors the tracks and Session Prep does not.\n"
    .. "On: Apply turns SWS Auto Color off, then colors the tracks (turn it on again in SWS).")
  if ch then Util.mark_sdirty() end
  ImGui.EndDisabled(ctx)
  if S.color and Prep.sws_autocolor() then
    ImGui.TextColored(ctx, COL.TEXT_DIM, S.color_win and "SWS Auto Color is on: Apply turns it off, then colors."
      or "SWS Auto Color is on: SWS colors the tracks, not Session Prep.")
  end
  UI.form_label("Capital letters", "The names that Apply writes in capitals (KICK IN, DRUMS, INSTRUMENT BUS). Default: All.")
  local cur = "All"
  for _, c in ipairs(CAPS) do if c[1] == S.caps then cur = c[2] end end
  ImGui.SetNextItemWidth(ctx, 180)
  if ImGui.BeginCombo(ctx, "##caps", cur) then
    for _, c in ipairs(CAPS) do
      if ImGui.Selectable(ctx, c[2], S.caps == c[1]) and S.caps ~= c[1] then S.caps = c[1]; Rules.changed() end
    end
    ImGui.EndCombo(ctx)
  end
  ch, S.spacer = UI.form_toggle("Spacer between folders", S.spacer,
    "On: Apply puts a spacer (a small gap in the track list) above each new folder and bus track, except the first.")
  if ch then Util.mark_sdirty() end
end

function UI.draw_settings_window()
  local docked = R.docked == true
  if UI.form_toggle("Dock in REAPER's docker", docked, "On: Session Prep is in a REAPER docker. Off: a floating window.") then
    R.dock_req = docked and 0 or (S.dock ~= 0 and S.dock or -1)
  end
  UI.form_label("Window position")
  if UI.button("Reset", UI.btn_w("Reset", 90)) then R.reset_win = true end
  UI.tip("Moves the window back to its default size and place, and undocks it.")
end

-- (the headings inside a Settings section: the normal heading, as in MIDI Pilot's Settings)
local PREP_HELP_TRACKS = [[Folders: Apply puts the tracks in folders, in the folder order of the Rules tab.
Pan L / R tracks: a track with L or R in its name starts with its Pan button at L or R.
Pan width: a Width column in the Prep table (each L / R track's width).
Disarm tracks: Apply turns off record arm and input monitoring.

Saved on this computer.]]
local PREP_HELP_ROUTING = [[Other: no master output: the Other folder (click, guide, talkback) never reaches the mix.

Saved on this computer.]]
local PREP_HELP_CHECKS = [[Check audio: Scan reads the audio and finds empty and silent tracks, fake stereo and one silent side.

Saved on this computer.]]
function UI.draw_settings_prep()
  local ch
  UI.heading("Tracks", PREP_HELP_TRACKS, "s_tracks")
  ch, S.folders = UI.form_toggle("Folders", S.folders,
    "On: Apply puts the tracks in folders (from the rules) in the folder order of the Rules tab (drag a folder header). "
    .. "Off: the tracks stay where they are.")
  if ch then Util.mark_sdirty() end
  ch, S.pairs = UI.form_toggle("Pan L / R tracks", S.pairs,
    "On: a track with L or R in its name (\"OH L\", \"Gtr 1 R\") starts with its Pan button at L or R. "
    .. "Off: every Pan button starts at \"-\" (the pan stays as it is).")
  if ch then Util.mark_sdirty() end
  ch, S.pan_w_on = UI.form_toggle("Pan width", S.pan_w_on,
    "On: the Prep table gets a Width column: set how far each L / R track pans (100 % = hard). Off (default): hard "
    .. "left / right, as a reminder to set them by ear.")
  if ch then Util.mark_sdirty() end
  ch, S.disarm = UI.form_toggle("Disarm tracks", S.disarm,
    "On (default): Apply turns off record arm and input monitoring on the ticked tracks (a client's session can come with armed tracks).")
  if ch then Util.mark_sdirty() end
  UI.heading("Routing", PREP_HELP_ROUTING, "s_routing")
  ch, S.other_off = UI.form_toggle("Other: no master output", S.other_off,
    "On (default): the Other folder (click, guide, talkback) gets no output to the master, so it never reaches the mix. "
    .. "Route it to your headphone output yourself.")
  if ch then Util.mark_sdirty() end
  UI.heading("Checks", PREP_HELP_CHECKS, "s_checks")
  ch, S.audio = UI.form_toggle("Check audio", S.audio,
    "On: Scan reads the audio and finds silent tracks, fake stereo and one silent side. A large session takes a few seconds.")
  if ch then Util.mark_sdirty() end
end

function UI.draw_settings_gain()
  local ch
  ch, S.gain = UI.form_toggle("Gain staging", S.gain,
    "On: Scan measures the level of each track, and Apply changes its item gain (clip gain) to the target. "
    .. "The faders stay as they are. Off by default.")
  if ch then Rules.changed() end
  ImGui.BeginDisabled(ctx, not S.gain)
  do -- Target: RMS / Peak
    UI.form_label("Target")
    ImGui.SetNextItemWidth(ctx, 110)
    if ImGui.BeginCombo(ctx, "##gain_mode", S.gain_by_peak and "Peak" or "RMS") then
      if ImGui.Selectable(ctx, "RMS", not S.gain_by_peak) and S.gain_by_peak then S.gain_by_peak = false; Rules.changed() end
      if ImGui.Selectable(ctx, "Peak", S.gain_by_peak) and not S.gain_by_peak then S.gain_by_peak = true; Rules.changed() end
      ImGui.EndCombo(ctx)
    end
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then
      ImGui.SetTooltip(ctx, "RMS (default): every track gets the same average level; the peaks follow.\n"
        .. "Peak: every track's peak goes to the target peak.")
    end
  end
  local function db_field(label, key, lo, hi, tip)
    UI.form_label(label)
    ImGui.SetNextItemWidth(ctx, 110)
    local chg, v = ImGui.DragDouble(ctx, "##" .. key, S[key], 0.1, lo, hi, "%.1f dBFS")
    if chg then S[key] = Util.clamp(math.floor(v * 10 + 0.5) / 10, lo, hi); Util.mark_sdirty() end
    if ImGui.IsItemDeactivatedAfterEdit(ctx) then Rules.changed() end
    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled()) then ImGui.SetTooltip(ctx, tip) end
  end
  if S.gain_by_peak then
    db_field("Target peak", "gain_ptarget", -30, 0, "The peak of each track after Apply (default -10 dBFS). "
      .. "The peaks are measured fast, so the real peak can be a little higher. Drag, or double-click to type.")
  else
    db_field("Target RMS", "gain_rms", -40, -6, "The average level of each track after Apply (default -18 dBFS). "
      .. "Pauses are not in the average. Drag, or double-click to type.")
    db_field("Peak limit", "gain_peak", -24, 0, "The gain never takes a peak above this level (default -6 dBFS). "
      .. "The peaks are measured fast and can be missed, so Session Prep keeps 1 dB more room under this limit.")
  end
  ImGui.EndDisabled(ctx)
end

SETTINGS_SECTIONS = {
  { "Appearance", UI.draw_settings_appearance }, { "Prep", UI.draw_settings_prep },
  { "Gain staging", UI.draw_settings_gain }, { "Window", UI.draw_settings_window },
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
  ImGui.TextColored(ctx, COL.TEXT_DIM, "Session Prep " .. CFG.VERSION .. "  -  MIT license")
  ImGui.PopTextWrapPos(ctx)
end

-- The window: the tab strip, then the panel of the tab (the Prep table scrolls by itself).
function UI.draw_main()
  UI.vgap(CFG.SP_EDGE)
  UI.draw_tabs()
  local aw, ah = ImGui.GetContentRegionAvail(ctx)
  local nh = UI.notice_h(aw - 16)
  ah = ah - CFG.SP_EDGE - nh
  local px, py = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), px, py, px + aw, py + ah, COL.PANEL_BG, 8,
    ImGui.DrawFlags_RoundCornersBottom())
  local child_flags = S.tab == TAB_PREP and ImGui.WindowFlags_NoScrollbar() or 0
  if ImGui.BeginChild(ctx, "##panel" .. S.tab, aw, ah, 0, child_flags) then
    ImGui.SetCursorPosY(ctx, CFG.SP_PANEL)
    ImGui.Indent(ctx, 10)
    ImGui.PushItemWidth(ctx, ImGui.GetContentRegionAvail(ctx) - 10)
    if S.tab == TAB_PREP then UI.draw_prep()
    elseif S.tab == TAB_RULES then UI.draw_rules()
    elseif S.tab == TAB_FX then UI.draw_fx()
    elseif S.tab == TAB_BUSES then UI.draw_buses()
    elseif S.tab == TAB_SETTINGS then UI.draw_settings()
    else UI.draw_help() end
    ImGui.Dummy(ctx, 0, CFG.SP_PANEL)
    ImGui.PopItemWidth(ctx)
    ImGui.Unindent(ctx, 10)
    ImGui.EndChild(ctx)
  end
  if nh > 0 then -- the notice, below the panel
    local n = R.notice
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
  if R.scan and r.EnumProjects(-1) ~= R.scan.proj then R.scan, R.rows = nil, nil end -- (another project tab)
  if R.scanning then
    if r.EnumProjects(-1) ~= R.scanning.proj then R.scanning = nil else Prep.scan_step(CFG.SCAN_BUDGET) end
  end
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
    if not R.docked then UI.edges() else R.rs = nil end -- resize edges: floating only
    ImGui.End(ctx)
  end
  UI.pop_style()
  ImGui.PopFont(ctx)
  if R.sdirty and not ImGui.IsMouseDown(ctx, 0) and not ImGui.IsAnyItemActive(ctx) then Util.save_settings() end
  if open then r.defer(loop) end
end

local function on_exit()
  if R.sdirty then Util.save_settings() end
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end

-- A second start closes the running Session Prep (REAPER 7: no question).
if r.set_action_options then r.set_action_options(1) end
do
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end
end
Util.load_settings()
apply_theme(S.light)
r.atexit(on_exit)
r.defer(loop)
