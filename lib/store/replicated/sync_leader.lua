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
local SyncConnection = require('../store/replicated/sync_connection')
local Manager = Cauterize.Supervisor:extend()

-- we start nothing by default
function Manager:_manage() end

local SyncLeader = {}
local manager = nil

function SyncLeader:enable()
  p('enabling')
  -- this supervisor should never stop restarting its children
  manager = Manager:new()
end

function SyncLeader:disable()
  p('disable')
  Manager.call(manager,'stop')
  manager = nil
end

function SyncLeader:add(elem)
  elem = json.decode(tostring(elem))
  p('add',elem)
  -- this child should never cause the supervisor to shut off
  Manager.call(manager,'add_child',SyncConnection,
    {name = elem.host .. ':' .. elem.port
    ,args = {elem}
    ,restart = 
      {count = 50
      ,every = 1}})
end

function SyncLeader:remove(elem)
  elem = json.decode(tostring(elem))
  p('remove',elem)
  Manager.call(manager,'remove_child',elem.host .. ':' .. elem.port)
end


return SyncLeader