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

local Name = require('cauterize/lib/name')
local Pid = require('cauterize/lib/pid')
require('tap')(function (test)
  test("can register and unregister a name",function()
    local proc = {_names = {},_pid = Pid.next()}
    Pid.enter(proc._pid,proc)
    Name.register(proc._pid,"test")
    assert(Pid.lookup(Name.lookup('test'))._names.test,"missing registration")
    Name.unregister("test")
    assert(proc._names.test == nil,"did not unregister")
    Pid.remove(proc._pid)
  end)
end)