-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   2 June 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------
local log = require('logger')

local default =
  {node_name = 'n1'
  ,replicated_db = false
  ,database_path = './database'
  ,node_wait_for_response_interval = 2000
  ,nodes = 
    {n1 = {host = "127.0.0.1", port = 1234}}
  ,max_packets_per_interval = 2
  ,systems = {}}

local function create_store(config)
  local Store
  if config.replicated_db then
    log.info('loading replicated store', config.database_path)
    Store = require('./store/replicated/replicated')
  else
    log.info('loading basic store', config.database_path)
    Store = require('./store/basic/basic')
  end

  -- create a new instance from a promise!!! gross.
  local meta = assert(rawget(Store, "meta")
    ,"Cannot inherit from instance object")
  local store = 
    setmetatable(require('./store/main').singleton(), meta)

  store:initialize(config.database_path)
  
  return store
end

return function(config)
  -- merge the defaults and the new values
  for key,value in pairs(config) do
    default[key] = value
  end
  local store = create_store(default)
  if store:exists(nil, {'exists', '#config-loaded'}) then
    log.info('config has already been loaded, ignoring new options')
  else
    log.info('loading all config file options into store')
    for key, value in pairs(default) do
      if key == 'systems' then
        for name, opts in pairs(value) do
          if type(opts.data) == 'table' then
            local data_name = 'system-' .. name .. '-data'
            log.debug('adding system data', data_name, opts.data)
            store:sadd(nil, {'sadd', data_name, unpack(opts.data)})
            opts.data = data_name
          end
          local cmd = {'hmset', name}
          for k,v in pairs(opts) do
            cmd[#cmd + 1] = k
            cmd[#cmd + 1] = v
          end
          log.debug('setting system',cmd)
          store:hmset(nil, cmd)
        end
      elseif key == 'nodes' then
        for name, opts in pairs(value) do
          
          if opts.systems then
            for system_id, system_opts in pairs(opts.systems) do
              log.debug('adding node to system',system_id .. '-nodes', name)
              store:sadd(nil, {'sadd', system_id .. '-nodes', name})
              if name == config.node_name then
                log.debug('added system to list on this node',system_id)
                store:sadd(nil, {'sadd', '#systems', system_id})
              end
            end
          end
          opts.systems = nil

          local cmd = {'hmset', '!' .. name}
          for k,v in pairs(opts) do
            cmd[#cmd + 1] = k
            cmd[#cmd + 1] = v
          end
          log.debug('adding node',cmd)
          store:hmset(nil, cmd)
          log.debug('adding node to node set', '!nodes', name)
          store:sadd(nil,{'sadd', '!nodes', name})
        end
      else
        log.debug('setting config value', '#' .. key, value)
        store:set(nil, {'set', '#' .. key, value})
      end
    end
    store:set(nil, {'set', '#config-loaded', 'true'})
  end
end