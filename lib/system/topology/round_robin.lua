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

-- round_robin evenly divides the data over all nodes in the cluster.
-- when one node is down, the data is divided over the remaining nodes
return function(data,order,state,id)

  -- if this node is not alive, then we don't need to do any
  -- calcualtions
  if not state[id] then
    return {}
  end

  local add = {}
  local count = #order
  local failover_idx = 0
  local alive_count = count
  local node_idx = count + 1 -- really gets set in the for loop
  local node_failover_idx = 0
  local is_alive = {}
  
  -- count how many servers are alive, count how many servers have
  -- failed before we find the id so that we can shift the id down
  -- when we are doing failover for other nodes
  local failed_count = 0
  for idx,name in pairs(order) do
    if name == id then
      node_idx = idx
    end
    local alive = state[name]
    is_alive[idx] = alive
    if not alive then
      if idx < node_idx then
        failed_count = failed_count + 1
      end
      alive_count = alive_count - 1
    end
  end
  node_failover_idx = node_idx - failed_count

  for i=1,#data do
    -- lua arrays are not 0 indexed, but mod is, so we account for it
    -- here
    local real_idx = ((i - 1) % count) + 1
    if real_idx == node_idx then
      -- the data point is assigned to this node
      add[#add + 1] = data[i]

    elseif not is_alive[real_idx] then
      -- if the other node is down, and we are responsible for it then
      -- add it in
      if ((failover_idx - 1) % alive_count) + 1 == 
          node_failover_idx then
        add[#add + 1] = data[i]
      end
      failover_idx = failover_idx + 1
    end
  end

  return add
end