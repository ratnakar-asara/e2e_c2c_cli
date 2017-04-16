#!/bin/bash

CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="40"}
COUNTER=0
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/localMspConfig/cacerts/ordererOrg0.pem

echo "Channel name : "$CHANNEL_NAME

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
   		exit 1
	fi
}

setGlobals () {

	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peer/peer$1/localMspConfig
	CORE_PEER_ADDRESS=peer$1:7051

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org0MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peer/peer$1/localMspConfig/cacerts/peerOrg0.pem
	else
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peer/peer$1/localMspConfig/cacerts/peerOrg1.pem
	fi
	env |grep CORE
}

disableGossip() {
	for counter in 0 1 2 3 ; do
		setGlobals $counter
		peer logging setlevel gossip/comm#-1 error
		peer logging setlevel cauthdsl error
		peer logging setlevel peer/gossip/mcs error
		peer logging setlevel gossip/discovery#peer0:7051 error
		peer logging setlevel gossip/pull#peer0:7051 error
		peer logging setlevel gossip/gossip#peer0:7051 error
		peer logging setlevel gossip/election error
		peer logging setlevel common/policies error
	done
}

createChannel() {
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/localMspConfig
	CORE_PEER_LOCALMSPID="OrdererMSP"

	for counter in 1 2; do
        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer0:7050 -c $CHANNEL_NAME$counter -f crypto/orderer/channel$counter.tx >&log.txt
	else
		peer channel create -o orderer0:7050 -c $CHANNEL_NAME$counter -f crypto/orderer/channel$counter.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME$counter\" is created successfully ===================== "
	echo
	done
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME$2.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1
	else
		COUNTER=0
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$1 has failed to Join the Channel $CHANNEL_NAME$2"
}

joinChannel () {
	for counter in 1 2; do
	for ch in 0 1 2 3; do
		setGlobals $ch
		joinWithRetry $ch $counter
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME$counter\" ===================== "
		sleep 2
		echo
	done
	done
}

installChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02 >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode example02 installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode example02 is installed on remote peer PEER$PEER ===================== "
	echo
	peer chaincode install -n mycc05 -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example05 >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode example05 installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode example05 is installed on remote peer PEER$PEER ===================== "
	echo

}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	for counter in 1 2; do
        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer0:7050 -C $CHANNEL_NAME$counter -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('Org0MSP.member','Org1MSP.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer0:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$counter -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('Org0MSP.member','Org1MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME$counter' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME$counter' is successful ===================== "
	echo

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer0:7050 -C $CHANNEL_NAME$counter -n mycc05 -v 1.0 -c '{"Args":["init","sum","0"]}' -P "OR	('Org0MSP.member','Org1MSP.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer0:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$counter -n mycc05 -v 1.0 -c '{"Args":["init","sum","0"]}' -P "OR	('Org0MSP.member','Org1MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME$counter' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME$counter' is successful ===================== "
	echo
	done
}

chaincodeQuery () {
  PEER=$1
  for counter in 1 2; do 
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME$counter'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME$counter -n mycc -c '{"Args":["get","a"]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$2" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME$counter' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	exit 1
  fi
  done
}

chaincodeInvoke () {
        PEER=$1
  for counter in 1 2; do 
        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer0:7050 -C $CHANNEL_NAME$counter -n mycc -c '{"Args":["put","a","1234567890abcdefghijklmnopqrstuvwxyz"]}' >&log.txt
	else
		peer chaincode invoke -o orderer0:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$counter -n mycc -c '{"Args":["put","a","1234567890abcdefghijklmnopqrstuvwxyz"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME$counter' is successful ===================== "
	echo

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer0:7050 -C $CHANNEL_NAME$counter -n mycc -c '{"Args":["put","b","ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"]}' >&log.txt
	else
		peer chaincode invoke -o orderer0:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$counter -n mycc -c '{"Args":["put","b","ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME$counter' is successful ===================== "
	echo
 done
}

chaincode05Query () {
  PEER=$1
  setGlobals $PEER
  for counter in 1 2; do 
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME$counter'... ===================== "
  
  local rc=1
  #local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  #while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  #do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     if test $counter -eq 1 ; then
	peer chaincode query -C $CHANNEL_NAME$counter -n mycc05 -c '{"Args":["get","mycc","mychannel2"]}' >&log.txt
     else
	peer chaincode query -C $CHANNEL_NAME$counter -n mycc05 -c '{"Args":["get","mycc","mychannel1"]}' >&log.txt 
     fi
     rc=$?
     #test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     #test "$VALUE" = "$2" && let rc=0
  #done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME$counter' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	exit 1
	echo
  fi
  done
}

chaincode05Invoke () {
        PEER=$1
  for counter in 1 2; do
  if test $counter -eq 1 ; then
        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer0:7050 -C $CHANNEL_NAME$counter -n mycc05 -c '{"Args":["put","mycc","!@#$%^&*()_+~!@#^(*&&^%$^%$%*^%$%#%&^","mychannel2"]}' >&log.txt
	else
		peer chaincode invoke -o orderer0:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$counter -n mycc05 -c '{"Args":["put","mycc","!@#$%^&*()_+~!@#^(*&&^%$^%$%*^%$%#%&^","mychannel2"]}' >&log.txt
	fi
  else 
        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer0:7050 -C $CHANNEL_NAME$counter -n mycc05 -c '{"Args":["put","mycc","!@#$%^&*()_+~!@#^(*&&^%$^%$%*^%$%#%&^","mychannel1"]}' >&log.txt
	else
		peer chaincode invoke -o orderer0:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$counter -n mycc05 -c '{"Args":["put","mycc","!@#$%^&*()_+~!@#^(*&&^%$^%$%*^%$%#%&^","mychannel1"]}' >&log.txt
	fi
  fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME$counter' is successful ===================== "
	echo
 done
}

disableGossip
## Create channel
createChannel

## Join all the peers to the channel
joinChannel


## Install chaincode on Peer0/Org0 and Peer2/Org1
installChaincode 0
installChaincode 1
installChaincode 2
installChaincode 3

#Instantiate chaincode on Peer2/Org1
echo "Instantiating chaincode on Peer2/Org1 ..."
instantiateChaincode 2

sleep 20

#Invoke on chaincode on Peer0/Org0
echo "send Invoke transaction on Peer0/Org0 ..."
chaincodeInvoke 0

#Query on chaincode on Peer0/Org0
chaincodeQuery 1 "1234567890abcdefghijklmnopqrstuvwxyz" "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

## Install chaincode on Peer3/Org1
#installChaincode 3

#Query on chaincode on Peer3/Org1, check if the result is 90
#chaincodeQuery 3 "1234567890abcdefghijklmnopqrstuvwxyz"


chaincode05Invoke 0
chaincode05Query 3

echo
echo "===================== All GOOD, End-2-End execution completed ===================== "
echo
exit 0
