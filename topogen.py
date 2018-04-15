#!/usr/bin/env python

############################################################################################
#   topogen.py
#       Generates a scalable fat-tree topology.
#       Follows this syntax:
#           ./topogen.py
#               [--test path_to_test {none}]
#               [--pcap]
#               [--K K {4}]
# 				[--exec_path exec_path {../behavioral-model/targets/simple_router/simple_router}]
# 				[--json_path json_path {./router/simple_router.json}]
# 				[--cli_path cli_path {../behavioral-model/tools/runtime_CLI.py}]
# 				[--tablegen_path tablegen_path {./router/tablegen_simple.py}]
#       Make sure to set env.sh first before proceeding.
############################################################################################

from mininet.net import Mininet
from mininet.cli import CLI
from mininet.link import Link, TCLink, Intf
from subprocess import Popen, PIPE
from mininet.log import setLogLevel
import os
import argparse
import sys
import subprocess
from random import randint
import imp

from router.p4_mininet import P4Switch, P4Host

# Handle arguments in a more elegant manner using argparse.

parser = argparse.ArgumentParser(description='Generates a scalable Fat-tree topology.')
parser.add_argument('--test', default=None, type=str, metavar='path_to_test', help='specify a test to run. defaults to None.')
parser.add_argument('--K', default='4', type=int, metavar='num_ports', help='number of ports per switch. defaults to 4.')
parser.add_argument('--exec_path', default='../behavioral-model/targets/simple_router/simple_router', type=str, help='provide the path to the simple_router executable')
parser.add_argument('--json_path', default='./router/simple_router.json', type=str, help='provide the path to the behavioral json')
parser.add_argument('--cli_path', default='../behavioral-model/tools/runtime_CLI.py', type=str, help='provide the path to the runtime CLI')
parser.add_argument('--tablegen_path', default='./router/tablegen_simple.py', type=str, help='provide the path to the table generator script')

args = parser.parse_args()

exec_path = args.exec_path
json_path = args.json_path
cli_path = args.cli_path
tablegen_path = args.tablegen_path

# Code proper.

if '__main__' == __name__:
    setLogLevel('info')
    net = Mininet(controller=None)
    #key = "net.mptcp.mptcp_enabled"
    #value = 1
    #p = Popen("sysctl -w %s=%s" % (key, value),
    #        shell=True, stdout=PIPE, stderr=PIPE)
    #stdout, stderr = p.communicate()
    #print "stdout=", stdout, "stderr=", stderr

    K = args.K 									# Moved from argv[1] to args.K
    print "Generating topology for K =", K

    print "Naming convention"
    print "Host:               h<pod><i><j>"
    print "Edge switch:        se<pod><i>"
    print "Aggregate switch:   sa<pod><i>"
    print "Core switch:        sc<i><j>"

    host_ip = [[[
        '10.%d.%d.%d'%(pod,i,j+2)
        for j in range(K/2)]
        for i in range(K/2)]
        for pod in range(K)]

    host = [[[
    net.addHost('h%d%d%d'%(pod,i,j),
        cls=P4Host,
        ip=host_ip[pod][i][j])
    for j in range(K/2)]
    for i in range(K/2)]
    for pod in range(K)]



    port_offset = 10000

    edge_port = [[
    pod*K/2+i + port_offset
    for i in range(K/2)]
    for pod in range(K)]

    agg_port = [[
    pod*K/2+i + K*K/2 + port_offset
    for i in range(K/2)]
    for pod in range(K)]

    core_port = [[
    i*K/2+j + K*K + port_offset
    for j in range(K/2)]
    for i in range(K/2)]

    edge = [[
    net.addSwitch('se%d%d'%(pod,i),
        cls = P4Switch,
         sw_path = exec_path,
        json_path = json_path,
        thrift_port = edge_port[pod][i],
        pcap_dump = True)
    for i in range(K/2)]
    for pod in range(K)]

    agg = [[
    net.addSwitch('sa%d%d'%(pod,i),
        cls = P4Switch,
        sw_path = exec_path,
        json_path = json_path,
        thrift_port = agg_port[pod][i],
        pcap_dump = True)
    for i in range(K/2)]
    for pod in range(K)]

    core = [[
    net.addSwitch('sc%d%d'%(i,j),
        cls = P4Switch,
        sw_path = exec_path,
        json_path = json_path,
        thrift_port = core_port[i][j],
        pcap_dump = True)
    for j in range(K/2)]
    for i in range(K/2)]



    edge_ip = [[
    '10.%d.%d.1'%(pod,i)
    for i in range(K/2)]
    for pod in range(K)]

    agg_ip = [[
    '10.%d.%d.1'%(pod,i)
    for i in range(K/2,K)]
    for pod in range(K)]

    core_ip = [[
    '10.%d.%d.%d'%(K,i+1,j+1)
    for j in range(K/2)]
    for i in range(K/2)]



    linkopt = {'bw': 20}

    #host to edge
    for pod in range(K):
        for i in range(K/2):
            for j in range(K/2):
                net.addLink(host[pod][i][j],edge[pod][i],cls=TCLink,**linkopt)

    #edge to aggregate
    for pod in range(K):
        for i in range(K/2):
            for j in range(K/2):
                net.addLink(edge[pod][i],agg[pod][j],cls=TCLink,**linkopt)

    #aggregate to core
    for pod in range(K):
        for i in range(K/2):
            for j in range(K/2):
                net.addLink(agg[pod][i],core[i][j],cls=TCLink,**linkopt)


    net.build()
    net.staticArp()
    net.start()

    #configure host forwarding
    for pod in range(K):
        for i in range(K/2):
            for j in range(K/2):
                host[pod][i][j].setDefaultRoute('dev eth0 via %s'%(edge_ip[pod][i]))
                # IPv6 messes with the logs. Disable it.
                host[pod][i][j].cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
                host[pod][i][j].cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")
                host[pod][i][j].cmd("sysctl -w net.ipv6.conf.lo.disable_ipv6=1")

    #get tablegen to initialize routing tables
    tablegen = imp.load_source('tablegen',tablegen_path).TableGenerator(
        K=K,
        port_offset=port_offset,
        verbose=True,
        cli_path=cli_path,
        json_path=json_path
    )

    tablegen.init_all()

    print "\n\n*** Topology setup done."

    if (args.test is not None):
        if (os.path.isfile("kickstart_python.test")):
            print "*** Running test: {}\n\n".format(args.test)
            CLI(net, script="kickstart_python.test")
            print "*** Test done: {}\n\n".format(args.test)
        else:
            print "*** Skipping test file, it does not exist: {}\n\n".format(args.test)
    else:
        print "*** No test to execute."
        # The interactive cmd will now only run if there are no tests executed.
        print "\n*** To quit, type 'exit' or press 'Ctrl+D'."
        CLI(net)

    try:
        net.stop()
    except:
        print "\n*** Quitting Mininet."
