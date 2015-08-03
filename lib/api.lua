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
local wrap = require('./wrappers')

-- buffer up data before sending it out
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
    local read = wrap.reader(codec.decoder, old_read)
    local write = wrap.writer(codec.encoder, buffer)
    handler(read, write, socket, old_read, buffer)
  end)
end