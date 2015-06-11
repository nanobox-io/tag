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

local Proc = require('./proc')
local Server = Proc:extend()

function Server.call(pid,...)
  return Server:_link_call(pid,'$call',...)
end


function Server.cast(pid,...)
  Server:send(pid,'$cast',{...},nil)
end

-- default handler for unhandled 'call' and 'cast' messages
function Server:_unhandled() return {false,'message not accepted'} end

function Server:_perform(ref,fun,...)
  local ret = nil
  if type(self[fun]) == 'function' then
    -- should this allow multiple returns?
    ret = self[fun](self,...)
  else
    -- do we really want this functionality?
    ret = self:_unhandled(fun,...)
  end
  self:respond(ref,ret)
end

function Server:_loop(msg)

  local fun,args,ref = unpack(msg)
  if fun == '$call' then
    self._current_call = ref
    self:_perform(ref,unpack(args))
  elseif fun == '$cast' then
    self:_perform(nil,unpack(args))
  elseif args == 'down' or args == '$exit' then
    self:_perform(nil,'down',unpack(msg))
  elseif type(fun) == 'userdata' then
    table.remove(msg,1)
    self:_perform(nil,fun,unpack(msg))
  else
    self:_perform(nil,'handle_message',msg)
  end
  self._current_call = nil
end

return Server