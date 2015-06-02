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
local Pid = require('./pid')
local Wrap = {}

local wraps = {}

-- wrap a function to send messages to a process
function Wrap.enter(ref)
  wraps[ref] = true
end

function Wrap.close(ref)
  if wraps[ref] then
    wraps[ref] = nil
    uv.close(ref)
  end
end

function Wrap.empty()
  for ref in pairs(wraps) do
    uv.close(ref)
  end
  wraps = {}
end

return Wrap