-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :  19 May 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------
local Ref = require('./ref')
local hrtime = require('uv').hrtime
local Object = require('core').Object
local Mailbox = Object:extend()


function Mailbox:initialize()
  self._selective = nil -- matches for a selective revc
  self._mailbox_searched = false -- flag for searching the mailbox
  self._box = {}
end

local function message_match(patterns,flag)
  for _,tag in pairs(patterns) do
    if tag == flag then
      return true
    end
  end
  return false
end

function Mailbox:match(flag)
  -- this could be set by an insertion
  if self._match then
    assert(self._selective ~= nil,"impossible match found")
    return true
  end

  if self._selective ~= nil then
    -- search the mailbox if we havne't yet.
    if not self._mailbox_searched then
      self._mailbox_searched = true
      for idx,message in pairs(self._box) do
        if message_match(self._selective,message[1]) then
          -- store off the match that was found so that we don't have
          -- to search the mailbox again
          table.remove(self._box,idx)
          self._match = message
          return true
        end
      end
    end

    -- otherwise check this message
    if message_match(self._selective,flag) then
      return true
    else
      return false
    end
  end
  -- if we are not doing a selective recv, then everything matches.
  -- but only if there is a message
  return flag ~= nil or #self._box > 0 
end

function Mailbox:get_message(message)
  local match = self._match
  -- clear out the match that was stored
  self._match = nil

  if not match then
    -- return the first message, no match was found
    match = table.remove(self._box,1)
  end
  return match
end

-- pull a message from the mailbox that matches the patterns passed in
function Mailbox:recv(tags,timeout)
  local ref = nil
  if timeout ~= nil and (type(timeout) ~= "number" or timeout < 0) then
    p(timeout)
    error('invalid timeout value')
  end
  
  -- if tags is a string, lets make it a list
  if type(tags) == "string" then
    tags = {tags}
  end

  -- if we are going to timeout, lets wait for a timeout message
  if timeout then
    if not tags then tags = {} end
    -- we need a ref so that no one else can inturupt this timeout
    ref = Ref.make()
    tags[#tags + 1] = ref
    self:yield('send',{'$self',0,timeout,ref})
  end

  -- store off the tags so that we can access them later
  self._selective = tags
  self._mailbox_searched = false

  -- wait for a message matching what is in self._selective
  while not self:match() do
    if self._match then
      -- we have the message, but lets let others run
      self:yield("yield")
    else
      -- we don't have anything in our mailbox, lets wait for it to
      -- arrive
      self:yield("pause")
    end
  end
  
  -- clear out the _selective, we don't need it anymore
  self._selective = nil
  self._mailbox_searched = false

  if timeout and self._match[1] == tags[#tags] then
    -- clear out the timer ref message
    self._match = nil
    return nil
  else
    -- get the message that matched the pattern
    return self:get_message()
  end
end


-- insert a message into the mailbox. returns if the message matches
-- any of the patterns that are set
function Mailbox:insert(...)
  local msg = {...}
  if not self._match and self:match(msg[1]) then
    -- only record the msg if we are doing a selective recv
    if self._selective ~= nil then
      self._match = msg
      return true
    else
      -- if we aren't doing a selective recv, then store the msg off
      self._box[#self._box + 1] = msg
      return true
    end
  end
  
  -- we need to insert the message into the mailbox
  self._box[#self._box + 1] = msg
  return false
end

function Mailbox:yield(...)
  local ret = {coroutine.yield(...)}
  if ret[1] == 'exit' then
    error(ret[2])
  end
  return unpack(ret)
end

return Mailbox