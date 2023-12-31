// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../../contracts/token/IndexToken.sol";
import "../../contracts/Swap.sol";
import "../../contracts/test/MockV3Aggregator.sol";
import "../../contracts/test/MockApiOracle.sol";
import "../../contracts/test/LinkToken.sol";

contract CounterTest is Test {


    uint256 internal constant SCALAR = 1e20;

    IndexToken public indexToken;
    Swap public swap;
    bytes32 jobId = "6b88e0402e5d415eb946e528b8e0c7ba";

    MockApiOracle public oracle;
    LinkToken link;

    address feeReceiver = vm.addr(1);
    address newFeeReceiver = vm.addr(2);
    address minter = vm.addr(3);
    address newMinter = vm.addr(4);
    address methodologist = vm.addr(5);


    event FeeReceiverSet(address indexed feeReceiver);
    event FeeRateSet(uint256 indexed feeRatePerDayScaled);
    event MethodologistSet(address indexed methodologist);
    event MethodologySet(string methodology);
    event MinterSet(address indexed minter);
    event SupplyCeilingSet(uint256 supplyCeiling);
    event MintFeeToReceiver(address feeReceiver, uint256 timestamp, uint256 totalSupply, uint256 amount);
    event ToggledRestricted(address indexed account, bool isRestricted);

    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address public constant SwapRouterV3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant FactoryV3 = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public constant SwapRouterV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant FactoryV2 = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;


    function setUp() public {
        indexToken = new IndexToken();
        indexToken.initialize(
            "Anti Inflation",
            "ANFI",
            1e18,
            feeReceiver,
            1000000e18,
            //swap addresses
            WETH9,
            QUOTER,
            SwapRouterV3,
            FactoryV3,
            SwapRouterV2,
            FactoryV2
        );
        indexToken.setMinter(minter);

        //swap
        swap = new Swap();
    }

    function testInitialized() public {
        // counter.increment();
        assertEq(indexToken.owner(), address(this));
        assertEq(indexToken.feeRatePerDayScaled(), 1e18);
        assertEq(indexToken.feeTimestamp(), block.timestamp);
        assertEq(indexToken.feeReceiver(), feeReceiver);
        assertEq(indexToken.methodology(), "");
        assertEq(indexToken.supplyCeiling(), 1000000e18);
        assertEq(indexToken.minter(), minter);
    }

    function testMintOnlyMinter() public {
        vm.expectRevert("IndexToken: caller is not the minter");
        indexToken.mint(address(this), 1000e18);
        assertEq(indexToken.balanceOf(address(this)), 0);
    }

    

    
}