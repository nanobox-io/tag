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
local Replicated = Store:extend()

local Splode = require('splode')
local splode, xsplode = Splode.splode, Splode.xsplode
local db = require('lmmdb')
local Env = db.Env
local DB = db.DB
local Txn = db.Txn
local Cursor = db.Cursor

function Replicated:init()
  Store._init(self)

  local txn = splode(Env.txn_begin,
    'unable to begin create transaction', self.env, nil, 0)
  -- replication stores remote node states, so that on disconnects
  -- replication can resume from where it left off
  self.replication = splode(DB.open, 'unable to create replication', 
    txn, "replication", DB.MDB_CREATE)

  -- logs records write operations on this node until not needed
  -- MDB_INTEGERKEY because we use timestamps
  self.logs = splode(DB.open, 'unable to create logs', 
    txn, "logs", DB.MDB_CREATE + DB.MDB_INTEGERKEY)


  -- we need to fetch the last operation that was commited
  local cursor = Cursor.open(txn, self.logs)
  local key, _op = Cursor.get(cursor, nil, Cursor.MDB_LAST,
    "unsigned long*")

  if key then
    -- if we have something stored, then the store is not new
    log.info("last operation commited", key[0])
    self.version = key[0]
  else
    -- if we don't have anything, then its a new database
    log.info("new database was opened")
    self.version = hrtime() * 100000
  end

  xsplode(0,Txn.commit,
    'unable to commit replicated database creation', txn)
end

return Replicated