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
local hrtime = require('uv').hrtime
local db = require('lmmdb')
local Txn = db.Txn
local Cursor = db.Cursor


exports.cdef = [[
typedef struct {
} hash_t;

typedef struct {
  int field_len; //length of the field
  int value_len; // length of the value
} hash_element_t;
]]

exports.flags = 
  {hmget = Txn.MDB_RDONLY
  ,hget = Txn.MDB_RDONLY
  ,hgetall = Txn.MDB_RDONLY}

function ensure_exists(self, txn, info)
  local key = info[2]
  local header, queue = self:resolve(txn, self.objects, key, 'header_t', 'hash_t')
  if not header then
    local new_header = assert(self:reserve(txn, self.objects, key, 'header_t', 'hash_t'))
    new_header.type = 'HASH'
  end
end

function exports:hset(txn, info)
  return exports.hmset(self, txn, info)
end

function exports:hmset(txn, info)
  local key = info[2]
  ensure_exists(self, txn, info)
  for i = 3, #info, 2 do
    local field = info[i]
    local value = info[i + 1]
    -- should be able to store numbers in hashes
    if type(value) == 'number' then
      value = tostring(value)
    end
    local field_len = #field
    local value_len = #value
    local total_len = field_len + value_len + ffi.sizeof('hash_element_t')
    local hash_elem = ffi.cast('hash_element_t*',ffi.new('char[' .. total_len .. ']'))
    local field_data = ffi.cast('intptr_t', hash_elem) + ffi.sizeof('hash_element_t')
    local value_data = field_data + field_len
    hash_elem.field_len = field_len
    hash_elem.value_len = value_len
    ffi.copy(ffi.cast('void*', field_data), field, field_len)
    ffi.copy(ffi.cast('void*', value_data), value, value_len)
    assert(Txn.put(txn, self.hash_elements, key, {hash_elem, total_len}))
  end
  return 'ok'
end

function exports:hmget(txn, info)
  local key = info[2]
  local values = {n = 0}
  local cursor = assert(Cursor.open(txn, self.hash_elements))
  for i = 3, #info do
    local field = info[i]
    local length = #field
    local total_len = length + ffi.sizeof('hash_element_t')
    local hash_field = ffi.cast('hash_element_t*',ffi.new('char[' .. total_len .. ']'))
    hash_field.field_len = length
    hash_field.value_len = 0
    local data = ffi.cast('intptr_t', hash_field) + ffi.sizeof('hash_element_t')
    ffi.copy(ffi.cast('void*', data), field, length)
    local sucess, hash_elem = 
      Cursor.get(cursor, key, {hash_field, total_len}, Cursor.MDB_GET_BOTH, nil,
        'hash_element_t*')
    values.n = values.n + 1
    if sucess then
      local data = ffi.cast('intptr_t', hash_elem) + ffi.sizeof('hash_element_t') + hash_elem.field_len
      values[values.n] = ffi.string(ffi.cast('void*', data), hash_elem.value_len)
    end
  end
  Cursor.close(cursor)
  return values
end

function exports:hget(txn, info)
  return unpack(exports.hmget(self, txn, info))
end

function exports:hgetall(txn, info)
  local key = info[2]
  local values = {}
  local cursor = assert(Cursor.open(txn, self.hash_elements))
  assert(Cursor.get(cursor, key, nil, Cursor.MDB_SET))
  assert(Cursor.get(cursor, key, nil, Cursor.MDB_FIRST_DUP))
  while true do
    local field = info[i]

    local _, hash_elem = 
      assert(Cursor.get(cursor, key, nil, Cursor.MDB_GET_CURRENT, nil,
        'hash_element_t*'))
    local field_data = ffi.cast('intptr_t', hash_elem) + ffi.sizeof('hash_element_t')
    local value_data = field_data + hash_elem.field_len
    values[#values + 1] = ffi.string(ffi.cast('void*', field_data), 
      hash_elem.field_len)
    values[#values + 1] = ffi.string(ffi.cast('void*', value_data),
      hash_elem.value_len)

    if not Cursor.get(cursor, key, nil, Cursor.MDB_NEXT_DUP) then
      break
    end
  end
  Cursor.close(cursor)
  return values
end

function exports:hdel(txn, info)
  assert('not implemented')
end