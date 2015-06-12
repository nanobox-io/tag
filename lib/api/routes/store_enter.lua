-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   11 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

Process = require('cauterize/lib/process')
Server = require('cauterize/tree/server')

exports.method = 'POST'
exports.path = '/store/:bucket/:key'
exports.route = function(req,res)

  -- I do not want to validate that what is passed in is json.
  -- really anything could be passed in.

  local thread = coroutine.running()

  Process:new(function(env)
    local response = Server.call('store','enter',req.params.bucket,
      req.params.key, req.body)
    
    if response[1] then
      res.code = 200
      res.body = "ok"
    else
      res.code = 500
      res.body = response[2]
    end
    coroutine.resume(thread)
  end,{})
  coroutine.yield()
end