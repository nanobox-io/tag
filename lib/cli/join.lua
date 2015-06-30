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
local http = require('coro-http')
local json = require('json')

function exports.cmd(global, config, ip, port)
  assert(ip,'unable to join a cluster without an ip to connect to')
  assert(port,'unable to join a cluster without a port to connect to')
  p('telling',global.host,global.port,'to join',ip,port)
  

  coroutine.wrap(function()
    local url = table.concat(
      {'http://'
      ,global.host
      ,':'
      ,global.port
      ,'/store/nodes'})
    local headers = {}

    local res, data = http.request('GET',url,{})
    p(res,data)
    assert(res.code == 200 or res.code == 203,'bad response from node')
    data = json.parse(data)
    local node_name = nil
    for name,timestamp in pairs(data) do
      node_name = name
      break
    end
    assert(node_name,'no node avaible')
    
    url = url .. '/' .. node_name
    res, data = http.request('GET',url,{})
    p(res,data)
    assert(res.code == 200 or res.code == 203,'unable to get node info')
    local add_url = table.concat(
      {'http://'
      ,ip
      ,':'
      ,port
      ,'/store/nodes/'
      ,node_name})
    res, data = http.request('POST',add_url,{},data)
    p(res,data)


    -- I need to wait around for the first node to know about the other nodes
  end)()
end

exports.opts = {}