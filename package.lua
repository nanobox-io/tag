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
  {name = "pagodabox/tag"
  ,version = "0.0.1"
  ,author =
    {name = "Daniel Barney"
    ,email = "daniel@pagodabox.com"}
  ,tags = {"failover","vip"}
  ,license = "MIT"
  ,homepage = "https://github.com/pagodabox/tag"
  ,dependencies = 
    {"luvit/tap@0.1.0-1"}
  ,files =
    {"**.lua"
    ,"**.txt"
    ,"**.so"
    ,"!examples"
    ,"!tests"
    ,"!.DS_Store"}}