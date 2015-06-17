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
local Ref = require('cauterize/lib/ref')
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

function Replicated:prepare(bucket, id)
  local timestamp = hrtime()
  local txn = splode(Env.txn_begin,
    'unable to begin replicated create transaction', self.env, nil,
    0)

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

  local pids = Group.get({'peers'})
  local count = #pids
  local ref = Ref.make()
  for pid in pairs(pids) do
    self:send(pid,'$call',{'sync', ...},{self:current(),ref})
  end

  local success_count = 0
  for i = 1,count do
    -- how long do I wait for all the messages before i give up?
    -- should I scale the time back when we have already waited?
    local cmd_was_replicated = self:recv(5000,{ref})
    if cmd_was_replicated and cmd_was_replicated[1] then
      success_count = success_count + 1
    end
  end

  if success_count == count then 
    return status[2]
  else
    return 'action was not comitted on all peers'
  end
end

function Replicated:enter(bucket, id, value)
  local args = {}
  return {pcall(function ()
    local txn, timestamp = self:prepare(bucket, id)
    local status = Store.enter(self, bucket, id, value, timestamp,
      txn)
    return self:finish(txn, status, timestamp, bucket, id, value)
  end)}
end

function Replicated:delete(bucket, id)
  local args = {}
  return {pcall(function ()
    local txn, timestamp = self:prepare(bucket, id)
    local status = Store.delete(self, bucket, id, txn)
    return self:finish(txn, status, timestamp, bucket, id)
  end)}
end

function Replicated:r_enter(bucket, id, data)
  p('performing r_enter',bucket,id)
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

      xsplode(0, Txn.commit,
        'unable to commit r_delete transaction', txn)

      txn = nil

      -- now i need to send this out to connections that are interested
      if object == nil or object.update > timestamp then
        self:send({'group', {'peers', 'b:' .. bucket, 'id:' .. combo}},
          '$cast', {'r_enter', bucket, id, data})
      end
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

      xsplode(0, Txn.commit,
        'unable to commit r_delete transaction', txn)

      txn = nil

      -- now i need to send this out to connections that are interested
      if object.update > timestamp then
        self:send({'group', {'peers', 'b:' .. bucket, 'id:' .. combo}},
          '$cast', {'r_delete', bucket, id, timestamp})
      end
    end
  end)}
  if txn then
    Txn.abort(txn)
  end
  return response
end

return Replicated