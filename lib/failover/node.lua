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

local Cauterize = require('cauterize')
local Name = require('cauterize/lib/name')
local log = require('logger')
local Node = Cauterize.Fsm:extend()

function Node:_init(config)
  self.state = 'down'

  -- dynamic config options
  self.needed_quorum = Cauterize.Fsm.call('config', 'register',
  	self:current(), 'needed_quorum', 'quorum_update')
  self.node_wait_for_response_intreval = Cauterize.Fsm.call('config',
    'register', self:current(), 'node_wait_for_response_interval',
    'udpate_config')
  
  self.reports = {}
  self.timers = {}
  self.name = config.name
  Name.register(self:current(),self.name)
end

-- set up some states
Node.down = {}
Node.up = {}

-- we got an update to the config value, lets set it
function Node:update_config(key,value)
  self[key] = value
end

function Node:quorum_update(key,value)
  assert(key == 'needed_quorum',
    'wrong key was passed to update quorum')
  self[key] = value

  -- we we need to recheck our node state
  self:change_state_if_quorum_satisfied()
end


-- we only want to check if we need to change states if up is called
-- in the down state or down in the up state.
function Node.down:up(who)
  self:set_remote_report(who,true)
  self:change_state_if_quorum_satisfied()
end

function Node.up:down(who)
  self:set_remote_report(who,false)
  self:change_state_if_quorum_satisfied()
end

-- up in up and down in down can't change the state
function Node.up:up(who)
  self:set_remote_report(who,true)
end

function Node.down:down(who)
  self:set_remote_report(who,false)
end

function Node:set_remote_report(who,node_is_up)
  -- cancel a timer if one was created
  if self.timers[who] then
    self:cancel_timer(self.timers[who])
  end
  self.reports[who] = node_is_up
end

function Node:set_permenant_state(state)
  self:change_to_new_state_and_notify(state)
  self.is_permenant = true
  return true
end

-- we are going to be waiting for this node to respond, start a timer
-- so that if it doesn't respond in time we will automatically mark
-- this node as down
function Node.up:start_timer(who)
  self.timers[who] = self:send_after('$self',
    self.node_wait_for_response_intreval, '$cast', {'down', who})
end

function Node:get_state()
  return self.state
end

function Node:change_state_if_quorum_satisfied()
  if not self.is_permenant then
    local up_quorum_count = 0
    for _,node_is_up in pairs(self.reports) do
      if node_is_up then
        up_quorum_count = up_quorum_count + 1
      end
    end

    if up_quorum_count >= self.needed_quorum then
      self:change_to_new_state_and_notify('up')
    else
      -- this is also a quorum, but for down.
      self:change_to_new_state_and_notify('down')
    end
  end
end

-- only change state if the new_state is different from the current
-- state
function Node:change_to_new_state_and_notify(new_state)
  if self.state ~= new_state and not self.is_permenant then
    self.state = new_state
    log.warning('node changed state',self.name,new_state)
    -- TODO notify everyone who wants a notification
  end
end

return Node