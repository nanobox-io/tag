-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   9 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local json = require('json')
local SyncConnection = require('./sync_connection')
local Supervisor = Cauterize.Supervisor

local SyncLeader = {}

function SyncLeader:enable()
  p('enabling')
end

function SyncLeader:disable()
  p('disable')
  Supervisor.call('sync-manager','stop')
end

function SyncLeader:add(elem)
  elem = json.decode(tostring(elem))
  p('add',elem)
  -- this child should never cause the supervisor to shut off
  Supervisor.call('sync-manager','add_child',SyncConnection,
    {name = elem.host .. ':' .. elem.port
    ,args = {elem}
    ,restart = 
      {count = 50
      ,every = 1}})
end

function SyncLeader:remove(elem)
  elem = json.decode(tostring(elem))
  p('remove',elem)
  Supervisor.call('sync-manager','remove_child',elem.host .. ':' .. elem.port)
end


return SyncLeader