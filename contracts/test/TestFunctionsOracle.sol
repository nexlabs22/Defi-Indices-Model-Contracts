// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../token/IndexToken.sol";
import "../proposable/ProposableOwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "../chainlink/FunctionsClient.sol";
import "../chainlink/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../factory/IPriceOracle.sol";
import "../vault/Vault.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title Index Token
/// @author NEX Labs Protocol
/// @notice The main token contract for Index Token (NEX Labs Protocol)
/// @dev This contract uses an upgradeable pattern
contract TestFunctionsOracle is
    Initializable,
    FunctionsClient,
    ConfirmedOwner,
    ContextUpgradeable,
    PausableUpgradeable
{
    using FunctionsRequest for FunctionsRequest.Request;

    IndexToken public indexToken;

    uint256 public fee;
    uint8 public feeRate; // 10/10000 = 0.1%
    uint256 public latestFeeUpdate;
    // Address that can claim fees accrued.
    address public feeReceiver;

    bytes32 public donId; // DON ID for the Functions DON to which the requests are sent
    address public functionsRouterAddress;
    string baseUrl;
    string urlParams;

    address public priceOracle;
    AggregatorV3Interface public toUsdPriceFeed;
    uint256 public lastUpdateTime;

    uint256 public totalOracleList;
    uint256 public totalCurrentList;

    mapping(uint256 => address) public oracleList;
    mapping(uint256 => address) public currentList;

    mapping(address => uint256) public tokenOracleListIndex;
    mapping(address => uint256) public tokenCurrentListIndex;

    mapping(address => uint256) public tokenCurrentMarketShare;
    mapping(address => uint256) public tokenOracleMarketShare;

    mapping(address => address[]) public fromETHPath;
    mapping(address => address[]) public toETHPath;
    mapping(address => uint24[]) public fromETHFees;
    mapping(address => uint24[]) public toETHFees;

    address public factoryAddress;
    address public factoryBalancerAddress;
    ISwapRouter public swapRouterV3;
    IUniswapV3Factory public factoryV3;
    IUniswapV2Router02 public swapRouterV2;
    IUniswapV2Factory public factoryV2;
    IWETH public weth;
    IQuoter public quoter;
    Vault public vault;

    //slipage tolerance
    uint256 public slippageTolerance; // 2000/10000 = 20%

    event FeeReceiverSet(address indexed feeReceiver);
    event VaultSet(address indexed vault);

    /**
     * @dev Throws if the caller is not a factory contract.
     */
    modifier onlyFactory() {
        require(
            msg.sender == factoryAddress || msg.sender == factoryBalancerAddress, "Caller is not a factory contract"
        );
        _;
    }

   
    function initialize(
        address _functionsRouterAddress,
        bytes32 _newDonId
    ) external initializer {
        
        require(_newDonId.length > 0, "Don ID cannot be empty");
        require(_functionsRouterAddress != address(0), "functions router address cannot be zero address");
        
        // __Ownable_init();
        __Pausable_init();
        __FunctionsClient_init(_functionsRouterAddress);
        __ConfirmedOwner_init(msg.sender);
        donId = _newDonId;
        
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function setSlippageTolerance(uint256 _slippageTolerance) public onlyOwner {
        slippageTolerance = _slippageTolerance;
    }

    function setFactory(address _factoryAddress) public onlyOwner {
        factoryAddress = _factoryAddress;
    }

    function setFactoryBalancer(address _factoryBalancerAddress) public onlyOwner {
        factoryBalancerAddress = _factoryBalancerAddress;
    }
    /**
     * @dev Sets the fee receiver address.
     * @param _feeReceiver The address of the fee receiver.
     */

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
        emit FeeReceiverSet(_feeReceiver);
    }

    function setFunctionsRouter(address _functionsRouterAddress) public onlyOwner {
        functionsRouterAddress = _functionsRouterAddress;
    }



    /**
     * @dev Sets the vault address.
     * @param _vaultAddress The address of the vault.
     */
    function setVault(address _vaultAddress) public onlyOwner {
        vault = Vault(_vaultAddress);
        emit VaultSet(_vaultAddress);
    }

    function setIndexToken(address _indexToken) public onlyOwner {
        indexToken = IndexToken(_indexToken);
    }

    /**
     * @notice Set the DON ID
     * @param newDonId New DON ID
     */
    function setDonId(bytes32 newDonId) external onlyOwner {
        donId = newDonId;
    }

    /**
     * @dev Sets the price feed address of the native coin to USD from the Chainlink oracle.
     * @param _toUsdPricefeed The address of native coin to USD price feed.
     */
    function setPriceFeed(address _toUsdPricefeed) external onlyOwner {
        require(_toUsdPricefeed != address(0), "ICO: Price feed address cannot be zero address");
        toUsdPriceFeed = AggregatorV3Interface(_toUsdPricefeed);
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        require(_priceOracle != address(0), "Price oracle address cannot be zero address");
        priceOracle = _priceOracle;
    }

    function setUniswapV3Router(address _swapRouterV3) external onlyOwner {
        require(
            _swapRouterV3 != address(0),
            "Swap router V3 address cannot be zero address"
        );
        swapRouterV3 = ISwapRouter(_swapRouterV3);
    }

    function setUniswapV3Factory(address _factoryV3) external onlyOwner {
        require(
            _factoryV3 != address(0),
            "Factory V3 address cannot be zero address"
        );
        factoryV3 = IUniswapV3Factory(_factoryV3);
    }

    function setUniswapV2Router(address _swapRouterV2) external onlyOwner {
        require(
            _swapRouterV2 != address(0),
            "Swap router V2 address cannot be zero address"
        );
        swapRouterV2 = IUniswapV2Router02(_swapRouterV2);
    }

    function setUniswapV2Factory(address _factoryV2) external onlyOwner {
        require(
            _factoryV2 != address(0),
            "Factory V2 address cannot be zero address"
        );
        factoryV2 = IUniswapV2Factory(_factoryV2);
    }

    function setWETH(address _weth) external onlyOwner {
        require(_weth != address(0), "WETH address cannot be zero address");
        weth = IWETH(_weth);
    }

    function setQuoter(address _quoter) external onlyOwner {
        require(_quoter != address(0), "Quoter address cannot be zero address");
        quoter = IQuoter(_quoter);
    }

    /**
     * @dev Converts an amount to Wei based on the given decimals.
     * @param _amount The amount to convert.
     * @param _amountDecimals The decimals of the amount.
     * @param _chainDecimals The decimals of the chain.
     * @return The amount in Wei.
     */
    function _toWei(int256 _amount, uint8 _amountDecimals, uint8 _chainDecimals) internal pure returns (int256) {
        if (_chainDecimals > _amountDecimals) {
            return _amount * int256(10 ** (_chainDecimals - _amountDecimals));
        } else {
            return _amount * int256(10 ** (_amountDecimals - _chainDecimals));
        }
    }

    /**
     * @dev Returns the price in Wei.
     * @return The price in Wei.
     */
    function priceInWei() public view returns (uint256) {
        (uint80 roundId,int price,,uint256 _updatedAt,) = toUsdPriceFeed.latestRoundData();
        require(roundId != 0, "invalid round id");
        require(_updatedAt != 0 && _updatedAt <= block.timestamp, "invalid updated time");
        require(price > 0, "invalid price");
        require(block.timestamp - _updatedAt < 1 days, "invalid updated time");

        uint8 priceFeedDecimals = toUsdPriceFeed.decimals();
        price = _toWei(price, priceFeedDecimals, 18);
        return uint256(price);
    }

    /**
     * @dev Sets the fee rate. The new fee should be between 1 to 100 (0.01% - 1%).
     * @param _newFee The new fee rate.
     */
    //Notice: newFee should be between 1 to 100 (0.01% - 1%)
    function setFeeRate(uint8 _newFee) public onlyOwner {
        uint256 distance = block.timestamp - latestFeeUpdate;
        require(distance / 60 / 60 >= 12, "You should wait at least 12 hours after the latest update");
        require(_newFee <= 100 && _newFee >= 1, "The newFee should be between 1 and 100 (0.01% - 1%)");
        feeRate = _newFee;
        latestFeeUpdate = block.timestamp;
    }


    /**
     * @dev Sets the base URL and URL parameters.
     * @param _beforeAddress The base URL.
     * @param _afterAddress The URL parameters.
     */
    function setUrl(string memory _beforeAddress, string memory _afterAddress) public onlyOwner {
        baseUrl = _beforeAddress;
        urlParams = _afterAddress;
    }

    function requestAssetsData(
        string calldata source,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) public returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        return _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
    }

    /**
     * @notice Store latest result/error
     * @param requestId The request ID, returned by sendRequest()
     * @param response Aggregated response from the user code
     * @param err Aggregated error from the user code or from the execution pipeline
     * Either response or error parameter will be set, but never both
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        (address[] memory _tokens, uint256[] memory _marketShares) =
            abi.decode(response, (address[], uint256[]));
        require(
            _tokens.length == _marketShares.length,
            "The length of the arrays should be the same"
        );
        _initData(_tokens, _marketShares);
    }

    function _initData(address[] memory tokens0, uint256[] memory marketShares0) internal {
        //save mappings
        for (uint256 i = 0; i < tokens0.length; i++) {
            oracleList[i] = tokens0[i];
            tokenOracleListIndex[tokens0[i]] = i;
            tokenOracleMarketShare[tokens0[i]] = marketShares0[i];
        
            if (totalCurrentList == 0) {
                currentList[i] = tokens0[i];
                tokenCurrentMarketShare[tokens0[i]] = marketShares0[i];
                tokenCurrentListIndex[tokens0[i]] = i;
            }
        }
        totalOracleList = tokens0.length;
        if (totalCurrentList == 0) {
            totalCurrentList = tokens0.length;
        }
        lastUpdateTime = block.timestamp;
    }

    function updatePathData(address[] memory tokens, bytes[] memory pathBytes) public onlyOwner {
        require(
            tokens.length == pathBytes.length,
            "The length of the tokens and pathBytes arrays should be the same"
        );
        for(uint256 i = 0; i < tokens.length; i++) {
            _initPathData(tokens[i], pathBytes[i]);
        }
    }

    function _initPathData(address _tokenAddress, bytes memory _pathBytes) internal {
        // decode pathBytes to get fromETHPath and fromETHFees
        (address[] memory _fromETHPath, uint24[] memory _fromETHFees) = abi.decode(_pathBytes, (address[], uint24[]));
        require(_fromETHPath.length == _fromETHFees.length + 1, "Invalid input arrays");
        fromETHPath[_tokenAddress] = _fromETHPath;
        fromETHFees[_tokenAddress] = _fromETHFees;
        // update toETHPath and toETHFees
        address[] memory _toETHPath = reverseAddressArray(_fromETHPath);
        uint24[] memory _toETHFees = reverseUint24Array(_fromETHFees);
        toETHPath[_tokenAddress] = _toETHPath;
        toETHFees[_tokenAddress] = _toETHFees;
    }

    function reverseUint24Array(uint24[] memory input) public pure returns (uint24[] memory) {
        uint256 length = input.length;

        for (uint256 i = 0; i < length / 2; i++) {
            // Swap elements
            (input[i], input[length - 1 - i]) = (input[length - 1 - i], input[i]);
        }

        return input;
    }

    function reverseAddressArray(address[] memory input) public pure returns (address[] memory) {
        uint256 length = input.length;

        for (uint256 i = 0; i < length / 2; i++) {
            // Swap elements
            (input[i], input[length - 1 - i]) = (input[length - 1 - i], input[i]);
        }

        return input;
    }

    

    function getFromETHPathData(address _tokenAddress) public view returns (address[] memory, uint24[] memory) {
        return (fromETHPath[_tokenAddress], fromETHFees[_tokenAddress]);
    }

    function getToETHPathData(address _tokenAddress) public view returns (address[] memory, uint24[] memory) {
        return (toETHPath[_tokenAddress], toETHFees[_tokenAddress]);
    }

    function updateCurrentList() external onlyFactory {
        totalCurrentList = totalOracleList;
        for (uint256 i = 0; i < totalOracleList; i++) {
            address tokenAddress = oracleList[i];
            currentList[i] = tokenAddress;
            tokenCurrentMarketShare[tokenAddress] = tokenOracleMarketShare[tokenAddress];
        }
    }

    /**
     * @dev Gets the amount out for a token swap.
     * @param path The path of the token swap.
     * @param fees The fees of the token swap.
     * @param amountIn The amount of input token.
     * @return finalAmountOut The amount of output token.
     */
    function getAmountOut(address[] memory path, uint24[] memory fees, uint256 amountIn)
        public
        view
        returns (uint256 finalAmountOut)
    {
        if (amountIn > 0) {
            if (fees.length > 0) {
                finalAmountOut = estimateAmountOutWithPath(path, fees, amountIn);
            } else {
                uint256[] memory v2amountOut = swapRouterV2.getAmountsOut(amountIn, path);
                finalAmountOut = v2amountOut[v2amountOut.length - 1];
            }
        }
        return finalAmountOut;
    }

    /**
     * @dev Gets the minimum amount out.
     * @return The minimum amount out.
     */
    function getMinAmountOut(address[] memory path, uint24[] memory fees, uint256 amountIn) public view returns (uint256) {
        uint amountOut = getAmountOut(path, fees, amountIn);
        return (amountOut * (10000 - slippageTolerance)) / 10000;
    }

    function getIndexTokenPrice() public view returns (uint256) {
        uint256 portfoliaValue = getPortfolioBalance();
        uint256 totalSupply = indexToken.totalSupply();
        uint256 ethusdPrice = priceInWei();
        if (portfoliaValue == 0 || totalSupply == 0) {
            return 0;
        } else {
            return (portfoliaValue * ethusdPrice) / (totalSupply);
        }
    }

    /**
     * @dev Gets the portfolio balance in WETH.
     * @return The portfolio balance in WETH.
     */
    function getPortfolioBalance() public view returns (uint256) {
        uint256 totalValue;
        for (uint256 i = 0; i < totalCurrentList; i++) {
            address tokenAddress = currentList[i];
            if (tokenAddress == address(weth)) {
                totalValue += IERC20(tokenAddress).balanceOf(address(vault));
            } else {
                uint256 value = getAmountOut(
                    toETHPath[tokenAddress], toETHFees[tokenAddress], IERC20(tokenAddress).balanceOf(address(vault))
                );
                totalValue += value;
            }
        }
        return totalValue;
    }

    /**
     * @dev Estimates the amount out for a token swap using Uniswap V3.
     * @param tokenIn The address of the input token.
     * @param tokenOut The address of the output token.
     * @param amountIn The amount of input token.
     * @return amountOut The estimated amount of output token.
     */
    function estimateAmountOut(address tokenIn, address tokenOut, uint128 amountIn, uint24 swapFee)
        public
        view
        returns (uint256 amountOut)
    {
        amountOut =
            IPriceOracle(priceOracle).estimateAmountOut(address(factoryV3), tokenIn, tokenOut, amountIn, swapFee);
    }

    function estimateAmountOutWithPath(address[] memory path, uint24[] memory fees, uint256 amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        uint256 lastAmount = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            lastAmount = IPriceOracle(priceOracle).estimateAmountOut(
                address(factoryV3), path[i], path[i + 1], uint128(lastAmount), fees[i]
            );
        }
        amountOut = lastAmount;
    }
}
