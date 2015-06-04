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

local ConfigLoader = Cauterize.Supervisor:extend()

function ConfigLoader:_init()
	local systems = ConfigLoader.call('config','get','systems')
	for name,system in pairs(systems) do
		local data = system.data
		system.data = nil
		ConfigLoader.call('store','enter','system',name,json.stringify(system))

		for idx,data in pairs(data) do
			ConfigLoader.call('store', 'enter', 'system-' .. name,
				tostring(idx), json.stringify(data))
		end
	end
end

return ConfigLoader