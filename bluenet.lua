-- Bluenet 2.0 client API
-- This file is not to be run manually
-- Copyright 2018 Shawn Anastasio
-- Licensed under terms of the GNU GPL v3 license

-- Include protocol library
dofile("bluenet2/protocol.lua")

-- Table of strings of open modem sides
local modems = {}
local local_id = os.getComputerID()

-- Internal functions
local function announce_host_up(side)
	local packet = Packet(VERSION, PACKET_TYPE_ANNOUNCE, AnnounceExtra(local_id, ANNCMD_HOST_UP))
	peripheral.call(side, "transmit", LAN_CHANNEL, 0, packet:serialize())
end

local function announce_host_down(side)
	local packet = Packet(VERSION, PACKET_TYPE_ANNOUNCE, AnnounceExtra(local_id, ANNCMD_HOST_UP))
	peripheral.call(side, "transmit", LAN_CHANNEL, 0, packet:serialize())
end

-- Rednet-compatible API
-- TODO: Protocols (CC 1.6+), broadcast, host/unhost/lookup (CC 1.6+)?
function open(side)
	if table_contains(modems, side) ~= nil then
		-- Already open, silently ignore
		return
	end

	peripheral.call(side, "open", LAN_CHANNEL)
	modems[#modems+1] = side
	announce_host_up(side)
end

function close(side)
	local key = table_contains(modems, side)
	if key == nil then
		-- Connection not open, ignore
		return
	end

	announce_host_down(side)
	modems[key] = nil
end

function isOpen(side)
	if table_contains(modem, side) == nil then
		return false
	else
		return true
	end
end

function send(dst, data)
	-- Construct a packet
	local packet = Packet(VERSION, PACKET_TYPE_DATA, DataExtra(local_id, dst, data))

	-- Serialize the packet and send to the router over WAN_CHANNEL on all enabled modems
	local packet_ser = packet:serialize()
	for _, v in pairs(modems) do
		peripheral.call(v, "transmit", LAN_CHANNEL, 0, packet_ser)
	end
end

function receive(timeout)
	if timeout ~= nil then
		os.startTimer(timeout)
	end

	while true do
		local event, side, s_channel, _, msg, _ = os.pullEvent()
		if event == "timer" and timeout ~= nil then
			-- Operation timed out, abort
			return nil
		elseif event == "modem_message" and s_channel == LAN_CHANNEL then
			-- Received a message on the LAN_CHANNEL, return it if the dst is us
			local packet = Packet.unserialize(msg)
			if packet:get_type() == PACKET_TYPE_DATA then
				local extra = DataExtra.from_raw(packet:get_extra())
				if extra:get_dst() == local_id then
					-- Packet is for us, return
					return extra:get_src(), extra:get_data()
				end
			end
		end
	end
end
