#!/bin/bash

############################################################################################
#   run.sh
#       Bootstrap a static topology.
#       Virtually follows topogen.py's syntax:
#           ./run.sh 
#               [--test path_to_test {none}] 
#               [--post path_to_post_process_script {none}]
#               [--router router_behavior {static}]
#               [--pcap]
#               [--K K {4}]
#               [--proto tcp|mptcp {mptcp}]
#               [--pmanager fullmesh|ndiffports {fullmesh}]
#               [--diffports num_diff_ports {1}]
#               [--payloadsize query|long|short {short}]
#               [--runcount num_counts {10}]
#       Make sure to set env.sh first before proceeding.
############################################################################################

# Export all the prerequisite environmental variables for this process.
set -o allexport
source env.sh
set +o allexport

# Clean the mess Mininet makes from a failed exit silently.
sudo mn -c &> /dev/null

# Clean old .pcap traces in case of errors.
rm s*.pcap

# Find the test script, if indicated.
# Store arguments first as we're mutating it.
args=("$@")

# Loop through and find value assigned to "--test".
while [[ "$#" > 0 ]]; do case $1 in
    --test) test="$2"; shift;;
    --post) post="$2"; shift;;
    --router) router="$2"; shift;;
    --pcap) pcap="true";;
    --K) K="$2"; shift;;
    --proto) proto="$2"; shift;;
    --pmanager) pmanager="$2"; shift;;
    --diffports) diffports="$2"; shift;;
    --payloadsize) payloadsize="$2"; shift;;
    --runcount) runcount="$2"; shift;;
    esac; shift
done

# Restore arguments to original position.
set -- "${args[@]}"

# Set default arguments.
if [[ -z "$router" ]]; then router="static"; fi
if [[ -z "$K" ]]; then K="4"; fi
if [[ -z "$proto" ]]; then proto="mptcp"; fi
if [[ -z "$pmanager" ]]; then pmanager="fullmesh"; fi
if [[ -z "$diffports" ]]; then diffports="1"; fi
if [[ -z "$payloadsize" ]]; then payloadsize="short"; fi
if [[ -z "$runcount" ]]; then runcount="10"; fi

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

# Set the TOPO_JSON and TOPO_TABLEGEN paths accordingly.
if [ "$router" == "static" ]; then
    TOPO_JSON_PATH=$TOPO_JSON_SIMPLE_PATH
    TOPO_TABLEGEN_PATH=$TOPO_TABLEGEN_SIMPLE_PATH
elif [[ "$router" == "ecmp" ]]; then
    TOPO_JSON_PATH=$TOPO_JSON_ECMP_PATH
    TOPO_TABLEGEN_PATH=$TOPO_TABLEGEN_ECMP_PATH
elif [[ "$router" == "ps" ]]; then
    TOPO_JSON_PATH=$TOPO_JSON_PS_PATH
    TOPO_TABLEGEN_PATH=$TOPO_TABLEGEN_PS_PATH
else
    echo "run.sh: error setting up router: unknown value \"$router\""
    exit 1
fi

# Quit the script if it is run with a post-processing script (--post) without pcap-logging enabled (--pcap).
if [[ ! -z "$post" ]] && [[ -z "$pcap" ]]; then
    echo "run.sh: can't run post-processing script without --pcap"
    exit 1
fi

# Create the argument file for the test file in JSON.
echo "{" > ../network-tests/logs/args.txt
echo "\"router\": \"$router\"," >> ../network-tests/logs/args.txt
echo "\"K\": \"$K\"," >> ../network-tests/logs/args.txt
echo "\"proto\": \"$proto\"," >> ../network-tests/logs/args.txt
echo "\"pmanager\": \"$pmanager\"," >> ../network-tests/logs/args.txt
echo "\"diffports\": \"$diffports\"," >> ../network-tests/logs/args.txt
echo "\"payloadsize\": \"$payloadsize\"," >> ../network-tests/logs/args.txt
echo "\"runcount\": \"$runcount\"" >> ../network-tests/logs/args.txt
echo "}" >> ../network-tests/logs/args.txt

# Set the environmental variables before running the topology generator.
TOPO_EXEC_PATH=$TOPO_EXEC_PATH
TOPO_CLI_PATH=$TOPO_CLI_PATH

# Then finally run the generator, passing fully all arguments.
    ./topogen.py "$@" --exec_path $TOPO_EXEC_PATH --json_path $TOPO_JSON_PATH --cli_path $TOPO_CLI_PATH --tablegen_path $TOPO_TABLEGEN_PATH || exit 1

# Clean the mess again after exiting, silently.
sudo mn -c &> /dev/null

# Run the postprocessing file, then delete all traces.
if [[ ! -z "$post" ]]; then
    sudo -u $SUDO_USER ./$post "$@" || exit 1
    rm s*.pcap
fi
