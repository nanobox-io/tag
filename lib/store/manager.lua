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
local log = require('logger')

local Basic = require('./basic/basic')
local Replication = require('./replicated/replicated')
local ConfigLoader = require('./config_loader')

local Store = Cauterize.Supervisor:extend()

function Store:_manage()
  if Cauterize.Supervisor.call('config','get','replicated_db') then
    log.info('enabling replicated mode')
    self:manage(Replication)
  else
    log.info('enabling single node')
    self:manage(Basic)
  end
  self:manage(ConfigLoader)
end

return Store