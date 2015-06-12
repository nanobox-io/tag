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
local Group = {}
local groups = {}

-- map a key with a pid so that the pid can be looked up later from
-- from the key
function Group.join(pid,name)
  local process = Pid.lookup(pid)
  if process then
    local group = groups[name]
    if not group then
      group = {}
      groups[name] = group
    end
    group[pid] = true
    process._groups[name] = true
  else
    error('unable to register a dead pid')
  end
end

function Group.leave(pid,name)
  local process = Pid.lookup(pid)
  if process then
    local group = groups[name]
    if group then
      group[pid] = nil
      process._groups[name] = nil
   end
  end
end

function add_group_to_members(members,name,count,is_present)
  local group = groups[name]
  if group then
    for pid in pairs(group) do
      if not is_present[pid] then
        is_present[pid] = true
        members[count] = pid
        count = count + 1
      end
    end
  end
  return count
end

function Group.get(name)
  local members = {}
  local is_present = {}
  local count = 1
  if type(name) == 'table' then
    for _,name in pairs(name) do
      count = add_group_to_members(members,name,count,is_present)
    end
  else
    count = add_group_to_members(members,name,count,is_present)
  end
  return members
end

-- clean up any mapping when the process exits
function Group.clean(pid)
  local process = Pid.lookup(pid)
  if process then
    for name,_ in pairs(process._groups) do
      groups[name][pid] = nil
    end
  end
end

function Group.empty()
  groups = {}
end

return Group