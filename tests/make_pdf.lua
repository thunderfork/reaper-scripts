-- @noindex
-- Makes tests\test.pdf: 3 A4 pages with a big "Page N" and staff lines.
-- Run with the normal Lua (not REAPER):  lua tests\make_pdf.lua
local here = arg[0]:match("^(.*)[/\\]") or "."
local pages = 3
local objs = {}
local function add(s) objs[#objs + 1] = s; return #objs end

add("<< /Type /Catalog /Pages 2 0 R >>")
add("") -- pages object, filled below
add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")
local kids = {}
for p = 1, pages do
  local c = { "BT /F1 64 Tf 170 720 Td (Page " .. p .. ") Tj ET", "1 w" }
  for staff = 0, 7 do -- 8 staves of 5 lines
    local y = 620 - staff * 70
    for l = 0, 4 do c[#c + 1] = string.format("50 %d m 545 %d l S", y - l * 7, y - l * 7) end
  end
  local stream = table.concat(c, "\n")
  local cid = add("<< /Length " .. #stream .. " >>\nstream\n" .. stream .. "\nendstream")
  kids[#kids + 1] = add("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
    .. "/Resources << /Font << /F1 3 0 R >> >> /Contents " .. cid .. " 0 R >>") .. " 0 R"
end
objs[2] = "<< /Type /Pages /Kids [" .. table.concat(kids, " ") .. "] /Count " .. pages .. " >>"

local out, offs = { "%PDF-1.4\n" }, {}
local len = #out[1]
for i, o in ipairs(objs) do
  offs[i] = len
  local s = i .. " 0 obj\n" .. o .. "\nendobj\n"
  out[#out + 1] = s; len = len + #s
end
local xref = { "xref\n0 " .. (#objs + 1) .. "\n0000000000 65535 f \n" }
for i = 1, #objs do xref[#xref + 1] = string.format("%010d 00000 n \n", offs[i]) end
out[#out + 1] = table.concat(xref)
out[#out + 1] = "trailer\n<< /Size " .. (#objs + 1) .. " /Root 1 0 R >>\nstartxref\n" .. len .. "\n%%EOF\n"
local f = assert(io.open(here .. "/test.pdf", "wb"))
f:write(table.concat(out)); f:close()
