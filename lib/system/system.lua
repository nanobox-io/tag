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
local Require = require('require')
local log = require('logger')
local Cauterize = require('cauterize')
local json = require('json')
local Plan = require('./plan')
local store = require('../store/main').singleton()
local Name = require('cauterize/lib/name')
local Group = require('cauterize/lib/group')

local System = Cauterize.Fsm:extend()

function System:_init(name)
  self.system = {}
  local kv = store:hgetall(nil, {'hgetall', name})
  for i = 1, #kv, 2 do
    self.system[kv[i]] = kv[i + 1]
  end

  self.state = 'disabled'
  self.node_id = store:get(nil, {'get', '#node_name'})
  self:build_topology(self.system.topology)
  self.name = name
  Name.register(self:current(), 'system-' .. name)
  Group.join(self:current(),'systems')

  
  self.apply_timeout = nil

  -- if the system has been defined as additional code to be loaded in
  -- Tag, then lets load it.
  if self.system.install == 'code:' then
    -- is this the right path for the new require?
    local req, module = Require('bundle:/lib/system/system.lua')
    local fn = assert(loadstring(self.system.code,'bundle:/lib/system/system/'..self.name))
    local global = {
      module = module,
      exports = module.exports,
      require = function (...)
        return module:require(...)
      end
    }
    setfenv(fn, setmetatable(global, { __index = _G }))
    self.code = fn()
    if not self.code then
      self.code = module.exports
    end
  end

  local function handle(signal)
    local sig_handler = uv.new_signal()
    uv.signal_start(sig_handler, signal, function()
      uv.close(sig_handler)
      self._on = {}
      self:apply()
      os.exit(0) -- this should really wait for everything to exit
    end)
  end
  handle('sigint')
  handle('sigquit')
  handle('sigterm')

  -- if the system needs to set it self up, it will have an install
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

function System:stop()
  self._on = {}
  self:apply()
  return true
end

local topologies = 
  {choose_one = true
  ,nothing = true
  ,max = true
  ,choose_one_or_all = true
  ,replicated = true
  ,round_robin = true}

function System:build_topology(description)
  local topology = function(data) return data end
  local wrap = function(top,arg,before)
    return function(data,order,nodes,id)
      data = before(data,order,nodes,id)
      return top(data,order,nodes,id,arg)
    end
  end
  description:gsub("([^:]*):?",function(match)
    match:gsub('([^[]*)[[]?([^]]*)]?',function(fun,arg)
      if fun ~= '' then
        if arg == '' then arg = nil end
        local level = topologies[fun]
        assert(level,'unknown topology: '..fun)
        topology = wrap(require('./topology/' .. fun),arg,topology)
      end
    end)
  end)
  self.topology = topology
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
  log.info('disabling system',self.name)
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
  local data
  local data_type = type(self.system.data)
  if data_type == 'table' then
    data = self.system.data
  else
    if data_type == 'string' then
      name = self.system.data
    else
      name = 'system-' .. self.name
    end
    data = store:smembers(nil,{'smembers',name})
  end

  -- divide it over the alive nodes in the system, and store the
  -- results for later
  self._on = self.topology(data, self.node_order, self.nodes,
    self.node_id)

  if self.apply_timeout then
    self:cancel_timer(self.apply_timeout[1])
    self:respond(self.apply_timeout[2],{false,'inturrupted'})
  end
  
  -- then run the plan after a set amount of time has passed
  -- we do this incase multiple changes in nodes being up/down come in
  -- a small amount of time and can be coalesed into a single change
  -- in the plan
  self.apply_timeout = 
    {self:send_after('$self',self.system.timeout or 2000, '$call',
      {'apply'}, self._current_call)
    ,self._current_call}
end

-- run a set of changes to bring this system to the next step of the
-- plan
function System:apply()
  self.plan:next(self._on)
  local add, remove = self.plan:changes()

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
  if self.code ~= nil then
    if type(self.code[name]) == 'function' then
      local ret = {pcall(function() self.code[name](self.code,elem) end)}
      if not ret[1] then
        log.warning('script failed to run',ret)
      end
    else
      p('skipping script',name,type(self.code[name]))
    end
  else
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
end


function System:node_important(id,nodes_in_cluster)
  local node = nodes_in_cluster[id]
  node = json.decode(tostring(node))  
  p('found node',node)
  local systems = node.systems
  if systems then
    for _,name in pairs(systems) do
      if name == self.name then
        return true
      end
    end
  end
  return false
end

-- TODO automatically transitioning to enabled and disabled should be
-- based on a quorum of nodes in the SYSTEM not the cluster. this will
-- allow systems that are partially alive to still function.

-- notify this system that a node came online
function System:up(node)
  local is_member_of_system = 
    store:sismember(nil, {'sismember',self.name .. '-nodes', node})
  if is_member_of_system then
    self.nodes[node] = true
    if node == self.node_id then
      self[self.state].enable(self)
    elseif self.state == 'enabled' then
      self:regen()
    end
    self:run('up', node)
  end
end

-- notify this system that a node went offline
function System:down(node)
  local is_member_of_system = 
    store:sismember(nil, {'sismember',self.name .. '-nodes', node})
  if is_member_of_system then
    self.nodes[node] = false
    if node == self.node_id then
      self[self.state].disable(self)
    elseif self.state == 'enabled' then
      self:regen()
    end
    self:run('down', node)
  end
end

-- If we are not in the correct state, lets return an error
function System.enabled:enable()
  return {false, 'unable to enable system from state ' .. self.state}
end

function System.disabled:disable()
  return {false, 'unable to disable system from state ' .. self.state}
end

return System