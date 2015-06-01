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

local Pid = {}

local pids = {}
local next_pid = 1
local total_pids = 0
local max_pids = 100


-- this could be better. its needs to take into account service
-- reboots and pid reuse.
function Pid.next()
	Pid.available()
	while pids[next_pid] ~= nil do
		next_pid = next_pid + 1
		if next_pid > max_pids then
			next_pid = 1
		end
	end
	return next_pid
end

-- throws an error if there are no available pids
function Pid.available()
	if total_pids >= max_pids then
		error('unable to create new process, max_pids reached')
	end
end

-- get a process from the pid
function Pid.lookup(pid)
	-- just incase nothing was passed in.
	if pid then
		return pids[pid]
	end
end

-- remove a pid from the mapping
function Pid.remove(pid)
	-- if the last pid died, we don't want to reuse the pid immediately
	if pid == next_pid then
		next_pid = next_pid + 1
	end

	pids[pid] = nil
	total_pids = total_pids - 1
end

function Pid.enter(pid,process)
	if pids[pid] == nil then
		pids[pid] = process
	else
		error('pid is already taken')
	end
end

function Pid.empty()
	pids = {}
	total_pids = 0
	next_pid = 1
end

return Pid