# bluenet2
`bluenet2` is an API-compatible replacement for ComputerCraft's `rednet` with support for more complex network topologies.

## Usage Overview

### Client Setup
As stated above, bluenet2 is mostly compatible with the existing Rednet API. This means that converting an existing rednet program to use bluenet2 is very easy. Simply include the `bluenet.lua` file using `os.loadAPI()` at the top of your project, and replace any references to `rednet` with `bluenet`. The program will still function as intended provided you have a properly set up the network. When creating a new program, one can follow the existing rednet documentation, replacing any `rednet` references with `bluenet`.

### Router Setup
The router computer should be configured with 2 or more modems. One modem functions as a WAN device, and the remaining ones function as LAN devices. This allows you to emulate a traditional wireless router setup; one wired LAN device, and one wireless LAN device. `routed.lua` should be made to start on launch, and the configuration file (`routed.conf`) should be set as follows:

- `WAN_DEVICES` is a Lua table of the devices to use as WAN devices
- `LAN_DEVICES` is a Lua table of the devices to use as LAN devices
- `VERBOSE` can be set to true to enable verbose output on the router display

After creating the configuration files and setting the options to suit your needs, run `routed.lua` or restart the computer. The computer will now monitor for incoming packets and route them as described below

## Architecture and Inner Workings

### LAN Routing
This is accomplished using a simple routing table. When a packet is recieved on a router's LAN device, the router compares the destination of that packet with the routing table. If the destination is in the routing table, it simply forwards that packet to the destination computer back through the LAN device. However, if the destination is not in the local routing table, it multicasts the packet on the WAN device. All other routers on the WAN recieve the packet on their respective WAN devices. 

### WAN Routing
When a packet is recieved on a router's WAN device, the router compares the destination of that packet with the local routing table, again. If the destination is in the local routing table, it forwards the packet to the destination computer through the LAN device. However, if the destination is not in the local routing table, the router simply discards the packet. 

### Routing Table
The router maintains a routing table based on client announcements. The clients announce themselves whenever `bluenet.open()` is called. The client remains in the routing table until it instructs the router to remove it from the table. This occurs in `bluenet.close()`.