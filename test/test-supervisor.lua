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
local Supervisor = require('cauterize/tree/supervisor')
local Server = require('cauterize/tree/server')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
	
	test('supervisors call _manage',function()
		local Test = Supervisor:extend()
		local manage_called = false
		local child_count = 0
		local Child = Server:extend()
		function Child:_init() child_count = child_count + 1 end

		function Test:_manage()
			self:manage(Child)
			:manage(Child)
			:manage(Child)
			manage_called = true
		end

		Reactor:enter(function(env)
			local pid = Test:new(env:current())
		end)

		assert(manage_called,"_manage was not called")
		assert(child_count == 3,"wrong number of children were started")
	end)

	test('supervisor restarts dead children',function()
		local Test = Supervisor:extend()
		local child_count = 0
		local Child = Server:extend()
		function Child:_init() 
			-- send a cast after a timeout.
			self:send_after(self:current(),100,'$cast',{'die'})
			child_count = child_count + 1
		end

		function Child:die() 
			p('child is going to die')
			self:exit()
		end
		function Test:_manage() 
			local opts = {restart = {every = 1}}
			self:manage(Child,opts)
		end

		Reactor:enter(function(env)
			local pid = Test:new(env:current())
		end)

		assert(child_count == 5,"wrong number of children were started")
	end)
end)