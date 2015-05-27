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

local Plan = require('../lib/system/plan')
require('tap')(function (test)
	local hash = 1
	function h()
		hash = hash + 1
		return {hash = hash}
	end
	
	test('plans can be created from an array', function()
		local plan = Plan:new({h(),h(),h()})
		local add, remove = plan:changes()

		assert(#remove == 0,
			'there should not have been anything to remove')
		assert(#add == 3, 'wrong number of elements')

	end)

	test('plans add and remove elements', function()
		local first = {h(),h(),h()}
		local second = {first[1],h()}
		local plan = Plan:new(first)
		plan:next(second)

		local add, remove = plan:changes()
		assert(#remove == 2,
			'did not remove two elements')
		assert(#add == 1, 'should only add one element')
		assert(add[1].hash == second[2].hash, 'wrong element was added')
		assert(remove[1].hash == first[2].hash,
			'incorrect element was removed')
		assert(remove[2].hash == first[3].hash,
			'incorrect element was removed')

	end)
end)