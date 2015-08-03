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
        local ret, err, cache_key = store.perform(store,cmd)
        if not err then
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
          local value = '-' .. err .. '\r\n'
          old_write(value)
        end
      end
    end
  end)

require('uv').run()