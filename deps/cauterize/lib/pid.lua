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
local max_pids = 10


-- this could be better. its needs to take into account service
-- reboots
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
	return pids[pid]
end

function Pid.remove(pid)
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

return Pid