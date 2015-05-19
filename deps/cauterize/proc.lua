-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   18 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Process = require('./lib/process')
local Proc = Process:extend()

function Proc.start(link)
	if link == nil then link = true end
	local ref = Process.next_ref()
	local opts = 
		{link = link
		,args = {current(),ref}}
	local pid = Proc:new("_start",opts)
	-- this should cause all processes that inheret from Proc to wait
	-- until the new process is started correctly.
	if recv({ref,'down'}) == 'down' then
		return nil
	else
		return pid
	end
end

function Proc:initialize()
	self.timeout = nil -- the next recv will timeout after this period
	self.need_stop = false -- flag to stop current process gracefully
end

-- default functions that children should overwrite
function Proc:_init() end
function Proc:_loop() end
function Proc:_destroy() end

function Proc:_stop()
	self.need_stop = true
end


-- basic RPC call that ensures a reponse or an error if the process
-- dies or is dead.
function Proc:_link_call(pid,type,...)
	local self = current()
	local ref = link(current(),pid)
	send(pid,type,{self,ref},{...})
	local msg = recv({ref,'down'})
	unlink(current(),ref)

	if typeof(msg) == 'table' and msg[1] == 'down' then
		error('process died')
	else
		-- I don't know if this should be unpacked by default or not
		return msg[2]
	end
end

-- respond to a _link_call request
function Proc:respond(ref,ret)
	local pid,ref = unpack(ref)
	send(pid,{ref,ret})
end

-- main loop function
function Proc:_start(parent,ref)
	-- i may want to do something here to see if we really need this
	-- process or not, check the return or not catch an error?
	self:_init()
	
	-- respond that we started sucessfully
	send(parent,ref)

	-- enter the main recv loop
	repeat
		local msg = Pid.recv(self.timeout)
		self.timeout = nil -- do we want to clear this out every time?
		self:_loop(msg)
	until self.need_stop
	
	self:_destroy()
end

return Proc