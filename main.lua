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
local logger = require('logger')
local os = require('os')

function main()
	if process.argv[1] == '-server' then
		logger:add_logger('info','console',function(...) p(os.date("%x %X"),...) end)
		logger:info("starting server")
		if #process.argv == 3 then
			table.remove(process.argv,1)
			require('./lib/server')
		else
			logger:info("Usage: tag -server (-config-file|-config-json) {path|json}")
		end
	else
		logger:add_logger('info','console',function(...) p(...) end)
		logger:debug("entering cli mode")
		require('./lib/cli')
	end
end
main()