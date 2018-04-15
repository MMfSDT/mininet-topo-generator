#!/bin/bash

############################################################################################
#   run.sh
#       Bootstrap a static topology.
#       Virtually follows topogen.py's syntax:
#           sudo ./run.sh 
#               [--test path_to_test {none}] 
#               [--post path_to_post_process_script {none}]
#               [--router router_behavior {static}]
#               [--pcap]
#               [--K K {4}]
#               [--proto tcp|mptcp {mptcp}]
#               [--pmanager fullmesh|ndiffports {fullmesh}]
#               [--diffports num_diff_ports {1}]
#               [--juggler]
#               [--payloadsize query|long|short {short}]
#               [--runcount num_counts {10}]
#               [--mode onetoone|onetomany {onetoone}]
#       Make sure to set env.sh first before proceeding.
############################################################################################

# *** Check arguments before script execution ***
# Quit the program if it wasn't executed as root.
if [[ $EUID -ne 0 ]]; then
    echo "[Error] run.sh must be executed as root. Quitting."
    exit 1
fi

# Check the curl version.
# TODO: Add argument skipping this test.

latestVer=$(curl -s 'https://curl.haxx.se/download/' | grep -oP 'href="curl-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -t. -rn -k1,1 -k2,2 -k3,3 | head -1)
installedVer=$(curl -V | grep -oP 'curl \K[0-9]+\.[0-9]+\.[0-9]+')

if [[ $latestVer != $installedVer ]]; then
    echo "Installing curl $latestVer"
    sudo apt-get build-dep curl
    mkdir ~/curl
    pushd ~/curl
    wget http://curl.haxx.se/download/curl-$latestVer.tar.bz2
    tar -xvjf curl-$latestVer.tar.bz2
    cd curl-$latestVer

    ./configure
    make
    sudo make install

    sudo ldconfig
    popd    
fi


# Export all the prerequisite environmental variables for this process.
set -o allexport
source env.sh
set +o allexport

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
    --juggler) juggler="true";;
    --payloadsize) payloadsize="$2"; shift;;
    --runcount) runcount="$2"; shift;;
    --mode) mode="$2"; shift;;
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
if [[ -z "$mode" ]]; then mode="onetoone"; fi

# Quit the script if it is run with K < 4 and mode of `onetomany`.
if (( K < 4 )) && [[ "$mode" == "onetomany" ]]; then
    echo "run.sh: onetomany does not work on K < 4"
    exit 1
fi

# Set the TOPO_JSON and TOPO_TABLEGEN paths accordingly, quit if incorrect value.
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

# Clean the mess Mininet makes from a failed exit silently.
mn -c &> /dev/null

# Clean old .pcap traces in case of errors.
rm s*.pcap &> /dev/null

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

# Create the argument file for the test file in JSON.
echo "{" > ../network-tests/logs/args.txt
echo "\"router\": \"$router\"," >> ../network-tests/logs/args.txt
echo "\"K\": \"$K\"," >> ../network-tests/logs/args.txt
echo "\"proto\": \"$proto\"," >> ../network-tests/logs/args.txt
echo "\"pmanager\": \"$pmanager\"," >> ../network-tests/logs/args.txt
echo "\"diffports\": \"$diffports\"," >> ../network-tests/logs/args.txt

if [[ ! -z "$juggler" ]]; then
    echo "\"juggler\": \"true\"," >> ../network-tests/logs/args.txt
else
    echo "\"juggler\": \"false\"," >> ../network-tests/logs/args.txt
fi

if [[ ! -z "$pcap" ]]; then
    echo "\"pcap\": \"true\"," >> ../network-tests/logs/args.txt
else
    echo "\"pcap\": \"false\"," >> ../network-tests/logs/args.txt
fi

echo "\"payloadsize\": \"$payloadsize\"," >> ../network-tests/logs/args.txt
echo "\"runcount\": \"$runcount\"," >> ../network-tests/logs/args.txt
echo "\"mode\": \"$mode\"" >> ../network-tests/logs/args.txt
echo "}" >> ../network-tests/logs/args.txt

# Prepare topogen.py arguments
TOPOGEN_ARGS=(--exec_path $TOPO_EXEC_PATH --json_path $TOPO_JSON_PATH --cli_path $TOPO_CLI_PATH --tablegen_path $TOPO_TABLEGEN_PATH --K $K)
if [[ ! -z "$test" ]]; then TOPOGEN_ARGS+=(--test $test); fi

# Remove previous mid.json
rm ../network-tests/logs/mid.json

# Finally, run topogen.py with the arguments specified above.
./topogen.py ${TOPOGEN_ARGS[*]}  || exit 1

# Clean the mess again after exiting, silently.
mn -c &> /dev/null

# If mid.json wasn't written, assume the test failed.
if [ ! -f ../network-tests/logs/mid.json ] && [[ ! -z "$post" ]]; then
    echo "Network testing failed."
    exit 1
fi

# Remove the /tmp/ trash from onetomany. Uncomment this if necessary.
if [[ "$mode" == "onetomany" ]]; then
    rm /tmp/mmfsdt-*
fi

# Fix the file ownership of the *.pcap at log files.
chown $SUDO_USER:$SUDO_USER ../network-tests/logs/args.txt
chown $SUDO_USER:$SUDO_USER ../network-tests/logs/aggregate.db
chown $SUDO_USER:$SUDO_USER ../network-tests/logs/mid.json
chown $SUDO_USER:$SUDO_USER s*.pcap

# Run the postprocessing file, then delete all traces.
if [[ ! -z "$post" ]]; then
    sudo -u $SUDO_USER ./$post "$@" || exit 1
    rm s*.pcap &> /dev/null
fi
