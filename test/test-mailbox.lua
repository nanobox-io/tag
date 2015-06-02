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

local Mailbox = require('cauterize/lib/mailbox')
require('tap')(function (test)
  test("insert,recv, and selective recv all work",function()
    local alive,err
    local mailbox = Mailbox:new()
    local thread = coroutine.create(function()
      assert(mailbox:recv()[1] == "asdf","first message was wrong")
      assert(mailbox:recv('test')[1] == "test","second message was wrong")
      assert(mailbox:recv()[1] == "qwerty","third message was wrong")
      assert(mailbox:recv('test')[1] == "test","fourth message was wrong")
      assert(mailbox:recv()[1] == "other","fifth message was wrong")
    end)
    
    coroutine.resume(thread)

    for _,msg in pairs({{'asdf'},{'qwerty'},{'test'}}) do
      mailbox:insert(unpack(msg))
      alive,err = coroutine.resume(thread)
      assert(alive or not err,err)
    end

    mailbox:insert('other')
    mailbox:insert('test')

    repeat
      alive,err = coroutine.resume(thread)
      if not alive then
        assert(err == 'cannot resume dead coroutine',err)
      end
    until not alive
    
  end)
end)