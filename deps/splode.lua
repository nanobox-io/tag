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

exports.name = "pagodabox/splode"
exports.version = "0.1.0"
exports.description = 
  "wrap a function to log, and throw an error"
exports.tags = {"error","explode","throw"}
exports.license = "MIT"
exports.deps = {"pagodabox/logger@0.1.0"}
exports.author =
  	{name = "Daniel Barney"
  	,email = "daniel@pagodabox.com"}
exports.homepage = 
  "https://github.com/pagodabox/tag/blob/master/deps/splode.lua"

local log = require('logger')

-- log the error, then throw an error
local function log_break(msg,err)
	if err ~= nil then
		log.warning(msg,err)
		error(err,0)
	end
end

-- wrap a function to throw an error if it returned an error
function exports.splode(fun,msg,...)
	return exports.xsplode(1,fun,msg,...)
end

-- wrap a function that returns a specific number args then an error
function exports.xsplode(count,fun,msg,...)
	local ret = {fun(...)}
	log_break(msg,ret[count + 1])
	return unpack(ret)
end