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
local codec = require('redis-codec')
local net = require('coro-net')
local wrap = require('./wrappers')
coroutine.wrap(function()
  local base_cli_opts = 
    {host = '127.0.0.1'
    ,port = 7007}

  args[0] = nil
  apply_opts(base_cli_opts, args)
  local cmd_name = args[1]
  assert(cmd_name, 'missing command')
  local old_reader, old_writer = assert(net.connect(base_cli_opts))
  local read = wrap.reader(codec.decoder, old_reader)
  local write = wrap.writer(codec.encoder, old_writer)
  assert(write(args))
  local res = read()
  p(res)
  os.exit(0)
end)()

require('uv').run()