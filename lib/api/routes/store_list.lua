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
ffi = require('ffi')

exports.method = 'GET'
exports.path = '/store/:bucket'
exports.route = function(req,res)

  local thread = coroutine.running()

  Process:new(function(env)
    local response = Server.call('store','fetch',req.params.bucket,
      req.body)
    
    if response[1] then
      res.code = 200
      local values = {}
      -- this will overflow, but has a very low collision rate.
      local etag = ffi.new('unsigned long long',0)
      for idx,elem in ipairs(response[2]) do
        etag = etag + elem.update
        values[idx] = tonumber(elem.update)
      end
      res.headers.etag = etag
      res.body = values
      res.headers['content-type'] = 'application/json'
    else
      res.code = 500
      res.body = response[2]
    end
    coroutine.resume(thread)
  end,{})
  coroutine.yield()
end