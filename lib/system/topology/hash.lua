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

local jch = require('jch')

return function(data,order,state,id)
  local bucket = nil

  for idx,name in pairs(order) do
    if name == id then
      bucket = idx
      break
    end
  end

  local elems = {}
  local count = #order
  for _,elem in pairs(data) do
  	-- data.hash is the crc32 hash of the data, it should give us good
  	-- enough distribution as a hashing key for jch
  	if jch(data.hash,count) == bucket then
  		elems[#elems + 1] = elem
  	end
  end

  return elems
end