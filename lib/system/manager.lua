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

local Manager = Cauterize.Supervisor:extend()

function Manager:_manage()
	local ret = Cauterize.Server.call('store','fetch','system')
	if ret[1] then
		for _,system in pairs(ret[2]) do
			-- I think I need to unpack the system.data here
			self:manage(System,{args = {system.data}})
		end
	end
end