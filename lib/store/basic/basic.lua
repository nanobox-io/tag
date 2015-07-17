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
local folder = jit.os .. '_' .. jit.arch
local compare = module:action('./' .. folder ..'/libcompare.so', ffi.load)

ffi.cdef[[
int compare_queue_objs(const MDB_val *a, const MDB_val *b);
]]

ffi.cdef[[
typedef enum {TOMBSTONE, STRING, NUMBER, SET, QUEUE} obj_type;

typedef struct {
  long creation; // creation date
  obj_type type; // what type of object is being stored
} header_t;
]]

local Basic = require('core').Object:extend()

function Basic:initialize(path)
  self.env = assert(Env.create(), 'unable to create store enviroment')

  -- set some defaults
  Env.set_maxdbs(self.env, 4) -- we only need 4 dbs
  Env.set_mapsize(self.env, 1024*1024*1024 * 10)
  Env.reader_check(self.env) -- make sure that no stale readers exist

  -- open the enviroment
  while true do

    -- Env.MDB_NOSUBDIR store data in one file
    -- Env.MDB_NOTLS allow multiple read_only transactions
    -- Env.MDB_NOLOCK locking is not handled by the library
    local sucess, err = Env.open(self.env, path,
      Env.MDB_NOSUBDIR + Env.MDB_NOTLS + Env.MDB_NOLOCK + Env.MDB_NOSYNC,
      tonumber('0644', 8))
    
    if not sucess then
      -- work around for solaris.
      if err == 'Device busy' then
        fs.unlinkSync(path .. '-lock')
      else
        error('unable to open store enviroment', err)
      end
    else
      break
    end
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

  -- we commit the transaction so that our tables are created
  assert(Txn.commit(txn))
  log.debug('database was opened')
  self.txn_timer = uv.new_timer()
end

function Basic:perform(info, read, write)
  local name = info[1]:lower()
  if Basic.valid_cmds[name] then
    return pcall(self[name],self, nil, info, read, write)
  else
    return false, 'UNKNOWN COMMAND'
  end
end

local function compose(cmd, fun, valid_types)
  return function(self, parent, info, ...)
    local txn = Env.txn_begin(self.env, parent, 0)
    local sucess, ret = fun(self, txn, info, ...)
    if sucess then
      assert(Txn.commit(txn))
    else
      Txn.abort(txn)
    end
    return sucess, ret
  end
end

local function wrap1(cmd, fun, valid_types)
  return function(self, parent, key, ...)
    if not key then return false, 'missing key' end
    local txn = Env.txn_begin(self.env, parent, self.flags[name])
    local old_container = Txn.get(txn, self.objects, key, "header_t*")
    if old_container then
      if old_container.type == 'TOMBSTONE' then
        old_container = nil
      else
        assert(valid_types[old_container.type],
          'key has wrong type for cmd')
      end
    end
    local sucess, new_container, ret = pcall(fun, self, txn,
      old_container, key, ...)
    if sucess then
      log.debug('ran cmd', cmd, key, ...)
      -- we may want to track statistics on what commands were run
      -- this is where we would do that
      local creation = hrtime()
      -- preserve the original creation timestamp
      if old_container then
        new_container.creation = old_container.creation
      else
        new_container.creation = creation
      end
      new_container.update = creation
      assert(Txn.commit(txn))
    else
      assert(Txn.abort(txn))
    end
    return sucess, ret
  end
end

local storage_types = 
  {'string'
  ,'set'
  ,'number'
  ,'queue'
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

local function resolve(data, types, headers)
  for _, t in ipairs(types) do
    if type(t) == 'number' then
      headers[#headers + 1] = ffi.cast('void *', data)
      data = ffi.cast('intptr_t', data) + t
    else
      headers[#headers + 1] = ffi.cast(t .. '*', data)
      data = ffi.cast('intptr_t', data) + ffi.sizeof(t)
    end
  end
  headers[#headers + 1] = ffi.cast('void *',data)
  return unpack(headers)
end

function Basic:update_time(txn, key)

end

function Basic:resolve(txn, table, key, type, ...)
  local data, err = Txn.get(txn, table, key, type .. '*')
  if data then
    local headers = {data}
    data = ffi.cast('intptr_t', data) + ffi.sizeof(type)
    return resolve(data, {...}, headers)
  else
    return false, err
  end
end

function Basic:reserve(txn, database, key, ...)
  local types = {...}
  local total_len = 0
  for _, t in ipairs(types) do
    if type(t) == 'number' then
      total_len = total_len + t
    else
      total_len = total_len + ffi.sizeof(t)
    end
  end

  local data = 
    assert(Txn.put(txn, database, key, total_len, Txn.MDB_RESERVE))
  return resolve(data, types, {})
end

return Basic