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

local Pid = require('./pid')
local Name = {}
local registered = {}

-- map a key with a pid so that the pid can be looked up later from
-- from the key
function Name.register(pid,name)
  local process = Pid.lookup(pid)
  if process then
    if Pid.lookup(registered[name]) then
      error('name is already taken')
    else
      registered[name] = pid
      process._names[name] = true
    end
  else
    error('unable to register a dead pid')
  end
end

function Name.lookup(name)
  return registered[name]
end

-- unmap a name if it exists.
function Name.unregister(name)
  local pid = registered[name]
  registered[name] = nil
  local process = Pid.lookup(pid)
  if process then
    process._names[name] = nil
  end
end

-- clean up any mapping when the process exits
function Name.clean(pid)
  local process = Pid.lookup(pid)
  if process then
    for name,_ in pairs(process._names) do
      registered[name] = nil
    end
  end
end

function Name.empty()
  registered = {}
end

return Name