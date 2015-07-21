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
local Process = require('cauterize/lib/process')
local log = require('logger')
local fs = require('fs')
local uv = require('uv')
local json = require('json')
local stdin = require('pretty-print').stdin


local Sync = require('./store/replicated/manager')
local Failover = require('./failover/manager')
local System = require('./system/manager')
local load_config = require('./default')
local store = require('./store/main').singleton()

if #args == 2 then

  local type = args[1]
  local data = args[2]
  if type == '-config-file' then
    data = fs:read(data)
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
  load_config(config)

  -- show a meaningful process name 'tag -> node1 127.0.0.1:1234'
  local node_name = store:get(nil, {'get', '#node_name'})
  local host, port = unpack(store:hmget(nil, {'hmget', '!' .. node_name, 'host', 'port'}))
  uv.set_process_title('tag -> ' .. node_name .. ' ' .. host .. ':' .. port)

  function App:_manage()
    self:manage(Failover,
          {type = 'supervisor', name = 'failover manager'})
        :manage(Sync,
          {type = 'supervisor', name = 'sync manager'})
        :manage(System,
          {type = 'supervisor', name = 'system manager'})

  end

  -- enter the main event loop, this function should never return
  Cauterize.Reactor:enter(function(env)
    local app = App:new(env:current())
    
    Cauterize.Supervisor.call('packet_server','enable')

    if config.exit_on_stdin_close == true then
      -- if stdin is closed, shutdown the system
      uv.read_start(stdin, function(err,data)
        if data == nil then
          log.info('stdin closed, shutting down system')
          Process:new(function()
            App.call(app, 'stop')
            Store.singleton:close()
            os.exit(0)
          end)
        end
      end)
    end
  end)

  -- not reached
  assert(false,'something went seriously wrong')
else
  -- print some simple help messages
  log.info('Usage: tag -server (-config-file|-config-json) {path|json}')
end

