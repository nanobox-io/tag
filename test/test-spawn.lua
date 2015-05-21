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

local hrtime = require('uv').hrtime
local Cauterize = require('cauterize')
local Pid = require('cauterize/lib/pid')
local Process = Cauterize.Process
local Reactor = Cauterize.Reactor
require('tap')(function (test)
	
	test('create a process',function()
		local ran = false
		local pid = Process:new(function(env)
			assert(env,"env is not set")
			ran = true
		end)
		assert(Pid.lookup(pid),'pid does not exist')
		Reactor:_step(Pid.lookup(pid))
		assert(ran,'the process did not run')
	end)

	test('send/recv work as expected',function()
		local time = nil
		local order = {}
		local t = function(step)
			order[#order + 1] = step
		end
		-- we don't want to exit when this finishes
		Reactor.continue = true

		-- enter the reactor, which should handle everything for us
		Reactor:enter(function(env)
			t(0)
			local pid = Process:new(function(env,parent)
				t(1)
				msg = env:recv()
				t(2)
				env:send(parent,'testing')
				t(3)
			end,{args = {env._pid}})
			t(4)
			env:send(pid,'hi!')
			t(5)
			msg = env:recv()
			t(6)
			local start = hrtime()
			env:send(env._pid,'what?')
			t(7)
			assert(env:recv(nil,500) == nil,"a message should not be returned")
			t(8)
			time = (hrtime() - start)/1000000
			t(9)
		end)
		
		
		assert(order[#order] == 9,'only got to step #'..#order)
		for idx,step in pairs({0,1,4,2,5,3,6,7,8,9}) do
			assert(order[idx] == step,'step '..step..' was ran out of order')
		end
		assert(time > 500,"timeout was incorrect")
		assert(msg[1] == 'testing','the process did not finish running')
	end)

end)