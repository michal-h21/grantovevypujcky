#!/usr/bin/env texlua

kpse.set_program_name "luatex"


local input = arg[1]
-- vždycky exportujeme do adresáře out
local output = "out" -- arg[2] or "out"
-- jméno čtenáře není v xlsx souboru, musíme specifikovat na command line
local ctenar = arg[2] 

-- id čtenáře není povinné
local id = arg[3] or "111"


local lfs = require "lfs"
local unicode = require "unicode"
local xlsx = require "spreadsheet-xlsx-reader"
local log = require "spreadsheet.spreadsheet-log"
local lower = unicode.utf8.lower

log.level = "warn"

local function help()
  print("xlsx_to_tex.lua <input> <jmeno_ctenare> [<id čtenáře>]")
  print("Výstupní soubor je v adresáři out")
  os.exit()
end

local function is_dir(name)
  if type(name)~="string" then return false end
  local cd = lfs.currentdir()
  local is = lfs.chdir(name) and true or false
  lfs.chdir(cd)
  return is
end

-- convert XLSX data to table
local function read_row(row)
  local data = {}
  for _, cell in ipairs(row) do
    local t = {}
    for _, x in ipairs(cell) do
      t[#t+1] = x.value
    end
    data[#data+1] = table.concat(t)
  end
  return data
end

local mapping = {
["Knihovna"] = "dilciknihovna",
["Termín vrácení"]="pujcenodo",
["Signatura jednotky"]="signatura",
[""]="ctenar",
[""]="idctenare",
["Titul"]="nazevautor",
["Datum výpůjčky"]="datumvypujcky",
["Status výpůjčky"]="status",
["Čárový kód"]="ck",
}


local function read_data(data, ctenar, id)
  local records = {}
  local lines = data.table or {}
  local first_line = read_row(table.remove(lines, 1) or {})
  local header = {}
  for i, column in ipairs(first_line) do
    local mapped_header = mapping[column]
    if mapped_header then
      header[i] = mapped_header 
    end
  end

  for _,line in ipairs(lines) do
    -- inicalizujeme záznam se jménem čtenáře a fake id
    local rec = {id_ctenare = id, ctenar = ctenar}
    local r = read_row(line)
    for i, x in ipairs(r) do
      local key = header[i]
      if key then
        rec[key] = x
      end
    end
    records[#records+1] = rec
  end
  return records
end

local function make_authors(records)
  local authors = {}
  local records = records or {}
  for _,rec in ipairs(records) do
    local author_id = rec.ctenar
    local author = authors[author_id] or {}
    table.insert(author, rec)
    authors[author_id] = author
  end
  return authors
end

local function make_filename(id, author)
  print(id, author)
  local aut_id = lower(author:gsub("[%s%,%/]+", "_"))
  return aut_id .. "_".. id .. ".tex"
end

local function escape(s)
  local escapes ={
    ["~"] = "textasciitilde",
    ["^"] = "textasciicircum",
    ['\\'] = "textbackslash"
  }
  return s:gsub('[&%%$#_{}~^\\]', function(a)
    local b = escapes[a] or a
    return '\\' .. b
  end)
end


local function make_tex(template,author, id, records)
  local r = {}
  -- projít všechny záznamy a vytvořit pro každej texový prostředí
  for _, x in ipairs(records) do
    local curr = {}
    -- projít jednotlivý políčka záznamu a vytvořit příkaz \nazevpolicka{obsah}
    for k,v in pairs(x) do
      -- jmeno prikazu nesmi obsahovat podtrzitko
      local command = k:gsub("_", "")
      curr[#curr+1] = string.format('\\%s{%s}', command, escape(v))
    end
    -- vlozit prostredi do pole k tisku
    r[#r+1] = string.format("\\begin{record}\n%s\n\\end{record}\n", table.concat(curr, "\n"))
  end
  local fields = {author = author , id = id, records = table.concat(r, "\n")}
  return template:gsub("%$(%w+)", fields)
end
  


local function make_files(authors, template) 
  for id, rec in pairs(authors) do
    local first = rec[1] or {}
    local id = first.id_ctenare
    local author = first.ctenar
    if author then
      local filename = make_filename(id, author) 
      local tex = make_tex(template,author, id, rec)
      print("Saving file: " .. output .."/" .. filename)
      local f = io.open(output .. "/" .. filename,"w")
      f:write(tex)
      f:close()
    end
  end
end

local template = [[
\documentclass{article}
\usepackage{grantovevypujcky}
\begin{document}
\autor{$author}
\id{$id}
\hlavicka
$records
\end{document}
]]
if not input then
  print "Chybí vstupní soubor"
  help()
elseif not is_dir(output) then
  print("Neexistující výstupní adresář: ".. output)
end



local workbook, msg = xlsx.load(input)
local sheet = workbook:get_sheet(1)
-- ToDo: a teď získat data

if not sheet then 
  print(msg)
  os.exit()
end

-- local datafile = io.open(input, "r")

-- local data = datafile:read("*all")
local records, msg = read_data(sheet, ctenar, id)
if not records then
  print(msg)
  os.exit()
end
local authors = make_authors(records)
make_files(authors, template)

