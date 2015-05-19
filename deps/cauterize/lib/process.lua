-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :  15 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Object = require('core').Object
local Pid = require('./pid')
local Link = require('./link')
-- local Mailbox = require('./mailbox')
local Name = require('./name')
local Ref = require('./ref')
local Reactor = require('./reactor')
local RunQueue = require('./run_queue')

local Process = Object:extend()

-- we only want to return a pid when we create a new process
function Process:new(...)
	local pid = Object.new(self,...)
	return pid._pid
end

function Process:initialize(start,opts)
	-- a function or a string that maps to a member function on the
	-- current object can be passed in to start the process
	if type(start) ~= 'function' and type(self[start]) ~= 'function' then
		error('unable to spawn pid without a starting function')
	end
	-- set some defaults
	if not opts then 
		opts = {link = true,args = {}} 
	elseif type(opts) ~= 'table' then
		error('bad options specified')
	end
	if not opts.args then opts.args = {} end

	-- normal is a pid exiting. this is the default
	self._crash_reason = 'normal'

	-- check if a pid is available. throws an error if one is not
	Pid.available()

	-- if there is a name for this process, see if the name is taken.
	if opts.register_name and opts.name and 
		Name.lookup(opts.name) ~= nil then
			error('name is already taken')
	end

	-- Nothing should fail from here on out.

	-- create a new mailbox
	self._mailbox = require('./mailbox'):new()

	-- create the coroutine that is the process
	if type(start) == 'function' then
		self._routine = coroutine.create(start)
	else
		self._routine = coroutine.create(function()
			self[start](unpack(opts.args))
		end)
	end

	-- track how long this process has been on CPU
	self._run_time = 0

	-- assign a pid to the new process
	self._pid = Pid.next()
	Pid.enter(self._pid,self)

	-- link the new process to the current process
	if opts.link and Reactor.current_pid then
		Link.link(self._pid,Reactor.current_pid)
	end

	-- set up the name for this process
	if opts.register_name and opts.name then
		Name.register(self._pid,opts.name)
	end

	-- should the next two really happen here?
	-- or should it be somewhere else?

	-- we add the pid to the run_queue
	RunQueue:enter(self)

	-- and we pause this pid if we need to.
	local current = Reactor.current()
	if current ~= nil then
		pids[current]:check_suspend()
	end
end

function Process:destroy()
	local pid = self._pid
	Name.clean(pid)
	Link.clean(pid,self._crash_reason)
	Pid.remove(pid)
end

function Process:exit()
	error('exit')
end

return Process