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

local store = Store:new('./tmp-store')

-- local profile = require('profile')
-- profile.start(997)

-- local dump = uv.new_timer()
-- uv.timer_start(dump, 1000, 1000, function()
--  local count, stacks = profile.dump(2)
--  if count > 0 then
--    p('profiler:')
--    for line, count in pairs(stacks) do
--      p(line,count)
--    end
--  end
-- end)

server({port = 7007},
  function(read, write, socket, old_read, old_write)
    for cmd in read do
      cmd[1] = cmd[1]:lower()
      if cmd[1] == 'ping' then
        -- fast path for PONG responses
        old_write('+PONG\r\n')
      else
        local sucess, ret = pcall(store.perform,store,cmd)
        if sucess then
          if type(ret) == 'function' then
            local thread = coroutine.running()
            ret(function(info, result)
              p('i have', info, result)
              if not pcall(write, info, result) then
                coroutine.resume(thread)
                return false
              end
            end)
            coroutine.yield()
          else
            write(ret)
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