> **Arbitrum Ecosystem Index (ARBEI) Protocol**

This repository contains three core Solidity contracts that power the ARBEI product suite:

1. **IndexToken**
2. **IndexFactory (+ IndexFactoryBalancer)**
3. **Vault**

Below you’ll find an overview of each component, their roles, deployment addresses on Arbitrum, and detailed usage instructions (minting, issuance, redemption, re-indexing, and re-weighting).

---

## Table of Contents

1. [Protocol Overview](#protocol-overview)
2. [Contracts & Repositories](#contracts--repositories)

   * [IndexToken](#indextoken)
   * [IndexFactory](#indexfactory)
   * [IndexFactoryBalancer](#indexfactorybalancer)
   * [Vault](#vault)
3. [Deployment Addresses (ARBEI)](#deployment-addresses-arbei)
4. [High-Level Workflow](#high-level-workflow)

   * [Token Issuance (Minting)](#token-issuance-minting)
   * [Redemption (Burning)](#redemption-burning)
   * [Re-Indexing & Re-Weighting](#re-indexing--re-weighting)
5. [Integration Details](#integration-details)

   * [Inter-Contract Dependencies](#inter-contract-dependencies)
   * [Parameters & Fee Mechanisms](#parameters--fee-mechanisms)
6. [Getting Started (Developer Setup)](#getting-started-developer-setup)
7. [License](#license)

---

## Protocol Overview

ARBEI (Arbitrum Ecosystem Index) is a decentralized on-chain index product designed for native DeFi investors. It allows users to mint (issue) and redeem index tokens (ERC-20) against underlying baskets of assets, all in self-custody. Core features include:

* **Issuance (Minting):** Deposit USDC (or ETH) into a Vault, which swaps into the index’s constituent tokens via Uniswap V2/V3, then mints ERC-20 index tokens.
* **Redemption (Burning):** Burn index tokens to receive proportional share of underlying assets or a chosen output token (USDC, WETH, etc.).
* **Re-Indexing:** Adjust the Vault’s holdings by removing assets no longer in the index and adding newly included tokens.
* **Re-Weighting:** Periodically rebalance the Vault to match target weights from an oracle-provided list (e.g., market percentages).

This “DeFi model” is fully on-chain and governed via a set of upgradeable, permissioned contracts (ProposableOwnableUpgradeable) that enable operators (governance multisig or DAO) to update parameters, asset lists, and fee rates without redeploying the entire protocol.

---

## Contracts & Repositories

Below are the three primary contracts (each in its own repository). All contracts use Solidity 0.8.20 with OpenZeppelin’s upgradeable libraries and Uniswap interfaces.

### 1. IndexToken

**Path / Repo:** `contracts/IndexToken.sol`
**Purpose:**

* Implements the ERC-20 index token that represents a basket of underlying assets.
* Tracks protocol fees (inflation-based) that accrue daily to a `feeReceiver`.
* Restricts minting/burning to a designated `minter` (the IndexFactory contract).
* Allows toggling “restricted” addresses for compliance/blacklist.

**Key Features:**

* **`feeRatePerDayScaled`:** Daily fee rate (scaled by 1e20) that compounds once per day and mints new tokens to `feeReceiver`.
* **`supplyCeiling`:** Upper limit on total supply; cannot mint beyond this.
* **`methodologist`:** Address authorized to publish a new “methodology” string (on-chain documentation).
* **`mint(address to, uint256 amount)` / `burn(address from, uint256 amount)`:** Only callable by `minter` (set typically to IndexFactory).
* **Overridden `transfer` / `transferFrom`:** Prevent transfers if either `msg.sender` or `to`/`from` is “restricted.”

**Initialization:**

```solidity
function initialize(
    string memory tokenName,
    string memory tokenSymbol,
    uint256 _feeRatePerDayScaled,
    address _feeReceiver,
    uint256 _supplyCeiling
) external initializer { … }
```

### 2. IndexFactory

**Path / Repo:** `contracts/IndexFactory.sol`
**Purpose:**

* Core issuance and redemption logic for the index token.
* Handles swapping input tokens (USDC or ETH) via Uniswap V2/V3, distributing underlying assets into a Vault, and minting new IndexTokens.
* Handles redemption by burning IndexTokens, swapping underlying assets back to a specified output token, and transferring proceeds to the user.
* Maintains pause/unpause, operator roles (via `factoryStorage.isOperator(...)`), and non-reentrancy.

**Key Functions:**

* **`initialize(address payable _factoryStorage)`:** Set the `IndexFactoryStorage` address.
* **`issuanceIndexTokens(address _tokenIn, address[] memory _path, uint24[] memory _fees, uint256 _amountIn)`:**

  1. Transfer `_amountIn + feeAmount` from user to this contract.
  2. Swap on Uniswap (V2 or V3) into WETH.
  3. Deduct `feeRate` (in basis points) => send fee in WETH to `feeReceiver`.
  4. Call internal `_issuance(...)` to swap WETH into each asset as per the current index weights, deposit into Vault, and mint IndexTokens.
* **`issuanceIndexTokensWithEth(uint256 _inputAmount) payable`:** Same as above, but user sends ETH directly (wrapped to WETH inside).
* **`redemption(uint256 amountIn, address _tokenOut, address[] memory _path, uint24[] memory _fees)`:**

  1. Burn `amountIn` of IndexToken from user.
  2. Calculate `burnPercent = (amountIn * 1e18) / totalSupply`.
  3. Withdraw proportional shares of every underlying token from the Vault.
  4. Swap each underlying token back to WETH (on Uniswap).
  5. Deduct `feeRate` => send fee in WETH to `feeReceiver`.
  6. Swap net WETH to `_tokenOut` (if not WETH) and transfer to user (or send ETH if `_tokenOut == WETH`).
* **`swap(...) internal`:** Wrapper to route between Uniswap V3 router and Uniswap V2 router (depending on factoryStorage configuration).
* **Access Control:** Only `owner()` or `factoryStorage.isOperator(...)` can call `pause()`, `unpause()`, or update `factoryStorage`.

> **Note:** All calldata paths (`address[] path`, `uint24[] fees`) must be computed off-chain (e.g., via a script or front end) using `factoryStorage.getFromETHPathData(...)` or `getToETHPathData(...)`, ensuring the correct Uniswap pool fee tiers.

### 3. IndexFactoryBalancer

**Path / Repo:** `contracts/IndexFactoryBalancer.sol`
**Purpose:**

* Performs periodic **re-indexing** and **re-weighting** of the Vault’s underlying portfolio.
* Used when the oracle’s asset list or target weights have changed.

**Key Functions:**

* **`initialize(address payable _factoryStorage)`:** Same as IndexFactory.
* **`reIndexAndReweight() external onlyOwnerOrOperator`:**

  1. Loop over all `currentList` tokens (existing vault constituents).

     * For each token ≠ WETH: withdraw its full balance from Vault → swap to WETH → hold in this contract.
     * If token is WETH: simply note WETH balance.
  2. Read `totalOracleList` (new asset list from oracle). For each token in `oracleList`:

     * Compute `(wethBalance * tokenOracleMarketShare)/100e18` → swap that amount of WETH into the new token, depositing directly back to the Vault.
  3. Call `factoryStorage.updateCurrentList()` → commit the new `currentList` on-chain.
  4. Emit `Rebalanced(block.timestamp)`.

> **Flow:**
>
> * **Step 1 (Sell old assets):** Converts all existing assets to WETH.
> * **Step 2 (Buy new assets):** Trades WETH into target tokens as per oracle weights.
> * **Step 3 (Commit new list):** Updates the stored array of “currentList” in `IndexFactoryStorage`.

### 4. Vault

**Path / Repo:** `contracts/Vault.sol`
**Purpose:**

* Holds the protocol’s underlying assets (all ERC-20 tokens) in custodial fashion.
* Only designated “operators” may withdraw tokens. (IndexFactory and IndexFactoryBalancer are operators.)

**Key Functions:**

* **`initialize() external initializer`:** Sets `owner = msg.sender` (proxy pattern).
* **`setOperator(address _operator, bool _status) external onlyOwner`:** Authorize or revoke operator status.
* **`withdrawFunds(address _token, address _to, uint256 _amount) external onlyOperator`:** Transfer `_amount` of `_token` from this Vault to `_to`. Emits `FundsWithdrawn`.

> **Security:**
>
> * No direct `receive()` or fallback logic that accepts Ethereum, except a custom revert in IndexFactoryBalancer to forbid native ETH transfers.
> * All actual on-chain swaps and movements of funds are driven by the Factory or Balancer, which are set as Vault operators.

---

## Deployment Addresses (ARBEI)

> **Network:** Arbitrum (Mainnet)
> **Product:** ARBEI (Arbitrum Ecosystem Index)

| Contract                  | Address                                      |
| ------------------------- | -------------------------------------------- |
| **IndexToken**            | `0x4386741db5Aadec9201c997b9fD197b598ef1323` |
| **IndexFactoryStorage**\* | `0xB1ae3b1A08cf98f7e02342F8adD29b86021B1632` |
| **IndexFactory**          | `0xC261547547fb4b108db504FE200e20Db7612D5E9` |
| **IndexFactoryBalancer**  | `0xb4bdDC1DC62128e28ed66Fcd5e606B9a05712F2E` |
| **Vault**                 | `0xA0213D39758abC34A583A821Ccd07dd1Ad3c13b3` |

> \* The `IndexFactoryStorage` contract holds all global state (feeRate, token lists, oracles, router addresses, etc.) and is shared by both `IndexFactory` and `IndexFactoryBalancer`.

---

## High-Level Workflow

### Token Issuance (Minting)

1. **Oracle-Driven Index List Update:**

   * Off-chain, a “market source” (could be a backend service or Chainlink Automation) periodically compiles a new asset list (`oracleList[]`) and each token’s target percentage (`tokenOracleMarketShare[token]`).
   * It then calls `IndexFactoryStorage.updateOracleList(...)` (not shown in these contracts) to update on-chain.

2. **User Calls `issuanceIndexTokens(...)`:**

   * **Input:** e.g., USDC (stablecoin) or any ERC-20 accepted by the index.
   * **Fee Calculation:** `feeAmount = (_amountIn * feeRate) / 10000`.
   * **Transfer From User:** Collects `_amountIn + feeAmount` from user.
   * **Swap to WETH:**

     ```solidity
     uint256 wethAmountBeforeFee = swap(_tokenInPath, _tokenInFees, _amountIn + feeAmount, address(this));
     uint256 feeWethAmount = (wethAmountBeforeFee * feeRate) / 10000;
     uint256 wethToDeploy = wethAmountBeforeFee - feeWethAmount;
     Transfer feeWethAmount → feeReceiver
     ```
   * **Deploy to Vault:**

     * Compute `firstPortfolioValue = factoryStorage.getPortfolioBalance()` (sum of all current holdings in WETH terms).
     * For each token in `currentList[]`:

       ```solidity
       uint256 marketShare = factoryStorage.tokenCurrentMarketShare(tokenAddress);
       // amount of WETH to swap for this token = (wethToDeploy * marketShare) / 100e18
       if tokenAddress != WETH:
           swap(... → Vault)
       else:
           WETH.transfer → Vault
       ```
   * **Mint IndexTokens:**

     * After all underlying swaps, compute `secondPortfolioValue = factoryStorage.getPortfolioBalance()`.
     * If `totalSupply > 0`:

       ```solidity
       newTotalSupply = (totalSupply * secondPortfolioValue) / firstPortfolioValue
       amountToMint = newTotalSupply - totalSupply
       ```
     * Else (first issuance):

       ```solidity
       price = factoryStorage.priceInWei()
       amountToMint = (secondPortfolioValue * price) / 100e18
       ```
     * `IndexToken.mint(msg.sender, amountToMint)`.
   * **Event Emitted:**

     ```solidity
     Issuanced(user, _tokenIn, _amountIn, amountToMint, getIndexTokenPrice(), block.timestamp)
     ```

3. **User Receives IndexTokens:** Holding these ERC-20 tokens represents a pro-rata share of the Vault’s pooled assets.

---

### Redemption (Burning)

1. **User Calls `redemption(...)`:**

   * **Input:** `amountIn` of IndexTokens to burn; desired output token (`_tokenOut`) and its Uniswap path (`_tokenOutPath`, `_tokenOutFees`).
   * **Compute Burn Percent:**

     ```solidity
     burnPercent = (amountIn * 1e18) / indexToken.totalSupply();
     indexToken.burn(msg.sender, amountIn);
     ```
   * **Withdraw Underlying from Vault:**

     * For each token in `currentList[]`:

       ```solidity
       swapAmount = (burnPercent * tokenBalanceInVault) / 1e18
       if token != WETH:
           Vault.withdrawFunds(token, this, swapAmount)
           swap(token → WETH → this)
       else:
           Vault.withdrawFunds(WETH, this, swapAmount)
           outputAmount += swapAmount
       ```
   * **Aggregate WETH:** Sum of all swapped WETH = `outputAmount`.
   * **Deduct Fee:**

     ```solidity
     ownerFee = (outputAmount * feeRate) / 10000
     netWeth = outputAmount - ownerFee
     WETH.transfer(feeReceiver, ownerFee)
     ```
   * **Swap to Desired Output:**

     * If `_tokenOut == WETH`:

       ```solidity
       WETH.withdraw(netWeth)
       send ETH → user
       emit Redemption(user, _tokenOut, amountIn, netWeth, currentPrice, block.timestamp)
       ```
     * Else:

       ```solidity
       swap(WETH → _tokenOut → user)
       emit Redemption(user, _tokenOut, amountIn, realOut, currentPrice, block.timestamp)
       ```

2. **User Receives Output Tokens/ETH:** Their IndexTokens have been burned, and they receive a pro-rata share of the pooled assets (minus fees) in the chosen token/ETH.

---

### Re-Indexing & Re-Weighting

Over time, the oracle may update which tokens belong to the index (**re-indexing**) or change each token’s weight (**re-weighting**). The `IndexFactoryBalancer` contract handles this in a single transaction:

1. **Sell All Current Assets to WETH:**

   * For each token in `currentList[]`:

     ```solidity
     tokenBalance = ERC20(token).balanceOf(Vault)
     if token != WETH:
         Vault.withdrawFunds(token, this, tokenBalance)
         swap(token → WETH → this)
     else:
         // WETH already in Vault; no swap needed
     ```
   * After the loop, this contract holds the entire portfolio in WETH.

2. **Buy New Assets per Oracle List:**

   * Let `wethBalance = WETH.balanceOf(this)`.
   * For each token in `oracleList[]`:

     ```solidity
     targetShare = factoryStorage.tokenOracleMarketShare(token)  // weight in 1e18 format
     amountToSwap = (wethBalance * targetShare) / 100e18
     if token != WETH:
         swap(WETH → token → Vault)
     else:
         WETH.transfer(Vault, amountToSwap)
     ```

3. **Update On-Chain `currentList[]`:**

   * After acquiring new tokens, call `factoryStorage.updateCurrentList()` to overwrite the old list with the new `oracleList[]`.
   * Emit `Rebalanced(block.timestamp)`.

> **Effects:**
>
> * Any token not in the new list is sold off.
> * Newly included tokens are purchased in the Vault at target weights.
> * Intermediate WETH holdings are never minted or burned; they simply flow through the Balancer.

---

## Integration Details

### Inter-Contract Dependencies

All four contracts rely on a centralized storage/oracle contract: `IndexFactoryStorage`. Although its code is not shown here, it must implement:

* **`swapRouterV3() → ISwapRouter`** & **`swapRouterV2() → IUniswapV2Router02`**: Pointers to Uniswap V3 and V2 routers.
* **`weth() → IWETH`**: WETH token contract.
* **`vault() → Vault`**: Vault address.
* **`indexToken() → IndexToken`**: IndexToken contract address.
* **`feeRate() → uint256`** & **`feeReceiver() → address`**: Protocol fee settings (basis points).
* **`currentList(uint256) → address`** & **`totalCurrentList() → uint256`**: Array of currently active index constituents and its length.
* **`oracleList(uint256) → address`** & **`totalOracleList() → uint256`**: Array of oracle-provided tokens for reindex.
* **`tokenCurrentMarketShare(address) → uint256`** & **`tokenOracleMarketShare(address) → uint256`**: Percent weights (scaled by 1e18) for each token in `currentList` and `oracleList`.
* **`getFromETHPathData(address) → (address[] path, uint24[] fees)`** & **`getToETHPathData(address) → (address[] path, uint24[] fees)`**: On-chain encoding of Uniswap swap paths (pool fee tiers) for efficient routing.
* **`getMinAmountOut(address[] path, uint24[] fees, uint256 amountIn) → uint256`**: Returns minimum acceptable output amount (e.g., with slippage tolerance) for a given Uniswap swap.
* **`getPortfolioBalance() → uint256`**: Sum of all current holdings’ values denominated in WETH (for pricing / pro-rata calculations).
* **`priceInWei() → uint256`** & **`getIndexTokenPrice() → uint256`**: Reference on-chain oracle values for initial token price and live index price.
* **`isOperator(address) → bool`**: Access control for both Factory and Balancer.
* **`updateCurrentList() external`**: Overwrites `currentList` to match `oracleList`.

Without a functional `IndexFactoryStorage`, none of the high-level mechanics will work. When deploying, be sure to point both `IndexFactory` and `IndexFactoryBalancer` to the same storage contract.

---

### Parameters & Fee Mechanisms

* **`feeRate` (basis points / 10,000):**

  * On every issuance, the user pays an upfront “feeRate%” of their deposit (in WETH).
  * On every redemption, a “feeRate%” of the redeemed WETH is diverted to `feeReceiver`.
  * This is distinct from the `feeRatePerDayScaled` inside `IndexToken`, which is an on-chain inflation mechanism (compounded daily).

* **`feeReceiver`:**

  * Receives WETH fees from issuance/redemption.
  * Receives inflationary token mints (once per day) on the IndexToken contract (pro-rata of total supply).

* **`supplyCeiling`:**

  * Set at IndexToken initialization; cannot mint beyond this absolute limit. Prevents unbounded dilution.

* **`methodology`:**

  * On-chain string describing the index’s construction, rebalancing frequency, and rationale.
  * Only the `methodologist` address can call `setMethodology(...)`.

* **`isRestricted` (mapping in IndexToken):**

  * Used to blacklist or “pause” certain addresses from sending/receiving tokens (e.g., in case of hacks or compliance).

---

## Getting Started (Developer Setup)

1. **Clone Each Repository**

   ```bash
   git clone git@github.com:nexlabs22/Defi-Indices-Model-Contracts.git
   ```

2. **Install Dependencies**
   Each repo uses Hardhat and Foundry (depending on your framework):

   ```bash
   npm install
   forge install
   ```

3. **Configure Environment Variables**

   * Create a `.env` file with keys for:

     ```env
     MAINNET_RPC_URL=“https://arb1.arbitrum.io/rpc”
     PRIVATE_KEY=“0x…”    # Deployer’s private key
     ```
   * In each Hardhat/Truffle config, point the Arbitrum mainnet network to `process.env.RPC_URL_ARBITRUM_MAINNET`.

4. **Compile & Test**

   ```bash
   forge compile
   forge build
   ```

5. **Deploy (Optional)**

   * Deploy the shared `IndexFactoryStorage` first.
   * Pass its address into `IndexFactory.initialize(...)` and `IndexFactoryBalancer.initialize(...)`.
   * Deploy `IndexToken` with parameters `[“ARBEI”, “ARBEI”, _feeRatePerDayScaled, _feeReceiver, _supplyCeiling]`.
   * Deploy `Vault`.
   * Deploy `IndexFactory` & `IndexFactoryBalancer`.
   * In `IndexFactoryStorage`, set:

     * `swapRouterV3`, `swapRouterV2`, `factoryV3`, `factoryV2`, `quoter`, `weth`, `vault`, `indexToken`, `feeReceiver`, `feeRate`, `token lists`, and path logic.

> **Tip:** Use a script to automatically configure all parameters in `IndexFactoryStorage`. Ensure that `isOperator(IndexFactory) = true` and `isOperator(IndexFactoryBalancer) = true`.

---

## License

This project is released under the **MIT License**. See the `LICENSE` file in each repository for details.
