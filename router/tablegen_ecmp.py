#!/usr/bin/env python

from random import shuffle
import subprocess

class TableGenerator:
	
	def __init__(self, K, port_offset, cli_path, json_path, verbose=False):
		self.host_ip = [[[
		'10.%d.%d.%d'%(pod,i,j+2)
		for j in range(K/2)]
		for i in range(K/2)]
		for pod in range(K)]
			
		self.port_offset = port_offset
		
		self.edge_port = [[
		pod*K/2+i + port_offset
		for i in range(K/2)]
		for pod in range(K)]
	
		self.agg_port = [[
		pod*K/2+i + K*K/2 + port_offset
		for i in range(K/2)]
		for pod in range(K)]
		
		self.core_port = [[
		i*K/2+j + K*K + port_offset
		for j in range(K/2)]
		for i in range(K/2)]
		
		self.verbose = verbose
		self.K = K
		self.port_offset = port_offset
		self.cli_path = cli_path
		self.json_path = json_path
		
		if self.verbose:
			print "Initialized TableGenerator with K=",K,", port_offset=",port_offset,", verbose=",verbose
	
	def edge_init(self):
		if self.verbose:
			print "Configuring edge routers"
		
		for pod in range(self.K):
			for i in range(self.K/2):
				if self.verbose:
					print "Configuring se%d%d"%(pod,i)

				cmd = ['table_set_default ipv4_match _drop']
			
				#downstream
				for j in range(self.K/2):
					for p in range(8):
						cmd.append('table_add ipv4_match set_nhop 10.%d.%d.%d/32 %d => %d'%(pod,i,j+2,p,j+1))

				ports = []
				for p in range(self.K/2):
					for j in range(16/self.K):
						ports.append(p)
				shuffle(ports)

				
				#upstream
				for j in range(8):
					p = ports[j]
					cmd.append('table_add ipv4_match set_nhop 10.0.0.0/8 %d => %d'%(j,p+1+self.K/2))
			
				p = subprocess.Popen(
					[self.cli_path, '--json', self.json_path, '--thrift-port', str(self.edge_port[pod][i])],
					stdin=subprocess.PIPE,
					stdout=subprocess.PIPE,
					stderr=subprocess.PIPE)
			
				msg,err = p.communicate('\n'.join(cmd))
				if self.verbose:
					print msg
				
	def agg_init(self):
		if self.verbose:
			print "Configuring aggregate routers"
		
		for pod in range(self.K):
			for i in range(self.K/2):
				if self.verbose:
					print "Configuring sa%d%d"%(pod,i)
					
				cmd = ['table_set_default ipv4_match _drop']
				
				ports = []
				for p in range(self.K/2):
					for j in range(16/self.K):
						ports.append(p)
				shuffle(ports)

				#downstream
				for j in range(self.K/2):
					for p in range(8):
						cmd.append('table_add ipv4_match set_nhop 10.%d.%d.0/24 %d => %d'%(pod,j,p,j+1))
				
				#upstream
				for j in range(8):
					p = ports[j]
					cmd.append('table_add ipv4_match set_nhop 10.0.0.0/8 %d => %d'%(j,p+1+self.K/2))
			
				p = subprocess.Popen(
					[self.cli_path, '--json', self.json_path, '--thrift-port', str(self.agg_port[pod][i])],
					stdin=subprocess.PIPE,
					stdout=subprocess.PIPE,
					stderr=subprocess.PIPE)
				
				msg,err = p.communicate('\n'.join(cmd))
				if self.verbose:
					print msg
	
	def core_init(self):
		if self.verbose:
			print "Configuring core routers"
		
		for i in range(self.K/2):
			for j in range(self.K/2):
				if self.verbose:
					print "\nConfiguring sc%d%d"%(i,j)
					
				cmd = ['table_set_default ipv4_match _drop']
			
				#everything is downstream
				for pod in range(self.K):
					for p in range(8):
						cmd.append('table_add ipv4_match set_nhop 10.%d.0.0/16 %d => %d'%(pod,p,pod+1))
			
				p = subprocess.Popen(
					[self.cli_path, '--json', self.json_path, '--thrift-port', str(self.core_port[i][j])],
					stdin=subprocess.PIPE,
					stdout=subprocess.PIPE,
					stderr=subprocess.PIPE)
				
				msg,err = p.communicate('\n'.join(cmd))
				if self.verbose:
					print msg
	
	def init_all(self):
		if self.verbose:
			print "Initializing all routers\n\n"
		
		self.edge_init()
		self.agg_init()
		self.core_init()
