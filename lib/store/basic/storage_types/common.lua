-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Pagoda Box, Inc.
-- @doc
--
-- @end
-- Created :   13 July 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

local db = require('lmmdb')
local Txn = db.Txn

-- remove a key from the database, this should be a tombstoned value
function exports:del(txn, info)
  local key = info[2]
  local header = self:resolve(txn, self.objects, key, 'header_t')
  if header then
    if header.type == 'SET' then
      assert(Txn.del(txn, self.set_elements, key))
    elseif header.type == 'QUEUE' then
      assert(Txn.del(txn, self.queue_items, key))
    end
    
    assert(Txn.del(txn, self.objects, key))
    return 1
  else
    return 0
  end
end

function exports:echo(txn, info)
  return info[2] or ''
end

function exports:type(txn, info)
  local key = info[2]
  local header = self:resolve(txn, self.objects, key, 'header_t')
  if not header then
    return 'none'
  else
    if header.type == 0 then
      return 'none'
    elseif header.type == 1 then
      return 'string'
    elseif header.type == 2 then
      return 'number'
    elseif header.type == 3 then
      return 'set'
    elseif header.type == 4 then
      return 'queue'
    else
      return 'unknown'
    end
  end
end

function exports:keys(txn, info)

end

function exports:exists(txn, info)
  local key = info[2]
  local header = self:resolve(txn, self.objects, key, 'header_t')
  return header ~= false
end

function exports:tail(txn, info)
  local key = info[2]
  local tails = self.tails[key]
  if not tails then
    tails = {}
    self.tails[key] = tails
  end
  local idx = #tails + 1
  local call_back
  tails[idx] = function(info)
    if call_back then
      call_back(info)
    end
  end

  return function(cb)
    call_back = cb
  end
end