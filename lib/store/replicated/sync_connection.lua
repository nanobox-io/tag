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
local hrtime = uv.hrtime
local json = require('json')
local log = require('logger')
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
  self.order = {}
  self:send('$self','$cast',{'timeout'})
  self.start = hrtime()
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
      p('client: begining sync',self.config.host,self.config.port)
      write('["sync"]')
      local response = call('count')
      assert(response[1],response[2])
      local count = 0
      for bucket,number in pairs(response[2]) do

        local members = call('fetch',bucket)
        assert(members[1],members[2])
        local comparison = {}
        for idx,name in ipairs(members[2]) do
          comparison[name] = 
            {tostring(members[2][name].hash)
            ,tostring(members[2][name].update)}
        end
        write(json.stringify({bucket,comparison}))
        local frame = read()
        local packet = json.decode(frame.payload)
        local sync, missing = packet[1], packet[2]
        -- store sync in the db
        for key,value in pairs(sync) do
          count = count + 1
          -- need to validate the structure received
          call('r_enter',bucket,key,value)
        end
        -- send across members that the remote is missing.
        local values = {}
        for key in pairs(missing) do
          -- send the structure across.
          values[key] = ffi.string(members[2][key])
        end
        write(json.stringify(values))
      end
      p('client: finished sync',self.config.host,self.config.port)
      write('{}')
      assert(read().payload == '{}')
      log.info('client: remote finished sync',self.config.host,self.config.port)
      log.info('client: sync pulled changes:',count)
      call('done')
    end)

    local ref = self:wrap(function(cb)
      coroutine.resume(routine,function(...)
        cb(...)
        return coroutine.yield()
      end)
      return Ref.make()
    end)
    -- join the peers group so that when any updates happen while
    -- syncing, they will get pushed across when the sync is done
    Group.join(self:current(),'peers')
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

    self.state = 'connected'
    self.write = function(args)
      coroutine.wrap(write)(json.stringify(args))
    end
  else
    -- stop the process
    self:send_after('$self',1000,'$cast',{'exit','normal'})
  end
end

function SyncConnection.connected:websocket_response(packet)
  if not packet then
    if hrtime() - self.start < 1000000000 then
      -- the connection was closed, so kill this process
      self:send_after('$self',1000,'$cast',{'stop'})
    else
      self.connected.stop(self)
    end
  else
    packet = json.parse(packet.payload)
    local response = self.order[packet]
    if response then
      self:respond(response,true)
    else
      log.warning('got a response that wasn\'t one that was sent')
    end
  end
end

function SyncConnection.disconnected:stop()
  self:_stop()
  log.info('canceling replication from',self.config.host,self.config.port)
  return true
end

function SyncConnection.connected:stop()
  uv.close(self.socket)
  self:_stop()
  log.info('canceling replication from',self.config.host,self.config.port)
  Group.leave(self:current(),'peers')
  return true
end

function SyncConnection.disconnected:sync(...)
  log.info('sync dropping',...)
  return false
end

function SyncConnection.connected:sync(cmd,...)
  local ref = Ref.make()
  self.order[ref] = self._current_call
  self.write({cmd, ref, ...})
end

return SyncConnection