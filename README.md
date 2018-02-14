# mininet-topo-generator
Generates a scalable fat-tree topology with customizable switches.

## Prerequisites and Dependencies
### P4's Behavioral Model
Before using the topology generator, you must have cloned and built the (behavioral model repository)[https://github.com/p4lang/behavioral-model]:

On your own comfortable directory, run the following code.
```bash
sudo apt-get update
git clone git://github.com/p4lang/behavioral-model
cd behavioral-model
sudo ./install-deps.sh
./autogen.sh
./configure --enable-debugger
make
```
### Setting Up Required Paths
Once you've built the repository, open `env.sh.example`, rename it to `env.sh`, and correct the executable and runtime CLI script paths if necessary.

## Running the Script
The same topology can be generated with differing switch behavior. To run the topology generator, use the following command:
```bash
sudo ./run_script.sh [--test path_to_test {None}] [--K K {4}] [--pcap]
```
where 
* `run_script` is one of the currently supported run scripts, and determines the routing behavior of the topology,
* `path_to_test` pertains to the test to be ran after generation (defaults to `None`, which goes directly to the Mininet cli),
* `K` is the size of the Fat-Tree network (`K` is an element of \{2, 4, 8, 16, 32, 64, 128\}; defaults to `4`),
* and `--pcap` enables `.pcap` logging (necessary for some tests).

### Supported Run Scripts
The following run scripts are currently supported:
* `run_static.sh` - generates a topology with static routes, randomly chosen at generation.

## Exiting the Script
To exit from the CLI, enter `exit` or press `Ctrl+D` (`Ctrl+C` doesn't work).

## Conventions
This section clarifies the several conventions used in assigning properties, such as names and ip addresses, of nodes in the mininet topology.
### Standard Topology Structure
For a given K, the topology is composed of K pods. Each pod is composed of K/2 aggregate routers and K/2 edge routers, each aggregate router connected to all edge routers, and vice versa. Each edge router is connected to K/2 hosts, for a total of (K/2)^2 hosts per pod. There are a total of (K/2)^2 core routers, each connected to one aggregate router per pod.
### Numbering and Naming
The following numbering and naming conventions are used:
* The pods are numbered for 0 to K-1.
* Edge routers are named `se<pod><i>`, where <pod> is the pod id, and <i> is the edge id within the pod, ranging from 0 to (K/2)-1.
* Aggregate routers are named `sa<pod><i>`, where <pod> is the pod id, and <i> is the aggregate id within the pod, ranging from 0 to (K/2)-1.
* Core routers are named `sc<i><j>`, where <i> and <j> ranges from 0 to (K/2)-1. <j> is an identifier for all cores of the same <i>, and <i> determines which aggregate core it connects to for each pod. The significance of <i> and <j> are explained in the Connections subsection.
* Hosts are named `h<pod><i><j>`, where <pod> is the pod id, <i> is the edge id of the edge router it is connected to, and <j> is the host id for all hosts connected to the i'th edge router.

### IP Addresses
From the node names, we can map it directly to unique IP addresses:
* For hosts with names `h<pod><i><j>`, the IP address is `10.<pod>.<i>.<j+2>`.
* For edge routers with names `se<pod><i>`, the IP address is `10.<pod>.<i>.1`.
* For aggregate routers with names `sa<pod><i>`, the IP address is `10.<pod>.<i+(K/2)>.1`.
* For core routers with names `sc<i><j>`, the IP address is `10.<K>.<i+1>.<j+1>`.

### Links
The following describes more precisely the connections between nodes:
* An edge router se<POD><I> is connected to hosts h<POD><I><j> for all 0 <= j <= (K/2)-1.
* All aggregate routers are connected to edge routers in the same pod, and vice versa. More precisely, an aggregate router sa<POD><I> is connected to edge routers se<POD><j> for all 0 <= j <= (K/2)-1.
* A core router sc<I><J> is connected to aggregate routers sa<pod><I> for 0 <= pod <= K-1.

### Port Assignment
Each link connected to a router is assigned a port for that router. For the following descriptions, the ports are numbered from 0 to K-1 (though in reality, it is usually numbered from 1 to K). The following describes the assignment for the p'th port for each type of router:
* For an edge router se<POD><I>, the first K/2 ports is assigned to host h<POD><I><p>, and the last K/2 ports is assigned to aggregate router sa<POD><p-(K/2)>.
* For an aggregate router sa<POD><I>, the first K/2 ports is assigned to edge router se<POD><p>, and the last K/2 ports is assigned to core router sc<I><p-(K/2)>
* For a core router sc<I><J>, the ports are assigned to aggregate router sa<p><I>.

The interfaces are similary assigned, but from eth1 to eth<K> instead of 0 to K-1.
### Thrift Port
Thrift ports are assigned for each router, and can be used to communicate and debug with the router. The following describes how the thrift ports are assigned:
* The first thrift port is 10000, and is assigned to se00. Succeeding ports are increasing in increments of 1.
* The first K*(K/2) thrift ports are assigned to edge routers se00, ..., se0<(K/2)-1>, se10, ..., se<K-1><(K/2)-1>.
* The next K*(K/2) thrift ports are assigned to aggregate routers sa00, ..., sa0<(K/2)-1>, sa10, ..., sa<K-1><(K/2)-1>.
* The next (and last) (K/2)^2 thrift ports are assigned to core routers sc00, ..., sc0<(K/2)-1>, sc10, ..., sc<(K/2)-1><(K/2)-1>.

## Debugging Using the nanomsg_client Tool
The Behavioral Model Repository has several tools that can be used for debugging. One which is enabled by default is the tools/nanomsg_client.py tool. It enables you to view how packets are processed inside the router (parser state transitions, table hits/misses, etc.). To use it, use the following command:

```bash
sudo ./nanomsg_client.py --thrift-port <port>
```

where <port> is the thrift port of the router you wish to view.