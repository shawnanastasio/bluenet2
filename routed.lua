-- Bluenet 2.0 routed
-- Copyright 2018 Shawn Anastasio
-- Licensed under the terms of the GNU GPL v3 license

-- Include protocol library
dofile("bluenet2/protocol.lua")

-- Include config file
if fs.exists("/routed.conf") then
	dofile("/routed.conf")
else
	-- Default config
	WAN_MODEMS = {}
	LAN_MODEMS = {}
	VERBOSE = true
end

-- Routing Table:
-- Key: ID
-- Value : {lan_side (str)}
local routing_table = {}

function init()
	print("Bluenet " .. VERSION .. " routed initializing...")

	-- Open ports for listening on WAN and LAN modems
	for k, v in pairs(WAN_MODEMS) do
		open_modem(v, WAN_CHANNEL)
	end

	for k, v in pairs(LAN_MODEMS) do
		open_modem(v, LAN_CHANNEL)
	end
end

function log(msg)
	if VERBOSE then
		print(msg)
	end
end

-- Wrapper function to open a modem for listening on a given channel
-- works on ComputerCraft modems as well as Immibis LAN modems
function open_modem(side, channel)
	local modem = peripheral.wrap(side)
	if modem.open ~= nil then
		-- ComputerCraft modem
		peripheral.call(side, "open", channel)
	elseif modem.setListening ~= nil then
		-- Immibis LAN modem
		peripheral.call(side, "setListening", channel, true)
	end
end

-- Wrapper function to send a message on a given modem
-- works on ComputerCraft and Immibis
function send_message(side, channel, msg)
	local modem = peripheral.wrap(side)
	if modem.transmit ~= nil then
		-- ComputerCraft modem
		peripheral.call(side, "transmit", channel, 0, msg)
	elseif modem.sendChannel ~= nil then
		-- Immibis LAN modem
		peripheral.call(side, "sendChannel", channel, msg)
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
			send_message(route[1], LAN_CHANNEL, msg)
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
				send_message(side, WAN_CHANNEL, msg)
			end
		else
			-- Destination is on lan, send it directly
			log("Packet from " .. data:get_src() .. " is to a dst on LAN")
			send_message(route[1], LAN_CHANNEL, msg)
		end
	else
		log("Error, recieved packet with unknown type: " .. type)
	end
end

function wan_loop()
	while true do
		--local _, side, s_channel, _, msg, _ = os.pullEvent("modem_message")
		local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()

		local s_channel = nil
		local side = nil
		local msg = nil
		if event == "modem_message" then
			-- Handle "modem_message" event from vanilla modems
			s_channel = arg2
			side = arg1
			msg = arg4
		elseif event == "lan_message" then
			s_channel = arg3
			side = arg1
			msg = arg4
		end

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