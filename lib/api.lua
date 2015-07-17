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
      if next_chunk == nil then error('redis connection closed') end
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

function bufferWrite(write, size, max_elems)
  if not size and not max_elems then
    return write
  else
    local len = 0
    local count = 0
    local running = false
    local buffer = {}
    local timer = uv.new_timer()

    local function write_buffer(direct)
      running = false
      if count > 0 then
        local packet = table.concat(buffer)
        buffer = {}
        len = 0
        count = 0
        if direct then
          return write(packet)
        else
          return coroutine.wrap(write)(packet)
       end
      end
    end

    return function(data)
      len = len + #data
      count = count + 1
      buffer[count] = data
      if len > size or count > max_elems then
        write_buffer(true)
      elseif not running then
        running = true
        uv.timer_start(timer, 1, 0, write_buffer)
      end
    end
  end
end

function exports.server(opts, handler)
  net.createServer(opts,function(old_read,old_write,socket)
    uv.tcp_nodelay(socket, false)
    -- local buffer = bufferWrite(old_write, 1024, 50)
    local read = wrapReader(codec.decoder, old_read)
    local write = wrapWriter(codec.encoder, old_write)
    handler(read, write, socket, old_read, old_write)
  end)
end