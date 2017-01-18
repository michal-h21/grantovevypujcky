#!/usr/bin/env texlua

local input = arg[1]
local output = arg[2] or "out"


local lfs = require "lfs"
local unicode = require "unicode"
local lower = unicode.utf8.lower

local function help()
  print("make_tex.lua <input> [<output dir>]")
  os.exit()
end

local function is_dir(name)
  if type(name)~="string" then return false end
  local cd = lfs.currentdir()
  local is = lfs.chdir(name) and true or false
  lfs.chdir(cd)
  return is
end

local function read_data(data)
  local data = data or ""
  local lines = data:explode("\n")
  if not lines then 
    return nil, "No records"
  end
  local records = {}
  local first_line = table.remove(lines, 1)
  local header = first_line:explode "\t"

  for _,line in ipairs(lines) do
    local rec = {}
    local r = line:explode "\t"
    for i, x in ipairs(r) do
      local key = header[i]
      rec[key] = x
    end
    records[#records+1] = rec
  end
  return records
end

local function make_authors(records)
  local authors = {}
  local records = records or {}
  for _,rec in ipairs(records) do
    local author_id = rec.id_ctenare
    local author = authors[author_id] or {}
    table.insert(author, rec)
    authors[author_id] = author
  end
  return authors
end

local function make_filename(id, author)
  print(id, author)
  local aut_id = lower(author:gsub("[%s%,]+", "_"))
  return aut_id .. "_".. id
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


local function make_tex(author, id, records)
end
  


local function make_files(authors) 
  for id, rec in pairs(authors) do
    local first = rec[1] or {}
    local id = first.id_ctenare
    local author = first.ctenar
    if author then
      local filename = make_filename(id, author)
      -- print(filename, #rec)
    end
  end
end

if not input then
  print "Chybí vstupní soubor"
  help()
elseif not is_dir(output) then
  print("Neexistující výstupní adresář: ".. output)
end

local datafile = io.open(input, "r")
local data = datafile:read("*all")
local records, msg = read_data(data)
if not records then
  print(msg)
  os.exit()
end
local authors = make_authors(records)
make_files(authors)

