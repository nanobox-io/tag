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

local uv = require('uv')
local log = require('logger')
local Cauterize = require('cauterize')
-- local Json = require('Json')
local Plan = require('./plan')
local Name = require('cauterize/lib/name')
-- local Pg = require('cauterize/lib/pg')

local System = Cauterize.Fsm:extend()
local topologies = 
  {choose_one = true
  ,nothing = true
  ,replicated = true
  ,round_robin = true}

function System:_init(system)
  self.system = system
  self.state = 'disabled'
  self.node_id = Cauterize.Fsm.call('config', 'get', 'node_name')
  if topologies[self.system.topology] then
    self.topology = require('./topology/' .. self.system.topology)
  else
    error('unknown topology '..self.system.topology)
  end
  Name.register(self:current(), self.system.name)
  -- Pg.register(self:current(), 'system')

  
  self.apply_timeout = nil
  
  -- this should clear out everything that is currently on this node
  -- so that we don't have to deal with it being there when it should
  -- not be
  local elems = self:run('load')
  self.plan = Plan:new(elems)
  self._on = {}
  self:apply()
end

-- create the states for this Fsm
System.disabled = {}
System.enabled = {}

function System.disabled:enable()
  p('enabling system')
  self.state = 'enabled'
  self:regen()
end

function System.enabled:disable()
  self.state = 'disabled'
  self:regen()
end

function System:regen()
  p('called regen')
  if self.state == 'disabled' then
    -- clear everything out
    self._on = {}
  else
    -- i need to get the data stored in the system
    local ret = Cauterize.Server.call('store', 'fetch',
      self.system.name)
    assert(ret[1], 'unable to get data nodes for system', ret[2])

    -- divide it over the alive nodes in the system, and store the
    -- results for later
    self._on = self.topology(ret[2], self.nodes, self.node_id)
  end

  if self.apply_timeout then
    self:cancel_timer(self.apply_timeout[1])
    self:respond(self.apply_timeout[2],{false,'inturrupted'})
  end
  
  -- then run the plan after a set amount of time has passed
  -- we do this incase multiple changes in nodes being up/down come in
  -- a small amount of time and can be coalesed into a single change
  -- in the plan
  self.apply_timeout = {self:send_after('$self', 1000, '$call',
    {'apply'}, self._current_call),self._current_call}
end

-- run a set of changes to bring this system to the next step of the
-- plan
function System:apply()
  self.plan:next(self._on)
  local add, remove = self.plan:changes()
  for _, elem in pairs(add) do
    log.info('bringing up', self.system.name, elem.data)
    self:run('up', elem)
  end
  for _, elem in pairs(remove) do
    log.info('taking down', self.system.name, elem.data)
    self:run('down', elem)
  end
  log.info('system has stabalized', self.system.name)
  return {true}
end

-- run a script for an element of the system
function System:run(name, elem)
  if self.system[name] then
    local data
    if elem then
      data = elem.data
    end
    log.debug('going to run', self.system[name], data)
    local io_pipe = uv.new_pipe(false)
    
    local proc = self:wrap(uv.spawn, self.system[name],
      {args = 
        {data}
      ,stdio = 
        {io_pipe,io_pipe,2}})
    assert(self:wrap(uv.read_start, io_pipe) == io_pipe)
    local code
    local stdout = {}

    -- collect run information
    repeat
      local msg = self:recv({io_pipe,proc})
      if msg[1] == io_pipe then
        stdout[#stdout + 1] = msg[3]
      else
        code = msg[2]
        break
      end
    until false

    self:close(proc)
    self:close(io_pipe)
    log.debug('result of running script',code,stdout)
  end
end

-- notify this system that a node came online
function System:up(node)
  self.nodes[node] = true
  if node == self.nodes_id then
    Cauterize.Fsm.send(self:current(), 'enable')
  else
    self:regen()
  end
end

-- notify this system that a node went offline
function System:down(node)
  self.nodes[node] = false
  if node == self.nodes_id then
    Cauterize.Fsm.send(self:current(), 'disable')
  else
    self:regen()
  end
end

-- If we are not in the correct state, lets return an error
function System:enable()
  return {false, 'unable to enable system from state ' .. self.state}
end

function System:disable()
  return {false, 'unable to disable system from state ' .. self.state}
end

return System