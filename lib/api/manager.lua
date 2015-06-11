-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 0; st-rulers: [70] -*-
-- vim: ts=2 sw=2 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   15 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local Cauterize = require('cauterize')
local Luvi = require('luvi')
local json = require('json')
local weblit = require('weblit-app')
local Api = Cauterize.Supervisor:extend()
local Splode = require('splode')
local util = require('../util')
local splode = Splode.splode

function Api:_manage()
  
  self.node = node or util.config_get('node_name')
  local gossip_config = util.config_get('nodes_in_cluster')[self.node]
  gossip_config = json.decode(tostring(gossip_config))

  local files = splode(Luvi.bundle.readdir,'no routes were present',
    'lib/api/routes')
  
  p('api listening on',gossip_config.host,gossip_config.port)
  weblit
    .use(require('weblit-auto-headers'))
    .bind(
      {host = gossip_config.host
      ,port = gossip_config.port})
    .use(function(req,res,go)
      local etag = req.headers['if-none-match']
      res.keepAlive = true
      go()
      -- don't need to json encode something that we don't care about.
      if res.headers.etag and etag == tostring(res.headers.etag) then
        res.body = nil
      else
        if type(res.body) == 'table' then
          res.body = json.encode(res.body)
        else
          res.body = tostring(res.body)
        end
      end
    end)

  for _,file in pairs(files) do
    local route = require('./routes/' .. file)
    p('loading route',route)
    weblit.route(route,route.route)

  end
  weblit.start()
end

return Api