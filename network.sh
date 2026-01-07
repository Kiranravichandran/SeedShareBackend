#!/bin/bash
#
# SeedShare Network Management Script
# This script manages the Hyperledger Fabric network for the SeedShare project
#

# Set script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAINCODE_DIR="${SCRIPT_DIR}/chaincode"

# Export paths
export PATH=${SCRIPT_DIR}/bin:$PATH
export FABRIC_CFG_PATH=${SCRIPT_DIR}/config

# Import utility functions
. scripts/utils.sh

# Container CLI configuration
: ${CONTAINER_CLI:="docker"}
: ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}

# Default configuration
CHANNEL_NAME="mychannel"
CC_NAME="SeedshareNetwork"
CC_VERSION="1"
CC_SEQUENCE="1"
CC_INIT_FCN="instantiate"
CC_SRC_LANGUAGE="javascript"
CC_SRC_PATH="./chaincode"
CC_END_POLICY="NA"
CC_COLL_CONFIG="NA"
VERBOSE=false
CRYPTO="cryptogen"
MAX_RETRY=5
CLI_DELAY=3
DATABASE="leveldb"

# Docker compose file configuration
COMPOSE_FILE_BASE=compose-test-net.yaml
COMPOSE_FILE_COUCH=compose-couch.yaml
COMPOSE_FILE_CA=compose-ca.yaml

# Get docker sock path from environment variable
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"

# Set environment variables for Org1
function setOrg1Env() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_ADDRESS=localhost:7051
    export CORE_PEER_MSPCONFIGPATH=${SCRIPT_DIR}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=${SCRIPT_DIR}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
}

# Set environment variables for Org2
function setOrg2Env() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_ADDRESS=localhost:9051
    export CORE_PEER_MSPCONFIGPATH=${SCRIPT_DIR}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=${SCRIPT_DIR}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
}

# Obtain CONTAINER_IDS and remove them
function clearContainers() {
    infoln "Removing remaining containers"
    ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
    ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter name='dev-peer*') 2>/dev/null || true
}

# Delete any images that were generated as a part of this setup
function removeUnwantedImages() {
    infoln "Removing generated chaincode docker images"
    ${CONTAINER_CLI} image rm -f $(${CONTAINER_CLI} images -aq --filter reference='dev-peer*') 2>/dev/null || true
}

# Versions of fabric known not to work with the test network
NONWORKING_VERSIONS="^1\.0\. ^1\.1\. ^1\.2\. ^1\.3\. ^1\.4\."

# Check prerequisites
function checkPrereqs() {
    ## Check if your have cloned the peer binaries and configuration files.
    peer version > /dev/null 2>&1

    if [[ $? -ne 0 || ! -d "${SCRIPT_DIR}/config" ]]; then
        errorln "Peer binary and configuration files not found.."
        errorln
        errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
        errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
        exit 1
    fi

    # use the fabric tools container to see if the samples and binaries match your
    # docker images
    LOCAL_VERSION=$(peer version | sed -ne 's/^ Version: //p')
    DOCKER_IMAGE_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-tools:latest peer version | sed -ne 's/^ Version: //p')

    infoln "LOCAL_VERSION=$LOCAL_VERSION"
    infoln "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

    if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
        warnln "Local fabric binaries and docker images are out of sync. This may cause problems."
    fi

    for UNSUPPORTED_VERSION in $NONWORKING_VERSIONS; do
        infoln "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
        if [ $? -eq 0 ]; then
            fatalln "Local Fabric binary version of $LOCAL_VERSION does not match the versions supported by the test network."
        fi

        infoln "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
        if [ $? -eq 0 ]; then
            fatalln "Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match the versions supported by the test network."
        fi
    done

    ## Check for fabric-ca
    if [ "$CRYPTO" == "Certificate Authorities" ]; then
        fabric-ca-client version > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            errorln "fabric-ca-client binary not found.."
            errorln
            errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
            errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
            exit 1
        fi
        CA_LOCAL_VERSION=$(fabric-ca-client version | sed -ne 's/ Version: //p')
        CA_DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-ca:latest fabric-ca-client version | sed -ne 's/ Version: //p' | head -1)
        infoln "CA_LOCAL_VERSION=$CA_LOCAL_VERSION"
        infoln "CA_DOCKER_IMAGE_VERSION=$CA_DOCKER_IMAGE_VERSION"

        if [ "$CA_LOCAL_VERSION" != "$CA_DOCKER_IMAGE_VERSION" ]; then
            warnln "Local fabric-ca binaries and docker images are out of sync. This may cause problems."
        fi
    fi

    # Check if chaincode directory exists
    if [ ! -d "${CHAINCODE_DIR}" ]; then
        fatalln "Chaincode directory not found at ${CHAINCODE_DIR}"
    fi

    infoln "Prerequisites check passed"
}

# Create Organization crypto material using cryptogen or CAs
function createOrgs() {
    if [ -d "organizations/peerOrganizations" ]; then
        rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
    fi

    # Create crypto material using cryptogen
    if [ "$CRYPTO" == "cryptogen" ]; then
        which cryptogen
        if [ "$?" -ne 0 ]; then
            fatalln "cryptogen tool not found. exiting"
        fi
        infoln "Generating certificates using cryptogen tool"

        infoln "Creating Org1 Identities"

        set -x
        cryptogen generate --config=./organizations/cryptogen/crypto-config-org1.yaml --output="organizations"
        res=$?
        { set +x; } 2>/dev/null
        if [ $res -ne 0 ]; then
            fatalln "Failed to generate certificates..."
        fi

        infoln "Creating Org2 Identities"

        set -x
        cryptogen generate --config=./organizations/cryptogen/crypto-config-org2.yaml --output="organizations"
        res=$?
        { set +x; } 2>/dev/null
        if [ $res -ne 0 ]; then
            fatalln "Failed to generate certificates..."
        fi

        infoln "Creating Orderer Org Identities"

        set -x
        cryptogen generate --config=./organizations/cryptogen/crypto-config-orderer.yaml --output="organizations"
        res=$?
        { set +x; } 2>/dev/null
        if [ $res -ne 0 ]; then
            fatalln "Failed to generate certificates..."
        fi

    fi

    # Create crypto material using Fabric CA
    if [ "$CRYPTO" == "Certificate Authorities" ]; then
        infoln "Generating certificates using Fabric CA"
        ${CONTAINER_CLI_COMPOSE} -f compose/$COMPOSE_FILE_CA -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-$COMPOSE_FILE_CA up -d 2>&1

        . organizations/fabric-ca/registerEnroll.sh

        while :
        do
            if [ ! -f "organizations/fabric-ca/org1/tls-cert.pem" ]; then
                sleep 1
            else
                break
            fi
        done

        infoln "Creating Org1 Identities"
        createOrg1

        infoln "Creating Org2 Identities"
        createOrg2

        infoln "Creating Orderer Org Identities"
        createOrderer
    fi

    infoln "Generating CCP files for Org1 and Org2"
    ./organizations/ccp-generate.sh
}

# Bring up the peer and orderer nodes using docker compose.
function networkUp() {
    checkPrereqs

    # generate artifacts if they don't exist
    if [ ! -d "organizations/peerOrganizations" ]; then
        createOrgs
    fi

    COMPOSE_FILES="-f compose/${COMPOSE_FILE_BASE} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_BASE}"

    if [ "${DATABASE}" == "couchdb" ]; then
        COMPOSE_FILES="${COMPOSE_FILES} -f compose/${COMPOSE_FILE_COUCH} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
    fi

    infoln "Starting Hyperledger Fabric network..."
    DOCKER_SOCK="${DOCKER_SOCK}" ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} up -d 2>&1

    $CONTAINER_CLI ps -a
    if [ $? -ne 0 ]; then
        fatalln "Unable to start network"
    fi
    
    infoln "Network started successfully"
}

# Create channel
function createChannel() {
    # Bring up the network if it is not already up.
    bringUpNetwork="false"

    if ! $CONTAINER_CLI info > /dev/null 2>&1 ; then
        fatalln "$CONTAINER_CLI network is required to be running to create a channel"
    fi

    # check if all containers are present
    CONTAINERS=($($CONTAINER_CLI ps | grep hyperledger/ | awk '{print $2}'))
    len=$(echo ${#CONTAINERS[@]})

    if [[ $len -ge 4 ]] && [[ ! -d "organizations/peerOrganizations" ]]; then
        echo "Bringing network down to sync certs with containers"
        networkDown
    fi

    [[ $len -lt 4 ]] || [[ ! -d "organizations/peerOrganizations" ]] && bringUpNetwork="true" || echo "Network Running Already"

    if [ $bringUpNetwork == "true"  ]; then
        infoln "Bringing up network"
        networkUp
    fi

    infoln "Creating channel: ${CHANNEL_NAME}"
    # now run the script that creates a channel. This script uses configtxgen once
    # to create the channel creation transaction and the anchor peer updates.
    scripts/createChannel.sh $CHANNEL_NAME $CLI_DELAY $MAX_RETRY $VERBOSE
    
    if [ $? -eq 0 ]; then
        infoln "Channel ${CHANNEL_NAME} created successfully"
    else
        fatalln "Failed to create channel"
    fi
}

# Deploy chaincode
function deployChaincode() {
    infoln "Deploying chaincode: ${CC_NAME}"
    
    scripts/deployCC.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE

    if [ $? -ne 0 ]; then
        fatalln "Failed to deploy chaincode"
    fi
    
    infoln "Chaincode ${CC_NAME} deployed successfully"
}

# Invoke chaincode function
function invokeChaincode() {
    local function_name=$1
    local args=$2
    
    if [ -z "$function_name" ]; then
        fatalln "Function name is required for chaincode invocation"
    fi
    
    infoln "Invoking chaincode function: ${function_name}"
    
    # Set Org1 environment
    setOrg1Env
    
    # Construct the invoke command
    local invoke_args="{\"function\":\"${function_name}\",\"Args\":[${args}]}"
    
    peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls \
        --cafile ${SCRIPT_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        -C ${CHANNEL_NAME} \
        -n ${CC_NAME} \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles ${SCRIPT_DIR}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles ${SCRIPT_DIR}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
        -c "${invoke_args}"
    
    if [ $? -eq 0 ]; then
        infoln "Chaincode function ${function_name} invoked successfully"
    else
        errorln "Failed to invoke chaincode function ${function_name}"
    fi
}

# Query chaincode function
function queryChaincode() {
    local function_name=$1
    local args=$2
    
    if [ -z "$function_name" ]; then
        fatalln "Function name is required for chaincode query"
    fi
    
    infoln "Querying chaincode function: ${function_name}"
    
    # Set Org1 environment
    setOrg1Env
    
    # Construct the query command
    local query_args="{\"function\":\"${function_name}\",\"Args\":[${args}]}"
    
    peer chaincode query \
        -C ${CHANNEL_NAME} \
        -n ${CC_NAME} \
        -c "${query_args}"
    
    if [ $? -eq 0 ]; then
        infoln "Chaincode function ${function_name} queried successfully"
    else
        errorln "Failed to query chaincode function ${function_name}"
    fi
}

# Tear down running network
function networkDown() {
    infoln "Stopping Hyperledger Fabric network..."

    COMPOSE_BASE_FILES="-f compose/${COMPOSE_FILE_BASE} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_BASE}"
    COMPOSE_COUCH_FILES="-f compose/${COMPOSE_FILE_COUCH} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
    COMPOSE_CA_FILES="-f compose/${COMPOSE_FILE_CA} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_CA}"
    COMPOSE_FILES="${COMPOSE_BASE_FILES} ${COMPOSE_COUCH_FILES} ${COMPOSE_CA_FILES}"

    if [ "${CONTAINER_CLI}" == "docker" ]; then
        DOCKER_SOCK=$DOCKER_SOCK ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes --remove-orphans
    elif [ "${CONTAINER_CLI}" == "podman" ]; then
        ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes
    else
        fatalln "Container CLI  ${CONTAINER_CLI} not supported"
    fi

    # Don't remove the generated artifacts -- note, the ledgers are always removed
    if [ "$MODE" != "restart" ]; then
        # Bring down the network, deleting the volumes
        ${CONTAINER_CLI} volume rm docker_orderer.example.com docker_peer0.org1.example.com docker_peer0.org2.example.com 2>/dev/null || true
        #Cleanup the chaincode containers
        clearContainers
        #Cleanup images
        removeUnwantedImages
        #
        ${CONTAINER_CLI} kill $(${CONTAINER_CLI} ps -q --filter name=ccaas) 2>/dev/null || true
        # remove orderer block and other channel configuration transactions and certs
        ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations' 2>/dev/null || true
        ## remove fabric ca artifacts
        ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/org1/msp organizations/fabric-ca/org1/tls-cert.pem organizations/fabric-ca/org1/ca-cert.pem organizations/fabric-ca/org1/IssuerPublicKey organizations/fabric-ca/org1/IssuerRevocationPublicKey organizations/fabric-ca/org1/fabric-ca-server.db' 2>/dev/null || true
        ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/org2/msp organizations/fabric-ca/org2/tls-cert.pem organizations/fabric-ca/org2/ca-cert.pem organizations/fabric-ca/org2/IssuerPublicKey organizations/fabric-ca/org2/IssuerRevocationPublicKey organizations/fabric-ca/org2/fabric-ca-server.db' 2>/dev/null || true
        ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/ordererOrg/msp organizations/fabric-ca/ordererOrg/tls-cert.pem organizations/fabric-ca/ordererOrg/ca-cert.pem organizations/fabric-ca/ordererOrg/IssuerPublicKey organizations/fabric-ca/ordererOrg/IssuerRevocationPublicKey organizations/fabric-ca/ordererOrg/fabric-ca-server.db' 2>/dev/null || true
        # remove channel and script artifacts
        ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz' 2>/dev/null || true
    fi
    
    infoln "Network stopped"
}

# Restart the network
function networkRestart() {
    infoln "Restarting Hyperledger Fabric network..."
    networkDown
    sleep 2
    networkUp
}

# Setup complete network (up + channel + chaincode)
function setupNetwork() {
    infoln "Setting up complete SeedShare network..."
    checkPrereqs
    networkUp
    createChannel
    deployChaincode
    infoln "SeedShare network setup completed successfully!"
}

# Run SeedShare demo transactions
function runDemo() {
    infoln "Running SeedShare demo transactions..."
    
    # Create new Farmer
    infoln "Creating new farmer..."
    invokeChaincode "requestNewFarmer" "\"Kiran\",\"kiran.r@presidio.com\",\"1234567890\",\"123456789012\""
    
    sleep 2
    
    # Approve New Farmer
    infoln "Approving new farmer..."
    invokeChaincode "approveNewFarmer" "\"Kiran\",\"123456789012\""
    
    sleep 2
    
    # View Farmer
    infoln "Viewing farmer details..."
    queryChaincode "viewFarmer" "\"Kiran\",\"123456789012\""
    
    sleep 2
    
    # Recharge Account
    infoln "Recharging farmer account..."
    invokeChaincode "rechargeAccount" "\"Kiran\",\"123456789012\",\"500\",\"ssh500\""
    
    sleep 2
    
    # Property Registration Request
    infoln "Requesting property registration..."
    invokeChaincode "propertyRegistrationRequest" "\"101\",\"Kiran\",\"1000\",\"Registered\",\"Kiran\",\"123456789012\""
    
    sleep 2
    
    # Property Approval
    infoln "Approving property registration..."
    invokeChaincode "approvePropertyRegistration" "\"101\",\"Kiran\""
    
    sleep 2
    
    # View Property
    infoln "Viewing property details..."
    queryChaincode "viewProperty" "\"101\",\"Kiran\""
    
    sleep 2
    
    # Update Property
    infoln "Updating property status..."
    invokeChaincode "updateProperty" "\"101\",\"Kiran\",\"123456789012\",\"onSale\""
    
    sleep 2
    
    # Purchase Property
    infoln "Purchasing property..."
    invokeChaincode "purchaseProperty" "\"101\",\"Kiran\",\"Apurva\",\"210987654321\""
    
    infoln "Demo transactions completed!"
}

# Print help
function printHelp() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  up              - Start the Fabric network"
    echo "  down            - Stop the Fabric network"
    echo "  restart         - Restart the Fabric network"
    echo "  createChannel   - Create the application channel"
    echo "  deployCC        - Deploy the SeedShare chaincode"
    echo "  setup           - Complete network setup (up + channel + chaincode)"
    echo "  demo            - Run SeedShare demo transactions"
    echo "  invoke <func>   - Invoke a chaincode function"
    echo "  query <func>    - Query a chaincode function"
    echo ""
    echo "Options:"
    echo "  -c <channel>    - Channel name (default: mychannel)"
    echo "  -ccn <name>     - Chaincode name (default: SeedshareNetwork)"
    echo "  -ccv <version>  - Chaincode version (default: 1)"
    echo "  -ccs <sequence> - Chaincode sequence (default: 1)"
    echo "  -ccl <language> - Chaincode language (default: javascript)"
    echo "  -ccp <path>     - Chaincode path (default: ./chaincode)"
    echo "  -ca             - Use Certificate Authorities instead of cryptogen"
    echo "  -s <database>   - Database type: leveldb or couchdb (default: leveldb)"
    echo "  -r <retries>    - Max retry attempts (default: 5)"
    echo "  -d <delay>      - CLI delay in seconds (default: 3)"
    echo "  -verbose        - Enable verbose output"
    echo "  -h              - Print this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup                                    # Setup complete network"
    echo "  $0 demo                                     # Run demo transactions"
    echo "  $0 up -s couchdb                           # Start network with CouchDB"
    echo "  $0 createChannel -c mychannel              # Create specific channel"
    echo "  $0 deployCC -ccn MyContract -ccv 2.0       # Deploy chaincode with version"
    echo "  $0 invoke requestNewFarmer \"Kiran\",\"email\",\"phone\",\"aadhar\""
    echo "  $0 query viewFarmer \"Kiran\",\"123456789012\""
}

# Parse command line arguments
if [[ $# -lt 1 ]] ; then
    printHelp
    exit 0
else
    MODE=$1
    shift
fi

# parse a createChannel subcommand if used
if [[ $# -ge 1 ]] ; then
    key="$1"
    if [[ "$key" == "createChannel" ]]; then
        export MODE="createChannel"
        shift
    fi
fi

# parse flags
while [[ $# -ge 1 ]] ; do
    key="$1"
    case $key in
    -h )
        printHelp $MODE
        exit 0
        ;;
    -c )
        CHANNEL_NAME="$2"
        shift
        ;;
    -ca )
        CRYPTO="Certificate Authorities"
        ;;
    -r )
        MAX_RETRY="$2"
        shift
        ;;
    -d )
        CLI_DELAY="$2"
        shift
        ;;
    -s )
        DATABASE="$2"
        shift
        ;;
    -ccl )
        CC_SRC_LANGUAGE="$2"
        shift
        ;;
    -ccn )
        CC_NAME="$2"
        shift
        ;;
    -ccv )
        CC_VERSION="$2"
        shift
        ;;
    -ccs )
        CC_SEQUENCE="$2"
        shift
        ;;
    -ccp )
        CC_SRC_PATH="$2"
        shift
        ;;
    -ccep )
        CC_END_POLICY="$2"
        shift
        ;;
    -cccg )
        CC_COLL_CONFIG="$2"
        shift
        ;;
    -cci )
        CC_INIT_FCN="$2"
        shift
        ;;
    -verbose )
        VERBOSE=true
        ;;
    * )
        errorln "Unknown flag: $key"
        printHelp
        exit 1
        ;;
    esac
    shift
done

# Are we generating crypto material with this command?
if [ ! -d "organizations/peerOrganizations" ]; then
    CRYPTO_MODE="with crypto from '${CRYPTO}'"
else
    CRYPTO_MODE=""
fi

# Determine mode of operation and printing out what we asked for
if [ "$MODE" == "up" ]; then
    infoln "Starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}' ${CRYPTO_MODE}"
    networkUp
elif [ "$MODE" == "createChannel" ]; then
    infoln "Creating channel '${CHANNEL_NAME}'."
    infoln "If network is not up, starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}' ${CRYPTO_MODE}"
    createChannel
elif [ "$MODE" == "down" ]; then
    infoln "Stopping network"
    networkDown
elif [ "$MODE" == "restart" ]; then
    infoln "Restarting network"
    networkDown
    networkUp
elif [ "$MODE" == "deployCC" ]; then
    infoln "deploying chaincode on channel '${CHANNEL_NAME}'"
    deployChaincode
elif [ "$MODE" == "setup" ]; then
    setupNetwork
elif [ "$MODE" == "demo" ]; then
    runDemo
elif [ "$MODE" == "invoke" ]; then
    if [ -z "$1" ]; then
        errorln "Function name required for invoke command"
        printHelp
        exit 1
    fi
    invokeChaincode "$1" "$2"
elif [ "$MODE" == "query" ]; then
    if [ -z "$1" ]; then
        errorln "Function name required for query command"
        printHelp
        exit 1
    fi
    queryChaincode "$1" "$2"
else
    printHelp
    exit 1
fi
