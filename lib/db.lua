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

local server = require('./api').server
local Store = require('./store/basic/basic')

local store = Store:new('./tmp-store')

-- local profile = require('jit.profile')

-- local hrtz = math.floor(tostring(1000000/997))
-- p('calling every',hrtz)
-- profile.start('i' .. hrtz .. 'fl',function(thread, samples, vmstate)
--  print(profile.dumpstack(thread, "lZ;", -20))
-- end)

server({port = 7007},
  function(read, write, socket, old_read, old_write)
    for cmd in read do
      cmd[1] = cmd[1]:lower()
      if cmd[1] == 'ping' then
        -- fast path for PONG responses
        old_write('+PONG\r\n')
      else
        local sucess, ret = store:perform(cmd)
        if sucess then
          write(ret)
        else
          -- errors need to be printed out this way so they are are
          -- encoded correctly
          local value = '-' .. ret .. '\r\n'
          old_write(value)
        end
      end
    end
  end)

require('uv').run()