-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   9 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local uv = require('uv')
local Cauterize = require('cauterize')
local websocket = require('websocket-codec')
local request = require('coro-http').request
local Group = require('cauterize/lib/group')
local SyncConnection = Cauterize.Fsm:extend()

function SyncConnection:_init(config)
  self.state = 'disconnected'
  self._recv_timeout = 0
  self.config = config
end

-- set up the states
SyncConnection.disconnected = {}
SyncConnection.connected = {}

function SyncConnection.disconnected:timeout()
  local opts =
    {host = config.host .. ":" .. config.port
    ,path = '/connect'}
    p('going to connect to',opts)
  p('got',websocket(opts,config,request))
end

return SyncConnection