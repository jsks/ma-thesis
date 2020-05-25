-- Simple script that implements bookdown's text references as a lua
-- filter directly in pandoc.
--
-- https://bookdown.org/yihui/bookdown/markdown-extensions-by-bookdown.html#fn5

refs = {}

function warn(txt)
   if PANDOC_STATE.verbosity == "INFO" or PANDOC_STATE.verbosity == "WARNING" then
      io.stderr:write("[WARNING] " .. txt .. "\n")
   end
end

function find_ref(para)
   if para.c[1].t ~= "Str" then
      return para
   end

   key = para.c[1].text
   if not string.match(key, "^%(ref:.+%)$") then
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

function replace_ref(elem)
   local i, j = string.find(elem.text, "%(ref:.+%)")
   if not i then
      return nil
   end

   m = string.sub(elem.text, i, j)
   if not refs[m] then
      warn("Text reference " .. m .. " undefined")
      return nil
   end

   ll = refs[m]:clone()
   if i > 0 then
      start = string.sub(elem.text, 1, i - 1)
      ll:insert(1, pandoc.Str(start))
   end

   if j < elem.text:len() then
      stop = string.sub(elem.text, j + 1, elem.text:len())
      ll:insert(pandoc.Str(stop))
   end

   return ll
end

return {
   { Para = find_ref },
   { Str = replace_ref }
}
