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
local lmmdb = require('lmmdb')
local json = require('json')

local Store = require('./store/manager')
local Failover = require('./failover/manager')

if #args == 2 then
	local App = Cauterize.Supervisor:extend()

	local type = args[1]
	local data = args[2]
	if type == '-config-file' then
		data = file:read(data)
	elseif type ~= '-config-json' then
		error('bad type'..type)
	end

	-- i need to validate and pull out the correct config options
	local config = json.parse(data)
	-- I really need to store the config somewhere...
	log.info('starting server with config:',config)

	function App:_manage()
		log.info('tag server is starting')
		self:manage(Store)
				:manage(Failover)

		if config.simple ~= true then
			log.info('enabling replicated mode')
			self:manage(Replication)
		end
	end

	-- enter the main event loop, this function should never return
	-- we aren't ready for this yet
	-- Cauterize.Reactor:enter(function(env)
	-- 	App:new(env:current())
	-- end)

	-- not reached
	assert(false,'something went seriously wrong')
else
	-- print some simple help messages
	log.info('Usage: tag -server (-config-file|-config-json) {path|json}')
end

