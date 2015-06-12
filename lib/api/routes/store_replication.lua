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
json = require('json')
ffi = require('ffi')

local params_for_cmds =
  {fetch = 2
  ,enter = 3
  ,remove = 2}


local function execute(write,params)
  Process:new(function(env)
    local response = Server.call('store',unpack(params))
    response = response[2]
    if type(response) == 'table' then
      for i,key in ipairs(response) do
        response[i] = nil
        response[key] = tonumber(response[key].update)
      end
      response = json.stringify(response)
    else
      response = tostring(response)
    end
    -- just so that this coroutine doesn't get suspended
    coroutine.wrap(function()
      write(response)
    end)()
  end,{})
end

exports.method = 'GET'
exports.path = '/connect'
exports.route = require('weblit-websocket')({},
  function(req,read,write)
    for frame in read do
      local params = json.decode(frame.payload)
      assert(params_for_cmds[params[1]] == #params - 1)
      execute(write,params)
    end
  end)