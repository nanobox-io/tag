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
local Mailbox = require('./mailbox')
local Timer = require('./timer')
local Name = require('./name')
local Ref = require('./ref')
local Wrap = require('./wrap')
local Reactor = require('./reactor')
local RunQueue = require('./run_queue')

local Process = Object:extend()

-- we only want to return a pid when we create a new process
function Process:new(...)
	local pid = Object.new(self,...)
	return pid._pid,pid._parent_link
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

	-- create a new mailbox, for some reason require doesn't work.
	-- probably because of require dependancies.
	self._mailbox = Mailbox:new()
	self._names = {}
	self._links = {}
	self._inverse_links = {}

	-- create the coroutine that is the process
	local process = self
	if type(start) == 'function' then
		self._routine = coroutine.create(function()
			-- we do this to preserve send,recv,exit functions.
			start(process,unpack(opts.args))
			error('normal',0)
		end)
	else
		self._routine = coroutine.create(function()
			self[start](self,unpack(opts.args))
			error('normal',0)
		end)
	end

	-- track how long this process has been on CPU
	self._run_time = 0

	-- assign a pid to the new process
	self._pid = Pid.next()
	Pid.enter(self._pid,self)

	-- link the new process to the current process
	if opts.link and Reactor.current() then
		self._parent_link = Link.link(self._pid,Reactor.current())
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
		self:yield()
	end
end

function Process:destroy()
	local pid = self._pid
	Name.clean(pid)
	local sent = Link.clean(pid,self._crash_reason)
	Pid.remove(pid)

	-- we need to get this working correctly.
	if self._pid == Reactor.current() then
		self:exit()
	end

	return sent
end

function Process:exit(pid,err)
	if not err and pid then 
		err = pid
		pid = nil
	end
	if not err then err = 'exit' end

	local current = Reactor.current()
	if current == nil then
		self._crash_reason = err
		-- and now I need to end the coroutine
		coroutine.resume(self._routine,err)
	elseif pid == nil or pid == current then
		error(err)
	else
		-- I need to terminate a different process
		self:send(pid,'$exit')
	end
end

-- send a message to a process after time has passed
function Process:send_after(pid,time,...)
	if type(time) ~= "number" or time < 0 then
		error("invalid interval")
	end

	-- string could be a registered name
	if type(pid) ~= "number" and type(pid) ~= 'string' then
		error('invalid pid')
	end

	if self and not self._mailbox then 
		self = Pid.lookup(Reactor.current())
	end

	-- I still need to check if the msg being sent is nil
	return self._mailbox:yield("send",{pid,time,...})
end

-- cancel the sending of a message that may have been sent
function Process:cancel_timer(timer)
	if timer then
		Timer.cancel(timer)
	end
end

-- send a message to a process
function Process:send(pid,...)
	self:send_after(pid,0,...)
end

-- receive a message from the mailbox
function Process:recv(...)
	return self._mailbox:recv(...)
end

function Process:yield()
	self._mailbox:yield('yield')
end

function Process:current()
	return Reactor.current()
end

-- we wrap an async function to be used inside of this coroutine
function Process:wrap(fun,...)
	return unpack(self._mailbox:yield('wrap',{fun,...}))
end

function Process:close(ref)
	Wrap.close(ref)
end

return Process