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

local Api = require('./api')
local Basic = require('./basic/basic')

local Store = Cauterize.Supervisor:entend()

function Store:_manage()
	log.info('store manager is starting up')
	self:manage(Basic)
			:manage(Api)
end

return Store