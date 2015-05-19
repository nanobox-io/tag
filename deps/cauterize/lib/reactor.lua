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
local hrtime = uv.hrtime
local RunQueue = require('./run_queue')
local Pid = require('./pid')
local Object = require('core').Object

local Reactor = Object:extend()
local current_pid = nil

function Reactor:initialize()
	-- I don't know if I need to set anything up yet.
end

-- enter is the entry into the cauterize project. it handles all the
-- messy evented to sync translation, running of processes, timeouts,
-- and everything else
function Reactor:enter()
	local loop = uv.loop_init()
	-- i need to do something to get the event loop to run something
	-- maybe a timer?
	uv.run(loop,'default')

	-- we will only get here once the program is shutting down
	uv.loop_close(loop)
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

function Reactor:_step(process)
	-- if the process is waiting to timeout, we stop the timer.
	if process._timer then
		cancel_timer(process._timer)
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
			if typeof(args) == "table"
					and typeof(args[1]) == "number"
					and args[1] > 0 then
				-- the process is waiting for something in a timeout
				-- unless it is just timing out....
				process._timer = send_after(process._pid,unpack(args))
			elseif args ~= nil then
				-- if the process has a bad timeout value, lets kill it
				process:exit('negative timeouts are not valid')
				-- and let the clean up routine run
				more = false
			else
				-- everything else should just be the process waiting for a
				-- message to arrive without a timeout
			end
		elseif info == "send" and args ~= nil then
			send(unpack(args))
		else
			process:exit('invalid yeild value')
			more = false
		end
	end
	if not more then
		-- the process is dead, set the crash message
		process._crash_message = info
		-- and perform clean up on the process
		process:clean()
	
	else
		-- if there is more, lets requeue the process
		RunQueue:enter(process)
	end
end

-- cancel a timeout timer
local function cancel_timer(timer)
	if timer then
		uv.timer_stop(timer)
		uv.close(timer)
	end
end

-- send a message to a process
local function send(pid,...)
	local process = Pid.lookup(pid)
	if process then
		-- add the message to the mailbox, will return true if a match
		-- found
		if process.mailbox:insert(...) then
			-- add the process to the list of things to run
			RunQueue:enter(process)
		end
	end
end

-- send a message to a process after a period of time has passed
local function send_after(pid,timeout,...)
	local args = {...}
	if timeout == 0 then
		send(pid,args)
	else
		local timer = uv.new_timer()
		local function ontimeout()
			uv.timer_stop(timer)
			uv.close(timer)
			send(pid,args)
		end
		uv.timer_start(timer, timeout, 0, ontimeout)
		return timer
	end
end

return Reactor:new()
