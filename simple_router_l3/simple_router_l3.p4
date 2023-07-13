#include <core.p4>
#include <tna.p4>

#define TYPE_IPV4 0x0800
#define TYPE_ARP 0x0806

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> ethType;
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
header ipv4_t {
    bit<4> version;
    bit<4> headerLen;
    bit<8> diffServ;
    bit<16> totalLen;
    bit<16> identification;
    bit<3> flags;
    bit<13> fragOffset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct ingress_header_t {
    ethernet_t       ethernet;
    arp_t            arp;
    ipv4_t           ipv4;
}

struct egress_header_t {
    // Emptry
}

struct ingress_metadata_t {
    bit<32> arpTargetIPv4_temp;
}

struct egress_metadata_t {
    // Empty
}

parser IngressParser(
        packet_in pkt,
        out ingress_header_t hdr,
        out ingress_metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    // TNA specific code
    state start {
        transition parse_tofino;
    }

    state parse_tofino {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ethType){
            TYPE_IPV4 : parse_ipv4;
            TYPE_ARP : parse_arp;
            default : accept; 
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        ig_md.arpTargetIPv4_temp = hdr.arp.targetIPv4;
        transition accept;
    }

    // Parse OUTER IPV4. Accept here if pkt coming from DNN
    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition accept;
    }
}

control IngressDeparser(
        packet_out pkt,
        inout ingress_header_t hdr,
        in ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    apply {
        pkt.emit(hdr);
    }
}

parser EgressParser(
        packet_in pkt,
        out egress_header_t hdr,
        out egress_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        transition accept;
    }
}

control EgressDeparser(
        packet_out pkt,
        inout egress_header_t hdr,
        in egress_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {}
}

control RouterEgress(
        inout egress_header_t hdr,
        inout egress_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {
    apply {}
}

control RouterIngress(
        inout ingress_header_t hdr,
        inout ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    action nop() {}


    /*------------------------- ARP Handling ----------------------------*/
    action arp_act(bit<48> ifaceMac){
        // Sending packet back to incoming port
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;

        // Changing Ethernet headers
        hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = ifaceMac;

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


    table arp_tbl {
        key = {
            hdr.arp.targetIPv4 : exact;
        }

        actions = {
            arp_act;
            nop;
        }

        const default_action = nop();
        size = 32;
    }


    /*-------------------------------L3 routing for all packets-----------------------------------*/
    action l3_routes_act(PortId_t egressPort) {
        ig_tm_md.ucast_egress_port = egressPort;
    }

    // This is currently dealing both L3 and L2
    table tbl_l3_routes {
        key = {
            hdr.ipv4.dstAddr : exact;
        }

        actions = {
            l3_routes_act;
            nop;
        }
        
        const default_action = nop();
        size = 32;
    }

    apply {
        // handle ARP
        if (hdr.ethernet.isValid() && hdr.arp.isValid()){
            arp_tbl.apply();
        }
        // Handle remaining packets (mostly CP) via L3 routes
        else if (hdr.ipv4.isValid()){
            tbl_l3_routes.apply();
        }
        // Drop any remaining garbage packets
        else{
            ig_dprsr_md.drop_ctl = 1;
        }
        // Skip egress processing
        ig_tm_md.bypass_egress = 1w1;
    }
}

Pipeline(IngressParser(),
         RouterIngress(),
         IngressDeparser(),
         EgressParser(),
         RouterEgress(),
         EgressDeparser()) pipe;

Switch(pipe) main;