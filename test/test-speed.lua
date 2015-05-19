-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   15 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local hrtime = require('uv').hrtime
require('tap')(function (test)
	
	test('can we pass 11 million messages per second?',function()
		local thread = coroutine.create(function()
			for i=1,10000000 do
				coroutine.yield()
			end
		end)
		local count = 0
		local start = hrtime()
		while coroutine.resume(thread) do count = count + 1 end
		assert(11000000 < count / ((hrtime() - start) / 1000000000),"resuming from a coroutine is too slow.")
	end)
end)