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
local Cauterize = require('cauterize')
local connect = require('coro-tcp').connect
local HttpCodec = require('http-codec')
local WebsocketCodec = require('websocket-codec')
local wrapper = require('coro-wrapper')
local wrapStream = require('coro-channel').wrapStream
local readWrap, writeWrap = wrapper.reader, wrapper.writer
local Group = require('cauterize/lib/group')
local Ref = require('cauterize/lib/ref')
local SyncConnection = Cauterize.Fsm:extend()

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
    self.write = write
    self.read = read
    self:wrap(function(cb)
      coroutine.wrap(function()
        repeat
          local packet = read()
          cb({'websocket_response',packet})
        until packet == nil
      end)()
      return '$cast'
    end)
    Group.join(self:current(),'sync')
    self.write('["test","command"]')
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