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
local types = require('ffi-cache')
local Txn = db.Txn
local Cursor = db.Cursor


exports.cdef = [[
typedef struct {
  long count; // total number of members in the set
} set_t;

typedef struct {
  long create; // time when element was added to struct
  int len; // length of data or 0 if TOMBSTONE'd
} set_element_t;
]]

exports.flags = 
  {scard = Txn.MDB_RDONLY
  ,members = Txn.MDB_RDONLY
  ,sismember = Txn.MDB_RDONLY}

local function check_exist(cursor, key, elem)
  local exist =
    Cursor.get(cursor, key, elem, Cursor.MDB_GET_BOTH, nil, -1)
  return exist and true or false
end

-- add an element to a set
function exports:sadd(txn, info)
  local key = info[2]
  local added = 0
  local cursor = assert(Cursor.open(txn, self.set_elements))
  for i = 3, #info do
    local elem = info[i]
    if not check_exist(cursor, key, elem) then
      local sucess = 
        Txn.put(txn, self.set_elements, key, elem, Txn.MDB_NODUPDATA)
      if sucess then
        added = added + 1
      end
    end
  end
  Cursor.close(cursor)
  if added > 0 then
    local sucess, err = self:incr(txn, {'incr', key, added}, 'set_t', 'SET')
    self:update_time(txn, key) -- this could get lost
  end
  return added
end

-- remove an element from a set
function exports:srem(txn, info)
  local key = info[2]
  local removed = 0
  local cursor = assert(Cursor.open(txn, self.set_elements))
  for i = 3, #info do
    local elem = info[i]
    if check_exist(cursor, key, elem) then
      local sucess = 
        Txn.del(txn, self.set_elements, key, elem)
      if sucess then
        removed = removed + 1
      end
    end
  end
  Cursor.close(cursor)
  if removed > 0 then
    self:decr(txn, {'decr', key, removed}, 'set_t', 'SET')
    self:update_time(txn, key)
  end
  return removed
end

-- get element count in a set
function exports:scard(txn, info)
  local key = info[2]
  local header, set =
    self:resolve(txn, self.objects, key, 'header_t', 'set_t')
  return header and tonumber(set.count) or 0
end

-- get all members in the set
function exports:smembers(txn, info)
  local key = info[2]
  local ret = {}
  local cursor = assert(Cursor.open(txn, self.set_elements))
  local sucess, value = 
    Cursor.get(cursor, key, nil, Cursor.MDB_SET)
  while sucess do
    ret[#ret + 1] = value
    sucess, value = 
      Cursor.get(cursor, key, nil, Cursor.MDB_NEXT_DUP)
  end
  Cursor.close(cursor)
  return ret
end

-- check if a member is in the set
function exports:sismember(txn, info)
  local key = info[2]
  local elem = info[3]
  local cursor = assert(Cursor.open(txn, self.set_elements))
  local exists = check_exist(cursor, key, elem) 
  Cursor.close(cursor)
  return exists
end