-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   2 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Config = require('./config')
local Link = require('cauterize/lib/link')
local ConfigRouter = Config:extend()


local store_collections =
  {nodes_in_cluster = 'nodes'
  ,systems = 'systems'}

local in_store =
  {node_wait_for_response_interval = true
  ,nodes_in_cluster = true
  ,needed_quorum = true
  ,max_packets_per_interval = true
  ,systems = true}

function ConfigRouter:get(key)
  local value = {false}
  if in_store[key] then
    local collection_name = store_collections[key]
    if collection_name then
      value = ConfigRouter.call('store','fetch',collection_name)
    else
      value = ConfigRouter.call('store','fetch','config',key)
    end
  end
  if not value[1] then
    value = Config.get(self,key)
  end
  return value
end

-- wrap the set function so that broadcasts are sent
function ConfigRouter:set(key, value)
  local response
  if in_store[key] then
    assert(store_collections[key],
      'unable to update an entire collection in the config')
    response = ConfigRouter.call('store','get','config',key)
    if response[2] ~= value then

      response = ConfigRouter.call('store','enter','config',key,value)
      response[2] = true
    else
      response[2] = false
    end
  else
    response = Config.set(self,key,value)
  end
   
  if response[1] == true and response[2] == true then
    self:broadcast(key, value)
  end
  return response
end

function ConfigRouter:broadcast(key, value, type)
  local registered_listeners = self._registered[key]
  if registered_listeners then
    for pid, fun in paris(registered_listeners) do
      Cauterize.Server.cast(pid, fun, key, value, type)
    end
  end
end

function ConfigRouter:register(pid, key, fun)
  local registered_listeners = self._registered[key]
  if not registered_listeners then
    registered_listeners = {}
    self._registered[key] = registered_listeners
  end
  registered_listeners[pid] = fun

  -- monitor so that when the process dies it can be removed
  Link.monitor(pid, self:current())

  return self:get(key)
end

function ConfigRouter:unregister(pid, key)
  local registered_listeners = self._registered[key]
  if registered_listeners then
    registered_listeners[pid] = nil
  end
  return true
end

function ConfigRouter:close(...)
  assert(false, 'process died and needs to be removed from config')
end

return ConfigRouter