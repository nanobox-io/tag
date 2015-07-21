-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   27 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local System = require('./system')
local log = require('logger')
local json = require('json')
local store = require('../store/main').singleton()

local Manager = Cauterize.Supervisor:extend()

function Manager:_manage()
  local local_systems = store:smembers(nil, {'smembers', '#systems'})
  local enabled = 0
  for _, name in pairs(local_systems) do
    log.info('enabling system', name)
    self:manage(System, {name = 'system-' .. name, args = {name}})
    enabled = enabled + 1
  end
  if enabled == 0 then
    log.info('entering arbitration mode, no systems enabled')
  end
end

return Manager