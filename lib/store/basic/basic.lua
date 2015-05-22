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
local hrtime = require('uv').hrtime

local db = require('lmmdb')
local Env = db.Env
local config = require('config')

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
local element = ffi.metatype("point_t", {})

local Basic = Cauterize.Server:entend()

-- called when this process starts running. responsible for opening
-- the store and setting everything up
function Basic:_init()
	-- this should come from the config file
	local path = './database'
	local err
	self.env,err = Env.create
	if err then
		log.warning('unable to create store enviroment',err)
		self:exit()
	end

	-- set some defaults
	Env.set_maxdbs(self.env,4) -- we only need 4 dbs
	Env.set_mapsize(self.env,1024*1024*1024) -- should be -1Gb in size
	Env.reader_check(self.env) -- make sure that no stale readers exist

	-- open the enviroment
	repeat

		-- Env.MDB_NOSUBDIR means that one file is created, and no subdir
		-- is used to store the files created
		err = Env.open(env,path,Env.MDB_NOSUBDIR,tonumber('0644',8))

		-- work around for solaris. I don't know what this breaks
		if err == 'Device busy' then
			fs.unlinkSync(path .. '-lock')
		else
			log.error('unable to open store enviroment',err)
			self:exit()
		end
	until err ~= 'Device busy' -- should only loop once


	-- create the tables that we use
	local txn = Env.txn_begin(env,nil,0)
	
	-- objects stores the actual objects
	self.objects = DB.open(txn,"objects",DB.MDB_CREATE)

	-- replication stores remote node states, so that on disconnects
	-- replication can resume from where it left off
	self.replication = DB.open(txn,"replication",DB.MDB_CREATE)

	-- logs records write operations on this node until not needed
	-- MDB_INTEGERKEY because we use timestamps
	self.logs = DB.open(txn,"logs",DB.MDB_CREATE + DB.MDB_INTEGERKEY)

	-- buckets stores the keys that are in a bucket. this is used to
	-- enforce order and for listing a bucket
	-- MDB_DUPSORT because we store multiple values under one key
	self.buckets = DB.open(txn,"buckets",DB.MDB_DUPSORT + DB.MDB_CREATE)
	
	-- we need to fetch the last operation that was commited
	local cursor = Cursor.open(txn,self.logs)
	local key,_op = Cursor.get(cursor,nil,Cursor.MDB_LAST,"unsigned long*")
	if key then
		-- if we have something stored, then the store is not new
		log.info("last operation commited",key[0])
		self.version = key[0]
	else
		-- if we don't have anything, then its a new database
		log.info("new database was opened")
		self.version = hrtime() * 100000
	end

	-- we commit the transaction so that our tables are created
	Txn.commit(txn)
end

-- enter a new bucket,key and value into the database, returns an
-- error or the update time of the data
function Basic:enter(bucket,key,value,parent)
	if type(value) ~= "string" then
		log.warning('value must be a string',value)
		return 'value must be a string'
	end
	-- we have a combo key for storing the actual data
	local combo = bucket .. ':' .. key

	-- begin a transaction
	local txn,err = Env.txn_begin(self.env,parent,0)
	if err then
		log.warning('store unable to create a transaction',combo)
		return err
	end

	-- add the key to the bucket table.
	err = Txn.put(txn,buckets,bucket,key,Txn.MDB_NODUPDATA)
	if err then
		log.warning("unable to add id to 'buckets' DB",combo,err)
		Txn.abort(txn)
		return err
	end

	-- create an empty object. 16 for 2 longs, #value for the data, 1
	-- for the NULL terminator
	-- MDB_RESERVE returns a pointer to the memory reserved and stored
	-- for the key combo
	local data,err = Txn.put(txn,combo,16 + #value + 1,Txn.MDB_RESERVE)

	-- set the creation and update time to be now.
	local container = ffi.cast("element_t",data)
	container.creation = hrtime()
	container.updated = container.creation

	-- copy in the actual data we are storing, 16 should be the right
	-- offset
	ffi.copy(value,container + 16)

	-- commit the transaction
	err = Txn.commit(txn)
	if err then
		log.warning('unable to commit transaction',combo,err)
		return err
	end
	
	-- we return the time that it was updated. The caller already has
	-- the data that was sent
	return continer.updated
end

-- remove a bucket,key from the database
function Basic:remove(bucket,key,parent)
	-- we have a combo key for storing the actual data
	local combo = bucket .. ':' .. key

	-- begin a transaction
	local txn,err = Env.txn_begin(self.env,parent,0)
	if err then
		log.warning('store unable to create a transaction',combo,err)
		return err
	end

	-- delete the object value
	local err = Txn.del(txn,objects,combo)
	if err then
		log.warning("unable to delete object",combo,err)
		Txn.abort(txn)
		return nil,err
	end

	-- delete the object key
	local err = Txn.del(txn,buckets,bucket,key)
	if err then
		log.warning("unable to delete object key",combo,err)
		Txn.abort(txn)
		return nil,err
	end

	-- commit all changes
	err = Txn.commit(txn)
	
	if err then
		log.warning('unable to commit transaction',combo,err)
		return err
	end

	return true
end

function Store:fetch(b_id,id,cb)
	-- this should be a read only transaction
	local txn,err = Env.txn_begin(self.env,nil,Txn.MDB_RDONLY)
	if err then
		return nil,err
	end

	local objects,err = DB.open(txn,"objects",0)
	if err then
		logger:info("unable to open 'objects' DB",err)
		Txn.abort(txn)
		return nil,err
	end


	if id then
		local json,err = Txn.get(txn,objects, b_id .. ":" .. id)
		Txn.abort(txn)
		if err then
			return nil,err
		else
			json = JSON.parse(json)
			json.script = self.scripts[b_id .. ":" .. id]
			if json["$script"] and not json.script then
				json.script = self:compile(json,b_id,id)
				self.scripts[b_id .. ":" .. id] = json.script
			end
			return json
		end
	else
		local buckets,err = DB.open(txn,"buckets",DB.MDB_DUPSORT)
		if err then
			logger:info("unable to open 'buckets' DB",err)
			return nil,err
		end
		local cursor,err = Cursor.open(txn,buckets)
		if err then
			logger:info("unable to create cursor",err)
			return nil,err
		end

		local key,id = Cursor.get(cursor,b_id,Cursor.MDB_SET_KEY)
		local acc
		if cb then
			while key == b_id do
				json,err = Txn.get(txn,objects, b_id .. ":" .. id)
				json = JSON.parse(json)
				json.script = self.scripts[b_id .. ":" .. id]
				if json["$script"] and not json.script then
					json.script = self:compile(json,b_id,id)
					self.scripts[b_id .. ":" .. id] = json.script
				end
				cb(key,json)
				key,id,err = Cursor.get(cursor,key,Cursor.MDB_NEXT_DUP)
			end
		else
			acc = {}
			while key == b_id do
				local json,err = Txn.get(txn,objects, b_id .. ":" .. id)
				json = JSON.parse(json)
				json.script = self.scripts[b_id .. ":" .. id]
				if json["$script"] and not json.script then
					json.script = self:compile(json,b_id,id)
					self.scripts[b_id .. ":" .. id] = json.script
				end
				acc[#acc + 1] = json
				key,id,err = Cursor.get(cursor,key,Cursor.MDB_NEXT_DUP)
			end
		end

		Cursor.close(cursor)
		Txn.abort(txn)
		return acc
	end

end

-- fetch a value from the database
function Basic:fetch(bucket,key)
	-- fetching is a read only transaction
	local txn,err = Env.txn_begin(self.env,nil,Txn.MDB_RDONLY)
	if err then
		return nil,err
	end

	if key then
		local combo = bucket .. ":" .. key
		local container,err = Txn.get(txn, self.objects, combo, "element_t")
		Txn.abort(txn)
		-- is this still valid? I'm not sure
		return container
	else

		-- we are doing a list.
		local cursor,err = Cursor.open(txn,self.buckets)
		if err then
			log.warning("unable to create cursor for list",err)
			return nil,err
		end
		local b_id,id = Cursor.get(cursor,bucket,Cursor.MDB_SET_KEY)
		local acc
		while b_id == bucket do
			local json,err = Txn.get(txn,self.objects, bucket .. ":" .. id)
			json = JSON.parse(json)
			json.script = self.scripts[b_id .. ":" .. id]
			if json["$script"] and not json.script then
				json.script = self:compile(json,b_id,id)
				self.scripts[b_id .. ":" .. id] = json.script
			end
			cb(key,json)
			key,id,err = Cursor.get(cursor,key,Cursor.MDB_NEXT_DUP)
		end
		Cursor.close(cursor)
	end
	
	return value
end

return Basic