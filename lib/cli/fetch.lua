-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   26 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------
local http = require('coro-http')

function exports.cmd(global, config, bucket, key)
  assert(bucket,'need a bucket to fetch from')
  local url = table.concat(
    {'http://'
    ,global.host
    ,':'
    ,global.port
    ,'/store/'
    ,bucket})

  if key then
    url = url .. '/' .. key
  end
  p(coroutine.wrap(function()
    p('making request',url)
    local res, data = http.request('GET',url,{},nil)
    p('done',res,data)
    if res.code == 404 then
      p('not found')
    elseif res.code == 200 or res.code == 203 then
      p(data)
    else
      p('unknown respose', res)
    end
  end)())
end

exports.opts = {}