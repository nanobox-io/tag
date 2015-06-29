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

local hrtime = require('uv').hrtime
local fs = require('coro-fs')
local db = require('lmmdb')
local Env = db.Env
local DB = db.DB
local Txn = db.Txn
local Cursor = db.Cursor


local function time_and_repeat(count,fun)

  local start = hrtime()
  for i=1, count do
    fun(i)
  end

  local per_second = count / ((hrtime() - start)/ 100000000000)
  per_second = math.floor(per_second) / 100
  return per_second
end


require('tap')(function (test)
  
  test('can we pass 11 million messages per second?',function()
    -- uncomment if you want to test speed
    
    -- -- local thread = coroutine.create(function()
    --  for i=1,100000000 do
    --    coroutine.yield()
    --  end
    -- end)
    -- local count = 0
    -- local start = hrtime()
    -- while coroutine.resume(thread) do count = count + 1 end
    -- assert(11000000 < count / ((hrtime() - start) / 1000000000),"resuming from a coroutine is too slow.")
  end)

  test('how fast are store operations?',coroutine.wrap(function()
    local opts = 
      {Env.MDB_NOSYNC
      ,Env.MDB_NOMETASYNC
      ,Env.MDB_NORDAHEAD
      ,Env.MDB_NOMEMINIT}

    local combos = 
      {{1,2,3,4}
      ,{1,2,3}
      ,{1,2,4}
      ,{1,3,4}
      ,{2,3,4}
      ,{1,2}
      ,{1,3}
      ,{1,4}
      ,{2,3}
      ,{2,4}
      ,{3,4}
      ,{1}
      ,{2}
      ,{3}
      ,{4}
      ,{}}

    local i = 1
    local get_opt = function()
      local option = combos[i]
      i = i + 1
      if option then
        local sum = 0
        for _,idx in pairs(option) do
          sum = sum + opts[idx]
        end
        return sum
      end
    end
    fs.unlink('./test-db')
    local stats = {}
    for opt in get_opt do
      p('testing',opt)
      local stat = {}
      stats[opt] = stat
      local env = Env.create()

      err = Env.open(env, './test-db', Env.MDB_NOSUBDIR + Env.MDB_NOLOCK + opt, tonumber('0644', 8))

      local txn = Env.txn_begin(env, nil, 0)
      local objects = DB.open(txn, "testing", DB.MDB_CREATE)
      Txn.commit(txn)

      stat.insert = time_and_repeat(100000,function(id)
        local txn = Env.txn_begin(env, nil, 0)
        Txn.put(txn, objects, 'test', id, Txn.MDB_NODUPDATA)
        Txn.commit(txn)
      end)
      stat.update = time_and_repeat(100000,function(id)
        local txn = Env.txn_begin(env, nil, 0)
        Txn.put(txn, objects, 'test', id, Txn.MDB_NODUPDATA)
        Txn.commit(txn)
      end)
      stat.read = time_and_repeat(100000,function(id)
        local txn = Env.txn_begin(env, nil, 0)
        Txn.put(txn, objects, 'test', id)
        Txn.commit(txn)
      end)
      stat.read_only = time_and_repeat(100000,function(id)
        local txn = Env.txn_begin(env, nil, Txn.MDB_RDONLY)
        Txn.put(txn, objects, 'test', id)
        Txn.commit(txn)
      end)
      stat.delete = time_and_repeat(100000,function(id)
        local txn = Env.txn_begin(env, nil, 0)
        Txn.del(txn, objects, 'test', id)
        Txn.commit(txn)
      end)

      local txn = Env.txn_begin(env, nil, 0)
      stat.insert_batch = time_and_repeat(100000,function(id)
        Txn.put(txn, objects, 'test', id, Txn.MDB_NODUPDATA)
      end)
      Txn.commit(txn)
      local txn = Env.txn_begin(env, nil, 0)
      stat.update_batch = time_and_repeat(100000,function(id)
        Txn.put(txn, objects, 'test', id, Txn.MDB_NODUPDATA)
      end)
      Txn.commit(txn)
      local txn = Env.txn_begin(env, nil, 0)
      stat.read_batch = time_and_repeat(100000,function(id)
        Txn.get(txn, objects, 'test', id)
      end)
      Txn.commit(txn)
      local txn = Env.txn_begin(env, nil, Txn.MDB_RDONLY)
      stat.read_only_batch = time_and_repeat(100000,function(id)
        Txn.get(txn, objects, 'test', id)
      end)
      Txn.commit(txn)
      local txn = Env.txn_begin(env, nil, 0)
      stat.delete_batch = time_and_repeat(100000,function(id)
        Txn.del(txn, objects, 'test', id)
      end)
      Txn.commit(txn)

      

      Env.close(env)
      assert(fs.unlink('./test-db'))
    end
    p(stats)
    
  end))
end)