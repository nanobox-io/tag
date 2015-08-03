-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Daniel Barney.
-- @doc
--
-- @end
-- Created :   1 July 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

exports.name = "pagodabox/redis-codec"
exports.version = "0.1.0"
exports.description = 
  "A set of functions to decode/encode the redis protocol"
exports.tags = {"redis","codec"}
exports.license = "MIT"
exports.deps = {}
exports.author =
    {name = "Daniel Barney"
    ,email = "daniel@pagodabox.com"}
exports.homepage = 
  "https://github.com/pagodabox/tag/blob/master/deps/redis-codec.lua"

function exports.decoder()
  local choose

  local function simple(data)
    local _, length = data:find('[^\r\n]+\r\n')
    if length ~= nil then
      return data:sub(2, length - 2), data:sub(length + 1)
    end
  end

  local function err(data)
    local string, rest = simple(data)
    if string ~= nil then
      error(string,0)
    end
  end

  local function integer(data)
    local string, rest = simple(data)
    if string ~= nil then
      return tonumber(string), rest
    end
  end

  local function bulk(data)
    local length, rest = integer(data)
    
    if length == -1 then
      return nil, rest:sub(3)
    elseif length ~= nil and #rest >= length + 2 then
      return rest:sub(1, length), rest:sub(length + 3)
    end
  end

  local function array(data)
    local count, rest = integer(data)
    if count ~= nil then
      local elems = {}
      while count > 0 do
        count = count - 1
        local elem
        elem, rest = choose(rest)
        if not rest then return end
        elems[#elems + 1] = elem
      end
      return elems, rest
    end
  end

  local function inline(data)
    local _, length = data:find('[^\r\n]+\r?\n')
    if length then
      local cmd = data:sub(1, length - 1)
      local parts = {}
      for match in cmd:gmatch('[^ ]+') do
        parts[#parts + 1] = match
      end
      return parts, data:sub(length + 1)
    end
  end

  local mappings = {}

  mappings[string.byte('+')] = simple
  mappings[string.byte('-')] = err
  mappings[string.byte(':')] = integer
  mappings[string.byte('$')] = bulk
  mappings[string.byte('*')] = array

  choose = function(data)
    if #data == 0 then return end
    local char = data:byte()
    local state = mappings[char]
    if not state then
      state = inline
    end
    return state(data)
  end

  return choose
end

local function pack_value(value)
  local t = type(value)
  if t == 'table' then
    -- support nil values
    local length = value.n or #value
    for i = 1, length do
      value[i] = pack_value(value[i])
    end
    return '*' .. tostring(length) .. '\r\n' .. table.concat(value)
  elseif t == 'string' then
    return '$' .. tostring(#value) .. '\r\n' .. value .. '\r\n'
  elseif t == 'number' then
    return ':' .. tostring(value) .. '\r\n'
  elseif t == 'nil' then
    return '$-1\r\n'
  elseif t == 'boolean' then
    return value and ':1\r\n' or ':0\r\n'
  else
    error('unknown type: ' .. t)
  end
end

local function pack(acc, ...)
  local count = 0
  for n=1, select('#', ...) do
    count = count + 1
    acc = acc .. pack_value(select(n, ...)) 
  end
  return acc, count
end

function exports.client_encoder()
  return function(...)
    local acc, count = pack('\r\n', ...)
    return '*' .. tostring(count) .. acc
  end
end

function exports.encoder()
  return pack_value
end