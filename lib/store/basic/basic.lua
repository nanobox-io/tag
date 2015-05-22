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
local log = require('logger')
local Splode = require('splode')
local splode, xsplode = Splode.splode, Splode.xsplode
local hrtime = require('uv').hrtime

local db = require('lmmdb')
local Env = db.Env
local DB = db.DB
local Txn = db.Txn
local Cursor = db.Cursor

local ffi = require("ffi")

-- we need a data storage object so that we don't have to encode and
-- decode just to update timestamps
ffi.cdef[[
typedef struct {
	long update; // last update time
	long creation; // creation date
	char data[1]; // first char of the string data
} element_t;
]]
-- we really want to use set/get methods

local Basic = Cauterize.Server:extend()

-- called when this process starts running. responsible for opening
-- the store and setting everything up
function Basic:_init()
	-- this should come from the config file
	local path = './database'
	local err
	self.env = splode(Env.create, 'unable to create store enviroment')

	-- set some defaults
	Env.set_maxdbs(self.env, 4) -- we only need 4 dbs
	Env.set_mapsize(self.env, 1024*1024*1024) -- should be ~1Gb in size
	Env.reader_check(self.env) -- make sure that no stale readers exist

	-- open the enviroment
	repeat

		-- Env.MDB_NOSUBDIR means that one file is created, and no subdir
		-- is used to store the files created
		err = Env.open(self.env, path, Env.MDB_NOSUBDIR, tonumber('0644', 8))

		-- work around for solaris. I don't know what this breaks
		if err == 'Device busy' then
			fs.unlinkSync(path .. '-lock')
		elseif err then
			log.error('unable to open store enviroment', err)
			self:exit()
		end
	until err ~= 'Device busy' -- should only loop once


	-- create the tables that we use
	local txn = splode(Env.txn_begin,
		'unable to begin create transaction', self.env, nil, 0)
	
	-- objects stores the actual objects
	self.objects = splode(DB.open, 'unable to create objects', 
		txn, "objects", DB.MDB_CREATE)

	-- replication stores remote node states, so that on disconnects
	-- replication can resume from where it left off
	self.replication = splode(DB.open, 'unable to create replication', 
		txn, "replication", DB.MDB_CREATE)

	-- logs records write operations on this node until not needed
	-- MDB_INTEGERKEY because we use timestamps
	self.logs = splode(DB.open, 'unable to create logs', 
		txn, "logs", DB.MDB_CREATE + DB.MDB_INTEGERKEY)

	-- buckets stores the keys that are in a bucket. this is used to
	-- enforce order and for listing a bucket
	-- MDB_DUPSORT because we store multiple values under one key
	self.buckets = splode(DB.open, 'unable to create buckets', 
		txn, "buckets", DB.MDB_DUPSORT + DB.MDB_CREATE)
	
	-- we need to fetch the last operation that was commited
	local cursor = Cursor.open(txn, self.logs)
	local key, _op = Cursor.get(cursor, nil, Cursor.MDB_LAST,
		"unsigned long*")

	if key then
		-- if we have something stored, then the store is not new
		log.info("last operation commited", key[0])
		self.version = key[0]
	else
		-- if we don't have anything, then its a new database
		log.info("new database was opened")
		self.version = hrtime() * 100000
	end

	-- we commit the transaction so that our tables are created
	xsplode(0,Txn.commit, 'unable to commit database creation', txn)
end

-- enter a new bucket, key and value into the database, returns an
-- error or the update time of the data
function Basic:enter(bucket, key, value, parent)

	-- we don't assume any encoding at all on the value, so it must be
	-- a string by the time this function gets called
	if type(value) ~= "string" then
		log.warning('value must be a string', value)
		return {false, 'value must be a string'}
	end

	local txn = nil
	
	-- captures results into either {true, results} or {false, error}
	local ret = {pcall(function()
		-- we have a combo key for storing the actual data
		local combo = bucket .. ':' .. key

		-- begin a transaction
		txn = splode(Env.txn_begin, 
			'store unable to create a transaction', self.env, parent, 0)

		-- add the key to the bucket table.
		xsplode(0, Txn.put,
			'unable to add '.. combo ..' to \'buckets\' DB', txn, self.buckets,
			bucket, key, Txn.MDB_NODUPDATA)

		-- create an empty object. 16 for 2 longs, #value for the data, 1
		-- for the NULL terminator
		-- MDB_RESERVE returns a pointer to the memory reserved and stored
		-- for the key combo
		local data = splode(Txn.put, 
			'unable to store value for ' .. combo, txn ,self.objects ,combo,
			16 + #value + 1, Txn.MDB_RESERVE)

		p('casting',data)
		-- set the creation and update time to be now.
		local container = ffi.new("element_t*", data)
		local creation = hrtime()
		container.creation = creation
		container.update = creation

		-- copy in the actual data we are storing, 16 should be the right
		-- offset
		local pos = ffi.cast('intptr_t',data) + 16
		ffi.copy(ffi.cast('void *', pos), value, #value)

		-- commit the transaction
		err = xsplode(0, Txn.commit, 
			'unable to commit transaction for' .. combo, txn)

		-- clear out becuase it is invalid
		txn = nil
		
		-- we return the time that it was updated. The caller already has
		-- the data that was sent
		return creation
	end)}

	-- perform some cleanup
	if txn then
		Txn.abort(txn)
	end

	return ret
end

-- remove a bucket, key from the database
function Basic:remove(bucket, key, parent)
	-- we may need to clear this out in case of error, which is why it
	-- is defined here

	local txn = nil
	-- should either be {true} or {false, error}
	local ret = {pcall(function()
		-- we have a combo key for storing the actual data
		local combo = bucket .. ':' .. key

		-- begin a transaction, store it in txn so it can be aborted later
		txn = splode(Env.txn_begin, 
			'store unable to create a transaction ' .. combo, self.env, 
			parent, 0)

		-- delete the object value
		xsplode(0, Txn.del, 'unable to delete object', txn, objects,
			combo)

		-- delete the object key
		xsplode(0, Txn.del, 'unable to delete object key ' .. combo, txn, 
			buckets, bucket, key)

		-- commit all changes
		xsplode(0, Txn.commit, 'unable to commit transaction ' .. combo,
			txn)

		-- clear out because it is invalid
		txn = nil
	end)}
	if txn then
		Txn.abort(txn)
	end
	return ret
end

-- fetch a value from the database
function Basic:fetch(bucket, key)
	
	local cursor, txn = nil, nil
	-- should either be {true, container}, {true, {container}} or 
	-- {false, error}
	local ret = {pcall(function()
		-- fetching is a read only transaction, hence MDB_RDONLY
		txn = splode(Env.txn_begin, 'unable to create txn ' .. bucket, 
			self.env, nil, Txn.MDB_RDONLY)

		if key then
			-- we are looking up a single value
			local combo = bucket .. ":" .. key
			return splode(Txn.get, 
				'does not exist ' .. combo, txn, self.objects, combo, 
				"element_t*")

		else
			-- we are doing a list.
			cursor = splode(Cursor.open, 
				'unable to create cursor for list' .. bucket, txn, 
				self.buckets)

			local b_id, id = xsplode(2, Cursor.get, 
				'unable to set the initial cursor ' .. bucket, cursor, bucket, 
				Cursor.MDB_SET_KEY)

			local acc = {}
			repeat
				local combo = bucket .. ":" .. id
				
				-- get the value for the current key
				local container = splode(Txn.get, 
					'unable to get value for key ' .. combo, txn, self.objects, 
					combo, "element_t*")
				acc[#acc + 1] = container

				-- advance cursor to next key, don't use 'splode because it
				-- errors when out of data points
				b_id, id = Cursor.get(cursor, key, Cursor.MDB_NEXT_DUP)
			until b_id ~= bucket
			
			return acc
		end
	end)}

	-- do some clean up if needed
	if cursor then
		Cursor.close(cursor)
	end
	if txn then
		Txn.abort(txn)
	end
	return ret
end

function Basic:_destroy()
	xsplode(0, Env.close, 'unable to close env', self.env)
end

return Basic