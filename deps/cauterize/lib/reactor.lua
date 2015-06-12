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
local os = require('os')
local hrtime = uv.hrtime
local RunQueue = require('./run_queue')
local Pid = require('./pid')
local Ref = require('./ref')
local Name = require('./name')
local Timer = require('./timer')
local Wrap = require('./wrap')
local Group = require('./group')
local Object = require('core').Object

local Reactor = Object:extend()
local reactor = nil
local current_pid = nil

function Reactor:initialize()
  self._idler = nil -- we run all process as an idler
  self._ilding = false -- are we currently idling
end

-- enter is the entry into the cauterize project. it handles all the
-- messy evented to sync translation, running of processes, timeouts,
-- and everything else
-- it should never exit, unless continue has been set, in which case
-- it will do its best to clean everything out for a new run
function Reactor:enter(fun)

  -- we need to avoid require loop dependancies
  local init = require('./process'):new(function(env)
    -- do we need to do some setup stuff?
    fun(env)
    -- what about teardown stuff?
  end,{name = 'init',register_name = true})

  -- start the idler running
  self:start_idle()

  -- this should cause this function to block until there is nothing
  -- else to work on
  repeat
    local events = uv.run()
  until not events

  --now exit the process
  if not (self.continue == true) then
    -- close the idler handle
    uv.close(self._idler)
    -- exit the process
    os.exit(0)
  else

  end

  self:clean()

  -- what about handles?
  p('io',Reactor.io_count())
  assert(Reactor.io_count() == 0,'still waiting on handles')
end

function Reactor:clean()
  -- clear out everything
  RunQueue:empty()
  Name.empty()
  Pid.empty()
  Ref.reset()
  Timer.empty()
  Wrap.empty()
  Group.empty()
end

function Reactor:start_idle()
  if not self._ilding then
    self._idler = uv.new_idle()
    uv.idle_start(self._idler,function()
      assert(Reactor.io_count() >= 0,'_io_wait was not right')
      -- we should only do this for a specific amount of time
      repeat until not self:step()
      assert(Reactor.io_count() >= 0,'_io_wait was not right after loop')

      -- disable the idler to let other things run
      uv.idle_stop(self._idler)
      uv.close(self._idler)
      self._ilding = false
    end)
    self._ilding = true
  end
end

-- count all the io that we are waiting for
function Reactor.io_count()
  return Timer.running()
end

function Reactor.current()
  return current_pid
end

-- step enters one process and runs until that process is suspended
function Reactor:step()
  local process = RunQueue:next()
  if process then
    self:_step(process)
  end
  return RunQueue:can_work()
end

-- just an internal function so that during testing we can bypass the
-- RunQueue
function Reactor:_step(process)
  -- set the current_pid so that it is available in the coroutine
  current_pid = process._pid

  -- we track how long this process has run
  local start = hrtime()
  -- we let the process perform one step until it is paused
  local more,info,args = coroutine.resume(process._routine,
    process._ret_args)
  -- track how long it was on CPU, or at least how long it took
  -- the coroutine.resume to finish running
  process._run_time = process._run_time + hrtime() - start

  -- we no longer need this set
  current_pid = nil

  -- a list of valid commands
  local valid = 
    {pause = true
    ,send = true
    ,wrap = true
    ,yield = true}

  if more and info then
    if valid[info] then
      -- run the function
      args = args or {}
      local ret,ret_value = Reactor[info](process._pid,unpack(args))
      if ret then
        RunQueue:enter(process)
      end
      process._ret_args = ret_value
    else
      error('invalid yield command: ' .. info)
    end
  end

  if not more then
    -- the process is dead, set the crash message
    process._crash_message = info
    -- and perform clean up on the process
    local sent = process:destroy()
    -- sent is a list of all processes that received messages because
    -- of links, they may need to be requeued.
    for _,link in pairs(sent) do
      if link._timer then
        uv.timer_stop(link._timer)
        uv.close(link._timer)
        link._timer = nil
      end
      RunQueue:enter(link)
    end
    if info ~= 'normal' then
      p('process died',process._pid,info)
    end
  end
end

-- causes the current process to wait for a message to arrive
function Reactor.pause() 
  return false
end

-- sends a message from the current process
function Reactor.send(current,pid,interval,timeout,...)
  local is_group,is_remote = false,false
  -- convert a name into a pid
  if type(pid) == 'string' then
    if pid == "$self" then
      pid = current
    end
  elseif type(pid) == 'table' then
    if pid[1] == 'group' then
      assert(type(pid[2]) == 'string','missing group name')
      is_group = true
    elseif pid[2] == 'remote' then
      error('sending to a remote is not supported yet')
    else
      error('unsupported pid type')
    end
  end
  
  if timeout > 0 then
    local timer = Timer.new(interval,timeout,Reactor.send,current,pid,
      interval,0,...)
    return true, timer
  else
    local need_to_start = false

    if is_group then
      local members = Group.get(pid[2])
      for i = 1, #members do
        -- if the message comes from a member of the group, only send
        -- it to the other members
        if current ~= members[i] then
          need_to_start = Reactor._send(members[i],...) or need_to_start
       end
      end
    elseif is_remote then
      need_to_start = Reactor._send(pid[2],...)
    else
      if Reactor._send(pid,...) then
        reactor:start_idle()
       end
    end
    if need_to_start then
      reactor:start_idle()
    end
  end
  return true
end

function Reactor._send(pid,...)
  if type(pid) == 'string' then
    pid = Name.lookup(pid)
  end
  local process = Pid.lookup(pid)
  if process then
    -- add the message to the mailbox, will return true if a match
    -- found
    if process._mailbox:insert(...) then
      -- add the process to the list of things to run
      RunQueue:enter(process)
      return true
    end
  end
end

-- causes the current process to be put at the back of the RunQueue
function Reactor.yield()
  return true
end

-- wrap an async function call to send messages to the process
function Reactor.wrap(current,fun,...)
  local ref
  local args = {...}
  local handle
  local values = {}

  -- setup the callback function
  args[#args + 1] = function(...)
    local process = Pid.lookup(current)
    if process then
      if process._mailbox:insert(ref,...) then
        RunQueue:enter(process)
        -- start the idler if needed
        reactor:start_idle()
      end
    end
  end

  -- can this return an error?
  ref = fun(unpack(args))
  if ref == 0 then -- the call was sucessfull
    -- grab the handle?
    ref = args[1]
  end
  Wrap.enter(ref)
  return true,{ref}
end

-- warp an io stream to send messages
function Reactor.stream()
  error('not yet implemented')
end

reactor = Reactor:new()

return reactor