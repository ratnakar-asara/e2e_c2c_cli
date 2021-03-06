#!/bin/bash

CHANNEL_NAME=$1
if [ -z "$1" ]; then
	echo "Setting channel to default name 'mychannel'"
	CHANNEL_NAME="mychannel"
fi

echo "Channel name - "$CHANNEL_NAME
echo

#Backup the original configtx.yaml
cp ../../common/configtx/tool/configtx.yaml ../../common/configtx/tool/configtx.yaml.orig
cp configtx.yaml ../../common/configtx/tool/configtx.yaml

cd $PWD/../../
echo "Building configtxgen"
make configtxgen

echo "Generating genesis block"
./build/bin/configtxgen -profile TwoOrgs -outputBlock orderer.block
mv orderer.block examples/e2e/crypto/orderer/orderer.block

echo "Generating channel configuration transaction"
./build/bin/configtxgen -profile TwoOrgs -outputCreateChannelTx channel1.tx -channelID "$CHANNEL_NAME""1"
./build/bin/configtxgen -profile TwoOrgs -outputCreateChannelTx channel2.tx -channelID "$CHANNEL_NAME""2"
mv channel1.tx examples/e2e/crypto/orderer/
mv channel2.tx examples/e2e/crypto/orderer/

#reset configtx.yaml file to its original
cp common/configtx/tool/configtx.yaml.orig common/configtx/tool/configtx.yaml
rm common/configtx/tool/configtx.yaml.orig
