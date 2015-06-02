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

local Cauterize = require('cauterize')
local Name = require('cauterize/lib/name')
local Link = require('cauterize/lib/link')
local Config = Cauterize.Server:extend()
local defaults = require('./default')

function Config:_init(custom)
	if not custom then
		self.config = {}
	else
	  self.config = custom
 end
 self._registered = {}
 Name.register(self:current(),'config')
end

function Config:get(key)

  local value = self.config[key]
  if not value then
    value = defaults[key]
  end
  return value
end

function Config:set(key, value)
  if self.config[key] ~= value then 
    self.config[key] = value
    self:broadcast(key, value, 'set')
  end
  return true
end

function Config:broadcast(key, value, type)
	local registered_listeners = self._registered[key]
  if registered_listeners then
    for pid, fun in paris(registered_listeners) do
      Cauterize.Server.cast(pid, fun, key, value, type)
    end
  end
end

function Config:register(pid, key, fun)
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

function Config:unregister(pid, key)
  local registered_listeners = self._registered[key]
  if registered_listeners then
    registered_listeners[pid] = nil
  end
  return true
end

function Config:close(...)
	assert(false, 'process died and needs to be removed from config')
end

return Config