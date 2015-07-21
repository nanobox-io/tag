-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   27 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------


local Object = require('core').Object
local Plan = Object:extend()

function Plan:initialize(on)
  self.on = {}
  self:next(on)
end

function Plan:next(on)
  if not on then on = {} end
  
  self.add = {}
  self.remove = {}
  local index = 1
  local lidx = 1

  -- compare the two sets of data, compile a list of things to add,
  -- with a second list of things to remove.
  -- data stored in lmmdb is always sorted
  while lidx <= #on do

    if self.on[index] == nil or on[lidx] == nil then
      -- if we run out of data, then we don't need to compare anymore
      break
    elseif self.on[index] > on[lidx] then
      -- we need to add data points that are members of on and 
      -- not members of self.on
      self.add[#self.add +1] = on[lidx]
      lidx = lidx + 1
    elseif self.on[index] < on[lidx] then
      -- we need to remove data points that are members of self.on and 
      -- not members of on
      self.remove[#self.remove +1] = self.on[index]
      index = index + 1
    else
      assert(self.on[index] == on[lidx],
        'got two elements that were not <, >, or == to each other')
      lidx = lidx + 1
      index = index + 1
    end
  end

  -- everything leftover else gets removed
  for index = index, #self.on do
    self.remove[#self.remove +1] = self.on[index]
  end

  -- everything leftover else gets added
  for idx = lidx, #on do
    self.add[#self.add +1] = on[idx]
  end

  self.on = on
end

function Plan:changes()
  return self.add, self.remove
end

return Plan