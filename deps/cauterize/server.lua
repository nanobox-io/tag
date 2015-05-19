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

local Proc = require('./proc')
local Server = Proc:extend()

Server.call = Server._link_call
function Server.call(pid,...)
	Server._link_call(pid,'$call',...)
end


function Server.cast(pid,fun,...)
	send(pid,'$cast',fun,nil,{...})
end

-- default handler for unhandled 'call' and 'cast' messages
function Server:_unhandled() end

function Server:_perform(fun,args,ref)
	local ret = nil
	if typeof(self[fun]) == 'function' then
		-- should this allow multiple returns?
		ret = self[fun](unpack(args))
	else
		-- do we really want this functionality?
		ret = self._unhandled(fun,unpack(args))
	end
	if ref ~= nil then
		Server.respond(ref,ret)
	end
end

function Server:_loop(msg)
	local type,fun,ref,args = unpack(msg)
	if type == '$call' then
		self:_perform(fun,args,ref)
	elseif type == '$cast' then
		self:_perform(fun,args,nil)
	else
		self:_perform('handle_message',msg,nil)
	end
end

return Server