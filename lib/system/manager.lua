-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   27 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local System = require('./system')
local log = require('logger')

local Manager = Cauterize.Supervisor:extend()

function Manager:_manage()
	local node_name = Cauterize.Fsm.call('config', 'get', 'node_name')
	local nodes_in_cluster = Cauterize.Fsm.call('config', 'get',
		'nodes_in_cluster')
	local alive_systems = nodes_in_cluster[node_name].systems
	local enabled = 0
  if alive_systems then
  	local systems = Cauterize.Fsm.call('config', 'get', 'systems')
    for _,system_name in pairs(alive_systems) do
    	local system_data = systems[system_name]
    	if system_data then
    		log.info('enabling system',system_name,system_data)
    		enabled = enabled + 1
	      self:manage(System,{args = {system_name,system_data}})
	    else
	    	log.warning('unknown system',system_name)
	    end
    end
 	end
 	if enabled == 0 then
 		log.info('entering arbitration mode, no systems enabled')
  end
end

return Manager