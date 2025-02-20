import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IndexFactory} from "../../contracts/factory/IndexFactory.sol";
import {IndexToken} from "../../contracts/token/IndexToken.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OnchainTest is Script {
    IndexToken indexToken;

    // Mainnet
    address user = vm.envAddress("USER");
    address weth = vm.envAddress("ARBITRUM_WETH_ADDRESS");
    address usdt = vm.envAddress("ARBITRUM_USDC_ADDRESS");
    address indexFactoryProxy = vm.envAddress("ARBITRUM_INDEX_FACTORY_PROXY_ADDRESS");
    address indexTokenProxy = vm.envAddress("ARBITRUM_INDEX_TOKEN_PROXY_ADDRESS");

    // Testnet
    // address user = vm.envAddress("USER");
    // address weth = vm.envAddress("SEPOLIA_WETH_ADDRESS");
    // address usdt = vm.envAddress("SEPOLIA_USDT_ADDRESS");
    // address indexFactoryProxy = vm.envAddress("SEPOLIA_INDEX_FACTORY_PROXY_ADDRESS");
    // address indexTokenProxy = vm.envAddress("SEPOLIA_INDEX_TOKEN_PROXY_ADDRESS");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        indexToken = IndexToken(indexTokenProxy);

        // Issuance With ETH
        issuanceAndRedemptionWithEth();

        // Issuance with ERC20 Token
        issuanceAndRedemptionWithUsdt();

        vm.stopBroadcast();
    }

    function issuanceAndRedemptionWithEth() public {
        IndexFactory(payable(indexFactoryProxy)).issuanceIndexTokensWithEth{value: (1e14 * 1001) / 1000}(1e14);

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdt;
        uint24[] memory fees = new uint24[](1);
        fees[0] = 3000;

        IndexFactory(payable(indexFactoryProxy)).redemption(
            indexToken.balanceOf(address(user)), address(weth), path, fees
        );
    }

    function issuanceAndRedemptionWithUsdt() public {
        IERC20(usdt).approve(address(indexFactoryProxy), 1001e18);

        address[] memory path0 = new address[](2);
        path0[0] = usdt;
        path0[1] = weth;
        uint24[] memory fees0 = new uint24[](1);
        fees0[0] = 3000;

        IndexFactory(payable(indexFactoryProxy)).issuanceIndexTokens(address(usdt), path0, fees0, 100e18);

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdt;
        uint24[] memory fees = new uint24[](1);
        fees[0] = 3000;

        IndexFactory(payable(indexFactoryProxy)).redemption(
            indexToken.balanceOf(address(user)), address(weth), path, fees
        );
    }
}
