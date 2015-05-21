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

local Actor = require('actor')
local Supervisor = Actor.Supervisor
local file = require('file')
local json = require('json')

local App = Supervisor:extend()

function App:_init(type,data)
	if type == "-config-file" then
		data = file:read(data)
	elseif type ~= "-config-json" then
		error("bad type"..type)
	end

	-- i need to validate and pull out the correct config options
	self.config = json.parse(data)
end

function App:_manage()
	self:manage(require('./store/store.lua'))
	:manage(require('./failover/manager.lua'))
end

if #args == 2 then
	Actor.Enter(function()
		App:start(args[1],args[2])
	end)
else
	logger.info("Usage: tag -server (-config-file|-config-json) {path|json}")
end

