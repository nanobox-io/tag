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

local Link = require('cauterize/lib/link')
local Pid = require('cauterize/lib/pid')
local Mailbox = require('cauterize/lib/mailbox')
require('tap')(function (test)
	local function new_proc()
		local proc = 
			{_links = {}
			,_pid = Pid.next()
			,_mailbox = Mailbox:new()
			,_inverse_links = {}}
		Pid.enter(proc._pid,proc)
		return proc
	end
	local proc1 = new_proc()
	local proc2 = new_proc()
	local proc3 = new_proc()

	test("can monitor another process",function()
		Link.monitor(proc1._pid,proc2._pid)
		assert(#proc2._mailbox._box == 0,"there was a message already")
		Link.clean(proc1._pid)
		assert(#proc2._mailbox._box == 1,"link message did not arrive")

	end)

	test("if the linked process is dead the message is immediately sent",function()
		assert(#proc1._mailbox._box == 0,"there was a message already")
		Link.monitor(proc3._pid + 1,proc1._pid)
		assert(#proc1._mailbox._box == 1,"link message did not arrive")

	end)

	test("we can link and unlink without the message being sent",function()
		assert(#proc3._mailbox._box == 0,"there was a message already")
		local ref = Link.monitor(proc1._pid,proc3._pid)
		Link.unmonitor(proc3._pid,ref)
		assert(#proc3._mailbox._box == 0,"link message should not have been delivered")

	end)
end)