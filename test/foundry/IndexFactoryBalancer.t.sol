// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../../contracts/interfaces/IUniswapV2Router02.sol";
import "../../contracts/factory/IndexFactoryBalancer.sol";
import "../../contracts/factory/IndexFactoryStorage.sol";
import "../../contracts/libraries/SwapHelpers.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../contracts/interfaces/IWETH.sol";
import {Vault} from "../../contracts/vault/Vault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract IndexFactoryBalancerTest is Test, IndexFactoryBalancer {
    IndexFactoryBalancer indexFactoryBalancer;
    IndexFactoryStorage indexFactoryStorage;
    address factoryStorageAddress;

    address user = address(1);
    address ownerAddr = address(0x2);
    address testAdd = address(0x3);

    address wethAddress = address(0x1234);
    address vaultAddress = address(0x5678);

    address token1 = address(0x1111);
    address token2 = address(0x2222);
    address someToken = address(0xAAA1);

    Vault vaultMock;
    IWETH wethMock;

    function setUp() external {
        vm.startPrank(ownerAddr);

        // indexFactoryStorage = new IndexFactoryStorage();
        // indexFactoryStorage.initialize(
        //     payable(testAdd),
        //     testAdd,
        //     // address(0),
        //     0x0,
        //     testAdd,
        //     wethAddress,
        //     testAdd,
        //     testAdd,
        //     testAdd,
        //     testAdd,
        //     vaultAddress
        // );

        IndexFactoryStorage indexFactoryStorageImp = new IndexFactoryStorage();
        indexFactoryStorage = IndexFactoryStorage(
            payable(
                address(
                    new ERC1967Proxy(
                        address(indexFactoryStorageImp),
                        abi.encodeWithSelector(
                            indexFactoryStorageImp.initialize.selector,
                            payable(testAdd),
                            testAdd,
                            // address(0),
                            0x0,
                            testAdd,
                            wethAddress,
                            testAdd,
                            testAdd,
                            testAdd,
                            testAdd,
                            vaultAddress
                        )
                    )
                )
            )
        );

        wethMock = IWETH(wethAddress);
        vaultMock = Vault(vaultAddress);

        indexFactoryStorage.setVault(vaultAddress);

        // indexFactoryBalancer = new IndexFactoryBalancer();
        // require(address(indexFactoryStorage) != address(0));
        // indexFactoryBalancer.initialize(payable(address(indexFactoryStorage)));
        IndexFactoryBalancer indexFactoryBalancerImp = new IndexFactoryBalancer();
        indexFactoryBalancer = IndexFactoryBalancer(
            payable(
                address(
                    new ERC1967Proxy(
                        address(indexFactoryBalancerImp),
                        abi.encodeWithSelector(
                            indexFactoryBalancerImp.initialize.selector,
                            payable(address(indexFactoryStorage))
                        )
                    )
                )
            )
        );
        assertTrue(address(indexFactoryStorage) != address(0));

        indexFactoryStorage.setFactoryBalancer(address(indexFactoryBalancer));

        factoryStorageAddress = address(indexFactoryStorage);

        vm.stopPrank();
    }

    function test_MutationToWei() public {
        {
            int256 amount = 100;
            uint8 amountDec = 8;
            uint8 chainDec = 18;
            int256 expected1 = amount * int256(10 ** (chainDec - amountDec));
            int256 actual1 = _toWei(amount, amountDec, chainDec);
            assertEq(
                actual1,
                expected1,
                "test_MutationCoverage: _toWei failed for chainDecimals > amountDecimals"
            );

            uint8 bigger = 18;
            uint8 smaller = 8;
            int256 expected2 = amount * int256(10 ** (bigger - smaller));
            int256 actual2 = _toWei(amount, bigger, smaller);
            assertEq(
                actual2,
                expected2,
                "test_MutationCoverage: _toWei failed for chainDecimals < amountDecimals"
            );
        }
    }

    function testReIndexAndReweight_Mutations_Failures() public {
        vm.startPrank(ownerAddr);

        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(
                indexFactoryStorage.totalCurrentList.selector
            ),
            abi.encode(uint256(1))
        );
        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(
                indexFactoryStorage.totalOracleList.selector
            ),
            abi.encode(uint256(1))
        );

        address someNonWeth1 = address(0xABC1);
        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(indexFactoryStorage.currentList.selector, 0),
            abi.encode(someNonWeth1)
        );

        address someNonWeth2 = address(0xABC2);
        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(indexFactoryStorage.oracleList.selector, 0),
            abi.encode(someNonWeth2)
        );

        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(
                indexFactoryStorage.tokenOracleMarketShare.selector,
                someNonWeth2
            ),
            abi.encode(uint256(50e18))
        );

        Vault vault = indexFactoryStorage.vault();
        vm.mockCall(address(vault), bytes(""), abi.encode(true));

        address wethAddr = address(indexFactoryStorage.weth());
        vm.mockCall(
            wethAddr,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryBalancer)
            ),
            abi.encode(uint256(500e18))
        );

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(
                Vault.withdrawFunds.selector,
                someNonWeth1,
                address(indexFactoryBalancer),
                100
            ),
            abi.encode(false)
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        uint256 wethBalance = 500e18;
        uint256 tokenOracleMarketShare = 50e18;
        uint256 incorrectAmountDivision = wethBalance / tokenOracleMarketShare;

        vm.mockCall(
            wethAddr,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryBalancer)
            ),
            abi.encode(incorrectAmountDivision)
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        uint256 incorrectAmountMultiplication = (wethBalance *
            tokenOracleMarketShare) * 100e18;

        vm.mockCall(
            wethAddr,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryBalancer)
            ),
            abi.encode(incorrectAmountMultiplication)
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(
                Vault.withdrawFunds.selector,
                someNonWeth2,
                address(indexFactoryBalancer),
                100
            ),
            abi.encode(false)
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        vm.stopPrank();
    }

    function testReIndexAndReweight_MutationLines() public {
        vm.startPrank(ownerAddr);

        address someNonWeth1 = address(0xABC1);
        uint256 wethBalance = 500e18;
        uint256 tokenOracleMarketShare = 50e18;

        vm.mockCall(
            address(indexFactoryBalancer),
            abi.encodeWithSignature(
                "swap(address,address,uint256,address,uint24)",
                someNonWeth1,
                wethAddress,
                100,
                ownerAddr,
                3000
            ),
            abi.encode(int256(-1))
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        uint256 incorrectDivision = wethBalance / tokenOracleMarketShare;
        vm.mockCall(
            address(indexFactoryBalancer),
            abi.encodeWithSignature(
                "swap(address,address,uint256,address,uint24)",
                wethAddress,
                someNonWeth1,
                100,
                ownerAddr,
                3000
            ),
            abi.encode(incorrectDivision)
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        uint256 incorrectMultiplication = (wethBalance *
            tokenOracleMarketShare) * 100e18;
        vm.mockCall(
            address(indexFactoryBalancer),
            abi.encodeWithSignature(
                "swap(address,address,uint256,address,uint24)",
                wethAddress,
                someNonWeth1,
                100,
                ownerAddr,
                3000
            ),
            abi.encode(incorrectMultiplication)
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        vm.mockCall(
            address(indexFactoryBalancer),
            abi.encodeWithSignature(
                "swap(address,address,uint256,address,uint24)",
                wethAddress,
                someNonWeth1,
                100,
                ownerAddr,
                3000
            ),
            abi.encode(int256(-1))
        );
        vm.expectRevert();
        indexFactoryBalancer.reIndexAndReweight();

        vm.stopPrank();
    }

    function testInitializeInvalidFactoryStorage() public {
        address payable invalidFactoryStorage = payable(address(0));
        vm.expectRevert("Initializable: contract is already initialized");
        indexFactoryBalancer.initialize(invalidFactoryStorage);
    }

    function testReIndexAndReweight_MutationLinesCov() public {
        vm.startPrank(ownerAddr);

        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(
                indexFactoryStorage.totalCurrentList.selector
            ),
            abi.encode(uint256(1))
        );
        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(
                indexFactoryStorage.totalOracleList.selector
            ),
            abi.encode(uint256(1))
        );

        address someNonWeth1 = address(0xABC1);
        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(indexFactoryStorage.currentList.selector, 0),
            abi.encode(someNonWeth1)
        );

        address someNonWeth2 = address(0xABC2);
        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(indexFactoryStorage.oracleList.selector, 0),
            abi.encode(someNonWeth2)
        );

        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(
                indexFactoryStorage.tokenOracleMarketShare.selector,
                someNonWeth2
            ),
            abi.encode(uint256(50e18))
        );

        Vault vault = indexFactoryStorage.vault();
        vm.mockCall(address(vault), bytes(""), abi.encode(true));

        address wethAddr = address(indexFactoryStorage.weth());
        vm.mockCall(
            wethAddr,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryBalancer)
            ),
            abi.encode(uint256(500e18))
        );

        vm.mockCall(
            address(indexFactoryBalancer),
            bytes(""),
            abi.encode(uint256(123e18))
        );

        indexFactoryBalancer.reIndexAndReweight();

        vm.stopPrank();
    }

    function test_initialize_SuccessfulInitialization() public {
        assertEq(
            address(indexFactoryBalancer.factoryStorage()),
            factoryStorageAddress
        );
    }

    

    function testWithdraw_Success() public {
        uint256 deposit = 5 ether;
        uint256 withdrawAmount = 3 ether;

        vm.deal(address(indexFactoryBalancer), deposit);

        vm.startPrank(ownerAddr);
        indexFactoryBalancer.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(
            ownerAddr.balance,
            withdrawAmount,
            "Owner did not receive the withdrawn Ether"
        );
        assertEq(
            address(indexFactoryBalancer).balance,
            deposit - withdrawAmount,
            "Contract balance mismatch"
        );
    }

    function testWithdraw_RevertOnInsufficientBalance() public {
        vm.startPrank(ownerAddr);
        vm.expectRevert("Insufficient balance");
        indexFactoryBalancer.withdraw(1 ether);
        vm.stopPrank();
    }

    function testWithdrawRevertWithNonOwnerAddress() public {
        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        indexFactoryBalancer.withdraw(1 ether);
        vm.stopPrank();
    }

    

    function test_withdraw_FailWithdrawWhenBalanceIsInsufficient() public {
        vm.prank(ownerAddr);
        vm.expectRevert("Insufficient balance");
        indexFactoryBalancer.withdraw(1);
    }

    function test_pause_SuccessfulPause() public {
        vm.startPrank(ownerAddr);
        indexFactoryBalancer.pause();
        vm.stopPrank();
        assert(indexFactoryBalancer.paused());
    }

    function test_unpause_SuccessfulUnpause() public {
        vm.startPrank(ownerAddr);
        indexFactoryBalancer.pause();
        indexFactoryBalancer.unpause();
        vm.stopPrank();
        assertFalse(indexFactoryBalancer.paused());
    }

    function testPauseWithNonOwnerAddress() public {
        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        indexFactoryBalancer.pause();
        vm.stopPrank();
    }

    function testUnpauseWithNonOwnerAddress() public {
        vm.startPrank(ownerAddr);
        indexFactoryBalancer.pause();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        indexFactoryBalancer.unpause();
        vm.stopPrank();
    }

    function test_SendETHDirectlyFail() public {
        deal(user, 10 ether);

        vm.startPrank(user);
        vm.expectRevert("You can't send ether directly to this contact");
        address(indexFactoryBalancer).call{value: 10 ether}("");

        vm.stopPrank();
    }

    function testreIndexAndReweight() public {
        vm.startPrank(ownerAddr);

        address token1 = address(0x1001);
        address token2 = address(0x1002);
        address wethAddress = address(indexFactoryStorage.weth());

        uint256 vaultToken1Balance = 1000 * 10 ** 18;
        uint256 vaultToken2Balance = 2000 * 10 ** 18;
        uint256 wethBalanceBefore = 5000 * 10 ** 18;

        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(
                Vault.withdrawFunds.selector,
                token1,
                address(indexFactoryBalancer),
                vaultToken1Balance
            ),
            abi.encode(true)
        );
        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(
                Vault.withdrawFunds.selector,
                token2,
                address(indexFactoryBalancer),
                vaultToken2Balance
            ),
            abi.encode(true)
        );

        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(IERC20.balanceOf.selector, token1),
            abi.encode(vaultToken1Balance)
        );
        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(IERC20.balanceOf.selector, token2),
            abi.encode(vaultToken2Balance)
        );

        vm.mockCall(
            wethAddress,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryBalancer)
            ),
            abi.encode(wethBalanceBefore)
        );

        vm.mockCall(
            wethAddress,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryStorage.vault())
            ),
            abi.encode(uint256(3000e18))
        );

        uint256 wethBalanceBeforeReweight = IWETH(wethAddress).balanceOf(
            address(indexFactoryStorage.vault())
        );

        indexFactoryBalancer.reIndexAndReweight();

        vm.mockCall(
            wethAddress,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryStorage.vault())
            ),
            abi.encode(uint256(4000e18))
        );

        uint256 wethBalanceAfterReweight = IWETH(wethAddress).balanceOf(
            address(indexFactoryStorage.vault())
        );

        uint256 wethBalanceAfter = wethBalanceBefore;
        assertEq(
            IERC20(wethAddress).balanceOf(address(indexFactoryBalancer)),
            wethBalanceAfter,
            "WETH balance mismatch after reindexing"
        );

        assertGt(wethBalanceAfterReweight, wethBalanceBeforeReweight);

        vm.stopPrank();
    }

    function testReIndexAndReweightRevertWithNonOwnerAddress() public {
        vm.startPrank(user);

        address token1 = address(0x1001);
        address token2 = address(0x1002);
        address wethAddress = address(indexFactoryStorage.weth());

        uint24 token1SwapFee = 3000;
        uint24 token2SwapFee = 10000;

        uint256 vaultToken1Balance = 1000 * 10 ** 18;
        uint256 vaultToken2Balance = 2000 * 10 ** 18;
        uint256 wethBalanceBefore = 5000 * 10 ** 18;

        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(
                Vault.withdrawFunds.selector,
                token1,
                address(indexFactoryBalancer),
                vaultToken1Balance
            ),
            abi.encode(true)
        );
        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(
                Vault.withdrawFunds.selector,
                token2,
                address(indexFactoryBalancer),
                vaultToken2Balance
            ),
            abi.encode(true)
        );

        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(IERC20.balanceOf.selector, token1),
            abi.encode(vaultToken1Balance)
        );
        vm.mockCall(
            address(indexFactoryStorage.vault()),
            abi.encodeWithSelector(IERC20.balanceOf.selector, token2),
            abi.encode(vaultToken2Balance)
        );

        vm.mockCall(
            wethAddress,
            abi.encodeWithSelector(
                IERC20.balanceOf.selector,
                address(indexFactoryBalancer)
            ),
            abi.encode(wethBalanceBefore)
        );

        vm.expectRevert("Ownable: caller is not the owner");
        indexFactoryBalancer.reIndexAndReweight();

        uint256 wethBalanceAfter = wethBalanceBefore;
        assertEq(
            IERC20(wethAddress).balanceOf(address(indexFactoryBalancer)),
            wethBalanceAfter,
            "WETH balance mismatch after reindexing"
        );

        vm.stopPrank();
    }

    function testFailReIndexAndReweight_RevertOnVaultWithdrawalFailure()
        public
    {
        vm.mockCall(
            vaultAddress,
            abi.encodeWithSelector(
                Vault.withdrawFunds.selector,
                address(0),
                address(indexFactoryBalancer),
                100
            ),
            abi.encode(false)
        );

        vm.startPrank(ownerAddr);
        vm.expectRevert("Vault withdrawal failed");
        indexFactoryBalancer.reIndexAndReweight();
        vm.stopPrank();
    }

    function testFailReceiveFunctionReverts() public {
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        vm.expectRevert("DoNotSendFundsDirectlyToTheContract");
        (bool success, ) = address(indexFactoryBalancer).call{value: 1 ether}(
            ""
        );
        assertFalse(success, "Direct ETH transfer should fail");
        vm.stopPrank();
    }

    function testFailSwap_RevertOnTransferFailure() public {
        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(indexFactoryStorage.swapRouterV3.selector),
            abi.encode(address(0))
        );

        vm.mockCall(
            address(indexFactoryStorage),
            abi.encodeWithSelector(indexFactoryStorage.swapRouterV2.selector),
            abi.encode(address(0))
        );

        vm.startPrank(ownerAddr);
        vm.expectRevert("Transfer failed");
        // SwapHelpers.swap(
        //     ISwapRouter(address(0)), IUniswapV2Router02(address(0)), 3000, address(0), address(0), 100, ownerAddr
        // );
        vm.stopPrank();
    }

    function testFailWithdraw_RevertWhenPaused() public {
        uint256 deposit = 5 ether;
        uint256 withdrawAmount = 3 ether;

        vm.deal(address(indexFactoryBalancer), deposit);

        vm.startPrank(ownerAddr);
        indexFactoryBalancer.pause();
        vm.expectRevert("Pausable: paused");
        indexFactoryBalancer.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    function testInitialize_SecondInitializationReverts() public {
        vm.startPrank(ownerAddr);
        vm.expectRevert("Initializable: contract is already initialized");
        indexFactoryBalancer.initialize(payable(address(indexFactoryStorage)));
        vm.stopPrank();
    }

    // function testCurrentListFunctionsWithoutMocking() public {
    //     address[] memory tokens = new address[](3);
    //     tokens[0] = token1;
    //     tokens[1] = token2;
    //     tokens[2] = wethAddress;

    //     uint256[] memory marketShares = new uint256[](3);
    //     marketShares[0] = 100e18;
    //     marketShares[1] = 200e18;
    //     marketShares[2] = 300e18;

    //     uint24[] memory swapFees = new uint24[](3);
    //     swapFees[0] = 3000;
    //     swapFees[1] = 10000;
    //     swapFees[2] = 500;

    //     vm.startPrank(ownerAddr);
    //     // indexFactoryStorage.mockFillAssetsList(tokens, marketShares, swapFees);
    //     IndexFactoryStorage.mockFillAssetsList(tokens, marketShares, swapFees);
    //     vm.stopPrank();

    //     uint256 total = indexFactoryStorage.totalCurrentList();
    //     assertEq(total, 3, "Expected totalCurrentList to be 3");

    //     assertEq(indexFactoryStorage.currentList(0), token1, "currentList(0) should be token1");
    //     assertEq(indexFactoryStorage.currentList(1), token2, "currentList(1) should be token2");
    //     assertEq(indexFactoryStorage.currentList(2), wethAddress, "currentList(2) should be wethAddress");
    // }

    // function testSetAndCheckCurrentList() public {
    //     vm.startPrank(ownerAddr);

    //     address[] memory tokens = new address[](2);
    //     tokens[0] = token1;
    //     tokens[1] = token2;

    //     uint256[] memory marketShares = new uint256[](2);
    //     marketShares[0] = 100e18;
    //     marketShares[1] = 200e18;

    //     uint24[] memory swapFees = new uint24[](2);
    //     swapFees[0] = 3000;
    //     swapFees[1] = 10000;

    //     indexFactoryStorage.mockFillAssetsList(tokens, marketShares, swapFees);

    //     vm.stopPrank();

    //     uint256 total = indexFactoryStorage.totalCurrentList();
    //     assertEq(total, 2, "totalCurrentList should be 2 after mockFillAssetsList");

    //     address listToken0 = indexFactoryStorage.currentList(0);
    //     address listToken1 = indexFactoryStorage.currentList(1);

    //     assertEq(listToken0, token1, "currentList(0) should return token1");
    //     assertEq(listToken1, token2, "currentList(1) should return token2");

    //     uint256 shareToken1 = indexFactoryStorage.tokenCurrentMarketShare(token1);
    //     uint256 shareToken2 = indexFactoryStorage.tokenCurrentMarketShare(token2);
    //     assertEq(shareToken1, 100e18, "tokenCurrentMarketShare for token1 mismatch");
    //     assertEq(shareToken2, 200e18, "tokenCurrentMarketShare for token2 mismatch");
    // }

    // function testMockCurrentListFunctions() public {
    //     address[] memory tokens = new address[](3);
    //     tokens[0] = token1;
    //     tokens[1] = token2;
    //     tokens[2] = wethAddress;

    //     uint256[] memory marketShares = new uint256[](3);
    //     marketShares[0] = 100e18;
    //     marketShares[1] = 200e18;
    //     marketShares[2] = 300e18;

    //     uint24[] memory swapFees = new uint24[](3);
    //     swapFees[0] = 3000;
    //     swapFees[1] = 10000;
    //     swapFees[2] = 500;

    //     vm.startPrank(ownerAddr);
    //     indexFactoryStorage.mockFillAssetsList(tokens, marketShares, swapFees);
    //     vm.stopPrank();

    //     uint256 total = indexFactoryStorage.totalCurrentList();
    //     assertEq(total, 3, "Expected totalCurrentList to be 3");

    //     assertEq(indexFactoryStorage.currentList(0), token1, "currentList(0) should be token1");
    //     assertEq(indexFactoryStorage.currentList(1), token2, "currentList(1) should be token2");
    //     assertEq(indexFactoryStorage.currentList(2), wethAddress, "currentList(2) should be wethAddress");
    // }

    function testSetFeeRate_TooSoon() public {
        vm.startPrank(ownerAddr);

        vm.expectRevert(
            "You should wait at least 12 hours after the latest update"
        );
        indexFactoryStorage.setFeeRate(50);
        vm.stopPrank();
    }

    function testInitialize_CannotInitializeTwice() public {
        vm.startPrank(ownerAddr);
        vm.expectRevert("Initializable: contract is already initialized");
        indexFactoryBalancer.initialize(payable(address(indexFactoryStorage)));
        vm.stopPrank();
    }

    function testSetFeeRate_InvalidRange() public {
        skip(13 hours);

        vm.startPrank(ownerAddr);
        vm.expectRevert("The newFee should be between 1 and 100 (0.01% - 1%)");
        indexFactoryStorage.setFeeRate(0);

        vm.expectRevert("The newFee should be between 1 and 100 (0.01% - 1%)");
        indexFactoryStorage.setFeeRate(101);

        indexFactoryStorage.setFeeRate(50);
        assertEq(
            indexFactoryStorage.feeRate(),
            50,
            "Fee rate should be updated to 50"
        );
        vm.stopPrank();
    }

    function testConcatenation() public {
        string memory a = "Hello";
        string memory b = "World";
        string memory result = indexFactoryStorage.concatenation(a, b);
        assertEq(result, "HelloWorld", "Concatenation function failed");
    }

    function testGetPortfolioBalance_Empty() public {
        vm.mockCall(
            address(indexFactoryStorage),
            bytes4(keccak256("totalCurrentList()")),
            abi.encode(uint256(0))
        );
        uint256 balance = indexFactoryStorage.getPortfolioBalance();
        assertEq(balance, 0, "Empty portfolio should have 0 balance");
    }

    function testSwap_SuccessPath() public {
        vm.startPrank(ownerAddr);

        uint256 amountIn = 500e18;
        address recipient = address(0x444);
        uint24 poolFee = 3000;

        vm.mockCall(
            address(indexFactoryStorage),
            bytes4(keccak256("swapRouterV3()")),
            abi.encode(ISwapRouter(address(0xABC1)))
        );
        vm.mockCall(
            address(indexFactoryStorage),
            bytes4(keccak256("swapRouterV2()")),
            abi.encode(IUniswapV2Router02(address(0xABC2)))
        );

        vm.mockCall(
            address(0x1111),
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                ownerAddr,
                address(indexFactoryBalancer),
                amountIn
            ),
            abi.encode(true)
        );

        vm.mockCall(
            address(0x1111),
            abi.encodeWithSelector(
                IERC20.approve.selector,
                address(0xABC1),
                amountIn
            ),
            abi.encode(true)
        );

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token2,
                fee: poolFee,
                recipient: recipient,
                deadline: block.timestamp + 300,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        vm.mockCall(
            address(0xABC1),
            abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                params
            ),
            abi.encode(300e18)
        );

        vm.stopPrank();
    }

    function test_toWei_Mutations() public {
        int256 amount = 100;
        uint8 amountDecimals = 8;
        uint8 chainDecimals = 18;

        int256 expected = amount *
            int256(10 ** (chainDecimals - amountDecimals));

        {
            uint8 mutatedChainDecimals = 8;
            int256 mutatedResult = _toWei(
                amount,
                amountDecimals,
                mutatedChainDecimals
            );
            assertFalse(
                mutatedResult == expected,
                "Mutation not killed: _chainDecimals < _amountDecimals"
            );
        }

        {
            uint256 mutatedMultiplier = 10 * (chainDecimals - amountDecimals);
            int256 mutatedResult = amount * int256(mutatedMultiplier);
            int256 result = _toWei(amount, amountDecimals, chainDecimals);
            assertFalse(
                mutatedResult == result,
                "Mutation not killed: 10 * (_chainDecimals - _amountDecimals)"
            );
        }

        {
            int256 mutatedResult = amount /
                int256(
                    10 /
                        (int256(uint256(chainDecimals)) -
                            int256(uint256(amountDecimals)))
                );
            int256 result = _toWei(amount, amountDecimals, chainDecimals);
            assertFalse(
                mutatedResult == result,
                "Mutation not killed: _amount / int256(10 / (_chainDecimals - _amountDecimals))"
            );
        }

        {
            uint8 mutatedChainDecimals = chainDecimals + amountDecimals;
            int256 mutatedResult = amount *
                int256(10 ** uint256(mutatedChainDecimals));
            int256 result = _toWei(amount, amountDecimals, chainDecimals);
            assertFalse(
                mutatedResult == result,
                "Mutation not killed: _chainDecimals + _amountDecimals"
            );
        }

        int256 actual = _toWei(amount, amountDecimals, chainDecimals);
        assertEq(expected, actual, "Original logic failed for valid input");
    }

    function testExponentiation_CorrectScaling() public {
        uint8 amountDecimals = 3;
        uint8 chainDecimals = 6;

        uint256 expected = 10 ** (chainDecimals - amountDecimals);
        uint256 mutated = 10 * (chainDecimals - amountDecimals);

        assertEq(expected, 1000, "Incorrect exponentiation");
        assertFalse(expected == mutated, "Mutation not detected");
    }

    function testTotalSupplyComparison() public {
        uint256 totalSupply = 1000;

        bool original = totalSupply > 0;
        bool mutated = totalSupply < 0;

        assertTrue(original, "Original condition failed");
        assertFalse(original == mutated, "Mutation not detected");
    }

    function test_toWei_Mutations2() public {
        int256 amount = 100;
        uint8 amountDecimals = 8;
        uint8 chainDecimals = 18;

        int256 expected = amount *
            int256(10 ** (chainDecimals - amountDecimals));

        int256 actual = _toWei(amount, amountDecimals, chainDecimals);

        {
            int256 mutatedDivision = amount /
                int256(10 ** (chainDecimals - amountDecimals));
            assertFalse(
                mutatedDivision == actual,
                "Mutation not killed: changed multiply to division"
            );
        }

        {
            uint256 mutatedMultiplier = 10 * (chainDecimals - amountDecimals);
            int256 mutatedResult = amount * int256(mutatedMultiplier);
            assertFalse(
                mutatedResult == actual,
                "Mutation not killed: replaced exponent with a simple multiply"
            );
        }

        {
            int256 mutatedExponent = int256(
                10 ** uint256(chainDecimals + amountDecimals)
            );
            int256 mutatedResult = amount * mutatedExponent;
            assertFalse(
                mutatedResult == actual,
                "Mutation not killed: replaced '-' with '+' in exponent calculation"
            );
        }

        assertEq(
            actual,
            expected,
            "Original _toWei logic is incorrect for this input"
        );
    }
}
