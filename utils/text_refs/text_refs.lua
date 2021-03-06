--[[
   text_refs.lua - Bookdown text references as pandoc lua filter

   Copyright (c) 2020 Joshua Krusell
   License: MIT
]]

PANDOC_VERSION:must_be_at_least '2.9.2'

refs = {}

function warn(txt)
   if PANDOC_STATE.verbosity == "INFO" or PANDOC_STATE.verbosity == "WARNING" then
      io.stderr:write("[WARNING] ", txt, "\n")
   end
end

local function replace(str, match, replacement)
   match = string.gsub(match, "[%%%]%^%-$().[*+?]", "%%%1")
   return string.gsub(str, match, replacement)
end

function find_ref(para)
   if para.c[1].t ~= "Str" then
      return para
   end

   local key = para.c[1].text
   if not string.match(key, "^%(ref:.-%)$") then
      return para
   else
      para.c:remove(1)
      if refs[key] then
         warn("Redefining text reference " .. key)
      end

      refs[key] = para.c:clone()

      return {}
   end
end

function Str_replace(elem)
   local i, j = string.find(elem.text, "%(ref:.-%)")
   if not i then
      return nil
   end

   local m = string.sub(elem.text, i, j)
   if not refs[m] then
      warn("Text reference " .. m .. " undefined")
      return nil
   end

   ll = refs[m]:clone()
   if i > 0 then
      local head = string.sub(elem.text, 1, i - 1)
      ll:insert(1, pandoc.Str(head))
   end

   if j < elem.text:len() then
      local tail = string.sub(elem.text, j + 1, elem.text:len())
      ll:insert(pandoc.Str(tail))
   end

   return ll
end

function RawBlock_replace(elem)
   local m = string.match(elem.text, "%(ref:.-%)")
   if m and refs[m] then
      elem.text = replace(elem.text, m, pandoc.utils.stringify(refs[m]))
   end

   return elem
end

return {
   { Para = find_ref },
   { Str = Str_replace,
     RawBlock = RawBlock_replace }
}
