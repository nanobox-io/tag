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
local Store = require('../lib/store/replicated/replicated')
local Config = require('../lib/config')
local json = require('json')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
  
  test('replicated stores correctly become Leaders or Followers',function()
    local enabled = false
    local call_works = false
    Reactor:enter(function(env)
      Config:new(env:current())
      Store:new(env:current())
      local opts = 
        {host = '127.0.0.1'
        ,port = 1234
        ,systems = {'sync', 1}}

      local system = Config.call('config','set','nodes_in_cluster',{test1 = opts})
      local system = Config.call('config','set','node_name','test1')
      local system = Store.call('store','fetch','systems','sync')
      local ret = Store.call('store','enter','nodes','test1',json.stringify(opts))
      p(ret)
      local pid = System:new(env:current(),'sync',json.parse(system[2]))
      enabled = System.cast(pid,'up','test1')
      enabled = System.call(pid,'enable')
      p('enabled system')
    end)

    assert(enabled[1],enabled[2])
    assert(call_works,'sending a message to the group did not work')
    
  end)
end)