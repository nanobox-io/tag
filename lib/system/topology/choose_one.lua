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

return function(data,order,state,id)
  for idx,name in pairs(order) do
    if name == id then
      is_alive = state[name]
      if is_alive then
        return {data[idx % #data +1 ]}
      end
    end
  end

  return {}
end