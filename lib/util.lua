-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   4 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Fsm = require('cauterize/tree/fsm')

function exports.config_watch(pid, key, fun)
  local response = Fsm.call('config', 'register', pid, key, fun)
  assert(response[1],'unable to get node config value: ' .. key)
  return response[2]
end

function exports.config_get(key)
  local response = Fsm.call('config', 'get', key)
  assert(response[1],'unable to get node config value: ' .. key)
  return response[2]
end