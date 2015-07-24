-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   15 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local log = require('logger')
local uv = require('uv')
local hrtime = uv.hrtime

local db = require('lmmdb')
local Env = db.Env
local DB = db.DB
local Txn = db.Txn

local ffi = require("ffi")
local jit = require('jit')
local folder = jit.os .. '-' .. jit.arch
local compare = assert(module:action('../../' .. folder ..'/libcompare.so', ffi.load))

local types = require('ffi-cache')

ffi.cdef[[
int compare_queue_objs(const MDB_val *a, const MDB_val *b);
int compare_hash_objs(const MDB_val *a, const MDB_val *b);
]]

ffi.cdef[[
typedef enum {TOMBSTONE, STRING, NUMBER, SET, QUEUE, HASH} obj_type;

typedef struct {
  long creation; // creation date
  obj_type type; // what type of object is being stored
} header_t;
]]

local Basic = require('core').Object:extend()

function Basic:initialize(path)
  self.env = assert(Env.create(), 'unable to create store enviroment')

  -- set some defaults
  Env.set_maxdbs(self.env, 5) -- we only need 5 dbs
  Env.set_mapsize(self.env, 1024*1024*1024 * 10)
  Env.reader_check(self.env) -- make sure that no stale readers exist


  -- Env.MDB_NOSUBDIR store data in one file
  -- Env.MDB_NOTLS allow multiple read_only transactions
  -- Env.MDB_NOLOCK locking is not handled by the library
  -- Env.MDB_NOSYNC defer flushing changed pages to disk until later
  -- Env.MDB_NOMEMINIT do not init memory
  local sucess, err = Env.open(self.env, path,
    Env.MDB_NOSUBDIR + Env.MDB_NOTLS + Env.MDB_NOLOCK + Env.MDB_NOSYNC + Env.MDB_NOMEMINIT,
    tonumber('0644', 8))
  
  if not sucess then
    p(err, path)
    error('unable to open store enviroment', err)
  end

  -- create the tables that we use
  local txn = assert(Env.txn_begin(self.env, nil, 0))
  
  self.objects = assert(DB.open(txn, "objects", DB.MDB_CREATE))

  self.information = assert(DB.open(txn, "information", DB.MDB_CREATE))

  self.set_elements = assert(DB.open(txn, "set_elements", DB.MDB_CREATE +  DB.MDB_DUPSORT))
  -- assert(DB.set_dupsort(txn, self.set_elements,
  --  compare.compare_set_objs))

  self.queue_items = assert(DB.open(txn, "queue_items", DB.MDB_CREATE + DB.MDB_DUPSORT))
  assert(DB.set_dupsort(txn, self.queue_items,
    compare.compare_queue_objs))

  self.hash_elements = assert(DB.open(txn, "hash_elements", DB.MDB_CREATE + DB.MDB_DUPSORT))
  assert(DB.set_dupsort(txn, self.hash_elements,
    compare.compare_hash_objs))

  -- we commit the transaction so that our tables are created
  assert(Txn.commit(txn))
  log.info('database was opened')
  self.tails = {}
end

function Basic:perform(info, read, write)
  local name = info[1]:lower()
  if Basic.valid_cmds[name] then
    return self[name](self, nil, info, read, write)
  else
    return nil, 'UNKNOWN COMMAND'
  end
end

-- create a cache that can be cleaned out by the gc.
local cache = {}
setmetatable(cache, {__mode = "v"})

local function compose(cmd, fun, valid_types)
  return function(self, parent, info, ...)
    local flags = self.flags[cmd] or 0
    local key
    if bit.band(flags, Txn.MDB_RDONLY) > 0 and info[2] then
      key = table.concat(info, ' ')
      local key_cache = cache[info[2]]
      if key_cache then
        local ret = key_cache[key]
        if ret then
          return ret, nil, key
        end
      end
    elseif info[2] then
      cache[info[2]] = nil
    end
    local txn = Env.txn_begin(self.env, parent, flags)
    local sucess, ret = pcall(fun,self, txn, info, ...)
    if sucess then
      -- if we need to log the function, this is where that would go
      assert(Txn.commit(txn))
      if bit.band(flags, Txn.MDB_RDONLY) > 0 and info[2] and key then
        local key_cache = cache[info[2]]
        if not key_cache then
          key_cache = {}
          cache[info[2]] = key_cache
        end
        key_cache[key] = ret
      end
      return ret, nil, cache_key
    else
      Txn.abort(txn)
      return nil, ret
    end
  end
end

local storage_types = 
  {'string'
  ,'set'
  ,'number'
  ,'queue'
  ,'hash'
  ,'common'}

Basic.flags = {}
Basic.valid_cmds = {}

for _, type in ipairs(storage_types) do
  local allowed_types = {}
  allowed_types[type:upper()] = true
  local storage = require('./storage_types/' .. type)
  if storage.cdef then
    ffi.cdef(storage.cdef)
  end
  if storage.flags then
    for name,flag in pairs(storage.flags) do
      assert(Basic.flags[name] == nil, 'flags already set')
      Basic.flags[name] = flag
    end
  end

  for name,fun in pairs(storage) do 
    if name ~= 'cdef' and name ~= 'flags' then
      assert(Basic[name] == nil, 'funciton already defined')
      Basic[name] = compose(name, fun, allowed_types)
      Basic.valid_cmds[name] = true
    end
  end
end

local function resolve(data, type_list, headers)
  for _, t in ipairs(type_list) do
    if type(t) == 'number' then
      headers[#headers + 1] = ffi.cast(types.typeof["void*"], data)
      data = ffi.cast(types.typeof.intptr_t, data) + t
    else
      headers[#headers + 1] = ffi.cast(types.typeof[t .. '*'], data)
      data = ffi.cast(types.typeof.intptr_t, data) + types.sizeof[t]
    end
  end
  headers[#headers + 1] = ffi.cast(types.typeof["void*"],data)
  return unpack(headers)
end

Basic.valid_cmds.flushall = true
function Basic:flushall(txn, info)
  p('flushing all the data from the database', txn, info)
  local txn = Env.txn_begin(self.env, txn, 0)
  assert(DB.drop(txn, self.objects, 0))
  assert(DB.drop(txn, self.set_elements, 0))
  assert(DB.drop(txn, self.queue_items, 0))
  assert(DB.drop(txn, self.hash_elements, 0))
  assert(Txn.commit(txn))
  cache = {}
  return 'ok'
end

function Basic:update_time(txn, key)

end

function Basic:resolve(txn, table, key, type, ...)
  local data, err = Txn.get(txn, table, key, type .. '*')
  if data then
    local headers = {data}
    data = ffi.cast(types.typeof.intptr_t, data) + types.sizeof[type]
    return resolve(data, {...}, headers)
  else
    return false, err
  end
end

function Basic:reserve(txn, database, key, ...)
  local type_list = {...}
  local total_len = 0
  for _, t in ipairs(type_list) do
    if type(t) == 'number' then
      total_len = total_len + t
    else
      total_len = total_len + types.sizeof[t]
    end
  end

  local data = 
    assert(Txn.put(txn, database, key, total_len, Txn.MDB_RESERVE))
  return resolve(data, type_list, {})
end

return Basic