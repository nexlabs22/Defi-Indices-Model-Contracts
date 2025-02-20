// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {IndexFactoryBalancer} from "../../../contracts/factory/IndexFactoryBalancer.sol";
import {IndexFactory} from "../../../contracts/factory/IndexFactory.sol";

contract SetFactoryStorage is Script {
    // Mainnet
    address indexFactoryProxy = vm.envAddress("ARBITRUM_INDEX_FACTORY_PROXY_ADDRESS");
    address indexFactoryBalancerProxy = vm.envAddress("ARBITRUM_INDEX_FACTORY_BALANCER_PROXY_ADDRESS");
    address indexFactoryStorageProxy = vm.envAddress("ARBITRUM_INDEX_FACTORY_STORAGE_PROXY_ADDRESS");

    // Testnet
    // address indexFactoryProxy = vm.envAddress("SEPOLIA_INDEX_FACTORY_PROXY_ADDRESS");
    // address indexFactoryBalancerProxy = vm.envAddress("SEPOLIA_INDEX_FACTORY_BALANCER_PROXY_ADDRESS");
    // address indexFactoryStorageProxy = vm.envAddress("SEPOLIA_INDEX_FACTORY_STORAGE_PROXY_ADDRESS");

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IndexFactoryBalancer(payable(indexFactoryBalancerProxy)).setFactoryStorage(indexFactoryStorageProxy);
        IndexFactory(payable(indexFactoryProxy)).setFactoryStorage(indexFactoryStorageProxy);

        vm.stopBroadcast();

        console.log("Values set successfully.");
    }
}
