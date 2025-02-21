// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../contracts/vault/Vault.sol";
import "./OlympixUnitTest.sol";
import "../mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultTest is Test {
    Vault vault;
    MockERC20 token;

    event FundsWithdrawn(address token, address to, uint256 amount);

    function setUp() external {
        // vault = new Vault();
        // vault.initialize();
        Vault vaultImpl = new Vault();
        vault = Vault(
            payable(
                address(
                    new ERC1967Proxy(
                        address(vaultImpl),
                        abi.encodeCall(Vault.initialize, ())
                    )
                )
            )
        );
        token = new MockERC20("Test", "TST");
        token.mint(address(this), 10000e18);
    }

    function test_withdrawFunds_FailWhenCallerIsNotOperator() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        address token = address(0x2);
        address to = address(0x3);
        uint256 amount = 1 ether;

        vm.startPrank(address(0x4));
        vm.expectRevert("NexVault: caller is not an operator");
        vault.withdrawFunds(token, to, amount);
        vm.stopPrank();
    }
    function test_transferOwnerShip() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        address newOwner = address(0x4);
        vault.transferOwnership(newOwner);
        assertEq(vault.owner(), newOwner);
    }

    function test_renounceOwnerShip() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        vault.renounceOwnership();
        assertEq(vault.owner(), address(0));
    }
    
    function test_withdrawFunds_FailWhenTokenAddressIsZero() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        address token = address(0);
        address to = address(0x3);
        uint256 amount = 1 ether;

        vm.startPrank(operator);
        vm.expectRevert("NexVault: token address is zero");
        vault.withdrawFunds(token, to, amount);
        vm.stopPrank();
    }

    function test_withdrawFunds_FailWhenRecipientAddressIsZero() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        address token = address(0x2);
        address to = address(0);
        uint256 amount = 1 ether;

        vm.startPrank(operator);
        vm.expectRevert("NexVault: recipient address is zero");
        vault.withdrawFunds(token, to, amount);
        vm.stopPrank();
    }

    function test_withdrawFunds_FailWhenAmountIsZero() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        address token = address(0x2);
        address to = address(0x3);
        uint256 amount = 0;

        vm.startPrank(operator);
        vm.expectRevert("NexVault: amount is zero");
        vault.withdrawFunds(token, to, amount);
        vm.stopPrank();
    }

    function testWithdrawFundsSuccessfully() public {
        uint256 initialAmount = 1000e18;
        // address token = address(0x2);
        address to = address(0x3);
        uint256 amount = initialAmount;

        deal(address(token), address(vault), initialAmount);

        address operator = address(0x1);
        vault.setOperator(operator, true);

        uint256 userBalanceBeforeWithdraw = IERC20(token).balanceOf(to);

        vm.startPrank(operator);
        vault.withdrawFunds(address(token), to, amount);
        vm.stopPrank();

        uint256 userBalanceAfterWithdraw = IERC20(token).balanceOf(to);

        assertGt(userBalanceAfterWithdraw, userBalanceBeforeWithdraw);
    }

    function testSetOperator() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);
        assertTrue(vault.isOperator(operator), "Operator should be set");

        vault.setOperator(operator, false);
        assertFalse(vault.isOperator(operator), "Operator should be unset");
    }

    function testWithdrawFunds_OperatorCanWithdraw() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        uint256 initialAmount = 1000e18;
        address to = address(0x3);
        uint256 amount = initialAmount;

        deal(address(token), address(vault), initialAmount);

        uint256 userBalanceBeforeWithdraw = IERC20(token).balanceOf(to);

        vm.startPrank(operator);
        vault.withdrawFunds(address(token), to, amount);
        vm.stopPrank();

        uint256 userBalanceAfterWithdraw = IERC20(token).balanceOf(to);

        assertEq(userBalanceAfterWithdraw, userBalanceBeforeWithdraw + amount, "Withdraw amount mismatch");
    }

    function testWithdrawFunds_EmitEvent() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        uint256 initialAmount = 1000e18;
        address to = address(0x3);
        uint256 amount = initialAmount;

        deal(address(token), address(vault), initialAmount);

        vm.startPrank(operator);
        vm.expectEmit(true, true, true, true);
        emit FundsWithdrawn(address(token), to, amount);
        vault.withdrawFunds(address(token), to, amount);
        vm.stopPrank();
    }

    function testWithdrawFunds_FailOnTransferFailure() public {
        address operator = address(0x1);
        vault.setOperator(operator, true);

        uint256 initialAmount = 1000e18;
        address to = address(0x3);
        uint256 amount = initialAmount;

        deal(address(token), address(vault), initialAmount);

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount),
            abi.encode(false)
        );

        vm.startPrank(operator);
        vm.expectRevert("SafeERC20: ERC20 operation did not succeed");
        vault.withdrawFunds(address(token), to, amount);
        vm.stopPrank();
    }
}