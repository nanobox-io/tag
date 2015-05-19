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

local Server = require('./server')
local Fsm = Server:extend()

-- we don't need these from Server
Fsm.call = nil
Fsm.cast = nil

function Fsm.send_event(pid,...)
	send(pid,'$cast',...)
end

function Fsm.send_all_event(pid,...)
	send(pid,'$cast_all',...)
end

function Fsm.send_event_sync(pid,...)
	Fsm._link_call(pid,'$call',...)
end

function Fsm.send_all_event_sync(pid,...)
	Fsm._link_call(pid,'$call_all',...)
end

function Fsm:initialize()
	self.state = nil -- this is the current state of the state machine
end

-- default event handler
function Fsm:event() end

function Fsm:_loop(msg)
	local type,ref,args = unpack(msg)

	if type == '$cast_all' then
		self:_perform('event',args,nil)
	elseif type == '$cast' then
		self:_perform(self.state,args,nil)
	elseif type == '$call_all' then
		self:_perform('event',args,ref)
	elseif type == '$call' then
		self:_perform(self.state,args,ref)
	else
		self:_perform('handle_message',msg,nil)
	end
end

return Fsm