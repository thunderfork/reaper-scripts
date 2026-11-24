-- @noindex
-- The tests of Tab Viewer's Note Detection tab (Tab Viewer\Notes.lua; it was the script Note Detective). tests\tabviewer.lua
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

test("notes: the test project of the Note Detection tab opens", function()
  r.RecursiveCreateDirectory(tmp, 0)
  empty_project(proj_file)
  r.Main_openProject("noprompt:" .. proj_file)
  C.S.simple = false -- (the tests check the extras; Simple mode has a test of its own)
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
  for i = 1, n do t[i] = { t0 = (i - 1) * len, t1 = i * len, tol = C.CFG.PUSH * len } end
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

test("group: a note just before the bar line belongs to the next bar", function()
  local rows = Group.rows(notes({ { 0, 0, 1.8 }, { 5, 1.8, 3.9 } }), bars(2, 2), "")
  eq(texts(rows), "C | F")
  eq(rows[2].t, 1.8, "it starts where the note starts")
  rows = Group.rows(notes({ { 0, 0, 1.8 }, { 5, 1.8, 2.0 }, { 5, 2.02, 4 } }), bars(2, 2), "")
  eq(texts(rows), "C | F", "played again on the bar line")
  rows = Group.rows(notes({ { 0, 0, 1.75 }, { 5, 1.75, 1.95 }, { 7, 2, 4 } }), bars(2, 2), "")
  eq(texts(rows), "C - F | G", "a short note inside the bar stays")
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

test("group: every note change, and about 2 seconds", function()
  local n = notes({ { 0, 0, 0.5 }, { 0, 0.5, 1 }, { 3, 1, 1.5 }, { 5, 2.2, 3 }, { 7, 4.5, 5 } })
  eq(texts(Group.make(n, "change", "C minor", 0, 5)), "C | Eb | F | G")
  eq(texts(Group.make(n, "sec", "C minor", 0, 5)), "C - Eb | F | G")
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
  p.mode, p.src, p.mk = "sec", "{A}", { "{B}", "{C}" }
  local txt = List.serialize(p)
  local q = List.parse(txt)
  eq(List.serialize(q), txt)
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
  eq(Project.read(), List.serialize(C.get_P()))
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

test("list: the line at a time", function()
  set_rows({ { 1, "C" }, { 3, "F" }, { 5, "G" } })
  eq(List.at(0.5), nil); eq(List.at(1), 1); eq(List.at(4.9), 2); eq(List.at(99), 3)
end)

test("list: another key changes the names", function()
  set_rows({ { 1, "G# - A# (A 1)" } })
  List.set_key("C minor")
  eq(texts(), "Ab - Bb (A 1)")
  List.undo()
  eq(texts(), "G# - A# (A 1)"); eq(C.get_P().key, "")
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
  local item, why = Find.source()
  eq(item, nil); ok(why:find("Select the bass item"), why)
  local tr = add_track("Bass")
  local midi = r.CreateNewMIDIItemInProj(tr, 0, 2, false)
  r.SetMediaItemSelected(midi, true)
  item, why = Find.source()
  eq(item, nil); ok(why:find("not audio"), why)
  local empty = r.AddMediaItemToTrack(tr)
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(empty, true)
  item, why = Find.source()
  eq(item, nil); ok(why:find("not audio"), why)
  r.SetMediaItemSelected(midi, true)
  item, why = Find.source()
  eq(item, nil); ok(why:find("1 item"), why)
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
  C.Util.apply_setting("counts", "0"); eq(C.S.counts, false)
  C.Util.apply_setting("counts", "1")
  C.Util.apply_setting("slide", "x"); eq(C.S.slide, "slash")
  C.Util.apply_setting("simple", "1"); eq(C.S.simple, true)
  eq(table.concat(C.Util.settings_lines(), " "), "out=markers frets=1 finger=1 strings=letters counts=1 export_dir= slide=slash simple=1 splits=1")
  C.Util.apply_setting("simple", "0")
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

test("clear: the list and what Note Detective wrote go; Undo and Ctrl+Z bring them back", function()
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
  eq(texts(), "C | F", "the Undo button: the list")
  r.Main_OnCommand(40029, 0)
  ok(markers():find("C@1.0", 1, true), "Ctrl+Z: the markers " .. markers())
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

test("slides: a glide into a note is 1 note with a slide mark; a plain note change is not (generated WAV)", function()
  clear_project(); clear_tempo()
  local tr = add_track("Bass")
  local it, tk = add_item(tr, path_wav("slide.wav", { { nil, 0.3 }, { 36, 0.8, 0.15 }, { 41, 0.8 }, { nil, 0.3 } }), 0)
  local list, _, t_end = find_all(it, tk)
  local opt = List.opt()
  eq(texts(Group.make(list, "change", "", 0, t_end, opt)), "C | /F (D 3)", "the slide into F")
  opt.slide = "sl"; eq(texts(Group.make(list, "change", "", 0, t_end, opt)), "C | sl. F (D 3)")
  opt.slide = "word"; eq(texts(Group.make(list, "change", "", 0, t_end, opt)), "C | F (D 3) (slide)")
  opt.slide = "off"; eq(texts(Group.make(list, "change", "", 0, t_end, opt)), "C | F (D 3)")
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
  eq(List.why(1), "Doubtful: the octave is unsure (high or low?).")
  eq(List.why(2), nil, "not doubtful")
  p = set_rows({ { 2, "E", true } })
  p.notes = notes({ { 4, 2, 2.5, true } })
  eq(List.why(1), "Doubtful: listen to it.", "no reason known")
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

test("simple mode: only the notes and the string of a high note; no fingering of runs, slides or beat counts", function()
  local list = notes({ { 5, 0, 0.4 }, { 3, 0.5, 0.9 }, { 0, 1, 1.4 }, { 10, 1.5, 1.9 }, { 7, 2, 3.9 } })
  for i, m in ipairs({ 41, 39, 36, 34, 43 }) do list[i].midi = m end
  list[5].slide = true
  C.S.simple = true
  eq(texts(Group.rows(list, bars(2, 2), "C minor", List.opt())), "F (D 3) - Eb - C - Bb | G (G 0)",
    "the high notes at the place of the fingering (the open G string after the run)")
  set_rows({ { 2, "C - G (D 5)", false, { 2, 3 } } })
  eq(Out.item_text(1), "C - G (D 5)", "no beat count")
  C.S.simple = false
  eq(texts(Group.rows(list, bars(2, 2), "C minor", List.opt())), "F (D 3) - Eb (D 1) - C (A 3) - Bb (A 1) | /G (G 0)")
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

test("beat count: 1 e & a in the Notes track items; off; a key change line without markers", function()
  clear_project(); clear_tempo()
  -- 120 BPM: bar 2 starts at 2 s; a 16th = 0.125 s
  eq(Group.count(0, 2), "1"); eq(Group.count(0, 2.125), "1e"); eq(Group.count(0, 2.25), "1&")
  eq(Group.count(0, 3.9), "4a"); eq(Group.count(0, 3.97), "1", "just before the next bar line")
  set_rows({ { 2, "C - Eb (A 6) - G", false, { 2, 2.75, 3.5 } }, { 4, "F" } })
  eq(Out.item_text(1), "1 C · 2& Eb (A 6) · 4 G")
  C.get_P().rows[1].text = "C - G" -- (typed: not 1 part per note any more)
  eq(Out.item_text(1), "C - G")
  C.get_P().rows[1].text = "C - Eb (A 6) - G"
  C.S.counts = false
  eq(Out.item_text(1), "C - Eb (A 6) - G", "off")
  C.S.counts = true
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
  ok(msg:find("Made a MIDI item", 1, true) and msg:find("No .mid file", 1, true), msg)
  r.Main_OnCommand(40029, 0) -- (the item goes again)
  C.get_P().notes = {}
end)

test("tempo: a project switch during Play with click puts the metronome back", function()
  local before = r.GetToggleCommandStateEx(0, 40364)
  TR.tempo = { click = before, click_seen = true }
  r.Main_OnCommand(40364, 0) -- (Play with click turned it over)
  TR.proj = nil -- (Tab Viewer sees another project)
  TV.Project.update()
  eq(r.GetToggleCommandStateEx(0, 40364), before, "the metronome as before")
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
  eq(tm.lbl_bpm, "150.0 BPM")
  Tempo.scale(0.5)
  near(tm.bpm, 75, 0.2, "1/2")
  Tempo.scale(2)
  near(tm.bpm, 150, 0.3, "x2")
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

test("tempo: the plan of 1 tempo and of Follow the song, with a short bar", function()
  local beats = {}
  for k = 1, 40 do beats[k] = 1 + (k - 1) * 0.5 end -- 120 BPM from 1 s
  local m, after, nb = Beat.plan(beats, 1, {}, "steady", 9)
  eq(#m, 1); near(m[1].t, 1, 1e-6); near(m[1].bpm, 120, 1e-6); eq(m[1].num, 4)
  near(after, 9, 1e-6, "the bar line after the song"); eq(nb, 4)
  m, after, nb = Beat.plan(beats, 1, { [9] = true }, "steady", 9) -- bar 3 has 3 beats
  eq(#m, 3); eq(m[2].num, 3); eq(m[2].bar, 2); eq(m[3].num, 4); near(m[3].t, 6.5, 1e-6)
  near(after, 10.5, 1e-6); eq(nb, 5)
  for k = 2, 40 do beats[k] = beats[k - 1] + 0.5 + 0.002 * k end -- it slows down
  beats[14] = beats[14] + 0.4 -- a wrong beat on a bar line (bar 4 starts at beat 13: beat 17)
  m = Beat.plan(beats, 1, {}, "follow", 15)
  eq(m[1].num, 4); eq(m[2].num, 0, "the same time signature")
  near(m[2].t, beats[5], 1e-6, "bar 2 on its beat")
  ok(m[2].bpm < m[1].bpm, "slower")
  local n, bpm = Beat.fit_bar(10, 11.9, 0.5)
  eq(n, 4); near(bpm, 240 / 1.9, 1e-6)
  n = Beat.fit_bar(10, 10.1, 0.5)
  eq(n, 1, "at least 1 beat")
end)

-- TR.tempo by hand: the song from t0 to t1, beats every per s from first (step: the change of each beat)
local function tempo_by_hand(item, t0, t1, first, per, step, style)
  local _, guid = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
  local beats, t, p = {}, first, per
  while t < t1 + 2 do beats[#beats + 1] = t; t = t + p; p = p + (step or 0) end
  TR.tempo = { song = { guid = guid, t0 = t0, t1 = t1 }, beats = beats, i0 = 1, short = {}, bpm = 60 / per,
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
  Tempo.set()
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

test("tempo: Follow the song puts every bar on its beat; a short bar; Set tempo again replaces it", function()
  clear_project(); clear_tempo()
  local it = add_item(add_track("Bass"), bass_wav("song5.wav", { { nil, 30 } }), 2)
  local beats = tempo_by_hand(it, 2, 32, 2.9, 0.36, 0.0004, "follow") -- it slows down a little
  Tempo.set_short(beats[9] + 0.1, true) -- bar 3 has 3 beats
  eq(#TR.tempo.short_list, 1); ok(TR.tempo.short_list[1].text:find("^Bar 3"), TR.tempo.short_list[1].text)
  Tempo.set()
  local m0 = where(beats[1]):match("^%d+")
  eq(where(beats[1]), m0 .. ".0.00", "bar 1")
  eq(where(beats[5]), (m0 + 1) .. ".0.00", "bar 2")
  eq(where(beats[9]), (m0 + 2) .. ".0.00", "bar 3 (3 beats)")
  eq(where(beats[12]), (m0 + 3) .. ".0.00", "bar 4 after the short bar")
  eq(where(beats[40]), (m0 + 10) .. ".0.00", "bar 11")
  Tempo.nudge(1) -- bar 1 a beat later; Set tempo again
  eq(TR.tempo.short[10], true, "the short bar moves with it")
  Tempo.set()
  local m1 = where(beats[2]):match("^%d+")
  eq(where(beats[2]), m1 .. ".0.00", "the new bar 1")
  eq(where(beats[41]), (m1 + 10) .. ".0.00", "bar 11")
  Tempo.remove_short(10)
  eq(#TR.tempo.short_list, 0)
end)

test("tempo: Play with click is taken back by the next try and by Set tempo", function()
  clear_project(); clear_tempo()
  local it = add_item(add_track("Bass"), bass_wav("song6.wav", { { nil, 20 } }), 1)
  tempo_by_hand(it, 1, 21, 1.5, 0.4)
  local click = r.GetToggleCommandStateEx(0, 40364)
  Tempo.try()
  eq(r.Undo_CanUndo2(0), TV.CFG.UNDO_TRY)
  eq(r.GetToggleCommandStateEx(0, 40364), 1, "the metronome is on")
  Tempo.nudge(1) -- a change: the try starts again
  eq(r.Undo_CanUndo2(0), TV.CFG.UNDO_TRY)
  r.OnStopButtonEx(0)
  Tempo.set()
  eq(r.GetToggleCommandStateEx(0, 40364), click, "the metronome as before")
  eq(r.Undo_CanUndo2(0), "Tab Viewer: set the tempo")
  r.Main_OnCommand(40029, 0)
  ok(r.Undo_CanUndo2(0) ~= TV.CFG.UNDO_TRY, "no try left behind")
  near(r.TimeMap_GetDividedBpmAtTime(10), 120, 0.01, "1 undo: the old tempo")
  TR.tempo = nil
end)

end
