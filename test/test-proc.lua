-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   20 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local Proc = require('cauterize/tree/proc')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
  
  test('procs notify the parent that they have finished setting up',function()
    local Test = Proc:extend()
    local init_ran = false
    local loop_ran = false
    local destroy_ran = false
    local response,msg
    function Test:_init() init_ran = true end
    function Test:_loop(msg)
      loop_ran = true
      assert(msg[1] == 'stop','msg sent was not stop')
      self:_stop() -- just sets a flag
      self:respond(msg[3],'ok')
    end
    function Test:_destroy() destroy_ran = true end

    Reactor:enter(function(env)
      local pid = Test:new(env:current())
      response = Proc:_link_call(pid,'stop') -- this should cause the process to stop
      msg = env:recv() -- this should be a down message

    end)
    p(response,msg)
    assert(init_ran,'_init did not run')
    assert(loop_ran,'_loop did not run')
    assert(response == 'ok','wrong message was delivered')
    assert(msg[2] == '$exit','wrong down message was delivered')
    assert(destroy_ran,'_destroy did not run')
  end)

  test('link_call will throw an error if the called process dies',function()
    local Test = Proc:extend()
    local died_early = true
    local response = nil
    function Test:_loop(msg)
      if msg[1] == 'die!' then
        error('i am dead')
      end
    end

    Reactor:enter(function(env)
      local pid = Test:new(env:current())
      Proc:_link_call(pid,'die!') -- this should cause the process to stop
      died_early = false
    end)

    assert(response == nil,"I did not get a response")
    assert(died_early,"didn't die soon enough")


  end)
end)