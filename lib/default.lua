-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   2 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

return
  {node_name = 'n1'
  ,replicated_db = false
  ,database_path = './database'
  ,node_wait_for_response_interval = 2000
  ,nodes_in_cluster = 
    {{name = 'n1', host = "127.0.0.1", port = 1234}}
  ,needed_quorum = 2
  ,max_packets_per_interval = 2
  ,systems = {}}