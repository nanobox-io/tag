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
local db = require('lmmdb')
local Txn = db.Txn

exports.cdef = [[
typedef struct {
  long count; // value
} number_t;
]]

-- increment a value in the database
function exports:incr(txn, info, container_type, header_type)
  local key = info[2]
  local amount = tonumber(info[3] or 1)
  local struct = container_type or 'number_t'
  local type = header_type or 'NUMBER'
  local header, number =
    self:resolve(txn, self.objects, key, 'header_t', struct)
  if header then
    amount = number.count + amount
  else
    amount = amount
  end
  local new_header, new_number =
    assert(self:reserve(txn, self.objects, key, 'header_t', struct))
  if header then
    ffi.copy(new_header, header, ffi.sizeof('header_t') + ffi.sizeof(struct))
  else
    new_header.type = type
  end
  new_number.count = amount
  return true, tonumber(amount)
end

function exports.decr(self, txn, info, container_type, header_type)
  info[3] = (tonumber(info[3] or 1)) * -1
  return exports.incr(self, txn, info, container_type, header_type)
end