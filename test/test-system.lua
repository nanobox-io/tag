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
local Store = require('../lib/store/basic/basic')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
	
	test('system can transition to enabled',function()
		local enabled = false
		Reactor:enter(function(env)
			local store = Store:new(env:current())
			p('store started',store)
			p(Store.call('store','fetch','test'))
			local opts = 
				{topology = 'nothing'
				,load = 'date'
				,name = 'test'}
			local pid = System:new(env:current(),opts)
			enabled = System.call(pid,'enable')
		end)

		assert(enabled[1],enabled[2])
		
	end)
end)