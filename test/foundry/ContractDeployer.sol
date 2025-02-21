// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../contracts/token/IndexToken.sol";
import "../../contracts/test/MockV3Aggregator.sol";
import "../../contracts/test/MockApiOracle.sol";
import "../../contracts/test/LinkToken.sol";
import "../../contracts/test/UniswapFactoryByteCode.sol";
import "../../contracts/test/UniswapWETHByteCode.sol";
import "../../contracts/test/UniswapRouterByteCode.sol";
import "../../contracts/test/UniswapPositionManagerByteCode.sol";
import "../../contracts/test/PriceOracleByteCode.sol";
import "../../contracts/factory/IndexFactory.sol";
import "../../contracts/factory/IndexFactoryStorage.sol";
import "../../contracts/factory/IndexFactoryBalancer.sol";
import "../../contracts/vault/Vault.sol";
// import "../../contracts/test/TestSwap.sol";
import "../../contracts/uniswap/Token.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "../../contracts/interfaces/IUniswapV3Pool.sol";

import "../../contracts/uniswap/INonfungiblePositionManager.sol";
import "../../contracts/interfaces/IUniswapV3Factory2.sol";
import "../../contracts/interfaces/IWETH.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// import "../../contracts/Swap.sol";

contract ContractDeployer is
    Test,
    UniswapFactoryByteCode,
    UniswapWETHByteCode,
    UniswapRouterByteCode,
    UniswapPositionManagerByteCode,
    PriceOracleByteCode
{
    bytes32 jobId = "6b88e0402e5d415eb946e528b8e0c7ba";

    address public constant QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    
    address feeReceiver = vm.addr(1);
    address newFeeReceiver = vm.addr(2);
    address minter = vm.addr(3);
    address newMinter = vm.addr(4);
    address methodologist = vm.addr(5);
    address owner = vm.addr(6);
    address add1 = vm.addr(7);

    Token token0;
    Token token1;
    Token token2;
    Token token3;
    Token token4;
    Token token5;
    Token token6;
    Token token7;
    Token token8;
    Token token9;

    Token usdt;

    address priceOracleAddress;
    address factoryAddress;
    address wethAddress;
    address router;
    address positionManager;
    IndexToken public indexToken;
    // Swap public swap;
    MockApiOracle public oracle;
    LinkToken link;
    // PriceOracle public priceOracle;
    IndexFactory public factory;
    IndexFactoryStorage public factoryStorage;
    IndexFactoryBalancer public factoryBalancer;
    Vault public vault;
    // TestSwap public testSwap;
    MockV3Aggregator public ethPriceOracle;
    ERC20 public dai;
    IWETH public weth;
    IQuoter public quoter;

    IUniswapV3Factory public factoryV3 = IUniswapV3Factory(factoryAddress);
    ISwapRouter public swapRouter = ISwapRouter(router);

    function getMinTick(int24 tickSpacing) public pure returns (int24) {
        return
            int24(
                (int256(-887272) / int256(tickSpacing) + 1) *
                    int256(tickSpacing)
            );
    }

    function getMaxTick(int24 tickSpacing) public pure returns (int24) {
        return
            int24((int256(887272) / int256(tickSpacing)) * int256(tickSpacing));
    }

    function encodePriceSqrt(
        uint256 reserve1,
        uint256 reserve0
    ) public pure returns (uint160) {
        uint256 sqrtPriceX96 = sqrt((reserve1 * 2 ** 192) / reserve0);
        return uint160(sqrtPriceX96);
    }

    function sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function deployContracts()
        public
        returns (
            LinkToken,
            MockApiOracle,
            IndexToken,
            MockV3Aggregator,
            // IndexFactory,
            IndexFactoryStorage,
            Vault
        )
    // TestSwap
    {
        LinkToken link = new LinkToken();
        MockApiOracle oracle = new MockApiOracle();

        MockV3Aggregator ethPriceOracle = new MockV3Aggregator(
            18, //decimals
            2000e18 //initial data
        );

        
        IndexToken indexTokenImpl = new IndexToken();
        IndexToken indexToken = IndexToken(
            payable(
                address(
                    new ERC1967Proxy(
                        address(indexTokenImpl),
                        abi.encodeCall(
                            IndexToken.initialize,
                            ("Anti Inflation",
                            "ANFI",
                            1e18,
                            feeReceiver,
                            1000000000e18)
                        )
                    )
                )
            )
        );

        
        Vault vaultImpl = new Vault();
        Vault vault = Vault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(vaultImpl),
                        abi.encodeCall(Vault.initialize, ())
                    )
                )
            )
        );

        

        IndexFactoryStorage factoryStorageImpl = new IndexFactoryStorage();
        IndexFactoryStorage factoryStorage = IndexFactoryStorage(
            payable(
                address(
                    new ERC1967Proxy(
                        address(factoryStorageImpl),
                        abi.encodeCall(
                            IndexFactoryStorage.initialize,
                            (
                            payable(address(indexToken)),
                            address(oracle),
                            jobId,
                            address(ethPriceOracle),
                            //swap addresses
                            wethAddress,
                            QUOTER,
                            router,
                            factoryAddress,
                            router,
                            factoryAddress
                            )
                        )
                    )
                )
            )
        );


        

        return (
            link,
            oracle,
            indexToken,
            ethPriceOracle,
            factoryStorage,
            vault
        );
    }

    function deployContracts2() public returns (IndexFactory, IndexFactoryBalancer) {
        
        IndexFactory factoryImpl = new IndexFactory();
        IndexFactory factory = IndexFactory(
            payable(
                address(
                    new ERC1967Proxy(
                        address(factoryImpl),
                        abi.encodeCall(
                            IndexFactory.initialize,
                            payable(address(factoryStorage))
                        )
                    )
                )
            )
        );

        IndexFactoryBalancer factoryBalancerImpl = new IndexFactoryBalancer();
        IndexFactoryBalancer factoryBalancer = IndexFactoryBalancer(
            payable(
                address(
                    new ERC1967Proxy(
                        address(factoryBalancerImpl),
                        abi.encodeCall(
                            IndexFactoryBalancer.initialize,
                            payable(address(factoryStorage))
                        )
                    )
                )
            )
        );

        


        return (factory, factoryBalancer);
    }

    function linkAllContracts() public {
        indexToken.setMinter(address(factory));
        factoryStorage.setFeeReceiver(address(feeReceiver));
        factoryStorage.setPriceOracle(priceOracleAddress);
        factoryStorage.setVault(address(vault));
        vault.setOperator(address(factory), true);
        factoryStorage.setFactoryBalancer(address(factoryBalancer));
        vault.setOperator(address(factoryBalancer), true);
    }

    function deployTokens(
        uint256 initialSupply
    ) public returns (Token[11] memory) {
        Token[11] memory tokens;

        for (uint256 i = 0; i < 11; i++) {
            tokens[i] = new Token(initialSupply);
        }

        return tokens;
    }

    function deployUniswap()
        public
        returns (address, address, address, address, address)
    {
        // bytes memory bytecode = factoryByteCode;
        address priceOracleAddress = deployByteCode(priceOracleByteCode);
        // address priceOracleAddress = address(0);
        address factoryAddress = deployByteCode(factoryByteCode);
        address wethAddress = deployByteCode(WETHByteCode);
        address routerAddress = deployByteCodeWithInputs(
            routerByteCode,
            abi.encode(factoryAddress, wethAddress)
        );
        address positionManagerAddress = deployByteCodeWithInputs(
            positionManagerByteCode,
            abi.encode(
                factoryAddress,
                wethAddress,
                0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
            )
        );

        return (
            priceOracleAddress,
            factoryAddress,
            wethAddress,
            routerAddress,
            positionManagerAddress
        );
    }

    function deployAllContracts(uint initialSupply) public {
        Token[11] memory tokens = deployTokens(initialSupply);
        token0 = tokens[0];
        token1 = tokens[1];
        token2 = tokens[2];
        token3 = tokens[3];
        token4 = tokens[4];
        token5 = tokens[5];
        token6 = tokens[6];
        token7 = tokens[7];
        token8 = tokens[8];
        token9 = tokens[9];
        usdt = tokens[10];

        (
            priceOracleAddress,
            factoryAddress,
            wethAddress,
            router,
            positionManager
        ) = deployUniswap();
        factoryV3 = IUniswapV3Factory(factoryAddress);
        swapRouter = ISwapRouter(router);
        weth = IWETH(wethAddress);
        (
            link,
            oracle,
            indexToken,
            ethPriceOracle,
            // factory,
            factoryStorage,
            vault
        ) = deployContracts();
        (factory, factoryBalancer) = deployContracts2();
        linkAllContracts();
    }

    function deployByteCode(bytes memory bytecode) public returns (address) {
        bytes memory bytecodeWithArgs = bytecode;
        address deployedContract;
        assembly {
            deployedContract := create(
                0,
                add(bytecodeWithArgs, 0x20),
                mload(bytecodeWithArgs)
            )
        }

        return deployedContract;
    }

    function deployByteCodeWithInputs(
        bytes memory bytecode,
        bytes memory _initData
    ) public returns (address) {
        bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, _initData);
        address deployedContract;
        assembly {
            deployedContract := create(
                0,
                add(bytecodeWithArgs, 0x20),
                mload(bytecodeWithArgs)
            )
        }

        return deployedContract;
    }

    function addLiquidity(
        address positionManager,
        address factory,
        Token token0,
        Token token1,
        uint amount0,
        uint amount1
    ) public {
        Token[] memory tokens = new Token[](2);
        tokens[0] = address(token0) < address(token1) ? token0 : token1;
        tokens[1] = address(token0) > address(token1) ? token0 : token1;
        uint[] memory amounts = new uint[](2);
        amounts[0] = address(tokens[0]) == address(token0) ? amount0 : amount1;
        amounts[1] = address(tokens[1]) == address(token1) ? amount1 : amount0;
        INonfungiblePositionManager(positionManager)
            .createAndInitializePoolIfNecessary(
                address(tokens[0]),
                address(tokens[1]),
                3000,
                encodePriceSqrt(1, 1)
            );
        address poolAddress = IUniswapV3Factory2(factory).getPool(
            address(tokens[0]),
            address(tokens[1]),
            3000
        );
        tokens[0].approve(positionManager, amounts[0]);
        tokens[1].approve(positionManager, amounts[1]);
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                address(tokens[0]),
                address(tokens[1]),
                3000,
                getMinTick(3000),
                getMaxTick(3000),
                amounts[0],
                amounts[1],
                0,
                0,
                address(this),
                block.timestamp
            );
        INonfungiblePositionManager(positionManager).mint(params);
    }

    function addLiquidityETH(
        address positionManager,
        address factory,
        Token token0,
        address weth,
        uint amount0,
        uint amount1
    ) public {
        Token[] memory tokens = new Token[](2);
        tokens[0] = address(token0) < address(weth) ? token0 : Token(weth);
        tokens[1] = address(token0) > address(weth) ? token0 : Token(weth);
        uint[] memory amounts = new uint[](2);
        amounts[0] = address(token0) < address(weth) ? amount0 : amount1;
        amounts[1] = address(token0) > address(weth) ? amount0 : amount1;
        INonfungiblePositionManager(positionManager)
            .createAndInitializePoolIfNecessary(
                address(tokens[0]),
                address(tokens[1]),
                3000,
                encodePriceSqrt(amounts[1] / 1e10, amounts[0] / 1e10)
            );
        address poolAddress = IUniswapV3Factory2(factory).getPool(
            address(tokens[0]),
            address(tokens[1]),
            3000
        );
        IWETH(weth).deposit{value: amount1}();
        tokens[0].approve(positionManager, amounts[0]);
        tokens[1].approve(positionManager, amounts[1]);
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                address(tokens[0]),
                address(tokens[1]),
                3000,
                getMinTick(3000),
                getMaxTick(3000),
                amounts[0],
                amounts[1],
                0,
                0,
                address(this),
                block.timestamp
            );
        INonfungiblePositionManager(positionManager).mint(params);
    }
}
