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

        // Testnet Mocks
        // fillMockAssetsListTestnet();

        vm.stopBroadcast();

        console.log("Values set successfully.");
    }

    function _getAssetList() internal pure returns (address[] memory) {
        address[] memory assetList = new address[](12);

        assetList[0] = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB
        assetList[1] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX
        assetList[2] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0; // UNI
        assetList[3] = 0x6694340fc020c5E6B96567843da2df01b2CE1eb6; // STG
        assetList[4] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8; // PENDLE
        assetList[5] = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978; // CRV
        assetList[6] = 0x18c11FD286C5EC11c3b683Caa813B77f5163A122; // GNS
        assetList[7] = 0x431402e8b9dE9aa016C743880e04E517074D8cEC; // HEGIC
        assetList[8] = 0x4e352cF164E64ADCBad318C3a1e222E9EBa4Ce42; // MCB
        assetList[9] = 0x539bdE0d7Dbd336b79148AA742883198BBF60342; // MAGIC
        assetList[10] = 0xe4DDDfe67E7164b0FE14E218d80dC4C08eDC01cB; // KNC
        assetList[11] = 0x55fF62567f09906A85183b866dF84bf599a4bf70; // KROM

        return assetList;
    }

    function _getMarketShares() internal pure returns (uint256[] memory) {
        uint256[] memory marketShares = new uint256[](12);
        marketShares[0] = 15000000000000000000; // 0.15
        marketShares[1] = 31508163067860700000; // 0.314...
        marketShares[2] = 22905354555984900000; // ...
        marketShares[3] = 17946014206125500000;
        marketShares[4] = 5512132695857800000;
        marketShares[5] = 2995906609222520000;
        marketShares[6] = 1794713750408810000;
        marketShares[7] = 1332012784884490000;
        marketShares[8] = 999775130045156000;
        marketShares[9] = 3371988279450500;
        marketShares[10] = 2314361668820400;
        marketShares[11] = 240849661853100; // KROM

        return marketShares;
    }

    function _getPathData() internal pure returns (bytes[] memory) {
        address wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address usdcAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        address arbAddress = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB
        address gmxAddress = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX
        address uniAddress = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0; // UNI
        address stgAddress = 0x6694340fc020c5E6B96567843da2df01b2CE1eb6; // STG
        address pendleAddr = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8; // PENDLE
        address crvAddress = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978; // CRV
        address gnsAddress = 0x18c11FD286C5EC11c3b683Caa813B77f5163A122; // GNS
        address hegicAddr = 0x431402e8b9dE9aa016C743880e04E517074D8cEC; // HEGIC
        address mcbAddress = 0x4e352cF164E64ADCBad318C3a1e222E9EBa4Ce42; // MCB
        address magicAddr = 0x539bdE0d7Dbd336b79148AA742883198BBF60342; // MAGIC
        address kncAddress = 0xe4DDDfe67E7164b0FE14E218d80dC4C08eDC01cB; // KNC
        address kromAddress = 0x55fF62567f09906A85183b866dF84bf599a4bf70; // KROM

        bytes[] memory pathData = new bytes[](12);
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = arbAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 500;
            pathData[0] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = gmxAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[1] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = uniAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[2] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = stgAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[3] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = pendleAddr;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 500;
            pathData[4] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = crvAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[5] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = gnsAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[6] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = hegicAddr;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 500;
            pathData[7] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](3);
            path[0] = wethAddress;
            path[1] = usdcAddress;
            path[2] = mcbAddress;
            uint24[] memory fees = new uint24[](2);
            fees[0] = 100;
            fees[1] = 3000;
            pathData[8] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = magicAddr;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[9] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = kncAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[10] = abi.encode(path, fees);
        }
        {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = kromAddress;
            uint24[] memory fees = new uint24[](1);
            fees[0] = 3000;
            pathData[11] = abi.encode(path, fees);
        }

        return pathData;
    }

    function fillMockAssetsListMainnet() internal {
        address[] memory assetList = _getAssetList();
        uint256[] memory marketShares = _getMarketShares();
        bytes[] memory pathData = _getPathData();

        uint256 totalShares = 0;

        for (uint256 i = 0; i < marketShares.length; i++) {
            totalShares += marketShares[i];
        }

        console.log("Total shares: ", totalShares);
        console.log("Market shares length: ", marketShares.length);
        require(totalShares == 100e18, "Total marketShares must equal 100e18");

        IndexFactoryStorage(indexFactoryStorageProxy).mockFillAssetsList(assetList, pathData, marketShares);

        console.log("Called mockFillAssetsList() with your 12 assets data.");
    }

    // function fillMockAssetsListMainnet() internal {
    //     address wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    //     address[] memory assetList = new address[](5);
    //     assetList[0] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8; // PENDLE
    //     assetList[1] = 0x6694340fc020c5E6B96567843da2df01b2CE1eb6; // STARGATE
    //     assetList[2] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0; // UNISWAP
    //     assetList[3] = 0x354A6dA3fcde098F8389cad84b0182725c6C91dE; // COMPOUND
    //     assetList[4] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX

    //     uint256[] memory marketShares = new uint256[](5);
    //     marketShares[0] = 28000000000000000000; // 28
    //     marketShares[1] = 23000000000000000000; // 23
    //     marketShares[2] = 18000000000000000000; // 18
    //     marketShares[3] = 18000000000000000000; // 18
    //     marketShares[4] = 13000000000000000000; // 13

    //     uint24[] memory feesData = new uint24[](1);
    //     feesData[0] = 3000;

    //     bytes[] memory pathData = new bytes[](5);
    //     for (uint256 i = 0; i < 5; i++) {
    //         address[] memory path = new address[](2);
    //         path[0] = wethAddress;
    //         path[1] = assetList[i];
    //         pathData[i] = abi.encode(path, feesData);
    //     }

    //     IndexFactoryStorage(indexFactoryStorageProxy).mockFillAssetsList(assetList, pathData, marketShares);

    //     console.log("Called mockFillAssetsList() with your 5 assets data.");
    // }

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
