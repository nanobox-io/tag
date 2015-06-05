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
local ffi = require('ffi')
local log = require('logger')
local Cauterize = require('cauterize')
-- local Json = require('Json')
local Plan = require('./plan')
local util = require ('../util')
local Name = require('cauterize/lib/name')
local Group = require('cauterize/lib/group')

local System = Cauterize.Fsm:extend()
local topologies = 
  {choose_one = true
  ,nothing = true
  ,replicated = true
  ,round_robin = true}

function System:_init(name,system)
  -- this might need to be dynamic
  self.system = system

  self.state = 'disabled'
  self.node_id = util.config_get('node_name')
  if topologies[self.system.topology] then
    self.topology = require('./topology/' .. self.system.topology)
  else
    error('unknown topology '..self.system.topology)
  end
  self.name = name
  Name.register(self:current(), 'system-' .. name)
  Group.join(self:current(),'systems')

  
  self.apply_timeout = nil

  -- the the system needs to set it self up, it will have an install
  -- script
	self:run('install')

  -- this should clear out everything that is currently on this node
  -- so that we don't have to deal with it being there when it should
  -- not be
  local elems = self:run('load')
  self.nodes = {}
  self.node_order = {}
  self.plan = Plan:new(elems)
  self._on = {}
  self:apply()
end

-- create the states for this Fsm
System.disabled = {}
System.enabled = {}

function System.disabled:enable()
  log.info('enabling system',self.name)
  self.state = 'enabled'
  self:run('enable')
  self:regen()
end

function System.enabled:disable()
  self.state = 'disabled'
  self._on = {}
  if self.apply_timeout then
    self:cancel_timer(self.apply_timeout[1])
    self:respond(self.apply_timeout[2],{false,'inturrupted'})
  end
  self:apply()
  self:run('disable')
end

function System:regen()

  local ret = System.call('store','fetch','system-' .. self.name)
  -- divide it over the alive nodes in the system, and store the
  -- results for later
  self._on = self.topology(ret[2], self.node_order, self.nodes,
    self.node_id)

  if self.apply_timeout then
    self:cancel_timer(self.apply_timeout[1])
    self:respond(self.apply_timeout[2],{false,'inturrupted'})
  end
  
  -- then run the plan after a set amount of time has passed
  -- we do this incase multiple changes in nodes being up/down come in
  -- a small amount of time and can be coalesed into a single change
  -- in the plan
  self.apply_timeout = {self:send_after('$self', 2000, '$call',
    {'apply'}, self._current_call),self._current_call}
end

-- run a set of changes to bring this system to the next step of the
-- plan
function System:apply()
  self.plan:next(self._on)
  local add, remove = self.plan:changes()
  for _,array in pairs({add,remove}) do
    for idx,elem in pairs(array) do
      array[idx] = elem:get_data()
    end
  end

  log.info('applying new system',{'add',add},{'remove',remove})
  for _, elem in pairs(add) do
    log.debug('adding', self.name, elem)
    self:run('add', elem)
  end
  for _, elem in pairs(remove) do
    log.debug('removing', self.name, elem)
    self:run('remove', elem)
  end
  log.info('system has stabalized', self.name)
  return {true}
end

-- run a script for an element of the system
function System:run(name, elem)
  local script = self.system[name]
  if script then
    local data
    if elem then
      data = elem
    end
    log.info('going to run', script, data)
    local io_pipe = uv.new_pipe(false)
    
    local proc = self:wrap(uv.spawn, script,
      {args = 
        {data,'testing'}
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
    if code == 0 then
      log.debug('result of running script',code,stdout)
    else
      log.warning('result of running script',code,stdout)
    end
  end
end


function System:node_important(node,nodes_in_cluster)
  local systems = nodes_in_cluster[node].systems
  if systems then
    for _,name in pairs(systems) do
      if name == self.name then
        return true
      end
    end
  end
  return false
end

local function sort_nodes(nodes,system)
  return function (node1,node2)
    local node1_priority
    local node2_priority
    
    local priorities = nodes[node1].priority
    if priorities then
      node1_priority = priorities[system]
    end
    priorities = nodes[node2].priority
    if priorities then
      node2_priority = priorities[system]
    end

    if node1_priority and node2_priority then
      return node1_priority < node2_priority
    elseif node1_priority then
      return true
    elseif node2_priority then
      return false
    else
      return node1 < node2
    end
  end
end

-- notify this system that a node came online
function System:up(node)
  local nodes_in_cluster = util.config_get('nodes_in_cluster')
  if self:node_important(node,nodes_in_cluster) then
    if self.nodes[node] == nil then
      self.node_order[#self.node_order + 1] = node
      table.sort(self.node_order,sort_nodes(nodes_in_cluster,self.name))
    end
    self.nodes[node] = true
    if node == self.node_id then
      self:send(self:current(), '$cast', {'enable'})
    else
      self:regen()
    end
  end
end

-- notify this system that a node went offline
function System:down(node)
  local nodes_in_cluster = util.config_get('nodes_in_cluster')
  if self:node_important(node,nodes_in_cluster) then
    self.nodes[node] = false
    if node == self.node_id then
      self:send(self:current(), '$cast', {'disable'})
    else
      self:regen()
    end
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