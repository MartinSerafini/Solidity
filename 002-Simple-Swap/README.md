# SimpleSwap
A simplified decentralized exchange (DEX) contract for swapping two ERC20 tokens using a constant product Automated Market Maker (AMM) model, similar to Uniswap V2, but without swap fees.

## Author
Martin Nicolas Serafini

## Contract Summary
The SimpleSwap contract facilitates permissionless trading and liquidity provision for a specific pair of ERC20 tokens. It implements the core AMM logic to enable token exchanges and allows users to contribute to or withdraw from the liquidity pool. The token pair is set immutably at the time of contract deployment via the constructor, making the contract ready for use immediately upon creation. This version is tailored to meet the interface requirements of an external verifier, ensuring compatibility with specific testing environments.

## Requirements
To interact with and deploy the SimpleSwap contract, you'll need the following:

* Solidity Compiler: Version 0.8.2 or newer.
* OpenZeppelin Contracts: Specifically, IERC20.sol for ERC20 token interactions and Ownable.sol for basic ownership functionalities. Ensure your development environment is configured to resolve these imports (e.g., via npm package installation).
* Two ERC20 Tokens: You'll need the addresses of two distinct ERC20 token contracts (tokenA and tokenB) to provide as arguments during the SimpleSwap contract's deployment. These tokens will form the liquidity pair for this specific SimpleSwap instance.
## Main Features
Core Functionality
* Fixed Token Pair: The contract operates exclusively with two designated ERC20 tokens. These TOKEN_A_ADDRESS and TOKEN_B_ADDRESS are immutable and defined during the contract's deployment.
* Liquidity Provision: Users can add liquidity by depositing both tokenA and tokenB into the pool. This function (addLiquidity) calculates and conceptually issues liquidity shares, representing the user's proportional stake in the pool.
* Liquidity Removal: Conversely, users can remove liquidity by burning their conceptual liquidity shares, receiving their proportional amount of both tokenA and tokenB back from the pool (removeLiquidity).
* Token Swapping: The swapExactTokensForTokens function allows users to exchange a precise amount of one token for the corresponding amount of the other, determined by the AMM's constant product formula.
* Price Oracle: The getPrice function provides a conceptual spot price of one token relative to the other within the pool.
  
## Technical Design
* Constant Product AMM: Employs the classic formula for determining exchange rates, ensuring balanced liquidity.
No Swap Fees: This implementation intentionally excludes any trading fees, simplifying the economic model.
* Slippage Control: All liquidity and swap functions include minAmount or amountOutMin parameters to protect users from unfavorable price movements due to slippage.
* Deadline Protection: Transaction functions incorporate a deadline parameter to prevent front-running attacks by invalidating transactions executed after a specified timestamp.
* Canonical Token Ordering: Internally, TOKEN_A_ADDRESS is always the numerically smaller address of the pair, ensuring consistent handling of token reserves and calculations.



