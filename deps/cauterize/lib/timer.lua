-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :  29 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local uv = require('uv')
local Timer = {}

local timers = {}
local alive_timers = 0


function Timer.new(interval,timeout,fun,...)
	alive_timers = alive_timers + 1
	local timer = uv.new_timer()
	local args = {...}
	timers[timer] = true
	uv.timer_start(timer, timeout, interval, function()
		if interval == 0 then
			alive_timers = alive_timers - 1
			timers[timer] = nil
			uv.close(timer)
		end
		fun(unpack(args))
	end)
	return timer
end

function Timer.cancel(ref)
	local timer = timers[ref]
	if timer then
		alive_timers = alive_timers - 1
		uv.timer_stop(ref)
		uv.close(ref)
		timers[ref] = nil
	end
end

function Timer.empty()
	for id in pairs(timers) do
		Timer.cancel(id)
	end
end

function Timer.running()
	return alive_timers
end

return Timer