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

local uv = require('uv')
local os = require('os')
local hrtime = uv.hrtime
local RunQueue = require('./run_queue')
local Pid = require('./pid')
local Ref = require('./ref')
local Name = require('./name')
local Object = require('core').Object

local Reactor = Object:extend()
local current_pid = nil

function Reactor:initialize()
	self._idler = uv.new_idle() -- we run all process as an idler
	self._io_wait = 0 -- count for how many io events we are waiting on
	self._ilding = false -- are we currently idling
end

-- enter is the entry into the cauterize project. it handles all the
-- messy evented to sync translation, running of processes, timeouts,
-- and everything else
-- it should never exit, unless continue has been set, in which case
-- it will do its best to clean everything out for a new run
function Reactor:enter(fun)

	-- we need to avoid require loop dependancies
	local init = require('./process'):new(function(env)
		-- do we need to do some setup stuff?
		fun(env)
		-- what about teardown stuff?
	end,{name = 'init',register_name = true})

	-- start the idler running
	self:start_idle()

	-- this should cause this function to block until there is nothing
	-- else to work on
	while self._io_wait > 0 or RunQueue:can_work() do
		uv.run("once")
		if not RunQueue:can_work() then
			uv.idle_stop(self._idler)
			self._ilding = false
		end	
	end

	--now exit the process
	if not (self.continue == true) then
		-- close the idler handle
		uv.close(self._idler)
		-- exit the process
		os.exit(0)
	else

	end

	-- clear out everything
	RunQueue:empty()
	Name.empty()
	Pid.empty()
	Ref.reset()

	-- what about handles?
	assert(self._io_wait == 0,'still waiting on handles')
end

function Reactor:start_idle()
	if not self._ilding then
		uv.idle_start(self._idler,function()
			assert(self._io_wait >= 0,"_io_wait was not right")
			-- we should only do this for a specific amount of time
			repeat until not self:step()
			assert(self._io_wait >= 0,"_io_wait was not right after loop")
		end)
		self._ilding = true
	end
end

function Reactor.current()
	return current_pid
end

-- step enters one process and runs until that process is suspended
function Reactor:step()
	local process = RunQueue:next()
	if process then
		self:_step(process)
	end
	return RunQueue:can_work()
end

-- just an internal function so that during testing we can bypass the
-- RunQueue
function Reactor:_step(process)
	-- if the process is waiting to timeout, we stop the timer.
	if process._timer then
		Reactor.cancel_timer(process._timer)
		process._timer = nil
		-- decrement so that when we are out of events we can end the loop
		self._io_wait = self._io_wait - 1
	end

	-- set the current_pid so that it is available in the coroutine
	current_pid = process._pid

	-- we track how long this process has run
	local start = hrtime()
	-- we let the process perform one step until it is paused
	local more,info,args = coroutine.resume(process._routine)

	-- track how long it was on CPU, or at least how long it took
	-- the coroutine.resume to finish running
	process._run_time = process._run_time + hrtime() - start

	-- we no longer need this set
	current_pid = nil

	if more and info then
		if info == "timeout" then
			if type(args) == "table"
					and type(args[1]) == "number"
					and args[1] > 0 then
				-- the process is waiting for something in a timeout
				-- unless it is just timing out....
				
				local dec = function() 
					self._io_wait = self._io_wait - 1
					self:start_idle()
					process._timer = nil
				end
				
				process._timer = Reactor.send_after(process._pid,dec,unpack(args))
				-- increment the counter so that we don't exit early
				self._io_wait = self._io_wait + 1

				-- we don't requeue this process
				return
			elseif type(args) == "table" and args[1] then
				-- if the process has a bad timeout value, lets kill it
				process:exit('negative timeouts are not valid')
				-- and let the clean up routine run
				more = false
			else
				-- everything else should just be the process waiting for a
				-- message to arrive without a timeout
				return
			end
		elseif info == "send" and args ~= nil then
			if args[2] == 0 then
				-- this need to be better
				table.remove(args,2)
				Reactor.send(unpack(args))
			else
				local dec = function() 
					self._io_wait = self._io_wait - 1
					self:start_idle()
					process._timer = nil
				end
				
				Reactor.send_after(table.remove(args,1),dec,unpack(args))
				-- increment the counter so that we don't exit early
				self._io_wait = self._io_wait + 1
			end
		elseif info == "pause" then
			-- pause causes the process to wait for a message to arrive
			return
		elseif into ~= "yield" then
			process:exit('invalid yield value')
			more = false
		end
	end
	if not more then
		-- the process is dead, set the crash message
		process._crash_message = info
		-- and perform clean up on the process
		local sent = process:destroy()
		-- sent is a list of all processes that received messages because
		-- of links, they may need to be requeued.
		for _,link in pairs(sent) do
			RunQueue:enter(link)
		end
		p('process died',process._pid,info)
	else
		-- if there is more, lets requeue the process
		RunQueue:enter(process)
	end
end

-- cancel a timeout timer
function Reactor.cancel_timer(timer)
	if timer then
		uv.timer_stop(timer)
		uv.close(timer)
	end
end

-- send a message to a process
function Reactor.send(pid,...)
	-- convert a name into a pid
	if type(pid) == 'string' then
		pid = Name.lookup(pid)
	end
	local process = Pid.lookup(pid)
	if process then
		-- add the message to the mailbox, will return true if a match
		-- found
		if process._mailbox:insert(...) then
			-- add the process to the list of things to run
			RunQueue:enter(process)
		else
			p('message did not match')
		end
	end
end

-- send a message to a process after a period of time has passed
function Reactor.send_after(pid,fun,timeout,...)
	local args = {...}
	if timeout == 0 then
		send(pid,args)
	else
		local timer = uv.new_timer()
		local function ontimeout()
			uv.timer_stop(timer)
			uv.close(timer)
			fun()
			Reactor.send(pid,unpack(args))
		end
		uv.timer_start(timer, timeout, 0, ontimeout)
		return timer
	end
end

return Reactor:new()
