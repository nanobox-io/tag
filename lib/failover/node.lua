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
local Name = require('cauterize/lib/name')
local log = require('logger')
local Node = Cauterize.Fsm:extend()

function Node:_init(config)
	self.state = 'down'
	self.quorum = config.quorum -- this should be computed
	self.timeout =  config.timeout or 1000
	self.reports = {}
	self.timers = {}
	Name.register(self:current(),config.name)
end

-- set up some states
Node.down = {}
Node.up = {}


-- we only want to check if we need to change states if up is called
-- in the down state or down in the up state.
function Node.down:up(who)
	self:set(who,true)
	self:check_quorum()
end

function Node.up:down(who)
	self:set(who,false)
	self:check_quorum()
end

-- up in up and down in down can't change the state
function Node.up:up(who)
	self:set(who,true)
end

function Node.down:down(who)
	self:set(who,false)
end

function Node:set(who,value)
	-- cancel a timer if one was created
	p('set',who,value,self.timers[who])
	if self.timers[who] then
		self:cancel_timer(self.timers[who])
	end
	self.reports[who] = value
end

-- we are going to be waiting for this node to respond, start a timer
-- so that if it doesn't respond in time we will automatiacally mark
-- this node as down
function Node.up:start_timer(who)
	p('starting timer',self.timeout,who)
	self.timers[who] = self:send_after(self:current(),
		self.timeout, '$cast', {'down', who})
	p('got timers',self.timers)
end

function Node:get_state()
	return self.state
end

-- check if we have enough of a quorum to change state
function Node:check_quorum()
	local up = 0
	-- count unique nodes that report that this node is up or down
	-- no report received is the same as a down report
	for _,report in pairs(self.reports) do
		if report == true then
			up = up + 1
		end
	end

	-- we need a quorum to aggree for the state to change
	if up >= self.quorum then
		self:change_state('up')
	else
		-- this is also a quorum of nodes 
		self:change_state('down')
	end
end

-- only change state if the new_state is different from the current
-- state
function Node:change_state(new_state)
	if self.state ~= new_state then
		self.state = new_state
		log.warning('node changed state',new_state)
		-- TODO notify everyone who wants a notification
	end
end

return Node