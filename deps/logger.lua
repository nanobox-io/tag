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

exports.name = "pagodabox/logger"
exports.version = "0.1.0"
exports.description = 
  "A simple logger framework that only manages log levels"
exports.tags = {"logger","level","log"}
exports.license = "MIT"
exports.author =
    {name = "Daniel Barney"
    ,email = "daniel@pagodabox.com"}
exports.homepage = 
  "https://github.com/pagodabox/tag/blob/master/deps/logger.lua"

local levels = {'debug','info','warning','error','fatal'}
local Logger = {}
local loggers = {}

do
  -- each level of the logger needs to also pass the message to the
  -- next level
  local gen_level = function(index)
    return function(...)
      for i = index, 1, -1 do
        local level = levels[i]
        for _idx, listener in pairs(loggers[level]) do
          listener(level, ...)
        end
      end
    end
  end

  -- setup the functions for logging.
  for idx,level in ipairs(levels) do
    Logger[level] = gen_level(idx)
    loggers[level] = {}
  end
end

local function valid_level(level)
  if not loggers[level] then
    error "unknown level"
  end
end

function Logger.add_logger(level,id,fun)
  valid_level(level)
  if loggers[level][id] then
      error "endpoint already exists"
  end
  if not fun then
    fun = p
  end

  loggers[level][id] = fun
end

function Logger.remove_logger(level,id)
  valid_level(level)
  loggers[level][id] = nil
end

return Logger