# Getting Started

commands to run

curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh

./network.sh up

./network.sh createChannel

./network.sh deployCC -ccn SeedshareNetwork -ccl javascript -ccp ../chaincode -ccv 1 -ccs 1 -cci instantiate
