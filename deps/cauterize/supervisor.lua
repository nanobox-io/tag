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

local Server = require('./server.lua')
local uv = require('uv')
local hrtime = uv.hrtime

local Supervisor = Server:extend()

function Supervisor:initialize()
	self.count = 0
	self._children = {}
	self.strategy = 'me'
end

function Supervisor:manage(child,opts)
	if not opts then opts = {} end
	if not opts.name  then 
		self.count = self.count + 1
		opts.name = "child_".. self.count
	end
	if not opts.restart then opts.restart = 
		{die = 5
		,every = 10}
	else
		if not opts.restart.die then opts.restart.die = 5 end
		if not opts.restart.every then opts.restart.every = 10 end
	end
	if not opts.args then opts.args = {} end
	if not opts.type then opts.type = 'worker' end

	local pid = Pid:new(child,
		{register = opts.register_name,name = opts.name,link = true},
		unpack(opts.args))

	-- this needs to be different. we need to be able to dynamically
	-- start and stop children
	self._children[#self._children +1 ] = 
		{pid = pid
		,id = #self._children
		,deaths = {}
		,opts = opts}

	-- so that calls can be chained
	return self
end

-- these are empty defaults
function Supervisor:_manage() end
function Supervisor:_init() end

function Supervisor:clean(child_id)
	-- I need to look up the child,
	-- and then decrement its death counter
end

function Supervisor:down(ref,pid,arg)
	local child = self.children[pid]
	if child then
		p('child died because',arg)
		child.deaths = child.deaths + 1
		Pid.send_after(current(),child.opts.restart.every * 1000,'$cast','clean',child.idx)
		local purged = {}
		
		if child.deaths > child.max_restarts then
			-- we need to kill all children
			-- and then die our selves.
		else
			-- we need to restart the child with the restart strategey
			self["restart_" .. self.strategey](child.id)
		end
	else
		error('got bad down message')
	end
end

function Supervisor:restart_me(child_id)

end