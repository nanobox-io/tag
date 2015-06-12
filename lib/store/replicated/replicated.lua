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

local Store = require('../basic/basic')
local Group = require('cauterize/lib/group')
local Replicated = Store:extend()

local hrtime = require('uv').hrtime
local json = require('json')
local Splode = require('splode')
local splode, xsplode = Splode.splode, Splode.xsplode
local db = require('lmmdb')
local Env = db.Env
local DB = db.DB
local Txn = db.Txn
local Cursor = db.Cursor

function Replicated:_init()
  Store._init(self)

  local txn = splode(Env.txn_begin,
    'unable to begin create transaction', self.env, nil, 0)
  
  -- replication stores remote node states, so that on disconnects
  -- replication can resume from where it left off
  self.replication = splode(DB.open, 'unable to create replication',
    txn, "replication", DB.MDB_CREATE)

  -- logs records write operations on this node until they are
  -- committed on all nodes connected to this one
  -- MDB_INTEGERKEY because we use timestamps
  self.logs = splode(DB.open, 'unable to create logs',
    txn, "logs", DB.MDB_CREATE + DB.MDB_INTEGERKEY)

  xsplode(0, Txn.commit,
    'unable to commit replicated database creation', txn)

end

function Replicated:prepare(bucket, id)
  local timestamp = hrtime()
  local txn = splode(Env.txn_begin,
    'unable to begin replicated create transaction', self.env, nil,
    0)

  xsplode(0, Txn.put,
    'unable to store in \'replication\' DB', txn, self.replication,
    timestamp, bucket .. ':' .. id, Txn.MDB_NODUPDATA)

  return txn, timestamp
end

function Replicated:finish(txn, status, ...)
  if status[1] then
    xsplode(0, Txn.commit,
      'unable to commit replicated create txn', txn)
  else
    xsplode(1, Txn.abort, 'unable to abort replicated txn', txn)
    error(status[2])
  end

  self:send({'group', 'sync'}, '$cast', {'sync', ...})

  return status[2]
end

function Replicated:enter(bucket, id, value)
  local args = {}
  return {pcall(function ()
    local txn, timestamp = self:prepare(bucket, id)
    local status = Store.enter(self, bucket, id, value, timestamp,
      txn)
    return self:finish(txn, status, timestamp, 'enter', bucket, id)
  end)}
end

function Replicated:delete(bucket, id)
  local args = {}
  return {pcall(function ()
    local txn, timestamp = self:prepare(bucket, id)
    local status = Store.delete(self, bucket, id, txn)
    return self:finish(txn, status, timestamp, 'delete', bucket, id)
  end)}
end

function Replicated:r_enter(bucket, id, data)
  local txn
  local response = {pcall(function()
    txn = splode(Env.txn_begin,
      'unable to begin r_enter transaction', self.env, nil, 0)

    local combo = bucket .. ':' .. id
    local object, err = Txn.get(txn, self.objects, combo,
      "element_t*")
    if object == nil or object.update > timestamp then
      xsplode(0, Txn.put, 'unable to store object key', txn,
        self.buckets, bucket, id)
      xsplode(0, Txn.put, 'unable to store object value', txn,
        self.objects, combo, data)
    end

    xsplode(0, Txn.commit,
      'unable to commit r_delete transaction', txn)

    txn = nil

    -- now i need to send this out to connections that are interested
    if object == nil or object.update > timestamp then
      self:send({'group', {'peers', bucket, combo}}, '$cast',
        {'r_delete', bucket, id, data})
    end
  end)}
  if txn then
    Txn.abort(txn)
  end
  return response
end

function Replicated:r_delete(bucket, id, timestamp)
  local txn
  local response = {pcall(function()
    txn = splode(Env.txn_begin,
      'unable to begin r_delete transaction', self.env, nil, 0)

    local combo = bucket .. ':' .. id
    local object = Txn.get(txn, self.objects, combo, "element_t*")

    if object and object.update > timestamp then
      xsplode(0, Txn.del, 'unable to delete object', txn,
        self.objects, combo)
    end

    xsplode(0, Txn.commit,
      'unable to commit r_delete transaction', txn)

    txn = nil

    -- now i need to send this out to connections that are interested
    if object.update > timestamp then
      self:send({'group', {'peers', bucket, combo}}, '$cast',
        {'r_delete', bucket, id, timestamp})
    end
  end)}
  if txn then
    Txn.abort(txn)
  end
  return response
end

return Replicated