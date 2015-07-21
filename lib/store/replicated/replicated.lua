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

-- ok so a few rules
-- prefixing a key with '#' disables replication for that key
-- prefixing a key with '$' enables splitting of the data across
--   nodes in the cluster. ensures that all members of a list/set/hash
--   are split across multiple nodes (this can really break things and
--   probably isn't reccommended unless you fully understand the
--   consequences.)
-- prefixing a key with '!' enables cluster wide replication, aka
--   the values are stored on every Peer before returning sucess to
--   the client.
-- prefixing a key with '~' will cause the data to be stored on every
--   Peer, but wihout waiting for all Peers to acknowlege that the key
--   was stored sucessfully
-- by default keys will be stored on the node that processed the
--   request, and on Peers of the node.
-- there is a set called #subscribed-keys that contains a list of all
--   keys that are being synced down from the Peer nodes.
-- there also exists a flag called #leader-node that informs the
--   node that all keys need to be synced from the Peer nodes, false
--   means that #subscribed-keys is used.
-- there also a key called #enable-proxy that turns the node
--   into just a proxy for the cluster, as data queried will not be
--   synced to the local node


local Store = require('../basic/basic')

local Replicated = Store:extend()
local replication_map = {}

local function split_division()

end

local function disabled_replication()

end

local function all_replicated()

end

local function eventually_replicated()

end

local function my_peers()

end

replication_map[string.byte('$')] = split_division
replication_map[string.byte('#')] = disabled_replication
replication_map[string.byte('!')] = all_replicated
replication_map[string.byte('~')] = eventually_replicated

function Replicated:perform(info, read, write)
  local key = info[2]
  local char = data:byte()
  local replication_strategy = replication_map[char]
  if not replication_strategy then
    replication_strategy = my_peers
  end
  local name = info[1]:lower()
  if Basic.valid_cmds[name] then
    -- get the key location
    return pcall(self[name],self, nil, info, read, write)
  else
    return false, 'UNKNOWN COMMAND'
  end
end