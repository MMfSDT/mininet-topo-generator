#!/usr/bin/env python
from mininet.net import Mininet
from mininet.cli import CLI
from mininet.link import Link, TCLink, Intf
from subprocess import Popen, PIPE
from mininet.log import setLogLevel
import sys
import subprocess
from random import randint

from router.p4_mininet import P4Switch, P4Host



###### INSERT PATHS HERE ######

exec_path = '../behavioral-model/targets/simple_router/simple_router'
json_path = './router/simple_router.json'
cli_path = '../behavioral-model/tools/runtime_CLI.py'

###############################



if '__main__' == __name__:
	setLogLevel('info')
	net = Mininet(controller=None)
    #key = "net.mptcp.mptcp_enabled"
    #value = 1
    #p = Popen("sysctl -w %s=%s" % (key, value),
    #        shell=True, stdout=PIPE, stderr=PIPE)
    #stdout, stderr = p.communicate()
    #print "stdout=", stdout, "stderr=", stderr

	K = int(sys.argv[1])
	print "Generating topology for K =",K

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
		pcap_dump = False)
	for i in range(K/2)]
	for pod in range(K)]

	agg = [[
	net.addSwitch('sa%d%d'%(pod,i),
		cls = P4Switch,
		sw_path = exec_path,
		json_path = json_path,
		thrift_port = agg_port[pod][i],
		pcap_dump = False)
	for i in range(K/2)]
	for pod in range(K)]

	core = [[
	net.addSwitch('sc%d%d'%(i,j),
		cls = P4Switch,
		sw_path = exec_path,
		json_path = json_path,
		thrift_port = core_port[i][j],
		pcap_dump = False)
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
	
	

	linkopt = {'bw': 10}
    
	#host to edge
	for pod in range(K):
		for i in range(K/2):
			for j in range(K/2):
				net.addLink(host[pod][i][j],edge[pod][i])

	#edge to aggregate
	for pod in range(K):
		for i in range(K/2):
			for j in range(K/2):
				net.addLink(edge[pod][i],agg[pod][j])

	#aggregate to core
	for pod in range(K):
		for i in range(K/2):
			for j in range(K/2):
				net.addLink(agg[pod][i],core[i][j])
				
	
	net.build()
	net.staticArp()
	net.start()
				
	
	#configure host forwarding
	for pod in range(K):
		for i in range(K/2):
			for j in range(K/2):
				host[pod][i][j].setDefaultRoute('dev eth0 via %s'%(edge_ip[pod][i]))
	
	#configure edge forwarding
	for pod in range(K):
		for i in range(K/2):
			cmd = ['table_set_default ipv4_exact _drop']
			
			#downstream
			for j in range(K/2):
				cmd.append('table_add ipv4_exact set_nhop %s => %s %d'%(host_ip[pod][i][j],host_ip[pod][i][j],j+1))
				
			#upstream
			for npod in range(K):
				for ni in range(K/2):
					if npod==pod and ni==i:
						continue
					for nj in range(K/2):
						fwd = randint(0,K/2-1)
						cmd.append('table_add ipv4_exact set_nhop %s => %s %d'%(host_ip[npod][ni][nj],agg_ip[pod][fwd],fwd+K/2+1))
			
			p = subprocess.Popen(
				[cli_path, '--json', json_path, '--thrift-port', str(edge_port[pod][i])],
				stdin=subprocess.PIPE,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE)
			
			msg,err = p.communicate('\n'.join(cmd))
			print msg
	
	#configure agg forwarding
	for pod in range(K):
		for i in range(K/2):
			cmd = ['table_set_default ipv4_exact _drop']
			
			for npod in range(K):
				for ni in range(K/2):
					for nj in range(K/2):
						if pod==npod:
							#downstream
							cmd.append('table_add ipv4_exact set_nhop %s => %s %d'%(host_ip[npod][ni][nj],edge_ip[pod][ni],ni+1))
						else:
							#upstream
							fwd = randint(0,K/2-1)
							cmd.append('table_add ipv4_exact set_nhop %s => %s %d'%(host_ip[npod][ni][nj],core_ip[i][fwd],fwd+K/2+1))
			
			p = subprocess.Popen(
				[cli_path, '--json', json_path, '--thrift-port', str(agg_port[pod][i])],
				stdin=subprocess.PIPE,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE)
			
			msg,err = p.communicate('\n'.join(cmd))
			print msg
	
	#configure core forwarding
	for i in range(K/2):
		for j in range(K/2):
			cmd = ['table_set_default ipv4_exact _drop']
			
			for npod in range(K):
				for ni in range(K/2):
					for nj in range(K/2):
						#everything is downstream
						cmd.append('table_add ipv4_exact set_nhop %s => %s %d'%(host_ip[npod][ni][nj],agg_ip[npod][ni],npod+1))
			
			p = subprocess.Popen(
				[cli_path, '--json', json_path, '--thrift-port', str(core_port[i][j])],
				stdin=subprocess.PIPE,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE)
			
			msg,err = p.communicate('\n'.join(cmd))
			print msg

	print "\n\nDone!"
	CLI(net)
	net.stop()
