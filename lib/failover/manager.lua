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
local Node = require('./node')
local log = require('logger')

local store = require('../store/store')

local Failover = Cauterize.Supervisor:entend()

function Failover:_manage()
	log.info('failover manager is starting up')

	-- start a process for each node in the cluster for monitoring.
	local ret = store:fetch('nodes')
	if ret[1] then
		for id,node in pairs(ret[2]) do
			local opts =
				{quorum = math.floor(#ret[2]/2) + 1
				,name = node.name}
			self:manage(Node,opts)
		end
	else
		error(ret[2])
	end
end

return Failover