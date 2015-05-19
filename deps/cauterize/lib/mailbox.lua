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
local hrtime = require('uv').hrtime
local RunQueue = require('./run_queue')
local Object = require('core').Object
local Mailbox = Object:extend()


function Mailbox:initialize()
	self._selective = nil -- matches for a selective revc
	self._box = {}
end

local function message_match(patterns,message)
	for _,tag in pairs(patterns) do
		if tag == message[1] then
			return true
		end
	end
	return false
end

function Mailbox:match(message)
	-- this could be set by an insertion
	if self._match then
		assert(self._selective ~= nil,"impossible match found")
		return true
	end

	if self._selective ~= nil then

		if message then
			-- if we are comparing one message
			if message_match(self._selective,message) then
				return true
			else
				return false
			end
		else
			-- if we are searching the mailbox
			for idx,message in pairs(self._box) do
				if message_match(self._selective,message) then
					-- store off the match that was found so that we don't have
					-- to search the mailbox again
					table.remove(self._box,idx)
					self._match = message
					return true
				end
			end
			return false
		end
	end
	-- if we are not doing a selective recv, then everything matches.
	-- but only if there is a message
	return message ~= nil or #self._box > 0 
end

function Mailbox:get_message(message)
	local match = self._match
	-- clear out the match that was stored
	self._match = nil

	if not match then
		-- return the first message, no match was found
		return table.remove(self._box,1)
	end
	return match
end

-- pull a message from the mailbox that matches the patterns passed in
function Mailbox:recv(tags,timeout)
	local ref = nil
	if timeout ~= nil and (type(timeout) ~= "number" or timeout < 0) then
		error('invalid timeout value')
	end
	
	-- if tags is a string, lets make it a list
	if type(tags) == "string" then
		tags = {tags}
	end

	-- if we are going to timeout, lets wait for a timeout message
	if timeout and tags then
		-- we need a ref so that no one else can inturupt this timeout
		ref = Ref.make()
		tags[#tags + 1] = ref
	end

	-- store off the tags so that we can access them later
	self._selective = tags

	-- wait for a message if we need one
	local wait = false
	while not self:match() and (timeout == nil or timeout > 0) do
		wait = true
		-- inform the reactor why we are waiting
		coroutine.yield("timeout",{timeout,ref})
	end
	if not wait then
		-- let other processes run
		coroutine.yield("timeout")
	end
	
	-- clear out the _selective, we don't need it anymore
	self._selective = nil

	-- get the message that matched the pattern
	return self:get_message()
end


-- insert a message into the mailbox. returns if the message matches
-- any of the patterns that are set
function Mailbox:insert(msg)
	if not self._match and self:match(msg) then
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

return Mailbox