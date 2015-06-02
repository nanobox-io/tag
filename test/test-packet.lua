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

local Cauterize = require('cauterize')
local uv = require('uv')
local Packet = require('../lib/failover/packet')
local Node = require('../lib/failover/node')
local Config = require('../lib/config')

local Reactor = Cauterize.Reactor
Reactor.continue = true -- don't exit when nothing is left
require('tap')(function (test)
  
  test('udp sockets can correctly start up',function()
    local Test = Packet:extend()
    local got_packet = false
    function Test.udp_recv(self,...)
      got_packet = true
      p('got message',...)
    end

    function Test:stop()
      self:_stop()
      return true
    end

    local host,port = "127.0.0.1",1234

    Reactor:enter(function(env)
    	Config:new(env:current())
      local node1 = 
        {name = 'n1'}
      local node1 = Node:new(env:current(), node1)

      local pid = Test:new(env:current(),host,port)
      Test.call(pid,'enable')
      local udp = uv.new_udp()
      uv.udp_bind(udp, host, 1235)
      
      uv.udp_send(udp, "testing", host, port)
      env:recv(nil,100)

      uv.udp_send(udp, "testing1", host, port)
      env:recv(nil,100)
      
      uv.close(udp)
      Test.call(pid,'stop')
    end)

    assert(got_packet,'did not get the packet')

  end)

  test('udp packets recevied can trigger state changes',function()
    local host,port = "127.0.0.1",1234
    local nodes = {}
    Reactor:enter(function(env)
    	Config:new(env:current(),{nodes_in_cluster = {}})
      local packets = {}
      for i = 0, 2 do
        local Test = Packet:extend()
        -- overwritten so that we can dynamically decide which node we
        -- need to talk to
        function Test:update_state_on_node(name,...)
          if #name == 3 then
            Packet.cast(tostring(i).."a"..name:sub(3),...)
          else
            Packet.cast(tostring(i).."a"..name,...)
          end
        end
        function Test:get_node_state(name,...)
          return Packet.call(tostring(i).."a"..name,'get_state')
        end
        function Test:is_node_local(name)
          return name == tostring(i)
        end
        packets[i] = Test:new(env:current(), host, port + i,
        	tostring(i) .. "a" .. tostring(i), true)
        Packet.call(packets[i],'remove_node',{name = 'n1'})
        nodes[i] = {}
        for j = 0, 2 do 
          local opts = 
            {quorum = 2,name = i.."a"..j,host = host, port = port + j}
          nodes[i][j] = Node:new(env:current(), opts)
          opts.name = tostring(j)
          Packet.call(packets[i],'add_node',opts)
        end
        Packet.call(packets[i],'enable')
      end

      env:recv(nil,4000)
      
      for i = 0, 2 do
        Packet.call(packets[i],'disable')
        for j = 0, 2 do 
          local state = Node.call(nodes[i][j],'get_state')
          Node.cast(nodes[i][j],'_stop')
          nodes[i][j] = state
        end
      end
    end)
    p('final states',nodes)
    local up,down = 0,0
    for i = 0, 2 do
      for j = 0, 2 do
        if nodes[i][j] == 'up' then
          up = up + 1
        else
          down = down + 1
        end
      end
    end
    assert(down == 0, tostring(down) .. ' nodes were down out of '.. tostring (up + down))
  end)
end)