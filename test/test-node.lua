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
local Node = require('../lib/failover/node')
local Config = require('../lib/config')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
  
  test('nodes will switch states once a quorum is reached',function()
    local state1,state2,state3
    Reactor:enter(function(env)
    	Config:new(env:current())
      local opts = 
        {quorum = 2
        ,name = 'testing'}
      local pid = Node:new(env:current(),opts)
      state1 = Node.call(pid,'get_state')
      
      Node.cast(pid,'up','node1')
      state2 = Node.call(pid,'get_state')
      Node.cast(pid,'up','node2')
      state3 = Node.call(pid,'get_state')
      
      Node.cast(pid,'down','node3')
      state4 = Node.call(pid,'get_state')
      Node.cast(pid,'down','node2')
      state5 = Node.call(pid,'get_state')
      Node.cast(pid,'_stop')
      p('done')
    end)
    
    p(state1,state2,state3,state4,state5)
    assert(state1 == 'down',"incorrect initial state")
    assert(state2 == 'down',"incorrect second state")
    assert(state3 == 'up',"incorrect third state")
    assert(state4 == 'up',"incorrect fourth state")
    assert(state5 == 'down',"incorrect fifth state")
  end)

  test('nodes will timeout and switch states correctly',function()
    local state1,state2
    Reactor:enter(function(env)
    	Config:new(env:current())
      local opts = 
        {quorum = 2
        ,name = 'testing'}
      local pid = Node:new(env:current(),opts)
      Node.cast(pid,'up','node1')
      Node.cast(pid,'up','node2')
      
      Node.cast(pid,'start_timer','node1')
      state1 = Node.call(pid,'get_state')
      Node.cast(pid,'up','node1')
      p('got message',env:recv(nil,2000))
      state2 = Node.call(pid,'get_state')
      
      Node.cast(pid,'start_timer','node1')
      p('got message',env:recv(nil,2000))
      
      state3 = Node.call(pid,'get_state')
      p('call returned',state2)
      
    end)
    
    
    assert(state1 == 'up',"incorrect initial state")
    assert(state2 == 'up',"timer fired")
    assert(state3 == 'down',"timer didn't fire")
  end)
end)