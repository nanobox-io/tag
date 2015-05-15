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

local Pid = require('./pid.lua')
local Object = require('core').object
local hrtime = require('uv').hrtime

local Supervisor = Object:entend()

function Supervisor:initialize()
	self._children = {}
	self._lookup = {}
end

function Supervisor:manage(child,opts)
	if not opts.restart then opts.restart = 
		{kill = 'me'
		,die = 5
		,every = 10}
	else
		if not opts.restart.kill then opts.restart.kill = 'me' end
		if not opts.restart.die then opts.restart.die = 5 end
		if not opts.restart.every then opts.restart.every = 10 end
	end
	if not opts.args then opts.args = {} end
	if not opts.type then opts.type = 'worker' end

	local pid,ref = Pid:new(child,{link = true},unpack(opts.args))
	
	-- do we need to maintin a two way mapping?
	Pid.link(Pid.current(),pid)

	self._children[#self._children +1 ] = 
		{pid = pid
		,deaths = {}
		,opts = opts}
	self._lookup[ref] = #self._children

end

-- these are empty defaults
function Supervisor:_manage() end
function Supervisor:_init() end

function Supervisor:start(...)
	self:_init(...)
	self:_manage()
	while true do
		local msg = self:recv()
		-- this should be a child dying.
		local type,ref,pid,arg = unpack(msg)
		if type == 'down' then
			local idx = self._lookup[ref]
			local child = self._children[idx]
			if child.pid._pid == pid then
				local now = hrtime()
				
				local new_deaths = {}
				local count = 1
				-- we are only interested in deaths that happened within the
				-- last every seconds
				-- only count those ones.
				now = now - child.opts.restart.every * 1000000000
				for _,prev in ipairs(child.deaths) do
					if prev >= now then
						count = count + 1
						new_deaths[#new_deaths + 1] = prev
					end
				end

				if count >= child.opts.restart.die then
					-- we need to kill all children, and then die our selves.
					self.restart_all()
					error('hit max restart frequency')
				else
					child.deaths[#child.deaths + 1] = now
					child.deaths = new_deaths
					-- we need to run the restart strategy
					self['restart_'..child.opts.kill](idx)
				end
				
				-- do I need to send a notification somewhere?
			else
				error('unknown message',msg)
			end
		else
			error('unknown message recevied',msg)
		end
	end
end