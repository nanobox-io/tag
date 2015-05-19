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
return
  {name = "pagodabox/actor"
  ,version = "0.1.0"
  ,author =
    {name = "Daniel Barney"
    ,email = "daniel@pagodabox.com"}
  ,tags = {"actor","coroutine","syncronous"}
  ,license = "MIT"
  ,homepage =
    "https://github.com/pagodabox/tag/blob/master/deps/actor"
  ,description = "Actor like behaviour for lua corotines"
  ,dependencies = 
    {"luvit/tap@0.1.0-1"
    ,"luvit/require@1.2.0"
    ,"luvit/core@1.0.2-1"}
  ,files =
    {"**.lua"
    ,"!examples"
    ,"!tests"}}