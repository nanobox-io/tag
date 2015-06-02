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

local Ref = require('./ref')
local Pid = require('./pid')
local Name = require('./name')
local Link = {}

-- sends the result of a link or monitor to the registered process
-- how does this requeue processes?
local function send_message(to,ref,kind,reason)
  if kind == "monitor" then
    return to._mailbox:insert(ref,'down',reason)
  elseif kind == "link" then
    return to._mailbox:insert(ref,'$exit',reason)
  else
    error("unknown link type "..kind)
  end
end


-- implementation of the link and monitor facade functions
local function link(from,to,kind)
  local ref = Ref.make()
  if type(from) == "string" then
    from = Name.lookup(from)
  end
  local from_p = Pid.lookup(from)
  local to_p = Pid.lookup(to)
  if not from_p then
    if to_p then
      send_message(to_p,ref,kind,'dead')
    else
      error('unable to ' .. kind .. ' a dead process')
    end
  elseif to_p then
    from_p._links[ref] = {kind,to}
    to_p._inverse_links[ref] = from
  else
    error('unable to ' .. kind .. ' a dead process')
  end
  return ref
end

-- monitor sends a message to the 'to' process when the 'from' process
-- finishes running
function Link.monitor(from,to)
  return link(from,to,'monitor')
end

-- link forcibly kills the 'to' process when the 'from' process has
-- finished running
function Link.link(from,to)
  return link(from,to,'link')
end


-- removes a link or monitor.
function Link.unlink(to,ref)
  local to_p = Pid.lookup(to)
  if to_p then
    local from = to_p._inverse_links[ref]
    local from_p = Pid.lookup(from)
    if from_p then
      assert(from_p._links[ref],"link was not set")
      from_p._links[ref] = nil
    end
    to_p._inverse_links[ref] = nil
  else
    error('unable to unlink from dead process')
  end
end

Link.unmonitor = Link.unlink


-- called when a process has finished running, this will propogate all
-- links and monitors to processes that have registered to receive the
-- messages.
function Link.clean(pid,reason)
  local process = Pid.lookup(pid)
  local sent = {}
  for ref,to in pairs(process._links) do
    local to_p = Pid.lookup(to[2])
    if to_p then
      if send_message(to_p,ref,to[1],process._crash_message) then
        sent[#sent + 1] = to_p
      end
    end
  end
  for ref,from in pairs(process._inverse_links) do
    local from_p = Pid.lookup(from)
    if from_p then
      from_p._links[ref] = nil
    end
  end
  -- return the list of pids that were sent to
  return sent
end

return Link