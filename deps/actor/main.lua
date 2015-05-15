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

local Pid = require('./pid.lua')

local function Enter(application)

	main = Pid:initialize(application)

	-- this should run until we need to block for io, how do we resume
	-- after that? No idea. we will see what happens
	-- we should also let this exit every now and then so that we do get
	-- io operations every now and then even on a busy machine
	while Pid.step() == true do end 
end

return
	{Supervisor = require('./supervisor.lua')
	,Fsm = require('./fsm.lua')
	,Enter = Enter}