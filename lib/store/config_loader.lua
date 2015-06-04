-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   21 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local log = require('logger')
local json = require('json')
local utl = require('../util')

local ConfigLoader = Cauterize.Supervisor:extend()

function ConfigLoader:_init()
  local dont_update = utl.config_get('replicated_db')

  -- load all the systems from the config file into the db, but only
  -- if a system with the same name does not exist
  local systems = utl.config_get('systems')  
  for name,system in pairs(systems) do
    local data = system.data
    system.data = nil
    if dont_update then
      local exists = ConfigLoader.call('store','fetch','system',name)
      if exists[1] then
        break
      end
    end

    ConfigLoader.call('store','enter','system',name,json.stringify(system))

    for idx,data in pairs(data) do
      ConfigLoader.call('store', 'enter', 'system-' .. name,
        tostring(idx), json.stringify(data))
    end
  end

  -- load all nodes in the config file into the database, but only if
  -- the current node isn't in it.
  local node_name = utl.config_get('node_name')
  log.info('checking if the config needs to be loaded into the db')
  local exists = ConfigLoader.call('store','fetch','nodes',node_name)

  if not exists[1] then
  	local nodes = utl.config_get('nodes_in_cluster')
    for name,node in pairs(nodes) do
      ConfigLoader.call('store','enter','nodes',name,
        json.stringify(node))
    end
  end
end

return ConfigLoader