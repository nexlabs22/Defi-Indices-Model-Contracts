// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../contracts/test/TestFunctionsOracle.sol";

/**

  TestFunctionsOracle implementation deployed at: 0x8fC8b8BE20caD44baf1dd729AF1499Cd043062e3
  testFunctionsOracle proxy deployed at: 0x9cFf7a27C616d062796729bcfb223b8461475243
  ProxyAdmin for TestFunctionsOracle deployed at: 0xB399d7acf932D41996bA616d290620af3563b3dE

forge script scripts/foundry/test/deployTestFunctionsOracle.s.sol --rpc-url $ARBITRUM_RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ARBISCAN_API_KEY --broadcast
 */

contract DeployTestFunctionsOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

       
        address functionsRouterAddress = 0x97083E831F8F0638855e2A515c90EdCF158DF238;
        bytes32 newDonId = 0x66756e2d617262697472756d2d6d61696e6e65742d3100000000000000000000;
      

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        TestFunctionsOracle testFunctionsOracle = new TestFunctionsOracle();

        bytes memory data = abi.encodeWithSignature(
            "initialize(address,bytes32)",
            functionsRouterAddress,
            newDonId
        );

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(testFunctionsOracle), address(proxyAdmin), data);

        console.log("TestFunctionsOracle implementation deployed at:", address(testFunctionsOracle));
        console.log("testFunctionsOracle proxy deployed at:", address(proxy));
        console.log("ProxyAdmin for TestFunctionsOracle deployed at:", address(proxyAdmin));

        vm.stopBroadcast();
    }
}
