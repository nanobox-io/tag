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
  assert(bucket,'need a bucket to delete from')
  assert(key,'need a key to delete')
  local url = table.concat(
    {'http://'
    ,global.host
    ,':'
    ,global.port
    ,'/store/'
    ,bucket
    ,'/'
    ,key})

  coroutine.wrap(function()
    local res, data = http.request('DELETE',url,{},nil)
    if res.code == 200 then
      p(data)
    else
      p('unknown respose', res)
    end
  end)()
end

exports.opts = {}