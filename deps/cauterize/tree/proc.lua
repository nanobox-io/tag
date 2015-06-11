-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   18 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Process = require('../lib/process')
local Ref = require('../lib/ref')
local Link = require('../lib/link')
local Pid = require('../lib/pid')
local Proc = Process:extend()

-- this should cause all processes that inheret from Proc to wait
-- until the new process is started correctly.
function Proc:new(parent,...)
  assert(parent ~= nil,'parent cannot be nil')

  -- set up some default options so that procs are started correctly
  local ref = Ref.make()
  local opts = 
    {link = true
    ,args = {parent,ref,...}}
  local pid,link = Process.new(self,"_start",opts)
  
  -- lookup the current process, and then have it recv a message
  -- kind of strange but it works
  if Pid.lookup(parent):recv({ref,link})[2] == 'down' then
    error('child failed to start')
  else
    return pid,link
  end
end

-- default functions that children should overwrite
function Proc:_init() end
function Proc:_loop() end
function Proc:_destroy() end

-- signal this proc that it needs to stop running gracefully
function Proc:_stop()
  self.need_stop = true
end


-- basic RPC call that ensures a reponse or an error if the process
-- dies or is dead.
function Proc:_link_call(pid,cmd,...)
  assert(type(pid) == 'string' or type(pid) == 'number',
    'bad pid in link_call ')

  -- look up the current process
  local current = self:current()
  local process = Pid.lookup(current)
  local args = {...}

  -- monitor the process that will be called, this will ensure a
  -- response is received
  local ref = Link.monitor(pid,current)
  local call_ref = Ref.make()
  
  -- send the process the message
  process:send(pid,cmd,args,{current,call_ref})
  -- recv the response or the error
  local msg = process:recv({ref,call_ref})

  -- unmonitor the process that was called
  Link.unmonitor(current,ref)

  -- check if we got a message, or if the called process died
  if type(msg) == 'table' and msg[1] == ref then
    error('process died in call',0)
  else
    assert(msg[1] == call_ref,"wrong message was returned")
    -- I don't know if this should be unpacked by default or not
    return msg[2]
  end
end

-- respond to a _link_call request
function Proc:respond(ref,ret)
  if ref ~= nil and ret ~= nil then
    local pid,ref = unpack(ref)
    self:send(pid,ref,ret)
 end
end

-- main loop function
function Proc:_start(parent,ref,...)
  self.recv_timeout = nil -- the next recv will timeout after this period
  self.need_stop = false -- flag to stop current process gracefully

  -- i may want to do something here to see if we really need this
  -- process or not, check the return or not catch an error?
  self:_init(...)
  
  -- respond that we started sucessfully
  self:send(parent,ref)

  -- enter the main recv loop
  local sucess
  repeat
    local msg = self:recv(nil,self.recv_timeout)
    self.recv_timeout = nil -- do we want to clear this out every time?
    if msg == nil then
      msg = {'timeout'}
    end
    sucess = {pcall(function() self:_loop(msg) end)}
    self.need_stop = self.need_stop or not sucess[1]
  until self.need_stop
  
  self:_destroy()

  if not sucess[1] then
    error(sucess[2])
  end
end

return Proc