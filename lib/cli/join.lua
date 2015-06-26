-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   26 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

function exports.cmd(global, config, ip, port)
  assert(ip,'unable to join a cluster without an ip to connect to')
  assert(port,'unable to join a cluster without a port to connect to')
  p('telling',global.host,global.port,'to join',ip,port)
end

exports.opts = {}