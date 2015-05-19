-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :  19 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Object = require('core').Object
local RunQueue = Object:extend()


function RunQueue:initialize()
	self.queue = {}
end

-- add a process to the queue to that it will be processed
function RunQueue:enter(process)
	if not process._enqueued then
		process._enqueued = true
		self.queue[#self.queue] = process
	else
		-- maybe move it up the list?
	end
end

-- get the next process that needs to be run
function RunQueue:next()
	local process = table.remove(self.queue,1)
	if process then
		process._enqueued = false
	end
	return process
end

-- return if there is something that can be worked on
function RunQueue:can_work()
	return #self.queue > 0
end

function RunQueue:yeild()
	-- if we are in a process, and it needs to suspend, lets suspend it
end

return RunQueue:new()