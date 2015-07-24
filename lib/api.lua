-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Daniel Barney.
-- @doc
--
-- @end
-- Created :   18 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------
local codec = require('redis-codec')
local net = require('coro-net')
local uv = require('uv')

-- need custom wrappers to support returning nil.
local function wrapReader(decoder,read)
  local buffer = ''
  local decode = decoder()
  return function()
    while true do
      local chunk, rest = decode(buffer)
      if rest then
        buffer = rest
        return chunk
      end
      local next_chunk = read()
      if next_chunk == nil then return nil end
      buffer = buffer .. next_chunk
    end
  end
end

local function wrapWriter(encoder,write)
  local encode = encoder()
  return function(...)
    local data = encode(...)
    return write(data)
  end
end

function bufferWrite(write)
  local count = 0
  local running = false
  local buffer = {}
  local writer = uv.new_idle()

  local function write_buffer(direct)
    if count == 0 then
      running = false
      uv.idle_stop(writer)
    else
      count = 0
      write(buffer)
      buffer = {}
    end
  end

  return function(data)
    count = count + 1
    buffer[count] = data
    if not running then
      running = true
      uv.idle_start(writer, write_buffer)
    end
  end
end

function exports.server(opts, handler)
  net.createServer(opts,function(old_read, old_write, socket)
    -- p(socket:send_buffer_size(1024 * 1024), socket:recv_buffer_size(1024 * 1024))
    uv.tcp_nodelay(socket, false)
    local function tmp_write(data)
      return assert(socket:write(data, function() end))
    end
    local buffer = bufferWrite(tmp_write)
    local read = wrapReader(codec.decoder, old_read)
    local write = wrapWriter(codec.encoder, buffer)
    handler(read, write, socket, old_read, buffer)
  end)
end