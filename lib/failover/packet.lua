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

local Cauterize = require('cauterize')
local uv = require('uv')
local Packet = Cauterize.Fsm:extend()

function Packet:_init(host,port)

	-- create a udp socket
	self.udp = uv.new_udp()
	uv.udp_bind(self.udp, host, port)
  p('set up udp correctly',uv.udp_getsockname(self.udp))

  -- create a fake function so that the udp messages get sent to this
  -- function
  self.enabled[self.udp] = self.udp_recv

  self.state = 'disabled'
  self.packet = 'test packet' -- should be generated when needed
  self.node = 'node1' -- should be pulled from the config
end

-- set up blank states
Packet.disabled = {}
Packet.enabled = {}

function Packet:udp_recv(err, msg, rinfo, flags)
	-- this is to show that there are no packets left to read?
	-- kind of odd
	if msg == nil then return end

	-- notify all nodes that they are still online.
	local who,nodes = self:parse(msg)
	for node in nodes do
		Cauterize.Fsm.cast(node,'up',who)
	end
end

function Packet:_destroy()
	uv.udp_recv_stop(self.udp)
	self.close(self.udp)
end

function Packet:parse(msg)
	error('not implemented yet')
end

function Packet.disabled:enable()
	self.state = 'enabled'
	assert(self:wrap(uv.udp_recv_start,self.udp) == self.udp)
	self._interval = self:send_interval("$self",1000,1000,'$cast',{'notify'})

	-- regenerate the list of nodes that we are interested in
	self:regen()

	return true
end

function Packet.enabled:notify()
	local count = 0
	local len = #self.nodes

	-- durring one notify interval we at max want to send max_broadcast
	-- packets
	while count < self.max_broadcast do

		-- if we ran out of nodes, lets grab a new list of nodes
		if len == 0 then
			len = self:regen()
		end

		-- send a packet to the remote server
		local who, host, port = unpack(table.remove(self.nodes,len))
		uv.udp_send(udp, self.packet, host, port)

		-- notify node that we are waiting for a response
		Cauterize.Fsm.cast(who,'start_timer',self.node)

		count = count + 1
		len = len - 1
	end
end

function Packet:regen()
	local ret = Cauterize.Server.call('store','fetch','node')
	assert(ret[1],ret[2])
	-- do I need to decode these?
	self.nodes = ret[2]
	return #self.nodes
end

function Packet.enabled:disable()
	self.state = 'disabled'
	self:cancel_timer(self._interval)
	uv.udp_recv_stop(self.udp)
	return true
end


return Packet