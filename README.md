# mininet-topo-generator
Generates a scalable fat-tree topology with customizable switches.

## Running the script
To run the topology generator, use the following command:
```bash
sudo mn -c && sudo python2 topogen.py <K>
```
where K is the size of the fat-tree network (K is an element of \{2,4,8,16,32,64,128\}).
