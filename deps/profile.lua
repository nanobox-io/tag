-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   14 July 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------
exports.name = "pagodabox/profile"
exports.version = "0.1.0"
exports.description = 
  "simple profiling code"
exports.tags = {"profile"}
exports.license = "MIT"
exports.author =
    {name = "Daniel Barney"
    ,email = "daniel@pagodabox.com"}
exports.homepage = 
  "https://github.com/pagodabox/tag/blob/master/deps/profile.lua"

local uv = require('uv')
local profile = require('jit.profile')

local Profile = {}
local storage = {}
local groups = {}
local head = 1
local tail = 1
local group = uv.new_timer()
local truncate = uv.new_timer()
local running = false
function Profile.start(hrtz, group_timeout, truncate_timeout)
  if not running then
    running = true
    group_timeout = group_timeout or 1000
    truncate_timeout = truncate_timeout or 60000
    local every = math.floor(tostring(1000000 / hrtz))
    profile.start('i' .. every .. 'fl',function(thread, samples, vmstate)
      local key = profile.dumpstack(thread, "FZ;", -20)
      storage[key] = samples + (storage[key] or 0)
    end)
    uv.timer_start(group, group_timeout, group_timeout, function()
      groups[head] = storage
      head = head + 1
      storage = {}
    end)
    uv.timer_start(truncate, truncate_timeout, truncate_timeout, function()
      table.remove(groups,tail)
      tail = tail + 1
    end)
  end
end

function Profile.stop()
  assert('not yet implemented')
end

function Profile.dump(back, skip)
  back = head - 1 - (back or 10)
  skip = head - 1 - (skip or 0)
  local all = {}
  local total = 0
  for i = skip, back, -1  do
    local group = groups[i]
    if not group then
      break
    end
    back = back - 1
    for stack, count in pairs(group) do
      total = count + count
      all[stack] = count + (stack[stack] or 0)
    end
    if back == 0 then
      break
    end
  end
  return total, all
end

return Profile