-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   21 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local choose_one = require('../lib/system/topology/choose_one')
local crc32 = require('../lib/store/basic/hash').crc32_string
local hash = require('../lib/system/topology/hash')
local nothing = require('../lib/system/topology/nothing')
local replicated = require('../lib/system/topology/replicated')
local round_robin = require('../lib/system/topology/round_robin')

require('tap')(function (test)
  
  test('nothing topology returns nothing',function()
    local data = nothing()
    assert(#data == 0,'got something')
  end)

  test('choose_one topology assigns data correctly',function()
    local data = choose_one({1,2,3},{1,2},{true,true},2)
    assert(#data == 1,'got more then 1 peice of data')
    assert(data[1] == 2,'wrong peice of data was assigned')
  end)

  -- this one runs out of memory????
  
  -- test('hash topology correctly divides data',function()
  -- 	p('(initial) memory size',collectgarbage('count'))
  -- 	local all_points = {}
  --   for i = 1,1000 do
  --     all_points[i] = {hash = crc32(tostring(i))}
  --     p(i,'memory size',collectgarbage('count'))
  --   end

  --   for node_count = 5,100 do  
  --     local nodes = {}
  --     local node_states = {}
  --     for i = 1,node_count do
  --       nodes[i] = i
  --       nodes[node_states] = true
  --       p('(node) memory size',collectgarbage('count'))
  --     end
  --     p('going to hash')
  --     local data = hash(all_points,nodes,{true,true,true,true,true},2)
  --     p('checking',#data,#all_points/node_count,node_count)
  --     assert(#data / #all_points/node_count < 1.05,'difference is too high')
  --   end
  -- end)

  test('replicated topology does nothing to the data',function()
    local data = replicated({1,2,3},{1,2},{true,true},2)
    assert(#data == 3,'got more then 1 peice of data')
    assert(data[1] == 1,'wrong peice of data was assigned')
    assert(data[2] == 2,'wrong peice of data was assigned')
    assert(data[3] == 3,'wrong peice of data was assigned')
  end)

  test('round_robin topology correctly moved data around nodes',function()
    
  end)
end)