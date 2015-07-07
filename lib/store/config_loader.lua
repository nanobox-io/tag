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

local bundle = require('luvi').bundle
local Cauterize = require('cauterize')
local log = require('logger')
local json = require('json')
local utl = require('../util')

local ConfigLoader = Cauterize.Server:extend()

function ConfigLoader:_init()
  -- load all nodes in the config file into the database, but only if
  -- the current node isn't in it.
  local node_name = utl.config_get('node_name')
  log.info('checking if the config needs to be loaded into the db')
  local exists = ConfigLoader.call('store','fetch','nodes',node_name)

  if not exists[1] then
    p('loading in config')

    local config_options = 
      {'max_packets_per_interval'
      ,'needed_quorum'
      ,'node_wait_for_response_interval'}

    for _,name in pairs(config_options) do
      local value = utl.config_get(name)
      p(ConfigLoader.call('store','enter','config',name,
        json.stringify(value)))
    end

    local nodes = utl.config_get('nodes_in_cluster')
    for name,node in pairs(nodes) do
      p(ConfigLoader.call('store','enter','nodes',name,
        json.stringify(node)))
    end

    local systems = utl.config_get('systems')
    systems.sync =
      {topology = 'max[3]:choose_one_or_all'
      ,data = 'nodes'
      ,install = 'code:'
      ,timeout = 250
      ,code = bundle.readfile('lib/store/replicated/sync_leader.lua')}

    for name,system in pairs(systems) do
      local data = nil
      if type(system.data) == 'table' then
        data = system.data
        system.data = nil
      end
      p(ConfigLoader.call('store','enter','systems',name,json.stringify(system)))
      if data then
        for idx,data in pairs(data) do
          p(ConfigLoader.call('store', 'enter', 'system-' .. name,
            tostring(idx), json.stringify(data)))
        end
      end
    end
  end
end

return ConfigLoader