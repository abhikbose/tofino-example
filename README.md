This repository contains sample P4 codes and configurations for Intel Tofino switch.

# Folder Structure
Each example program is stored in a seprate folder as follows. For more information read the `README` files are provided in each folder.

### wire16 
This code connects a pair of Tofino ports and make them behave like they are point-to-point connected using a cable. It is written in P4_16. Hence the name wire16. It matches Ingress port of the incoming packet and connects to a specific Egress port based on the configuration. This program also comes with an example `C++` code for the controller API along with the `bf_rt` `Python` based rules for the control plane. This code doesn't handle ARP explicitely and it is assumed that the network stacks at the hosts will handle ARP.

### simple_router_l3
This code matches the destination IPv4 of an incoming packet and send it to igress port specified for that IP in the control plane configuration. This code handles ARP too at the Tofino switch and generates ARP response from the switch itself. This code comes with standard `Python` based control plane API rules.

### mac_router
This code performs MAC based routing similar to `simple_l3_router`, except it matches destination MAC of the incoming packet instead of destionation IPv4. This code also handles ARP at the Tofino switch and comes with `Python` based control plane rules.

### wire_recirculate
This code shows how to set a Tofino front panel port in loopback mode and achieve recirculation using that loopback port. This also has an example use of a `DirectCounter` extern.