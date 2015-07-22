-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   14 July 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local uv = require('uv')
local server = require('./api').server
local Store = require('./store/basic/basic')
local codec = require('redis-codec')

local store = Store:new('./tmp-store')

local profile = require('profile')
profile.start(997)

local dump = uv.new_timer()
uv.timer_start(dump, 10000, 10000, function()
  local count, stacks = profile.dump(20)
  p('collected', count, 'samples')
  if count > 0 then
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe( false)
    local stdin = uv.new_pipe(false)
    handle, pid = uv.spawn("flamegraph.pl", {
      stdio = {stdin, stdout, stderr}
      ,args = {'--hash'}
    }, function() end)
    local fd = uv.fs_open('./graph.svg', "w", 438)
    local offset = 0
    uv.read_start(stdout, function(err, data)
      if err or not data then
        uv.fs_close(fd)
        uv.close(stdout)
        uv.close(stderr)
        uv.close(stdin)
        uv.close(handle)
      else
        uv.fs_write(fd, data, offset)
        offset = offset + #data
      end
    end)
    uv.read_start(stderr, function() end)
    for line, count in pairs(stacks) do
      uv.write(stdin, line .. " " .. count .. "\n")
    end
    uv.shutdown(stdin)
  end
end)

server({port = 7007},
  function(read, write, socket, old_read, old_write)
    local encoder = codec.encoder()
    local cache = {}
    setmetatable(cache, {__mode = "v"})
    for cmd in read do
      cmd[1] = cmd[1]:lower()
      if cmd[1] == 'ping' then
        -- fast path for PONG responses
        old_write('+PONG\r\n')
      else
        local sucess, ret, cache_key = pcall(store.perform,store,cmd)
        if sucess then
          if cache_key and cache[cache_key] then
            old_write(cache[cache_key])
          else
            if cache_key then
              
            end
            local encoded = encoder(ret)
            if cache_key then
              cache[cache_key] = encoded
            end
            old_write(encoded)
          end
        else
          -- errors need to be printed out this way so they are
          -- encoded correctly
          local value = '-' .. ret .. '\r\n'
          old_write(value)
        end
      end
    end
  end)

require('uv').run()