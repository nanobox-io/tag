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
local Server = require('cauterize/tree/server')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
	
	test('servers correctly respond to cast and call',function()
		local Test = Server:extend()
		local test1_ran = false
		local test2_ran = false
		local test1_ret = nil
		local test2_ret = 1
		local stop_errored = true
		function Test:test1() test1_ran = true; return true end
		function Test:test2() test2_ran = true; return false end
		function Test:stop() self:_stop() end

		Reactor:enter(function(env)
			local pid = Test:new(env:current())
			test1_ret = Server.call(pid,'test1')
			test2_ret = Server.cast(pid,'test2')
			Server.call(pid,'stop')
			stop_errored = false
		end)
		
		assert(test1_ran,"call did not work")
		assert(test2_ran,"cast did not work")
		assert(test1_ret == true,"call did not return a value")
		assert(test2_ret == nil,"cast did returned a value")

		assert(stop_errored,"stop did not throw an error")

	end)
end)