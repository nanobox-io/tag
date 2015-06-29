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

local Cauterize = require('cauterize')
local Name = require('cauterize/lib/name')
local log = require('logger')
local Splode = require('splode')
local splode, xsplode = Splode.splode, Splode.xsplode
local hrtime = require('uv').hrtime
local hash = require('./hash').crc32_string
local utl = require('../../util')

local db = require('lmmdb')
local Env = db.Env
local DB = db.DB
local Txn = db.Txn
local Cursor = db.Cursor

local ffi = require("ffi")

-- we need a data storage object so that we don't have to encode and
-- decode just to update timestamps
ffi.cdef[[
typedef struct {
  long hash; // hash of the data
  long update; // last update time
  long creation; // creation date
  int len; // length of char string
  char data[1]; // first char of the string data
} element_t;
]]
-- we really want to use set/get methods
element = ffi.metatype("element_t",
  {__tostring = function(self)
      local pointer = ffi.cast('intptr_t',self)
      pointer = pointer + 28
      return ffi.string(ffi.cast('void*',pointer),self.len)
    end})

local Basic = Cauterize.Server:extend()

-- called when this process starts running. responsible for opening
-- the store and setting everything up
function Basic:_init()
  -- this should come from the config file
  local path = utl.config_get('database_path')
  local err
  self.env = splode(Env.create, 'unable to create store enviroment')

  -- set some defaults
  Env.set_maxdbs(self.env, 3) -- we only need 3 dbs
  Env.set_mapsize(self.env, 1024*1024*1024) -- should be ~1Gb in size
  Env.reader_check(self.env) -- make sure that no stale readers exist

  -- open the enviroment
  repeat

    -- Env.MDB_NOSUBDIR means that one file is created, and no subdir
    -- is used to store the files created
    err = Env.open(self.env, path, Env.MDB_NOSUBDIR, tonumber('0644', 8))

    -- work around for solaris. I don't know what this breaks
    if err == 'Device busy' then
      fs.unlinkSync(path .. '-lock')
    elseif err then
      log.error('unable to open store enviroment', err)
      self:exit()
    end
  until err ~= 'Device busy' -- should only loop once

  -- create the tables that we use
  local txn = splode(Env.txn_begin,
    'unable to begin create transaction', self.env, nil, 0)
  
  -- objects stores the actual objects
  self.objects = splode(DB.open, 'unable to create objects',
    txn, "objects", DB.MDB_CREATE)

  -- objects stores the actual objects
  self.counts = splode(DB.open, 'unable to create object counts',
    txn, "count", DB.MDB_CREATE)

  -- buckets stores the keys that are in a bucket. this is used to
  -- enforce order and for listing a bucket
  -- MDB_DUPSORT because we store multiple values under one key
  self.buckets = splode(DB.open, 'unable to create buckets',
    txn, "buckets", DB.MDB_DUPSORT + DB.MDB_CREATE)

  -- we commit the transaction so that our tables are created
  xsplode(0,Txn.commit, 'unable to commit database creation', txn)
  Name.register(self:current(),'store')
end

-- count how many values are in a bucket, or in all buckets
function Basic:count(bucket,parent)
  local txn = nil

  local ret = {pcall(function()
    txn = splode(Env.txn_begin,
      'store unable to create a transaction', self.env, parent,
      Txn.MDB_RDONLY)

    if bucket then
      local count = splode(Txn.get,
        'does not exist', txn, self.counts, bucket,
        "unsigned long long*")
      return tonumber(count[0])

    else
      -- we are doing a list.
      cursor = splode(Cursor.open,
        'unable to create cursor for count', txn,
        self.counts)

      local acc = {}
      repeat
        -- advance cursor to next key, don't use 'splode because it
        -- errors when out of data points
        local bucket, count = Cursor.get(cursor, key, Cursor.MDB_NEXT,
          nil, "unsigned long long*")
        if bucket then
          acc[bucket] = tonumber(count[0])
        end
      until bucket == nil
      
      return acc
    end
  end)}

  if txn then
    Txn.abort(txn)
  end
  return ret
end

-- enter a new bucket, key and value into the database, returns an
-- error or the update time of the data
function Basic:enter(bucket, key, value, timestamp, parent)
  local txn = nil

  -- captures results into either {true, results} or {false, error}
  local ret = {pcall(function()
    assert(type(value) == "string",'value must be a string')
    assert(bucket,'unable to enter without a bucket')
    assert(key,'unable to enter without a key')
    -- we have a combo key for storing the actual data
    local combo = bucket .. ':' .. key

    -- begin a transaction
    txn = splode(Env.txn_begin,
      'store unable to create a transaction', self.env, parent, 0)

    -- preserve the creation date if this is an update
    local creation
    local prev,err = Txn.get(txn, self.objects, combo, "element_t*")
    if prev then
      creation = prev.creation
    else
      creation = timestamp or hrtime()

      -- add the key to the bucket table.
      xsplode(0, Txn.put,
        'unable to add to \'buckets\' DB', txn, self.buckets,
        bucket, key, Txn.MDB_NODUPDATA)

      -- increment how many objects are in the bucket
      local count = Txn.get(txn, self.counts, bucket,
        "unsigned long long*")
      if count and count[0] then
        count = tonumber(count[0] + 1)
      else
        count = 1
      end
      xsplode(0, Txn.put,
        'unable to add to \'count\' DB', txn, self.counts,
        bucket, count, Txn.MDB_NODUPDATA)
    end

    -- create an empty object. 24 for 3 longs, 4 for 1 int #value for
    -- the data, 1 for the NULL terminator
    -- MDB_RESERVE returns a pointer to the memory reserved and stored
    -- for the key combo
    local data = splode(Txn.put,
      'unable to store value', txn ,self.objects ,combo,
      24 + 4 + #value + 1, Txn.MDB_RESERVE)

    -- set the creation and update time to be now.
    local container = ffi.new("element_t*", data)
    if not prev then
      -- only if not an update
      container.creation = creation
      container.update = creation
      container.hash = hash(combo)
    else
      container.update = timestamp or hrtime()
    end

    -- copy in the actual data we are storing, 28 should be the right
    -- offset
    local pos = ffi.cast('intptr_t',data) + 28
    container.len = #value
    ffi.copy(ffi.cast('void *', pos), value, container.len)

    -- commit the transaction
    xsplode(0, Txn.commit,
      'unable to commit transaction', txn)

    -- clear out becuase it is invalid
    txn = nil
    
    -- if it is going to be replicated, we return the continater
    if timestamp then
      return container
    else
      return container.update
    end
  end)}

  -- perform some cleanup
  if txn then
    Txn.abort(txn)
  end

  return ret
end

-- remove a bucket, key from the database
function Basic:remove(bucket, key, parent)
  -- we may need to clear this out in case of error, which is why it
  -- is defined here

  local txn = nil
  -- should either be {true} or {false, error}
  local ret = {pcall(function()
    assert(bucket,'unable to remove without a bucket')
    assert(key,'unable to remove without a key')
    -- we have a combo key for storing the actual data
    local combo = bucket .. ':' .. key
    
    -- begin a transaction, store it in txn so it can be aborted later
    txn = splode(Env.txn_begin,
      'store unable to create a transaction', self.env,
      parent, 0)

    -- delete the object value
    xsplode(0, Txn.del, 'unable to delete object', txn, self.objects,
      combo)

    -- delete the object key
    xsplode(0, Txn.del, 'unable to delete object key', txn,
      self.buckets, bucket, key)

    -- decrement how many objects are in the bucket
      local count = Txn.get(txn, self.counts, bucket,
        "unsigned long long*")
      if count and count[0] > 1 then
        xsplode(0, Txn.put,
          'unable to decrement \'count\' DB', txn, self.counts,
          bucket, tonumber(count[0] - 1), Txn.MDB_NODUPDATA)
      else
        xsplode(0, Txn.del, 'unable to delete bucket count key', txn,
          self.counts, bucket)
      end
      

    -- commit all changes
    xsplode(0, Txn.commit, 'unable to commit transaction',
      txn)

    -- clear out because it is invalid
    txn = nil
  end)}
  if txn then
    Txn.abort(txn)
  end
  return ret
end

-- fetch a value from the database
function Basic:fetch(bucket, key)
  
  local cursor, txn = nil, nil
  -- should either be {true, container}, {true, {container}} or
  -- {false, error}
  local ret = {pcall(function()
    if key == "" then
      key = nil
    end
    assert(bucket,'unable to list without a bucket')
    -- fetching is a read only transaction, hence MDB_RDONLY
    txn = splode(Env.txn_begin, 'unable to create txn ', self.env,
      nil, Txn.MDB_RDONLY)

    if key then
      -- we are looking up a single value
      local combo = bucket .. ":" .. key
      return splode(Txn.get,
        'does not exist', txn, self.objects, combo,
        "element_t*")

    else
      -- we are doing a list.
      cursor = splode(Cursor.open,
        'unable to create cursor for list' .. bucket, txn,
        self.buckets)

      local b_id, id = xsplode(2, Cursor.get,
        'unable to set the initial cursor ' .. bucket, cursor, bucket,
        Cursor.MDB_SET_KEY)

      local acc = {}
      repeat
        local combo = bucket .. ":" .. id
        
        -- get the value for the current key
        local container = splode(Txn.get,
          'unable to get value for key', txn, self.objects,
          combo, "element_t*")
        acc[#acc + 1] = id
        acc[id] = container

        -- advance cursor to next key, don't use 'splode because it
        -- errors when out of data points
        b_id, id = Cursor.get(cursor, key, Cursor.MDB_NEXT_DUP)
      until b_id ~= bucket

      return acc
    end
  end)}

  -- do some clean up if needed
  if cursor then
    Cursor.close(cursor)
  end
  if txn then
    Txn.abort(txn)
  end
  return ret
end

function Basic:_destroy()
  xsplode(0, Env.close, 'unable to close env', self.env)
end

return Basic