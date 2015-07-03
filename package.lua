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
  ,tags = 
    {"failover"
    ,"cluster"}
  ,license = "MIT"
  ,homepage = "https://github.com/pagodabox/tag"
  ,description = "Tag nodes and enjoy automatic failover for your cluster!"
  ,dependencies = 
    {"luvit/tap@0.1.0-1"
    ,"luvit/require@1.2.0"
    ,"luvit/core@1.0.2-1"
    ,"luvit/fs@1.2.0"
    ,"luvit/json@2.5.0"
    ,"creationix/coro-http@1.2.0"
    ,"creationix/weblit-app@0.2.6-1"
    ,"creationix/weblit-auto-headers@0.1.2-1"
    ,"creationix/mime@0.1.2-1"
    ,"creationix/weblit-websocket@0.2.3-2"
    ,"creationix/coro-split@0.1.1"
    ,"creationix/coro-fs@1.3.0"
    ,"pagodabox/cauterize@0.1.1"
    ,"pagodabox/lmmdb@0.1.1"
    ,"pagodabox/logger@0.1.0"
    ,"pagodabox/parse-opts@0.1.0"
    ,"pagodabox/splode@0.1.0"}
  ,files =
    {"**.lua"
    ,"**.txt"
    ,"**.so"
    ,"!examples"
    ,"!tests"}}