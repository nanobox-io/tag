-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   21 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local Group = require('cauterize/lib/group')
local Node = require('./node')
local Packet = require('./packet')
local log = require('logger')
local utl = require('../util')

local Nodes = Cauterize.Supervisor:extend()

function Nodes:_manage()
  -- join the group to get updates to the nodes collection
  Group.join(self:current(),'b:nodes')
  -- start a process for each node in the cluster for monitoring.
  local ret = Nodes.call('store','fetch','nodes')
  assert(ret[1],ret[2])
  for _,name in ipairs(ret[2]) do
    local opts =
      {name = 'node_' .. name}
    self:manage(Node,{name = name, args = {opts}})
  end
end

function Nodes:r_enter(bucket,id)
  assert(bucket == 'nodes')
  self:add_child(Node,
    {name = id
    ,args = {{name = id}}})
end

function Nodes:r_delete(bucket,id)
  assert(bucket == 'nodes')
  self:remove_child(id)
end

local Failover = Cauterize.Supervisor:extend()

function Failover:_manage()
  log.info('failover manager is starting up')
  self:manage(Packet, {name = 'packet server'})
      :manage(Nodes, {name = 'node manager', type = 'supervisor'})
end

return Failover