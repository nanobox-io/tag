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
mime = require('mime')


exports.method = 'GET'
exports.path = '/store/:bucket/:key'
exports.route = function(req,res)

  local thread = coroutine.running()

  Process:new(function(env)
    local response = Server.call('store','fetch',req.params.bucket,
      req.params.key, req.body)
    
    if response[1] then
      res.code = 200
      res.headers.etag = response[2].update
      res.headers['content-type'] = mime.getType(req.params.key)
      res.body = tostring(response[2])
    else
      res.code = 500
      res.body = response[2]
    end
    coroutine.resume(thread)
  end,{})
  coroutine.yield()
end