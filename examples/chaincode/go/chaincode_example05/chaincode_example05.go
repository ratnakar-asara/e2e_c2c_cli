/*
Copyright IBM Corp. 2016 All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

		 http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"fmt"

	"github.com/hyperledger/fabric/common/util"
	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

// This chaincode is a test for chaincode querying another chaincode - invokes chaincode_example02 and computes the sum of a and b and stores it as state

// SimpleChaincode example simple Chaincode implementation
type SimpleChaincode struct {
}

// Init takes two arguments, a string and int. The string will be a key with
// the int as a value.
func (t *SimpleChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Printf("\n============ Chaincode 2 INIT ================")
	return shim.Success(nil)
}

// Invoke queries another chaincode and updates its own state
func (t *SimpleChaincode) invoke(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	fmt.Printf("================ Invoke on chaincode 05\n")
	if len(args) != 3 {
		return shim.Error("Incorrect number of arguments. Expecting 3")
	}

	chaincodeURL := args[0]
	val1 := args[1]
	val2 := args[1]
        channelName :=  args[2]
	fmt.Printf("Channel Name is %s\n", channelName)

	// Invoke on chaincode_example02
	f := "put"
	invokeArgs := util.ToChaincodeArgs(f, "a", val1)
	response := stub.InvokeChaincode(chaincodeURL, invokeArgs, channelName)
	if response.Status != shim.OK {
		errStr := fmt.Sprintf("Failed to query chaincode. Got error: %s", response.Payload)
		fmt.Printf(errStr)
		return shim.Error(errStr)
	}
	fmt.Printf("Invoke response %s\n", string(response.Payload))

	invokeArgs = util.ToChaincodeArgs(f, "b", val2)
	response = stub.InvokeChaincode(chaincodeURL, invokeArgs, channelName)
	if response.Status != shim.OK {
		errStr := fmt.Sprintf("Failed to query chaincode. Got error: %s", response.Payload)
		fmt.Printf(errStr)
		return shim.Error(errStr)
	}
	fmt.Printf("Invoke response %s\n", string(response.Payload))
	return shim.Success([]byte("OK"))
}

func (t *SimpleChaincode) query(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	fmt.Printf("================ Query on chaincode 05\n")
	if len(args) != 2 {
		return shim.Error("Incorrect number of arguments. Expecting 2")
	}

	chaincodeURL := args[0]
        channelName :=  args[1]
	fmt.Printf("Channel Name is %s\n", channelName)

	// Query chaincode_example02
	f := "get"
	queryArgs := util.ToChaincodeArgs(f, "a")
	response := stub.InvokeChaincode(chaincodeURL, queryArgs, channelName)
	if response.Status != shim.OK {
		errStr := fmt.Sprintf("Failed to query chaincode. Got error: %s", response.Payload)
		fmt.Printf(errStr)
		return shim.Error(errStr)
	}
        val1 := string(response.Payload)
	fmt.Printf(val1)

	queryArgs = util.ToChaincodeArgs(f, "b")
	response = stub.InvokeChaincode(chaincodeURL, queryArgs, channelName)
	if response.Status != shim.OK {
		errStr := fmt.Sprintf("Failed to query chaincode. Got error: %s", response.Payload)
		fmt.Printf(errStr)
		return shim.Error(errStr)
	}
        val2 := string(response.Payload)
	fmt.Printf(val2)

	fmt.Printf("Query chaincode successful. \n")
	jsonResp := "{\"Val1\":\"" + val1 + "\",\"Val2\":\"" + val2 + "\"}"
	fmt.Printf("Query Response:%s\n", jsonResp)
	return shim.Success([]byte(jsonResp))
}

func (t *SimpleChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	function, args := stub.GetFunctionAndParameters()
	if function == "invoke" {
		return t.invoke(stub, args)
	} else if function == "query" {
		return t.query(stub, args)
	}

	return shim.Success([]byte("Invalid invoke function name. Expecting \"invoke\" \"query\""))
}

func main() {
	err := shim.Start(new(SimpleChaincode))
	if err != nil {
		fmt.Printf("Error starting Simple chaincode: %s", err)
	}
}
