/* Copyright 2013-present Barefoot Networks, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


header_type ethernet_t {
    fields {
        dstAddr : 48;
        srcAddr : 48;
        etherType : 16;
    }
}

header_type ipv4_t {
    fields {
        version : 4;
        ihl : 4;
        diffserv : 8;
        totalLen : 16;
        identification : 16;
        flags : 3;
        fragOffset : 13;
        ttl : 8;
        protocol : 8;
        hdrChecksum : 16;
        srcAddr : 32;
        dstAddr: 32;
        padding: 32;
    }
}

header_type tcp_t {
    fields {
        srcPort: 8;
        dstPort: 8;
    }
}

header_type routing_metadata_t {
    fields {
        nhop_ipv4 : 32;
        hashVal: 8;
    }
}

header ethernet_t ethernet;
header ipv4_t ipv4;
header tcp_t tcp;
metadata routing_metadata_t routing_metadata;

field_list ipv4_checksum_list {
        ipv4.version;
        ipv4.ihl;
        ipv4.diffserv;
        ipv4.totalLen;
        ipv4.identification;
        ipv4.flags;
        ipv4.fragOffset;
        ipv4.ttl;
        ipv4.protocol;
        ipv4.srcAddr;
        ipv4.dstAddr;
}


field_list_calculation ipv4_checksum {
    input {
        ipv4_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    update ipv4_checksum;
}

field_list flow_id {
    ipv4.srcAddr;
    tcp.srcPort;
    ipv4.dstAddr;
    tcp.dstPort;
    ipv4.protocol;
}

field_list_calculation flow_hash {
    input {
        flow_id;
    }
    algorithm: crc16;
    output_width: 8;
}

calculated_field routing_metadata.hashVal {
    update flow_hash;
}

parser start {
    extract(ethernet);
    extract(ipv4);
    extract(tcp);
    return ingress;
}

action _drop() {
    drop();
}

action set_nhop(nhop_ipv4, port) {
    modify_field(routing_metadata.nhop_ipv4, nhop_ipv4);
    modify_field(standard_metadata.egress_spec, port);
    modify_field(ipv4.ttl, ipv4.ttl - 1);
}

table ipv4_exact {
    reads {
        ipv4.dstAddr : exact;
    }
    actions {
        set_nhop;
        _drop;
    }
    size: 1024;
}

control ingress {
    if(valid(ipv4) and ipv4.ttl>0) {
        apply(ipv4_exact);
    }
}

control egress {
}


