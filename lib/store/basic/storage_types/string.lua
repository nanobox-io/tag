-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   13 July 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local ffi = require('ffi')
local Txn = require('lmmdb').Txn

exports.cdef = [[
typedef struct {
  int len; // how long the string is
} string_t;
]]

exports.flags = 
  {get = Txn.MDB_RDONLY}

-- fetch a value from the database
function exports:get(txn, info)
  local header, string, value =
    self:resolve(txn, self.objects, info[2], 'header_t', 'string_t')
  if header then
    if header.type == 1 then
      return ffi.string(value, string.len)
    else
      local number = ffi.cast('number_t*', string)
      return tonumber(number.count)
    end
  end
end

-- enter a new bucket, key and value into the database, returns an
-- error or the update time of the data
function exports:set(txn, info)
  local key = info[2]
  local elem = info[3]
  local t = type(elem)
  if t == 'number' then
    local header, number = 
      assert(self:reserve(txn, self.objects, key, 'header_t', 'number_t'))
    self:update_time(txn, key)
    number.count = elem
    header.type = 'NUMBER'
  elseif t == 'boolean' then
    local header, number = 
      assert(self:reserve(txn, self.objects, key, 'header_t', 'number_t'))
    self:update_time(txn, key)
    number.count = elem and 1 or 0
    header.type = 'NUMBER'
  else
    local length = #elem
    local header, string, data = 
      assert(self:reserve(txn, self.objects, key, 'header_t', 'string_t', length))
    self:update_time(txn, key)
    ffi.copy(data, elem, length)
    string.len = length
    header.type = 'STRING'
  end
  return 'ok'
end

-- for name,fun in pairs(exports) do
--  exports[name] = function(self, txn, info)
--    if self:validate_type(txn, info, 'string_t') then
--      return fun(self, txn, info)
--    else
--      return false, 'Invalid type for command'
--    end
--  end
-- end