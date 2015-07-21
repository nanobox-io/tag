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
local Cursor = db.Cursor

exports.cdef = [[
typedef struct {
} queue_t;

typedef struct {
  long id; // id of queue elem
  int len; // length of data to be stored
} queue_elem_t;
]]

-- should be 1/2 of a 64 bit number or a long
-- if 1 million new indicies are added every second, we will run
-- out in 300,000 years.
-- this NEEDS to be stored somewhere
local head = ffi.new('unsigned long',tonumber('FFFFFFFFFFFFFFF',16))
local tail = head

local function push(self, txn, info, front)
  local key = info[2]
  local header, queue = self:resolve(txn, self.objects, key, 'header_t', 'queue_t')
  if not header then
    local new_header = assert(self:reserve(txn, self.objects, key, 'header_t', 'queue_t'))
    new_header.type = 'QUEUE'
  end
  for i = 3, #info do
    local elem = info[i]
    local length = #elem
    local total_len = length + ffi.sizeof('queue_elem_t')
    local queue_elem = ffi.cast('queue_elem_t*',ffi.new('char[' .. total_len .. ']'))
    if front then
      queue_elem.id = head
      head = head + 1
    else
      queue_elem.id = tail
      tail = tail - 1
    end
    queue_elem.len = length

    local data = ffi.cast('intptr_t', queue_elem) + ffi.sizeof('queue_elem_t')
    ffi.copy(ffi.cast('void*', data), elem, length)

    assert(Txn.put(txn, self.queue_items, key, {queue_elem,total_len}))
  end
  local cursor = assert(Cursor.open(txn, self.queue_items))
  assert(Cursor.get(cursor, key, nil, Cursor.MDB_SET))
  local count = assert(Cursor.count(cursor))
  Cursor.close(cursor)
  return tonumber(count)
end

local function pop(self, txn, info, front)
  local key = info[2]
  local header, queue = 
    self:resolve(txn, self.objects, key, 'header_t', 'queue_t')
  if not header then
    return nil
  end
  local cursor = assert(Cursor.open(txn, self.queue_items))
  assert(Cursor.get(cursor, key, nil, Cursor.MDB_SET))
  local count = assert(Cursor.count(cursor))
  if count == 1 then
    assert(Txn.del(txn, self.objects, key))
  end
  assert(Cursor.get(cursor, key, nil, front and Cursor.MDB_FIRST_DUP or Cursor.MDB_LAST_DUP))
  local _, queue_elem = assert(Cursor.get(cursor, key, nil, Cursor.MDB_GET_CURRENT, nil, 'queue_elem_t*'))
  assert(Cursor.del(cursor, 0))
  if front then
    head = head - 1
  else
    tail = tail + 1
  end
  Cursor.close(cursor)
  local data = ffi.cast('intptr_t', queue_elem) + ffi.sizeof('queue_elem_t')
  return ffi.string(ffi.cast('void*', data), queue_elem.len)
end

-- add an element to the head of the queue
function exports:lpush(txn, info)
  return push(self, txn, info, true)
end

-- remove an element from the front of the queue
function exports:lpop(txn, info)
  return pop(self, txn, info, true)
end

-- add an element to the back of the queue
function exports:rpush(txn, info)
  return push(self, txn, info, false)
end

-- remove an element from the back of the queue
function exports:rpop(txn, info)
  return pop(self, txn, info, false)
end

-- pop an element from one queue to another
function exports:rpoplpush(txn, info)
  local src = info[2]
  local dest = info[3]
  local elem = pop(self, txn, {'pop', src}, false)
  if elem then
    push(self, txn, {'push', dest, elem}, true)
    return elem
  end
end

-- get the length of a list
function exports:llen(txn, info)
  local key = info[2]
  local cursor = assert(Cursor.open(txn, self.queue_items))
  if not Cursor.get(cursor, key, nil, Cursor.MDB_SET) then
    return 0
  else
    local count = assert(Cursor.count(cursor))
    Cursor.close(cursor)
    return tonumber(count)
  end
end

local function resolve(index, length)
  return index < 0 and 
    math.max(length + index + 1, 0)
  or
    math.min(length, index)
end

local function resolve_start(start, stop, length)
  local pos, next, amount
  if start < 0 then
    if -start > length then
      start = 0
      amount = math.min(stop, length - start)
      pos, next = Cursor.MDB_FIRST_DUP, Cursor.MDB_NEXT_DUP
    else
      start = -start
      amount = math.min(stop, start)
      start = start - 1
      pos, next = Cursor.MDB_LAST_DUP, Cursor.MDB_PREV_DUP
    end
  else
    amount = math.min(stop, length - start)
    pos, next = Cursor.MDB_FIRST_DUP, Cursor.MDB_NEXT_DUP
  end
  if stop < 0 then
    amount = length - start + stop
  end
  return start, amount, pos, next
end

-- get a range of elements in the queue
function exports:lrange(txn, info)
  local key = info[2]
  local start = tonumber(info[3])
  local stop = tonumber(info[4])
  local length = exports.llen(self, txn, info)

  -- do some calculations
  local skip, amount, position, direction =
    resolve_start(start, stop, length)
  if amount == 0 then
    return {}
  end
  local list = {}
  local cursor = assert(Cursor.open(txn, self.queue_items))
  assert(Cursor.get(cursor, key, nil, Cursor.MDB_SET))
  assert(Cursor.get(cursor, key, nil, position))
  while skip > 0 do
    skip = skip - 1
    assert(Cursor.get(cursor, key, nil, direction))
  end
  while amount > 0 do
    amount = amount - 1
    local _, queue_elem = 
      assert(Cursor.get(cursor, key, nil, Cursor.MDB_GET_CURRENT, nil, 'queue_elem_t*'))
    local data = ffi.cast('intptr_t', queue_elem) + ffi.sizeof('queue_elem_t')
    list[#list + 1] = ffi.string(ffi.cast('void*', data), queue_elem.len)
    -- I need to see if this can fail
    Cursor.get(cursor, key, nil, Cursor.MDB_NEXT_DUP)
  end
  Cursor.close(cursor)
  return list
end

-- trim the queue down to size
function exports:ltrim(txn, info)
  local key = info[2]
  local start = tonumber(info[3])
  local stop = tonumber(info[4])

  local length = exports.llen(self, txn, info)
  local first = resolve(start, length)
  local last = length - resolve(stop, length)

  if first + last == length then
    assert(Txn.del(txn, self.objects, key))
    assert(Txn.del(txn, self.queue_items, key))
  else
    local cursor = assert(Cursor.open(txn, self.queue_items))
    assert(Cursor.get(cursor, key, nil, Cursor.MDB_SET))

    while first > 0 do
      first = first - 1
      assert(Cursor.get(cursor, key, nil ,Cursor.MDB_FIRST_DUP))
      assert(Cursor.del(cursor, 0))
    end

    while last > 0 do
      last = last - 1
      assert(Cursor.get(cursor, key, nil, Cursor.MDB_LAST_DUP))
      assert(Cursor.del(cursor, 0))
    end

    Cursor.close(cursor)
  end
  return 'ok'
end

-- I need blocking varieties of most of these...