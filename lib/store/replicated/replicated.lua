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

local uv = require('uv').hrtime
local bundle = require('luvi').bundle
local json = require('json')
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

  -- logs records write operations on this node until they are
  -- committed on all nodes connected to this one
  -- MDB_INTEGERKEY because we use timestamps
  self.logs = splode(DB.open, 'unable to create logs', 
    txn, "logs", DB.MDB_CREATE + DB.MDB_INTEGERKEY)
  
  self:load_store_system(txn)

  xsplode(0,Txn.commit,
    'unable to commit replicated database creation', txn)

end

local function prepare(bucket, id)
	local timestamp = hrtime()
	local txn = splode(Env.txn_begin,
    'unable to begin replicated create transaction', self.env, nil,
    0)

	xsplode(0, Txn.put,
    'unable to store in \'replication\' DB', txn, self.replication,
    timestamp, bucket .. ':' .. key, Txn.MDB_NODUPDATA)

	return txn, timestamp
end

local function finish(txn,status,timestamp,type)
	if status[1] then
		status = splode(Txn.commit, 
			'unable to commit replicated create txn', txn)
	else
		xplode(1,Txn.abort,'unable to abort replicated txn',txn)
		error(status[2])
	end

	self:send({'group','sync'},'sync',timestamp,type)

	return status[2]
end

function Replicated:enter(bucket,id,value)
	local args = {}
	return {pcall(function ()
		local txn, timestamp = prepare(bucket, id)
		local status = Store.enter(self,bucket,id,value,timestamp,txn)
		return finish(txn, status, timestamp, 'enter')
	end)}
end

function Replicated:delete(bucket,id)
	local args = {}
	return {pcall(function ()
		local txn, timestamp = prepare(bucket, id)
		local status = Store.delete(self,bucket,id,txn)
		return finish(txn, status, timestamp, 'delete')
	end)}
end

function Replicated:load_store_system(txn)
	local store = 
		{topology = 'max[3]:choose_one_or_all'
		,data = 'nodes'
		,install = 'code:'
		,code = bundle.readfile('lib/store/replicated/sync-leader')}
	Store.enter(self,'systems','sync',json.stringify(store),txn)
end

return Replicated