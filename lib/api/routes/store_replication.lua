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
log = require('logger')

local store_cmd_length =
  {fetch = 2
  ,enter = 3
  ,remove = 2
  ,r_remove = 3
  ,r_enter = 4}


local custom_cmds = {}

local function call_store(cb,params)
  Process:new(function(env)
    cb(Server.call('store',unpack(params)))
  end,{})
end

local function execute(write,params)
  call_store(function(response)
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
  end,params)
end

exports.method = 'GET'
exports.path = '/connect'
exports.route = require('weblit-websocket')({},
  function(req,read,write)
    for frame in read do
      local params = json.decode(frame.payload)
      local cmd = params[1]
      local param_length = store_cmd_length[cmd]
      if param_length == #params - 1 then
        execute(write,params)
      elseif param_length == nil then
        if custom_cmds[cmd] == nil then
          write('unknown command')
        else
          custom_cmds[cmd](read,write,unpack(params))
        end
      else
        write('wrong number of params for function')
      end
    end
  end)

local function perform(...)
  local thread = coroutine.running()
  call_store(function(results)
    coroutine.resume(thread,results[2])
  end,{...})
  return coroutine.yield()
end

function custom_cmds.sync(read,write)
  log.info('server: started sync command')
  local count = 0
  for frame in read do
    if frame.payload == '{}' then
      write('{}')
      log.info('server: sync pulled updates:',count)
      return
    end
    local pack = json.decode(frame.payload)
    local bucket, members = pack[1], pack[2]
    -- look up collection in store
    local collection = perform('fetch',bucket)
    -- subscribe to changes

    -- compare against what was recieved
    local sync = {}
    for idx,name in ipairs(collection) do
      local comparison = members[name]
      local object_is_different = 
        comparison[1] ~= tostring(collection[name].hash)
      local remote_is_newer = 
        comparison[2] ~= tostring(collection[name].update)
      if comparison == nil or (object_is_different and remote_is_newer) then
        -- should be the actual struct, not just the data.
        local struct = collection[name]
        sync[name] = ffi.string(struct,24 + 4 + struct.len + 1)
      else
      end
      members[name] = nil
    end
    -- send any updates that need to be sent
    write(json.stringify({sync,members}))
    -- get any updates from remote
    local updates = json.decode(read().payload)
    for key,value in pairs(updates) do
      count = count + 1
      -- need to validate the structure received
      perform('r_enter',bucket,key,value)
    end

  end
end