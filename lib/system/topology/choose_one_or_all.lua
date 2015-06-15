-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   9 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

-- if the index of the id idn't larger then the number of elements in
-- the data array, then return all data points, if it is larger, then
-- choose_one from the data array
return function(data,order,state,id)
  local index
  for i = 1, #order do
    if order[i] == id then
      if i <= #data then
        table.remove(data,i)
        return data
      end
      index = i
      break
    end
  end
  if index == nil then
    return {}
  else
    return {data[(index - 1) % #data + 1]}
  end
end