# Connection and configuration
Consider Server A and Server B are connected with tofino switch at port 49 and 50
Server A IPv4 = 192.168.0.1, MAC: 00:00:00:00:00:01
Server B IPv4 = 192.168.0.2, MAC: 00:00:00:00:00:02

# Compilation
```
cmake $SDE/p4studio/ -DCMAKE_INSTALL_PREFIX=$SDE/install -DCMAKE_MODULE_PATH=$SDE/cmake -DP4_NAME=mac_router -DP4_PATH=<full path of mac_router.p4>
make
sudo make install
```

# Loading the code
Please run the following commands onwards in a 'screen' session. This terminal need to remain open throughout the duration of using Tofino switch. If a screen session is not used a disconnected SSH will stop the Tofino.

```
$SDE/run_switchd.sh -p mac_router
```

# Set Up the ports for 40 Gbps NIC
```
ucli
pm
port-add 49/- 40G NONE
an-set 49/- 2
port-enb 49/-
port-add 50/- 40G NONE
an-set 50/- 2
port-enb 50/-
# Wait for 10 second
show
exit
```

Check the "OPR" field from the output. It should show "UP" for both the ports if you are using Kernel network stack. Once dpdk driver is bound to the interfaces, the "OPR" field shows "UP" only after running the application. Please *DO NOT* proceed further until these are showing *"UP"*. Please not down the value in D_P field correspondig to each port and use that value while installing the rules, for e.g., for PORT 49 and 50 D_P is 28 and 44 respectively.

# Installing rules
### Start bf runtime
```
bfrt_python
```
From here onwards it is a python shell.
*NOTE:* Replace the IP, MAC and D_P according to your set up.

### ARP Rules
```
bfrt.mac_router.pipe.SwitchIngress.t_arp.add_with_a_arp("192.168.0.1", "00:00:00:00:00:01")
bfrt.mac_router.pipe.SwitchIngress.t_arp.add_with_a_arp("192.168.0.2", "00:00:00:00:00:02")
```

### MAC Rules
```
bfrt.mac_router.pipe.SwitchIngress.t_mac_forward.add_with_a_mac_forward("00:00:00:00:00:01", 28)
bfrt.mac_router.pipe.SwitchIngress.t_mac_forward.add_with_a_mac_forward("00:00:00:00:00:02", 44)
```

Server A and B should be able to ping each other at this point