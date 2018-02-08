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

## Running the script
### Scalable Fat-Tree with Static Routes
To run the topology generator, use the following command:
```bash
sudo ./run_static.sh [test_name {none}] [K {4}]
```
where `test_name` pertains to the test to be ran after generation (defaults to `none`, which goes directly to the Mininet cli), and `K` is the size of the Fat-Tree network (`K` is an element of \{2, 4, 8, 16, 32, 64, 128\}; defaults to `4`).
