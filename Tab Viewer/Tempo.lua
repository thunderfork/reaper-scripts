-- @noindex
-- Tempo: Find tempo (find the tempo of a song from a track or from the tab, put REAPER's bars on it). Used by Tab
-- Viewer (its Find tempo, and the Detection tab); ReaPack installs it next to the script (@provides).
--   local TP = dofile(<folder> .. "Tempo.lua")
--   local Tempo = TP.new(host)  -- host: see TP.new
-- Moved from Note Detective (23 November 2026, segment 2d; the tab part, Tempo.from_tab / Beat.tab_plan, came with
-- 2e); its tests are in tests\notes.lua and tests\tabviewer.lua.

local r = reaper
local TP = { Beat = {} }
local Beat = TP.Beat

TP.CFG = {
  SR = 4000, HOP = 40,          -- the audio is read at 4000 Hz; 1 value of the attack curve every 10 ms
  STEP = 0.025,                 -- s of work per frame while Find tempo runs
  ON_GATE = 35,                 -- dB: the first sound is not this far below the loud parts (TP.first_sound)
  ALIGN_SCAN = 90,              -- s: Set tempo looks this far into the song item for its first sound
  BPM_MIN = 60, BPM_MAX = 200,  -- the tempos that Find tempo tries
  BPM_LO = 90, BPM_HI = 180,    -- a found tempo outside is doubled or halved (the Tempo dropdown corrects it)
  BPM_BAR = 0.15,               -- "Follow the song": a bar this far from the song tempo is a wrong beat (the song tempo)
  STEADY = 0.03,                -- s: 9 of 10 beats this close to 1 straight grid: a steady song ("1 tempo")
  PRE_MIN = 0.5,                -- of a beat: a shorter bar before beat 1 (or after the song) joins the bar before it
}
local CFG = TP.CFG

---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------
-- A time as "1:02.4".
function TP.time(t)
  t = math.floor(math.max(0, t) * 10 + 0.5) / 10
  return string.format("%d:%04.1f", math.floor(t / 60), t % 60)
end
-- A track name of a metronome ("Metronome", "Click"; not "Clicks").
function TP.is_click(name)
  local low = (name or ""):lower()
  return low:find("metronome", 1, true) ~= nil or low:match("%f[%a]click%f[%A]") ~= nil
end
-- The item with this GUID (nil: none). An undo makes new item pointers, so a kept item is kept by its GUID.
function TP.item_by_guid(proj, guid)
  if (guid or "") == "" then return nil end
  local it = r.BR_GetMediaItemByGUID and r.BR_GetMediaItemByGUID(proj, guid)
  if it then return it end
  for i = 0, r.CountMediaItems(proj) - 1 do
    local item = r.GetMediaItem(proj, i)
    local _, g = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
    if g == guid then return item end
  end
end

-- Reads the mono samples of a take at CFG.SR, block by block (TP.read_block). Never inside a coroutine:
-- reaper.array and GetAudioAccessorSamples give silence there. off: the first second of the item that is read.
function TP.reader(take, len, off)
  return { acc = r.CreateTakeAudioAccessor(take), n = math.floor(len * CFG.SR), i = 0, x = {}, buf = r.new_array(16000),
    off = off or 0 }
end
function TP.read_block(rd) -- true when all is read
  local c = math.min(8000, rd.n - rd.i)
  if c > 0 then
    rd.buf.clear()
    r.GetAudioAccessorSamples(rd.acc, CFG.SR, 2, rd.off + rd.i / CFG.SR, c, rd.buf)
    local v, x, i = rd.buf.table(1, c * 2), rd.x, rd.i
    for k = 1, c do x[i + k] = (v[2 * k - 1] + v[2 * k]) * 0.5 end
    rd.i = i + c
  end
  if rd.i < rd.n then return false end
  TP.close(rd)
  return true
end
function TP.close(rd)
  if rd and rd.acc then r.DestroyAudioAccessor(rd.acc); rd.acc = nil end
end

-- The time (s) of the first sound of x (sr) that is not noise: the first 10 ms with a level less than CFG.ON_GATE dB
-- below the loud parts (the 95th percentile). For Set tempo without a list: more sure than the first pluck (song 2:
-- the first pluck missed the first note). nil: silence.
function TP.first_sound(x, sr)
  local n, lv, sorted = math.max(1, math.floor(sr * 0.01)), {}, {}
  for s = 1, #x - n + 1, n do
    local e = 0
    for i = s, s + n - 1 do e = e + x[i] * x[i] end
    lv[#lv + 1] = 10 * math.log(e / n + 1e-12, 10)
    if lv[#lv] > -100 then sorted[#sorted + 1] = lv[#lv] end
  end
  if #sorted == 0 then return nil end
  table.sort(sorted)
  local quiet = sorted[math.max(1, math.floor(#sorted * 0.95))] - CFG.ON_GATE
  for k, v in ipairs(lv) do if v > quiet then return (k - 1) * n / sr end end
end
-- The first sound of an audio item (its first CFG.ALIGN_SCAN s), project time; nil: none.
function TP.first_sound_of(item)
  local take = item and r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return nil end
  local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local rd = TP.reader(take, math.min(CFG.ALIGN_SCAN, r.GetMediaItemInfo_Value(item, "D_LENGTH")))
  while not TP.read_block(rd) do end
  local t = TP.first_sound(rd.x, CFG.SR)
  return t and pos + t
end

---------------------------------------------------------------------------
-- BEAT (the tempo, the beats and the bars of a song; plain functions without REAPER, so the tests reach them)
---------------------------------------------------------------------------
-- The attack curve: 1 value every 10 ms, the rise of the level of the plain signal and of its difference (the
-- bright attacks). Value k is at (k - 1) * HOP / SR + Beat.F0 s.
Beat.F0 = 0.01
function Beat.onset(x, tick)
  local env, pa, pb, H = {}, nil, nil, CFG.HOP
  for s = 1, #x - 4 * H, H do
    local a, b = 0, 0
    for i = s, s + 2 * H - 1 do
      local v = x[i]
      local d = x[i + 1] - v
      a, b = a + v * v, b + d * d
    end
    a, b = math.log(a + 1e-4), math.log(b + 1e-4)
    env[#env + 1] = (pa and math.max(0, a - pa) or 0) + (pb and math.max(0, b - pb) or 0)
    pa, pb = a, b
    if tick and #env % 500 == 0 then tick(0.2 * s / #x) end
  end
  return env
end

-- How strongly the attacks of the values a..b repeat at a tempo, and at its double (8th notes).
function Beat.strength(env, mean, bpm, a, b)
  local w = 2 * math.pi * bpm / 60 / (CFG.SR / CFG.HOP)
  local cw, sw = math.cos(w), math.sin(w)
  local co, si = math.cos(w * a), math.sin(w * a)
  local c, s, c2, s2 = 0, 0, 0, 0
  for i = a, b do
    local v = env[i] - mean
    c, s = c + v * co, s + v * si
    c2, s2 = c2 + v * (co * co - si * si), s2 + v * 2 * co * si
    co, si = co * cw - si * sw, si * cw + co * sw
  end
  return math.sqrt(c * c + s * s) + 0.5 * math.sqrt(c2 * c2 + s2 * s2)
end

-- The tempo of the attack curve (BPM, from CFG.BPM_LO to CFG.BPM_HI); nil when it is shorter than 4 s.
function Beat.tempo(env, tick)
  local n = #env
  if n < 400 then return nil end
  local mean = 0
  for i = 1, n do mean = mean + env[i] end
  mean = mean / n
  local best, bs = CFG.BPM_MIN, -1
  local steps = math.floor((CFG.BPM_MAX - CFG.BPM_MIN) / 0.25)
  for k = 0, steps do
    local bpm = CFG.BPM_MIN + k * 0.25
    local s = Beat.strength(env, mean, bpm, 1, n)
    if s > bs then best, bs = bpm, s end
    if tick then tick(0.2 + 0.6 * k / steps) end
  end
  local base = best
  for k = -50, 50 do
    local bpm = base + k * 0.01
    local s = Beat.strength(env, mean, bpm, 1, n)
    if s > bs then best, bs = bpm, s end
  end
  while best < CFG.BPM_LO do best = best * 2 end
  while best > CFG.BPM_HI do best = best / 2 end
  return best
end

-- The beats at a tempo (s, from the first value): the strongest attacks about 1 beat apart (dynamic programming).
function Beat.track(env, bpm, tick)
  local per = 60 / bpm * CFG.SR / CFG.HOP
  local n, score, back = #env, {}, {}
  for i = 1, n do
    local bv, bj = 0, nil
    for j = math.max(1, math.floor(i - per * 1.15)), math.floor(i - per * 0.85) do
      local l = math.log((i - j) / per)
      local v = score[j] - 400 * l * l
      if v > bv then bv, bj = v, j end
    end
    score[i], back[i] = env[i] + 0.5 * ((env[i - 1] or 0) + (env[i + 1] or 0)) + bv, bj
    if tick and i % 2000 == 0 then tick(0.8 + 0.2 * i / n) end
  end
  local e, ev = nil, -1
  for i = math.max(1, n - math.floor(2 * per)), n do if score[i] > ev then e, ev = i, score[i] end end
  local rev = {}
  while e do rev[#rev + 1] = (e - 1) * CFG.HOP / CFG.SR + Beat.F0; e = back[e] end
  local beats = {}
  for i = #rev, 1, -1 do beats[#beats + 1] = rev[i] end
  return beats
end

-- The straight grid through the beats from i0: its start, its beat length, and how far 9 of 10 beats are from it.
function Beat.fit(beats, i0)
  local n = #beats - i0 + 1
  if n < 2 then return beats[i0] or 0, 0.5, 0 end
  local sk, st, skk, skt = 0, 0, 0, 0
  for k = 0, n - 1 do
    local t = beats[i0 + k]
    sk, st, skk, skt = sk + k, st + t, skk + k * k, skt + k * t
  end
  local p = (n * skt - sk * st) / (n * skk - sk * sk)
  if not (p > 0) then p = 0.5 end
  local a = (st - p * sk) / n
  local res = {}
  for k = 0, n - 1 do res[k + 1] = math.abs(beats[i0 + k] - (a + p * k)) end
  table.sort(res)
  return a, p, res[math.max(1, math.floor(0.9 * n))]
end

-- The beat of bar 1: the first beat with sound (the user checks it). Right on the 2 real songs of the trials
-- (23 November 2026; the strongest of the 4 places in a bar was 1 beat late on both).
function Beat.bar1(beats, env)
  local str, sorted = {}, {}
  for k, t in ipairs(beats) do
    local f = math.floor((t - Beat.F0) * CFG.SR / CFG.HOP + 1.5)
    local m = 0
    for j = f - 2, f + 2 do m = math.max(m, env[j] or 0) end
    str[k], sorted[k] = m, m
  end
  if #beats == 0 then return 1 end
  table.sort(sorted)
  local med, first = sorted[#sorted // 2 + 1], 1
  while str[first] and str[first] < 0.5 * med do first = first + 1 end
  return first > #beats and 1 or first
end

-- A tempo as Set tempo writes it: at most 1 decimal place (159.875 BPM helps no one: the user, 26 November 2026).
function Beat.round(bpm) return math.floor(bpm * 10 + 0.5) / 10 end
-- A tempo as the window shows it: "160 BPM", "159.9 BPM".
function TP.bpm_text(bpm)
  local b = Beat.round(bpm)
  return b == math.floor(b) and string.format("%d BPM", math.floor(b)) or string.format("%.1f BPM", b)
end

-- The tempo markers of the song from bar 1 until t_end, bars of 4 beats (no short bars: the user, 26 November 2026):
-- { { t, bpm, num (4 on the first, then 0: the same), bar (0 = bar 1) } }, the bar line after the song, and the number
-- of bars. style "steady": 1 tempo (the straight grid of the beats);
-- "follow": 1 marker per bar, on the beats (a bar far from the song tempo is a wrong beat: it gets the song tempo).
-- Every tempo has at most 1 decimal place (Beat.round): "steady" fits the start of its grid again for the rounded
-- tempo; in "follow" a bar ends a little off its beat (under 1 ms) and the next bar starts there, so the errors do
-- not add up.
function Beat.plan(beats, i0, style, t_end)
  local a, p = Beat.fit(beats, i0)
  local base = Beat.round(60 / p)
  p = 60 / base
  if style ~= "follow" and beats[i0] then -- (the start of the straight grid with the rounded beat length)
    local s, k = 0, 0
    for j = i0, #beats do s = s + beats[j] - (j - i0) * p; k = k + 1 end
    a = s / k
  end
  local m, i, num, bar = {}, i0, 0, 0
  local t = style == "follow" and beats[i0] or a
  while (t < t_end - 1e-9 or #m == 0) and bar < 5000 do
    local n = 4
    local bpm, nxt = base, nil
    if style == "follow" then
      local b = beats[i + n]
      if b and math.abs(60 * n / (b - t) / base - 1) <= CFG.BPM_BAR then bpm = Beat.round(60 * n / (b - t)) end
      nxt = t + 60 * n / bpm
    else
      nxt = a + (i + n - i0) * p
    end
    if style == "follow" or n ~= num then
      m[#m + 1] = { t = t, bpm = bpm, num = n ~= num and n or 0, bar = bar }
    end
    num, i, t, bar = n, i + n, nxt, bar + 1
  end
  return m, t, bar
end

-- The tempo markers of a tab (bars: GP.timeline) with its bar 1 at t0, the same shape as Beat.plan: { { t, bpm, num
-- (0: the same as before), den, bar (0 = bar 1), beat (in the bar, in beats of den; a change inside a bar) } }, the
-- time after the last bar, the number of bars. A marker only where the tempo or the time signature changes.
function Beat.tab_plan(bars, t0)
  local m, t, bpm, num, den = {}, t0, nil, 0, 0
  for k, b in ipairs(bars) do
    local q, sig = 0, b.num ~= num or b.den ~= den
    local function upto(q1) -- (the time of the bar from q to q1 at the tempo of now)
      t, q = t + (q1 - q) * 60 / bpm, q1
    end
    local first = b.tempos[1] and b.tempos[1].q < 1e-6
    if sig or first then
      if first then bpm = b.tempos[1].bpm end
      m[#m + 1] = { t = t, bpm = bpm, num = sig and b.num or 0, den = b.den, bar = k - 1, beat = 0 }
    end
    for i, x in ipairs(b.tempos) do
      if not (i == 1 and first) and x.q < b.len - 1e-9 then
        upto(x.q)
        bpm = x.bpm
        m[#m + 1] = { t = t, bpm = bpm, num = 0, den = b.den, bar = k - 1, beat = x.q * b.den / 4 }
      end
    end
    upto(b.len)
    num, den = b.num, b.den
  end
  return m, t, #bars
end
-- The time from bar 1 of a tab to the quarter note qn of it (bars: GP.timeline).
function Beat.tab_time(bars, qn)
  local m = Beat.tab_plan(bars, 0)
  local q0, k, t = 0, 1, 0
  for _, b in ipairs(bars) do
    if q0 + b.len > qn then break end
    q0, k = q0 + b.len, k + 1
  end
  for _, x in ipairs(m) do -- (the last marker before the place: its time and tempo go on to the place)
    local xq = 0
    for j = 1, x.bar do xq = xq + bars[j].len end
    xq = xq + x.beat * 4 / x.den
    if xq > qn + 1e-9 then break end
    t = x.t + (qn - xq) * 60 / x.bpm
  end
  return t
end

-- A bar between 2 fixed times, at about this beat length: its beats and its tempo (exact, not Beat.round: the bars
-- before bar 1 and after the song must end on the old bar lines, or the song and the songs after it move).
function Beat.fit_bar(t0, t1, beat)
  local n = math.max(1, math.floor((t1 - t0) / beat + 0.5))
  return n, 60 * n / (t1 - t0)
end

---------------------------------------------------------------------------
-- TEMPO (Find tempo reads a track in steps, or takes the tempo of the tab; Set tempo writes the tempo map of the song)
---------------------------------------------------------------------------
-- Find tempo of a script. host: { R (its runtime table: R.proj, and the state R.tempo, R.tsrc, R.tsrc_sel live
-- there), name ("Tab Viewer"), notice(text, warn),
-- song() (the item of the song, its start, its end; or nil and why), first_note(tm) (the time of the first note of the
-- song, or nil: then the first sound of the song item), shift(d, tm) (the audio moved d s), written() (after each tempo
-- write), set_extra(d) (more text for the Set tempo notice) }.
-- Returns the functions of the section (Tempo.begin, Tempo.step, Tempo.set ...).
function TP.new(host)
  local R = host.R
  local Tempo = {}

  -- The tracks to listen to (the Find tempo menu): { { tr, label } }: metronome tracks first, then drums, then the other tracks with items.
  function Tempo.sources()
    if R.tsrc then return R.tsrc end
    local groups = { {}, {}, {} }
    for i = 0, r.CountTracks(R.proj) - 1 do
      local tr = r.GetTrack(R.proj, i)
      if r.CountTrackMediaItems(tr) > 0 then
        local _, name = r.GetTrackName(tr)
        local low = name:lower()
        local g = TP.is_click(name) and 1 or (low:find("drum", 1, true) or low:find("kit", 1, true)
          or low:find("perc", 1, true)) and 2 or 3
        local list = groups[g]
        list[#list + 1] = { tr = tr, label = string.format("%d: %s", i + 1, name) }
      end
    end
    local all = {}
    for _, list in ipairs(groups) do for _, e in ipairs(list) do all[#all + 1] = e end end
    R.tsrc = all
    return all
  end
  -- The chosen track to listen to (the first one until the user picks one).
  function Tempo.source()
    local all = Tempo.sources()
    for _, e in ipairs(all) do if e.tr == R.tsrc_sel then return e end end
    return all[1]
  end

  -- The audio item of a track that plays the longest between t0 and t1.
  function Tempo.item_on(tr, t0, t1)
    local best, bo = nil, 0
    for i = 0, r.CountTrackMediaItems(tr) - 1 do
      local it = r.GetTrackMediaItem(tr, i)
      local p = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local o = math.min(t1, p + r.GetMediaItemInfo_Value(it, "D_LENGTH")) - math.max(t0, p)
      local tk = r.GetActiveTake(it)
      if tk and not r.TakeIsMIDI(tk) and o > bo then best, bo = it, o end
    end
    return best
  end

  -- Find tempo: reads the part of the track that plays with the song (in steps: Tempo.step).
  function Tempo.begin(tr)
    local song, t0, t1 = host.song()
    if not song then host.notice(t0, true); return end
    local it = tr and r.ValidatePtr2(R.proj, tr, "MediaTrack*") and Tempo.item_on(tr, t0, t1)
    if not it then host.notice("That track has no audio while the song plays. Pick another track.", true); return end
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local a, b = math.max(t0, pos), math.min(t1, pos + r.GetMediaItemInfo_Value(it, "D_LENGTH"))
    Tempo.cancel()
    local _, guid = r.GetSetMediaItemInfo_String(song, "GUID", "", false)
    R.tempo = { song = { guid = guid, t0 = t0, t1 = t1 },
      run = { item = it, f0 = a, done = 0, rd = TP.reader(r.GetActiveTake(it), b - a, a - pos) } }
  end
  -- false when the song or the read item is gone: Find tempo stops, the result goes.
  function Tempo.check()
    local tm = R.tempo
    if not tm then return false end
    local run = tm.run
    if not TP.item_by_guid(R.proj, tm.song.guid) or (run and not r.ValidatePtr2(R.proj, run.item, "MediaItem*")) then
      Tempo.cancel()
      R.tempo = nil
      return false
    end
    return true
  end
  function Tempo.step()
    local tm = R.tempo
    local run = tm and tm.run
    if not run or not Tempo.check() then return end
    run.stop = r.time_precise() + CFG.STEP
    while not run.co do -- (first the samples, then the beats: reaper.array gives silence inside a coroutine)
      if TP.read_block(run.rd) then
        run.co = coroutine.create(function()
          local function tick(v)
            run.done = 0.1 + 0.9 * v
            if r.time_precise() > run.stop then coroutine.yield() end
          end
          local env = Beat.onset(run.rd.x, tick)
          local bpm = Beat.tempo(env, tick)
          return env, bpm, bpm and Beat.track(env, bpm, tick)
        end)
      else
        run.done = 0.1 * run.rd.i / math.max(1, run.rd.n)
      end
      if r.time_precise() > run.stop then return end
    end
    local ok, env, bpm, beats = coroutine.resume(run.co)
    if not ok then Tempo.cancel(); host.notice("Find tempo stopped: " .. tostring(env), true); return end
    if coroutine.status(run.co) ~= "dead" then return end
    tm.run = nil
    if not bpm or #beats < 8 then
      R.tempo = nil
      host.notice("No tempo found: the song is too short, or the track is silent.", true)
      return
    end
    tm.env, tm.f0 = env, run.f0
    Tempo.set_beats(bpm, beats)
    host.notice(string.format("Tempo found: %s. Check Bar 1, then click Set tempo.", tm.lbl_bpm))
  end
  function Tempo.cancel()
    local tm = R.tempo
    if tm and tm.run then TP.close(tm.run.rd); tm.run = nil end
  end

  -- From the tab (Tab Viewer's "From tab"): no listening; the tempo, its changes and the time signatures of the tab (bars:
  -- GP.timeline). Bar 1 goes where the first note of the tab (qn: quarter notes from its start) meets the first sound
  -- of the song. Bar 1 (by beats) and Set tempo work as after Find tempo.
  function Tempo.from_tab(bars, qn)
    local song, t0, t1 = host.song()
    if not song then host.notice(t0, true); return end
    if not bars[1] then return end
    Tempo.cancel()
    local first = TP.first_sound_of(song) or t0
    local bar1 = first - Beat.tab_time(bars, qn or 0)
    local beat = 60 / bars[1].tempos[1].bpm
    while bar1 < 0 do bar1 = bar1 + beat end
    local _, guid = r.GetSetMediaItemInfo_String(song, "GUID", "", false)
    local beats, i0 = {}, 1
    for k = -32, 64 do -- (beats at the first tempo around bar 1: the < and > of Bar 1 move it by 1 of them)
      local t = bar1 + k * beat
      if t >= 0 then
        beats[#beats + 1] = t
        if k == 0 then i0 = #beats end
      end
    end
    local _, t_after = Beat.tab_plan(bars, bar1)
    R.tempo = { song = { guid = guid, t0 = t0, t1 = math.max(t1, t_after) }, tab = bars, beats = beats, i0 = i0,
      bpm = bars[1].tempos[1].bpm, steady = true, style = "tab" }
    Tempo.labels()
    host.notice(string.format("Tempo of the tab: %s. Check Bar 1, then click Set tempo.", R.tempo.lbl_bpm))
  end
  -- The tempo markers that Set tempo writes: Beat.plan, or Beat.tab_plan from the tab. Also the tempo before bar 1.
  function Tempo.plan()
    local tm = R.tempo
    if tm.tab then
      local m, t_after, nbars = Beat.tab_plan(tm.tab, tm.beats[tm.i0])
      return m, t_after, nbars, m[1].bpm
    end
    local m, t_after, nbars = Beat.plan(tm.beats, tm.i0, tm.style, tm.song.t1)
    local _, p = Beat.fit(tm.beats, tm.i0)
    return m, t_after, nbars, Beat.round(60 / p)
  end

  -- The found beats (s from the read start); bar 1 and the style start again.
  function Tempo.set_beats(bpm, rel)
    local tm = R.tempo
    tm.bpm, tm.beats = bpm, {}
    for k, t in ipairs(rel) do tm.beats[k] = t + tm.f0 end
    tm.i0 = Beat.bar1(rel, tm.env)
    local _, _, dev = Beat.fit(tm.beats, tm.i0)
    tm.steady = dev < CFG.STEADY
    tm.style = tm.steady and "steady" or "follow"
    Tempo.labels()
  end
  -- The Tempo dropdown: the found tempo (f 1), half (0.5) or double (2) of it: its beats again.
  function Tempo.scale(f)
    local tm = R.tempo
    local bpm = tm.bpm0 * f
    Tempo.set_beats(bpm, Beat.track(tm.env, bpm))
    tm.f = f
    Tempo.labels()
  end
  -- Bar 1 one beat earlier (-1) or later (1).
  function Tempo.nudge(d)
    local tm = R.tempo
    local i0 = math.max(1, math.min(#tm.beats, tm.i0 + d))
    if i0 == tm.i0 then return end
    tm.i0 = i0
    Tempo.labels()
  end
  function Tempo.set_style(style)
    R.tempo.style = style
    Tempo.labels()
  end

  -- The texts of the section (made after a change, not every frame): lbl_bpm, lbl_bar1, lbl_note (the grey line: the
  -- tab's tempo changes, or why the Style is suggested), choices (the Tempo dropdown: { { f, lbl } }).
  function Tempo.labels()
    local tm = R.tempo
    tm.lbl_bar1 = TP.time(tm.beats[tm.i0])
    if tm.tab then
      local n = 0
      for _, b in ipairs(tm.tab) do n = n + #b.tempos end
      tm.lbl_bpm = TP.bpm_text(tm.bpm)
      tm.lbl_note = n > 1 and string.format("The tab has %d tempo changes; Set tempo writes them too.", n - 1) or nil
      return
    end
    local _, p = Beat.fit(tm.beats, tm.i0)
    tm.lbl_bpm = TP.bpm_text(60 / p) -- (what Set tempo writes)
    tm.bpm0, tm.f = tm.bpm0 or tm.bpm, tm.f or 1
    tm.choices = { { f = 1, lbl = TP.bpm_text(tm.bpm0) .. " (found)" } }
    if tm.bpm0 >= CFG.BPM_MIN then tm.choices[#tm.choices + 1] = { f = 0.5, lbl = TP.bpm_text(tm.bpm0 / 2) .. " (half)" } end
    if tm.bpm0 <= CFG.BPM_MAX then tm.choices[#tm.choices + 1] = { f = 2, lbl = TP.bpm_text(tm.bpm0 * 2) .. " (double)" } end
    for _, c in ipairs(tm.choices) do if c.f == tm.f then tm.lbl_choice = c.lbl end end
    local m = Beat.plan(tm.beats, tm.i0, "follow", tm.song.t1)
    local bpms = {}
    for k, x in ipairs(m) do bpms[k] = x.bpm end
    table.sort(bpms)
    local lo, hi = bpms[math.max(1, math.floor(0.1 * #bpms))], bpms[math.max(1, math.ceil(0.9 * #bpms))]
    tm.lbl_note = tm.steady and "Suggested: 1 tempo (the beats stay on 1 steady grid)."
      or string.format("Suggested: Follow the song (it drifts %.0f-%.0f BPM).", lo, hi)
  end

  -- Holds the rest of the project in place while the tempo changes: the items go to time mode for a moment, the
  -- markers, regions and envelope points come back at their times (REAPER's default timebase is beats).
  function Tempo.hold()
    local h, proj = { items = {}, marks = {}, env = {} }, R.proj
    for i = 0, r.CountMediaItems(proj) - 1 do
      local it = r.GetMediaItem(proj, i)
      h.items[#h.items + 1] = { it, r.GetMediaItemInfo_Value(it, "C_BEATATTACHMODE") }
      r.SetMediaItemInfo_Value(it, "C_BEATATTACHMODE", 0)
    end
    local i = 0
    while true do
      local n, rgn, pos, e, name, num, color = r.EnumProjectMarkers3(proj, i)
      if n == 0 then break end
      h.marks[#h.marks + 1] = { rgn = rgn, pos = pos, e = e, name = name, num = num, color = color }
      i = i + 1
    end
    local nt = r.CountTracks(proj)
    for k = 0, nt do -- (k = nt: the master track)
      local tr = k < nt and r.GetTrack(proj, k) or r.GetMasterTrack(proj)
      for e = 0, r.CountTrackEnvelopes(tr) - 1 do
        local env = r.GetTrackEnvelope(tr, e)
        local _, ename = r.GetEnvelopeName(env)
        if ename ~= "Tempo map" and r.CountEnvelopePoints(env) > 0 then
          local pts = {}
          for p = 0, r.CountEnvelopePoints(env) - 1 do pts[p + 1] = { r.GetEnvelopePoint(env, p) } end
          h.env[#h.env + 1] = { env = env, pts = pts }
        end
      end
    end
    return h
  end
  function Tempo.release(h)
    for _, x in ipairs(h.items) do
      if r.ValidatePtr2(R.proj, x[1], "MediaItem*") then r.SetMediaItemInfo_Value(x[1], "C_BEATATTACHMODE", x[2]) end
    end
    for _, mk in ipairs(h.marks) do
      r.SetProjectMarker4(R.proj, mk.num, mk.rgn, mk.pos, mk.e, mk.name, mk.color, mk.name == "" and 1 or 0)
    end
    for _, e in ipairs(h.env) do
      if r.CountEnvelopePoints(e.env) == #e.pts then
        for p, pt in ipairs(e.pts) do r.SetEnvelopePoint(e.env, p - 1, pt[2], pt[3], pt[4], pt[5], pt[6], true) end
        r.Envelope_SortPoints(e.env)
      end
    end
  end

  -- The measure that starts at a bar line t (a time a little before or after it counts too).
  function Tempo.measure_at(t)
    local beat, m, cml = r.TimeMap2_timeToBeats(R.proj, t)
    return beat > cml / 2 and m + 1 or m
  end
  -- The tempo markers of the song (m, from Beat.plan): whole bars at the song tempo (bpm) before bar 1, back to the
  -- start of the song item (t_item: the count-in has bars too), a bar before them that ends on the first of them, the
  -- song, then a bar up to the next bar line of the old grid, where the old tempo goes on. The old markers in between
  -- go; the ones after it come back at their times. The markers with a time signature are put by measure (REAPER moves
  -- them to a bar line).
  function Tempo.map(m, t_after, nbars, t_item, bpm)
    local proj, first, last = R.proj, m[1], m[#m]
    local beat0, beat1 = 60 / bpm, 60 / last.bpm
    local back = math.max(0, math.ceil((first.t - t_item) / (4 * beat0) - 1e-6))
    while back > 0 and first.t - back * 4 * beat0 < 0 do back = back - 1 end
    local t_start = first.t - back * 4 * beat0 -- (the first bar line of the song's tempo)
    local _, mb = r.TimeMap2_timeToBeats(proj, t_start)
    local tb = r.TimeMap2_beatsToTime(proj, 0, mb)
    if t_start - tb < CFG.PRE_MIN * beat0 and mb > 0 then mb = mb - 1; tb = r.TimeMap2_beatsToTime(proj, 0, mb) end
    local _, me = r.TimeMap2_timeToBeats(proj, t_after)
    local te = r.TimeMap2_beatsToTime(proj, 0, me + 1)
    if te - t_after < CFG.PRE_MIN * beat1 then te = r.TimeMap2_beatsToTime(proj, 0, me + 2) end
    local num_e, den_e, bpm_e = r.TimeMap_GetTimeSigAtTime(proj, te)
    local later = {}
    for k = r.CountTempoTimeSigMarkers(proj) - 1, 0, -1 do
      local _, t, _, _, bpm_k, num, den, lin = r.GetTempoTimeSigMarker(proj, k)
      if t >= tb - 1e-6 then
        if t >= te - 1e-6 then table.insert(later, 1, { t = t, bpm = bpm_k, num = num, den = den, lin = lin }) end
        r.DeleteTempoTimeSigMarker(proj, k)
      end
    end
    local function put(meas, b, num, den, beat)
      r.SetTempoTimeSigMarker(proj, -1, -1, meas, beat or 0, b, num, num > 0 and den or 0, false)
    end
    local m0 = mb -- (the measure of the first bar line of the song's tempo)
    if t_start - tb > 0.0625 then -- (closer: that bar line is the old one)
      local n, b = Beat.fit_bar(tb, t_start, beat0)
      put(mb, b, n, 4)
      m0 = mb + 1
    end
    if back > 0 then put(m0, 60 / beat0, 4, 4) end -- (the bars before bar 1: the song tempo)
    m0 = m0 + back -- (the measure of bar 1)
    for _, x in ipairs(m) do put(m0 + x.bar, x.bpm, x.num, x.den or 4, x.beat) end
    local n, b = Beat.fit_bar(t_after, te, beat1)
    put(m0 + nbars, b, n, 4)
    if not (later[1] and math.abs(later[1].t - te) < 1e-4) then put(m0 + nbars + 1, bpm_e, num_e, den_e) end
    for _, x in ipairs(later) do
      if x.num > 0 then
        r.SetTempoTimeSigMarker(proj, -1, -1, Tempo.measure_at(x.t), 0, x.bpm, x.num, x.den, x.lin)
      else
        r.SetTempoTimeSigMarker(proj, -1, x.t, -1, -1, x.bpm, 0, 0, x.lin)
      end
    end
  end

  -- Writes the tempo map of the song as 1 undo step. Returns the time of bar 1, and with align: the move of
  -- Tempo.align (s; nil: no first note found).
  function Tempo.write(undo_name, align)
    local tm = R.tempo
    local m, t_after, nbars, bpm = Tempo.plan()
    r.Undo_BeginBlock2(R.proj)
    r.PreventUIRefresh(1)
    local h = Tempo.hold()
    Tempo.map(m, t_after, nbars, tm.song.t0, bpm)
    Tempo.release(h)
    -- (from the tab: bar 1 is already where its first note meets the song; a note off the beat must stay there)
    local d = align and (tm.tab and 0 or Tempo.align()) or nil
    r.PreventUIRefresh(-1)
    r.UpdateTimeline()
    r.Undo_EndBlock2(R.proj, undo_name, -1)
    host.written()
    return m[1].t, d
  end

  -- The time of the first note of the song: the host's (Tab Viewer: the first found note of the Notes list), else the
  -- first sound of the song item. nil: none.
  function Tempo.first_note()
    local tm = R.tempo
    local item = TP.item_by_guid(R.proj, tm.song.guid)
    if not item then return nil end
    return host.first_note(tm) or TP.first_sound_of(item)
  end
  -- Set tempo, after the grid (decided 23 November 2026 by the user): the audio of the song moves so its first note
  -- sits exactly on the nearest beat. Every item that lies at least half inside the song moves (so a backing track of
  -- the whole set does not). Returns the move (s), or nil without a first note.
  function Tempo.align()
    local tm, proj = R.tempo, R.proj
    local tn = Tempo.first_note()
    if not tn then return nil end
    local beat, m, cml = r.TimeMap2_timeToBeats(proj, tn)
    local b = math.floor(beat + 0.5)
    local tb = b >= cml - 1e-9 and r.TimeMap2_beatsToTime(proj, 0, m + 1) or r.TimeMap2_beatsToTime(proj, b, m)
    local d = tb - tn
    if math.abs(d) < 0.0005 then return 0 end
    local t0, t1 = tm.song.t0, tm.song.t1
    for i = 0, r.CountMediaItems(proj) - 1 do
      local it = r.GetMediaItem(proj, i)
      local p, len = r.GetMediaItemInfo_Value(it, "D_POSITION"), r.GetMediaItemInfo_Value(it, "D_LENGTH")
      if math.min(p + len, t1) - math.max(p, t0) >= len / 2 then r.SetMediaItemInfo_Value(it, "D_POSITION", p + d) end
    end
    tm.song.t0, tm.song.t1 = t0 + d, t1 + d
    for k, t in ipairs(tm.beats) do tm.beats[k] = t + d end
    host.shift(d, tm)
    return d
  end

  -- Set tempo: the tempo map of the song for good (1 undo step). Returns the measure (from 0) of bar 1.
  function Tempo.set()
    local tm = R.tempo
    local t, d = Tempo.write(host.name .. ": set the tempo", true)
    local _, m = r.TimeMap2_timeToBeats(R.proj, t + 1e-6)
    local msg = string.format("Tempo set: %s, bar 1 of the song is bar %d.", tm.lbl_bpm, m + 1)
    if d and math.abs(d) >= 0.0005 then
      msg = msg .. string.format(" The audio moved %d ms %s: the first note is on the beat.", math.floor(math.abs(d) * 1000 + 0.5), d > 0 and "later" or "earlier")
    elseif not d then
      msg = msg .. " No first note found: the audio stays."
    end
    msg = msg .. " One Ctrl+Z takes it back."
    msg = msg .. host.set_extra(d)
    host.notice(msg)
    return m
  end

  return Tempo
end

return TP
