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
local Node = require('../lib/failover/node')

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
			local node1 = 
				{quorum = 2
				,name = '1'}
			local node1 = Node:new(env:current(), node1)

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

	test('udp packets recevied can trigger state changes',function()
		local host,port = "127.0.0.1",1234
		local node1 = 
			{quorum = 2
			,name = '1'}
		local node2 = 
			{quorum = 2
			,name = '2'}
		local node3 = 
			{quorum = 2
			,name = '3'}
		Reactor:enter(function(env)
			local packet1 = Packet:new(env:current(), host, port ,'1')
			local packet2 = Packet:new(env:current(), host, port + 1, '2')
			local packet3 = Packet:new(env:current(), host, port + 2, '3')

			-- these are shared between the three packet monitors above
			local node1 = Node:new(env:current(), node1)
			local node2 = Node:new(env:current(), node2)
			local node3 = Node:new(env:current(), node3)

			p('created nodes',node1,node2,node3)


			for _,monitor in pairs({packet1,packet2,packet3}) do
				Packet.call(monitor,'add_node',
					{name = "1", host = host, port = port})
				Packet.call(monitor,'add_node',
					{name = "2", host = host, port = port + 1})
				Packet.call(monitor,'add_node',
					{name = "3", host = host, port = port + 2})
				Packet.call(monitor,'enable')
			end

			env:recv(nil,5000)
			Packet.call(packet1,'disable')
			Packet.call(packet2,'disable')
			Packet.call(packet3,'disable')

			Node.cast(node1,'_stop')
			Node.cast(node2,'_stop')
			Node.cast(node3,'_stop')

			Node.cast(packet1,'_stop')
			Node.cast(packet2,'_stop')
			Node.cast(packet3,'_stop')
		end)

		assert(false,"this is a bad test because it requires manual verification")
	end)
end)