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
  if value == nil then
    value = defaults[key]
  end
  return {true,value}
end

function Config:set(key, value)
  if self.config[key] ~= value then 
    self.config[key] = value
    return {true,false}
  end
  return {true,true}
end

-- if this is called it is because the node is not replicated. nothing
-- can change in the config this way, so this is a NOOP
function Config:register(pid, key)
  return self:get(key)
end

-- NOOP
function Config:unregister()
	return {true}
end

return Config