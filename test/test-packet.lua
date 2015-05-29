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
local uv = require('uv')
local Packet = require('../lib/failover/packet')
local Store = require('../lib/store/basic/basic')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
	
	test('udp sockets can correctly start up',function()
		local Test = Packet:extend()
		local got_packet = false
		function Test.udp_recv(self,...)
			got_packet = true
			p('got message',...)
		end

		function Test:stop()
			self:_stop()
			return true
		end

		local host,port = "127.0.0.1",1234

		Reactor:enter(function(env)
			Store:new(env:current())
			Store.call('store','enter','node','node1','this is test data')
			local pid = Test:new(env:current(),host,port)
			Test.call(pid,'enable')
			local udp = uv.new_udp()
			uv.udp_bind(udp, host, 1235)
			
			uv.udp_send(udp, "testing", host, port)
			env:recv(nil,100)

			uv.udp_send(udp, "testing1", host, port)
			env:recv(nil,100)
			
			uv.close(udp)
			Test.call(pid,'stop')
		end)

		assert(got_packet,'did not get the packet')

	end)
end)