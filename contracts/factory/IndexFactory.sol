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
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IWETH.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./IPriceOracle.sol";
import "../libraries/SwapHelpers.sol";
import "./IndexFactoryStorage.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title Index Token
/// @author NEX Labs Protocol
/// @notice The main token contract for Index Token (NEX Labs Protocol)
/// @dev This contract uses an upgradeable pattern
contract IndexFactory is
    ContextUpgradeable,
    ProposableOwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    IndexFactoryStorage public factoryStorage;

    event Issuanced(
        address indexed user,
        address indexed inputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 price,
        uint256 time
    );

    event Redemption(
        address indexed user,
        address indexed outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 price,
        uint256 time
    );

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
        __ReentrancyGuard_init();
        factoryStorage = IndexFactoryStorage(_factoryStorage);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    
    receive() external payable {
        
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
     * @param path The path of the tokens to swap.
     * @param fees The fees of the tokens to swap.
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

    function _mintIndexTokensForIssuance(
        uint256 _wethAmount,
        uint256 _firstPortfolioValue,
        uint256 _secondPortfolioValue
    ) internal returns (uint256 amountToMint) {
        //mint index tokens
        IndexToken indexToken = factoryStorage.indexToken();
        uint256 totalSupply = indexToken.totalSupply();
        if (totalSupply > 0) {
            uint256 newTotalSupply = (totalSupply * _secondPortfolioValue) /
                _firstPortfolioValue;
            amountToMint = newTotalSupply - totalSupply;
        } else {
            uint256 price = factoryStorage.priceInWei();
            amountToMint = (_wethAmount * price) / 1e16;
        }
        indexToken.mint(msg.sender, amountToMint);
    }

    function _issuance(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _totalCurrentList,
        Vault _vault,
        uint256 _wethAmount,
        uint256 _firstPortfolioValue
    ) internal {
        IWETH weth = factoryStorage.weth();
        //swap
        for (uint256 i = 0; i < _totalCurrentList; i++) {
            address tokenAddress = factoryStorage.currentList(i);
            uint256 marketShare = factoryStorage.tokenCurrentMarketShare(
                tokenAddress
            );
            (
                address[] memory fromETHPath,
                uint24[] memory fromETHFees
            ) = factoryStorage.getFromETHPathData(tokenAddress);
            if (tokenAddress != address(weth)) {
                uint256 outputAmount = swap(
                    fromETHPath,
                    fromETHFees,
                    (_wethAmount * marketShare) / 100e18,
                    address(_vault)
                );
                require(outputAmount > 0, "Swap failed");
            } else {
                weth.transfer(
                    address(_vault),
                    (_wethAmount * marketShare) / 100e18
                );
            }
        }
        uint256 secondPortfolioValue = factoryStorage.getPortfolioBalance();
        //mint index tokens
        uint256 amountToMint = _mintIndexTokensForIssuance(
            _wethAmount,
            _firstPortfolioValue,
            secondPortfolioValue
        );
        emit Issuanced(
            msg.sender,
            _tokenIn,
            _amountIn,
            amountToMint,
            factoryStorage.getIndexTokenPrice(),
            block.timestamp
        );
    }

    /**
     * @dev Issues index tokens by swapping the input token.
     * @param _tokenIn The address of the input token.
     * @param _tokenInPath The path of the input token.
     * @param _tokenInFees The fees of the input token.
     * @param _amountIn The amount of input token.
     */
    function issuanceIndexTokens(
        address _tokenIn,
        address[] memory _tokenInPath,
        uint24[] memory _tokenInFees,
        uint256 _amountIn
    ) public whenNotPaused nonReentrant {
        require(_tokenIn != address(0), "Invalid token address");
        require(_amountIn > 0, "Invalid amount");
        IWETH weth = factoryStorage.weth();
        Vault vault = factoryStorage.vault();
        uint256 totalCurrentList = factoryStorage.totalCurrentList();
        uint256 feeRate = factoryStorage.feeRate();
        uint256 feeAmount = (_amountIn * feeRate) / 10000;

        uint256 firstPortfolioValue = factoryStorage.getPortfolioBalance();
        
        IERC20(_tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            _amountIn + feeAmount
        );
        
        uint256 wethAmountBeforFee = swap(
            _tokenInPath,
            _tokenInFees,
            _amountIn + feeAmount,
            address(this)
        );
        address feeReceiver = factoryStorage.feeReceiver();
        uint256 feeWethAmount = (wethAmountBeforFee * feeRate) / 10000;
        uint256 wethAmount = wethAmountBeforFee - feeWethAmount;

        //giving fee to the fee receiver
        require(
            weth.transfer(address(feeReceiver), feeWethAmount),
            "fee transfer failed"
        );
        _issuance(
            _tokenIn,
            _amountIn,
            totalCurrentList,
            vault,
            wethAmount,
            firstPortfolioValue
        );
    }

    /**
     * @dev Issues index tokens with ETH.
     * @param _inputAmount The amount of ETH input.
     */
    function issuanceIndexTokensWithEth(
        uint256 _inputAmount
    ) public payable whenNotPaused nonReentrant {
        require(_inputAmount > 0, "Invalid amount");
        Vault vault = factoryStorage.vault();
        IWETH weth = factoryStorage.weth();
        address feeReceiver = factoryStorage.feeReceiver();
        uint256 feeRate = factoryStorage.feeRate();
        uint256 feeAmount = (_inputAmount * feeRate) / 10000;
        uint256 finalAmount = _inputAmount + feeAmount;
        require(msg.value == finalAmount, "lower or more than required amount");
        weth.deposit{value: finalAmount}();
        require(
            weth.transfer(address(feeReceiver), feeAmount),
            "fee transfer failed"
        );
        uint256 totalCurrentList = factoryStorage.totalCurrentList();
        uint256 firstPortfolioValue = factoryStorage.getPortfolioBalance();
        _issuance(
            address(weth),
            _inputAmount,
            totalCurrentList,
            vault,
            _inputAmount,
            firstPortfolioValue
        );
    }

    function _swapToOutputToken(
        uint256 _amountIn,
        uint256 _outputAmount,
        address _tokenOut,
        address[] memory _tokenOutPath,
        uint24[] memory _tokenOutFees,
        uint256 feeRate,
        address feeReceiver
    ) internal returns (uint256 realOut) {
        IWETH weth = factoryStorage.weth();
        uint256 ownerFee = (_outputAmount * feeRate) / 10000;
        if (_tokenOut == address(weth)) {
            weth.withdraw(_outputAmount - ownerFee);
            weth.transfer(address(feeReceiver), ownerFee);
            (bool _userSuccess, ) = payable(msg.sender).call{
                value: _outputAmount - ownerFee
            }("");
            require(_userSuccess, "transfer eth fee to the user failed");
            emit Redemption(
                msg.sender,
                _tokenOut,
                _amountIn,
                _outputAmount - ownerFee,
                factoryStorage.getIndexTokenPrice(),
                block.timestamp
            );
            return _outputAmount - ownerFee;
        } else {
            weth.transfer(address(feeReceiver), ownerFee);
            uint256 realOut = swap(
                _tokenOutPath,
                _tokenOutFees,
                _outputAmount - ownerFee,
                msg.sender
            );
            emit Redemption(
                msg.sender,
                _tokenOut,
                _amountIn,
                realOut,
                factoryStorage.getIndexTokenPrice(),
                block.timestamp
            );
            return realOut;
        }
    }

    function _redemptionSwaps(
        uint256 _burnPercent,
        uint256 _totalCurrentList,
        Vault _vault
    ) internal returns (uint256 outputAmount) {
        IWETH weth = factoryStorage.weth();
        for (uint256 i = 0; i < _totalCurrentList; i++) {
            address tokenAddress = factoryStorage.currentList(i);
            (
                address[] memory toETHPath,
                uint24[] memory toETHFees
            ) = factoryStorage.getToETHPathData(tokenAddress);
            uint256 swapAmount = (_burnPercent *
                IERC20(tokenAddress).balanceOf(address(_vault))) / 1e18;
            if (tokenAddress != address(weth)) {
                _vault.withdrawFunds(tokenAddress, address(this), swapAmount);
                uint256 swapAmountOut = swap(
                    toETHPath,
                    toETHFees,
                    swapAmount,
                    address(this)
                );
                outputAmount += swapAmountOut;
            } else {
                _vault.withdrawFunds(address(weth), address(this), swapAmount);
                outputAmount += swapAmount;
            }
        }
    }

    function _redemption(
        uint256 _totalCurrentList,
        Vault _vault,
        uint256 _burnPercent,
        address _tokenOut,
        address[] memory _tokenOutPath,
        uint24[] memory _tokenOutFees,
        uint256 feeRate,
        address feeReceiver
    ) internal returns (uint256 realOut) {
        IndexToken indexToken = factoryStorage.indexToken();
        uint256 outputAmount;
        //swap
        outputAmount = _redemptionSwaps(
            _burnPercent,
            _totalCurrentList,
            _vault
        );
        realOut = _swapToOutputToken(
            _burnPercent,
            outputAmount,
            _tokenOut,
            _tokenOutPath,
            _tokenOutFees,
            feeRate,
            feeReceiver
        );
    }

    /**
     * @dev Redeems index tokens for the specified output token.
     * @param amountIn The amount of index tokens to redeem.
     * @param _tokenOut The address of the output token.
     * @param _tokenOutPath The path of the output token.
     * @param _tokenOutFees The fees of the output token.
     */
    function redemption(
        uint256 amountIn,
        address _tokenOut,
        address[] memory _tokenOutPath,
        uint24[] memory _tokenOutFees
    ) public whenNotPaused nonReentrant returns (uint256) {
        Vault vault = factoryStorage.vault();
        uint256 totalCurrentList = factoryStorage.totalCurrentList();
        uint256 feeRate = factoryStorage.feeRate();
        address feeReceiver = factoryStorage.feeReceiver();
        IndexToken indexToken = factoryStorage.indexToken();
        uint256 burnPercent = (amountIn * 1e18) / indexToken.totalSupply();

        indexToken.burn(msg.sender, amountIn);

        uint256 realOut = _redemption(
            factoryStorage.totalCurrentList(),
            vault,
            burnPercent,
            _tokenOut,
            _tokenOutPath,
            _tokenOutFees,
            feeRate,
            feeReceiver
        );

        return realOut;
    }
}
