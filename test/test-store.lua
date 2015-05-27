-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   22 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local log = require('logger')
local Store = require('../lib/store/basic/basic')

log.add_logger('debug','store',p)

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
	
	test('store can start and stop correctly',function()
		local store_started = false
		local store_stopped = false
		-- we don't want to change the actual store
		local TestStore = Store:extend()
		function TestStore:stop()
			p('called stop')
			self:_stop()
			return true
		end
		Reactor:enter(function(env)
			local pid = TestStore:new(env:current())
			store_started = true
			p('going to call',pid)
			store_stopped = Cauterize.Server.call(pid,'stop')
		end)
		
		assert(store_started,"store did not start")
		assert(store_stopped,"store did not stop")
	end)

	test('store can insert/fetch/remove items',function()
		local clean,enter,fetch,list,del,update = nil,nil,nil,nil,nil,nil
		Reactor:enter(function(env)
			local pid = Store:new(env:current())
			clean = Cauterize.Server.call(pid,'fetch','test','asdf')
			p('clean got',clean)
			enter = Cauterize.Server.call(pid,'enter','test','asdf','data')
			fetch = Cauterize.Server.call(pid,'fetch','test','asdf')
			list = Cauterize.Server.call(pid,'fetch','test')
			del = Cauterize.Server.call(pid,'fetch','test','asdf')
			update = Cauterize.Server.call(pid,'enter','test','asdf','what')
		end)

		assert(clean[1] or clean[2] == 'MDB_NOTFOUND: No matching key/data pair found',clean[2])
		assert(enter[1],enter[2])
		assert(fetch[1],fetch[2])
		assert(fetch[2].update == enter[2],'we got the wrong object')
		assert(list[1],list[2])
		assert(list[2][1].update == enter[2],'listing got the wrong object')
		assert(del[1],del[2])
		assert(update[1],update[2])
		assert(update[2] ~= enter[2],'updated to the same time?')

	end)
end)