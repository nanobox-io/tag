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
	local nodes = store:fetch('nodes')
	for id,node in pairs(nodes) do
		self:manage(Node:new(self:current(),opts))
	end
end

return Failover