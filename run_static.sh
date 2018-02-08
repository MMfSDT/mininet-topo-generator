#!/bin/bash

############################################################################################
#   run_static.sh
#       Bootstrap a static topology.
#       Follows this syntax:
#           ./run_static.sh [test name {none}] [K {4}]
#       Make sure to set env.sh first before proceeding.
############################################################################################

# Export all the prerequisite environmental variables for this process.
set -o allexport
source env.sh
set +o allexport

# Clean the mess Mininet makes from a failed exit silently.
sudo mn -c &> /dev/null

# Set the environmental variables before running the topology generator.
TOPO_EXEC_PATH=$TOPO_EXEC_PATH \
    TOPO_JSON_PATH=$TOPO_JSON_PATH \
    TOPO_CLI_PATH=$TOPO_CLI_PATH \
# Then finally run the generator with the following default arguments:
#   test name: none (cli only); K: 4;
    ./topogen.py --test_name ${1:-none} --K ${2:-4}