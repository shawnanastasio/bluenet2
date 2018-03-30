-- Bluenet protocol constants and helper functions
-- This file is not to be run manually
-- Copyright 2018 Shawn Anastasio
-- Licensed under the terms of the GNU GPL v3 license

-- Channel for all LAN data traffic
LAN_CHANNEL = 100

-- Channel for all WAN announcement traffic
WAN_CHANNEL = 101

-- Packet types
PACKET_TYPE_ANNOUNCE = 1
PACKET_TYPE_DATA = 2

-- Version number
VERSION = 2.0

-- Announce commands
ANNCMD_HOST_UP = 1
ANNCMD_HOST_DOWN = 2

-- The protocol defines a top level data packet with the following structure
-- {protover, type, extra}
-- protover : A number representing the protocol version of the sender
-- type : A number representing the type of datapacket, see PACKET_TYPE_*
-- extra : An extra table whose contents are type-specific

-- Extra data structures per-type
-- ANNOUNCE:
-- {src, anncmd}
-- src : The ID of the packet's sender
-- anncmd : Announce command, see ANNCMD_*

-- DATA:
-- {src, dst, data}
-- src : The ID of the packet's sender
-- dst : The ID of the packet's intended recipient
-- data : A string of the packet data

-- Implementation

-- Packet is a class that provides methods for creating, serializing, deserializing,
-- and inspecting packets.
Packet = {}
Packet.__index = Packet

setmetatable(Packet, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

function Packet.new(protover, type, extra)
    local self = setmetatable({}, Packet)
    self[1] = protover
    self[2] = type
	self[3] = extra
	return self
end

function Packet.from_raw(raw)
	setmetatable(raw, Packet)
	return raw
end

-- Return protocol version of this packet's sender
function Packet:get_ver()
	return self[1]
end

-- Return type of this packet
function Packet:get_type()
	return self[2]
end

-- Return raw extra data table for this packet
function Packet:get_extra()
	return self[3]
end

function Packet:serialize()
	return textutils.serialize(self)
end

function Packet.unserialize(msg)
	local self = textutils.unserialize(msg)
	setmetatable(self, Packet)
	return self
end

-- AnnounceExtra is a class that provides methods for creating/accessing
-- the `extra` table in a PACKET_TYPE_ANNOUNCE Packet.
AnnounceExtra = {}
AnnounceExtra.__index = AnnounceExtra

setmetatable(AnnounceExtra, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

function AnnounceExtra.new(src, anncmd)
	local self = setmetatable({}, AnnounceExtra)
	self[1] = src
	self[2] = anncmd
	return self
end

function AnnounceExtra.from_raw(raw)
	setmetatable(raw, AnnounceExtra)
	return raw
end

function AnnounceExtra:get_src()
	return self[1]
end

function AnnounceExtra:get_cmd()
	return self[2]
end

-- DataExtra
DataExtra = {}
DataExtra.__index = DataExtra

setmetatable(DataExtra, {
	__call = function(cls, ...)
		return cls.new(...)
	end,
})

function DataExtra.new(src, dst, data)
	local self = setmetatable({}, DataExtra)
	self[1] = src
	self[2] = dst
	self[3] = data
	return self
end

function DataExtra.from_raw(raw)
	setmetatable(raw, DataExtra)
	return raw
end

function DataExtra:get_src()
	return self[1]
end

function DataExtra:get_dst()
	return self[2]
end

function DataExtra:get_data()
	return self[3]
end

-- Helper functions

-- Checks if table contains element
-- Returns key if yes, nil if no
function table_contains(tbl, elem)
	for k, v in pairs(tbl) do
		if v == elem then
			return k
		end
	end
	return nil
end