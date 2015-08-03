-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   23 July 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

exports.name = "pagodabox/ffi-cache"
exports.version = "0.1.0"
exports.description = 
  "caches typeof and sizeof ffi lookups to avoid costly parsing of c declarations"
exports.tags = {"ffi"}
exports.license = "MIT"
exports.deps = {}
exports.author =
    {name = "Daniel Barney"
    ,email = "daniel@pagodabox.com"}
exports.homepage = 
  "https://github.com/pagodabox/tag/blob/master/deps/ffi-cache.lua"

local ffi = require('ffi')

exports.sizeof = {}
exports.typeof = {}

-- memorize the size of c type objects
setmetatable(exports.sizeof, {
  __index = function(self, key)
    local size = ffi.sizeof(key)
    rawset(self, key, size)
    return size
  end
  })

-- memorize constructors for c type objects
setmetatable(exports.typeof, {
  __index = function(self, key)
    local template = ffi.typeof(key)
    rawset(self, key, template)
    return template
  end
})