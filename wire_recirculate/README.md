port-add 51/- 100G NONE
port-loopback 51/- mac-near or serdes-near
port-enb 51/-

bfrt.wire_recirculate.pipe.SwitchIngress.tbl_rclt_forward.add_with_act_set_rclt(64, 0xFF, 0, 0xFF, 1, 65, 66)
bfrt.wire_recirculate.pipe.SwitchIngress.tbl_rclt_forward.add_with_act_set_rclt(65, 0xFF, 0, 0xFF, 1, 64, 66)
bfrt.wire_recirculate.pipe.SwitchIngress.tbl_rclt_forward.add_with_act_continue_rclt(0, 0, 0, 0, 2, 66)
bfrt.wire_recirculate.pipe.SwitchIngress.tbl_rclt_forward.add_with_act_clear_rclt(0, 0, 1, 0xFF, 1)


<!-- If the above last rule has 4 then the following 2nd rule shall return 4 times of the following first rule if the loopback recirculation port is working correctly -->
bfrt.wire_recirculate.pipe.SwitchIngress.c_rclt.get(0, from_hw=1)
bfrt.wire_recirculate.pipe.SwitchIngress.c_rclt.get(1, from_hw=1)

bfrt.wire_recirculate.pipe.SwitchIngress.tbl_rclt_forward.dump(from_hw=1)