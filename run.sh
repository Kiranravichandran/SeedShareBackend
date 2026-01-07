#!/bin/bash

# Set environment variables
export PATH=${PWD}/bin:$PATH
export FABRIC_CFG_PATH=$PWD/config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_ADDRESS=localhost:7051
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_LOCALMSPID="Org1MSP"
export FABRIC_NODEENV_VERSION=2.5
export FABRIC_CCENV_VERSION=2.5
export CORE_CHAINCODE_BUILDER=hyperledger/fabric-ccenv:2.5
export CORE_CHAINCODE_NODE_RUNTIME=hyperledger/fabric-nodeenv:2.5

echo "Starting SeedShare Hyperledger Fabric Network..."

# Stop any existing network
echo "Stopping existing network..."
./network.sh down

# Start the network
echo "Starting network..."
./network.sh up createChannel

# Deploy chaincode
echo "Deploying chaincode..."
./network.sh deployCC -ccn SeedshareNetwork -ccl javascript -ccp ./chaincode -ccv 5 -ccs 1 -cci NA

echo "Network setup complete! Running demo transactions..."

# Fixed certificate paths
ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
ORG1_TLS_ROOTCERT=${PWD}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
ORG2_TLS_ROOTCERT=${PWD}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem

echo "Chaincode deployed and initialized successfully! Running demo transactions..."

# Create new Farmer
echo "Creating new farmer..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"requestNewFarmer","Args":["Kiran","kiran.r@presidio.com","1234567890","123456789012"]}'

# Approve New Farmer
echo "Approving new farmer..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"approveNewFarmer","Args":["Kiran","123456789012"]}'

# View Farmer
echo "Viewing farmer details..."
peer chaincode query -C mychannel -n SeedshareNetwork -c '{"function":"viewFarmer","Args":["Kiran","123456789012"]}'

# Recharge Account
echo "Recharging farmer account..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"rechargeAccount","Args":["Kiran","123456789012","500","ssh500"]}'

# Property Registration Request
echo "Requesting property registration..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"propertyRegistrationRequest","Args":["101","Kiran","1000","Registered", "Kiran","123456789012"]}'

# Property Approval
echo "Approving property registration..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"approvePropertyRegistration","Args":["101","Kiran"]}'

# View Property
echo "Viewing property details..."
peer chaincode query -C mychannel -n SeedshareNetwork -c '{"function":"viewProperty","Args":["101","Kiran"]}'

# Update Property
echo "Updating property status..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"updateProperty","Args":["101","Kiran","123456789012","onSale"]}'

# Create buyer farmer
echo "Creating buyer farmer..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"requestNewFarmer","Args":["Apurva","apurva@presidio.com","9876543210","210987654321"]}'

# Approve buyer farmer
echo "Approving buyer farmer..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"approveNewFarmer","Args":["Apurva","210987654321"]}'

# Recharge buyer account
echo "Recharging buyer account..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"rechargeAccount","Args":["Apurva","210987654321","1500","ssh1000"]}'

# Purchase Property
echo "Purchasing property..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls true --cafile $ORDERER_CA -C mychannel -n SeedshareNetwork --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS_ROOTCERT --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS_ROOTCERT -c '{"function":"purchaseProperty","Args":["101","Kiran","Apurva","210987654321"]}'

# View updated property with new owner
echo "Viewing property after purchase..."
peer chaincode query -C mychannel -n SeedshareNetwork -c '{"function":"viewProperty","Args":["101","Apurva"]}'

# View buyer's updated balance
echo "Viewing buyer's updated balance..."
peer chaincode query -C mychannel -n SeedshareNetwork -c '{"function":"viewFarmer","Args":["Apurva","210987654321"]}'

echo "Demo transactions completed!"
