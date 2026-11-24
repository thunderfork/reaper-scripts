-- @noindex
-- Tab Viewer tests (and the shared Guitar Pro reader). Run with .\tools\test.ps1 -Script "Tab Viewer" (it starts the
-- portable test REAPER in C:\REAPERtest). Loads Tab Viewer.lua without its window, runs each test, writes
-- tests\result_tabviewer.txt, quits REAPER. The test data (tabviewer_data.lua) is made up: no real song.
local r = reaper
local here = ({ r.get_action_context() })[2]:match("^(.*)[/\\]")
local out = {}
local passed, failed = 0, 0
local function log(s) out[#out + 1] = s end
local function eq(a, b, what)
  if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function ok(v, what) if not v then error((what or "check") .. " failed", 2) end end
local function near(a, b, tol, what) ok(math.abs(a - b) <= tol, (what or "value") .. ": " .. tostring(a) .. " is not about " .. tostring(b)) end
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

-- the test folders: 3 projects (a, b, c) and the files to open (src); the copies of an earlier run go first
local tmp = r.GetResourcePath() .. "\\TabViewerTests"
for _, d in ipairs({ "a", "b", "c", "src", "src2" }) do r.RecursiveCreateDirectory(tmp .. "\\" .. d, 0) end
for _, f in ipairs({ "a\\Tabs\\Song.gp", "a\\Tabs\\Song (2).gp", "b\\Tabs\\Song.gp", "c\\Tabs\\Song.gp" }) do os.remove(tmp .. "\\" .. f) end
local function write(path, data)
  local f = io.open(path, "wb")
  if f then f:write(data); f:close() end
end
local function exists(path) return r.file_exists(path) end
local proj_a, proj_b, proj_c = tmp .. "\\a\\song.rpp", tmp .. "\\b\\other.rpp", tmp .. "\\c\\copy.rpp"
for _, p in ipairs({ proj_a, proj_b }) do write(p, "<REAPER_PROJECT 0.1\n  TEMPO 120 4 4\n>\n") end
r.Main_openProject("noprompt:" .. proj_a)

local function finish()
  log(string.format("%d passed, %d failed", passed, failed))
  local f = io.open(here .. "\\result_tabviewer.txt", "w")
  if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  r.Main_SaveProject(0, false)
  r.defer(function() r.Main_OnCommand(40004, 0) end) -- File: Quit REAPER
end

TabViewerTest = {}
local loaded, err = pcall(dofile, here .. "\\..\\Tab Viewer\\Tab Viewer.lua")
local C = TabViewerTest
if not loaded or not C.Project then
  log("FAIL  load Tab Viewer.lua: " .. tostring(err)); failed = 1; finish(); return
end
local GP, Tabs, Project, R = C.GP, C.Tabs, C.Project, C.R
local D = dofile(here .. "\\tabviewer_data.lua")
log(string.format("REAPER %s in %s, Tab Viewer %s loaded", r.GetAppVersion(), r.GetResourcePath(), C.CFG.VERSION))
Project.update()

local src = tmp .. "\\src\\Song.gp"
write(src, D.GP_FILE)
write(tmp .. "\\src2\\Song.gp", D.GP_FILE .. "another tab") -- (the same name, other content: still a zip)

-- GUITAR PRO READER ------------------------------------------------------

test("unpack: the 3 kinds of deflate blocks (fixed, stored, dynamic); damaged data stops with an error", function()
  eq(GP.inflate(D.INF_FIXED), "Hello, bass player!", "fixed")
  eq(GP.inflate(D.INF_STORED), D.INF_TEXT, "stored")
  eq(GP.inflate(D.INF_DYNAMIC), D.GPIF, "dynamic")
  eq(pcall(GP.inflate, "\255\255\255\255"), false, "a damaged block")
  eq(pcall(GP.inflate, D.INF_DYNAMIC:sub(1, 40)), false, "cut short")
end)

test("unzip: the score of a .gp file; a file without a score", function()
  eq(GP.unzip(D.GP_FILE, "Content/score.gpif"), D.GPIF)
  local x, why = GP.unzip(D.GP_NOSCORE, "Content/score.gpif")
  eq(x, nil); eq(why, "missing")
  eq(select(2, GP.unzip("not a zip at all, just text", "Content/score.gpif")), "damaged")
end)

test("read: the tracks of a .gp file (instrument, strings, tuning, capo), the tempo and the bars", function()
  local doc, why = GP.read(src)
  ok(doc, "read: " .. tostring(why))
  eq(#doc.tracks, 4); eq(#doc.mbars, 3)
  local t = {}
  for k, tr in ipairs(doc.tracks) do t[k] = string.format("%s:%s:%s:%s:%d", tr.name, tr.kind, tr.inst, table.concat(tr.open, " "), tr.capo) end
  eq(table.concat(t, " | "), "Bass:bass:Electric Bass:28 33 38 43:0 | Rhythm Guitar:guitar:Electric Guitar:38 45 50 55 59 64:2"
    .. " | Drums:drums:Drums::0 | Keys:other:Electric Piano:35 40 45 50 55 59 64:0", "the drums have no strings")
  eq(doc.tempo, 120, "the first tempo"); eq(doc.tempos, 2, "2 tempo marks (the other automation is not one)")
end)

test("read: the notes of a track (ties, dots, triplets, muted notes, grace notes, repeats, 3/4)", function()
  local doc = GP.parse(D.GPIF)
  eq(table.concat(GP.order(doc.mbars), " "), "1 2 2 3", "bar 2 twice")
  local t = {}
  for k, x in ipairs(GP.notes(doc, 1)) do t[k] = string.format("%.2f+%.2f %d s%d f%d", x.q, x.len, x.midi, x.s, x.fret) end
  eq(table.concat(t, " | "), "0.00+4.00 36 s2 f3 | 4.00+1.50 40 s3 f2 | 8.00+1.50 40 s3 f2 | 12.00+0.33 43 s4 f0",
    "the tie joins, the muted note is left out, the grace note takes no time (bar 2), the repeat plays twice, the triplet")
  eq(#GP.notes(doc, 2), 0, "a track with no bars: no notes")
end)

test("read: the repeat bar marks (%) play the bar before, or the 2 bars before", function()
  local doc = GP.parse(D.GPIF)
  -- after the 3/4 bar (G): a bar with a 1-bar repeat mark, then a 4/4 bar with an A, then a 2-bar repeat mark
  doc.bars["3"] = "<Clef>F4</Clef><SimileMark>Simple</SimileMark><Voices>-1 -1 -1 -1</Voices>"
  doc.bars["4"] = "<Clef>F4</Clef><Voices>3 -1 -1 -1</Voices>"
  doc.voices["3"] = "<Beats>5</Beats>"
  doc.beats["5"] = '<Rhythm ref="3" /><Notes>5</Notes>'
  doc.rhythms["3"] = "<NoteValue>Whole</NoteValue>"
  doc.notes["5"] = '<Properties><Property name="Fret"><Fret>0</Fret></Property><Property name="Midi"><Number>33</Number></Property><Property name="String"><String>1</String></Property></Properties>'
  doc.bars["5"] = "<Clef>F4</Clef><SimileMark>FirstOfDouble</SimileMark><Voices>-1 -1 -1 -1</Voices>"
  doc.bars["6"] = "<Clef>F4</Clef><SimileMark>SecondOfDouble</SimileMark><Voices>-1 -1 -1 -1</Voices>"
  for _, b in ipairs({ { 3, "3" }, { 4, "4" }, { 3, "5" }, { 4, "6" } }) do
    doc.mbars[#doc.mbars + 1] = { num = b[1], den = 4, bars = { b[2] }, count = 0 }
  end
  local t = {}
  for _, x in ipairs(GP.notes(doc, 1)) do if x.q >= 12 then t[#t + 1] = string.format("%.2f %d", x.q, x.midi) end end
  eq(table.concat(t, " | "), "12.00 43 | 15.00 43 | 18.00 33 | 22.00 43 | 25.00 33",
    "the G bar again, the A bar, then the G and A bars again")
end)

-- A small made-up Guitar Pro 3 / 4 / 5 file (v: 300, 400, 500 or 510), written from the same format notes as the
-- reader (Guitar Pro 5.1: checked on a real file too). 3 tracks (guitar in Drop D with capo 2, bass, drums), 4 bars:
-- bar 1 a repeat start, bar 2 ending 1 and the repeat end (plays twice), bar 3 ending 2, bar 4 in 3/4. Its guitar:
-- bar 1 D2 (a chord diagram, a text, beat effects), a dotted B2 (note effects) tied to an 8th, a rest; bar 2 3
-- triplet 8ths, a dead note, a half E4 with a tempo change; bar 3 a whole G2; bar 4 a dotted half D2 and an empty beat.
local function old_file(v)
  local b = {}
  local function u8(x) b[#b + 1] = string.char(x & 0xFF) end
  local function i16(x) b[#b + 1] = string.pack("<i2", x) end
  local function i32(x) b[#b + 1] = string.pack("<i4", x) end
  local function zeros(n) b[#b + 1] = string.rep("\0", n) end
  local function bstr(s, size) u8(#s); b[#b + 1] = s .. string.rep("\0", size - #s) end
  local function istr(s) i32(#s); b[#b + 1] = s end
  local function ibstr(s) i32(#s + 1); u8(#s); b[#b + 1] = s end
  local function bend() u8(1); i32(50); i32(2); for _ = 1, 2 do i32(0); i32(50); u8(0) end end
  bstr("FICHIER GUITAR PRO " .. ({ [300] = "v3.00", [400] = "v4.06", [500] = "v5.00", [510] = "v5.10" })[v], 30)
  ibstr("Test Song")
  for _ = 1, (v >= 500 and 8 or 7) do ibstr("") end
  i32(1); ibstr("a notice")
  local function lyrics() i32(0); for _ = 1, 5 do i32(1); istr("") end end
  if v < 400 then u8(0); i32(100); i32(0)
  elseif v < 500 then u8(0); lyrics(); i32(100); i32(0); u8(0)
  else
    lyrics()
    if v > 500 then i32(100); i32(0); zeros(11) end
    zeros(28); i16(0x1FF)
    for _ = 1, 10 do ibstr("") end
    ibstr("Moderate"); i32(100)
    if v > 500 then u8(0) end
    u8(0); i32(0)
  end
  for c = 1, 64 do i32(c == 1 and 29 or c == 2 and 33 or 0); zeros(8) end -- (programs: 1 overdrive guitar, 2 bass)
  if v >= 500 then for _ = 1, 19 do i16(-1) end i32(0) end
  i32(4); i32(3)
  -- the bars: flags, then num, den, repeat end, and the alternate ending, marker, key in the order of the version
  local heads = { { f = 1 | 2 | 4 | 32, num = 4, marker = "Intro" }, { f = 8 | 16, close = true, alt = 1 }, { f = 16, alt = 2 },
    { f = 1, num = 3 } }
  for k, h in ipairs(heads) do
    if v >= 500 and k > 1 then u8(0) end
    u8(h.f)
    if h.f & 1 ~= 0 then u8(h.num) end
    if h.f & 2 ~= 0 then u8(4) end
    if h.close then u8(v >= 500 and 2 or 1) end -- (Guitar Pro 5: how often it plays; 3 and 4: how often it repeats)
    local function alt() u8(v >= 500 and (1 << (h.alt - 1)) or h.alt) end
    local function marker() ibstr(h.marker); zeros(4) end
    if v < 500 then
      if h.f & 16 ~= 0 then alt() end
      if h.f & 32 ~= 0 then marker() end
    else
      if h.f & 32 ~= 0 then marker() end
      if h.f & 16 ~= 0 then alt() end
      if h.f & 3 ~= 0 then zeros(4) end
      if h.f & 16 == 0 then u8(0) end
      u8(0)
    end
  end
  -- the tracks (the strings from the highest)
  local function track(t, flags, name, tun, chan, capo)
    if v >= 500 and (t == 1 or v == 500) then u8(0) end
    u8(flags); bstr(name, 40); i32(#tun)
    for i = 1, 7 do i32(tun[i] or 0) end
    i32(1); i32(chan); i32(chan); i32(24); i32(capo); zeros(4)
    if v >= 500 then
      zeros(4 + 25 + (v == 500 and 15 or 16))
      if v > 500 then zeros(4); ibstr("Clean"); ibstr("Amp") end
    end
  end
  track(1, 0, "Rhythm", { 64, 59, 55, 50, 45, 38 }, 1, 2)
  track(2, 0, "Low end", { 43, 38, 33, 28 }, 2, 0)
  track(3, 1, "Kit", { 0, 0, 0, 0, 0, 0 }, 10, 0)
  if v >= 500 then zeros(v == 500 and 2 or 1) end
  -- the beats and notes
  local function note(n)
    local f = 0x20 | (n.eff and 0x08 or 0) | (n.more and (0x10 | 0x80 | 0x01) or 0)
    u8(f); u8(n.typ or 1)
    if v < 500 and f & 0x01 ~= 0 then u8(0); u8(0) end
    if f & 0x10 ~= 0 then u8(6) end
    u8(n.fret)
    if f & 0x80 ~= 0 then u8(1); u8(1) end
    if v >= 500 then
      if f & 0x01 ~= 0 then b[#b + 1] = string.pack("<d", 1.0) end
      u8(0)
    end
    if n.eff then
      if v < 400 then u8(0x01 | 0x04 | 0x10); bend(); zeros(4)
      else
        u8(0x01 | 0x10); u8(0x04 | 0x08 | 0x10 | 0x20)
        bend(); zeros(v >= 500 and 5 or 4); u8(0); u8(1)
        if v >= 500 then u8(2); zeros(3) else u8(1) end
        zeros(2)
      end
    end
  end
  local function beat(o)
    local f = (o.dot and 1 or 0) | (o.chord and 2 or 0) | (o.text and 4 or 0) | (o.beff and 8 or 0) | (o.mix and 16 or 0)
      | (o.tup and 32 or 0) | (o.status and 64 or 0)
    u8(f)
    if o.status then u8(o.status) end
    u8(o.dur)
    if o.tup then i32(o.tup) end
    if o.chord then
      if v >= 500 then zeros(17); bstr("D5", 21); zeros(4); i32(0); for _ = 1, 7 do i32(-1) end zeros(32)
      elseif v >= 400 then u8(1); zeros(16); bstr("D5", 22); zeros(67) -- (the new chord format: the name at 16)
      else u8(0); ibstr("D5"); i32(1); for _ = 1, 6 do i32(-1) end end -- (the old one)
    end
    if o.text then ibstr(o.text) end
    if o.beff then
      if v < 400 then u8(0x20 | 0x40); u8(1); i32(0); u8(0); u8(0)
      else u8(0x20 | 0x40); u8(0x04 | 0x02); u8(1); bend(); u8(0); u8(0); u8(1) end
    end
    if o.mix then
      u8(29)
      if v >= 500 then zeros(16) end
      u8(100); for _ = 1, 5 do u8(0xFF) end -- (a volume, the others no change)
      if v >= 500 then ibstr("") end
      i32(120)
      u8(0); u8(0)
      if v > 500 then u8(0) end
      if v >= 400 then u8(0) end
      if v >= 500 then u8(0) end
      if v > 500 then ibstr("British"); ibstr("Distortion") end
    end
    local notes = o.notes or {}
    table.sort(notes, function(x, y) return x.gs < y.gs end)
    local sf = 0
    for _, n in ipairs(notes) do sf = sf | (1 << (7 - n.gs)) end
    u8(sf)
    for _, n in ipairs(notes) do note(n) end
    if v >= 500 then i16(0) end
  end
  local music = {
    { -- (the guitar)
      { { dur = 0, chord = true, text = "riff", beff = true, notes = { { gs = 6, fret = 0 } } },
        { dur = 0, dot = true, notes = { { gs = 5, fret = 2, eff = true } } },
        { dur = 1, notes = { { gs = 5, fret = 0, typ = 2 } } }, { dur = 0, status = 2 } },
      { { dur = 1, tup = 3, notes = { { gs = 4, fret = 0 } } }, { dur = 1, tup = 3, notes = { { gs = 4, fret = 2 } } },
        { dur = 1, tup = 3, notes = { { gs = 4, fret = 4 } } }, { dur = 0, notes = { { gs = 3, fret = 5, typ = 3 } } },
        { dur = -1, mix = true, notes = { { gs = 1, fret = 0 } } } },
      { { dur = -2, notes = { { gs = 6, fret = 5, more = true } } } },
      { { dur = -1, dot = true, notes = { { gs = 6, fret = 0 } } }, { dur = 0, status = 0 } },
    },
    { -- (the bass)
      { { dur = -2, notes = { { gs = 4, fret = 0 } } } }, { { dur = -2, notes = { { gs = 3, fret = 2 } } } },
      { { dur = -2, notes = { { gs = 2, fret = 0 } } } }, { { dur = -1, dot = true, notes = { { gs = 1, fret = 2 } } } },
    },
    { -- (the drums: kick and hi-hat, then rests)
      { { dur = 0, notes = { { gs = 6, fret = 36 }, { gs = 5, fret = 42 } } }, { dur = 0, status = 2 }, { dur = -1, status = 2 } },
      { { dur = -2, status = 2 } }, { { dur = -2, status = 2 } }, { { dur = -1, dot = true, status = 2 } },
    },
  }
  for k = 1, 4 do
    for t = 1, 3 do
      local beats = music[t][k]
      i32(#beats)
      for _, o in ipairs(beats) do beat(o) end
      if v >= 500 then
        if t == 2 and k == 1 then i32(1); beat({ dur = 0, notes = { { gs = 1, fret = 0 } } }) -- (a 2nd voice)
        else i32(0) end
        u8(0)
      end
    end
  end
  return table.concat(b)
end

test("older files (.gp3, .gp4, .gp5 of Guitar Pro 5.0 and 5.1): tracks, bars, repeats, endings, notes", function()
  local function fmt(list)
    local t = {}
    for k, x in ipairs(list) do t[k] = string.format("%.2f+%.2f %d s%d f%d", x.q, x.len, x.midi, x.s, x.fret) end
    return table.concat(t, " | ")
  end
  for _, v in ipairs({ 300, 400, 500, 510 }) do
    local ext = v == 300 and "gp3" or v == 400 and "gp4" or "gp5"
    local path = tmp .. "\\src\\old" .. v .. "." .. ext
    local data = old_file(v)
    write(path, data)
    local doc, why = GP.read(path)
    ok(doc, v .. ": " .. tostring(why))
    eq(doc.rest, 0, v .. ": read to the last byte")
    local t = {}
    for k, tr in ipairs(doc.tracks) do t[k] = string.format("%s:%s:%s:%s:%d", tr.name, tr.kind, tr.inst, table.concat(tr.open, " "), tr.capo) end
    eq(table.concat(t, " | "), "Rhythm:guitar:Guitar:38 45 50 55 59 64:2 | Low end:bass:Bass:28 33 38 43:0 | Kit:drums:Drums::0", v)
    eq(#doc.mbars, 4, v); eq(doc.mbars[4].num, 3, v .. ": bar 4 in 3/4"); eq(doc.tempo, 100, v); eq(doc.tempos, 2, v)
    eq(table.concat(GP.order(doc.mbars), " "), "1 2 1 3 4", v .. ": the repeat with 2 endings")
    eq(fmt(GP.notes(doc, 1)), "0.00+1.00 38 s1 f0 | 1.00+2.00 47 s2 f2 | 4.00+0.33 50 s3 f0 | 4.33+0.33 52 s3 f2"
      .. " | 4.67+0.33 54 s3 f4 | 6.00+2.00 64 s6 f0 | 8.00+1.00 38 s1 f0 | 9.00+2.00 47 s2 f2 | 12.00+4.00 43 s1 f5"
      .. " | 16.00+3.00 38 s1 f0", v .. ": the tie joins, the dead note is left out, the triplets, the empty beat takes no time")
    eq(fmt(GP.notes(doc, 2)), "0.00+4.00 28 s1 f0" .. (v >= 500 and " | 0.00+1.00 43 s4 f0" or "") .. " | 4.00+4.00 35 s2 f2"
      .. " | 8.00+4.00 28 s1 f0" .. (v >= 500 and " | 8.00+1.00 43 s4 f0" or "") .. " | 12.00+4.00 38 s3 f0 | 16.00+3.00 45 s4 f2",
      v .. ": the bass (Guitar Pro 5: a 2nd voice)")
    eq(fmt(GP.notes(doc, 3)):sub(1, 37), "0.00+1.00 36 s1 f36 | 0.00+1.00 42 s2", v .. ": the drums: the note numbers")
    -- Guitar Pro 5 can leave out the last byte (a real file did); more missing: damaged
    write(path, data:sub(1, -2))
    ok(GP.read(path), v .. ": the last byte missing")
    write(path, data:sub(1, -40))
    local d2, w2 = GP.read(path)
    eq(d2, nil, v .. ": cut short"); ok(w2:find("damaged", 1, true), v .. ": " .. tostring(w2))
  end
end)

test("Tempo and bars from the tab: the tempo changes and time signatures in the order they play, the markers", function()
  local Beat = C.TP.Beat
  local path = tmp .. "\\src\\old510.gp5"
  write(path, old_file(510))
  local doc = GP.read(path)
  local tl = GP.timeline(doc)
  local t = {}
  for k, b in ipairs(tl) do
    local tp = {}
    for i, x in ipairs(b.tempos) do tp[i] = string.format("%g@%g", x.q, x.bpm) end
    t[k] = string.format("%g %d/%d [%s]", b.len, b.num, b.den, table.concat(tp, " "))
  end
  eq(table.concat(t, " | "), "4 4/4 [0@100] | 4 4/4 [2@120] | 4 4/4 [] | 4 4/4 [] | 3 3/4 []",
    "the first tempo, the change in bar 2 (the 2nd played bar only), 3/4 at the end")
  local m, t_after, nbars = Beat.tab_plan(tl, 10)
  t = {}
  for k, x in ipairs(m) do t[k] = string.format("%.2f %g %d/%d bar %d beat %g", x.t, x.bpm, x.num, x.den, x.bar, x.beat) end
  eq(table.concat(t, " | "), "10.00 100 4/4 bar 0 beat 0 | 13.60 120 0/4 bar 1 beat 2 | 18.60 120 3/4 bar 4 beat 0",
    "a marker only where the tempo or the time signature changes")
  near(t_after, 20.1, 1e-6, "the end"); eq(nbars, 5)
  near(Beat.tab_time(tl, 6), 3.6, 1e-6, "a place after the tempo change")
  near(Beat.tab_time(tl, 7), 4.1, 1e-6, "1 beat later at the new tempo")
  near(Beat.tab_time(tl, 1), 0.6, 1e-6, "in bar 1")
  -- a .gp file: the tempo at its bar (master bar 3: 140; bar 2 repeats, so it is the 4th bar that plays)
  tl = GP.timeline(GP.read(src))
  eq(#tl, 4); eq(tl[1].tempos[1].bpm, 120, ".gp: bar 1"); eq(#tl[3].tempos, 0, ".gp: the repeat")
  eq(tl[4].tempos[1] and tl[4].tempos[1].bpm, 140, ".gp: master bar 3")
end)

test("Set tempo from a track: the tab's empty bars before its first note come before bar 1 of the song", function()
  local keep = R.tab
  R.tab = { bars = { { notes = {} }, { notes = {} }, { notes = {} }, { notes = {} }, { notes = {} },
    { notes = { { q = 0 } } } } } -- (5 empty bars, the first note in bar 6)
  eq(Tabs.start_bar(9, false), 5, "bar 1 of the song is bar 10: the tab starts 5 bars earlier, on bar 5")
  eq(Tabs.start_bar(9, true), 10, "from the tab: bar 1 is already the tab's bar 1")
  eq(Tabs.start_bar(2, false), 1, "no room before the song: bar 1 (the notice says why)")
  R.tab = keep
end)

test("Set tempo from the tab: REAPER's tempo map (the change inside a bar, 3/4), 1 undo step", function()
  local proj = R.proj
  local path = tmp .. "\\src\\old510.gp5"
  local tl = GP.timeline(GP.read(path))
  local keep = R.tempo
  R.tempo = { song = { t0 = 0, t1 = 30 }, short = {}, tab = tl, beats = { 2 }, i0 = 1, bpm = 100 }
  C.Tempo.write("Tab Viewer test: set the tempo")
  near(r.TimeMap2_QNToTime(proj, r.TimeMap2_timeToQN(proj, 2)), 2, 1e-3, "bar 1 at 2 s")
  local function bpm_at(t) return 60 / (r.TimeMap2_QNToTime(proj, r.TimeMap2_timeToQN(proj, t) + 0.01) - t) * 0.01 end
  near(bpm_at(3), 100, 0.01, "bar 1: 100")
  near(bpm_at(5.7), 120, 0.01, "after the change in bar 2: 120")
  local num = r.TimeMap_GetTimeSigAtTime(proj, 10.7)
  eq(num, 3, "the last bar in 3/4")
  local _, m1 = r.TimeMap2_timeToBeats(proj, 2.001)
  local _, m5 = r.TimeMap2_timeToBeats(proj, 10.601)
  eq(m5 - m1, 4, "the 3/4 bar is the 5th bar from bar 1")
  r.Undo_DoUndo2(proj)
  R.tempo = keep
end)

-- A made-up .gpx (Guitar Pro 6) file system: sector 0 empty (4096 bytes), then for each file its entry sector (type 2,
-- the name at 4, the size at 0x8c, the data sectors from 0x94, 0 ends) and its data sectors.
local function bcfs(files)
  local S = 0x1000
  local sectors = { string.rep("\255", S) }
  for _, f in ipairs(files) do
    local first = #sectors -- (the number of the entry sector)
    local n = math.max(1, math.ceil(#f[2] / S))
    local e = string.pack("<i4", 2) .. f[1] .. string.rep("\0", 127 - #f[1]) .. string.rep("\0", 9)
      .. string.pack("<i4", #f[2]) .. string.rep("\0", 4)
    for k = 1, n do e = e .. string.pack("<i4", first + k) end
    e = e .. string.pack("<i4", 0)
    sectors[#sectors + 1] = e .. string.rep("\0", S - #e)
    for k = 1, n do
      local part = f[2]:sub((k - 1) * S + 1, k * S)
      sectors[#sectors + 1] = part .. string.rep("\0", S - #part)
    end
  end
  return "BCFS" .. table.concat(sectors)
end
-- The "BCFZ" packing of it: a run of the same byte as a copy of the bytes before it (it doubles), else 1-3 plain bytes.
local function bcfz(plain)
  local bits, nb = {}, 0
  local function put(v, n) for i = n - 1, 0, -1 do nb = nb + 1; bits[nb] = (v >> i) & 1 end end
  local function rput(v, n) for i = 0, n - 1 do nb = nb + 1; bits[nb] = (v >> i) & 1 end end
  local i, len = 1, #plain
  while i <= len do
    local c = plain:byte(i)
    local back, ahead = 0, 0
    while back < 32767 and i - back - 1 >= 1 and plain:byte(i - back - 1) == c do back = back + 1 end
    while ahead < 32767 and i + ahead <= len and plain:byte(i + ahead) == c do ahead = ahead + 1 end
    local size = math.min(back, ahead)
    if size >= 4 then
      local w = 0
      while (1 << w) <= size do w = w + 1 end
      put(1, 1); put(w, 4); rput(size, w); rput(size, w)
      i = i + size
    else
      local k = math.min(3, len - i + 1)
      put(0, 1); rput(k, 2)
      for j = 0, k - 1 do put(plain:byte(i + j), 8) end
      i = i + k
    end
  end
  local bytes = {}
  for k = 1, nb, 8 do
    local v = 0
    for j = 0, 7 do v = (v << 1) | (bits[k + j] or 0) end
    bytes[#bytes + 1] = string.char(v)
  end
  return "BCFZ" .. string.pack("<i4", #plain) .. table.concat(bytes)
end

test(".gpx (Guitar Pro 6): packed and unpacked; instrument refs; notes with only string and fret", function()
  -- the test score as Guitar Pro 6 writes it: instrument refs, no MIDI numbers in the notes; longer than 1 sector
  local score = D.GPIF:gsub('<Property name="Midi"><Number>%d+</Number></Property>', "")
    :gsub("<InstrumentSet><Name>Electric Bass</Name><Type>electricBass</Type><LineCount>5</LineCount></InstrumentSet>", '<Instrument ref="e-bass4" />')
    :gsub("<InstrumentSet><Name>Electric Guitar</Name><Type>electricGuitar</Type></InstrumentSet>", '<Instrument ref="e-gtr6" />')
    :gsub("<InstrumentSet><Name>Drums</Name><Type>drumKit</Type></InstrumentSet>", '<Instrument ref="drmkt" />')
    :gsub("</GPIF>", "<!--" .. string.rep("a", 6000) .. "-->\n</GPIF>")
  ok(not score:find("Midi", 1, true) and score:find("e-bass4", 1, true), "the score of Guitar Pro 6")
  local fs = bcfs({ { "misc.xml", "<Misc />" }, { "score.gpif", score } })
  local packed = bcfz(fs)
  eq(GP.bcfz(packed:sub(5)), fs, "unpacked again")
  for name, data in pairs({ ["packed.gpx"] = packed, ["plain.gpx"] = fs }) do
    local p = tmp .. "\\src\\" .. name
    write(p, data)
    local doc, why = GP.read(p)
    ok(doc, name .. ": " .. tostring(why))
    local t = {}
    for k, tr in ipairs(doc.tracks) do t[k] = tr.name .. ":" .. tr.kind end
    eq(table.concat(t, " "), "Bass:bass Rhythm Guitar:guitar Drums:drums Keys:other", name)
    local n = {}
    for k, x in ipairs(GP.notes(doc, 1)) do n[k] = string.format("%.2f+%.2f %d s%d f%d", x.q, x.len, x.midi, x.s, x.fret) end
    eq(table.concat(n, " | "), "0.00+4.00 36 s2 f3 | 4.00+1.50 40 s3 f2 | 8.00+1.50 40 s3 f2 | 12.00+0.33 43 s4 f0",
      name .. ": the pitch from the tuning and the fret")
  end
  local function why(name, data)
    local p = tmp .. "\\src\\" .. name
    write(p, data)
    local doc, w = GP.read(p)
    eq(doc, nil, name)
    return w
  end
  ok(why("text.gpx", "hello"):find("damaged, or it is not a Guitar Pro file", 1, true), "not a .gpx")
  ok(why("noscore.gpx", bcfs({ { "misc.xml", "<Misc />" } })):find("No score", 1, true), "no score in it")
  ok(why("broken.gpx", "BCFZ" .. string.pack("<i4", 5000) .. "\255\255\255\255\255\255"):find("damaged", 1, true), "a damaged packing")
  -- a damaged sector list that points back (the score entry is sector 3; its 1st data sector says 1): no endless loop
  local back = bcfs({ { "misc.xml", "<Misc />" }, { "score.gpif", score } })
  local at = 4 + 3 * 0x1000 + 0x94
  back = back:sub(1, at) .. string.pack("<i4", 1) .. back:sub(at + 5)
  ok(why("back.gpx", back), "a sector list that points back: an answer, no endless loop")
end)

test(".gp: a damaged zip index (it points past the end) gives a message, no script error", function()
  local data = D.GP_FILE .. "PK\3\4" -- (a local header sign at the very end, nothing after it)
  local pos = 1
  while true do
    pos = data:find("PK\1\2", pos, true)
    if data:sub(pos + 46, pos + 45 + string.unpack("<I2", data, pos + 28)) == "Content/score.gpif" then break end
    pos = pos + 4
  end
  data = data:sub(1, pos + 41) .. string.pack("<I4", #D.GP_FILE) .. data:sub(pos + 46)
  local p = tmp .. "\\src\\badindex.gp"
  write(p, data)
  local doc, w = GP.read(p)
  eq(doc, nil); ok(w and w:find("damaged", 1, true), tostring(w))
end)

test("read: why a file can not be read (an older version, not a tab, damaged, no score, missing)", function()
  local function why(name, data)
    local p = tmp .. "\\src\\" .. name
    if data then write(p, data) end
    local doc, w = GP.read(p)
    eq(doc, nil, name)
    return w
  end
  ok(why("old.gp5", "hello"):find("damaged, or it is not a Guitar Pro file", 1, true), "not a gp5")
  ok(why("v2.gp3", "\24FICHIER GUITAR PRO v2.21" .. string.rep("\0", 40)):find("version can not be read", 1, true), "version 2")
  ok(why("notes.txt", "text"):find("not a Guitar Pro file", 1, true), "txt")
  ok(why("damaged.gp", "hello"):find("damaged", 1, true), "not a zip")
  ok(why("empty.gp", D.GP_NOSCORE):find("No score", 1, true), "no score")
  ok(why("gone.gp"):find("Could not open", 1, true), "missing")
end)

test("tunings: Standard, a shifted standard, Drop, other notes, the capo", function()
  eq(GP.tuning_text({ 28, 33, 38, 43 }, "bass", 0), "Standard")
  eq(GP.tuning_text({ 23, 28, 33, 38, 43 }, "bass", 0), "Standard", "5-string bass")
  eq(GP.tuning_text({ 27, 32, 37, 42 }, "bass", 0), "Eb Standard")
  eq(GP.tuning_text({ 24, 31, 36, 41 }, "bass", 0), "Drop C")
  eq(GP.tuning_text({ 40, 45, 50, 55, 59, 64 }, "guitar", 0), "Standard")
  eq(GP.tuning_text({ 38, 45, 50, 55, 59, 64 }, "guitar", 2), "Drop D, capo 2")
  eq(GP.tuning_text({ 35, 40, 45, 50, 55, 59, 64 }, "guitar", 0), "Standard", "7-string")
  eq(GP.tuning_text({ 47, 52, 57, 62, 67, 71, 76 }, "guitar", 0), "Standard", "an octave higher")
  eq(GP.tuning_text({ 38, 43, 50, 55, 59, 62 }, "guitar", 0), "D G D G B D", "open G: the notes")
  eq(GP.tuning_text({ 22, 28, 33, 38 }, "bass", 0), "Bb E A D", "only the low string down 6: the notes")
end)

-- TAB VIEWER -------------------------------------------------------------

test("chord names: from the notes (root, kind, a slash bass), from the file (.gp diagrams, .gp3/4/5), only where they change", function()
  local function name(t) return tostring(GP.chord_name(t)) end
  eq(name({ 45, 52, 57, 60, 64 }), "Am", "A minor, open")
  eq(name({ 40, 47, 52, 56, 59, 64 }), "E", "E major")
  eq(name({ 43, 47, 50, 53 }), "G7"); eq(name({ 38, 45, 50 }), "D5", "a power chord")
  eq(name({ 52, 55, 60 }), "C/E", "the lowest note is not the root")
  eq(name({ 50, 55, 57 }), "Dsus4"); eq(name({ 48, 52, 55, 59 }), "Cmaj7")
  eq(name({ 40 }), "nil", "1 note"); eq(name({ 40, 52 }), "nil", "an octave"); eq(name({ 40, 41 }), "nil", "not a chord")
  -- a .gp: a chord diagram of the bass track, named on its first beat
  local x = D.GPIF:gsub('<Track id="0">', '<Track id="0"><Properties><Property name="DiagramCollection"><Items><Item id="0" name="Am7"></Item></Items></Property></Properties>', 1)
  x = x:gsub('<Beat id="0">', '<Beat id="0"><Chord>0</Chord>', 1)
  local tab = GP.tab(GP.parse(x), 1)
  eq(tab.bars[1].chords[1] and tab.bars[1].chords[1].name, "Am7", ".gp: the file's name"); eq(tab.has_chords, true)
  eq(GP.tab(GP.parse(D.GPIF), 1).has_chords, nil, "single notes, no names: no chord row")
  -- held chords get a name, a fast riff (16ths) does not; the same chord again: no 2nd name
  local function n(pos, len, midi, s) return { pos = pos, len = len, midi = midi, s = s, fret = 0 } end
  local riff = { tracks = { { open = { 40, 45, 50, 55, 59, 64 } } }, mbars = { { num = 4, den = 4, bars = { "b" } } }, bars = { b = {
    n(0, 1.5, 45, 2), n(0, 1.5, 52, 3), n(0, 1.5, 57, 4), n(0, 1.5, 60, 5), -- Am, held
    n(1.5, 0.25, 38, 1), n(1.5, 0.25, 45, 2),                       -- D5, a 16th
    n(2, 1, 45, 2), n(2, 1, 52, 3), n(2, 1, 57, 4), n(2, 1, 60, 5), -- Am again
    n(3, 1, 43, 1), n(3, 1, 47, 2), n(3, 1, 50, 3) } } }            -- G, 1 beat
  local names = {}
  for _, c in ipairs(GP.tab(riff, 1).bars[1].chords) do names[#names + 1] = c.q .. ":" .. c.name end
  eq(table.concat(names, " "), "0:Am 3:G")
  for _, v in ipairs({ 300, 400, 500, 510 }) do
    local path = tmp .. "\\src\\chords" .. v .. ".gp" .. math.min(5, v // 100)
    write(path, old_file(v))
    local doc, why = GP.read(path)
    ok(doc, v .. ": " .. tostring(why))
    local t = GP.tab(doc, 1)
    local all = {}
    for bi, b in ipairs(t.bars) do for _, c in ipairs(b.chords) do all[#all + 1] = bi .. ":" .. c.name end end
    eq(table.concat(all, " "), "1:D5", v .. ": the name of the file, once (the repeat plays the same chord)")
  end
end)

test("the track list: instrument and strings, tuning; the line below it", function()
  local rows, info = Tabs.rows(GP.read(src))
  local t = {}
  for k, row in ipairs(rows) do t[k] = row.name .. " / " .. row.what .. " / " .. row.tun end
  eq(table.concat(t, " | "), "Bass / Bass, 4 strings / Standard | Rhythm Guitar / Guitar, 6 strings / Drop D, capo 2"
    .. " | Drums / Drums /  | Keys / Electric Piano / ")
  ok(rows[2].tip:find("D A D G B E", 1, true) and rows[2].tip:find("Capo: fret 2", 1, true), "the tooltip: open strings, capo")
  ok(rows[4].tip:find("Not a tab part", 1, true), "keys: not a tab part")
  eq(info, "3 bars  ·  4/4 (changes)  ·  120 BPM in the file (changes)")
end)

test("open a tab in a saved project: a copy in its Tabs folder, the project data; the same tab again; another one", function()
  eq(R.projfn, proj_a, "the test project")
  local done, copied = Tabs.open(src)
  eq(done, true); eq(copied, true)
  eq(Tabs.cur().file, "Tabs/Song.gp", "relative to the project")
  ok(exists(tmp .. "\\a\\Tabs\\Song.gp"), "the copy")
  eq(#R.rows, 4, "the track list")
  Project.save()
  local _, txt = r.GetProjExtState(0, "Tab Viewer", "cfg")
  eq(txt, "tab=Tabs/Song.gp\n", "the project data")
  Tabs.open(src)
  eq(Tabs.cur().file, "Tabs/Song.gp", "the same tab again: no 2nd copy")
  ok(not exists(tmp .. "\\a\\Tabs\\Song (2).gp"))
  Tabs.open(tmp .. "\\src2\\Song.gp")
  eq(Tabs.cur().file, "Tabs/Song (2).gp", "the same name, another tab: its own copy")
  Tabs.open(src)
  Project.save()
end)

test("the tab of a track: the bars as they play (repeats, 3/4), the notes on their strings, the string names", function()
  local tab = GP.tab(GP.parse(D.GPIF), 1)
  eq(tab.nstr, 4); eq(table.concat(tab.names, " "), "E A D G")
  local t = {}
  for k, b in ipairs(tab.bars) do
    local n = {}
    for j, x in ipairs(b.notes) do n[j] = string.format("%.2f s%d %s", x.q, x.s, C.Tabs.note_txt(x, true)) end
    t[k] = string.format("%.0f+%.0f/%d: %s", b.q0, b.len, b.n16, table.concat(n, ", "))
  end
  eq(table.concat(t, " | "), "0+4/16: 0.00 s2 3 | 4+4/16: 0.00 s3 2, 1.50 s3 x | 8+4/16: 0.00 s3 2, 1.50 s3 x | 12+3/12: 0.00 s4 0",
    "bar 2 twice, the 3/4 bar 12 16ths, the muted note an x")
  eq(#GP.notes(GP.parse(D.GPIF), 1), 4, "Note Detective: no dead notes (bar 2 plays twice)")
  write(tmp .. "\\src\\guitar.gp5", old_file(510))
  local g = GP.tab(GP.read(tmp .. "\\src\\guitar.gp5"), 1) -- (the guitar of the older file test: Drop D)
  eq(table.concat(g.names, " "), "D A D G B E", "the highest E is not the lowest name: capital")
  eq(table.concat(GP.tab({ tracks = { { open = { 40, 45, 50, 55, 59, 64 } } }, mbars = {} }, 1).names, " "), "E A D G B e")
end)

test("playing marks: read from a .gp note; the links to the next note, held parts (4), P.M. runs; x; <12>; a fix keeps them", function()
  local fx = GP.fx('<Note><Property name="HopoOrigin"><Enable /></Property><Property name="Slide"><Flags>2</Flags></Property>'
    .. '<Property name="PalmMuted"><Enable /></Property><Vibrato>Slight</Vibrato></Note>')
  ok(fx and fx.ho and fx.pm and fx.vib and fx.slide == 2 and not fx.bend, "read")
  eq(GP.fx("<Note><Property name=\"Fret\"><Fret>3</Fret></Property></Note>"), nil, "no marks")
  -- Tabs.link: a hammer-on to the next note on its string, a held part "(7)", a held part whose note was fixed: off
  local n1, n2, n3 = { q = 0, s = 1, fret = 5, fx = { ho = true, pm = true } }, { q = 0.5, s = 1, fret = 7, fx = { pm = true } },
    { q = 1, s = 2, fret = 3 }
  local t1, t2 = { q = 1.5, s = 1, fret = 7, tie = true }, { q = 2, s = 2, fret = 9, tie = true }
  local m1 = { q = 0, s = 1, fret = 2, fx = { pm = true } }
  local lt = { bars = { { notes = { n1, n2, n3 }, ties = { t1, t2 } }, { notes = { m1 } } } }
  Tabs.link(lt, true)
  ok(n1.nx == n2 and n2.nx == t1 and t1.nx == m1 and t1.nxb == 2, "the next item on each string, across the bar line")
  eq(t1.txt, "(7)"); eq(t2.off, true, "a held part of another fret: not drawn")
  local runs = {}
  for k, ru in ipairs(lt.pm) do runs[k] = string.format("%d:%.1f-%d:%.1f", ru.b0, ru.q0, ru.b1, ru.q1) end
  eq(table.concat(runs, " "), "1:0.0-1:0.5 2:0.0-2:0.0", "P.M. runs: a place without it ends the run")
  Tabs.link(lt, false)
  eq(#lt.pm, 0, "Playing marks off: no P.M. row")
  local g0 = GP.tab(GP.read(tmp .. "\\src\\guitar.gp5"), 1)
  local nt = 0
  for _, b in ipairs(g0.bars) do nt = nt + #(b.ties or {}) end
  ok(nt > 0, "the .gp5 test song: held parts of its tied notes")
  eq(C.Tabs.note_txt({ fret = 12, fx = { harm = true } }, true), "<12>")
  eq(C.Tabs.note_txt({ fret = 12, fx = { harm = true } }, false), "12", "marks off: the fret")
  eq(C.Tabs.note_txt({ fret = 0, fx = { dead = true } }, false), "x", "a dead note: always x")
  -- the older files: the test song has effects (bends, slides, hammer-ons): read with the notes, not skipped wrongly
  local g = GP.tab(GP.read(tmp .. "\\src\\guitar.gp5"), 1)
  local n = 0
  for _, b in ipairs(g.bars) do for _, x in ipairs(b.notes) do if x.fx then n = n + 1 end end end
  ok(n > 0, "the .gp5 test song: notes with marks")
  -- a fixed note (a new fret, same place and string) keeps its marks; Tabs.build
  Tabs.open(src)
  local b2 = R.tab.bars[2]
  local i = Tabs.note_at(R.tab, 2, 1.5, b2.notes[2].s)
  eq(b2.notes[i].txt, "x", "the dead note")
  Tabs.set_fret(2, 1, 4) -- (the other note of that bar: the bar is now an edit)
  b2 = R.tab.bars[2]
  eq(b2.notes[2].txt, "x", "the dead note of an edited bar stays x")
  Tabs.set_fret(2, 2, 7)
  eq(R.tab.bars[2].notes[2].txt, "7", "a dead note with a fret: a note")
  Tabs.undo_all()
  R.undo = {} -- (the next tests count the Undo steps)
  Project.save()
end)

test("the Track dropdown: its texts, the default track (bass), the choice saved in the project", function()
  Tabs.open(src)
  local t = {}
  for k, row in ipairs(R.rows) do t[k] = row.label end
  eq(table.concat(t, " | "), "Bass - 4 strings, Standard | Rhythm Guitar - 6 strings, Drop D, capo 2 | Drums - Drums | Keys - Electric Piano")
  eq(Tabs.track(), 1, "the bass first"); ok(R.tab and R.tab.nstr == 4, "its tab")
  Tabs.pick(2)
  eq(Tabs.cur().track, 2); eq(R.tab.nstr, 6, "the guitar")
  eq(Project.serialize(C.get_P()), "tab=Tabs/Song.gp\ntrack=2\n")
  eq(Project.parse("tab=Tabs/Song.gp\ntrack=2\n").tabs[1].track, 2, "read back")
  Tabs.pick(3)
  eq(R.tab, nil); ok(R.tab_why:find("Drum tracks", 1, true), "drums: the line")
  Tabs.pick(4)
  ok(R.tab_why:find("no tab", 1, true), "keys: no tab")
  Tabs.pick(1)
  eq(Tabs.cur().track, nil, "the default again: not saved")
  eq(Project.serialize(C.get_P()), "tab=Tabs/Song.gp\n")
  Tabs.pick(2)
  Tabs.open(src)
  eq(Tabs.cur().track, nil, "another Open tab: the default track")
  Tabs.cur().track = 9
  eq(Tabs.track(), 1, "a saved track that the tab does not have: the default")
  Tabs.cur().track = nil
  Project.save()
end)

test("the tab on the window: a click on a place gives its bar and 16th, and the song time there", function()
  Tabs.open(src)
  local tab = R.tab
  tab.lines, tab.h = Tabs.layout(tab, 600)
  eq(#tab.lines, 2, "4 bars on 600 px: 2 lines"); eq(tab.lines[1].last, 2)
  local b = tab.bars[2]
  local bi, q = Tabs.hit(tab, C.CFG.TAB_LEFT + b.x + b.pad + 4.5 * b.sw, C.CFG.TAB_TOP)
  eq(bi, 2); eq(q, 1, "the 5th 16th: 1 quarter note in")
  eq(Tabs.hit(tab, 1, C.CFG.TAB_TOP), nil, "on the string names")
  local b4, ln2 = tab.bars[4], tab.lines[2]
  bi, q = Tabs.hit(tab, C.CFG.TAB_LEFT + b4.x + b4.pad + 0.5 * b4.sw, ln2.y + C.CFG.TAB_TOP)
  eq(bi, 4); eq(q, 0)
  near(Tabs.time_of(2, 1), 2.5, 1e-9, "bar 2 + 1 quarter note at 120 BPM")
end)

test("fix the tab: a fret, another string, delete; the written bar (its repeats too), saved, Undo and Redo", function()
  Tabs.open(src)
  local file_txt = Project.serialize(C.get_P())
  local b1 = R.tab.bars[1]
  local n1 = b1.notes[1]
  ok(n1, "the bass has a note in bar 1")
  local s1, f1, wb = n1.s, n1.fret, b1.wb
  -- a new fret
  ok(Tabs.set_fret(1, 1, 7), "fret 7")
  eq(R.tab.bars[1].notes[1].fret, 7); eq(R.tab.bars[1].notes[1].txt, "7", "the text drawn")
  for _, b in ipairs(R.tab.bars) do
    if b.wb == wb then eq(b.notes[1].fret, 7, "each place where the written bar plays") end
  end
  eq(Tabs.set_fret(1, 1, 25), false, "above CFG.FRETS: no change")
  eq(#R.undo, 1, "1 Undo step")
  local txt = Project.serialize(C.get_P())
  ok(txt:find("\nedit=1 " .. wb .. " ", 1, true), "saved: " .. txt)
  eq(Project.parse(txt).tabs[1].edits[1][wb][1].fret, 7, "read back")
  -- another string at the same pitch, or a reason
  local open = R.doc.tracks[1].open
  local dir = open[s1 + 1] and 1 or -1
  local done, why = Tabs.move_string(1, 1, dir)
  if done then
    local i = Tabs.note_at(R.tab, 1, n1.q, s1 + dir)
    ok(i, "on the next string")
    eq(R.tab.bars[1].notes[i].fret, 7 + open[s1] - open[s1 + dir], "the same pitch")
  else ok(type(why) == "string", "a reason") end
  eq(Tabs.move_string(1, Tabs.note_at(R.tab, 1, n1.q, done and s1 + dir or s1), 99), nil, "no string there")
  -- delete
  local count = #R.tab.bars[1].notes
  Tabs.delete(1, 1)
  eq(#R.tab.bars[1].notes, count - 1, "deleted")
  -- the next note in the order they play
  eq(Tabs.next_note(R.tab, 1, 1, -1), nil, "before the first note: none")
  -- Undo all the steps: the file's notes again, nothing saved
  while Tabs.undo(-1) do end
  eq(R.tab.bars[1].notes[1].fret, f1); eq(R.tab.bars[1].notes[1].s, s1)
  eq(Project.serialize(C.get_P()), file_txt, "no edit line")
  ok(Tabs.undo(1), "Redo"); eq(R.tab.bars[1].notes[1].fret, 7, "the fret again")
  -- the saved fix after a reload of the project data
  Project.load(Project.serialize(C.get_P()))
  eq(R.tab.bars[1].notes[1].fret, 7, "loaded from the project"); eq(#R.undo, 0, "a new session: no Undo")
  Tabs.cur().edits = nil
  Tabs.build()
  Project.save()
end)

test("a click on the tab: selects; only a double-click on the same place opens the box (a note's or a new note's)", function()
  Tabs.open(src)
  local tab = R.tab
  local n1 = tab.bars[1].notes[1]
  local s, q = n1.s, n1.q
  local free
  for k = 0, tab.bars[1].n16 - 1 do if not Tabs.note_at(tab, 1, k / 4, s) then free = k / 4; break end end
  -- a single click on a note: selected, no box
  local sel, box, nq, last = Tabs.click(tab, 1, q, s, false, nil)
  ok(sel and sel.s == s, "selected"); eq(box, nil, "no box"); eq(nq, q)
  -- then a click on an empty place (ImGui may call it a double-click: the time was short): no box (the bug)
  sel, box, nq, last = Tabs.click(tab, 1, free, s, true, last)
  eq(sel, nil); eq(box, nil, "another place: no box")
  -- a real double-click on that empty place: the box of a new note
  sel, box = Tabs.click(tab, 1, free, s, true, last)
  ok(box and box.new, "the box of a new note")
  -- a double-click on the note: its box
  local _, _, _, l2 = Tabs.click(tab, 1, q, s, false, nil)
  sel, box = Tabs.click(tab, 1, q, s, true, l2)
  ok(box and not box.new and box.txt == n1.txt, "the note's box")
  -- between the strings: no box
  _, box = Tabs.click(tab, 1, free, nil, true, { bi = 1, q = math.floor(free * 4), s = nil })
  eq(box, nil, "not on a string")
end)

test("fix the tab: my notes are marked; Undo all changes (only this track) and its Undo", function()
  Tabs.open(src)
  local n1 = R.tab.bars[1].notes[1]
  local f1 = n1.fret
  eq(n1.mine, nil, "the file's note: not marked")
  Tabs.set_fret(1, 1, f1 == 9 and 8 or 9)
  ok(R.tab.bars[1].notes[1].mine, "the fixed note: marked")
  for k = 2, #R.tab.bars[1].notes do ok(not R.tab.bars[1].notes[k].mine, "the other notes of the bar: not marked") end
  Tabs.cur().edits[2] = { [1] = {} } -- (a fix of another track: stays)
  ok(Tabs.undo_all(), "Undo all changes")
  eq(R.tab.bars[1].notes[1].fret, f1, "the file's fret"); eq(Tabs.cur().edits[1], nil, "nothing saved for the track")
  ok(Tabs.cur().edits[2], "the other track keeps its fixes")
  eq(Tabs.undo_all(), false, "nothing to undo now")
  ok(Tabs.undo(-1), "Ctrl+Z"); ok(R.tab.bars[1].notes[1].fret ~= f1, "the fixes are back")
  ok(Tabs.undo(1), "Redo"); eq(R.tab.bars[1].notes[1].fret, f1)
  Tabs.cur().edits = nil
  R.undo, R.redo = {}, {}
  Tabs.build()
  Project.save()
end)

test("fix the tab: a new note (1 16th), never on another note; a note moves a 16th in its bar, never over another", function()
  Tabs.open(src)
  local b = R.tab.bars[1]
  local n1 = b.notes[1]
  local s, q = n1.s, n1.q
  eq(select(2, Tabs.add(1, q, s, 3)), "A note is already there.")
  eq(select(2, Tabs.add(1, 0, s, 30)), "A fret from 0 to 24, please.")
  -- a free 16th on that string
  local free
  for k = 0, b.n16 - 1 do if not Tabs.note_at(R.tab, 1, k / 4, s) then free = k / 4; break end end
  ok(free, "a free 16th in bar 1")
  ok(Tabs.add(1, free, s, 5), "added")
  local i = Tabs.note_at(R.tab, 1, free, s)
  eq(R.tab.bars[1].notes[i].fret, 5); eq(R.tab.bars[1].notes[i].len, 0.25)
  -- move it: to the start of the bar only when free; never out of the bar
  eq(select(2, Tabs.move(1, i, -(free + 1))), "A note stays in its bar.")
  local nq = Tabs.move(1, i, 0.25)
  if nq then eq(nq, free + 0.25); ok(Tabs.note_at(R.tab, 1, nq, s), "moved")
  else ok(Tabs.note_at(R.tab, 1, free + 0.25, s) or free + 0.25 > b.len - 0.25, "blocked by a note or the bar end") end
  while Tabs.undo(-1) do end
  eq(Tabs.note_at(R.tab, 1, free, s), nil, "Undo: the new note goes")
  Tabs.cur().edits = nil
  R.redo = {}
  Tabs.build()
  Project.save()
end)

test("bar 1 of the tab = bar N of the song: the times, the play position, the bar numbers, saved; < stops at 1", function()
  Tabs.open(src)
  Tabs.set_bar(3)
  eq(Tabs.cur().bar, 3); eq(R.bar_txt, "Bar 3 of the song")
  eq(R.tab.bars[1].label .. " " .. R.tab.bars[4].label, "3 6", "the song's bar numbers")
  eq(Project.serialize(C.get_P()), "tab=Tabs/Song.gp\nbar=3\n")
  eq(Project.parse("tab=x.gp\nbar=3\n").tabs[1].bar, 3, "read back")
  -- 120 BPM 4/4: bar 3 starts at 4 s; the tab's bars are 4, 4, 4 and 3 quarter notes (its 3/4 bar fits)
  near(Tabs.time_of(1, 0), 4, 1e-9); near(Tabs.time_of(2, 1), 6.5, 1e-9)
  local bi, q = Tabs.place_of(6.5)
  eq(bi, 2); near(q, 1, 1e-9)
  bi, q = Tabs.place_of(10.25)
  eq(bi, 4, "the 3/4 bar (12 quarter notes in)"); near(q, 0.5, 1e-9)
  eq(Tabs.place_of(3.9), nil, "before the tab"); eq(Tabs.place_of(4 + 15 * 0.5), nil, "after it")
  Tabs.set_bar(0)
  eq(Tabs.cur().bar, nil, "1 at least, and 1 is not saved"); eq(R.tab.bars[1].label, "1")
  Tabs.set_bar(5)
  Tabs.open(src)
  eq(Tabs.cur().bar, nil, "another Open tab: bar 1")
  Project.save()
end)

test("loop (Shift+click a bar): from the selected note or the edit cursor to the bar end; again: off, as before; speed", function()
  Tabs.open(src) -- (bar 1 of the tab at 0 s, 120 BPM: a 4/4 bar is 2 s)
  local proj = R.proj
  eq(select(2, Tabs.loop_start(2, nil, nil)), 0, "no start place: the bar start")
  eq(Tabs.loop_start(2, 3, 1), 2, "a start after the bar: the bar start")
  r.GetSet_LoopTimeRange2(proj, true, true, 0, 0, false)
  r.GetSetRepeatEx(proj, 0)
  R.tsel = { bi = 1, q = 1, s = 1 }
  Tabs.loop(2)
  local a, b = r.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
  near(a, 0.5, 1e-9, "from the selected note"); near(b, 4, 1e-9, "to the end of bar 2")
  eq(r.GetSetRepeatEx(proj, -1), 1, "repeat on")
  Tabs.loop(3) -- (another bar: the loop moves; the state before stays the one before the 1st loop)
  a, b = r.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
  near(b, 6, 1e-9, "to the end of bar 3")
  Tabs.loop(3)
  eq(R.loop, nil, "the same bar again: off")
  eq(r.GetSetRepeatEx(proj, -1), 0, "repeat as it was")
  a, b = r.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
  eq(a, b, "no time selection, as before")
  R.tsel = nil
  r.SetEditCurPos2(proj, 9, false, false) -- (after bar 2: the loop of bar 2 is the whole bar)
  Tabs.loop(2)
  a = r.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
  near(a, 2, 1e-9, "the edit cursor after the bar: the bar start")
  Tabs.select(nil)
  eq(R.loop, nil, "another tab: the loop ends")
  Tabs.select(1)
  Tabs.speed(0.75)
  near(r.Master_GetPlayRate(proj), 0.75, 1e-6, "75%")
  eq(r.GetToggleCommandStateEx(0, 40671), 1, "the pitch stays")
  Tabs.speed(1)
  near(r.Master_GetPlayRate(proj), 1, 1e-6, "100%")
  eq(R.pitch_old, nil)
end)

test("the yellow line when the project's tempo is not the tab's (the tab would drift)", function()
  Tabs.open(src)
  eq(R.tempo_warn, nil, "the project and the tab: both 120 BPM")
  R.doc.tempo = 150
  Tabs.tempo_check()
  ok(R.tempo_warn and R.tempo_warn:find("120 BPM, the tab's 150 BPM", 1, true), tostring(R.tempo_warn))
  Tabs.show(nil)
  eq(R.tempo_warn, nil, "no tab: no line")
  Tabs.open(src) -- (the tests after this one start with the tab open)
end)

test("open a file that can not be read: nothing changes", function()
  local before = Tabs.cur().file
  local done, why = Tabs.open(tmp .. "\\src\\damaged.gp")
  eq(done, nil); ok(why and why:find("damaged", 1, true), "why")
  eq(Tabs.cur().file, before); eq(#R.rows, 4, "the list of the tab before")
end)

test("another project: its own tab (none); back: the tab again; a missing tab file", function()
  r.Main_SaveProject(0, false)
  r.Main_openProject("noprompt:" .. proj_b)
  Project.update()
  eq(Tabs.cur(), nil, "project b has no tab"); eq(R.rows, nil); eq(R.err, nil)
  r.Main_openProject("noprompt:" .. proj_a)
  Project.update()
  eq(Tabs.cur().file, "Tabs/Song.gp", "project a: its tab"); eq(#R.rows, 4)
  Tabs.cur().file = "Tabs/gone.gp"
  Tabs.load()
  eq(R.rows, nil); ok(R.err and R.err:find("missing", 1, true), "the line in the window: " .. tostring(R.err))
  Tabs.cur().file = "Tabs/Song.gp"
  Tabs.load()
end)

test("a project that is not saved yet: the copy at the 1st save; Save as: the tab goes with the project", function()
  local keep_fn, keep_p, keep_cur = R.projfn, C.get_P(), R.cur
  C.set_P({ tabs = {} })
  R.projfn = "" -- (not saved)
  local done, copied = Tabs.open(src)
  eq(done, true); eq(copied, false, "no project folder yet")
  eq(Tabs.cur().file, src, "the full path for now")
  R.projfn = proj_b -- (the 1st save)
  Tabs.moved("")
  eq(Tabs.cur().file, "Tabs/Song.gp"); ok(exists(tmp .. "\\b\\Tabs\\Song.gp"), "the copy at the 1st save")
  R.projfn = proj_c -- (Save as into another folder)
  Tabs.moved(proj_b)
  eq(Tabs.cur().file, "Tabs/Song.gp"); ok(exists(tmp .. "\\c\\Tabs\\Song.gp"), "the copy in the new folder")
  eq(#R.rows, 4, "the list stays")
  R.projfn, R.pdirty = keep_fn, false
  C.set_P(keep_p); R.cur = keep_cur
  Tabs.relist()
end)

test("tabs per region: Open tab for the region at the edit cursor, the tab moves with its region, saved", function()
  local proj = R.proj -- (120 BPM 4/4: a bar is 2 s)
  local i1 = r.AddProjectMarker2(proj, true, 8, 20, "Song One", -1, 0)   -- (starts on bar 5)
  local i2 = r.AddProjectMarker2(proj, true, 21, 40, "Song Two", -1, 0)  -- (starts inside bar 11)
  Tabs.regions()
  local n0 = #C.get_P().tabs -- (the tab without a region of the tests before)
  r.SetEditCurPos2(proj, 9, false, false)
  local done, _, g = Tabs.open(src)
  eq(done, true); eq(g and g.label, 'Region ' .. i1 .. ' "Song One"', "the region at the edit cursor")
  eq(#C.get_P().tabs, n0 + 1, "a new tab"); ok(Tabs.cur().rgn, "linked by GUID")
  near(Tabs.time_of(1, 0), 8, 1e-9, "bar 1 of the tab on the region's start")
  eq(R.bar_txt, "Bar 1 of the region")
  Tabs.set_bar(2)
  near(Tabs.time_of(1, 0), 10, 1e-9, "bar 2 of the region"); eq(R.tab.bars[1].label, "2", "the region's bar numbers")
  r.SetEditCurPos2(proj, 22, false, false)
  Tabs.open(tmp .. "\\src2\\Song.gp")
  eq(#C.get_P().tabs, n0 + 2, "the 2nd region: its own tab")
  near(Tabs.time_of(1, 0), 22, 1e-9, "a region inside a bar: the next bar line")
  local two = R.cur
  r.SetEditCurPos2(proj, 22, false, false)
  Tabs.open(src)
  eq(#C.get_P().tabs, n0 + 2, "Open tab again in the same region: it replaces its tab"); eq(R.cur, two)
  eq(Tabs.at(9), n0 + 1); eq(Tabs.at(30), two); eq(Tabs.at(1), 1, "outside the regions: the tab without a region")
  -- the region moves 4 bars later: its tab moves with it
  r.SetProjectMarker(i1, true, 16, 28, "Song One")
  Tabs.regions()
  Tabs.select(n0 + 1)
  near(Tabs.time_of(1, 0), 18, 1e-9, "bar 2 of the moved region")
  local txt = Project.serialize(C.get_P())
  ok(txt:find("region={", 1, true) and txt:find("bar=2", 1, true), txt)
  local back = Project.parse(txt)
  eq(#back.tabs, n0 + 2); eq(back.tabs[n0 + 1].rgn, Tabs.cur().rgn, "read back"); eq(back.tabs[n0 + 1].bar, 2)
  ok(R.tab_labels[n0 + 1].txt:find('Song One', 1, true), R.tab_labels[n0 + 1].txt)
  -- the region is deleted: the tab stays, "its region is gone", from the song's bar 2
  r.DeleteProjectMarker(proj, i1, true)
  Tabs.regions()
  ok(R.tab_labels[n0 + 1].txt:find("its region is gone", 1, true), R.tab_labels[n0 + 1].txt)
  near(Tabs.time_of(1, 0), 2, 1e-9)
  Tabs.set_region(R.rgns.list[1])
  eq(Tabs.cur().bar, nil, "another region: from its first bar"); near(Tabs.time_of(1, 0), 22, 1e-9)
  Tabs.remove()
  eq(#C.get_P().tabs, n0 + 1, "removed"); ok(Tabs.cur(), "another tab in the window")
  Tabs.select(n0 + 1); Tabs.remove()
  eq(#C.get_P().tabs, n0)
  r.DeleteProjectMarker(proj, i2, true)
  Tabs.regions(); Tabs.select(1)
  r.SetEditCurPos2(proj, 0, false, false)
  Project.save()
end)

test("tabs per region: the window follows the play or edit cursor; Find tempo takes the audio of the region", function()
  local proj = R.proj
  local i1 = r.AddProjectMarker2(proj, true, 8, 20, "Song One", -1, 0)
  local i2 = r.AddProjectMarker2(proj, true, 24, 40, "Song Two", -1, 0)
  local i3 = r.AddProjectMarker2(proj, true, 44, 50, "No Tab", -1, 0)
  Tabs.regions()
  local whole = R.cur -- (the tab without a region)
  r.SetEditCurPos2(proj, 9, false, false); Tabs.open(src); local one = R.cur
  r.SetEditCurPos2(proj, 25, false, false); Tabs.open(src); local two = R.cur
  R.follow_last = nil
  Tabs.follow(9); eq(R.cur, one, "in Song One")
  Tabs.follow(30); eq(R.cur, two, "in Song Two")
  Tabs.select(one)
  Tabs.follow(31); eq(R.cur, one, "a choice in the dropdown stays while the place has the same tab")
  Tabs.follow(21); eq(R.cur, whole, "between the regions: the tab without a region")
  Tabs.follow(45); eq(R.cur, nil, "a region without a tab: none"); eq(R.rows, nil)
  eq(Tabs.at(45), nil, "not the tab without a region")
  Tabs.follow(30); eq(R.cur, two)
  -- the song of Find tempo: the longest audio item in the region of the tab (not a longer one elsewhere)
  local tr = r.GetTrack(proj, 0) or (r.InsertTrackAtIndex(0, false) or r.GetTrack(proj, 0))
  local function audio_item(pos, len)
    local it = r.AddMediaItemToTrack(tr)
    r.SetMediaItemInfo_Value(it, "D_POSITION", pos); r.SetMediaItemInfo_Value(it, "D_LENGTH", len)
    local tk = r.AddTakeToMediaItem(it)
    r.SetMediaItemTake_Source(tk, r.PCM_Source_CreateFromType("WAVE"))
    return it
  end
  local long = audio_item(8, 12)    -- (in Song One)
  local mine = audio_item(25, 10)   -- (in Song Two)
  r.SelectAllMediaItems(proj, false)
  eq(Tabs.song_item(), mine, "Song Two: its own item")
  Tabs.select(one); eq(Tabs.song_item(), long, "Song One: its own item")
  Tabs.select(whole); eq(Tabs.song_item(), long, "no region: the longest of the project")
  Tabs.follow(45)
  r.DeleteTrackMediaItem(tr, long); r.DeleteTrackMediaItem(tr, mine)
  -- clean up: the 2 tabs and the 3 regions go
  for _, i in ipairs({ two, one }) do Tabs.select(i); Tabs.remove() end
  for _, i in ipairs({ i1, i2, i3 }) do r.DeleteProjectMarker(proj, i, true) end
  Tabs.regions(); Tabs.select(whole); R.follow_last = nil
  r.SetEditCurPos2(proj, 0, false, false)
  Project.save()
end)

test("chord names: centred over their chord, pushed past the name before, cut before the next chord", function()
  local function bar(x, chords) return { x = x, pad = 0, sw = 10, n16 = 16, chords = chords } end
  local tab = { bars = { bar(0, { { q = 0, name = "Am" }, { q = 0.25, name = "Cmaj7" }, { q = 2, name = "G" } }) },
    lines = { { first = 1, last = 1 } } }
  local width = function(t) return #t * 6 end -- (6 px a letter)
  local fit = function(t, w) return t:sub(1, math.max(1, w // 6)) end
  Tabs.place_chords(tab, width, fit)
  local c = tab.bars[1].chords
  eq(c[1].x, 0); eq(c[1].txt, "A")       -- (at the left edge: cut before Cmaj7's chord at 15 px)
  eq(c[2].x, 12); eq(c[2].txt, "Cmaj7")  -- (pushed past "A"; ends before G at 85 px)
  eq(c[3].x, 82); eq(c[3].txt, "G")      -- (centred: 85 - 3)
end)

for _, t in ipairs(tests) do
  local good, e = pcall(t[2])
  if good then passed = passed + 1; log("ok    " .. t[1])
  else failed = failed + 1; log("FAIL  " .. t[1] .. ": " .. tostring(e)) end
end
finish()
