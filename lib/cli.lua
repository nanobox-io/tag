-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   15 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local log = require('logger')
local apply_opts = require('parse-opts')

local base_cli_opts = 
  {host = '127.0.0.1'
  ,port = 1234}

local valid_commands = 
  {join = true
  ,leave = true
  ,enter = true
  ,fetch = true
  ,delete = true}

apply_opts(base_cli_opts,args)

local cmd_name = args[1]
assert(cmd_name,'missing command')

if valid_commands[cmd_name] then
  log.info('running cmd',cmd_name)
  local module = require('./cli/' .. cmd_name)
  local cmd_opts, cmd = module.cmd_opts, module.cmd
  table.remove(args,1)
  apply_opts(cmd_opts,args)
  cmd(base_cli_opts,cmd_opts,unpack(args))
  return require('uv').run()
else
  error('invalid command: '..cmd_name)
end
