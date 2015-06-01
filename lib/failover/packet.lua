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
local log = require('logger')
local Packet = Cauterize.Fsm:extend()

function Packet:_init(host,port,node)

	-- create a udp socket
	self.udp = uv.new_udp()
	uv.udp_bind(self.udp, host, port)
  p('set up udp correctly',uv.udp_getsockname(self.udp))

  -- create a fake function so that the udp messages get sent to this
  -- function
  self.enabled[self.udp] = self.udp_recv

  self.state = 'disabled'
  self.packet = 'test packet' -- should be generated when needed
  self.node = node or '1' -- should be pulled from the config
  self.max_packets_per_interval = 2 -- should be pulled from the config
  self.nodes = {}
  self.nodes_in_last_interval = {}
  self.responses_sent = 0
end

-- set up blank states
Packet.disabled = {}
Packet.enabled = {}

function Packet:udp_recv(err, msg, rinfo, flags)
	-- this is to show that there are no packets left to read?
	-- kind of odd
	if msg == nil then return end

	-- notify all nodes of the state reported in the remote packet
	local who, nodes = self:parse(msg)
	for node,state in pairs(nodes) do
		Cauterize.Fsm.cast(node, state, who)
	end

	-- we got a response, lets add this node to the list of nodes that
	-- this it is up!
	Cauterize.Fsm.cast(who, 'up', self.node)

	-- now respond to the node that made the call
	if not self.nodes_in_last_interval[who] then
		uv.udp_send(self.udp, self.packet, rinfo.ip, rinfo.port)
		self.nodes_in_last_interval[who] = true
		self.responses_sent = self.responses_sent + 1
	end

end

function Packet:parse(msg)
	local who, nodes = nil, {}

	for idx in pairs(self.nodes) do
		nodes[idx] = 'up'
	end

	for down_node in string.gmatch(msg,"(%w+)") do
		if who == nil then
			who = down_node
		else
			nodes[down_node] = 'down'
		end
	end

	return who, nodes
end

function Packet.disabled:enable()
	self.state = 'enabled'
	assert(self:wrap(uv.udp_recv_start,self.udp) == self.udp)
	-- start sending broadcasts after 5 seconds to let this node catch
	-- up with the cluster state
	self._interval = self:send_interval("$self", 1000, 1000, '$cast',
		{'notify'})
	p('going to call',self.node)
	Cauterize.Fsm.call(self.node,'set_permenant_state','up')

	-- regenerate the list of nodes that we are interested in
	self:regen()

	return true
end

function Packet.enabled:notify()
	local packets_sent_during_last_interval = self.responses_sent
	local nodes_left = #self.pending_nodes

	self:generate_new_packet()

	-- durring one notify interval we at max want to send max_packets_per_interval
	-- packets
	while packets_sent_during_last_interval < 
			self.max_packets_per_interval do

		-- if we ran out of nodes, lets grab a new list of nodes
		if nodes_left == 0 then
			nodes_left = self:regen()
			if nodes_left == 0 then
				break
			end
		end

		-- send a packet to the remote server
		local who, host, port = unpack(table.remove(self.pending_nodes,
			nodes_left))
		if not self.nodes_in_last_interval[who] then
			log.debug('sending packet',self.packet,'to',who)
			uv.udp_send(self.udp, self.packet, host, port)

			-- notify node that we are waiting for a response
			Cauterize.Fsm.cast(who,'start_timer',self.node)
		end

		packets_sent_during_last_interval =
			packets_sent_during_last_interval + 1
		nodes_left = nodes_left - 1
	end

	self.nodes_in_last_interval = {}
	self.responses_sent = math.max(0,
		self.responses_sent - self.max_packets_per_interval)

end

function Packet:generate_new_packet()
	local names = {self.node}
	-- create a list of all nodes that are not up.
	for name in pairs(self.nodes) do
		if name ~= self.node then
			local ret = self.call(name,'get_state')
			if ret ~= 'up' then
				names[#names + 1] = name
			end
		end
	end
	self.packet = table.concat(names,':')
end

function Packet:add_node(node)
	p('adding node',node)
	assert(node.name,'missing node name')
	assert(node.host,'missing node host')
	assert(node.port,'missing node port')
	self.nodes[node.name] = node
	return true
end

function Packet:remove_node(node)
	self.nodes[node.name] = nil
end

function Packet:regen()
	self.pending_nodes = {}
	local count = 0
	for idx,node in pairs(self.nodes) do
		if node.name ~= self.node then
			count = count + 1
			self.pending_nodes[count] = {node.name,node.host,node.port}
		end
	end
	return count
end

function Packet.enabled:disable()
	self.state = 'disabled'
	self:cancel_timer(self._interval)
	uv.udp_recv_stop(self.udp)
	return true
end

function Packet:_destroy()
	uv.udp_recv_stop(self.udp)
	self:close(self.udp)
	self:cancel_timer(self._interval)
end

return Packet