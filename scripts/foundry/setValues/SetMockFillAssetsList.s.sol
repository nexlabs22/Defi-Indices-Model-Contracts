// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {IndexFactoryStorage} from "../../../contracts/factory/IndexFactoryStorage.sol";

contract SetMockFillAssetsList is Script {
    // Mainnet
    address indexFactoryStorageProxy = vm.envAddress("ARBITRUM_INDEX_FACTORY_STORAGE_PROXY_ADDRESS");

    // Testnet
    // address indexFactoryStorageProxy = vm.envAddress("SEPOLIA_INDEX_FACTORY_STORAGE_PROXY_ADDRESS");

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Mainnet Mock
        fillMockAssetsListMainnet();

        // Testnet Mock
        // fillMockAssetsListTestnet();

        vm.stopBroadcast();

        console.log("Values set successfully.");
    }

    function fillMockAssetsListMainnet() internal {
        address wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        address[] memory assetList = new address[](5);
        assetList[0] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8; // PENDLE
        assetList[1] = 0x6694340fc020c5E6B96567843da2df01b2CE1eb6; // STARGATE
        assetList[2] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0; // UNISWAP
        assetList[3] = 0x354A6dA3fcde098F8389cad84b0182725c6C91dE; // COMPOUND
        assetList[4] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX

        uint256[] memory marketShares = new uint256[](5);
        marketShares[0] = 28000000000000000000; // 28
        marketShares[1] = 23000000000000000000; // 23
        marketShares[2] = 18000000000000000000; // 18
        marketShares[3] = 18000000000000000000; // 18
        marketShares[4] = 13000000000000000000; // 13

        uint24[] memory feesData = new uint24[](1);
        feesData[0] = 3000;

        bytes[] memory pathData = new bytes[](5);
        for (uint256 i = 0; i < 5; i++) {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = assetList[i];
            pathData[i] = abi.encode(path, feesData);
        }

        IndexFactoryStorage(indexFactoryStorageProxy).mockFillAssetsList(assetList, pathData, marketShares);

        console.log("Called mockFillAssetsList() with your 5 assets data.");
    }

    // function fillMockAssetsListTestnet() internal {
    //     address[] memory assetList = new address[](11);
    //     assetList[0] = 0x9CD4f9Bec89e00A560840174Dc8054Fb4b3e1858; // sepoliaTestArbitrumAddress
    //     assetList[1] = 0x8B0D01137979e409Bba15098aA5665c647774003; // sepoliaTestAAVEAddress
    //     assetList[2] = 0xC361Ce0885FaA9F6F5f41F2b2A08E72E465DFbc6; // sepoliaTestCLIPPERAddress
    //     assetList[3] = 0xCAC218f00e79A6923228487C52dcba71666C6b17; // sepoliaTestPENDLEAddress
    //     assetList[4] = 0x861b6Db57c71F9E5B989a18d4C6f600b7b26E170; // sepoliaTestSILOAddress
    //     assetList[5] = 0xe4e401c5a31d43550D9218CCf412A761e5441F39; // sepoliaTestCAKEAddress
    //     assetList[6] = 0xdc29d1B632F84b64f9b2742D1CD305D11f9Db76A; // sepoliaTestDODOAddress
    //     assetList[7] = 0x7844288a55B09Af610200C738e9714A3B55eEA34; // sepoliaTestSALEAddress
    //     assetList[8] = 0x46F7bA9B4bfA0F7179a01Bf42143E78e65fD7904; // sepoliaTestPNPAddress
    //     assetList[9] = 0x2A0FDA08272292883187019773F5c655cc7804FF; // sepoliaTestCVXAddress
    //     assetList[10] = 0x6AeFff05e69Df302e4fe508778C23996A53B440f; // sepoliaTestJOEAddress

    //     uint256[] memory marketShares = new uint256[](11);
    //     marketShares[0] = 15000000000000000000; // 15e18
    //     marketShares[1] = 12500000000000000000; // 12.5e18
    //     marketShares[2] = 12500000000000000000;
    //     marketShares[3] = 9375000000000000000; // 9.375e18
    //     marketShares[4] = 9375000000000000000;
    //     marketShares[5] = 7500000000000000000; // 7.5e18
    //     marketShares[6] = 7500000000000000000;
    //     marketShares[7] = 7500000000000000000;
    //     marketShares[8] = 6250000000000000000; // 6.25e18
    //     marketShares[9] = 6250000000000000000;
    //     marketShares[10] = 6250000000000000000;

    //     uint24[] memory feesData = new uint24[](1);
    //     feesData[0] = 3000;

    //     bytes[] memory pathData = new bytes[](11);
    //     for (uint256 i = 0; i < 11; i++) {
    //         address[] memory path = new address[](2);
    //         path[0] = wethAddress;
    //         path[1] = assetList[i];
    //         pathData[i] = abi.encode(path, feesData);
    //     }

    //     IndexFactoryStorage(indexFactoryStorageProxy).mockFillAssetsList(
    //         assetList, pathData, marketShares
    //     );

    //     console.log("Called mockFillAssetsList() with your 11 assets data.");
    // }
}
