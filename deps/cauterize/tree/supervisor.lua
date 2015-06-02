-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   15 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local instanceof = require('core').instanceof
local Server = require('./server')
local Proc = require('./proc')
local uv = require('uv')
local hrtime = uv.hrtime

local Supervisor = Server:extend()

function Supervisor:_init()
  self.count = 0
  self._children = {}
  self._deaths = {}
  self._maps = {}
  self._pids = {}
  self.restart_strategy = 'one'
  self:_manage()
  -- now I need to start up all child processes
  for idx,child in pairs(self._children) do
    self:start_child(child,idx)
  end
end

function Supervisor:manage(child,opts)
  if not instanceof(child,Proc) then
    error('can not supervise a process that is not based on \'proc\'')
  end
  if type(opts) == 'string' then
    opts = {type = opts}
  end
  if not opts then opts = {} end
  if not opts.name  then 
    self.count = self.count + 1
    opts.name = "child_".. self.count
  end
  if not opts.restart then opts.restart = 
    {count = 5
    ,every = 10}
  else
    if not opts.restart.count then opts.restart.count = 5 end
    if not opts.restart.every then opts.restart.every = 10 end
  end
  if not opts.type then opts.type = 'worker' end
  if not opts.args then opts.args = {} end

  -- store off the child to start
  opts.class = child

  -- this needs to be different. we need to be able to dynamically
  -- start and stop children
  local idx = #self._children +1 
  self._children[idx] = opts
  self._deaths[idx] = 0

  -- so that calls can be chained
  return self
end

function Supervisor:start_child(child,idx)
  -- catch an error if the child fails to start
  local fun = function()
    local opts = self._children[idx]
    local pid,link = child.class:new(self:current(),unpack(opts.args))
    self._maps[link] = {idx,pid}
    self._pids[idx] = pid
    -- do we need to link from parent to child to kill the child if the
    -- parent exits?
    -- TODO: probably
  end
  
  -- the child failed to start
  if not xpcall(fun,p) then
    self:check_down(idx)
  end
  
end

function Supervisor:stop()
  -- stop all processes managed by this supervisor
  self:restart_rest(1,true)
  -- now stop this supervisor
  self._stop()
end

function Supervisor:clean(child_id)
  self._deaths[child_id] = self._deaths[child_id] - 1
end

function Supervisor:down(ref,reason)
  local idx,pid = unpack(self._maps[ref])
  
  -- its now invalid anyways
  self._maps[ref] = nil
  self._pids[idx] = nil
  
  -- check if the process has been down too much
  self:check_down(idx)
end

function Supervisor:check_down(idx)
  local child = self._children[idx]
  assert(child,"missing child")

  -- record this death
  self._deaths[idx] = self._deaths[idx] + 1

  -- if we have died to manny times
  if self._deaths[idx] >= child.restart.count then
    -- we need to kill all children
    for _,pair in pairs(self._maps) do
      self:exit(pair[2])
    end

    -- and then kill ourself
    self:exit()
  else
    -- send a message to decrement the child death count
    self:send_after(self:current(),child.restart.every * 1000,'clean',idx)

    -- and run the restart strategy
    self['restart_' .. self.restart_strategy](self,idx)
  end
end

function Supervisor:restart_one(child_id)
  self:start_child(self._children[child_id],child_id)
end

function Supervisor:restart_rest(child_id,skip)
  for idx = child_id,#self._children do
    local pid = self._pids[idx]
    if pid then
      if self._children[idx].type == 'supervisor' then
        -- should wait for the supervisor to exit
        self:call(pid,'stop')
      else
        -- this may be too sudden
        self:exit(pid)
      end
    end
    if skip then
      self:start_child(self._children[idx],idx)
    end
  end
end

function Supervisor:restart_all()
  self:restart_rest(1)
end

function Supervisor:restart_remove(child_id)
  self._children[child_id] = nil
  self._deaths[child_id] = nil
end

return Supervisor