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
local split = require('coro-split')
local uv = require('uv')
local hrtime = uv.hrtime

local function time_and_repeat(name,count,fun)
  p('starting',name)
  local start = hrtime()
  local job = function(init,total)
    return function()
      for i=init, count, total do
        fun(i)
      end
    end 
  end

  split(job(1,2),job(2,2))
  
  local per_second = count / ((hrtime() - start)/ 100000000000)
  per_second = math.floor(per_second) / 100
  p('done',per_second,'per second')
end

function exports.cmd(global, config, count)
  local bucket = 'bench'
  local key = 'key'
  
  local base = table.concat(
    {'http://'
    ,global.host
    ,':'
    ,global.port
    ,'/store/'
    ,bucket
    ,'/'})

  coroutine.wrap(function()
    p('begining test')
    count = tonumber(count)
    local value = ('a'):rep(1024)
    local request = function(method,url,payload)
      local args = {}
      return function(i)
        assert(http.request(method,url .. i,{},payload))
      end
    end
    time_and_repeat('POST request 1k payload', count,
      request('POST',base,value))
    time_and_repeat('GET requests', count,
      request('GET',base))
    time_and_repeat('GET requests (list)', count/100,
      function()
        assert(http.request('GET',base,{}))
      end)
    time_and_repeat('DELETE requests', count,
      request('DELETE',base))
  end)()
end

exports.opts = {}