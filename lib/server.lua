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
local log = require('logger')
local file = require('fs')
local json = require('json')
local Config = require('./config_router')
local splode = require('splode')
splode.logger = log.warning


local Store = require('./store/manager')
local Failover = require('./failover/manager')
local System = require('./system/manager')
local Api = require('./api/manager')

if #args == 2 then

  local type = args[1]
  local data = args[2]
  if type == '-config-file' then
    data = file:read(data)
  elseif type ~= '-config-json' then
    error('bad type'..type)
  end

  -- maybe I should drop some ascii art in here? that could be fun :)

  local config,err = json.parse(data)
  if config == nil then
    error('json was poorly formatted')
  end

  -- set up the main application supervisor
  local App = Cauterize.Supervisor:extend()
  function App:_manage()
    self:manage(Config,{args = {config}, name = 'config'})
        :manage(Store,{type = 'supervisor', name = 'store manager'})
        :manage(Failover,
          {type = 'supervisor', name = 'failover manager'})
        :manage(System,{type = 'supervisor', name = 'system manager'})
        :manage(Api,{type = 'supervisor', name = 'api manager'})
  end

  -- enter the main event loop, this function should never return
  Cauterize.Reactor:enter(function(env)
    App:new(env:current())
    
    -- now that everything is setup lets enable the sending of packets
    Cauterize.Supervisor.call('packet_server','enable')
  end)

  -- not reached
  assert(false,'something went seriously wrong')
else
  -- print some simple help messages
  log.info('Usage: tag -server (-config-file|-config-json) {path|json}')
end

