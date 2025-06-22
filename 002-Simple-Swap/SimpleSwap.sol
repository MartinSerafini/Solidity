// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleSwap - TokenA/TokenB Pair (No Fees), adapted for original verifier
 * @dev A simplified decentralized exchange contract specialized for swapping two tokens: TokenA and TokenB.
 * This version implements the core AMM logic (constant product formula) similar to Uniswap V2,
 * but with the explicit exclusion of swap fees.
 * It allows users to add and remove liquidity for this specific pair, swap between them,
 * get price, and calculate output amounts.
 * This contract is adapted to conform to the function signatures expected by the original SwapVerifier,
 * specifically by accepting token addresses in addLiquidity and removeLiquidity,
 * and by not returning a value from swapExactTokensForTokens.
 * The token pair (TOKEN_A_ADDRESS, TOKEN_B_ADDRESS) is set once at deployment via the constructor.
 * @custom:security Users must approve token transfers via ERC20's `approve` function.
 */
contract SimpleSwap is Ownable {
    address public immutable TOKEN_A_ADDRESS; 
    address public immutable TOKEN_B_ADDRESS; 

    uint public tokenAReserve;
    uint public tokenBReserve;
    uint public totalLPSupply;

    
    /// @dev Emitted when liquidity is added to the TokenA/TokenB pool.
    /// @param provider The address that supplied the liquidity.
    /// @param amountTokenA The amount of TokenA tokens added to the pool.
    /// @param amountTokenB The amount of TokenB tokens added to the pool.
    /// @param liquidity The conceptual liquidity shares minted and assigned to the provider.
    event AddLiquidity(
        address indexed provider,
        uint amountTokenA,
        uint amountTokenB,
        uint liquidity
    );

    /// @dev Emitted when liquidity is removed from the TokenA/TokenB pool.
    /// @param receiver The address that receives the TokenA and TokenB tokens.
    /// @param liquidity The amount of conceptual liquidity shares that were burned.
    /// @param amountTokenA The amount of TokenA tokens returned to the receiver.
    /// @param amountTokenB The amount of TokenB tokens returned to the receiver.
    event RemoveLiquidity(
        address indexed receiver,
        uint liquidity,
        uint amountTokenA,
        uint amountTokenB
    );

    /// @dev Emitted when a swap occurs.
    /// @param sender The address that initiated the swap.
    /// @param tokenIn The address of the token that was sent into the pool.
    /// @param tokenOut The address of the token that was received from the pool.
    /// @param amountIn The amount of tokenIn that was swapped.
    /// @param amountOut The amount of tokenOut that was received.
    /// @param to The address that received the tokenOut (can be different from sender for third-party swaps).
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint amountIn,
        uint amountOut,
        address to
    );

    /**
     * @dev Constructor for SimpleSwap.
     * Initializes Ownable by setting the deployer as the initial owner.
     * Sets the immutable token pair (TOKEN_A_ADDRESS, TOKEN_B_ADDRESS) at deployment time.
     * @param _tokenA The address of the first ERC20 token for this swap pair.
     * @param _tokenB The address of the second ERC20 token for this swap pair.
     */
    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        require(_tokenA != address(0) && _tokenB != address(0), "SimpleSwap: ZERO_ADDRESS");
        require(_tokenA != _tokenB, "SimpleSwap: IDENTICAL_ADDRESSES");

        // Ensure TOKEN_A_ADDRESS is always the numerically smaller address for consistency.
        if (_tokenA > _tokenB) {
            TOKEN_A_ADDRESS = _tokenB;
            TOKEN_B_ADDRESS = _tokenA;
        } else {
            TOKEN_A_ADDRESS = _tokenA;
            TOKEN_B_ADDRESS = _tokenB;
        }
    }

    /**
     * @dev Internal helper function to validate if the provided tokens match the configured pair.
     * @param token1 The address of the first token to check.
     * @param token2 The address of the second token to check.
     */
    function _validateTokens(address token1, address token2) private view {
        // 'initialized' ya no es necesario, ya que los tokens se establecen en el constructor.
        require(
            (token1 == TOKEN_A_ADDRESS && token2 == TOKEN_B_ADDRESS) ||
            (token1 == TOKEN_B_ADDRESS && token2 == TOKEN_A_ADDRESS),
            "SimpleSwap: UNSUPPORTED_TOKEN_PAIR"
        );
    }

    /**
     * @dev Internal helper to determine which amounts/mins correspond to TOKEN_A_ADDRESS and TOKEN_B_ADDRESS.
     * This helps reduce stack depth in addLiquidity and removeLiquidity by handling the token order flexibility.
     * @param _tokenA The tokenA address passed to the external function.
     * @param _amountADesired Amount desired for _tokenA.
     * @param _amountBDesired Amount desired for _tokenB.
     * @param _amountAMin Min amount for _tokenA.
     * @param _amountBMin Min amount for _tokenB.
     * @return inputAmountA Corresponds to TOKEN_A_ADDRESS's desired amount.
     * @return inputAmountB Corresponds to TOKEN_B_ADDRESS's desired amount.
     * @return minAmountA Corresponds to TOKEN_A_ADDRESS's min amount.
     * @return minAmountB Corresponds to TOKEN_B_ADDRESS's min amount.
     */
    function _mapAmountsToCanonicalOrder(
        address _tokenA,
        uint _amountADesired,
        uint _amountBDesired,
        uint _amountAMin,
        uint _amountBMin
    )
        private
        view
        returns (
            uint inputAmountA,
            uint inputAmountB,
            uint minAmountA,
            uint minAmountB
        )
    {
        if (_tokenA == TOKEN_A_ADDRESS) {
            inputAmountA = _amountADesired;
            inputAmountB = _amountBDesired;
            minAmountA = _amountAMin;
            minAmountB = _amountBMin;
        } else {
            // _tokenA must be TOKEN_B_ADDRESS, meaning _tokenB is TOKEN_A_ADDRESS
            inputAmountA = _amountBDesired; // amountBDesired is actually for TOKEN_A_ADDRESS
            inputAmountB = _amountADesired; // amountADesired is actually for TOKEN_B_ADDRESS
            minAmountA = _amountBMin;
            minAmountB = _amountAMin;
        }
    }

    /**
     * @dev Allows users to add liquidity to the TokenA-TokenB pool.
     * Tokens are transferred from the user to the contract.
     * Conceptual liquidity shares are calculated and conceptually issued.
     * This function accepts tokenA and tokenB as parameters to align with the original verifier's interface.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param amountADesired The desired amount of TokenA to add.
     * @param amountBDesired The desired amount of TokenB to add.
     * @param amountAMin The minimum acceptable amount of TokenA to add (slippage control).
     * @param amountBMin The minimum acceptable amount of TokenB to add (slippage control).
     * @param to The address to receive the conceptual liquidity shares (typically msg.sender).
     * @param deadline The timestamp by which the transaction must be mined to prevent front-running.
     * @return actualAmountA The actual amount of TokenA added.
     * @return actualAmountB The actual amount of TokenB added.
     * @return mintedLiquidity The conceptual liquidity shares issued.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint actualAmountA, uint actualAmountB, uint mintedLiquidity) {
        _validateTokens(tokenA, tokenB);
        require(block.timestamp <= deadline, "SimpleSwap: EXPIRED");

        // Use helper function to get canonical amounts, reducing stack depth here.
        (uint inputAmountA, uint inputAmountB, uint minAmountA, uint minAmountB) =
            _mapAmountsToCanonicalOrder(tokenA, amountADesired, amountBDesired, amountAMin, amountBMin);

        // Capture current reserves to avoid re-reading storage and maintain consistent state for calculations
        uint currentTokenAReserve = tokenAReserve;
        uint currentTokenBReserve = tokenBReserve;
        uint currentTotalLPSupply = totalLPSupply;

        if (currentTokenAReserve == 0 && currentTokenBReserve == 0) {
            // Initial Liquidity: Accepts desired amounts directly.
            require(inputAmountA > 0 && inputAmountB > 0, "SimpleSwap: INITIAL_LIQUIDITY_ZERO_AMOUNT");
            actualAmountA = inputAmountA;
            actualAmountB = inputAmountB;
            mintedLiquidity = sqrt(actualAmountA * actualAmountB);
        } else {
            // Subsequent Liquidity: Maintains ratio.
            uint optimalAmountB = inputAmountA * currentTokenBReserve / currentTokenAReserve;

            if (optimalAmountB <= inputAmountB) {
                require(optimalAmountB >= minAmountB, "SimpleSwap: INSUFFICIENT_TOKEN_B_AMOUNT");
                actualAmountA = inputAmountA; // Keep desired A
                actualAmountB = optimalAmountB; // Adjust B to optimal
            } else {
                uint optimalAmountA = inputAmountB * currentTokenAReserve / currentTokenBReserve;
                require(optimalAmountA >= minAmountA, "SimpleSwap: INSUFFICIENT_TOKEN_A_AMOUNT");
                actualAmountA = optimalAmountA; // Adjust A to optimal
                actualAmountB = inputAmountB; // Keep desired B
            }

            // Calculate new liquidity shares
            uint liquidityFromA = actualAmountA * currentTotalLPSupply / currentTokenAReserve;
            uint liquidityFromB = actualAmountB * currentTotalLPSupply / currentTokenBReserve;
            mintedLiquidity = liquidityFromA < liquidityFromB ? liquidityFromA : liquidityFromB;
        }

        require(mintedLiquidity > 0, "SimpleSwap: ZERO_LIQUIDITY_MINTED");
        require(actualAmountA >= minAmountA, "SimpleSwap: INSUFFICIENT_TOKEN_A_AMOUNT_FINAL");
        require(actualAmountB >= minAmountB, "SimpleSwap: INSUFFICIENT_TOKEN_B_AMOUNT_FINAL");

        // Transfer tokens from user to contract, requiring prior approval via IERC20 `approve`.
        IERC20(TOKEN_A_ADDRESS).transferFrom(msg.sender, address(this), actualAmountA);
        IERC20(TOKEN_B_ADDRESS).transferFrom(msg.sender, address(this), actualAmountB);

        // Update reserves and total conceptual liquidity supply.
        tokenAReserve = currentTokenAReserve + actualAmountA;
        tokenBReserve = currentTokenBReserve + actualAmountB;
        totalLPSupply = currentTotalLPSupply + mintedLiquidity;

        emit AddLiquidity(to, actualAmountA, actualAmountB, mintedLiquidity);
    }

    /**
     * @dev Allows users to remove liquidity from the TokenA-TokenB pool.
     * Conceptual liquidity shares are "burned" and tokens are returned to the user.
     * This function accepts tokenA and tokenB as parameters to align with the original verifier's interface.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param liquidityAmount The amount of conceptual liquidity shares to burn.
     * @param amountAMin The minimum acceptable amount of TokenA to receive (slippage control).
     * @param amountBMin The minimum acceptable amount of TokenB to receive (slippage control).
     * @param to The address to receive the tokens.
     * @param deadline The timestamp by which the transaction must be mined.
     * @return amountTokenA The actual amount of TokenA received.
     * @return amountTokenB The actual amount of TokenB received.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidityAmount,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountTokenA, uint amountTokenB) {
        _validateTokens(tokenA, tokenB);
        require(block.timestamp <= deadline, "SimpleSwap: EXPIRED");
        require(liquidityAmount > 0, "SimpleSwap: ZERO_LIQUIDITY_BURNED");

        uint currentTokenAReserve = tokenAReserve;
        uint currentTokenBReserve = tokenBReserve;
        uint currentTotalLPSupply = totalLPSupply;

        require(currentTokenAReserve > 0 && currentTokenBReserve > 0, "SimpleSwap: NO_LIQUIDITY_IN_POOL");
        require(liquidityAmount <= currentTotalLPSupply, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED_AMOUNT");

        // Calculate amounts of tokens to return based on liquidity burned.
        amountTokenA = liquidityAmount * currentTokenAReserve / currentTotalLPSupply;
        amountTokenB = liquidityAmount * currentTokenBReserve / currentTotalLPSupply;

        require(amountTokenA >= amountAMin, "SimpleSwap: INSUFFICIENT_TOKEN_A_RETURN");
        require(amountTokenB >= amountBMin, "SimpleSwap: INSUFFICIENT_TOKEN_B_RETURN");

        // Update reserves and total conceptual liquidity.
        tokenAReserve = currentTokenAReserve - amountTokenA;
        tokenBReserve = currentTokenBReserve - amountTokenB;
        totalLPSupply = currentTotalLPSupply - liquidityAmount;

        // Transfer tokens to user.
        IERC20(TOKEN_A_ADDRESS).transfer(to, amountTokenA);
        IERC20(TOKEN_B_ADDRESS).transfer(to, amountTokenB);

        emit RemoveLiquidity(to, liquidityAmount, amountTokenA, amountTokenB);
    }

    /**
     * @dev Swaps an exact amount of an input token (TokenA or TokenB) for an output token (the other).
     * The path must be [TOKEN_A_ADDRESS, TOKEN_B_ADDRESS] or [TOKEN_B_ADDRESS, TOKEN_A_ADDRESS].
     * This function does not return `amounts` to match the original verifier's interface.
     * @param amountIn The exact amount of the input token to swap.
     * @param amountOutMin The minimum acceptable amount of the output token to receive (slippage control).
     * @param path An array of token addresses. Must be exactly two addresses: [tokenIn, tokenOut].
     * Valid paths are [TOKEN_A_ADDRESS, TOKEN_B_ADDRESS] or [TOKEN_B_ADDRESS, TOKEN_A_ADDRESS].
     * @param to The address to receive the output tokens.
     * @param deadline The timestamp by which the transaction must be mined.
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        _validateTokens(path[0], path[1]); // Validate that the tokens in the path are the correct ones
        require(block.timestamp <= deadline, "SimpleSwap: EXPIRED");
        require(path.length == 2, "SimpleSwap: INVALID_PATH_LENGTH");

        address tokenIn = path[0];
        address tokenOut = path[1];

        // Ensure the path consists of the two configured token addresses.
        require(
            (tokenIn == TOKEN_A_ADDRESS && tokenOut == TOKEN_B_ADDRESS) ||
            (tokenIn == TOKEN_B_ADDRESS && tokenOut == TOKEN_A_ADDRESS),
            "SimpleSwap: UNSUPPORTED_TOKEN_PAIR_IN_PATH"
        );

        uint reserveIn;
        uint reserveOut;

        if (tokenIn == TOKEN_A_ADDRESS) {
            reserveIn = tokenAReserve;
            reserveOut = tokenBReserve;
        } else { // tokenIn == TOKEN_B_ADDRESS
            reserveIn = tokenBReserve;
            reserveOut = tokenAReserve;
        }

        require(reserveIn > 0 && reserveOut > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_FOR_SWAP");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

        require(amountOut >= amountOutMin, "SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");

        if (tokenIn == TOKEN_A_ADDRESS) {
            tokenAReserve += amountIn;
            tokenBReserve -= amountOut;
        } else { // tokenIn == TOKEN_B_ADDRESS
            tokenBReserve += amountIn;
            tokenAReserve -= amountOut;
        }

        IERC20(tokenOut).transfer(to, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, to);
    }

    /**
     * @dev Calculates the amount of output tokens received for a given input amount and reserves.
     * Implements the constant product formula (x * y = k) WITHOUT a fee.
     * @param amountIn The amount of input tokens.
     * @param reserveIn The reserve of the input token in the pool.
     * @param reserveOut The reserve of the output token in the pool.
     * @return amountOut The calculated amount of output tokens to receive.
     */
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure returns (uint amountOut) {
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY");

        uint numerator = amountIn * reserveOut;
        uint denominator = reserveIn + amountIn;

        amountOut = numerator / denominator;
    }

    /**
     * @dev Gets the conceptual price of one token in terms of the other (TokenA or TokenB).
     * Price is calculated as reserveB / reserveA.
     * This function accepts tokenA and tokenB as parameters to align with the original verifier's interface.
     * @param queryTokenA The address of the token whose price is being queried.
     * @param queryTokenB The address of the token in terms of which queryTokenA's price is expressed.
     * @return price The price of queryTokenA in terms of queryTokenB (scaled by 1e18 for precision).
     */
    function getPrice(address queryTokenA, address queryTokenB) external view returns (uint price) {
        _validateTokens(queryTokenA, queryTokenB);
        
        uint _reserveA;
        uint _reserveB;

        if (queryTokenA == TOKEN_A_ADDRESS) {
            _reserveA = tokenAReserve;
            _reserveB = tokenBReserve;
        } else { // queryTokenA == TOKEN_B_ADDRESS
            _reserveA = tokenBReserve;
            _reserveB = tokenAReserve;
        }

        require(_reserveA > 0, "SimpleSwap: NO_RESERVE_A");
        require(_reserveB > 0, "SimpleSwap: NO_RESERVE_B");

        price = _reserveB * (10**18) / _reserveA;
    }

    /**
     * @dev Internal helper function to calculate integer square root.
     * Used for calculating initial liquidity shares.
     * @param y The number to calculate the square root of.
     * @return z The integer square root of y.
     */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z is 0
    }

    /**
     * @dev Returns the current block's timestamp.
     * This function can be used for testing `deadline` parameters and by off-chain applications.
     * @return The current Unix timestamp (seconds since epoch).
     */
    function getCurrentTimestamp() external view returns (uint) {
        return block.timestamp;
    }
}