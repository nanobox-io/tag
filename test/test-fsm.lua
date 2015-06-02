-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   21 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local Fsm = require('cauterize/tree/fsm')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
  
  test('finite state machines correctly switch states',function()
    local Test = Fsm:extend()
    local on,off,on_ret,off_ret = false,false,false,false
    function Test:_init() self.state = 'on' end
    Test.on = {}
    Test.off = {}
    function Test.on:off()
      off = true;
      self.state = 'off'
      return true
    end
    function Test.off:on() 
      on = true;
      self.state = 'on'
      return true
    end

    Reactor:enter(function(env)
      local pid = Test:new(env:current())
      off_ret = Fsm.cast(pid,'off')
      on_ret = Fsm.call(pid,'on')
    end)
    
    
    assert(off,"turning it off did not work")
    assert(on,"turning it on did not work")
    assert(on_ret == true,"got no response from on")
    assert(off_ret == nil,"got a response from off")

  end)
end)