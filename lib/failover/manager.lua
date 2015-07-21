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
local Ref = require('cauterize/lib/ref')
local Node = require('./node')
local Packet = require('./packet')
local log = require('logger')
local store = require('../store/main').singleton()


local Nodes = Cauterize.Supervisor:extend()

function Nodes:_manage()
  -- tail the key that we are interested in
  local upgrade = store:tail(nil, {'tail', '!nodes'})
  -- fetch all members
  local members = store:smembers(nil, {'smembers', '!nodes'})
  local ref = self:wrap(function(ref, cb) upgrade(cb) return Ref.make() end)
  self[ref] = self.replicate
  for _, member in pairs(members) do
    self:send_after('$self', 0, '$cast', {'r_enter',member})
  end
  store:del(nil,{'del', '#ping_nodes'})
end

function Nodes:replicate(info, result)
  p(info, result)
end

function Nodes:r_enter(id)
  self:add_child(Node,
    {name = id
    ,args = {{name = id}}})
  if id ~= store:get(nil, {'get', '#node_name'}) then
    p('number of nodes:',store:lpush(nil,{'lpush', '#ping_nodes', id}),id)
  end
end

function Nodes:r_delete(id)
  self:remove_child(id)
  store:lrem(nil,{'lpush', '#ping_nodes', id, 0})
end

local Failover = Cauterize.Supervisor:extend()

function Failover:_manage()
  log.info('failover manager is starting up')
  self:manage(Packet, {name = 'packet server'})
      :manage(Nodes, {name = 'node manager', type = 'supervisor'})
end

return Failover