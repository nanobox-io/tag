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

local Object = require('core').object
local hrtime = require('uv').hrtime

local Pid = Object:entend()
local run_queue = {queue = {}}

function run_queue:enter(pid)
	queue[#queue + 1] = pid
end

function run_queue:length(pid)
	return #self.queue
end

function run_queue:next()
	return table.remove(self.queue,1)
end

local pids = {} -- all pids can be accessed by id
local registered_pids = {} -- you can reference pids by a name
local max_pids = 1000 -- this may need to be setable.
local newest_pid = 1 -- keep track of the last pid that was created
local running_pids = 0 -- this is how manny pids are currently running
local current_pid -- this is the current pid that is running
local ref = 0 -- we also create unique refs

function Pid:initialize(start,opts)
	local ref
	if type(start) ~= 'function' then
		error('unable to spawn pid without a starting function')
	end
	if opts and type(opts) ~= 'table' then
		error('bad options specified')
	end
	if running_pids >= max_pids then
		error('unable to spawn another pid, max pid limit reached')
	end
	running_pids = running_pids + 1
	self._mailbox = {}
	self._links = {}
	self._inverse_links = {}
	-- I may want to set the env for the 'start' function
	self._routine = coroutine.create(start)
	self._run_time = 0

	-- find the next available process identifier
	-- this could be optimized
	while pids[newest_pid] ~= nil do
		newest_pid = newest_pid + 1
		if newest_pid > max_pids then
			newest_pid = 0
		end
	end
	self._pid = newest_pid
	pids[newest_pid] = self
	if self.opts.link then
		ref = pid.link(self._pid,current_pid)
	end

	-- we add the pid to the run_queue
	run_queue:enter(self)

	-- and we pause this pid if we need to.
	local current = Pid.current()
	if current then
		current:check_suspend()
	end
	return self,ref
end

function Pid:step()
	current_pid = self._pid
	local start_time = hrtime()
	local ran, arg = coroutine.resume(self._routine)
	self._run_time = hrtime() - start_time
	current_pid = nil
	if ran and arg then
		self._timeout = timer.setTimeout(arg,function()
			self:send('timeout')
		end)
	end
	if coroutine.status(self._routine) == 'dead' then
		running_pids = running_pids - 1
		-- propogate links to pids that have linked to the process
		for ref,link in self._links do
			link:send({'down',ref,self._pid,arg})
			link:unlink(ref,false)
		end

		-- we are dead, lets free up our pid so that it can be reused
		pids[self._pid] = nil

		-- lets clear out all registered names
		for name in pairs(self._registered) do
			registered_pids[name] = nil
		end
	end
end

function Pid.step()
	local pid = run_queue:next()
	if pid then
		pid:step()
		return true
	else
		return false -- there is nothing left to run.
	end
end

function Pid:send(...)
	-- once we get selective recv working, it should be implemented here
	if self._timeout then
		timer.cancelTimer(self._timeout)
	end
	self._mailbox[#self._mailbox + 1] = {...}
	run_queue:enter(self)

	-- if we are in a process, we need to pause to let others go.
	local current = Pid.current()
	if current then
		current:check_suspend()
	else
		-- if we are not in a process, lets run another step.
		Pid.step()
	end
end

function Pid:check_suspend(timeout)
	-- this check needs to be smarter
	if run_queue:length() > 0 then
		-- make sure to requeue this process so that it can continue later
		run_queue:enter(self)
		local _,response = coroutine.yield(timeout)
		if response == 'exit' then
			error('killed')
		end
		return response
	end
end

function Pid:recv(timeout)
	-- we may want to suspend
	local response = self:check_suspend(timeout)

	-- we need to handle timeouts and selective receives
	if response == nil then
		return table.remove(self._mailbox,1)
	elseif response == 'timeout' then
		return 'timeout'
	else
		error('unknown return from suspension',response)
	end
end

function Pid.register(pid,name)
	if pids[pid] == nil then
		error 'unable to register dead pid'
	elseif registered_pids[name] and pids[registered_pids[name]] then
		error 'name is already registered'
	end
	registered_pids[name] = pid
	pids[pid]._registered[name] = true
end

function Pid.unregister(name)
	local pid = registered_pids[name]
	registered_pids[name] = nil
	if pid then
		if pids[pid] then
			pids[pid]._registered[name] = nil
		end
	end
end

function Pid.current()
	return current_pid
end

function Pid.send(pid,...)
	local process
	if type(pid) == 'number' then
		process = pids[pid]
	elseif type(pid) == 'string' then
		process = registered_pids[pid]
	elseif type(pid) == 'table' then
		error('sending to a remote is not supported yet')
	end

	if process then
		process:send(...)
	end
end

function Pid.link(from,to)
	if pids[to] == nil then
		error('pid is already dead')
	end
	ref = ref + 1
	if pids[from] == nil and pids[to] then
		pids[to]:send({'down',ref,from})
	else
		pids[from]._links[ref] = to
		pids[to]._inverse_links[ref] = from
	end
	return ref
end

function Pid:unlink(ref,clear)
	local to = self._links[ref]
	if to then
		self._links[ref] = nil
		to._inverse_links[ref] = nil
		if clear then
			-- we need to clear out the mailbox
		end
	else
		error('no matching link found')
	end
end

function Pid.unlink(from,ref)
	local pid = pids[from]
	if pid then
		pid:unlink(ref,true)
	end
end

function pid:exit()
	coroutine:resume(self._routine,'exit')
end

function Pid.exit(pid)
	local pid = pids[pid]
	if pid then
		pid:exit()
	end
end

return Pid