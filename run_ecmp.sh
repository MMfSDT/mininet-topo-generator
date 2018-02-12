#!/bin/bash

############################################################################################
#   run_static.sh
#       Bootstrap a static topology.
#       Virtually follows topogen.py's syntax:
#           ./run_static.sh [--test_name test name {none}] [--K K {4}] [--pcap]
#       Make sure to set env.sh first before proceeding.
############################################################################################

# Export all the prerequisite environmental variables for this process.
set -o allexport
source env.sh
set +o allexport

# Clean the mess Mininet makes from a failed exit silently.
sudo mn -c &> /dev/null

# Find the test script, if indicated.
# Store arguments first as we're mutating it.
args=("$@")
# Loop through and find value assigned to "--test".
while [[ "$#" > 1 ]]; do case $1 in
    --test) test="$2"; shift;;
  esac; shift
done
# Restore arguments to original position.
set -- "${args[@]}"

# It is necessary to create a source file for Mininet to parse.
#   This automatically generated file is at "./kickstart_python.test"
if [[ -z "$test" ]]; then
    # If "--test" wasn't given as an argument, remove existing source file.
    echo "No test to execute."
    rm kickstart_python.test &> /dev/null
elif [[ ! -f "$test" ]]; then
    # If "--test" file does not exist, remove existing source file.
    echo "File \"$test\" does not exist. Skipping."
    rm kickstart_python.test &> /dev/null
else 
    # If "--test" file does exist, write the source file.
    echo "py execfile(\"$test\")" > kickstart_python.test
    echo "Running test: \"$test\""
fi

# Set the environmental variables before running the topology generator.
TOPO_EXEC_PATH=$TOPO_EXEC_PATH
TOPO_JSON_PATH=$TOPO_JSON_ECMP_PATH
TOPO_CLI_PATH=$TOPO_CLI_PATH
TOPO_TABLEGEN_PATH=$TOPO_TABLEGEN_ECMP_PATH

# Then finally run the generator, passing fully all arguments.
    ./topogen.py "$@" --exec_path $TOPO_EXEC_PATH --json_path $TOPO_JSON_PATH --cli_path $TOPO_CLI_PATH --tablegen_path $TOPO_TABLEGEN_PATH
# Clean the mess again after exiting, silently.
sudo mn -c &> /dev/null
