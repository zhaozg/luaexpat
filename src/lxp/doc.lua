-- luaexpat-utils
-- lxp.doc implements some useful things on LOM documents, such as returned by lxp.lom.parse.
-- In particular, it can convert LOM back into XML text, with optional pretty-printing control.
-- It's based on stanza.lua from Prosody (http://hg.prosody.im/trunk/file/4621c92d2368/util/stanza.lua)
--
-- Can be used as a lightweight one-stop-shop for simple XML processing; a simple XML parser is included
-- but the default is to use lxp.lom if it can be found.
--
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
--
-- classic Lua XML parser by Roberto Ierusalimschy.
-- modified to output LOM format.
-- http://lua-users.org/wiki/LuaXml
--
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local t_insert = table.insert
local t_concat = table.concat
local t_remove = table.remove
local s_match = string.match
local tostring = tostring
local setmetatable = setmetatable
local getmetatable = getmetatable
local pairs = pairs
local ipairs = ipairs
local type = type
local next = next
local unpack = unpack or table.unpack
local s_gsub = string.gsub
local s_find = string.find
local s_sub = string.sub
local pcall, require, io = pcall, require, io
local split
--module (...)
local _M = {}
local Doc = { __type = "doc" }
Doc.__index = Doc

--- create a new document node.
-- @param tag the tag name
-- @param attr optional attributes (table of name-value pairs)
function _M.new(tag, attr)
  local doc = { tag = tag, attr = attr or {}, last_add = {} }
  return setmetatable(doc, Doc)
end

-- injects an existing document already parsed
-- @param tdoc table containing the parsed document
function _M.build(tdoc)
  _M.walk(tdoc, false, function(_, d)
    setmetatable(d, Doc)
  end)
  return tdoc
end

--- parse an XML document.  By default, this uses lxp.lom.parse, but
-- falls back to basic_parse, or if use_basic is true
-- @param text_or_file  file or string representation
-- @param is_file whether text_or_file is a file name or not
-- @param use_basic do a basic parse
-- @return a parsed LOM document with the document metatatables set
-- @return nil, error the error can either be a file error or a parse error
function _M.parse(text_or_file, is_file, use_basic)
  local parser, status, lom
  if use_basic then
    parser = _M.basic_parse
  else
    status, lom = pcall(require, "lxp.lom")
    if not status then
      parser = _M.basic_parse
    else
      parser = lom.parse
    end
  end
  if is_file then
    local f, err = io.open(text_or_file)
    if not f then
      return nil, err
    end
    text_or_file = f:read("*a")
    f:close()
  end
  local doc, err = parser(text_or_file)
  if not doc then
    return nil, err
  end
  if lom then
    _M.walk(doc, false, function(_, d)
      setmetatable(d, Doc)
    end)
  end
  return doc
end

---- convenient function to add a document node, This updates the last inserted position.
-- @param tag a tag name
-- @param attrs optional set of attributes (name-string pairs)
function Doc:addtag(tag, attrs)
  local s = _M.new(tag, attrs);
  (self.last_add[#self.last_add] or self):add_direct_child(s)
  t_insert(self.last_add, s)
  return self
end

--- convenient function to add a text node.  This updates the last inserted position.
-- @param text a string
function Doc:text(text)
  (self.last_add[#self.last_add] or self):add_direct_child(text)
  return self
end

---- go up one level in a document
function Doc:up()
  t_remove(self.last_add)
  return self
end

function Doc:reset()
  local last_add = self.last_add
  for i = 1, #last_add do
    last_add[i] = nil
  end
  return self
end

--- append a child to a document directly.
-- @param child a child node (either text or a document)
function Doc:add_direct_child(child)
  t_insert(self, child)
end

--- append a child to a document at the last element added
-- @param child a child node (either text or a document)
function Doc:add_child(child)
  (self.last_add[#self.last_add] or self):add_direct_child(child)
  return self
end

--- function to create an element with a given tag name and a set of children.
-- @param tag a tag name
-- @param items either text or a table where the hash part is the attributes and the list part is the children.
function _M.elem(tag, items)
  local s = _M.new(tag)
  if type(items) == "string" then
    items = { items }
  end
  if _M.is_tag(items) then
    t_insert(s, items)
  elseif type(items) == "table" then
    for k, v in pairs(items) do
      if type(k) == "string" then
        s.attr[k] = v
        t_insert(s.attr, k)
      else
        s[k] = v
      end
    end
  end
  return s
end

--- given a list of names, return a number of element constructors.
-- @param list  a list of names, or a comma-separated string.
-- @usage local parent,children = doc.tags 'parent,children' <br>
--  doc = parent {child 'one', child 'two'}
function _M.tags(list)
  local ctors = {}
  if type(list) == "string" then
    list = split(list, ",")
  end
  for _, tag in ipairs(list) do
    local ctor = function(items)
      return _M.elem(tag, items)
    end
    t_insert(ctors, ctor)
  end
  return unpack(ctors)
end

local templ_cache = {}

local function is_data(data)
  return #data == 0 or type(data[1]) ~= "table"
end

local function prepare_data(data)
  -- a hack for ensuring that $1 maps to first element of data, etc.
  -- Either this or could change the gsub call just below.
  for i, v in ipairs(data) do
    data[tostring(i)] = v
  end
end

--- create a substituted copy of a document,
-- @param templ  may be a document or a string representation which will be parsed and cached
-- @param data  a table of name-value pairs or a list of such tables
-- @return an XML document
function Doc.subst(templ, data)
  if type(data) ~= "table" or not next(data) then
    return nil, "data must be a non-empty table"
  end
  if is_data(data) then
    prepare_data(data)
  end
  if type(templ) == "string" then
    if templ_cache[templ] then
      templ = templ_cache[templ]
    else
      local str, err = templ
      templ, err = _M.parse(str)
      if not templ then
        return nil, err
      end
      templ_cache[str] = templ
    end
  end
  local function _subst(item)
    return _M.clone(templ, function(s)
      return s:gsub("%$(%w+)", item)
    end)
  end
  if is_data(data) then
    return _subst(data)
  end
  local list = {}
  for _, item in ipairs(data) do
    prepare_data(item)
    t_insert(list, _subst(item))
  end
  if data.tag then
    list = _M.elem(data.tag, list)
  end
  return list
end

--- get the first child with a given tag name.
-- @param tag the tag name
function Doc:child_with_name(tag)
  for _, child in ipairs(self) do
    if child.tag == tag then
      return child
    end
  end
end

local _children_with_name
function _children_with_name(self, tag, list, recurse)
  for _, child in ipairs(self) do
    if type(child) == "table" then
      if child.tag == tag then
        t_insert(list, child)
      end
      if recurse then
        _children_with_name(child, tag, list, recurse)
      end
    end
  end
end

--- get all elements in a document that have a given tag.
-- @param tag a tag name
-- @param dont_recurse optionally only return the immediate children with this tag name
-- @return a list of elements
function Doc:get_elements_with_name(tag, dont_recurse)
  local res = {}
  _children_with_name(self, tag, res, not dont_recurse)
  return res
end

-- iterate over all children of a document node, including text nodes.
function Doc:children()
  local i = 0
  return function(a)
    i = i + 1
    return a[i]
  end, self, i
end

-- return the first child element of a node, if it exists.
function Doc:first_childtag()
  if #self == 0 then
    return
  end
  for _, t in ipairs(self) do
    if type(t) == "table" then
      return t
    end
  end
end

function Doc:matching_tags(tag, xmlns)
  xmlns = xmlns or self.attr.xmlns
  local tags = self
  local start_i, max_i = 1, #tags
  return function()
    for i = start_i, max_i do
      local v = tags[i]
      if (not tag or v.tag == tag) and (not xmlns or xmlns == v.attr.xmlns) then
        start_i = i + 1
        return v
      end
    end
  end,
    tags
end

--- iterate over all child elements of a document node.
function Doc:childtags()
  local i = 0
  return function(a)
    local v
    repeat
      i = i + 1
      v = self[i]
      if v and type(v) == "table" then
        return v
      end
    until not v
  end,
    self[1],
    i
end

--- visit child element  of a node and call a function, possibility modifying the document.
-- @param callback  a function passed the node (text or element). If it returns nil, that node will be removed.
-- If it returns a value, that will replace the current node.
function Doc:maptags(callback)
  local is_tag = _M.is_tag
  local i = 1
  while i <= #self do
    if is_tag(self[i]) then
      local ret = callback(self[i])
      if ret == nil then
        t_remove(self, i)
      else
        self[i] = ret
        i = i + 1
      end
    end
  end
  return self
end

local xml_escape
do
  local escape_table = { ["'"] = "&apos;", ['"'] = "&quot;", ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }
  function xml_escape(str)
    return (s_gsub(str, "['&<>\"]", escape_table))
  end
  _M.xml_escape = xml_escape
end

-- pretty printing
-- if indent, then put each new tag on its own line
-- if attr_indent, put each new attribute on its own line
local function _dostring(t, buf, self, xml_escape, parentns, idn, indent, attr_indent)
  local nsid = 0
  local tag = t.tag
  local lf, alf = "", " "
  if indent then
    lf = "\n" .. idn
  end
  if attr_indent then
    alf = "\n" .. idn .. attr_indent
  end
  t_insert(buf, lf .. "<" .. tag)
  for k, v in pairs(t.attr) do
    if type(k) ~= "number" then -- LOM attr table has list-like part
      if s_find(k, "\1", 1, true) then
        local ns, attrk = s_match(k, "^([^\1]*)\1?(.*)$")
        nsid = nsid + 1
        t_insert(
          buf,
          " xmlns:ns"
            .. nsid
            .. "='"
            .. xml_escape(ns)
            .. "' "
            .. "ns"
            .. nsid
            .. ":"
            .. attrk
            .. "='"
            .. xml_escape(v)
            .. "'"
        )
      elseif not (k == "xmlns" and v == parentns) then
        t_insert(buf, alf .. k .. "='" .. xml_escape(v) .. "'")
      end
    end
  end
  local len, has_children = #t
  if len == 0 then
    local out = "/>"
    if attr_indent then
      out = "\n" .. idn .. out
    end
    t_insert(buf, out)
  else
    t_insert(buf, ">")
    for n = 1, len do
      local child = t[n]
      if child.tag then
        self(child, buf, self, xml_escape, t.attr.xmlns, idn and idn .. indent, indent, attr_indent)
        has_children = true
      else -- text element
        t_insert(buf, xml_escape(child))
      end
    end
    t_insert(buf, (has_children and lf or "") .. "</" .. tag .. ">")
  end
end

---- pretty-print an XML document
--- @param idn an initial indent (indents are all strings)
--- @param indent an indent for each level
--- @param attr_indent if given, indent each attribute pair and put on a separate line
--- @return a string representation
function _M.tostring(t, idn, indent, attr_indent)
  local buf = {}
  _dostring(t, buf, _dostring, xml_escape, nil, idn, indent, attr_indent)
  return t_concat(buf)
end

Doc.__tostring = _M.tostring

--- get the full text value of an element
function Doc:get_text()
  local res = {}
  for _, el in ipairs(self) do
    if type(el) == "string" then
      t_insert(res, el)
    end
  end
  return t_concat(res)
end

--- make a copy of a document
-- @param doc the original document
-- @param strsubst an optional function for handling string copying which could do substitution, etc.
function _M.clone(doc, strsubst)
  local lookup_table = {}
  local function _copy(object)
    if type(object) ~= "table" then
      if strsubst and type(object) == "string" then
        return strsubst(object)
      else
        return object
      end
    elseif lookup_table[object] then
      return lookup_table[object]
    end
    local new_table = {}
    lookup_table[object] = new_table
    for index, value in pairs(object) do
      new_table[_copy(index)] = _copy(value) -- is cloning keys much use, hm?
    end
    return setmetatable(new_table, getmetatable(object))
  end

  return _copy(doc)
end

--- compare two documents.
-- @param t1 any value
-- @param t2 any value
function _M.compare(t1, t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then
    return false, "type mismatch"
  end
  if ty1 == "string" then
    return t1 == t2 and true or "text " .. t1 .. " ~= text " .. t2
  end
  if ty1 ~= "table" or ty2 ~= "table" then
    return false, "not a document"
  end
  if t1.tag ~= t2.tag then
    return false, "tag  " .. t1.tag .. " ~= tag " .. t2.tag
  end
  if #t1 ~= #t2 then
    return false, "size " .. #t1 .. " ~= size " .. #t2 .. " for tag " .. t1.tag
  end
  -- compare attributes
  for k, v in pairs(t1.attr) do
    if t2.attr[k] ~= v then
      return false, "mismatch attrib"
    end
  end
  for k, v in pairs(t2.attr) do
    if t1.attr[k] ~= v then
      return false, "mismatch attrib"
    end
  end
  -- compare children
  for i = 1, #t1 do
    local yes, err = _M.compare(t1[i], t2[i])
    if not yes then
      return err
    end
  end
  return true
end

--- is this value a document element?
-- @param d any value
function _M.is_tag(d)
  return type(d) == "table" and type(d.tag) == "string"
end

--- call the desired function recursively over the document.
-- @param depth_first  visit child notes first, then the current node
-- @param operation a function which will receive the current tag name and current node.
function _M.walk(doc, depth_first, operation)
  if not depth_first then
    operation(doc.tag, doc)
  end
  for _, d in ipairs(doc) do
    if _M.is_tag(d) then
      _M.walk(d, depth_first, operation)
    end
  end
  if depth_first then
    operation(doc.tag, doc)
  end
end

local escapes = { quot = '"', apos = "'", lt = "<", gt = ">", amp = "&" }
local function unescape(str)
  return (str:gsub("&(%a+);", escapes))
end

local function parseargs(s)
  local arg = {}
  s:gsub("([%w:]+)%s*=%s*([\"'])(.-)%2", function(w, _, a)
    arg[w] = unescape(a)
  end)
  return arg
end

--- Parse a simple XML document using a pure Lua parser based on Robero Ierusalimschy's original version.
-- @param s the XML document to be parsed.
-- @param all_text  if true, preserves all whitespace. Otherwise only text containing non-whitespace is included.
function _M.basic_parse(s, all_text)
  local stack = {}
  local top = {}
  t_insert(stack, top)
  local ni, c, label, xarg, empty
  local i, j = 1
  -- we're not interested in <?xml version="1.0"?>
  local _, istart = s_find(s, "^%s*<%?[^%?]+%?>%s*")
  if istart then
    i = istart + 1
  end
  while true do
    ni, j, c, label, xarg, empty = s_find(s, "<(%/?)([%w:%-_]+)(.-)(%/?)>", i)
    if not ni then
      break
    end
    local text = s_sub(s, i, ni - 1)
    if all_text or not s_find(text, "^%s*$") then
      t_insert(top, unescape(text))
    end
    if empty == "/" then -- empty element tag
      t_insert(top, setmetatable({ tag = label, attr = parseargs(xarg), empty = 1 }, Doc))
    elseif c == "" then -- start tag
      top = setmetatable({ tag = label, attr = parseargs(xarg) }, Doc)
      t_insert(stack, top) -- new level
    else -- end tag
      local toclose = t_remove(stack) -- remove top
      top = stack[#stack]
      if #stack < 1 then
        error("nothing to close with " .. label)
      end
      if toclose.tag ~= label then
        error("trying to close " .. toclose.tag .. " with " .. label)
      end
      t_insert(top, toclose)
    end
    i = j + 1
  end
  local text = s_sub(s, i)
  if all_text or not s_find(text, "^%s*$") then
    t_insert(stack[#stack], unescape(text))
  end
  if #stack > 1 then
    error("unclosed " .. stack[#stack].tag)
  end
  local res = stack[1]
  return type(res[1]) == "string" and res[2] or res[1]
end

local function empty(attr)
  return not attr or not next(attr)
end

local function is_text(s)
  return type(s) == "string"
end
local function is_element(d)
  return type(d) == "table" and d.tag ~= nil
end

-- returns the key,value pair from a table if it has exactly one entry
local function has_one_element(t)
  local key, value = next(t)
  if next(t, key) ~= nil then
    return false
  end
  return key, value
end

local function tostringn(d)
  return tostring(d):sub(1, 60)
end

local function append_capture(res, tbl)
  if not empty(tbl) then -- no point in capturing empty tables...
    local key
    if tbl._ then -- if $_ was set then it is meant as the top-level key for the captured table
      key = tbl._
      tbl._ = nil
      if empty(tbl) then
        return
      end
    end
    -- a table with only one pair {[0]=value} shall be reduced to that value
    local numkey, val = has_one_element(tbl)
    if numkey == 0 then
      tbl = val
    end
    if key then
      res[key] = tbl
    else -- otherwise, we append the captured table
      t_insert(res, tbl)
    end
  end
end

local function capture_attrib(res, pat, value)
  pat = pat:sub(2)
  if pat:find("^%d+$") then -- $1 etc means use this as an array location
    pat = tonumber(pat)
  end
  res[pat] = value
  return true
end

local match
function match(d, pat, res, keep_going)
  local ret = true
  if d == nil then
    d = ""
  end
  -- attribute string matching is straight equality, except if the pattern is a $ capture,
  -- which always succeeds.
  if type(d) == "string" then
    if type(pat) ~= "string" then
      return false
    end
    if pat:find("^%$") then
      return capture_attrib(res, pat, d)
    else
      return d == pat
    end
  else
    -- this is an element node. For a match to succeed, the attributes must
    -- match as well.
    if d.tag == pat.tag then
      if not empty(pat.attr) then
        if empty(d.attr) then
          ret = false
        else
          for prop, pval in pairs(pat.attr) do
            local dval = d.attr[prop]
            if not match(dval, pval, res) then
              ret = false
              break
            end
          end
        end
      end
      -- the pattern may have child nodes. We match partially, so that {P1,P2} shall match {X,P1,X,X,P2,..}
      if ret and #pat > 0 then
        local i, j = 1, 1
        local function next_elem()
          j = j + 1 -- next child element of data
          if is_text(d[j]) then
            j = j + 1
          end
          return j <= #d
        end
        repeat
          local p = pat[i]
          -- repeated {{<...>}} patterns  shall match one or more elements
          -- so e.g. {P+} will match {X,X,P,P,X,P,X,X,X}
          if is_element(p) and p.repeated then
            local found
            repeat
              local tbl = {}
              ret = match(d[j], p, tbl, false)
              if ret then
                found = false --true
                append_capture(res, tbl)
              end
            until not next_elem() or (found and not ret)
            i = i + 1
          else
            ret = match(d[j], p, res, false)
            if ret then
              i = i + 1
            end
          end
        until not next_elem() or i > #pat -- run out of elements or patterns to match
        -- if every element in our pattern matched ok, then it's been a successful match
        if i > #pat then
          return true
        end
      end
      if ret then
        return true
      end
    else
      ret = false
    end
    -- keep going anyway - look at the children!
    if keep_going then
      for child in d:childtags() do
        ret = match(child, pat, res, keep_going)
        if ret then
          break
        end
      end
    end
  end
  return ret
end

function Doc:match(pat)
  if is_text(pat) then
    pat = _M.parse(pat, false, true)
  end
  _M.walk(pat, false, function(_, d)
    if is_text(d[1]) and is_element(d[2]) and is_text(d[3]) and d[1]:find("%s*{{") and d[3]:find("}}%s*") then
      t_remove(d, 1)
      t_remove(d, 2)
      d[1].repeated = true
    end
  end)

  local res = {}
  local ret = match(self, pat, res, true)
  return res, ret
end

--- split a string into a list of strings separated by a delimiter.
function split(s, re)
  local res = {}
  re = "[^" .. re .. "]+"
  for k in s:gmatch(re) do
    t_insert(res, k)
  end
  return res
end

local function export(name, mod)
  local rawget, rawset = _G.rawget, _G.rawset
  if not rawget(_G, "__PRIVATE_REQUIRE") then
    local path = split(name, "%.")
    local T = _G
    for i = 1, #path - 1 do
      local p = rawget(T, path[i])
      if not p then
        p = {}
        rawset(T, path[i], p)
      end
      T = p
    end
    rawset(T, path[#path], mod)
  end
  return mod
end

return export(..., _M)
