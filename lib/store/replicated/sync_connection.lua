-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   9 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local uv = require('uv')
local json = require('json')
local Cauterize = require('cauterize')
local connect = require('coro-tcp').connect
local HttpCodec = require('http-codec')
local WebsocketCodec = require('websocket-codec')
local wrapper = require('coro-wrapper')
local wrapStream = require('coro-channel').wrapStream
local readWrap, writeWrap = wrapper.reader, wrapper.writer
local Group = require('cauterize/lib/group')
local Ref = require('cauterize/lib/ref')
local Fsm = Cauterize.Fsm
local SyncConnection = Fsm:extend()

function SyncConnection:_init(config)
  self.state = 'disconnected'
  self._recv_timeout = 0
  self.config = config
  self:send_after('$self',1000,'$cast',{'timeout'})
end

-- set up the states
SyncConnection.disconnected = {}
SyncConnection.connected = {}

local function establish_connection(host, port, cb)
  local socket = uv.new_tcp()
  socket:connect(host, port, function(err)
    coroutine.wrap(function()
      if err then
        uv.close(socket)
        cb(err)
      else
        local rawRead, rawWrite = wrapStream(socket)

        local read, updateDecoder = readWrap(rawRead, HttpCodec.decoder())
        local write, updateEncoder = writeWrap(rawWrite, HttpCodec.encoder())

        -- Perform the websocket handshake
        local successfull = WebsocketCodec.handshake({
          host = host,
          path = "/connect"
        }, function (req)
          write(req)
          local res,err = read()
          if not res then
            cb("Missing server response")
          end
          if res.code == 400 then
            local reason = read() or res.reason
            cb("Invalid request: " .. reason)
          end
          return res
        end)

        if successfull then
          -- Upgrade the protocol to websocket
          updateDecoder(WebsocketCodec.decode)
          updateEncoder(WebsocketCodec.encode)
          cb(nil,socket,read,write)
        else
          uv.close(socket)
          cb('bad reqest was made')
        end
      end
    end)()
  end)
  return socket
end

function SyncConnection.disconnected:timeout()
  local ref = self:wrap(establish_connection,self.config.host,self.config.port)
  self.disconnected[ref] = self.disconnected.established
end

function SyncConnection.disconnected:established(err,socket,read,write)
  if not err then
    self.state = 'connected'
    self.socket = socket

    local routine = coroutine.create(function(call)
      p('client: begining sync')
      write('["sync"]')
      local response = call('count')
      assert(response[1],response[2])
      for bucket,number in pairs(response[2]) do
        p('client: syncing bucket',bucket,'member count',number)

        local members = call('fetch',bucket)
        assert(members[1],members[2])
        local comparison = {}
        for idx,name in ipairs(members[2]) do
          comparison[name] = 
            {tostring(members[2][name].hash)
            ,tostring(members[2][name].update)}
        end
        p('client: sending bucket time stamps',bucket)
        write(json.stringify({bucket,comparison}))
        local frame = read()
        local packet = json.decode(frame.payload)
        local sync, missing = packet[1], packet[2]
        -- store sync in the db
        p('client: applying remote sync',bucket)
        for key,value in pairs(sync) do
          p('client: remote sync r_enter',bucket,key)
          -- need to validate the structure received
          call('r_enter',bucket,key,value)
        end
        -- send across members that the remote is missing.
        local values = {}
        for key in pairs(missing) do
          p('client: sending remote requested',key)
          -- send the structure across.
          values[key] = ffi.string(members[2][key])
        end
        write(json.stringify(values))
      end
      p('client: finished sync')
      write('{}')
      assert(read().payload == '{}')
      p('client: remote finished sync')
      call('done')
    end)

    local ref = self:wrap(function(cb)
      coroutine.resume(routine,function(...)
        cb(...)
        return coroutine.yield()
      end)
      return Ref.make()
    end)
    repeat
      cmd = self:recv({ref})
      table.remove(cmd,1)
      local results = Fsm.call('store',unpack(cmd))
      assert(coroutine.resume(routine,results))

    until cmd[1] == 'done'

    -- setup the websocket to respond to commands from the other side

    self:wrap(function(cb)
      coroutine.wrap(function()
        repeat
          local packet = read()
          cb({'websocket_response',packet})
        until packet == nil
      end)()
      return '$cast'
    end)

  else
    -- stop the process
    self:send_after('$self',1000,'$cast',{'exit','normal'})
  end
end

function SyncConnection.connected:websocket_response(packet)
  if not packet then
    -- the connection was closed, so kill this process
    self:send_after('$self',1000,'$cast',{'exit','normal'})
  else
    p('got a websocket response',packet)
  end
end

function SyncConnection.disconnected:sync(...)
  log.info('sync dropping',...)
  return false
end

function SyncConnection.connected:sync(...)
  log.info('sync replicating',...)

  return true
end

return SyncConnection