-- @noindex
-- The tests of Tab Viewer's Detection tab (Tab Viewer\Notes.lua; it was the script Note Detective). tests\tabviewer.lua
-- runs them after its own (.\tools\test.ps1 -Script "Tab Viewer"): this file returns a function that adds them to its
-- list (T: test, eq, ok, near, TV = TabViewerTest). The first one opens their own saved test project.
return function(T)
local r = reaper
local test, eq, ok, near, TV = T.test, T.eq, T.ok, T.near, T.TV
local C = TV.Notes -- (the modules of Notes.lua)
local TR = TV.R    -- (Tab Viewer's state: Find tempo, the notices)

-- a saved test project
local tmp = r.GetResourcePath() .. "\\NotesTests"
local proj_file = tmp .. "\\test.rpp"
local function empty_project(path)
  local pf = io.open(path, "w")
  if pf then pf:write("<REAPER_PROJECT 0.1\n  TEMPO 120 4 4\n>\n"); pf:close() end
end
local Key, Group, List, Project, Find, Out, R = C.Key, C.Group, C.List, C.Project, C.Find, C.Out, C.R

test("notes: the test project of the Detection tab opens", function()
  r.RecursiveCreateDirectory(tmp, 0)
  empty_project(proj_file)
  r.Main_openProject("noprompt:" .. proj_file)
  Project.update()
  TV.Project.update()
end)

local function texts(rows)
  local t = {}
  for i, row in ipairs(rows or C.get_P().rows) do t[i] = row.text end
  return table.concat(t, " | ")
end
local function set_rows(list, key)
  local p = List.default()
  p.key = key or ""
  for i, x in ipairs(list) do p.rows[i] = { t = x[1], text = x[2], doubt = x[3] or false, ts = x[4] } end
  C.set_P(p)
  R.undo, R.sel, R.edit, R.written = {}, nil, nil, nil
  return p
end
local function clear_project()
  for i = r.CountTracks(0) - 1, 0, -1 do r.DeleteTrack(r.GetTrack(0, i)) end
  while true do
    local n = r.EnumProjectMarkers2(0, 0)
    if n == 0 then break end
    r.DeleteProjectMarkerByIndex(0, 0)
  end
  set_rows({})
end
local function markers()
  local t, i = {}, 0
  while true do
    local n, rgn, pos, e, name = r.EnumProjectMarkers2(0, i)
    if n == 0 then break end
    t[#t + 1] = rgn and string.format("[%s %.1f-%.1f]", name, pos, e) or string.format("%s@%.1f", name, pos)
    i = i + 1
  end
  return table.concat(t, " ")
end
local function track_names()
  local t = {}
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    t[#t + 1] = select(2, r.GetTrackName(tr)) .. ":" .. math.floor(r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH"))
  end
  return table.concat(t, " ")
end
local function add_track(name, depth)
  local n = r.CountTracks(0)
  r.InsertTrackAtIndex(n, false)
  local tr = r.GetTrack(0, n)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  if depth then r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth) end
  return tr
end
-- a WAV file with bass-like notes: { { midi, seconds }, ... } (midi nil: silence); 4 harmonics, a short attack
local function bass_wav(name, list, cents)
  local sr = 44100
  local path = tmp .. "\\" .. name
  local data = {}
  for _, n in ipairs(list) do
    local len = math.floor(n[2] * sr)
    local hz = n[1] and 440 * 2 ^ ((n[1] + (cents or 0) / 100 - 69) / 12) or 0
    for i = 0, len - 1 do
      local v = 0
      if n[1] then
        local t = i / sr
        local env = math.min(1, i / 200) * math.min(1, (len - i) / 1500) * (0.5 + 0.5 * math.exp(-3 * t))
        local a = 2 * math.pi * hz * t
        v = 0.3 * env * (math.sin(a) + 0.6 * math.sin(2 * a) + 0.4 * math.sin(3 * a) + 0.2 * math.sin(4 * a))
      end
      local s = math.floor(v * 32767 + 0.5)
      data[#data + 1] = string.pack("<i2<i2", s, s)
    end
  end
  local body = table.concat(data)
  local f = assert(io.open(path, "wb"))
  f:write("RIFF", string.pack("<I4", 36 + #body), "WAVEfmt ", string.pack("<I4I2I2I4I4I2I2", 16, 1, 2, sr, sr * 4, 4, 16),
    "data", string.pack("<I4", #body), body)
  f:close()
  return path
end
-- a WAV file with metronome clicks: every 60 / bpm s from first; beat number accent (and every 4th after it) is loud
local function click_wav(name, bpm, first, accent, len)
  local sr = 44100
  local path = tmp .. "\\" .. name
  local n = math.floor(len * sr)
  local buf = {}
  for i = 1, n do buf[i] = 0 end
  local k, t = 1, first
  while t < len - 0.05 do
    local amp = ((k - accent) % 4 == 0 and k >= accent) and 0.8 or 0.3
    local s0 = math.floor(t * sr)
    for i = 0, math.floor(0.03 * sr) do
      buf[s0 + i + 1] = amp * math.exp(-i / (0.006 * sr)) * math.sin(2 * math.pi * 1000 * i / sr)
    end
    k, t = k + 1, t + 60 / bpm
  end
  local data = {}
  for i = 1, n do
    local s = math.floor(buf[i] * 32767 + 0.5)
    data[i] = string.pack("<i2<i2", s, s)
  end
  local body = table.concat(data)
  local f = assert(io.open(path, "wb"))
  f:write("RIFF", string.pack("<I4", 36 + #body), "WAVEfmt ", string.pack("<I4I2I2I4I4I2I2", 16, 1, 2, sr, sr * 4, 4, 16),
    "data", string.pack("<I4", #body), body)
  f:close()
  return path
end
-- the tempo map back to 120 BPM 4/4 only
local function clear_tempo()
  for k = r.CountTempoTimeSigMarkers(0) - 1, 1, -1 do r.DeleteTempoTimeSigMarker(0, k) end -- (never a loop: a
  if r.CountTempoTimeSigMarkers(0) > 0 then r.SetTempoTimeSigMarker(0, 0, 0, -1, -1, 120, 4, 4, false) end -- delete can fail)
  r.SetEditCurPos(0, false, false) -- (SetCurrentBPM puts a marker at the edit cursor)
  r.SetCurrentBPM(0, 120, false)
  eq(r.CountTempoTimeSigMarkers(0) <= 1, true, "the tempo map is clear")
  r.Undo_OnStateChange2(0, "test: a clean project") -- (an undo goes back to this state, not to the last test)
end
-- a WAV file of 1 bass sound whose pitch follows a path: { { midi, seconds, glide } } (glide: it moves to the next
-- midi in that time); dips: times (s) where the level dips 10 dB for 30 ms (a repeated note without a silence)
local function path_wav(name, path, dips)
  local sr = 44100
  local data, ph, t = {}, 0, 0
  for k, seg in ipairs(path) do
    local len = math.floor(seg[2] * sr)
    local nxt = path[k + 1]
    for i = 0, len - 1 do
      local tt = i / sr
      local m = seg[1] or 60
      if seg[3] and nxt and tt > seg[2] - seg[3] then m = m + (nxt[1] - m) * (tt - (seg[2] - seg[3])) / seg[3] end
      ph = ph + 2 * math.pi * 440 * 2 ^ ((m - 69) / 12) / sr
      local amp = seg[1] and 0.3 or 0
      for _, d in ipairs(dips or {}) do if t >= d - 0.015 and t < d + 0.015 then amp = 0.1 end end
      local v = amp * (math.sin(ph) + 0.6 * math.sin(2 * ph) + 0.4 * math.sin(3 * ph))
      local s = math.floor(v * 32767 * 0.7 + 0.5)
      data[#data + 1] = string.pack("<i2<i2", s, s)
      t = t + 1 / sr
    end
  end
  local body = table.concat(data)
  local file = tmp .. "\\" .. name
  local f = assert(io.open(file, "wb"))
  f:write("RIFF", string.pack("<I4", 36 + #body), "WAVEfmt ", string.pack("<I4I2I2I4I4I2I2", 16, 1, 2, sr, sr * 4, 4, 16),
    "data", string.pack("<I4", #body), body)
  f:close()
  return file
end
local function add_item(tr, path, pos)
  local it = r.AddMediaItemToTrack(tr)
  local tk = r.AddTakeToMediaItem(it)
  local src = r.PCM_Source_CreateFromFile(path)
  r.SetMediaItemTake_Source(tk, src)
  r.SetMediaItemInfo_Value(it, "D_POSITION", pos)
  r.SetMediaItemInfo_Value(it, "D_LENGTH", (r.GetMediaSourceLength(src)))
  r.GetSetMediaItemTakeInfo_String(tk, "P_NAME", path:match("([^\\]*)$"), true)
  return it, tk
end
-- the notes of an item in 1 go: notes, tuning, the end of the item
local function find_all(it, tk)
  local pos, len = r.GetMediaItemInfo_Value(it, "D_POSITION"), r.GetMediaItemInfo_Value(it, "D_LENGTH")
  local rd = C.TP.reader(tk, len)
  while not C.TP.read_block(rd) do end
  local list, tune = Find.notes(rd.x, pos, function() end)
  return list, tune, pos + len
end
-- notes for the grouping tests: { pc, t, t1, doubt }
local function notes(list)
  local t = {}
  for i, n in ipairs(list) do t[i] = { pc = n[1], t = n[2], t1 = n[3], doubt = n[4] or false } end
  return t
end
local function bars(n, len)
  local t = {}
  for i = 1, n do t[i] = { t0 = (i - 1) * len, t1 = i * len, tol = C.CFG.BAR_TOL } end
  return t
end

test("key: found in file names", function()
  eq(Key.find("Far Away-Bass-C minor-166bpm-441hz.mp3"), "C minor")
  eq(Key.find("01. Far_Away-Cm-160bpm-442hz"), "C minor", "Cm")
  eq(Key.find("Song-bass-F# major-120bpm"), "F# major")
  eq(Key.find("Song-bass-A# minor-120bpm"), "Bb minor", "the usual name")
  eq(Key.find("A Major Thing-Bass-G minor"), "G minor", "the last one counts")
  eq(Key.find("Amen-Bass-120bpm"), nil, "no key")
  eq(Key.find(""), nil)
end)

test("key: note names are correct for the key", function()
  local function names(key)
    local t = {}
    for i = 0, 11 do t[#t + 1] = Key.names(key)[i] end
    return table.concat(t, " ")
  end
  eq(names("C minor"), "C Db D Eb E F F# G Ab A Bb B")
  eq(names("E major"), "C C# D D# E F F# G G# A A# B")
  eq(names("F major"), "C Db D Eb E F F# G Ab A Bb B")
  eq(names("G# minor"), "C C# D D# E F F# G G# A A# B")
  eq(names(""), "C C# D D# E F F# G G# A A# B", "no key: sharps")
  eq(Key.names("F# major")[5], "E#", "E# belongs to F# major")
  for _, k in ipairs(Key.LIST) do
    for pc = 0, 11 do
      local l, a = Key.names(k)[pc]:match("^([A-G])([#b]?)$")
      ok(l, k .. ": a name with 1 sign at most")
      eq(Key.pc(l, a), pc, k .. " " .. pc)
    end
  end
end)

test("key: the names change, the text in brackets stays", function()
  eq(Key.respell("G# - A#", "C minor"), "Ab - Bb")
  eq(Key.respell("D# (D 1) - C - A# (A 1)", "C minor"), "Eb (D 1) - C - Bb (A 1)")
  eq(Key.respell("EEE - F F", "C minor"), "EEE - F F", "words stay")
  eq(Key.respell("Ab - Bridge", "E major"), "G# - Bridge")
  eq(Key.respell("(A# 1", ""), "(A# 1", "an open bracket")
end)

test("group: 1 per bar, the same bar again has no marker", function()
  local rows = Group.rows(notes({ { 0, 0, 2 }, { 0, 2.1, 4 }, { 3, 4, 5 }, { 5, 5, 6 } }), bars(3, 2), "C minor")
  eq(texts(rows), "C | Eb - F")
  eq(rows[2].t, 4, "the start")
  eq(#rows[2].ts, 2, "the time of each note")
end)

test("group: strict bars (25 November 2026): a note is in the bar where it starts; a note that rings on is the next bar's first note too", function()
  local rows = Group.rows(notes({ { 0, 0, 1.8 }, { 5, 1.8, 3.9 } }), bars(2, 2), "")
  eq(texts(rows), "C - F | F", "an 8th before the bar line: in its own bar, and it rings on in the next one")
  rows = Group.rows(notes({ { 0, 0, 1.98 }, { 5, 1.98, 4 } }), bars(2, 2), "")
  eq(texts(rows), "C | F", "20 ms before the bar line: the 1 of the next bar")
  eq(rows[2].t, 1.98, "it starts where the note starts")
  rows = Group.rows(notes({ { 0, 0, 2.5 }, { 7, 2.5, 4 } }), bars(2, 2), "")
  eq(texts(rows), "C | C - G", "rings on into the next bar: a plain name, no brackets")
  eq(rows[2].t, 2, "the line starts on the bar line")
  rows = Group.rows(notes({ { 0, 0, 2.1 }, { 7, 2.1, 4 } }), bars(2, 2), "")
  eq(texts(rows), "C | G", "rings only 0.1 s on: not shown")
  rows = Group.rows(notes({ { 0, 0, 1.75 }, { 5, 1.75, 1.95 }, { 7, 2, 4 } }), bars(2, 2), "")
  eq(texts(rows), "C - F | G", "a short note inside the bar stays")
  rows = Group.rows(notes({ { 0, 0, 5.9 }, { 0, 6, 8 } }), bars(4, 2), "")
  eq(texts(rows), "C", "a long C, then C again: 1 marker")
  rows = Group.rows(notes({ { 8, 0, 1 }, { 1, 1, 3 } }), bars(2, 2), "C minor")
  eq(texts(rows), "Ab - Db | Db", "the key decides the names (the Db rings on into bar 2)")
  rows = Group.rows(notes({ { 8, 0, 2.5 }, { 1, 2.5, 4 } }), bars(2, 2), "C minor")
  eq(texts(rows), "Ab | Ab - Db")
end)

test("group: after a silent bar the same notes get a marker again", function()
  local rows = Group.rows(notes({ { 0, 0, 1.5 }, { 0, 4, 5.5 } }), bars(3, 2), "")
  eq(texts(rows), "C | C")
end)

test("group: doubtful when most of a part is doubtful", function()
  local rows = Group.rows(notes({ { 0, 0, 1, true }, { 0, 1.02, 1.9 }, { 3, 2, 4, true } }), bars(2, 2), "C minor")
  eq(texts(rows), "C | Eb")
  eq(rows[1].doubt, true); eq(rows[2].doubt, true)
  rows = Group.rows(notes({ { 0, 0, 0.3, true }, { 0, 0.32, 1.9 } }), bars(1, 2), "")
  eq(rows[1].doubt, false, "the sure notes support it")
end)

test("group: a repeated block starts with a marker of its own", function()
  local k = { "C", "C", "F", "G", "C", "C", "F", "G", "Ab", "C", "C", "C", "F", "G", "C", "C", "F", "G" }
  -- (bars 1-8 come back at bars 11-18; bar 10 is also C, so bar 11 would have no marker)
  eq(Group.sections(k)[11], true)
  local n = 0
  for _ in pairs(Group.sections(k)) do n = n + 1 end
  eq(n, 1, "only there")
  eq(next(Group.sections({ "C", "C", "C", "C", "C", "C", "C", "C", "C", "C", "C", "C" })), nil, "a steady note is no section")
  eq(next(Group.sections({})), nil)
end)

test("group: every note change", function()
  local n = notes({ { 0, 0, 0.5 }, { 0, 0.5, 1 }, { 3, 1, 1.5 }, { 5, 2.2, 3 }, { 7, 4.5, 5 } })
  eq(texts(Group.make(n, "change", "C minor", 0, 5)), "C | Eb | F | G")
  eq(#Group.make({}, "bar", "", 0, 5), 0, "no notes")
end)

test("group: the bars of the project (120 BPM, 4/4)", function()
  local b = Group.project_bars(0, 3, 7)
  eq(#b, 3); eq(b[1].t0, 2); eq(b[3].t1, 8)
  eq(Group.bar_text(0, 2), "2.1"); eq(Group.bar_text(0, 3.4), "2.3"); eq(Group.bar_text(0, 3.45), "2.4")
  eq(Group.bar_text(0, 3.96), "3.1", "just before the bar line: the next bar")
end)

test("list: the project data goes out and comes back", function()
  local p = set_rows({ { 1.5, "Ab - Bb", true, { 1.5, 2 } }, { 3, "F (D 3)" } }, "C minor")
  p.mode, p.src, p.mk = "change", "{A}", { "{B}", "{C}" }
  local txt = List.serialize(p)
  local q = List.parse(txt)
  eq(List.serialize(q), txt)
  eq(List.parse("mode=sec").mode, "bar", "the removed About 2 seconds (26 November 2026): 1 per bar")
  eq(q.rows[1].doubt, true); eq(#q.rows[1].ts, 2); eq(q.rows[2].ts, nil)
  eq(List.serialize(List.default()), "", "nothing to save: no text")
  eq(#List.parse("row=x\nrow=1\t0\t\t\nfoo\nkey=").rows, 0, "broken lines are skipped")
end)

test("list: a big list stays whole in the project", function()
  local big = {}
  for i = 1, 400 do big[i] = { i, "C - Eb - C - G - F - Eb - C - " .. i, false, { i, i + 0.1, i + 0.2 } } end
  set_rows(big, "C minor")
  R.pdirty = true
  Project.save()
  eq(Project.read(), "song=" .. R.song .. "\n" .. List.serialize(C.get_P()), "1 block: the song, then its list")
  set_rows({})
  Project.save()
  eq(Project.read(), "", "an empty list leaves nothing in the project")
end)

test("list: typed notes, an empty text keeps the old one", function()
  set_rows({ { 1, "C", true }, { 2, "F" }, { 3, "C" }, { 4, "C" } })
  eq(List.set_text(1, "  "), nil); eq(C.get_P().rows[1].text, "C")
  eq(List.set_text(1, " C "), nil, "the same text"); eq(C.get_P().rows[1].doubt, false, "but looked at")
  eq(List.set_text(1, "Eb"), "C", "the old text")
  eq(#List.same("C", 1), 2)
  List.set_all(List.same("C", 1), "Eb")
  eq(texts(), "Eb | F | Eb | Eb")
  List.undo()
  eq(texts(), "C | F | C | C", "1 Undo step for all")
end)

test("list: doubtful lines", function()
  set_rows({ { 1, "C" }, { 2, "F", true }, { 3, "G", true } })
  eq(List.doubtful(), 2)
  eq(List.next_doubtful(nil), 2); eq(List.next_doubtful(2), 3); eq(List.next_doubtful(3), 2, "from the top again")
  List.checked(2); List.checked(3)
  eq(List.next_doubtful(1), nil)
  set_rows({})
  eq(List.next_doubtful(nil), nil, "an empty list")
end)

test("list: join and split", function()
  set_rows({ { 1, "C - F", false, { 1, 2 } }, { 3, "F - G", true, { 3, 4 } } })
  List.join(1)
  eq(texts(), "C - F - G", "the same note goes on"); eq(#C.get_P().rows[1].ts, 3); eq(C.get_P().rows[1].doubt, true)
  List.join(1)
  eq(texts(), "C - F - G", "no next line")
  ok(List.split(1, nil))
  eq(texts(), "C - F | G"); eq(C.get_P().rows[2].t, 4, "at the time of the note")
  ok(List.split(1, 1.5))
  eq(texts(), "C | F | G"); eq(C.get_P().rows[2].t, 1.5, "at the cursor")
  eq(List.split(1, nil), false, "1 note, no cursor")
  eq(List.split(3, 100), true, "the last line, the cursor later")
  eq(texts(), "C | F | G | G")
  set_rows({ { 1, "A (x) - B" }, { 5, "C" } })
  ok(List.split(1, nil)); eq(C.get_P().rows[2].t, 3, "typed notes: spread over the time")
end)

test("list: add, move, delete and Undo", function()
  set_rows({ { 1, "C" }, { 3, "F" } }, "C minor")
  eq(List.add(2), 2); eq(texts(), "C | C | F")
  eq(List.add(0.5), 1); eq(texts(), "C | C | C | F")
  eq(List.move(1, 10), 4); eq(C.get_P().rows[4].t, 10)
  R.sel = 4
  List.delete(4)
  eq(R.sel, 3); eq(texts(), "C | C | F")
  List.undo(); eq(#C.get_P().rows, 4)
  for _ = 1, 10 do List.undo() end
  eq(texts(), "C | F", "back at the start")
  List.delete(1); List.delete(1)
  eq(R.sel, nil, "an empty list")
  List.delete(1)
end)

test("the tab draws (the UI/UX review of 25 November 2026): empty, and a list with a line that is not sure; the count", function()
  set_rows({})
  R.view = nil
  C.draw(500)
  eq(C.UI.view().status, "", "empty: no count")
  set_rows({ { 1, "C" }, { 3, "F", true } })
  R.view = nil
  C.draw(500)
  eq(C.UI.view().status, "2 lines, 1 not sure")
  set_rows({ { 1, "C" } })
  R.view = nil
  eq(C.UI.view().status, "1 line", "none unsure: only the count")
  -- before and after Find tempo (26 November 2026: Find notes was off until then), with and without a tab (Import
  -- from tab): the stand-in fails when BeginDisabled gets nil
  local tm0, tab0 = TR.tempo, TR.tab
  TR.tempo = nil
  C.draw(500)
  TR.tab = tab0 or { bars = {} }
  C.draw(500)
  TR.tempo = { song = {} }
  C.draw(500)
  TR.tempo, TR.tab = tm0, tab0
  R.view = nil
end)

test("list: Redo (the toolbar arrow, 25 November 2026)", function()
  set_rows({ { 1, "C" }, { 3, "F" } })
  List.delete(1); eq(texts(), "F")
  List.undo(); eq(texts(), "C | F", "Undo")
  List.undo(true); eq(texts(), "F", "Redo")
  List.undo(true); eq(texts(), "F", "nothing more to redo")
  List.undo(); List.add(2); eq(#R.redo, 0, "a new change: no Redo")
end)

test("list: the line at a time", function()
  set_rows({ { 1, "C" }, { 3, "F" }, { 5, "G" } })
  eq(List.at(0.5), nil); eq(List.at(1), 1); eq(List.at(4.9), 2); eq(List.at(99), 3)
  -- the toolbar's |<, < and > (25 November 2026)
  eq(List.go(0, 4), 1, "|<"); eq(List.go(-1, 4), 1, "<"); eq(List.go(1, 4), 3, ">")
  eq(List.go(1, 5), nil, "> on the last line: none"); eq(List.go(-1, 1), nil, "< on the first line: none")
  eq(List.go(1, 0.5), 1, "before the first line: > to it"); eq(List.go(-1, 0.5), 1)
  eq(List.go(2, 1), 3, ">|: the last line"); eq(List.go(2, 0.5), 3, ">| before the first line")
  set_rows({})
  eq(List.go(2, 1), nil, ">| without lines: none")
end)

test("list: another key changes the names", function()
  set_rows({ { 1, "G# - A# (A 1)" } })
  List.set_key("C minor")
  eq(texts(), "Ab - Bb (A 1)")
  List.undo()
  eq(texts(), "G# - A# (A 1)"); eq(C.get_P().key, "")
end)

test("Transpose (26 November 2026): the names in the transposed key; a corrected line keeps its text", function()
  eq(C.Key.shift("E minor", 2), "F# minor"); eq(C.Key.shift("C major", -1), "B major"); eq(C.Key.shift("", 3), "")
  eq(C.Key.shift("Eb major", 12), "Eb major", "an octave: the same key")
  local n = notes({ { 4, 1, 1.4 }, { 7, 1.5, 1.9 } }) -- (E, G)
  local opt = List.opt(0)
  opt.high, opt.runs = false, false
  eq(texts(Group.make(n, "change", "E minor", 0, 5, opt)), "E | G")
  opt.tp = 2
  eq(texts(Group.make(n, "change", "E minor", 0, 5, opt)), "F# | A", "2 half steps higher, in F# minor")
  local p = set_rows({})
  p.notes, p.mode, p.key, p.t_end = n, "change", "E minor", 5
  p.rows = Group.make(n, "change", "E minor", 0, 5, List.opt(0))
  p.rows[2].text = "my G"
  TV.Tabs.set_transpose(2) -- (the toolbar: the list follows)
  eq(texts(), "F# | my G", "the names transposed; your text stays")
  TV.Tabs.set_transpose(0)
  eq(texts(), "E | my G")
end)

test("another project: the list is not used and not written", function()
  clear_project()
  set_rows({ { 1, "C" } })
  R.pdirty = true
  Project.save()
  r.Main_SaveProject(0, false)
  List.step()
  C.get_P().notes, R.sel = { { t = 1, t1 = 2, pc = 0, midi = 36 } }, 1
  local other = tmp .. "\\other.rpp"
  empty_project(other)
  r.Main_openProject("noprompt:" .. other) -- (the same tab)
  Project.update()
  eq(#C.get_P().rows, 0, "no rows"); eq(#R.undo, 0, "no Undo steps"); eq(#C.get_P().notes, 0, "no notes"); eq(R.sel, nil)
  eq(Project.read(), "", "nothing written")
  r.Main_openProject("noprompt:" .. proj_file)
  Project.update()
  eq(texts(), "C", "the first project has its list")
  clear_project()
  R.pdirty = true
  Project.save()
  R.undo = { "row=1\t0\t\tC" }
  r.Main_openProject("noprompt:" .. other)
  Project.update()
  eq(#R.undo, 0, "2 projects without a list")
  r.Main_openProject("noprompt:" .. proj_file)
  Project.update()
end)

test("Save as keeps the list and the Undo steps", function()
  clear_project()
  set_rows({ { 1, "C" } })
  R.pdirty = true
  Project.save()
  List.step()
  r.Main_SaveProjectEx(0, tmp .. "\\saved_as.rpp", 0)
  Project.update()
  eq(texts(), "C"); eq(#R.undo, 1)
  r.Main_SaveProjectEx(0, proj_file, 0)
  Project.update()
  clear_project()
end)

test("find: the notes of a WAV file, in project time, with the key of the name", function()
  clear_project()
  -- 120 BPM: 1 bar = 2 s. C C | Eb F | (silence) | C C, from bar 2 (2 s); 30 cents sharp
  local path = bass_wav("Far Away-Bass-C minor-120bpm.wav", { { 36, 1 }, { 36, 1 }, { 39, 1 }, { 41, 1 }, { nil, 2 }, { 32, 2 } }, 30)
  local tr = add_track("Bass")
  local it, tk = add_item(tr, path, 2)
  local list, tune, stop = find_all(it, tk)
  ok(math.abs(tune - 0.3) < 0.04, string.format("tuning 0.30 (got %.2f)", tune))
  ok(math.abs(stop - 10) < 0.01, "the end")
  local _, guid = r.GetSetMediaItemInfo_String(it, "GUID", "", false)
  Find.done({ guid = guid, name = Find.name(it) }, list, tune, stop)
  eq(C.get_P().key, "C minor")
  eq(texts(), "C | Eb - F (D 3) | Ab", "F2 is above the lowest octave; C2 (A 3) and Ab1 are not")
  local rows = C.get_P().rows
  for i, t in ipairs({ 2, 4, 8 }) do ok(math.abs(rows[i].t - t) < 0.06, string.format("row %d at %d s (got %.3f)", i, t, rows[i].t)) end
  for i = 1, 3 do eq(rows[i].doubt, false, "row " .. i .. " sure") end
  ok(Find.item() == it, "the item is found again")
  List.set_mode("change")
  eq(texts(), "C | Eb | F (D 3) | Ab")
  List.undo()
  eq(texts(), "C | Eb - F (D 3) | Ab")
end)

test("tuning: which found notes are heard again (only those that can now be an octave lower)", function()
  local need = Find.retune_need
  eq(need({ pc = 2, midi = 38 }, 28, 26), "hear", "Standard -> Drop D: a D in the lowest octave")
  eq(need({ pc = 2, midi = 50 }, 28, 26), 50, "a higher D stays")
  eq(need({ pc = 4, midi = 28 }, 28, 26), 28, "E: the same lowest octave")
  eq(need({ pc = 2, midi = 26 }, 26, 28), 38, "Drop D -> Standard: the low D goes up into the lowest octave")
  eq(need({ pc = 3, midi = 39 }, 28, 27), "hear", "Half step down: Eb")
  eq(Find.retune_pick(nil, 26), 38, "too short: the octave it had")
  eq(select(2, Find.retune_pick(nil, 26)), true, "and yellow")
  eq(Find.retune_pick(-30, 26), 38, "odd harmonics far below: the higher octave")
  eq(Find.retune_pick(10, 26), 26, "strong odd harmonics: the low octave")
end)

test("tuning: a low D (a generated WAV) found in Standard becomes D1 in Drop D; your correction stays; Undo", function()
  clear_project(); clear_tempo()
  -- D1 (26), A1 (33), D1, F2 (41): in Standard the lowest D is D2 (38)
  local path = bass_wav("dropd.wav", { { 26, 1 }, { 33, 1 }, { 26, 1 }, { 41, 1 } })
  local tr = add_track("Bass")
  local it, tk = add_item(tr, path, 0)
  local list, tune, stop = find_all(it, tk)
  local _, guid = r.GetSetMediaItemInfo_String(it, "GUID", "", false)
  local p = C.get_P()
  p.key, p.mode, p.tuning = "D minor", "change", "std"
  Find.done({ guid = guid, name = "dropd" }, list, tune, stop)
  R.ask = nil -- (no key question: the key is known)
  p = C.get_P()
  local d = {}
  for _, n in ipairs(p.notes) do if n.pc == 2 then d[#d + 1] = n.midi end end
  eq(table.concat(d, " "), "38 38", "Standard: the D notes in its lowest octave")
  eq(#p.rows, 4, texts())
  p.rows[2].text = "A (mine)"
  local heard = List.set_tuning("dropd")
  eq(heard, 2, "the 2 D notes heard again")
  d = {}
  for _, n in ipairs(C.get_P().notes) do if n.pc == 2 then d[#d + 1] = n.midi end end
  eq(table.concat(d, " "), "26 26", "Drop D: D1")
  eq(C.get_P().rows[2].text, "A (mine)", "your correction stays")
  List.undo()
  eq(C.get_P().tuning, "std"); eq(C.get_P().notes[1].midi, 38, "Undo: the notes before")
end)

test("find: every note from E1 to G3 (the 2 methods agree on a clean note)", function()
  clear_project()
  local list = {}
  for m = 28, 55 do list[#list + 1] = { m, 0.5 } end
  local tr = add_track("Bass")
  local it, tk = add_item(tr, bass_wav("chromatic.wav", list), 0)
  local found = find_all(it, tk)
  local k = 1
  for _, n in ipairs(found) do if list[k] and n.pc == list[k][1] % 12 then k = k + 1 end end
  eq(k - 1, #list, "notes in order")
  eq(#found, #list, "no extra notes")
end)

test("find: in steps, as in the window", function()
  clear_project()
  local tr = add_track("Bass")
  local it = add_item(tr, bass_wav("steps.wav", { { 36, 2 }, { 41, 2 } }), 0)
  r.SetMediaItemSelected(it, true)
  Find.begin()
  ok(R.find, "running")
  local n = 0
  while R.find and n < 2000 do Find.step(); n = n + 1 end
  ok(n > 1, "more than 1 step (" .. tostring(TR.notice and TR.notice.text) .. ")")
  eq(texts(), "C | F (D 3)")
end)

test("find: a deleted item or another project stops it", function()
  clear_project()
  local tr = add_track("Bass")
  local it = add_item(tr, tmp .. "\\steps.wav", 0)
  r.SetMediaItemSelected(it, true)
  Find.begin()
  Find.step()
  r.DeleteTrackMediaItem(tr, it)
  Find.step()
  eq(R.find, nil)
  local it2 = add_item(tr, tmp .. "\\steps.wav", 0)
  r.SetMediaItemSelected(it2, true)
  Find.begin()
  ok(R.find)
  r.Main_SaveProject(0, false)
  r.Main_openProject("noprompt:" .. tmp .. "\\other.rpp")
  Project.update()
  eq(R.find, nil, "another project")
  r.Main_openProject("noprompt:" .. proj_file)
  Project.update()
end)

test("find: what cannot be read says why", function()
  clear_project()
  R.trk = nil
  local item, why = Find.source()
  eq(item, nil); ok(why:find("Pick the bass track"), why)
  local tr = add_track("Bass")
  local midi = r.CreateNewMIDIItemInProj(tr, 0, 2, false)
  r.SetMediaItemSelected(midi, true)
  item, why = Find.source()
  eq(item, nil); ok(why:find("no audio item"), why)
  r.AddMediaItemToTrack(tr) -- (an empty item: no take)
  item, why = Find.source()
  eq(item, nil); ok(why:find("no audio item"), why)
end)

test("undo: 1 undo for the list and Write, in the order they happened; Write undone in REAPER: only the list", function()
  clear_project()
  set_rows({ { 1, "C" }, { 3, "F" } })
  Out.write("markers")
  ok(markers() ~= "", "written: " .. markers())
  List.delete(1)
  eq(texts(), "F")
  List.undo()
  eq(texts(), "C | F", "1st: the list change")
  ok(markers() ~= "", "the markers stay")
  List.undo()
  eq(markers(), "", "2nd: Write")
  eq(texts(), "C | F", "the list stays")
  Out.write("markers")
  r.Main_OnCommand(40029, 0) -- (Write undone in REAPER itself)
  List.delete(1)
  List.undo(); List.undo()
  eq(texts(), "C | F", "no 2nd REAPER undo for a step that is gone")
  eq(#R.undo, 0)
  -- a newer REAPER step after Write (debug-time 25 November 2026): Undo leaves the markers, and the notice says why
  Out.write("markers")
  r.InsertTrackAtIndex(r.CountTracks(0), false)
  r.Undo_OnStateChange2(0, "test: a newer step")
  eq(r.Undo_CanUndo2(0), "test: a newer step", "REAPER's last step")
  TR.notice = nil
  List.undo()
  ok(markers() ~= "", "the markers stay")
  ok(TR.notice and TR.notice.warn and TR.notice.text:find("Undo History", 1, true), "the notice: " .. tostring(TR.notice and TR.notice.text))
end)

test("key: a suggestion from the found notes (major, minor, the usual names); too few notes: none", function()
  local function seq(pcs, lens)
    local list, t = {}, 0
    for i, pc in ipairs(pcs) do list[i] = { pc = pc, t = t, t1 = t + (lens and lens[i] or 0.5) }; t = t + 1 end
    return list
  end
  eq(C.Key.guess(seq({ 0, 4, 7, 0, 5, 7, 0, 2, 4, 0 }, { 2, 1, 1, 2, 0.5, 1, 2, 0.5, 1, 2 })), "C major")
  eq(C.Key.guess(seq({ 9, 0, 4, 9, 2, 4, 9, 7, 0, 9 }, { 2, 1, 1, 2, 0.5, 1, 2, 0.5, 1, 2 })), "A minor")
  eq(C.Key.guess(seq({ 3, 7, 10, 3, 8, 10, 3, 5, 7, 3 }, { 2, 1, 1, 2, 0.5, 1, 2, 0.5, 1, 2 })), "Eb major", "a flat key")
  eq(C.Key.guess(seq({ 0, 4, 7 })), nil, "3 notes: none")
end)

test("found tab: a staccato note lasts to the next note; only a gap of an 8th or more is a rest", function()
  local list = C.Imp.legato({ { q0 = 0, q1 = 0.25 }, { q0 = 0.5, q1 = 0.75 }, { q0 = 1.5, q1 = 1.75 }, { q0 = 2, q1 = 2.5 } }, 0.5)
  eq(list[1].q1, 0.5, "a 16th gap: to the next note")
  eq(list[2].q1, 0.75, "a gap of 3 16ths: a rest")
  eq(list[3].q1, 2, "a 16th gap")
  eq(list[4].q1, 2.5, "the last note stays")
end)

test("found tab grid: near an 8th -> the 8th; a scoop or a false 2nd pluck before an 8th goes; a real 16th run stays", function()
  local function n(i, q0, q1, midi) return { i = i, q0 = q0, q1 = q1, midi = midi } end
  local function starts(list)
    local t = {}
    for _, x in ipairs(list) do t[#t + 1] = string.format("%g:%d", x.q0, x.midi) end
    return table.concat(t, " ")
  end
  eq(starts(C.Imp.grid({ n(1, 0.08, 0.4, 36), n(2, 0.57, 0.9, 36), n(3, 1.2, 1.4, 36) }, 0)), "0:36 0.5:36 1.25:36",
    "a little late: the 8th; clearly off: the 16th")
  eq(starts(C.Imp.grid({ n(1, 0.25, 0.4, 35), n(2, 0.5, 1, 36) }, 0)), "0.5:36", "B scooped into C: C only")
  eq(starts(C.Imp.grid({ n(1, 0.25, 0.4, 36), n(2, 0.5, 1, 36) }, 0)), "0.5:36", "C plucked 2 times: 1 C")
  eq(starts(C.Imp.grid({ n(1, 0, 0.25, 33), n(2, 0.25, 0.5, 35), n(3, 0.5, 0.75, 36), n(4, 0.75, 1, 38) }, 0)),
    "0:33 0.25:35 0.5:36 0.75:38", "a 16th run stays")
  eq(starts(C.Imp.grid({ n(1, 0.25, 0.4, 31), n(2, 0.5, 1, 36) }, 0)), "0.25:31 0.5:36", "a jump of a 4th: a real note")
  eq(starts(C.Imp.grid({ n(1, 0.1, 0.4, 36) }, 0.1)), "0:36", "the delay")
end)

test("loop: a line loops from its start to the next line; the last one to the end of the item, at most 4 s", function()
  set_rows({ { 1, "C" }, { 3, "F" }, { 10, "G" } })
  local a, b = List.row_span(1); eq(a, 1); eq(b, 3)
  a, b = List.row_span(3); eq(a, 10); eq(b, 14, "the last: 4 s")
  C.get_P().t_end = 11.5
  a, b = List.row_span(3); eq(b, 11.5, "the end of the bass item")
  eq(List.row_span(4), nil, "no such line")
end)

test("find: the Track row: the selected audio item on the track, else its longest; your choice of track", function()
  eq(Find.pick({}), nil, "no audio item")
  eq(Find.pick({ { len = 2 }, { len = 9 }, { len = 4 } }), 2, "the longest")
  eq(Find.pick({ { len = 2 }, { len = 9 }, { len = 4, sel = true } }), 3, "the selected one")
  clear_project()
  local bass, other = add_track("Bass"), add_track("Guitar")
  local short = add_item(bass, tmp .. "\\steps.wav", 0)
  r.SetMediaItemInfo_Value(short, "D_LENGTH", 1)
  local long = add_item(bass, tmp .. "\\steps.wav", 10)
  local g = add_item(other, tmp .. "\\steps.wav", 0)
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(g, true)
  R.trk = nil
  eq(Find.source(), g, "no choice: the track of the selected item")
  R.trk = bass
  eq(Find.source(), long, "your track: its longest item (the selected one is on another track)")
  r.SetMediaItemSelected(short, true)
  eq(Find.source(), short, "a selected item on your track")
  R.trk = nil
end)

test("find: silence gives no notes and keeps the list", function()
  clear_project()
  set_rows({ { 1, "C" } })
  local tr = add_track("Bass")
  local it, tk = add_item(tr, bass_wav("silence.wav", { { nil, 2 } }), 0)
  local list, tune, stop = find_all(it, tk)
  eq(#list, 0)
  Find.done({ guid = "", name = "" }, list, tune, stop)
  eq(texts(), "C")
  local it2, tk2 = add_item(tr, bass_wav("tiny.wav", { { 36, 0.02 } }), 5)
  eq(#find_all(it2, tk2), 0, "a tiny file")
end)

test("write: markers, again without doubles, 1 undo step", function()
  clear_project()
  r.AddProjectMarker2(0, false, 0.5, 0, "Mine", -1, 0)
  set_rows({ { 1, "Ab" }, { 2, "Ab - Bb" } })
  Out.write("markers")
  eq(markers(), "Mine@0.5 Ab@1.0 Ab - Bb@2.0")
  List.set_text(1, "G")
  Out.write("markers")
  eq(markers(), "Mine@0.5 G@1.0 Ab - Bb@2.0")
  r.Undo_DoUndo2(0)
  eq(markers(), "Mine@0.5 Ab@1.0 Ab - Bb@2.0", "1 undo")
  Out.write("markers")
  eq(markers(), "Mine@0.5 G@1.0 Ab - Bb@2.0", "after the undo: no doubles")
  eq(r.CountTracks(0), 0, "no Notes track")
end)

test("write: the Notes track, above the bass; other items stay", function()
  clear_project()
  add_track("Music", 1)
  local bass = add_track("Bass", -1)
  local it = add_item(bass, tmp .. "\\steps.wav", 0)
  local p = set_rows({ { 0.5, "Ab" }, { 2, "Bb" } })
  p.src = select(2, r.GetSetMediaItemInfo_String(it, "GUID", "", false))
  Out.write("both")
  eq(track_names(), "Music:1 Notes:0 Bass:-1")
  eq(markers(), "Ab@0.5 Bb@2.0")
  local tr = r.GetTrack(0, 1)
  eq(r.CountTrackMediaItems(tr), 2)
  local i2 = r.GetTrackMediaItem(tr, 1)
  eq(select(2, r.GetSetMediaItemInfo_String(i2, "P_NOTES", "", false)), "Bb")
  ok(math.abs(r.GetMediaItemInfo_Value(i2, "D_LENGTH") - 2) < 0.01, "the last one ends with the bass item")
  local mine = r.AddMediaItemToTrack(tr)
  r.SetMediaItemInfo_Value(mine, "D_POSITION", 20)
  Out.write("track")
  eq(markers(), "", "only the track: no markers")
  eq(r.CountTrackMediaItems(tr), 3, "my item stays, no doubles")
  Out.write("markers")
  eq(r.CountTrackMediaItems(tr), 1, "only my item"); eq(track_names(), "Music:1 Notes:0 Bass:-1")
  r.DeleteTrackMediaItem(tr, mine)
  Out.write("track")
  Out.write("markers")
  eq(track_names(), "Music:1 Bass:-1", "an empty Notes track goes")
end)

test("finish: names", function()
  eq(Out.title("Far Away-Bass-C minor-166bpm-441hz.mp3"), "Far Away")
  eq(Out.title("01. Far_Away-bass-C minor-160bpm.m4a"), "Far Away")
  eq(Out.title("Bass.wav"), "Bass", "only the instrument")
  eq(Out.title(""), "")
  eq(Out.artist("12 - The Band - Far Away.RPP", "far away"), "The Band")
  eq(Out.artist("12 - Far Away.RPP", "Far Away"), "", "a number is no artist")
  eq(Out.artist("", "Far Away"), "")
  eq(Out.region_name("The Band", "Far Away", "C minor"), "The Band - Far Away - C Minor")
  eq(Out.region_name("", "Far Away", ""), "Far Away")
  eq(Out.region_name(" ", "", ""), "")
end)

test("finish: the region, the plugins, the metronome track, the list", function()
  clear_project()
  add_track("Music", 1)
  local bass = add_track("Bass")
  add_track("Metronome", -1)
  add_track("Clicky")
  r.TrackFX_AddByName(bass, "ReaEQ", false, -1)
  r.TrackFX_AddByName(bass, "ReaTune", false, -1)
  local it = add_item(bass, tmp .. "\\steps.wav", 2.5)
  local p = set_rows({ { 3, "C" } }, "C minor")
  p.src = select(2, r.GetSetMediaItemInfo_String(it, "GUID", "", false))
  Out.write("markers")
  Out.finish_begin()
  local f = R.finish
  eq(f.fresh, true); eq(f.fx, 2); eq(#f.clicks, 1); eq(f.clicks[1].name, "Metronome")
  List.set_text(1, "D")
  Out.finish_begin()
  eq(R.finish.fresh, false, "changed since Write")
  List.undo()
  f = R.finish
  f.artist, f.title = "The Band", "Far Away"
  Out.finish(f)
  eq(markers(), "[The Band - Far Away - C Minor 2.0-8.0] C@3.0")
  eq(track_names(), "Music:1 Bass:-1 Clicky:0", "the folder still ends")
  eq(r.TrackFX_GetCount(bass), 0)
  eq(#C.get_P().rows, 0); eq(List.serialize(C.get_P()), "", "the list leaves the project")
  r.Undo_DoUndo2(0)
  eq(track_names(), "Music:1 Bass:0 Metronome:-1 Clicky:0", "1 undo")
  eq(r.TrackFX_GetCount(r.GetTrack(0, 1)), 2)
  eq(markers(), "C@3.0")
  List.undo()
  eq(texts(), "C", "Undo brings the list back")
  Out.write("markers")
  eq(markers(), "C@3.0", "and it knows its markers")
end)

test("finish: everything off, and the same region again", function()
  clear_project()
  local bass = add_track("Bass")
  r.TrackFX_AddByName(bass, "ReaEQ", false, -1)
  add_track("Click")
  local it = add_item(bass, tmp .. "\\steps.wav", 0)
  for _ = 1, 2 do
    local p = set_rows({ { 1, "C" } }, "")
    p.src = select(2, r.GetSetMediaItemInfo_String(it, "GUID", "", false))
    Out.finish_begin()
    local f = R.finish
    f.del_fx, f.del_clicks, f.artist, f.title = false, false, "", "Far Away"
    Out.finish(f)
  end
  eq(markers(), "[Far Away 0.0-6.0]", "1 region")
  eq(track_names(), "Bass:0 Click:0"); eq(r.TrackFX_GetCount(bass), 1)
  set_rows({ { 1, "C" } })
  Out.finish_begin()
  R.finish.artist, R.finish.title = "", ""
  eq(Out.finish(R.finish), "", "no name, no bass item: no region")
  eq(markers(), "[Far Away 0.0-6.0]")
end)

test("settings: defaults and bad values", function()
  C.Util.apply_setting("out", "both"); eq(C.S.out, "both")
  C.Util.apply_setting("out", "x"); eq(C.S.out, "markers")
  C.Util.apply_setting("frets", "0"); eq(C.S.frets, false)
  C.Util.apply_setting("frets", "1")
  C.Util.apply_setting("finger", "0"); eq(C.S.finger, false)
  C.Util.apply_setting("finger", "1")
  C.Util.apply_setting("strings", "x"); eq(C.S.strings, "letters")
  C.Util.apply_setting("simple", "1"); eq(C.S.simple, nil, "a removed setting (Simple mode) is not read")
  eq(table.concat(C.Util.settings_lines(), " "), "out=markers frets=1 finger=1 strings=letters export_dir= splits=0")
  C.Util.apply_setting("export_dir", " D:\\Songs ")
  eq(C.S.export_dir, "D:\\Songs")
  C.Util.apply_setting("export_dir", "")
end)

test("key change: the names follow the new key from that line; saved; removed; Write makes a marker", function()
  clear_project(); clear_tempo()
  set_rows({ { 1, "G#" }, { 3, "G# - C" }, { 5, "G# (A 11)" } }, "C minor")
  List.set_key("C minor")
  List.respell()
  eq(texts(), "Ab | Ab - C | Ab (A 11)")
  List.key_from(2, "E major")
  eq(texts(), "Ab | G# - C | G# (A 11)", "from line 2 on; brackets stay")
  eq(List.key_at(4), "E major"); eq(List.key_at(2), "C minor")
  local q = List.parse(List.serialize(C.get_P()))
  eq(#q.keys, 1); eq(q.keys[1].key, "E major"); near(q.keys[1].t, 3, 1e-6)
  List.set_key("C major")
  eq(texts(), "Ab | G# - C | G# (A 11)", "the song key: only the lines before the change")
  Out.write("markers")
  ok(markers():find("Key: E major@3.0", 1, true), markers())
  List.key_from(2, "")
  eq(texts(), "Ab | Ab - C | Ab (A 11)", "removed")
  List.undo()
  eq(texts(), "Ab | G# - C | G# (A 11)", "Undo brings it back")
end)

test("saved notes: the found notes go out and come back with the list; Markers can change after a reopen", function()
  local p = set_rows({ { 0, "C" } })
  p.notes, p.t_end = notes({ { 0, 0, 0.9 }, { 5, 1, 1.9, true } }), 2
  p.notes[1].midi, p.notes[2].midi = 36, 41
  local q = List.parse(List.serialize(p))
  eq(#q.notes, 2); eq(q.notes[2].midi, 41); eq(q.notes[2].doubt, true); near(q.notes[2].t1, 1.9, 1e-6); near(q.t_end, 2, 1e-6)
  C.set_P(q)
  List.set_mode("change")
  eq(texts(), "C | F (D 3)", "grouped again from the saved notes")
end)

test("clear: the list and what the tab wrote go; 1 Undo brings both back", function()
  clear_project(); clear_tempo()
  add_track("Bass")
  local p = set_rows({ { 1, "C" }, { 3, "F" } })
  p.notes = notes({ { 0, 1, 2 } })
  r.AddProjectMarker2(0, false, 7, 0, "mine", -1, 0)
  Out.write("both")
  C.get_P().notes = notes({ { 0, 1, 2 } })
  C.get_P().notes[1].midi = 36
  C.Export.run({ item = true, file = false, step = 0.25 })
  Out.clear()
  eq(markers(), "mine@7.0", "only my own marker stays")
  eq(track_names(), "Bass:0", "no Notes track, no Bass MIDI track")
  eq(#C.get_P().rows, 0); eq(#C.get_P().notes, 0)
  eq(r.Undo_CanUndo2(0), "Tab Viewer: clear")
  List.undo()
  eq(texts(), "C | F", "Undo: the list")
  ok(markers():find("C@1.0", 1, true), "and the markers " .. markers())
  eq(r.Undo_CanUndo2(0), "Tab Viewer: export MIDI", "the step before it stays")
end)

test("Write: 'Written (n markers)' until the list changes", function()
  clear_project()
  set_rows({ { 1, "C" }, { 3, "F" } })
  eq(R.written_lbl, nil)
  Out.write("markers")
  eq(R.written_lbl, "Written (2 markers)")
  List.delete(1)
  eq(R.written_lbl, nil, "the list changed")
  Out.write("track")
  eq(R.written_lbl, "Written (1 text item)")
  List.undo()
  eq(R.written_lbl, nil, "Write undone")
end)

test("found notes as a tab: the bars from the bar of the first note, the 16th grid, the fingering of the list", function()
  clear_project(); clear_tempo()
  local p = set_rows({ { 2, "C" } })
  -- 120 BPM: bar 2 from 2 s; notes on 1, 1&, 4 (bar 2) and 1 of bar 4 (bar 3 is empty)
  p.notes = notes({ { 0, 2, 2.2 }, { 3, 2.25, 2.45 }, { 5, 3.5, 3.9 }, { 7, 6, 6.4, true } })
  for k, m in ipairs({ 36, 39, 41, 43 }) do p.notes[k].midi = m end
  local doc = C.Imp.found_doc()
  eq(doc.m0 + 1, 2, "bar 1 of the tab = bar 2 of the song")
  eq(#doc.mbars, 3, "bars 2, 3 (empty) and 4"); eq(doc.tracks[1].kind, "bass")
  local tab = doc.tab()
  eq(#tab.bars, 3); eq(#tab.bars[2].notes, 0); near(tab.bars[3].q0, 8, 1e-6, "bar 4: 8 quarter notes after bar 2")
  local s = {}
  for _, nt in ipairs(tab.bars[1].notes) do s[#s + 1] = string.format("%g:%s%d", nt.q, tab.names[nt.s], nt.fret) end
  eq(table.concat(s, " "), "0:A3 0.5:A6 3:D3", "places and frets (the hand stays in 3rd position)")
  near(tab.bars[1].notes[1].len, 0.5, 1e-6, "a note ends where the next one starts (the export's grid)")
  ok(doc.tab() ~= tab, "a new tab each time (Tab Viewer changes it)")
  C.set_P(List.default())
  eq(C.Imp.found_doc(), nil, "no notes: no tab")
end)

test("slides: a glide into a note is 1 note (no mark, decided 25 November 2026); a plain note change too (generated WAV)", function()
  clear_project(); clear_tempo()
  local tr = add_track("Bass")
  local it, tk = add_item(tr, path_wav("slide.wav", { { nil, 0.3 }, { 36, 0.8, 0.15 }, { 41, 0.8 }, { nil, 0.3 } }), 0)
  local list, _, t_end = find_all(it, tk)
  local slid = false
  for _, n in ipairs(list) do if n.slide then slid = true end end
  ok(slid, "the slide into F is found")
  eq(texts(Group.make(list, "change", "", 0, t_end, List.opt())), "C | F (D 3)", "no mark")
  it, tk = add_item(tr, path_wav("noslide.wav", { { nil, 0.3 }, { 36, 0.8 }, { 41, 0.8 }, { nil, 0.3 } }), 5)
  list, _, t_end = find_all(it, tk)
  eq(texts(Group.make(list, "change", "", 0, t_end, List.opt())), "C | F (D 3)", "a plain note change")
end)

test("glitch filter: a short passing note (2 semitones) stays (generated WAV; the overtone jump itself: trial 7)", function()
  clear_project(); clear_tempo()
  local it, tk = add_item(add_track("Bass"), path_wav("passing.wav", { { nil, 0.3 }, { 36, 0.6 }, { 38, 0.15 }, { 36, 0.6 }, { nil, 0.3 } }), 0)
  local t = {}
  for k, n in ipairs(find_all(it, tk)) do t[k] = tostring(n.pc) end
  eq(table.concat(t, " "), "0 2 0", "C - D - C")
end)

-- a bass tone at 4000 Hz in memory (as bass_wav): { { midi or nil (silence), seconds, gain (dB, default 0) } }
local function tone4k(list)
  local x = {}
  for _, n in ipairs(list) do
    local len = math.floor(n[2] * 4000)
    local hz, g = n[1] and 440 * 2 ^ ((n[1] - 69) / 12) or 0, 10 ^ ((n[3] or 0) / 20)
    for i = 0, len - 1 do
      local v = 0
      if n[1] then
        local t = i / 4000
        local env = math.min(1, i / 18) * math.min(1, (len - i) / 136) * (0.5 + 0.5 * math.exp(-3 * t))
        local a = 2 * math.pi * hz * t
        v = 0.3 * g * env * (math.sin(a) + 0.6 * math.sin(2 * a) + 0.4 * math.sin(3 * a) + 0.2 * math.sin(4 * a))
      end
      x[#x + 1] = v
    end
  end
  return x
end
local function times_near(list, want, what)
  eq(#list, #want, what .. ": the number")
  for i, v in ipairs(want) do near(list[i], v, 0.02, what .. " " .. i) end
end

test("onsets: 1 per pluck; a held note has none inside; the same note plucked again; a soft part (generated)", function()
  local Det = C.Det
  times_near(Det.onsets_of(tone4k({ { nil, 0.5 }, { 28, 2 } }), 4000), { 0.5 }, "a held low E: only its start")
  times_near(Det.onsets_of(tone4k({ { nil, 0.5 }, { 33, 0.25 }, { 33, 0.25 }, { 33, 0.25 }, { 33, 0.25 } }), 4000),
    { 0.5, 0.75, 1, 1.25 }, "the same A, 4 plucks without a gap")
  -- faint noise before the bass (the bleed of a separated stem, 60 dB down): no pluck and no note there (lessons:
  -- Set tempo aligned that noise instead of the first bass note)
  local x, seed = {}, 1
  for i = 1, 4000 do seed = (seed * 1103515245 + 12345) % 2147483648; x[i] = 0.0003 * (seed / 2147483648 - 0.5) end
  for _, v in ipairs(tone4k({ { 33, 1 } })) do x[#x + 1] = v end
  times_near(Det.onsets_of(x, 4000), { 1 }, "noise 60 dB down, then A at 1 s: only the A")
  local found = Det.analyse(x, function() end, 28)
  eq(#found, 1, "1 note, none in the noise"); near(found[1].t, 1, 0.02)
  near(C.TP.first_sound(x, 4000), 1, 0.011, "the first sound for Set tempo: the A, not the noise")
  eq(C.TP.first_sound({ 0, 0, 0 }, 4000), nil, "silence")
  -- (a loud note straight into a much softer one hides the soft start: that note starts at its pitch change instead)
  times_near(Det.onsets_of(tone4k({ { 36, 1 }, { 36, 1 }, { nil, 0.3 }, { 43, 1, -25 }, { 43, 1, -25 }, { 36, 1 } }), 4000),
    { 0, 1, 2.3, 3.3, 4.3 }, "the soft part (25 dB lower) keeps its plucks (Dev 5)")
end)

test("notes: they start at the onsets, end at their own end (not over a silence), 1 pitch each (generated)", function()
  local notes = C.Det.analyse(tone4k({ { 28, 1 }, { nil, 0.4 }, { 40, 1 }, { 33, 0.25 }, { 33, 0.25 } }), function() end, 28)
  local want = { { 28, 0, 0.97 }, { 40, 1.4, 2.38 }, { 33, 2.4, 2.63 }, { 33, 2.65, 2.88 } }
  eq(#notes, #want, "E1, E2, the A twice")
  for i, w in ipairs(want) do
    eq(notes[i].midi, w[1], "note " .. i)
    near(notes[i].t, w[2], 0.02, "the start of note " .. i)
    near(notes[i].t1, w[3], 0.05, "the end of note " .. i .. " (E1: before the silence)")
  end
end)

test("octave limit of a song: the emptiest place between the 2 groups; few notes or no gap: the fixed limit", function()
  local Det, CFG = C.Det, C.CFG
  local v = {}
  for k = 1, 60 do v[#v + 1] = -25 + (k % 7) end -- (the high octave: -25 .. -19)
  for k = 1, 20 do v[#v + 1] = -6 + (k % 5) end -- (the low octave: -6 .. -2)
  local lim = Det.octave_limit(v)
  ok(lim > -18 and lim < -7, "between the groups (got " .. lim .. ")")
  eq(Det.octave_limit({ -25, -3 }), CFG.OCT_DB, "few notes")
  local flat = {}
  for k = 1, 80 do flat[k] = -20 + k / 4 end
  eq(Det.octave_limit(flat), CFG.OCT_DB, "no gap")
end)

test("doubtful lines say why (UX 1); after a reopen only 'listen to it'", function()
  clear_project()
  local p = set_rows({ { 2, "E", true }, { 4, "A" } })
  p.notes = notes({ { 4, 2, 2.5, true }, { 9, 4, 4.5 } })
  p.notes[1].why = "octave"
  eq(List.why(1), "Not sure: the octave is unsure (high or low?).")
  eq(List.why(2), nil, "not doubtful")
  p = set_rows({ { 2, "E", true } })
  p.notes = notes({ { 4, 2, 2.5, true } })
  eq(List.why(1), "Not sure: listen to it.", "no reason known")
end)

test("repeated notes: split on the 16th grid when the project has a tempo marker; the marker stays 1 note (generated WAV)", function()
  clear_project(); clear_tempo()
  local tr = add_track("Bass")
  local dips = {}
  for k = 1, 7 do dips[k] = 0.5 + k * 0.25 end -- (120 BPM: 8th notes from 0.5 s in the file)
  local it, tk = add_item(tr, path_wav("eighths_legato.wav", { { nil, 0.5 }, { 36, 2 }, { nil, 0.5 } }, dips), 1.5)
  local list, _, t_end = find_all(it, tk)
  eq(#list, 8, "no tempo marker: the onsets hear the 8 plucks (review 23 November 2026; before: 1 long note)")
  r.SetTempoTimeSigMarker(0, -1, 0, -1, -1, 120, 4, 4, false)
  list, _, t_end = find_all(it, tk)
  eq(#list, 8, "8 notes on the grid, not more")
  eq(texts(Group.make(list, "bar", "", 0, t_end, List.opt())), "C", "the marker: only the note (no 8ths label)")
  eq(#C.Export.notes(list, 0.25), 8, "8 notes in the export")
end)

test("1 mode (25 November 2026): the fingering of runs, no slide mark, no beat count", function()
  local list = notes({ { 5, 0, 0.4 }, { 3, 0.5, 0.9 }, { 0, 1, 1.4 }, { 10, 1.5, 1.9 }, { 7, 2, 3.9 } })
  for i, m in ipairs({ 41, 39, 36, 34, 43 }) do list[i].midi = m end
  list[5].slide = true
  eq(texts(Group.rows(list, bars(2, 2), "C minor", List.opt())), "F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1) | G (G 0)")
  set_rows({ { 2, "C - G (D 5)", false, { 2, 3 } } })
  eq(Out.item_text(1), "C - G (D 5)", "the Notes track item: the line")
end)

test("strings of the notes: a note with its string (from a tab) keeps it; the list and the found tab use that place", function()
  clear_project(); clear_tempo()
  local p = set_rows({ { 2, "C" } })
  p.notes = notes({ { 0, 2, 2.4 }, { 7, 2.5, 2.9 } })
  p.notes[1].midi, p.notes[2].midi = 36, 43
  eq(C.List.places()[2].s, 3, "G2 after C2: D 5")
  p.notes[2].s = 4
  R.places = nil
  eq(C.List.places()[2].s, 4, "its string stays (the open G)")
  eq(texts(Group.rows(p.notes, bars(2, 2), "", List.opt())), "C - G (G 0)", "the list uses the same place")
  eq(List.parse(List.serialize(C.get_P())).notes[2].s, 4, "saved")
  local tab = C.Imp.found_doc().tab()
  eq(tab.bars[1].notes[2].s, 4, "the found tab too"); eq(tab.bars[1].notes[2].fret, 0)
end)

-- (the Guitar Pro reader itself, and the notes of Tab Viewer's tab: tests\tabviewer.lua)
test("import to list: the tunings of the list", function()
  eq(C.Imp.tuning({ 24, 31, 36, 41 }).id, "dropc"); eq(C.Imp.tuning({ 1, 2, 3 }), nil)
  -- the tunings added on 26 November 2026: a D standard or 5-string A standard tab finds its own
  eq(C.Imp.tuning({ 26, 31, 36, 41 }).id, "dstd"); eq(C.Imp.tuning({ 21, 26, 31, 36, 41 }).id, "five_a")
  local seen = {}
  for _, t in ipairs(C.CFG.TUNINGS) do
    ok(not seen[t.id], "1 id once: " .. t.id); seen[t.id] = true
    ok(#t.open == 4 or #t.open == 5, t.id .. ": 4 or 5 strings (the string names)")
    for s = 2, #t.open do ok(t.open[s] > t.open[s - 1], t.id .. ": from the lowest string") end
  end
  ok(C.GP and C.GP.read, "the shared Guitar Pro reader is loaded")
end)

test("import to list: the notes of the tab replace the list; strings, tuning, the fixes of the found tab go; Undo", function()
  clear_project(); clear_tempo()
  local p = set_rows({ { 2, "F" } })
  p.notes = notes({ { 5, 2, 2.5 } })
  p.notes[1].midi = 41
  p.tuning = "dropc"
  p.tab = { edits = { [1] = { [1] = {} } } } -- (a fix of the found notes' tab)
  local list = { { t = 2, t1 = 4, midi = 36, s = 2 }, { t = 4, t1 = 4.5, midi = 40, s = 3 }, { t = 4.5, t1 = 5, midi = 40, s = 3 },
    { t = 5, t1 = 6, midi = 43, s = 4 } }
  local n = C.Imp.apply(list, { 28, 33, 38, 43 })
  eq(n, 4)
  local P2 = C.get_P()
  eq(P2.tuning, "std", "the tuning of the tab")
  near(P2.notes[1].t, 2, 1e-9); near(P2.notes[1].t1, 4, 1e-9)
  eq(P2.notes[2].s, 3, "the string of the tab"); eq(P2.notes[2].man, true); eq(P2.tab, nil, "the fixes are in the notes now")
  ok(#P2.rows > 0, "the list is made again")
  List.undo()
  eq(C.get_P().notes[1].midi, 41, "Undo: the notes before"); eq(C.get_P().tuning, "dropc")
  ok(C.get_P().tab and C.get_P().tab.edits, "and the fixes of the found tab")
end)

test("string names: letters or numbers as in tab books", function()
  local std, five = Key.tuning("std"), Key.tuning("five")
  eq(table.concat(Key.string_names(std, true), " "), "4 3 2 1")
  eq(table.concat(Key.string_names(five, true), " "), "5 4 3 2 1")
  eq(Key.place(40, std, Key.string_names(std, true)), " (3 7)")
  eq(Key.place(40, std), " (A 7)")
  C.S.strings = "numbers"
  eq(List.opt().names[1], "4")
  C.S.strings = "letters"
end)

test("Notes track items: the line; a key change line without markers", function()
  clear_project(); clear_tempo()
  set_rows({ { 2, "C - Eb (A 6) - G", false, { 2, 2.75, 3.5 } }, { 4, "F" } })
  eq(Out.item_text(1), "C - Eb (A 6) - G")
  List.key_from(2, "F major")
  eq(Out.item_text(2, true), "Key: F major\nF", "the key change on its first line (no markers)")
  eq(Out.item_text(2, false), "F")
end)

test("strings: the plain name in the lowest octave, else the lowest string with fret 7 or less", function()
  local std, five, dropc = Key.tuning("std"), Key.tuning("five"), Key.tuning("dropc")
  eq(Key.tuning("x").id, "std", "an unknown tuning is Standard")
  eq(Key.place(28, std), ""); eq(Key.place(39, std), "", "D# on the A string is still the lowest octave")
  eq(Key.place(40, std), " (A 7)"); eq(Key.place(43, std), " (D 5)"); eq(Key.place(45, std), " (D 7)")
  eq(Key.place(55, std), " (G 12)", "higher than fret 7 everywhere: the lowest fret")
  eq(Key.place(28, five), ""); eq(Key.place(40, five), " (A 7)")
  eq(Key.place(36, dropc), " (A 5)", "drop C: C2 is an octave above the low C")
  eq(Key.low(4, 28), 28); eq(Key.low(3, 28), 39); eq(Key.low(0, 24), 24); eq(Key.low(0, 28), 36)
end)

test("strings: the tuning of the song goes out and comes back with the list", function()
  local p = set_rows({ { 1, "C" } })
  eq(List.serialize(p):find("tuning=", 1, true), nil, "Standard is not written")
  List.set_tuning("five")
  local q = List.parse(List.serialize(C.get_P()))
  eq(q.tuning, "five")
  eq(List.parse("tuning=bad").tuning, "std")
  List.undo()
  eq(C.get_P().tuning, "std", "Undo")
end)

test("strings: E1, E2 and G2 of a WAV file (the octave), and with the switch off", function()
  clear_project()
  local tr = add_track("Bass")
  local it, tk = add_item(tr, bass_wav("octaves.wav", { { 28, 1 }, { nil, 0.4 }, { 40, 1 }, { nil, 0.4 }, { 43, 1 } }), 0)
  local list, _, t_end = find_all(it, tk)
  local mids = {}
  for i, n in ipairs(list) do mids[i] = tostring(n.midi) .. (n.doubt and "?" or "") end
  eq(table.concat(mids, " "), "28 40 43", "the octaves, none doubtful")
  local rows = Group.make(list, "change", "", 0, t_end, { tun = Key.tuning("std"), high = true })
  eq(texts(rows), "E | E (D 2) | G (G 0)", "the places of the fingering (as in the tab)")
  rows = Group.make(list, "change", "", 0, t_end, nil)
  eq(texts(rows), "E | G", "switches off: only the names (the same E is 1 part)")
  rows = Group.make(list, "change", "", 0, t_end, { tun = Key.tuning("five"), high = true })
  ok(texts(rows):find("^E | E %(") ~= nil, "5 strings: " .. texts(rows))
end)

test("export: the notes on the 16th grid, without overlaps", function()
  clear_tempo()
  local Export = C.Export
  -- 120 BPM: 1 quarter note = 0.5 s
  local list = Export.notes({ { pc = 0, midi = 36, t = 2.03, t1 = 2.97 }, { pc = 5, midi = 41, t = 2.9, t1 = 3.6 },
    { pc = 7, midi = 43, t = 2.91, t1 = 3.0 }, { pc = 4, t = 4.0, t1 = 4.01 } }, 0.25)
  local t = {}
  for i, x in ipairs(list) do t[i] = string.format("%d %.2f-%.2f", x.midi, x.q0, x.q1) end
  eq(table.concat(t, " | "), "36 4.00-5.75 | 41 5.75-7.25 | 28 8.00-8.25",
    "quantized; a note ends where the next starts; 2 on 1 step: the first stays; no octave: the lowest E")
  eq(Export.notes({ { pc = 0, midi = 36, t = 2.03, t1 = 2.97 } }, 0)[1].q0 > 4.05, true, "No quantize")
end)

test("export: notes that are all found late land on their own 16th (lessons, 23 November 2026)", function()
  clear_tempo()
  -- 120 BPM: a 16th = 0.125 s; every note found 0.07 s late (more than half a 16th), a little scatter
  local found, d = {}, { 0, 0.01, -0.01, 0.005, 0, -0.005, 0.01, 0 }
  for k = 1, 8 do found[k] = { pc = 0, midi = 36 + k, t = 2 + (k - 1) * 0.25 + 0.07 + d[k], t1 = 2 + k * 0.25 + 0.07 } end
  local list = C.Export.notes(found, 0.25)
  for k, x in ipairs(list) do near(x.q0, 4 + (k - 1) * 0.5, 1e-9, "note " .. k) end
end)

test("export: no .mid file (project not saved), but the MIDI item is made: the notice says both", function()
  C.get_P().notes = { { pc = 0, midi = 36, t = 2, t1 = 2.5 } }
  local fn = R.projfn
  R.projfn = ""
  local msg, warn = C.Export.run({ item = true, file = true, step = 0.25 })
  R.projfn = fn
  eq(warn, true)
  ok(msg:find("Made a MIDI item", 1, true) and msg:find("No files", 1, true), msg)
  r.Main_OnCommand(40029, 0) -- (the item goes again)
  C.get_P().notes = {}
end)

test("tempo: a project switch drops the Find tempo result", function()
  TR.tempo = { song = {} }
  TR.proj = nil -- (Tab Viewer sees another project)
  TV.Project.update()
  eq(TR.tempo, nil)
end)

test("export: notes that are all found a little early stay on their 16th, not 1 16th earlier (lessons, 23 November 2026)", function()
  clear_tempo()
  -- 120 BPM: a 16th = 0.125 s; every note found 0.035 s early (about 30% of a 16th), a little scatter
  local found, d = {}, { 0, 0.005, -0.005, 0.004, 0, -0.004, 0.003, 0 }
  for k = 1, 8 do found[k] = { pc = 0, midi = 36 + k, t = 2 + (k - 1) * 0.25 - 0.035 + d[k], t1 = 2 + k * 0.25 } end
  local list = C.Export.notes(found, 0.25)
  for k, x in ipairs(list) do near(x.q0, 4 + (k - 1) * 0.5, 1e-9, "note " .. k .. " (beat 1 must not move to 4a)") end
end)

test("export: the notes of a WAV file land on their 8th notes (lessons, 23 November 2026)", function()
  clear_project(); clear_tempo()
  local seq = { { nil, 0.5 } }
  for _, m in ipairs({ 36, 39, 41, 43, 36, 34, 31, 36 }) do seq[#seq + 1] = { m, 0.25 } end -- 120 BPM: 8th notes
  seq[#seq + 1] = { nil, 0.5 }
  local it, tk = add_item(add_track("Bass"), bass_wav("eighths.wav", seq), 1.5) -- the 1st note at 2 s = beat 5
  local list = C.Export.notes(find_all(it, tk), 0.25)
  eq(#list, 8, "8 notes")
  for k, x in ipairs(list) do near(x.q0, 4 + (k - 1) * 0.5, 1e-9, "note " .. k .. " on its 8th") end
end)

test("export: the MIDI item on the Bass MIDI track and the .mid file; again: replaced; 1 undo step", function()
  clear_project(); clear_tempo()
  Project.update()
  local tr = add_track("Bass")
  local it = add_item(tr, bass_wav("Far Away-Bass-C minor.wav", { { 36, 1 }, { 41, 1 } }), 2)
  local list, tune, stop = find_all(it, r.GetActiveTake(it))
  local _, guid = r.GetSetMediaItemInfo_String(it, "GUID", "", false)
  Find.done({ guid = guid, name = Find.name(it) }, list, tune, stop)
  local path = C.Export.path()
  ok(path and path:find("Far Away %- Bass%.mid$"), "the file name: " .. tostring(path))
  C.S.export_dir = tmp .. "\\Exports"
  local p2 = C.Export.path()
  ok(p2:find("Exports/Far Away - Bass.mid", 1, true), "the chosen folder: " .. p2)
  C.Export.run({ item = false, file = true, step = 0.25 })
  ok(r.file_exists(p2), "written into the chosen folder (made when missing)")
  os.remove(p2)
  C.S.export_dir = ""
  os.remove(path)
  local msg, warn = C.Export.run({ item = true, file = true, step = 0.25 })
  eq(warn, nil, msg)
  ok(msg:find("Exported 2 notes", 1, true), msg)
  local mt = C.Out.find_track("midi")
  ok(mt, "the Bass MIDI track")
  eq(select(2, r.GetTrackName(mt)), "Bass MIDI")
  eq(r.CountTrackMediaItems(mt), 1)
  local take = r.GetActiveTake(r.GetTrackMediaItem(mt, 0))
  local _, nn = r.MIDI_CountEvts(take)
  eq(nn, 2, "2 notes")
  local _, _, _, s1, _, _, p1 = r.MIDI_GetNote(take, 0)
  local _, _, _, s2, _, _, p2 = r.MIDI_GetNote(take, 1)
  eq(p1, 36); eq(p2, 41)
  near(r.MIDI_GetProjQNFromPPQPos(take, s1), 4, 1e-6, "the 1st note on beat 1 of bar 2")
  near(r.MIDI_GetProjQNFromPPQPos(take, s2), 6, 1e-6, "the 2nd note")
  local f = assert(io.open(path, "rb"))
  local data = f:read("a")
  f:close()
  eq(data:sub(1, 4), "MThd")
  ok(data:find("\xFF\x51\x03\x07\xA1\x20", 1, true), "the tempo 120 (500000 us)")
  ok(data:find("\xFF\x58\x04\x04\x02", 1, true), "4/4")
  ok(data:find("\x90\x24\x60", 1, true) and data:find("\x90\x29\x60", 1, true), "the 2 notes")
  ok(data:find("Far Away - Bass", 1, true), "the track name")
  C.Export.run({ item = true, file = false, step = 0.25 })
  eq(r.CountTrackMediaItems(mt), 1, "again: replaced")
  eq(r.Undo_CanUndo2(0), "Tab Viewer: export MIDI")
  os.remove(path)
  -- the Guitar Pro file (25 November 2026): the same name, .gp5; it reads back with the reader
  local msg2, warn2 = C.Export.run({ item = false, file = false, gp = true, step = 0.25 })
  eq(warn2, nil, msg2)
  ok(msg2:find("Far Away - Bass.gp5", 1, true), msg2)
  local gp = path:gsub("%.mid$", ".gp5")
  local fg = assert(io.open(gp, "rb"))
  local doc = C.GP.read_old(fg:read("a"))
  fg:close()
  ok(doc, "the Guitar Pro file reads back")
  if doc then
    eq(doc.rest, 0); eq(doc.tempo, 120); eq(doc.tracks[1].kind, "bass"); eq(table.concat(doc.tracks[1].open, " "), "28 33 38 43")
    local t = {}
    for k, x in ipairs(C.GP.notes(doc, 1)) do t[k] = string.format("%.2f %d", x.q, x.midi) end
    eq(table.concat(t, " | "), "0.00 36 | 2.00 41", "the found notes, from the bar of the first one")
  end
  os.remove(gp)
end)

test("export: the Guitar Pro file: a note over the bar line goes on tied; a tempo change; your fix in the Tab tab", function()
  clear_project(); clear_tempo()
  -- 120 BPM: a C from beat 1 of bar 2 for 3 quarters, then an F over 2 bar lines (bar 3, into bar 4 at 90 BPM)
  local p = set_rows({ { 2, "C - F" } })
  p.notes = { { pc = 0, midi = 36, t = 2, t1 = 3.5, man = true }, { pc = 5, midi = 41, t = 3.5, t1 = 6.5, man = true } }
  r.SetTempoTimeSigMarker(0, -1, 6, -1, -1, 90, 4, 4, false) -- (bar 4 at 90 BPM: the F ends 3/4 of a beat into it)
  r.UpdateTimeline()
  local song = TV.Tabs.found_song("Test")
  ok(song, "a song")
  if not song then return end
  eq(math.floor(song.tempo + 0.5), 120); ok(song.bars[3] and song.bars[3].tempo and math.floor(song.bars[3].tempo + 0.5) == 90, "the tempo change")
  local doc = C.GP.read_old(C.GP.write_gp5(song))
  local t = {}
  for k, x in ipairs(C.GP.notes(doc, 1)) do t[k] = string.format("%.2f+%.2f %d", x.q, x.len, x.midi) end
  eq(table.concat(t, " | "), "0.00+3.00 36 | 3.00+5.75 41", "the F over 2 bar lines: 1 note (tied)")
  -- a fix in the Tab tab (the found notes' entry): bar 1, the C on fret 8 of the E string (C2)
  p.tab = p.tab or { edits = {} }
  p.tab.edits = { [1] = { [1] = { { q = 0, s = 1, fret = 8, len = 3 }, { q = 3, s = 2, fret = 8, len = 1 } } } }
  song = TV.Tabs.found_song("Test")
  local doc2 = C.GP.read_old(C.GP.write_gp5(song))
  local n1 = C.GP.notes(doc2, 1)[1]
  eq(n1.s, 1, "the fix: the E string"); eq(n1.fret, 8)
  p.tab = nil
  clear_tempo()
end)

test("fingering: the run of the example stays in 1 hand position", function()
  local std = Key.tuning("std")
  local function show(list)
    local t = {}
    for i, pl in ipairs(list) do t[i] = pl and Key.place_text(pl, std):sub(2) or "-" end
    return table.concat(t, " ")
  end
  eq(show(Key.finger({ 41, 39, 36, 34 }, std)), "(D 3) (D 1) (A 3) (A 1)")
  eq(show(Key.finger({ 40, 40, 40 }, std)), "(D 2) (D 2) (D 2)", "the same note stays on its string, low on the neck")
  eq(show(Key.finger({ 36, 20, 36 }, std)), "(A 3) - (A 3)", "a note below the neck: the rest goes on")
  eq(#Key.finger({}, std), 0)
end)

test("fingering: a row of 4 notes gets every place, the other rows the high notes only", function()
  local list = notes({ { 5, 0, 0.4 }, { 3, 0.5, 0.9 }, { 0, 1, 1.4 }, { 10, 1.5, 1.9 }, { 7, 2, 3.9 } })
  for i, m in ipairs({ 41, 39, 36, 34, 43 }) do list[i].midi = m end
  local opt = { tun = Key.tuning("std"), high = true, runs = true }
  eq(texts(Group.rows(list, bars(2, 2), "C minor", opt)), "F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1) | G (G 0)")
  opt.runs = false
  eq(texts(Group.rows(list, bars(2, 2), "C minor", opt)), "F (D 3) - Eb - C - Bb | G (G 0)", "fingering off")
  opt.high, opt.runs = false, true
  eq(texts(Group.rows(list, bars(2, 2), "C minor", opt)), "F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1) | G", "high notes off")
  C.S.frets, C.S.finger = false, false
  eq(List.opt().high or List.opt().runs, false, "both off")
  C.S.frets, C.S.finger = true, true
  eq(List.opt().runs, true)
end)

local Beat, Tempo = C.TP.Beat, TV.Tempo -- (Tab Viewer's Find tempo, with the hooks of the list)
-- the bar and the beat in it at a time ("bar.beat", the beat with 2 decimals)
local function where(t)
  local beat, m = r.TimeMap2_timeToBeats(0, t)
  if beat > 3.995 then beat = 0; m = m + 1 end
  return string.format("%d.%.2f", m + 1, math.abs(beat) < 0.005 and 0 or beat)
end

test("tempo: a click track (generated WAV): its tempo, its beats and bar 1", function()
  clear_project(); clear_tempo()
  local bass = add_track("Bass")
  local it = add_item(bass, bass_wav("song.wav", { { nil, 30 } }), 2)
  local click = add_track("Metronome")
  add_item(click, click_wav("click.wav", 150, 1.0, 1, 30), 2) -- bar 1 at the first click: 1 s (3 s in the project)
  add_track("Drums")
  r.SetMediaItemSelected(it, true)
  TR.tsrc = nil
  local src = Tempo.sources()
  eq(src[1].label, "2: Metronome", "the metronome first")
  eq(#src, 2, "only tracks with items")
  Tempo.begin(Tempo.source().tr)
  local n = 0
  while TR.tempo and TR.tempo.run and n < 5000 do Tempo.step(); n = n + 1 end
  local tm = TR.tempo
  ok(tm and tm.beats, "beats found (" .. tostring(TR.notice and TR.notice.text) .. ")")
  ok(n > 1, "more than 1 step")
  near(tm.bpm, 150, 0.3, "tempo")
  near(tm.beats[tm.i0], 3.0, 0.03, "bar 1")
  eq(tm.steady, true, "steady")
  eq(tm.style, "steady")
  eq(tm.lbl_bpm, "150 BPM")
  -- the Tempo dropdown (26 November 2026): found, half, double of the found tempo
  eq(#tm.choices, 3); eq(tm.lbl_choice, tm.choices[1].lbl); ok(tm.choices[2].lbl:find("(half)", 1, true))
  Tempo.scale(0.5)
  near(tm.bpm, 75, 0.2, "half"); eq(tm.f, 0.5); eq(tm.lbl_choice, tm.choices[2].lbl)
  Tempo.scale(2)
  near(tm.bpm, 300, 0.6, "double of the found tempo, not of the half")
  Tempo.scale(1)
  near(tm.bpm, 150, 0.3, "the found tempo again")
  eq(C.TP.bpm_text(159.875), "159.9 BPM"); eq(C.TP.bpm_text(160.02), "160 BPM")
end)

test("tempo: Find tempo needs the song and a track with audio", function()
  clear_project(); clear_tempo()
  TR.tempo = nil
  local tr = add_track("Drums")
  Tempo.begin(tr)
  eq(TR.tempo, nil); ok(TR.notice.text:find("song's audio", 1, true), "asks for the song")
  local bass = add_track("Bass")
  local it = add_item(bass, bass_wav("song2.wav", { { nil, 6 } }), 0)
  r.SetMediaItemSelected(it, true)
  Tempo.begin(tr)
  eq(TR.tempo, nil); ok(TR.notice.text:find("no audio", 1, true), "the track is empty")
end)

test("tempo: the plan of 1 tempo and of Follow the song", function()
  local beats = {}
  for k = 1, 40 do beats[k] = 1 + (k - 1) * 0.5 end -- 120 BPM from 1 s
  local m, after, nb = Beat.plan(beats, 1, "steady", 9)
  eq(#m, 1); near(m[1].t, 1, 1e-6); near(m[1].bpm, 120, 1e-6); eq(m[1].num, 4)
  near(after, 9, 1e-6, "the bar line after the song"); eq(nb, 4)
  for k = 2, 40 do beats[k] = beats[k - 1] + 0.5 + 0.002 * k end -- it slows down
  beats[14] = beats[14] + 0.4 -- a wrong beat on a bar line (bar 4 starts at beat 13: beat 17)
  m = Beat.plan(beats, 1,"follow", 15)
  eq(m[1].num, 4); eq(m[2].num, 0, "the same time signature")
  near(m[2].t, beats[5], 0.002, "bar 2 on its beat (the rounded tempo: under 2 ms)")
  ok(m[2].bpm < m[1].bpm, "slower")
  local n, bpm = Beat.fit_bar(10, 11.9, 0.5)
  eq(n, 4); near(bpm, 240 / 1.9, 1e-6, "exact: it fills the gap")
  n = Beat.fit_bar(10, 10.1, 0.5)
  eq(n, 1, "at least 1 beat")
end)

test("tempo: Set tempo writes at most 1 decimal place, and the bars stay on the beats (26 November 2026)", function()
  local function one_decimal(x) return math.abs(x * 10 - math.floor(x * 10 + 0.5)) < 1e-6 end
  local beats, per = {}, 60 / 159.875
  for k = 1, 600 do beats[k] = 2 + (k - 1) * per end -- 159.875 BPM, about 3:45
  local m = Beat.plan(beats, 1,"steady", beats[600])
  eq(#m, 1); near(m[1].bpm, 159.9, 1e-9, "1 tempo: rounded")
  local worst = 0
  for k = 1, 600 do worst = math.max(worst, math.abs(m[1].t + (k - 1) * 60 / 159.9 - beats[k])) end
  ok(worst < 0.03, "1 tempo: the grid stays near the beats (" .. worst .. " s)")
  for k = 2, 600 do beats[k] = beats[k - 1] + per * (1 + 0.01 * math.sin(k / 20)) end -- it drifts a little
  m = Beat.plan(beats, 1,"follow", beats[600])
  worst = 0
  for k, x in ipairs(m) do
    ok(one_decimal(x.bpm), "bar " .. k .. ": 1 decimal place (" .. x.bpm .. ")")
    worst = math.max(worst, math.abs(x.t - beats[1 + 4 * (k - 1)]))
  end
  ok(worst < 0.002, "Follow the song: every bar starts on its beat (" .. worst .. " s)")
  eq(Beat.round(159.875), 159.9); eq(Beat.round(160.04), 160); eq(Beat.round(120), 120)
end)

-- TR.tempo by hand: the song from t0 to t1, beats every per s from first (step: the change of each beat)
local function tempo_by_hand(item, t0, t1, first, per, step, style)
  local _, guid = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
  local beats, t, p = {}, first, per
  while t < t1 + 2 do beats[#beats + 1] = t; t = t + p; p = p + (step or 0) end
  TR.tempo = { song = { guid = guid, t0 = t0, t1 = t1 }, beats = beats, i0 = 1, bpm = 60 / per,
    steady = style ~= "follow", style = style or "steady" }
  Tempo.labels()
  return beats
end

test("tempo: Set tempo puts bar 1 on the song; other songs, items, markers and envelopes stay; 1 undo step", function()
  clear_project(); clear_tempo()
  local bass = add_track("Bass")
  local it = add_item(bass, bass_wav("song3.wav", { { nil, 30 } }), 10)
  local other = add_item(add_track("Song 2"), bass_wav("song4.wav", { { nil, 20 } }), 60)
  r.SetTempoTimeSigMarker(0, -1, 60, -1, -1, 130, 4, 4, false) -- song 2 has its own tempo (first: it moves markers)
  r.AddProjectMarker2(0, false, 25, 0, "in the song", -1, 0)
  r.AddProjectMarker2(0, true, 60, 80, "Song 2", -1, 0)
  local env = r.GetTrackEnvelopeByName(bass, "Volume")
  if not env then r.SetOnlyTrackSelected(bass); r.Main_OnCommand(40406, 0); env = r.GetTrackEnvelopeByName(bass, "Volume") end
  ok(env, "a volume envelope")
  r.InsertEnvelopePoint(env, 30, 0.5, 0, 0, false, true)
  r.Envelope_SortPoints(env)
  local before = r.CountEnvelopePoints(env)
  local function env_t(i) local _, t = r.GetEnvelopePoint(env, i); return t end
  local env_last = env_t(before - 1)
  tempo_by_hand(it, 10, 40, 10.3, 0.4) -- 150 BPM, bar 1 at 10.3 s (between REAPER's bar lines)
  TR.tset = nil
  eq(TV.Tabs.tempo_state().ok, false, "step 1 not done: the song has no tempo marker (song 2's at 60 s is not its)")
  C.draw(500) -- (the Tempo rows of the Detection tab with a result: its controls and Set tempo; 26 November 2026)
  TV.S.closed[TV.UI.FOLD_TEMPO], TV.S.closed[TV.UI.FOLD_SONG] = true, true
  C.draw(500) -- (folded: only the headings with their status)
  TV.S.closed[TV.UI.FOLD_TEMPO], TV.S.closed[TV.UI.FOLD_SONG] = nil, nil
  local tm = TR.tempo
  TR.tempo = { song = tm.song, run = { done = 0.5 } }
  C.draw(500) -- (while it listens: the progress and Cancel)
  TR.tempo = tm
  Tempo.set()
  TR.tset = nil
  ok(TV.Tabs.tempo_state().ok, "step 1 done: Set tempo gave the song its tempo")
  eq(TV.Tabs.tempo_state().txt, "Set: 150 BPM")
  eq(where(8), "5.0.00", "the old bar line before the song stays")
  eq(where(8.7), "6.0.00", "a bar at the song tempo before bar 1 (the bass item starts at 10 s, inside it)")
  near(r.TimeMap_GetDividedBpmAtTime(9.5), 150, 0.01, "the count-in has the song tempo")
  eq(where(10.3), "7.0.00", "bar 1 on a bar line")
  eq(where(10.3 + 4 * 0.4), "8.0.00", "the next bar")
  near(r.TimeMap_GetDividedBpmAtTime(20), 150, 0.01, "the tempo of the song")
  near(r.GetMediaItemInfo_Value(it, "D_POSITION"), 10, 1e-6, "the bass item")
  near(r.GetMediaItemInfo_Value(it, "D_LENGTH"), 30, 1e-6, "its length")
  near(r.GetMediaItemInfo_Value(other, "D_POSITION"), 60, 1e-6, "song 2")
  eq(markers(), "in the song@25.0 [Song 2 60.0-80.0]")
  near(env_t(before - 1), env_last, 1e-6, "the envelope point")
  local _, t60, _, _, bpm60 = r.GetTempoTimeSigMarker(0, r.FindTempoTimeSigMarker(0, 60.001))
  near(t60, 60, 1e-6, "the tempo marker of song 2"); near(bpm60, 130, 1e-6)
  eq(where(60), where(60):match("^%d+") .. ".0.00", "song 2 starts on a bar line")
  near(r.TimeMap_GetDividedBpmAtTime(50), 120, 0.01, "between the songs: the old tempo")
  eq(r.Undo_CanUndo2(0), "Tab Viewer: set the tempo")
  r.Main_OnCommand(40029, 0) -- Edit: Undo
  near(r.TimeMap_GetDividedBpmAtTime(20), 120, 0.01, "undo: the old tempo")
  it = r.GetMediaItem(0, 0)
  near(r.GetMediaItemInfo_Value(it, "D_POSITION"), 10, 1e-6, "undo: the bass item")
  eq(markers(), "in the song@25.0 [Song 2 60.0-80.0]")
  -- The tempo is right (26 November 2026): 1 marker at the song start with the tempo it has, 1 undo step
  TR.tset = nil
  eq(TV.Tabs.tempo_state().ok, false, "undo: step 1 not done again")
  TV.Tabs.tempo_is_right()
  ok(TV.Tabs.tempo_state().ok, "The tempo is right: step 1 done")
  near(r.TimeMap_GetDividedBpmAtTime(20), 120, 0.01, "the tempo stays")
  eq(r.Undo_CanUndo2(0), "Tab Viewer: the tempo is right")
  eq(TV.Tabs.has_song_tempo({}, 10, 40), false, "no markers")
  eq(TV.Tabs.has_song_tempo({ 4, 41 }, 10, 40), false, "before (more than 5 s) and after the song")
  eq(TV.Tabs.has_song_tempo({ 6 }, 10, 40), true, "bar 1 a little before the item")
end)

test("tempo: Set tempo moves the song's audio so its first bass note is on the nearest beat; the list too; Ctrl+Z", function()
  clear_project(); clear_tempo()
  -- the bass item at 10 s: silence, then F from 11.13 s (30 ms after a beat: 150 BPM, bar 1 at 10.3 s, beats 0.4 s)
  local it = add_item(add_track("Bass"), bass_wav("align.wav", { { nil, 1.13 }, { 41, 2 }, { nil, 10 } }), 10)
  local mix = add_item(add_track("Mix"), bass_wav("align_mix.wav", { { nil, 13 } }), 10)
  local set = add_item(add_track("Backing"), bass_wav("align_set.wav", { { nil, 100 } }), 0)
  local other = add_item(add_track("Song 2"), bass_wav("align2.wav", { { nil, 10 } }), 60)
  local _, guid = r.GetSetMediaItemInfo_String(it, "GUID", "", false)
  r.Undo_OnStateChange2(0, "test: the items") -- (Ctrl+Z below comes back to here)
  tempo_by_hand(it, 10, 23.13, 10.3, 0.4)
  Tempo.set() -- (no list of this item: the first pluck of the item)
  local d = r.GetMediaItemInfo_Value(it, "D_POSITION") - 10
  near(d, -0.03, 0.015, "the bass moved about 30 ms earlier")
  near(r.GetMediaItemInfo_Value(mix, "D_POSITION"), 10 + d, 1e-9, "the mix with it")
  near(r.GetMediaItemInfo_Value(set, "D_POSITION"), 0, 1e-9, "a backing track of the whole set stays")
  near(r.GetMediaItemInfo_Value(other, "D_POSITION"), 60, 1e-9, "song 2 stays")
  ok(TR.notice.text:find("ms earlier: the first note is on the beat", 1, true), TR.notice.text)
  eq(r.Undo_CanUndo2(0), "Tab Viewer: set the tempo", "1 undo step")
  r.Main_OnCommand(40029, 0) -- Edit: Undo
  near(r.GetMediaItemInfo_Value(C.Util.item_by_guid(guid), "D_POSITION"), 10, 1e-9, "Ctrl+Z: the audio back")
  -- with found notes of this item: the first found note decides, and the list moves with the audio
  clear_tempo()
  local p = set_rows({ { 11.12, "F" } })
  p.src, p.notes = guid, notes({ { 5, 11.12, 13 } })
  it = C.Util.item_by_guid(guid)
  tempo_by_hand(it, 10, 23.13, 10.3, 0.4)
  Tempo.set()
  near(r.GetMediaItemInfo_Value(it, "D_POSITION"), 9.98, 1e-9, "20 ms earlier: the found note at 11.12 s on 11.1 s")
  near(C.get_P().notes[1].t, 11.1, 1e-9, "the found note moved with it"); near(C.get_P().rows[1].t, 11.1, 1e-9, "its line")
  List.undo()
  near(C.get_P().notes[1].t, 11.12, 1e-9, "Undo of the list: back")
end)

test("tempo: Follow the song puts every bar on its beat; Set tempo again replaces it", function()
  clear_project(); clear_tempo()
  local it = add_item(add_track("Bass"), bass_wav("song5.wav", { { nil, 30 } }), 2)
  local beats = tempo_by_hand(it, 2, 32, 2.9, 0.36, 0.0004, "follow") -- it slows down a little
  Tempo.set()
  local m0 = where(beats[1]):match("^%d+")
  eq(where(beats[1]), m0 .. ".0.00", "bar 1")
  eq(where(beats[5]), (m0 + 1) .. ".0.00", "bar 2")
  eq(where(beats[13]), (m0 + 3) .. ".0.00", "bar 4")
  eq(where(beats[41]), (m0 + 10) .. ".0.00", "bar 11")
  Tempo.nudge(1) -- bar 1 a beat later; Set tempo again
  Tempo.set()
  local m1 = where(beats[2]):match("^%d+")
  eq(where(beats[2]), m1 .. ".0.00", "the new bar 1")
  eq(where(beats[42]), (m1 + 10) .. ".0.00", "bar 11")
  TR.tempo = nil
end)

-- SONGS: 1 list per song (decided 26 November 2026) -------------------------------------------------------------
local Songs, Lists = C.Songs, C.Lists
local function guid(it) return select(2, r.GetSetMediaItemInfo_String(it, "GUID", "", false)) end
local function go_to(t) -- (the edit cursor moves; the next frame of the Detection tab)
  r.SetEditCurPos(t, false, false)
  Project.update()
  Lists.follow()
end

test("songs: regions, and the bass items outside them; the song at a time; the song of an item", function()
  local list = Songs.make({ { id = "R1", t0 = 0, t1 = 10 } },
    { { id = "A", t0 = 1, t1 = 9, item = true }, { id = "B", t0 = 9, t1 = 30, item = true } })
  eq(#list, 2, "A is in the region (its middle)"); eq(list[1].id, "R1"); eq(list[2].id, "B", "B is its own song")
  eq(Songs.at(list, 5), 1); eq(Songs.at(list, 9.5), 2, "2 songs there: the later one"); eq(Songs.at(list, 40), nil, "none")
  eq(Songs.at(list, 10 - 1e-4), 2, "a hair before the end of R1: B")
  eq(Songs.for_item(list, { id = "B", t0 = 9, t1 = 30 }, "R1").id, "B", "its own song, also when the shown one touches it")
  eq(Songs.for_item(list, { id = "A", t0 = 1, t1 = 9 }, "B").id, "R1", "in a region: that region")
  local two = Songs.make({ { id = "R1", t0 = 0, t1 = 3 }, { id = "R2", t0 = 3, t1 = 6 } }, { { id = "L", t0 = 0, t1 = 6, item = true } })
  eq(#two, 2, "1 long item for 2 regions: 2 songs")
  eq(Songs.for_item(two, { id = "L", t0 = 0, t1 = 6 }, "R1").id, "R1", "the shown song")
  eq(Songs.for_item(two, { id = "L", t0 = 0, t1 = 6 }, "X").id, "R2", "else the song at its middle")
  local a, b = Find.part(two[2], 0, 6); eq(a, 3); eq(b, 6, "Find notes reads only that region's part")
  a, b = Find.part(list[2], 9, 30); eq(a, 9); eq(b, 30, "an item song: all of it")
  eq(Songs.make({}, {})[1], nil, "no regions, no bass track: no songs")
  eq(Find.pick({ { len = 2, ov = 0 }, { len = 9, ov = 0 }, { len = 4, ov = 3 } }), 3, "the item in the shown song")
  eq(Find.pick({ { len = 2, ov = 0, sel = true }, { len = 4, ov = 3 } }), 1, "a selected item first")
end)

test("lists: 1 block per song; an older list without songs is not read", function()
  local l = Lists.split("song=A\nkey=C minor\nrow=1.0000\t0\t\tC\nsong=\nrow=2.5000\t0\t\tF\nrow=3.0000\t0\t\tG")
  eq(table.concat(l.ids, ","), "A,", "2 songs (the 2nd: a project without songs)")
  eq(Lists.count(l.txt[""]), 2); eq(Lists.count(l.txt.A), 1); eq(Lists.count(nil), 0)
  eq(Lists.first_t(l.txt.A), 1); eq(Lists.first_t("key=C"), nil)
  eq(Lists.split(Lists.join(l)).txt.A, l.txt.A, "out and back")
  Lists.set(l, "A", "")
  eq(table.concat(l.ids, ","), "", "an empty list leaves")
  eq(#Lists.split("row=1.0000\t0\t\tC").ids, 0, "an old list (no song= line) is not read")
  eq(#Lists.split("").ids, 0)
end)

test("songs: each song keeps its list and its Undo; between songs the last stays; saved; another project", function()
  clear_project(); clear_tempo()
  R.ask, R.trk = nil, nil
  local tr = add_track("Bass")
  local a = add_item(tr, tmp .. "\\steps.wav", 0)
  local b = add_item(tr, tmp .. "\\steps.wav", 10)
  R.trk = tr
  go_to(1)
  local songs = Songs.get()
  eq(#songs, 2); eq(songs[1].id, guid(a)); eq(songs[2].name, "steps.wav")
  eq(R.song, guid(a), "the song at the edit cursor")
  local p = set_rows({ { 1, "C" }, { 2, "F" } })
  p.src = guid(a)
  List.delete(2)
  go_to(11)
  eq(R.song, guid(b)); eq(#C.get_P().rows, 0, "song 2: its own list (none yet)"); eq(#R.undo, 0, "and its own Undo")
  set_rows({ { 11, "G" } })
  go_to(6)
  eq(R.song, guid(b), "between songs: the last list stays"); eq(texts(), "G")
  go_to(2)
  eq(texts(), "C", "song 1: its list"); eq(#R.undo, 1, "and its Undo")
  List.undo()
  eq(texts(), "C | F")
  R.pdirty = true
  Project.save()
  local l = Lists.split(Project.read())
  eq(#l.ids, 2, "2 lists in the project"); ok(l.txt[guid(b)]:find("\tG", 1, true), l.txt[guid(b)])
  r.Main_SaveProject(0, false)
  r.Main_openProject("noprompt:" .. tmp .. "\\other.rpp")
  Project.update()
  eq(#C.get_P().rows, 0, "another project: no list")
  r.Main_openProject("noprompt:" .. proj_file)
  Project.update()
  eq(texts(), "C | F", "back: the list of the song at the edit cursor")
  go_to(12)
  eq(texts(), "G", "and the other song's list (its Track found again from the song)")
end)

test("songs: Write and Clear change only the markers and Notes items of the shown song", function()
  -- (the project of the test before: song 1 "C | F" at 1 and 2 s, song 2 "G" at 11 s)
  go_to(1)
  Out.write("both")
  go_to(11)
  Out.write("both")
  eq(markers(), "C@1.0 F@2.0 G@11.0", "song 1's markers stay")
  local notes_tr = Out.find_track()
  eq(r.CountTrackMediaItems(notes_tr), 3, "and its Notes items")
  Out.clear()
  eq(markers(), "C@1.0 F@2.0", "Clear: only song 2's")
  eq(r.CountTrackMediaItems(notes_tr), 2)
  go_to(1)
  eq(texts(), "C | F", "song 1's list stays")
  Out.write("both")
  eq(r.CountTrackMediaItems(notes_tr), 2, "Write again: no doubles")
end)

test("songs: 1 long bass item for 2 regions; Find notes fills each song's list from its part, the other stays", function()
  clear_project(); clear_tempo()
  R.ask, R.trk = nil, nil
  local tr = add_track("Bass")
  add_item(tr, bass_wav("two_songs.wav", { { 36, 2 }, { nil, 2 }, { 41, 2 } }), 0)
  r.AddProjectMarker2(0, true, 0, 3, "One", -1, 0)
  r.AddProjectMarker2(0, true, 3, 6, "Two", -1, 0)
  R.trk = tr
  go_to(4)
  local songs = Songs.get()
  eq(#songs, 2); eq(songs[2].name, "Two"); eq(R.song, songs[2].id)
  local function find()
    C.UI.find()
    local n = 0
    while R.find and n < 2000 do Find.step(); n = n + 1 end
    R.ask = nil
  end
  find()
  eq(texts(), "F (D 3)", "song Two: only its part")
  go_to(1)
  eq(#C.get_P().rows, 0, "song One: no list yet")
  find()
  eq(texts(), "C", "song One")
  go_to(4)
  eq(texts(), "F (D 3)", "song Two's list was not replaced")
  eq(C.status(), "Song 2 of 2: Two  |  1 line", "the bottom bar")
end)

test("songs: Find notes on a selected item of another song fills that song's list", function()
  clear_project(); clear_tempo()
  R.ask, R.trk = nil, nil
  local tr = add_track("Bass")
  local a = add_item(tr, tmp .. "\\steps.wav", 0)
  local b = add_item(tr, tmp .. "\\steps.wav", 10)
  R.trk = tr
  go_to(1)
  local p = set_rows({ { 1, "A" } })
  p.src = guid(a)
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(b, true)
  C.UI.find()
  eq(R.ask, nil, "no question: song 2 has no list")
  local n = 0
  while R.find and n < 2000 do Find.step(); n = n + 1 end
  eq(R.song, guid(b)); eq(texts(), "C | F (D 3)", "song 2's list")
  go_to(12); go_to(1)
  eq(texts(), "A", "song 1's list stays")
end)

test("songs: a list whose song is gone goes to the song at its first line (a region added over the item)", function()
  clear_project(); clear_tempo()
  R.ask, R.trk = nil, nil
  local tr = add_track("Bass")
  local a = add_item(tr, tmp .. "\\steps.wav", 0)
  R.trk = tr
  go_to(1)
  eq(R.song, guid(a))
  set_rows({ { 1, "C" } })
  r.AddProjectMarker2(0, true, 0, 5, "Far Away", -1, 0)
  go_to(1)
  local songs = Songs.get()
  eq(#songs, 1); eq(songs[1].name, "Far Away")
  eq(R.song, songs[1].id, "the shown list is now the region's"); eq(texts(), "C")
  R.pdirty = true
  Project.save()
  ok(Lists.split(Project.read()).txt[songs[1].id], "saved under the region")
  eq(Lists.split(Project.read()).txt[guid(a)], nil, "not under the item")
  clear_project()
end)

end
