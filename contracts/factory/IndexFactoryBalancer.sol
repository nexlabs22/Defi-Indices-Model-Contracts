// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../token/IndexToken.sol";
import "../proposable/ProposableOwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./IPriceOracle.sol";
import "../libraries/SwapHelpers.sol";
import "./IndexFactoryStorage.sol";

/// @title Index Token
/// @author NEX Labs Protocol
/// @notice The main token contract for Index Token (NEX Labs Protocol)
/// @dev This contract uses an upgradeable pattern
contract IndexFactoryBalancer is
    ContextUpgradeable,
    ProposableOwnableUpgradeable,
    PausableUpgradeable
{
    IndexFactoryStorage public factoryStorage;

    event Rebalanced(uint indexed time);

    modifier onlyOwnerOrOperator() {
        require(
            _msgSender() == owner() || factoryStorage.isOperator(_msgSender()),
            "Caller is not owner or operator"
        );
        _;
    }

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _factoryStorage The address of the Uniswap V2 factory.
     */
    function initialize(address payable _factoryStorage) external initializer {
        require(
            _factoryStorage != address(0),
            "Invalid factory storage address"
        );
        __Ownable_init();
        __Pausable_init();
        factoryStorage = IndexFactoryStorage(_factoryStorage);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Converts an amount to Wei based on the given decimals.
     * @param _amount The amount to convert.
     * @param _amountDecimals The decimals of the amount.
     * @param _chainDecimals The decimals of the chain.
     * @return The amount in Wei.
     */
    function _toWei(
        int256 _amount,
        uint8 _amountDecimals,
        uint8 _chainDecimals
    ) internal pure returns (int256) {
        if (_chainDecimals > _amountDecimals) {
            return _amount * int256(10 ** (_chainDecimals - _amountDecimals));
        } else {
            return _amount * int256(10 ** (_amountDecimals - _chainDecimals));
        }
    }

    /**
     * @dev The contract's fallback function that does not allow direct payments to the contract.
     * @notice Prevents users from sending ether directly to the contract by reverting the transaction.
     */
    receive() external payable {
        revert("DoNotSendFundsDirectlyToTheContract");
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function setFactoryStorage(address _factoryStorage) external onlyOwner {
        require(
            _factoryStorage != address(0),
            "Invalid factory storage address"
        );
        factoryStorage = IndexFactoryStorage(_factoryStorage);
    }

    /**
     * @dev Internal function to swap tokens.
     * @param path The path of the swap.
     * @param fees The fees of the swap.
     * @param amountIn The amount of input token.
     * @param _recipient The address of the recipient.
     * @return outputAmount The amount of output token.
     */
    function swap(
        address[] memory path,
        uint24[] memory fees,
        uint256 amountIn,
        address _recipient
    ) internal returns (uint256 outputAmount) {
        ISwapRouter swapRouterV3 = factoryStorage.swapRouterV3();
        IUniswapV2Router02 swapRouterV2 = factoryStorage.swapRouterV2();
        uint256 amountOutMinimum = factoryStorage.getMinAmountOut(path, fees, amountIn);
        // Ensure the transfer is successful
        outputAmount = SwapHelpers.swap(
            swapRouterV3,
            swapRouterV2,
            path,
            fees,
            amountIn,
            amountOutMinimum,
            _recipient
        );
    }

    /**
     * @dev Reindexes and reweights the portfolio.
     */
    function reIndexAndReweight() public onlyOwnerOrOperator {
        IWETH weth = factoryStorage.weth();
        Vault vault = factoryStorage.vault();
        uint256 totalCurrentList = factoryStorage.totalCurrentList();
        uint256 totalOracleList = factoryStorage.totalOracleList();
        for (uint256 i; i < totalCurrentList; i++) {
            address tokenAddress = factoryStorage.currentList(i);
            (
                address[] memory toETHPath,
                uint24[] memory toETHFees
            ) = factoryStorage.getToETHPathData(tokenAddress);
            uint256 tokenBalance = IERC20(tokenAddress).balanceOf(
                address(vault)
            );
            if (tokenAddress != address(weth)) {
                bool success = vault.withdrawFunds(
                    tokenAddress,
                    address(this),
                    tokenBalance
                );
                require(success, "Vault withdrawal failed");
                uint256 outputAmount = swap(
                    toETHPath,
                    toETHFees,
                    tokenBalance,
                    address(this)
                );
                require(outputAmount > 0, "Swap failed");
            }
        }
        uint256 wethBalance = weth.balanceOf(address(this));
        for (uint256 i; i < totalOracleList; i++) {
            address tokenAddress = factoryStorage.oracleList(i);
            (
                address[] memory fromETHPath,
                uint24[] memory fromETHFees
            ) = factoryStorage.getFromETHPathData(tokenAddress);
            uint256 tokenOracleMarketShare = factoryStorage
                .tokenOracleMarketShare(tokenAddress);
            if (tokenAddress != address(weth)) {
                uint256 outputAmount = swap(
                    fromETHPath,
                    fromETHFees,
                    (wethBalance * tokenOracleMarketShare) / 100e18,
                    address(vault)
                );
                require(outputAmount > 0, "Swap failed");
            }
        }
        //update current list
        factoryStorage.updateCurrentList();
        emit Rebalanced(block.timestamp);
    }
}
