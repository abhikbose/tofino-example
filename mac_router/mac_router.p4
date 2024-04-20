// typedef bit<9> PortId_t defined by default

#include <core.p4>
#include <tna.p4>

// Constant definations
#define TYPE_ARP 0x0806

// typedefs
typedef bit<48> mac_addr_t;

//######## Header definations #############
header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

header arp_t {
    bit<16> htype;
    bit<16> ptype;
    bit<8> hp_addr_len;
    bit<8> protocol_len;
    bit<16> op_code;
    bit<48> senderMac;
    bit<32> senderIPv4;
    bit<48> targetMac;
    bit<32> targetIPv4;
}

struct header_t {
    ethernet_h ethernet;
    arp_t arp;
}

struct metadata_t {
    bit<32> arpTargetIPv4_temp;
}
struct empty_header_t {}
struct empty_metadata_t {}

// Ingress Parser
parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

	// TNA specific code
	state start {
		pkt.extract(ig_intr_md);
		pkt.advance(PORT_METADATA_SIZE);
		transition parse_ethernet;
	}

    // Parse ethernet
	state parse_ethernet {
		pkt.extract(hdr.ethernet);
		transition select(hdr.ethernet.ether_type){
            TYPE_ARP: parse_arp;
            default: accept;
        }
	}

    // Parse arp if it is an arp packet
    state parse_arp {
        pkt.extract(hdr.arp);
        ig_md.arpTargetIPv4_temp = hdr.arp.targetIPv4;
        transition accept;
    }
}

// Ingress Deparser
control SwitchIngressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

	apply {
		pkt.emit(hdr);
	}
}

control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    action nop() {}

    // Code for arp handling
    action a_arp(bit<48> ifaceMac){
        // Sending packet back to incoming port
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;

        // Changing Ethernet headers
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = ifaceMac;

        // Changing ARP headers
        hdr.arp.op_code = 2; // Arp req = 1, ARP reply = 2
        hdr.arp.targetMac = hdr.arp.senderMac;
        hdr.arp.senderMac = ifaceMac;

        // Swaping sender and target IPv4
        // ip4_addr_t targetIPv4_temp = hdr.arp.targetIPv4;
        // arpTargetIPv4_temp set in parser = hdr.arp.targetIPv4 to avoid warning
        hdr.arp.targetIPv4 = hdr.arp.senderIPv4;
        hdr.arp.senderIPv4 = ig_md.arpTargetIPv4_temp;
    
        // Disabling l3 table. This need not to be done bcz arp packets doesn't have ipv4
        // l3_disabled = true;
    }


    table t_arp {
        key = {
            hdr.arp.targetIPv4 : exact;
        }

        actions = {
            a_arp;
            nop;
        }

        const default_action = nop();
        size = 32;
    }

    // Code for mac forwarding
    action a_mac_forward (PortId_t dport){
        ig_tm_md.ucast_egress_port = dport;
    }

    table t_mac_forward {
        key = {
            hdr.ethernet.dst_addr : exact;
        }

        actions = {
            a_mac_forward;
            nop;
        }

        const default_action = nop();
        size = 16;
    }

	apply {
		if (hdr.arp.isValid()){
            // If arp request, generate an arp response
            t_arp.apply();
        }
        else {
            // Simple mac forwarding
            t_mac_forward.apply();
        }

		// Skip egress processing
		ig_tm_md.bypass_egress = 1w1;
	}
}


// Empty egress parser/control blocks
parser EmptyEgressParser(
        packet_in pkt,
        out empty_header_t hdr,
        out empty_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        transition accept;
    }
}

control EmptyEgressDeparser(
        packet_out pkt,
        inout empty_header_t hdr,
        in empty_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {}
}

control EmptyEgress(
        inout empty_header_t hdr,
        inout empty_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {
    apply {}
}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         EmptyEgressParser(),
         EmptyEgress(),
         EmptyEgressDeparser()) pipe;

Switch(pipe) main;
