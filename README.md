How to run Sample chaincode example05 calling example02


* clone fabric code
```
git clone https://github.com/hyperledger/fabric.git
```

* Build binaries and docker-images

```
make native docker
```

* clone this repo to run the test

```
cd fabric/examples
git clone https://github.com/ratnakar-asara/e2e_c2c_cli e2e
cd e2e
```


* Run the script

```
 ./network_setup.sh restart
```
