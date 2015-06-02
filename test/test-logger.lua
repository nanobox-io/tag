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


require('tap')(function (test)
  local logger = require('logger')
  test('can add a logging endpoint',function()
    
    local count = 0;
    logger.add_logger('debug','test',function(level,arg)
      assert(arg == 'testing','logging arguments did not match')
      count = count + 1
    end)
    logger.add_logger('error','test',function(level,arg)
      assert(arg == 'testing','logging arguments did not match')
      count = count + 1
    end)

    logger.debug('testing')
    assert(count == 1, 'one match is only called once')

    logger.error('testing')
    assert(count == 3, 'two matches is called twice')
    
    logger.remove_logger('error','test')
    logger.remove_logger('debug','test')
    logger.error('testing')
    assert(count == 3, 'after removing, nothing is logged')
  end)
end)