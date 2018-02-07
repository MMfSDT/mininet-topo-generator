# mininet-topo-generator
Generates a scalable fat-tree topology with customizable switches.

## Dependencies
Before using the topology generator, you must have cloned and built the behavioral model repository:
https://github.com/p4lang/behavioral-model

Once you've built the repository, open topogen.py and correct the executable and runtime CLI script paths if necessary. 

## Running the script
To run the topology generator, use the following command:
```bash
sudo mn -c && sudo python2 topogen.py <K>
```
where K is the size of the fat-tree network (K is an element of \{2,4,8,16,32,64,128\}).
