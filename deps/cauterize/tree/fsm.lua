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

local Server = require('./server')
local Fsm = Server:extend()

-- we need a custom _perform function to support the syntax of
-- Class.state:function()
function Fsm:_perform(ref,fun,...)
  local ret = nil
  if self.state == nil then
    p(self)
    error('unable to have a nil state')
 end
  if self[self.state] ~= nil and 
      type(self[self.state][fun]) == "function" then

    -- call a function on a state member
    ret = self[self.state][fun](self, ...)

    self:respond(ref,ret)
  else
    -- pass call upto parent class Server
    Server._perform(self,ref,fun,...)
  end
end

return Fsm