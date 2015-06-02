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
    if process._timer then
      error('unable to enqueue process with an active timer')
    end
    process._enqueued = true
    self.queue[#self.queue + 1] = process
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

-- clear everything out of the queue
function RunQueue:empty()
  self.queue = {}
end

return RunQueue:new()