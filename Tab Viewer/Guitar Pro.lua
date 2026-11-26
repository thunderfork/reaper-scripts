-- @noindex
-- Guitar Pro: reads Guitar Pro files (the tracks, tunings, bars and notes). Used by Tab Viewer (the Tab tab and the
-- Note Detection tab); ReaPack installs it next to the script (@provides).
-- Plain Lua 5.4 (no REAPER calls): the tests and a plain Lua can run it.
--   local GP = dofile(<folder> .. "Guitar Pro.lua")
--   local doc, why = GP.read(path)

local GP = {}

---------------------------------------------------------------------------
-- INFLATE (the "deflate" packing of a zip file, RFC 1951)
---------------------------------------------------------------------------
local byte, char, unpack = string.byte, string.char, table.unpack
local LEN_BASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEN_EXTRA = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DIST_BASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073,
  4097, 6145, 8193, 12289, 16385, 24577 }
local DIST_EXTRA = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CL_ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

-- A lookup table of a Huffman code from its code lengths (lens[0 .. n - 1]): t[the next maxlen bits] = symbol * 16 +
-- its length. Returns t, maxlen.
local function huffman(lens, n)
  local count, maxlen = {}, 0
  for s = 0, n - 1 do
    local l = lens[s] or 0
    if l > 0 then count[l] = (count[l] or 0) + 1; if l > maxlen then maxlen = l end end
  end
  local code, nxt = 0, {}
  for l = 1, maxlen do code = (code + (count[l - 1] or 0)) << 1; nxt[l] = code end
  local t, size = {}, 1 << maxlen
  for s = 0, n - 1 do
    local l = lens[s] or 0
    if l > 0 then
      local c, rev = nxt[l], 0
      nxt[l] = c + 1
      for _ = 1, l do rev = (rev << 1) | (c & 1); c = c >> 1 end -- (the bits come lowest first)
      local v = s * 16 + l
      for k = rev, size - 1, 1 << l do t[k] = v end
    end
  end
  return t, maxlen
end

-- The bytes o[1 .. n] as a string (in pieces: unpack takes a limited number of values).
local function to_string(o, n)
  local parts = {}
  for k = 1, n, 4096 do parts[#parts + 1] = char(unpack(o, k, math.min(n, k + 4095))) end
  return table.concat(parts)
end

local FIXED_LIT, FIXED_DIST
local function fixed_tables()
  if not FIXED_LIT then
    local l = {}
    for s = 0, 143 do l[s] = 8 end
    for s = 144, 255 do l[s] = 9 end
    for s = 256, 279 do l[s] = 7 end
    for s = 280, 287 do l[s] = 8 end
    local d = {}
    for s = 0, 29 do d[s] = 5 end
    FIXED_LIT, FIXED_DIST = { huffman(l, 288) }, { huffman(d, 30) }
  end
  return FIXED_LIT, FIXED_DIST
end

-- The unpacked bytes of the deflate data in src from position pos (a string). Errors on damaged data.
function GP.inflate(src, pos)
  local p, buf, cnt, n, o = pos or 1, 0, 0, 0, {}
  local last = #src
  local function need(k)
    while cnt < k do
      local b = byte(src, p)
      if not b then
        if p > last + 4 then error("the packed data ends too early") end
        b = 0 -- (a code near the end: the table looks at a few bits more than it uses)
      end
      p = p + 1
      buf = buf | (b << cnt)
      cnt = cnt + 8
    end
  end
  local function bits(k)
    need(k)
    local v = buf & ((1 << k) - 1)
    buf, cnt = buf >> k, cnt - k
    return v
  end
  local function sym(t, maxlen)
    need(maxlen)
    local v = t[buf & ((1 << maxlen) - 1)]
    if not v then error("a damaged code") end
    local l = v & 15
    buf, cnt = buf >> l, cnt - l
    return v >> 4
  end
  repeat
    local final, typ = bits(1), bits(2)
    if typ == 0 then -- (stored: the rest of this byte goes, then LEN, NLEN and the bytes as they are)
      bits(cnt % 8)
      p, buf, cnt = p - cnt // 8, 0, 0
      local len = (byte(src, p) or 0) | ((byte(src, p + 1) or 0) << 8)
      p = p + 4
      if p + len - 1 > last then error("the packed data ends too early") end
      for k = 0, len - 1 do o[n + 1 + k] = byte(src, p + k) end
      n, p = n + len, p + len
    else
      local lt, lm, dt, dm
      if typ == 1 then
        local fl, fd = fixed_tables()
        lt, lm, dt, dm = fl[1], fl[2], fd[1], fd[2]
      elseif typ == 2 then
        local hlit, hdist, hclen = bits(5) + 257, bits(5) + 1, bits(4) + 4
        local cl = {}
        for k = 1, hclen do cl[CL_ORDER[k]] = bits(3) end
        local ct, cm = huffman(cl, 19)
        local lens, k = {}, 0
        while k < hlit + hdist do
          local s = sym(ct, cm)
          if s < 16 then lens[k] = s; k = k + 1
          else
            local v, rep = 0, 0
            if s == 16 then
              if k == 0 then error("a damaged code") end
              v, rep = lens[k - 1], 3 + bits(2)
            elseif s == 17 then rep = 3 + bits(3)
            else rep = 11 + bits(7) end
            for _ = 1, rep do lens[k] = v; k = k + 1 end
          end
        end
        local dl = {}
        for j = 0, hdist - 1 do dl[j] = lens[hlit + j] end
        lt, lm = huffman(lens, hlit)
        dt, dm = huffman(dl, hdist)
      else
        error("a damaged block")
      end
      while true do
        local s = sym(lt, lm)
        if s < 256 then n = n + 1; o[n] = s
        elseif s == 256 then break
        else
          s = s - 256
          local len = LEN_BASE[s] + bits(LEN_EXTRA[s])
          local d = sym(dt, dm) + 1
          local dist = DIST_BASE[d] + bits(DIST_EXTRA[d])
          if dist > n then error("a damaged distance") end
          for _ = 1, len do n = n + 1; o[n] = o[n - dist] end
        end
      end
    end
  until final == 1
  return to_string(o, n)
end

-- The file `name` from the zip data (a string). nil and why.
function GP.unzip(data, name)
  local eocd
  for k = #data - 21, math.max(1, #data - 65557), -1 do
    if data:sub(k, k + 3) == "PK\5\6" then eocd = k; break end
  end
  if not eocd then return nil, "damaged" end
  local entries, cd = string.unpack("<I2xxxxI4", data, eocd + 10) -- (the number of files; the size skipped; the start)
  local pos = cd + 1
  for _ = 1, entries do
    if data:sub(pos, pos + 3) ~= "PK\1\2" then return nil, "damaged" end
    local method, csize, size, nlen, elen, clen, off = string.unpack("<I2xxxxxxxxI4I4I2I2I2xxxxxxxxI4", data, pos + 10)
    if data:sub(pos + 46, pos + 45 + nlen) == name then
      local lp = off + 1
      if data:sub(lp, lp + 3) ~= "PK\3\4" then return nil, "damaged" end
      local ln, le = string.unpack("<I2I2", data, lp + 26)
      local start = lp + 30 + ln + le
      if method == 0 then return data:sub(start, start + csize - 1) end
      if method ~= 8 then return nil, "damaged" end
      local ok, out = pcall(GP.inflate, data, start)
      if not ok or #out ~= size then return nil, "damaged" end
      return out
    end
    pos = pos + 46 + nlen + elen + clen
  end
  return nil, "missing"
end

---------------------------------------------------------------------------
-- GPX (Guitar Pro 6: a small file system "BCFS", usually packed as "BCFZ"; its score.gpif is like the one of a .gp)
---------------------------------------------------------------------------
-- The unpacked bytes of "BCFZ" data (data: after "BCFZ": the unpacked size, then a bit stream of pieces: a copy of
-- earlier bytes, or 1-3 plain bytes). A stream that ends early gives what it has (as Guitar Pro reads it).
function GP.bcfz(data)
  local want = string.unpack("<i4", data, 1)
  if want < 0 or want > 200 * 1024 * 1024 then error("a damaged size") end
  local pos, bp, last = 5, 0, #data
  local function bits(n) -- (n <= 24 bits, the highest bit first)
    local b1, b2, b3, b4 = byte(data, pos, pos + 3)
    local w = ((b1 or 0) << 24) | ((b2 or 0) << 16) | ((b3 or 0) << 8) | (b4 or 0)
    local v = (w >> (32 - bp - n)) & ((1 << n) - 1)
    bp = bp + n
    pos, bp = pos + (bp >> 3), bp & 7
    return v
  end
  local function rbits(n) -- (n bits, the lowest bit first)
    local v, r = bits(n), 0
    for _ = 1, n do r = (r << 1) | (v & 1); v = v >> 1 end
    return r
  end
  local o, n = {}, 0
  while n < want and pos <= last do
    if bits(1) == 1 then
      local w = bits(4)
      local off, size = rbits(w), rbits(w)
      local src = n - off
      if off == 0 or src < 0 then error("a damaged copy") end
      for k = 1, math.min(off, size) do n = n + 1; o[n] = o[src + k] end
    else
      for _ = 1, rbits(2) do n = n + 1; o[n] = bits(8) end
    end
  end
  return to_string(o, math.min(n, want))
end

-- The files of a "BCFS" file system (fs: after "BCFS"): sectors of 4096 bytes; sector 0 is empty; a file entry (type
-- 2) has its name (at 4), its size (at 0x8c) and the numbers of its data sectors (from 0x94, 0 ends the list).
function GP.bcfs(fs)
  local S, files, off = 0x1000, {}, 0x1000
  while off + 4 <= #fs do
    if string.unpack("<i4", fs, off + 1) == 2 then
      local e = off
      local name = fs:sub(e + 5, e + 4 + 127):match("^[^%z]*")
      local size = string.unpack("<i4", fs, e + 0x8c + 1)
      local parts = {}
      for k = 0, (S - 0x94) // 4 - 1 do
        local sector = string.unpack("<i4", fs, e + 0x94 + 4 * k + 1)
        if sector <= 0 or sector * S >= #fs then break end
        parts[#parts + 1] = fs:sub(sector * S + 1, sector * S + S)
        off = math.max(off, sector * S) -- (the next entry comes after the last data sector; never back: a damaged list)
      end
      files[name] = table.concat(parts):sub(1, math.max(0, size))
    end
    off = off + S
  end
  return files
end

-- The score (score.gpif) of a .gpx file (data: the whole file); nil: none in it. Errors on damaged data.
function GP.gpx(data)
  local head = data:sub(1, 4)
  local fs = head == "BCFZ" and GP.bcfz(data:sub(5)) or data
  if fs:sub(1, 4) ~= "BCFS" then error("not a file system") end
  return GP.bcfs(fs:sub(5))["score.gpif"]
end

---------------------------------------------------------------------------
-- READ (a file -> the parts of the score)
---------------------------------------------------------------------------
local BINARY = { gp3 = true, gp4 = true, gp5 = true }
-- The parts of the score of a Guitar Pro file (GP.parse, GP.read_old). nil and why (a text for the user).
function GP.read(path)
  local ext = (path:match("%.(%w+)$") or ""):lower()
  if ext ~= "gp" and ext ~= "gpx" and ext ~= "gpif" and not BINARY[ext] then
    return nil, "This is not a Guitar Pro file. Pick a .gp, .gpx, .gp5, .gp4 or .gp3 file."
  end
  local f = io.open(path, "rb")
  if not f then return nil, "Could not open the file." end
  local data = f:read("a")
  f:close()
  local doc
  if BINARY[ext] then
    if not data:sub(1, 31):find("GUITAR PRO", 1, true) then return nil, "This file is damaged, or it is not a Guitar Pro file." end
    local ok, d, why = pcall(GP.read_old, data)
    if not ok then return nil, "This file is damaged: it could not be read to its end." end
    if not d then return nil, why end
    doc = d
  else
    local xml, why = GP.score(data, ext)
    if not xml then return nil, why end
    doc = GP.parse(xml)
  end
  if #doc.tracks == 0 or #doc.mbars == 0 then return nil, "No tracks or bars in this file." end
  return doc
end

-- The score text of a .gp, .gpx or .gpif file (data: the whole file). nil and why (a text for the user).
function GP.score(data, ext)
  local xml = data
  if ext == "gp" then
    if data:sub(1, 4) ~= "PK\3\4" then return nil, "This file is damaged, or it is not a Guitar Pro 7 or 8 file." end
    local ok, x, why = pcall(GP.unzip, data, "Content/score.gpif") -- (a damaged zip index can stop the reading)
    xml = ok and x or nil
    if not xml then
      return nil, why == "missing" and "No score in this file: is it a Guitar Pro 7 or 8 file?" or "This file is damaged: it could not be unpacked."
    end
  elseif ext == "gpx" then
    local head = data:sub(1, 4)
    if head ~= "BCFZ" and head ~= "BCFS" then return nil, "This file is damaged, or it is not a Guitar Pro file." end
    local ok, x = pcall(GP.gpx, data)
    if not ok then return nil, "This file is damaged: it could not be unpacked." end
    if not x then return nil, "No score in this file: is it a Guitar Pro 6 file?" end
    xml = x
  end
  if not xml:find("<GPIF", 1, true) then return nil, "This file has no Guitar Pro score in it." end
  return xml
end

-- What a track is: "bass", "guitar", "drums" or "other", from its instrument type (Guitar Pro 7 / 8: "electricBass",
-- "synthBass", "electricGuitar", "steelGuitar", "drumKit", "electricPiano" ...; Guitar Pro 6: "e-bass4", "e-gtr6",
-- "s-gtr6", "drmkt" ...) or its name (Guitar Pro 3 to 5).
function GP.kind(typ)
  local t = (typ or ""):lower()
  if t:find("drum", 1, true) or t:find("drm", 1, true) or t:find("perc", 1, true) then return "drums" end
  if t:find("bass", 1, true) then return "bass" end
  if t:find("guit", 1, true) or t:find("gtr", 1, true) then return "guitar" end
  return "other"
end

-- The parts of a score (the text of score.gpif): { tracks = { { name, kind (GP.kind), inst (the instrument name),
-- open = { MIDI from the lowest string } (none for drums), capo } }, tempo (the first, BPM), tempos (how many),
-- mbars = { { num, den, bars = { the bar of each track }, rstart, rend, count, alt = { [pass] = true }, section (its
-- name: "Solo"; nil: none) } }, and the
-- tables bars, voices, beats, notes, rhythms (by id) }; tmap = { { bar (its master bar), frac (how far into the bar,
-- 0-1) or q (quarter notes into it: the older files), bpm (quarter notes) } }: the tempo changes (GP.timeline).
local TEMPO_UNIT = { 0.5, 1, 1.5, 2, 3 }
-- The text of an element's content: without the spaces and line breaks around it and without a <![CDATA[ ]]> wrapper
-- (lessons 24 November 2026: a real file has line breaks around it). nil: "".
local function xml_text(s)
  s = (s or ""):match("^%s*(.-)%s*$")
  return s:match("^<!%[CDATA%[(.-)%]%]>$") or s
end
function GP.parse(xml)
  local function tbl(tag)
    local t = {}
    for id, body in xml:gmatch("<" .. tag .. ' id="(%d+)">(.-)</' .. tag .. ">") do t[id] = body end
    return t
  end
  local doc = { tracks = {}, mbars = {}, bars = tbl("Bar"), voices = tbl("Voice"), beats = tbl("Beat"), notes = tbl("Note"),
    rhythms = tbl("Rhythm"), tempos = 0 }
  for body in xml:gmatch('<Track id="%d+">(.-)</Track>') do
    local inst = body:match("<InstrumentSet>(.-)</InstrumentSet>") or ""
    local kind = GP.kind(inst:match("<Type>(.-)</Type>") or body:match('<Instrument ref="([^"]*)"')) -- (Guitar Pro 6: a ref)
    local open = {}
    if kind ~= "drums" then
      for p in (body:match('<Property name="Tuning">%s*<Pitches>([%d%s]+)</Pitches>') or ""):gmatch("%d+") do open[#open + 1] = tonumber(p) end
    end
    local diag = {} -- (the chord diagrams of the track: their names, by id; a beat names its chord by id)
    for id, nm in body:gmatch('<Item id="(%d+)" name="([^"]*)"') do diag[id] = nm end
    doc.tracks[#doc.tracks + 1] = { name = body:match("<Name><!%[CDATA%[(.-)%]%]></Name>") or "Track", kind = kind,
      inst = inst:match("<Name>(.-)</Name>") or "", open = open, diag = diag,
      capo = tonumber(body:match('<Property name="CapoFret">%s*<Fret>(%d+)</Fret>') or "") or 0 }
  end
  doc.tmap = {}
  for body in (xml:match("<MasterTrack>(.-)</MasterTrack>") or ""):gmatch("<Automation>(.-)</Automation>") do
    if body:match("<Type>(.-)</Type>") == "Tempo" then
      doc.tempos = doc.tempos + 1
      local v, unit = body:match("<Value>%s*([%d%.]+)%s*(%d*)")
      local bpm = tonumber(v or "")
      if doc.tempos == 1 then doc.tempo = bpm end
      -- the beat of the tempo: 1 an 8th, 2 a quarter (the usual), 3 a dotted quarter, 4 a half, 5 a dotted half
      if bpm then
        bpm = bpm * (TEMPO_UNIT[tonumber(unit) or 2] or 1)
        doc.tmap[#doc.tmap + 1] = { bar = (tonumber(body:match("<Bar>(%d+)</Bar>") or "") or 0) + 1,
          frac = tonumber(body:match("<Position>([%d%.]+)</Position>") or "") or 0, bpm = bpm }
      end
    end
  end
  for body in xml:gmatch("<MasterBar>(.-)</MasterBar>") do
    local num, den = body:match("<Time>(%d+)/(%d+)</Time>")
    local mb = { num = tonumber(num) or 4, den = tonumber(den) or 4, bars = {} }
    for id in (body:match("<Bars>([%d%s%-]+)</Bars>") or ""):gmatch("%-?%d+") do mb.bars[#mb.bars + 1] = id end
    local rs, re, cnt = body:match('<Repeat start="(%a+)" end="(%a+)" count="(%d+)"')
    mb.rstart, mb.rend, mb.count = rs == "true", re == "true", tonumber(cnt) or 0
    local sec = body:match("<Section>(.-)</Section>") -- (a section: its text, else its letter; "Solo", "A")
    if sec then
      local txt, letter = xml_text(sec:match("<Text>(.-)</Text>")), xml_text(sec:match("<Letter>(.-)</Letter>"))
      mb.section = txt ~= "" and txt or letter ~= "" and letter or nil
    end
    local alt = body:match("<AlternateEndings>([%d%s]+)</AlternateEndings>")
    if alt then
      mb.alt = {}
      for p in alt:gmatch("%d+") do mb.alt[tonumber(p)] = true end
    end
    doc.mbars[#doc.mbars + 1] = mb
  end
  return doc
end

---------------------------------------------------------------------------
-- OLDER FILES (.gp3, .gp4, .gp5: Guitar Pro 3 to 5, a binary format; read in the order the file is written)
---------------------------------------------------------------------------
-- The MIDI program families (General MIDI), for a track that is no guitar, bass or drums.
local GM_FAMILY = { "Piano", "Chromatic percussion", "Organ", "Guitar", "Bass", "Strings", "Ensemble", "Brass", "Reed",
  "Pipe", "Synth lead", "Synth pad", "Synth effects", "Ethnic", "Percussive", "Sound effects" }
local TUPLET = { [3] = 2, [5] = 4, [6] = 4, [7] = 4, [9] = 8, [10] = 8, [11] = 8, [12] = 8, [13] = 8 } -- (n notes in the time of)

-- What a track of an older file is: its MIDI channel 10 or the drum flag, its MIDI program (24-31 guitars, 32-39
-- basses), else its name (GP.kind).
function GP.old_kind(name, drums, program)
  if drums then return "drums" end
  if program >= 32 and program <= 39 then return "bass" end
  if program >= 24 and program <= 31 then return "guitar" end
  return GP.kind(name)
end

-- The parts of the score of a .gp3, .gp4 or .gp5 file (data: the whole file), the same as GP.parse gives (the bars
-- are lists of notes: GP.bar_notes). nil and why (a text for the user). Errors (caught by GP.read) on damaged data.
function GP.read_old(data)
  -- (Guitar Pro 5 can leave out the last bytes of the last bar: up to 3 bytes after the end read as 0)
  local length = #data
  data = data .. "\0\0\0"
  local p = 1
  local function u8()
    local b = byte(data, p)
    if not b then error("the file ends too early") end
    p = p + 1
    return b
  end
  local function i8() local b = u8(); return b >= 128 and b - 256 or b end
  local function i16() local v; v, p = string.unpack("<i2", data, p); return v end
  local function i32() local v; v, p = string.unpack("<i4", data, p); return v end
  local function skip(n)
    p = p + n
    if p > #data + 1 then error("the file ends too early") end
  end
  local function bstr(size) -- (a length byte, then always `size` bytes)
    local n = u8()
    local s = data:sub(p, p + math.min(n, size) - 1)
    skip(size)
    return s
  end
  local function istr() -- (a length, then the text)
    local n = i32()
    if n < 0 then error("a damaged length") end
    local s = data:sub(p, p + n - 1)
    skip(n)
    return s
  end
  local function ibstr() -- (the size of what follows, a length byte, the text)
    local d = i32()
    if d <= 0 then return "" end
    local n = u8()
    local s = data:sub(p, p + n - 1)
    skip(d - 1)
    return s
  end
  local function count(n, max) -- (a number of things: a damaged file gives a wild one)
    if n < 0 or n > max then error("a damaged count") end
    return n
  end

  local head = bstr(30)
  local major, minor = head:match("GUITAR PRO v?L?(%d)%.(%d%d)")
  local v = major and tonumber(major) * 100 + tonumber(minor)
  if not v or v < 300 or v > 510 then return nil, "This Guitar Pro version can not be read (" .. head .. ")." end
  local doc = { tracks = {}, mbars = {}, bars = {}, tempos = 1, tmap = {} }
  local here = { k = 1, pos = 0 } -- (the bar and the place in it of the beat that is read: a tempo change there)

  -- the song: texts, lyrics, page setup, tempo, key, the 64 MIDI channels
  local function info()
    for _ = 1, (v >= 500 and 9 or 8) do ibstr() end -- (title, subtitle, artist, album, words, [music,] copyright, tab, instructions)
    for _ = 1, count(i32(), 1000) do ibstr() end -- (the notice lines)
  end
  local function lyrics()
    i32()
    for _ = 1, 5 do i32(); istr() end
  end
  info()
  if v < 400 then
    skip(1) -- (triplet feel)
    doc.tempo = i32()
    i32() -- (key)
  elseif v < 500 then
    skip(1)
    lyrics()
    doc.tempo = i32()
    i32(); skip(1) -- (key, octave)
  else
    lyrics()
    if v > 500 then i32(); i32(); skip(11) end -- (the master effect: volume, ?, equalizer)
    skip(30) -- (page setup: size, margins, proportion, header and footer)
    for _ = 1, 10 do ibstr() end -- (its texts)
    ibstr() -- (the tempo name)
    doc.tempo = i32()
    if v > 500 then skip(1) end -- (hide the tempo)
    skip(1); i32() -- (key, octave)
  end
  local programs = {}
  for c = 1, 64 do programs[c] = i32(); skip(8) end -- (program; volume, balance, chorus, reverb, phaser, tremolo, 2 blank)
  if v >= 500 then skip(38); i32() end -- (the 19 directions: coda, segno ...; the master reverb)
  local nbars, ntracks = count(i32(), 5000), count(i32(), 100)

  -- the bars (master bars): time signature, repeats, alternate endings
  local num, den, altmask = 4, 4, {}
  for k = 1, nbars do
    if v >= 500 and k > 1 then skip(1) end
    local f = u8()
    if f & 1 ~= 0 then num = i8() end
    if f & 2 ~= 0 then den = i8() end
    local mb = { num = num, den = den, bars = {}, rstart = f & 4 ~= 0, rend = false, count = 0 }
    if f & 8 ~= 0 then -- (a repeat end: Guitar Pro 5 keeps how often it plays, 3 and 4 how often it repeats)
      local c = i8()
      mb.rend, mb.count = true, v >= 500 and c or c + 1
    end
    local function alternative()
      local a, mask = u8(), nil
      if v >= 500 then mask = a -- (the endings as bits)
      else -- (the number of the ending: all endings up to it that the bars before, back to the repeat start, do not have)
        local had = 0
        for j = k - 1, 1, -1 do
          if doc.mbars[j].rstart then break end
          had = had | (altmask[j] or 0)
        end
        mask = ((1 << a) - 1) ~ had
      end
      altmask[k], mb.alt = mask, {}
      for b = 0, 7 do if mask & (1 << b) ~= 0 then mb.alt[b + 1] = true end end
    end
    if v < 500 then
      if f & 16 ~= 0 then alternative() end
      if f & 32 ~= 0 then mb.section = ibstr(); skip(4) end -- (a marker: its name (the section) and colour)
      if f & 64 ~= 0 then skip(2) end -- (a key)
    else
      if f & 32 ~= 0 then mb.section = ibstr(); skip(4) end
      if f & 64 ~= 0 then skip(2) end
      if f & 16 ~= 0 then alternative() end
      if f & 3 ~= 0 then skip(4) end -- (the beams)
      if f & 16 == 0 then skip(1) end
      skip(1) -- (triplet feel)
    end
    doc.mbars[k] = mb
  end

  -- the tracks: name, strings (from the highest in the file), MIDI channel, capo
  local strings = {}
  for t = 1, ntracks do
    if v >= 500 and (t == 1 or v == 500) then skip(1) end
    local flags = u8()
    local name = bstr(40)
    local ns = count(i32(), 7)
    local tun = {}
    for i = 1, 7 do
      local x = i32()
      if i <= ns then tun[i] = x end
    end
    i32() -- (port)
    local chan = i32() - 1
    i32(); i32() -- (effect channel, frets)
    local capo = i32()
    skip(4) -- (colour)
    if v >= 500 then
      skip(4) -- (flags, accents, bank)
      skip(25) -- (RSE: humanize, 3 values, 12 bytes)
      skip(v == 500 and 15 or 16) -- (RSE instrument)
      if v > 500 then skip(4); ibstr(); ibstr() end -- (equalizer, effect, its category)
    end
    local open = {}
    for i = ns, 1, -1 do open[#open + 1] = tun[i] end
    local drums = flags & 1 ~= 0 or chan % 16 == 9
    local program = programs[chan + 1] or 0
    local kind = GP.old_kind(name, drums, program)
    doc.tracks[t] = { name = name ~= "" and name or ("Track " .. t), kind = kind, open = kind == "drums" and {} or open,
      capo = capo, inst = kind == "drums" and "Drums" or (GM_FAMILY[program // 8 + 1] or "") }
    strings[t] = { n = ns, open = open, last = {} }
  end
  if v >= 500 then skip(v == 500 and 2 or 1) end

  -- the notes, bar after bar, each bar: track after track
  local function bend() skip(5); skip(count(i32(), 100) * 9) end -- (type, value; the points: position, value, vibrato)
  -- A chord diagram: its name ("" none). Guitar Pro 5: 107 bytes, the name at 17; the new format of 3 and 4 (after
  -- its first byte 1): 124 / 106 bytes, the name at 25 / 16; the old format: name, first fret, 6 frets.
  local function chord()
    local at, name = p, nil
    if v >= 500 then skip(17); name = bstr(21); p = at; skip(107); return name end
    if u8() == 0 then
      name = ibstr()
      if i32() ~= 0 then skip(24) end
      return name
    end
    at = p
    skip(v >= 400 and 16 or 25); name = bstr(22)
    p = at; skip(v >= 400 and 106 or 124)
    return name
  end
  local function beat_effects() -- (returns true for a vibrato of the beat: its notes get the mark)
    if v < 400 then
      local f = u8()
      if f & 0x20 ~= 0 then skip(5) end -- (slap or tremolo bar)
      if f & 0x40 ~= 0 then skip(2) end -- (stroke)
      return f & 0x03 ~= 0
    else
      local f1, f2 = u8(), u8()
      if f1 & 0x20 ~= 0 then skip(1) end
      if f2 & 0x04 ~= 0 then bend() end -- (tremolo bar)
      if f1 & 0x40 ~= 0 then skip(2) end
      if f2 & 0x02 ~= 0 then skip(1) end -- (pick stroke)
      return f1 & 0x03 ~= 0
    end
  end
  local function mix_table()
    skip(1) -- (instrument)
    if v >= 500 then skip(16) end -- (RSE instrument)
    local vals = {}
    for i = 1, 6 do vals[i] = i8() end -- (volume, balance, chorus, reverb, phaser, tremolo; -1: no change)
    if v >= 500 then ibstr() end -- (the tempo name)
    local tempo = i32()
    for i = 1, 6 do if vals[i] >= 0 then skip(1) end end
    if tempo >= 0 then
      skip(v > 500 and 2 or 1)
      if tempo > 0 then
        doc.tempos = doc.tempos + 1
        doc.tmap[#doc.tmap + 1] = { bar = here.k, q = here.pos, bpm = tempo }
      end
    end
    if v >= 400 then skip(1) end -- (all tracks)
    if v >= 500 then skip(1) end -- (wah)
    if v > 500 then ibstr(); ibstr() end -- (the RSE effect and its category)
  end
  -- The playing marks of a note (GP.fx): ho (hammer-on / pull-off), slide (the flags of GP.SLIDE), bend, vib, pm, harm.
  local SLIDE4 = { [-2] = 32, [-1] = 16, [1] = 1, [2] = 2, [3] = 4, [4] = 8 } -- (Guitar Pro 4: a value, not flags)
  local function note_effects(fx)
    if v < 400 then
      local f = u8()
      if f & 0x01 ~= 0 then bend(); fx.bend = true end
      if f & 0x02 ~= 0 then fx.ho = true end
      if f & 0x04 ~= 0 then fx.slide = 2 end
      if f & 0x10 ~= 0 then skip(4) end -- (grace note)
      return
    end
    local f1, f2 = u8(), u8()
    if f1 & 0x01 ~= 0 then bend(); fx.bend = true end
    if f1 & 0x02 ~= 0 then fx.ho = true end
    if f1 & 0x10 ~= 0 then skip(v >= 500 and 5 or 4) end
    if f2 & 0x02 ~= 0 then fx.pm = true end
    if f2 & 0x04 ~= 0 then -- (tremolo picking: 1 8ths, 2 16ths, 3 32nds)
      local t = u8()
      if t >= 1 and t <= 3 then fx.trem = t end
    end
    if f2 & 0x08 ~= 0 then -- (slide)
      local s = i8()
      fx.slide = v >= 500 and (s & 0x3F) or SLIDE4[s]
    end
    if f2 & 0x10 ~= 0 then -- (harmonic)
      local h = i8()
      fx.harm = true
      if v >= 500 and h == 2 then skip(3) elseif v >= 500 and h == 3 then skip(1) end
    end
    if f2 & 0x20 ~= 0 then skip(2) end -- (trill)
    if f2 & 0x40 ~= 0 then fx.vib = true end
  end
  local function note(st, gs, pos, len, out, vib)
    local f = u8()
    local typ = f & 0x20 ~= 0 and u8() or 1 -- (1 normal, 2 tied, 3 dead)
    if v < 500 and f & 0x01 ~= 0 then skip(2) end
    if f & 0x10 ~= 0 then skip(1) end -- (dynamics)
    local fret = f & 0x20 ~= 0 and i8() or 0
    if f & 0x80 ~= 0 then skip(2) end -- (fingering)
    if v >= 500 then
      if f & 0x01 ~= 0 then skip(8) end
      skip(1)
    end
    local fx = { vib = vib or nil, dead = typ == 3 or nil }
    if f & 0x08 ~= 0 then note_effects(fx) end
    if typ == 2 then fret = st.last[gs] or fret end -- (a tied note keeps the fret of the note before on its string)
    st.last[gs] = fret
    local s = st.n - gs + 1 -- (1 = the lowest string)
    out[#out + 1] = { pos = pos, len = len, midi = (st.open[s] or 0) + fret, s = s, fret = fret, tie = typ == 2,
      fx = next(fx) and fx or nil }
  end
  local function beat(st, pos, out)
    local f = u8()
    local empty = f & 0x40 ~= 0 and u8() == 0
    local d = i8()
    if d < -2 or d > 6 then error("a damaged note value") end
    local len = 4 / (1 << (d + 2))
    if f & 0x01 ~= 0 then len = len * 1.5 end
    if f & 0x20 ~= 0 then
      local n = i32()
      if TUPLET[n] then len = len * TUPLET[n] / n end
    end
    if f & 0x02 ~= 0 then
      local name = chord():gsub("[%c]", "")
      if name ~= "" then
        out.chords = out.chords or {}
        out.chords[#out.chords + 1] = { pos = pos, name = name }
      end
    end
    if f & 0x04 ~= 0 then ibstr() end -- (text)
    local vib = f & 0x08 ~= 0 and beat_effects()
    if f & 0x10 ~= 0 then mix_table() end
    local sf = u8()
    for gs = 1, st.n do
      if sf & (1 << (7 - gs)) ~= 0 then note(st, gs, pos, len, out, vib) end
    end
    if v >= 500 and i16() & 0x0800 ~= 0 then skip(1) end
    return empty and 0 or len
  end
  for k = 1, nbars do
    for t = 1, ntracks do
      local out = {}
      for _ = 1, (v >= 500 and 2 or 1) do -- (the voices)
        local pos = 0
        for _ = 1, count(i32(), 1000) do
          here.k, here.pos = k, pos
          pos = pos + beat(strings[t], pos, out)
        end
      end
      if v >= 500 then skip(1) end -- (line break)
      local id = k .. ":" .. t
      doc.bars[id], doc.mbars[k].bars[t] = out, id
    end
  end
  doc.rest = length + 1 - p -- (the bytes after the last bar: 0 in a file that was read right)
  return doc
end

-- The order in which the master bars play: the repeats played out (count = how often), alternate endings on their pass.
-- The bars of an ending: the file marks only its first bar ("1." on bar 85); the bars after it up to its :| belong
-- to it too (mb.alt; the user's tab, 24 November 2026: an ending of 2 bars). An ending after the last :| stays 1 bar.
function GP.endings(mbars)
  local cur, run = nil, {}
  for _, mb in ipairs(mbars) do
    if mb.rstart then cur, run = nil, {} end
    if mb.alt then cur, run = mb.alt, {}
    elseif cur then run[#run + 1] = mb end
    if mb.rend then
      if cur then for _, x in ipairs(run) do x.alt = cur end end
      cur, run = nil, {}
    end
  end
end
function GP.order(mbars)
  GP.endings(mbars)
  local order, i, start, pass, after = {}, 1, 1, {}, nil
  while i <= #mbars and #order < 20000 do
    local mb = mbars[i]
    if mb.rstart then start = i end
    local p = pass[start] or after or 1 -- (after: the last pass, for the endings just after its :|, "2.")
    if mb.alt and not mb.alt[p] then
      i = i + 1
    else
      order[#order + 1] = i
      if not mb.alt then after = nil end
      if mb.rend and p < math.max(1, mb.count) then
        pass[start] = p + 1
        i = start
      else
        if mb.rend then pass[start], after, start = nil, p, i + 1 end -- (a :| without |: repeats from here)
        i = i + 1
      end
    end
  end
  return order
end

-- The playing marks of a note of a .gp / .gpx file (its XML text): { ho (hammer-on / pull-off from it), slide (flags:
-- 1 shift, 2 legato, 4 out down, 8 out up, 16 in from below, 32 in from above; the same in .gp5), bend, vib, pm
-- (palm mute), harm (harmonic), dead }, or nil (none).
local FX_PROPS = { ho = "HopoOrigin", bend = "Bended", pm = "PalmMuted", harm = "HarmonicType", dead = "Muted" }
for k, name in pairs(FX_PROPS) do FX_PROPS[k] = '<Property name="' .. name .. '"' end -- (the texts searched: made once)
function GP.fx(n)
  if not n:find("<Property", 1, true) and not n:find("<Vibrato>", 1, true) then return nil end
  local fx
  for k, find in pairs(FX_PROPS) do
    if n:find(find, 1, true) then fx = fx or {}; fx[k] = true end
  end
  local sl = tonumber(n:match('<Property name="Slide">%s*<Flags>(%d+)</Flags>') or "")
  if sl and sl > 0 then fx = fx or {}; fx.slide = sl end
  if n:find("<Vibrato>", 1, true) then fx = fx or {}; fx.vib = true end
  return fx
end

-- (tremolo picking, a part of a quarter note: 1/2 8ths, 1/4 16ths, 1/8 32nds -> fx.trem, the slashes; a real file
-- has "1/4" for 16ths, lessons 24 November 2026)
local TREMOLO = { ["2"] = 1, ["4"] = 2, ["8"] = 3 }
local NOTE_VALUE = { Zero = 0, Whole = 4, Half = 2, Quarter = 1, Eighth = 0.5, ["16th"] = 0.25, ["32nd"] = 0.125, ["64th"] = 0.0625 }
-- The notes of 1 bar, voice after voice: { { pos (quarter notes from the start of the bar), len, midi, s (1 = the
-- lowest string), fret, tie, fx (GP.fx; a muted (dead) note: fx.dead) } }; grace notes are left out. bar: the text of a bar of a .gp
-- file, or the list itself (an older file: GP.read_old makes it). open: the tuning of the track (a note with only its
-- string and fret, as in Guitar Pro 6, gets its pitch from it). diag: the chord names of the track by id. The chord
-- names of the bar: out.chords = { { pos, name } } (nil: none).
function GP.bar_notes(doc, bar, open, diag)
  if type(bar) == "table" then return bar end
  local out = {}
  for vid in ((bar and bar:match("<Voices>([%d%s%-]+)</Voices>")) or ""):gmatch("%-?%d+") do
    local voice = doc.voices[vid]
    local pos = 0
    for bid in ((voice and voice:match("<Beats>([%d%s]+)</Beats>")) or ""):gmatch("%d+") do
      local beat = doc.beats[bid] or ""
      if beat:find("<GraceNotes>", 1, true) then beat = "" end -- (a grace note takes no time of the bar: left out)
      local rh = beat == "" and "<NoteValue>Zero</NoteValue>" or doc.rhythms[beat:match('<Rhythm ref="(%d+)"') or ""] or ""
      local len = NOTE_VALUE[rh:match("<NoteValue>(.-)</NoteValue>") or ""] or 1
      local dots = tonumber(rh:match('<AugmentationDot count="(%d+)"') or 0)
      if dots > 0 then len = len * (2 - 0.5 ^ dots) end
      local tn, td = rh:match("<PrimaryTuplet num=\"(%d+)\" den=\"(%d+)\"")
      if tn then len = len * tonumber(td) / tonumber(tn) end
      local cname = diag and diag[beat:match("<Chord>(%d+)</Chord>") or ""]
      if cname and cname ~= "" then
        out.chords = out.chords or {}
        out.chords[#out.chords + 1] = { pos = pos, name = cname }
      end
      local trem = TREMOLO[beat:match("<Tremolo>1/(%d+)</Tremolo>") or ""] -- (tremolo picking: a mark of the beat)
      for nid in (beat:match("<Notes>([%d%s]+)</Notes>") or ""):gmatch("%d+") do
        local n = doc.notes[nid] or ""
        local midi = tonumber(n:match('<Property name="Midi">%s*<Number>(%d+)</Number>') or "")
        local s = tonumber(n:match('<Property name="String">%s*<String>(%d+)</String>') or "")
        local fret = tonumber(n:match('<Property name="Fret">%s*<Fret>(%d+)</Fret>') or "")
        if not midi and s and fret and open and open[s + 1] then midi = open[s + 1] + fret end
        if midi then
          local fx = GP.fx(n)
          if trem then fx = fx or {}; fx.trem, fx.tup = trem, tn and tonumber(td) / tonumber(tn) end -- (tup: 2/3 a triplet)
          out[#out + 1] = { pos = pos, len = len, midi = midi, s = s and s + 1, fret = fret,
            tie = n:match('<Tie origin="%a+" destination="true"') ~= nil, fx = fx }
        end
      end
      pos = pos + len
    end
  end
  return out
end

-- The notes of a track in the order they play: { { q, len (quarter notes from the start of bar 1), midi, s (1 = the
-- lowest string), fret } }; ties join the note before. A repeat bar mark (%, the SimileMark of a bar) plays the bar
-- that played 1 bar before (Simple) or 2 bars before (FirstOfDouble, SecondOfDouble). Second value: the chord names
-- of the file in the order they play: { { q, name } }. dead: keep the muted (dead) notes (the tab shows them as x;
-- without dead they are left out); each note has its playing marks (fx, as GP.fx) when it has any.
local SIMILE_BACK = { Simple = 1, FirstOfDouble = 2, SecondOfDouble = 2 }
local EMPTY = {} -- (never changed: a list with nothing in it, without a new table)
-- A note of GP.notes from note x of a bar that starts at q (w: the written length; len: how long it rings, with ties).
-- f: mb.fit of its bar (a new time signature with the notes fitted into the bar: Tab Viewer; else 1).
local function new_note(x, q, f)
  return { q = q + x.pos * f, len = x.len * f, w = x.len * f, midi = x.midi, s = x.s, fret = x.fret, fx = x.fx }
end
function GP.notes(doc, track, dead)
  local out, q, last, played, seen, names = {}, 0, {}, {}, {}, {}
  local tr = doc.tracks[track]
  local open, diag = tr and tr.open, tr and tr.diag
  for j, k in ipairs(GP.order(doc.mbars)) do
    local mb = doc.mbars[k]
    local bar = doc.bars[mb.bars[track] or "-1"]
    local back = type(bar) == "string" and SIMILE_BACK[bar:match("<SimileMark>(%a+)</SimileMark>") or ""]
    if back then bar = played[j - back] end
    played[j] = bar
    if bar and not seen[bar] then seen[bar] = GP.bar_notes(doc, bar, open, diag) end -- (a repeated bar: read once)
    local f = mb.fit or 1
    for _, c in ipairs(bar and seen[bar] and seen[bar].chords or {}) do names[#names + 1] = { q = q + c.pos * f, name = c.name } end
    for _, x in ipairs(bar and seen[bar] or {}) do
      local prev = last[x.midi]
      if x.fx and x.fx.dead then -- (a dead note: only for the tab; never part of a tie)
        if dead then out[#out + 1] = new_note(x, q, f) end
      elseif x.tie and prev and math.abs(prev.q + prev.len - q - x.pos * f) < 1e-3 then -- (a tie: the note before goes
        -- on, only when it ends here (not 1 from bars before: a damaged file, a gap); ties: its held parts { q, w }, for the tab)
        prev.len = q + (x.pos + x.len) * f - prev.q
        prev.ties = prev.ties or {}
        prev.ties[#prev.ties + 1] = { q = q + x.pos * f, w = x.len * f }
      else
        local n = new_note(x, q, f)
        out[#out + 1] = n
        last[x.midi] = n
      end
    end
    q = q + 4 * mb.num / mb.den
  end
  table.sort(out, function(a, b) return a.q < b.q or (a.q == b.q and a.midi < b.midi) end) -- (a chord: from the lowest)
  return out, names
end

-- The tab of a track: its bars in the order they play (the repeats played out), each with its notes: { nstr, names
-- (the open strings, from the lowest; the highest "e" when it has the name of the lowest), bars = { { q0 (quarter
-- notes from the start of the tab), len, n16 (its 16ths), notes = { { q (in the bar), len, w (written), s (1 = the lowest
-- string), fret } }, chords = { { q, name } } } }, has_chords }. A note without a string and fret (drums) is left
-- out. The chord names: the file's, else named from the notes that start together and ring at least 1 beat
-- (GP.chord_name; decided 24 November 2026: fast riffs get no names); a name shows only where the chord changes.
function GP.tab(doc, track)
  local open = doc.tracks[track].open
  local tab = { nstr = #open, names = {}, bars = {} }
  for s, m in ipairs(open) do tab.names[s] = GP.NAMES[m % 12] end
  if tab.nstr > 1 and tab.names[tab.nstr] == tab.names[1] then tab.names[tab.nstr] = tab.names[tab.nstr]:lower() end
  local q = 0
  for _, k in ipairs(GP.order(doc.mbars)) do
    local len = 4 * doc.mbars[k].num / doc.mbars[k].den
    tab.bars[#tab.bars + 1] = { q0 = q, len = len, n16 = math.max(1, math.ceil(len * 4 - 1e-9)), notes = {}, chords = {},
      wb = k } -- (wb: the written bar; a repeat plays it again)
    q = q + len
  end
  local notes, names = GP.notes(doc, track, true)
  -- the chords: by place (in 48ths of a quarter note), the file's name or the notes there
  local at, places = {}, {}
  local function place(qq)
    local key = math.floor(qq * 48 + 0.5)
    if not at[key] then at[key] = { q = qq, midis = {} }; places[#places + 1] = key end
    return at[key]
  end
  for _, c in ipairs(names) do place(c.q).name = c.name end
  local function bar_at(from, qq) -- (the bar where qq is, from bar index from on: the places only grow)
    while tab.bars[from + 1] and qq >= tab.bars[from + 1].q0 - 1e-9 do from = from + 1 end
    return from
  end
  local b = 1
  for _, n in ipairs(notes) do
    b = bar_at(b, n.q)
    local bar = tab.bars[b]
    if bar and n.s and n.fret then
      bar.notes[#bar.notes + 1] = { q = n.q - bar.q0, len = n.len, w = n.w, s = n.s, fret = n.fret, fx = n.fx }
      for _, t in ipairs(n.ties or EMPTY) do -- (the held parts of a tied note: drawn "(4)", in the bar where they start)
        local tbar = tab.bars[bar_at(b, t.q)]
        tbar.ties = tbar.ties or {}
        tbar.ties[#tbar.ties + 1] = { q = t.q - tbar.q0, w = t.w, s = n.s, fret = n.fret, tie = true,
          trem = n.fx and n.fx.trem and n.fx } -- (a tremolo-picked note: its held parts are picked too)
      end
    end
    if bar and n.s and n.fret and not (n.fx and n.fx.dead) then
      local x = place(n.q)
      x.midis[#x.midis + 1] = n.midi
      x.len = math.max(x.len or 0, n.len)
    end
  end
  table.sort(places)
  local shown
  b = 1
  for _, key in ipairs(places) do
    local x = at[key]
    local name = x.name or ((x.len or 0) >= 1 - 1e-6 and GP.chord_name(x.midis)) or nil -- (a fast riff: no names)
    if name and name ~= shown then
      b = bar_at(b, x.q)
      local bar = tab.bars[b]
      if bar then
        bar.chords[#bar.chords + 1] = { q = x.q - bar.q0, name = name }
        shown, tab.has_chords = name, true
      end
    end
  end
  return tab
end

-- The name of a chord from its notes (MIDI numbers): the root and its kind ("Am", "G7", "D5"), "/" the lowest note
-- when it is not the root ("C/E"); nil when it is not a chord (fewer than 2 note names, or no known kind).
local CHORD_KINDS = {
  ["0 4 7"] = "", ["0 3 7"] = "m", ["0 7"] = "5", ["0 4 7 10"] = "7", ["0 4 7 11"] = "maj7", ["0 3 7 10"] = "m7",
  ["0 2 7"] = "sus2", ["0 5 7"] = "sus4", ["0 3 6"] = "dim", ["0 4 8"] = "aug", ["0 4 7 9"] = "6", ["0 3 7 9"] = "m6",
  ["0 2 4 7"] = "add9", ["0 2 4 7 10"] = "9", ["0 5 7 10"] = "7sus4", ["0 3 6 10"] = "m7b5", ["0 3 6 9"] = "dim7",
  ["0 4 10"] = "7", ["0 3 10"] = "m7", ["0 4 11"] = "maj7", ["0 2 3 7"] = "madd9",
}
function GP.chord_name(midis)
  if #midis < 2 then return nil end
  local low, pcs, has = math.huge, {}, {}
  for _, m in ipairs(midis) do
    low = math.min(low, m)
    if not has[m % 12] then has[m % 12] = true; pcs[#pcs + 1] = m % 12 end
  end
  if #pcs < 2 then return nil end
  local bass = low % 12
  table.sort(pcs, function(a, c) return (a - bass) % 12 < (c - bass) % 12 end) -- (the lowest note first: the usual root)
  for _, root in ipairs(pcs) do
    local iv = {}
    for k, pc in ipairs(pcs) do iv[k] = (pc - root) % 12 end
    table.sort(iv)
    local kind = CHORD_KINDS[table.concat(iv, " ")]
    if kind then return GP.NAMES[root] .. kind .. (root ~= bass and ("/" .. GP.NAMES[bass]) or "") end
  end
  return nil
end

-- The bars of the tab in the order they play, with their time signature and tempo: { { len (quarter notes), num,
-- den, tempos = { { q (quarter notes into the bar), bpm } } } }. Bar 1 always has a tempo at q 0 (the file's first
-- tempo, else 120); a repeated bar has its tempo changes again on each pass.
function GP.timeline(doc)
  local at = {}
  for _, x in ipairs(doc.tmap or {}) do
    local mb = doc.mbars[x.bar]
    if mb then
      local list = at[x.bar] or {}
      at[x.bar] = list
      local q = x.q and x.q * (mb.fit or 1) or (x.frac or 0) * 4 * mb.num / mb.den
      local dup = false
      for _, y in ipairs(list) do if math.abs(y.q - q) < 1e-6 then y.bpm, dup = x.bpm, true end end -- (each track: once)
      if not dup then list[#list + 1] = { q = q, bpm = x.bpm } end
    end
  end
  for _, list in pairs(at) do table.sort(list, function(a, b) return a.q < b.q end) end
  -- (a bar with its notes fitted, mb.fit: its tempo times fit, so it lasts as long as before: 4/4 at 125 -> 6/8 at
  -- 93.75; the bar after it gets the tempo of the file back)
  local out, bpm, pf = {}, doc.tempo or 120, 1
  for j, k in ipairs(GP.order(doc.mbars)) do
    local mb = doc.mbars[k]
    local f = mb.fit or 1
    local tempos = {}
    for i, x in ipairs(at[k] or {}) do tempos[i] = { q = x.q, bpm = x.bpm * f, file = x.bpm } end
    if (j == 1 or math.abs(f - pf) > 1e-9) and not (tempos[1] and tempos[1].q < 1e-6) then
      table.insert(tempos, 1, { q = 0, bpm = bpm * f, file = bpm })
    end
    if tempos[1] then bpm = tempos[#tempos].file end
    for _, x in ipairs(tempos) do x.file = nil end
    pf = f
    out[j] = { len = 4 * mb.num / mb.den, num = mb.num, den = mb.den, tempos = tempos }
  end
  return out
end

---------------------------------------------------------------------------
-- TUNINGS (the names shown for a track)
---------------------------------------------------------------------------
GP.NAMES = { [0] = "C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B" } -- (the usual names in tunings)
local STD_LOW = { bass = { [4] = 28, [5] = 23, [6] = 23 }, guitar = { [6] = 40, [7] = 35, [8] = 30 } }
-- The note names of the open strings, from the lowest: "E A D G".
function GP.notes_text(open)
  local t = {}
  for k, m in ipairs(open) do t[k] = GP.NAMES[m % 12] end
  return table.concat(t, " ")
end
-- The name of a tuning: "Standard", "Eb Standard", "Drop D", else its notes ("Bb E A D"); ", capo 2" after it.
-- kind: "bass" or "guitar" (all strings a 4th apart; a guitar's 2nd highest string a major 3rd).
function GP.tuning_text(open, kind, capo)
  local n, name = #open, nil
  if n >= 2 and STD_LOW[kind] then
    local std, drop = true, true
    for k = 1, n - 1 do
      local want = (kind == "guitar" and k == n - 2) and 4 or 5
      local d = open[k + 1] - open[k]
      if d ~= want then std = false end
      if d ~= (k == 1 and want + 2 or want) then drop = false end
    end
    local low = STD_LOW[kind][n]
    if std and low then name = (open[1] - low) % 12 == 0 and "Standard" or (GP.NAMES[open[1] % 12] .. " Standard")
    elseif drop then name = "Drop " .. GP.NAMES[open[1] % 12] end
  end
  name = name or GP.notes_text(open)
  if (capo or 0) > 0 then name = name .. ", capo " .. capo end
  return name
end

---------------------------------------------------------------------------
-- WRITE A GUITAR PRO 5 FILE (.gp5; the Export of the Note Detection tab, decided 25 November 2026)
---------------------------------------------------------------------------
-- The plain and dotted note values (quarter notes, the Guitar Pro duration: -2 whole ... 3 32nd), the longest first.
local GP5_VALUES = {}
for d = -2, 3 do
  local len = 4 / (1 << (d + 2))
  GP5_VALUES[#GP5_VALUES + 1] = { len = len * 1.5, d = d, dot = true }
  GP5_VALUES[#GP5_VALUES + 1] = { len = len, d = d }
end
table.sort(GP5_VALUES, function(a, b) return a.len > b.len end)
-- A length (quarter notes) as note values that are played one after the other (tied): the longest that fits first.
-- What is shorter than a 32nd is left out. Returns { { d, dot }, ... }.
function GP.values(len)
  local out = {}
  while len > 0.125 - 1e-3 do
    for _, v in ipairs(GP5_VALUES) do
      if v.len <= len + 1e-3 then out[#out + 1] = v; len = len - v.len; break end
    end
  end
  return out
end
-- The file (Guitar Pro 5.10, the same layout that GP.read_old reads) of song = { title, artist, tempo (BPM),
-- tracks = { { name, open = { the MIDI note of each string, from the lowest }, program (General MIDI, 0-127) } },
-- bars = { { num, den, tempo (a change at its start, or nil), tracks = { [t] = { { len (quarter notes), trip (a
-- triplet: len is the played length), notes = { { s (1 = the lowest string), fret } } (none: a rest), tie (the notes
-- go on from the bar before) } } } } } }. An event that is not 1 note value is written as tied notes (a rest: rests).
function GP.write_gp5(song)
  local b = {}
  local function u8(x) b[#b + 1] = char(x & 0xFF) end
  local function i16(x) b[#b + 1] = string.pack("<i2", x) end
  local function i32(x) b[#b + 1] = string.pack("<i4", x) end
  local function zeros(n) b[#b + 1] = string.rep("\0", n) end
  local function bstr(s, size) s = s:sub(1, size); u8(#s); b[#b + 1] = s .. string.rep("\0", size - #s) end
  local function istr(s) i32(#s); b[#b + 1] = s end
  local function ibstr(s) s = s:sub(1, 255); i32(#s + 1); u8(#s); b[#b + 1] = s end
  local tracks, bars = song.tracks, song.bars
  -- the song: texts, lyrics, the master effect, the page, the tempo, key
  bstr("FICHIER GUITAR PRO v5.10", 30)
  ibstr(song.title or ""); ibstr(""); ibstr(song.artist or "")
  for _ = 1, 6 do ibstr("") end -- (album, words, music, copyright, tab, instructions)
  i32(0) -- (no notice lines)
  i32(0); for _ = 1, 5 do i32(1); istr("") end -- (lyrics)
  i32(100); i32(0); zeros(11) -- (the master effect: volume, ?, equalizer)
  i32(210); i32(297); i32(10); i32(10); i32(15); i32(10); i32(100); i16(0x1FF) -- (A4, margins, size, header and footer)
  for _, s in ipairs({ "%TITLE%", "%SUBTITLE%", "%ARTIST%", "%ALBUM%", "Words by %WORDS%", "Music by %MUSIC%",
    "Words & Music by %WORDSMUSIC%", "Copyright %COPYRIGHT%", "All Rights Reserved - International Copyright Secured",
    "Page %N%/%P%" }) do ibstr(s) end
  ibstr("Moderate"); i32(math.floor((song.tempo or 120) + 0.5)); u8(0) -- (the tempo; shown)
  u8(0); i32(0) -- (key C, octave)
  -- the 64 MIDI channels: track t plays on channel 2t - 1 (its effect channel 2t)
  for c = 1, 64 do
    local tr = tracks[(c + 1) // 2]
    i32(tr and tr.program or 25); u8(13); u8(8); zeros(4); zeros(2) -- (program; volume, balance, effects off)
  end
  for _ = 1, 19 do i16(-1) end -- (no directions: coda, segno ...)
  i32(0) -- (the master reverb)
  i32(#bars); i32(#tracks)
  -- the bars: the time signature where it changes (beamed in 8ths)
  local num, den
  for k, bar in ipairs(bars) do
    if k > 1 then u8(0) end
    local f = (bar.num ~= num and 1 or 0) | (bar.den ~= den and 2 or 0)
    u8(f)
    if f & 1 ~= 0 then u8(bar.num) end
    if f & 2 ~= 0 then u8(bar.den) end
    if f & 3 ~= 0 then u8(2); u8(2); u8(2); u8(2) end
    u8(0); u8(0) -- (no alternate ending; no triplet feel)
    num, den = bar.num, bar.den
  end
  -- the tracks: visible, tab and notation, the strings from the highest
  for t, tr in ipairs(tracks) do
    if t == 1 then u8(0) end
    u8(0x08); bstr(tr.name or ("Track " .. t), 40)
    local n = #tr.open
    i32(n)
    for i = 1, 7 do i32(tr.open[n - i + 1] or 0) end
    i32(1); i32(2 * t - 1); i32(2 * t); i32(24); i32(0) -- (port, channel, effect channel, frets, capo)
    u8(255); u8(0); u8(0); u8(0) -- (red)
    i16(0x0003); u8(0); u8(0) -- (tab and notation; accents; bank)
    u8(0); zeros(12); zeros(12) -- (RSE: humanize ...)
    i32(-1); i32(1); i32(-1); i32(-1) -- (no RSE instrument)
    zeros(4); ibstr(""); ibstr("") -- (equalizer, effect, its category)
  end
  u8(0)
  -- the beats
  local function beat(v, trip, notes, tie, n, tempo)
    local f = (v.dot and 0x01 or 0) | (trip and 0x20 or 0) | (tempo and 0x10 or 0) | (notes and 0 or 0x40)
    u8(f)
    if not notes then u8(2) end -- (a rest)
    u8(v.d)
    if trip then i32(3) end
    if tempo then -- (a mix table with only a tempo change)
      u8(0xFF); i32(-1); i32(-1); i32(-1); i32(-1)
      for _ = 1, 6 do u8(0xFF) end
      ibstr(""); i32(math.floor(tempo + 0.5)); u8(0); u8(0)
      u8(0); u8(0xFF); ibstr(""); ibstr("") -- (applies to all tracks; no wah; no RSE effect)
    end
    local sf, list = 0, {}
    for _, nt in ipairs(notes or {}) do
      local gs = n - nt.s + 1 -- (1 = the highest string)
      if gs >= 1 and gs <= 7 and sf & (1 << (7 - gs)) == 0 then sf = sf | (1 << (7 - gs)); list[#list + 1] = { gs = gs, fret = nt.fret } end
    end
    table.sort(list, function(x, y) return x.gs < y.gs end)
    u8(sf)
    for _, nt in ipairs(list) do
      u8(0x20); u8(tie and 2 or 1); u8(math.max(0, math.min(99, nt.fret))); u8(0)
    end
    i16(0)
  end
  for _, bar in ipairs(bars) do
    for t, tr in ipairs(tracks) do
      local n, beats, tempo = #tr.open, {}, t == 1 and bar.tempo or nil
      for _, e in ipairs(bar.tracks and bar.tracks[t] or {}) do
        local notes = e.notes and e.notes[1] and e.notes or nil
        for k, v in ipairs(GP.values(e.trip and e.len * 1.5 or e.len)) do
          beats[#beats + 1] = { v = v, trip = e.trip, notes = notes, tie = notes and (k > 1 or e.tie) }
        end
      end
      if not beats[1] then -- (an empty bar: 1 rest over the whole bar)
        for _, v in ipairs(GP.values(4 * bar.num / bar.den)) do beats[#beats + 1] = { v = v } end
      end
      i32(#beats)
      for k, x in ipairs(beats) do beat(x.v, x.trip, x.notes, x.tie, n, k == 1 and tempo or nil) end
      i32(0) -- (voice 2: empty)
      u8(0) -- (no line break)
    end
  end
  return table.concat(b)
end

return GP
