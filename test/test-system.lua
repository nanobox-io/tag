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
local System = require('../lib/system/system')
local Config = require('../lib/config')
local Store = require('../lib/store/basic/basic')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
  
  test('system can transition to enabled',function()
    local enabled = false
    local call_works = false
    Reactor:enter(function(env)
      Config:new(env:current())
      Store:new(env:current())

      local opts = 
        {topology = 'nothing'
        ,load = 'date'
        ,name = 'test'}

      System.call('config','set','test',opts)
      local Test = System:extend()
      function Test:test_call()
        call_works = true
      end
      local pid = Test:new(env:current(),'test',opts)
      env:send({'group','systems'},'$cast',{'test_call'})
      enabled = System.call(pid,'enable')
    end)

    assert(enabled[1],enabled[2])
    assert(call_works,'sending a message to the group did not work')
    
  end)
end)