-- Bluenet 2.0 routed
-- Copyright 2018 Shawn Anastasio
-- Licensed under the terms of the GNU GPL v3 license

-- Include protocol library
dofile("bluenet2/protocol.lua")

local WAN_MODEMS = {}
local LAN_MODEMS = {}
local VERBOSE = true

-- Include config file
if fs.exists("/routed.conf") then
	dofile("/routed.conf")
end

-- Routing Table:
-- Key: ID
-- Value : {lan_side (str)}
local routing_table = {}

function init()
	print("Bluenet " .. VERSION .. " routed initializing...")

	-- Open ports for listening on WAN and LAN modems
	for k, v in pairs(WAN_MODEMS) do
		peripheral.call(v, "open", WAN_CHANNEL)
	end

	for k, v in pairs(LAN_MODEMS) do
		peripheral.call(v, "open", LAN_CHANNEL)
	end
end

function log(msg)
	if VERBOSE then
		print(msg)
	end
end

-- Handle a modem event from a WAN modem
function handle_wan_msg(side, msg)
	-- Decode the message
	local packet = Packet.unserialize(msg)
	local type = packet:get_type()

	local ver = packet:get_ver()
	if ver ~= VERSION then
		log("Recieved packet from different proto version " .. VERSION .. ". Continuing...")
	end

	if type == PACKET_TYPE_ANNOUNCE then
		log("Error, recieved ANNOUNCE packet on WAN!")
	elseif type == PACKET_TYPE_DATA then
		-- Check if dst is on LAN
		local data = DataExtra.from_raw(packet:get_extra())
		local route = routing_table[data:get_dst()]
		if route ~= nil then
			-- Send packet
			peripheral.call(route[1], "transmit", LAN_CHANNEL, 0, msg)
			log("Forwarding packet from wan src " .. data:get_src() .. " to dst " .. data:get_dst())
		else
			log("Dropping packet for dst " .. data:get_dst() .. " not in routing table")
		end
	else
		log("Error, recieved packet with unknown type: " .. type)
	end
end

function handle_lan_msg(side, msg)
	-- Decode the message
	local packet = Packet.unserialize(msg)
	local type = packet:get_type()

	local ver = packet:get_ver()
	if ver ~= VERSION then
		log("Recieved packet from different proto version " .. VERSION .. ". Continuing...")
	end

	if type == PACKET_TYPE_ANNOUNCE then
		local announce = AnnounceExtra.from_raw(packet:get_extra())
		local anncmd = announce:get_cmd()
		if anncmd == ANNCMD_HOST_UP then
			-- Add this host to the routing table
			local src = announce:get_src()
			routing_table[src] = {side}
			log("Adding " .. src .. " to routing table")
			-- TODO: Add some authentication?
		elseif anncmd == ANNCMD_HOST_DOWN then
			-- Remove this host from the routing table
			local src = announce:get_src()
			routing_table[src] = nil
			log("Removing " .. src .. " from the routing table")
		else
			log("Recieved packet with unknown ANNCMD: " .. anncmd)
		end
	elseif type == PACKET_TYPE_DATA then
		local data = DataExtra.from_raw(packet:get_extra())
		-- Check if packet dst is on LAN
		local dst = data:get_dst()
		local route = routing_table[dst]
		if route == nil then
			-- Destination is not on LAN, broadcast it to all WAN modems
			log("Forwarding LAN packet from " .. data:get_src() .. " to WAN")
			for _, side in pairs(WAN_MODEMS) do
				peripheral.call(side, "transmit", WAN_CHANNEL, 0, msg)
			end
		else
			-- Destination is on lan, send it directly
			log("Packet from " .. data:get_src() .. " is to a dst on LAN")
			peripheral.call(route[1], "transmit", LAN_CHANNEL, 0, msg)
		end
	else
		log("Error, recieved packet with unknown type: " .. type)
	end
end

function wan_loop()
	while true do
		local _, side, s_channel, _, msg, _ = os.pullEvent("modem_message")
		-- Handle message if it's on the WAN channel and it was from a WAN modem
		if s_channel == WAN_CHANNEL then
			local res = table_contains(WAN_MODEMS, side)
			if res ~= nil then
				-- Packet is on the LAN channel and came from a LAN modem, handle it
				handle_wan_msg(side, msg)
			end
		end
	end
end

function lan_loop()
	while true do
		local _, side, s_channel, _, msg, _ = os.pullEvent("modem_message")
		-- Handle message if it's on the LAN channel and it was from a LAN modem
		if s_channel == LAN_CHANNEL then
			local res = table_contains(LAN_MODEMS, side)
			if res ~= nil then
				-- Packet is on the LAN channel, handle it
				handle_lan_msg(side, msg)
			end
		end
	end
end

init()
parallel.waitForAll(wan_loop, lan_loop)