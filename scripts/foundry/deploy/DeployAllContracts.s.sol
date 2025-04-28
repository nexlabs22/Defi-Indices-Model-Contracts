// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {IndexFactory} from "../../../contracts/factory/IndexFactory.sol";
import {IndexFactoryBalancer} from "../../../contracts/factory/IndexFactoryBalancer.sol";
import {IndexFactoryStorage} from "../../../contracts/factory/IndexFactoryStorage.sol";
import {IndexToken} from "../../../contracts/token/IndexToken.sol";
import {Vault} from "../../../contracts/vault/Vault.sol";
import {PriceOracleByteCode} from "../../../contracts/test/PriceOracleByteCode.sol";

/**
 * @dev This script organizes deployment steps into separate functions
 * to reduce local variable usage in a single function body.
 */
contract DeployAllContracts is Script, PriceOracleByteCode {
    uint256 internal deployerPrivateKey;
    address internal functionsRouterAddress;
    bytes32 internal newDonId;
    address internal toUsdPriceFeed;
    address internal wethAddress;
    address internal quoterAddress;
    address internal swapRouterV3;
    address internal factoryV3;
    address internal swapRouterV2;
    address internal factoryV2;

    string internal tokenName;
    string internal tokenSymbol;
    uint256 internal feeRatePerDayScaled;
    address internal feeReceiver;
    uint256 internal supplyCeiling;

    address internal indexTokenProxy;
    address internal indexFactoryStorageProxy;
    address internal indexFactoryProxy;
    address internal indexFactoryBalancerProxy;
    address internal priceOracle;
    address internal vaultProxy;

    IndexToken internal indexTokenImplementation;
    ProxyAdmin internal indexTokenProxyAdmin;

    IndexFactoryStorage internal indexFactoryStorageImplementation;
    ProxyAdmin internal indexFactoryStorageProxyAdmin;

    IndexFactory internal indexFactoryImplementation;
    ProxyAdmin internal indexFactoryProxyAdmin;

    IndexFactoryBalancer internal indexFactoryBalancerImplementation;
    ProxyAdmin internal indexFactoryBalancerProxyAdmin;

    Vault internal vaultImplementation;
    ProxyAdmin internal vaultProxyAdmin;

    function run() external {
        // 2.1 Load environment vars
        readEnvVars();

        // 2.2 Start broadcast
        vm.startBroadcast(deployerPrivateKey);

        // 2.3 Deploy everything step by step
        deployIndexToken();
        // deployIndexFactoryStorage();
        // deployIndexFactory();
        // deployIndexFactoryBalancer();
        // deployPriceOracle();
        // deployVault();

        // // 2.4 Set the necessary values after deployment
        // setProxyValues();

        // // Mainnet Mock
        // fillMockAssetsListMainnet();

        // Testnet Mock
        // fillMockAssetsListTestnet();

        // 2.5 End broadcast
        vm.stopBroadcast();
    }

    function readEnvVars() internal {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        functionsRouterAddress = vm.envAddress("ARBITRUM_FUNCTIONS_ROUTER_ADDRESS");
        newDonId = vm.envBytes32("ARBITRUM_NEW_DON_ID");
        toUsdPriceFeed = vm.envAddress("ARBITRUM_TO_USD_PRICE_FEED");
        wethAddress = vm.envAddress("ARBITRUM_WETH_ADDRESS");
        quoterAddress = vm.envAddress("ARBITRUM_QUOTER_ADDRESS");
        swapRouterV3 = vm.envAddress("ARBITRUM_ROUTER_V3_ADDRESS");
        factoryV3 = vm.envAddress("ARBITRUM_FACTORY_V3_ADDRESS");
        swapRouterV2 = vm.envAddress("ARBITRUM_ROUTER_V2_ADDRESS");
        factoryV2 = vm.envAddress("ARBITRUM_FACTORY_V2_ADDRESS");

        tokenName = "Arbitrum Ecosystem Index";
        tokenSymbol = "ARBEI";
        feeRatePerDayScaled = vm.envUint("ARBITRUM_FEE_RATE_PER_DAY_SCALED");
        feeReceiver = vm.envAddress("ARBITRUM_FEE_RECEIVER");
        supplyCeiling = vm.envUint("ARBITRUM_SUPPLY_CEILING");

        // functionsRouterAddress = vm.envAddress("SEPOLIA_FUNCTIONS_ROUTER_ADDRESS");
        // newDonId = vm.envBytes32("SEPOLIA_NEW_DON_ID");
        // toUsdPriceFeed = vm.envAddress("SEPOLIA_TO_USD_PRICE_FEED");
        // wethAddress = vm.envAddress("SEPOLIA_WETH_ADDRESS");
        // quoterAddress = vm.envAddress("SEPOLIA_QUOTER_ADDRESS");
        // swapRouterV3 = vm.envAddress("SEPOLIA_ROUTER_V3_ADDRESS");
        // factoryV3 = vm.envAddress("SEPOLIA_FACTORY_V3_ADDRESS");
        // swapRouterV2 = vm.envAddress("SEPOLIA_ROUTER_V2_ADDRESS");
        // factoryV2 = vm.envAddress("SEPOLIA_FACTORY_V2_ADDRESS");

        // tokenName = "Arbitrum Ecosystem Index";
        // tokenSymbol = "ARBEI";
        // feeRatePerDayScaled = vm.envUint("SEPOLIA_FEE_RATE_PER_DAY_SCALED");
        // feeReceiver = vm.envAddress("SEPOLIA_FEE_RECEIVER");
        // supplyCeiling = vm.envUint("SEPOLIA_SUPPLY_CEILING");
    }

    function deployIndexToken() internal {
        indexTokenProxyAdmin = new ProxyAdmin();
        indexTokenImplementation = new IndexToken();

        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,uint256,address,uint256)",
            tokenName,
            tokenSymbol,
            feeRatePerDayScaled,
            feeReceiver,
            supplyCeiling
        );

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(indexTokenImplementation), address(indexTokenProxyAdmin), initData);

        indexTokenProxy = address(proxy);

        console.log("///////// IndexToken //////////");
        console.log("IndexToken impl:", address(indexTokenImplementation));
        console.log("IndexToken proxy:", indexTokenProxy);
        console.log("IndexToken ProxyAdmin:", address(indexTokenProxyAdmin));
    }

    function deployIndexFactoryStorage() internal {
        indexFactoryStorageProxyAdmin = new ProxyAdmin();
        indexFactoryStorageImplementation = new IndexFactoryStorage();

        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,bytes32,address,address,address,address,address,address,address)",
            payable(indexTokenProxy),
            functionsRouterAddress,
            newDonId,
            toUsdPriceFeed,
            wethAddress,
            quoterAddress,
            swapRouterV3,
            factoryV3,
            swapRouterV2,
            factoryV2
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(indexFactoryStorageImplementation), address(indexFactoryStorageProxyAdmin), initData
        );

        indexFactoryStorageProxy = address(proxy);

        console.log("///////// IndexFactoryStorage //////////");
        console.log("IndexFactoryStorage impl:", address(indexFactoryStorageImplementation));
        console.log("IndexFactoryStorage proxy:", indexFactoryStorageProxy);
        console.log("IndexFactoryStorage ProxyAdmin:", address(indexFactoryStorageProxyAdmin));
    }

    function deployIndexFactory() internal {
        indexFactoryProxyAdmin = new ProxyAdmin();
        indexFactoryImplementation = new IndexFactory();

        bytes memory initData = abi.encodeWithSignature("initialize(address)", indexFactoryStorageProxy);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(indexFactoryImplementation), address(indexFactoryProxyAdmin), initData
        );

        indexFactoryProxy = address(proxy);

        console.log("///////// IndexFactory //////////");
        console.log("IndexFactory impl:", address(indexFactoryImplementation));
        console.log("IndexFactory proxy:", indexFactoryProxy);
        console.log("IndexFactory ProxyAdmin:", address(indexFactoryProxyAdmin));
    }

    function deployIndexFactoryBalancer() internal {
        indexFactoryBalancerProxyAdmin = new ProxyAdmin();
        indexFactoryBalancerImplementation = new IndexFactoryBalancer();

        bytes memory initData = abi.encodeWithSignature("initialize(address)", indexFactoryStorageProxy);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(indexFactoryBalancerImplementation), address(indexFactoryBalancerProxyAdmin), initData
        );

        indexFactoryBalancerProxy = address(proxy);

        console.log("///////// IndexFactoryBalancer //////////");
        console.log("IndexFactoryBalancer impl:", address(indexFactoryBalancerImplementation));
        console.log("IndexFactoryBalancer proxy:", indexFactoryBalancerProxy);
        console.log("IndexFactoryBalancer ProxyAdmin:", address(indexFactoryBalancerProxyAdmin));
    }

    function deployPriceOracle() internal {
        address deployed = deployByteCode(priceOracleByteCode);
        priceOracle = deployed;

        console.log("///////// PriceOracle //////////");
        console.log("PriceOracle deployed at:", priceOracle);
    }

    function deployVault() internal {
        vaultProxyAdmin = new ProxyAdmin();
        vaultImplementation = new Vault();

        bytes memory initData = abi.encodeWithSignature("initialize()");

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(vaultImplementation), address(vaultProxyAdmin), initData);

        vaultProxy = address(proxy);

        console.log("///////// Vault //////////");
        console.log("Vault impl:", address(vaultImplementation));
        console.log("Vault proxy:", vaultProxy);
        console.log("Vault ProxyAdmin:", address(vaultProxyAdmin));
    }

    function setProxyValues() internal {
        IndexToken(indexTokenProxy).setMinter(indexFactoryProxy);

        IndexFactoryStorage(indexFactoryStorageProxy).setFeeReceiver(feeReceiver);
        IndexFactoryStorage(indexFactoryStorageProxy).setPriceOracle(priceOracle);
        IndexFactoryStorage(indexFactoryStorageProxy).setVault(vaultProxy);
        IndexFactoryStorage(indexFactoryStorageProxy).setFactoryBalancer(indexFactoryBalancerProxy);

        Vault(vaultProxy).setOperator(indexFactoryProxy, true);
        Vault(vaultProxy).setOperator(indexFactoryBalancerProxy, true);
    }

    function fillMockAssetsListMainnet() internal {
        address[] memory assetList = new address[](5);
        assetList[0] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8; // PENDLE
        assetList[1] = 0x6694340fc020c5E6B96567843da2df01b2CE1eb6; // STARGATE
        assetList[2] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0; // UNISWAP
        assetList[3] = 0x354A6dA3fcde098F8389cad84b0182725c6C91dE; // COMPOUND
        assetList[4] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX

        uint256[] memory marketShares = new uint256[](5);
        marketShares[0] = 28000000000000000000;
        marketShares[1] = 23000000000000000000;
        marketShares[2] = 18000000000000000000;
        marketShares[3] = 18000000000000000000;
        marketShares[4] = 13000000000000000000;

        uint24[] memory feesData = new uint24[](1);
        feesData[0] = 3000;

        bytes[] memory pathData = new bytes[](5);
        for (uint256 i = 0; i < 5; i++) {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = assetList[i];
            pathData[i] = abi.encode(path, feesData);
        }

        // IndexFactoryStorage(indexFactoryStorageProxy).mockFillAssetsList(assetList, pathData, marketShares);

        console.log("Called mockFillAssetsList() with your 5 assets data.");
    }

    function fillMockAssetsListTestnet() internal {
        address[] memory assetList = new address[](11);
        assetList[0] = 0x9CD4f9Bec89e00A560840174Dc8054Fb4b3e1858; // sepoliaTestArbitrumAddress
        assetList[1] = 0x8B0D01137979e409Bba15098aA5665c647774003; // sepoliaTestAAVEAddress
        assetList[2] = 0xC361Ce0885FaA9F6F5f41F2b2A08E72E465DFbc6; // sepoliaTestCLIPPERAddress
        assetList[3] = 0xCAC218f00e79A6923228487C52dcba71666C6b17; // sepoliaTestPENDLEAddress
        assetList[4] = 0x861b6Db57c71F9E5B989a18d4C6f600b7b26E170; // sepoliaTestSILOAddress
        assetList[5] = 0xe4e401c5a31d43550D9218CCf412A761e5441F39; // sepoliaTestCAKEAddress
        assetList[6] = 0xdc29d1B632F84b64f9b2742D1CD305D11f9Db76A; // sepoliaTestDODOAddress
        assetList[7] = 0x7844288a55B09Af610200C738e9714A3B55eEA34; // sepoliaTestSALEAddress
        assetList[8] = 0x46F7bA9B4bfA0F7179a01Bf42143E78e65fD7904; // sepoliaTestPNPAddress
        assetList[9] = 0x2A0FDA08272292883187019773F5c655cc7804FF; // sepoliaTestCVXAddress
        assetList[10] = 0x6AeFff05e69Df302e4fe508778C23996A53B440f; // sepoliaTestJOEAddress

        uint256[] memory marketShares = new uint256[](11);
        marketShares[0] = 15000000000000000000; // 15e18
        marketShares[1] = 12500000000000000000; // 12.5e18
        marketShares[2] = 12500000000000000000;
        marketShares[3] = 9375000000000000000; // 9.375e18
        marketShares[4] = 9375000000000000000;
        marketShares[5] = 7500000000000000000; // 7.5e18
        marketShares[6] = 7500000000000000000;
        marketShares[7] = 7500000000000000000;
        marketShares[8] = 6250000000000000000; // 6.25e18
        marketShares[9] = 6250000000000000000;
        marketShares[10] = 6250000000000000000;

        uint24[] memory feesData = new uint24[](1);
        feesData[0] = 3000;

        bytes[] memory pathData = new bytes[](11);
        for (uint256 i = 0; i < 11; i++) {
            address[] memory path = new address[](2);
            path[0] = wethAddress;
            path[1] = assetList[i];
            pathData[i] = abi.encode(path, feesData);
        }

        // IndexFactoryStorage(indexFactoryStorageProxy).mockFillAssetsList(assetList, pathData, marketShares);

        console.log("Called mockFillAssetsList() with your 11 assets data.");
    }

    function deployByteCode(bytes memory bytecode) public returns (address) {
        address deployedContract;
        assembly {
            deployedContract := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        return deployedContract;
    }
}
