// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleSwap - TokenA/TokenB Pair (No Fees), adapted for original verifier
 * @notice A simplified decentralized exchange contract to swap two specific tokens without fees.
 * @dev Implements core AMM logic (constant product formula) similar to Uniswap V2 without swap fees.
 * Users can add/remove liquidity, swap tokens, get price info, and calculate outputs.
 * The contract matches the function signature expected by the original SwapVerifier.
 */
contract SimpleSwap is Ownable {
    /// @notice The first token address in the pair (immutable after deployment).
    address public immutable TOKEN_A_ADDRESS;
    /// @notice The second token address in the pair (immutable after deployment).
    address public immutable TOKEN_B_ADDRESS;

    /// @notice Reserve amount of Token A currently in the pool.
    uint public tokenAReserve;
    /// @notice Reserve amount of Token B currently in the pool.
    uint public tokenBReserve;
    /// @notice Total conceptual liquidity shares issued.
    uint public totalLPSupply;

    /**
     * @notice Emitted when liquidity is added to the pool.
     * @param provider The address supplying liquidity.
     * @param amountTokenA The amount of Token A added.
     * @param amountTokenB The amount of Token B added.
     * @param liquidity The liquidity shares minted.
     */
    event AddLiquidity(
        address indexed provider,
        uint amountTokenA,
        uint amountTokenB,
        uint liquidity
    );

    /**
     * @notice Emitted when liquidity is removed from the pool.
     * @param receiver The address receiving the tokens.
     * @param liquidity The liquidity shares burned.
     * @param amountTokenA The amount of Token A returned.
     * @param amountTokenB The amount of Token B returned.
     */
    event RemoveLiquidity(
        address indexed receiver,
        uint liquidity,
        uint amountTokenA,
        uint amountTokenB
    );

    /**
     * @notice Emitted when a token swap occurs.
     * @param sender The address initiating the swap.
     * @param tokenIn The token address sent to the pool.
     * @param tokenOut The token address received from the pool.
     * @param amountIn The input token amount swapped.
     * @param amountOut The output token amount received.
     * @param to The address receiving the output tokens.
     */
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint amountIn,
        uint amountOut,
        address to
    );

    /**
     * @notice Constructs the SimpleSwap contract setting the token pair.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     */
    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        require(_tokenA != address(0) && _tokenB != address(0), "SimpleSwap: ZERO_ADDRESS");
        require(_tokenA != _tokenB, "SimpleSwap: IDENTICAL_ADDRESSES");

        address canonicalTokenA;
        address canonicalTokenB;

        if (_tokenA < _tokenB) {
            canonicalTokenA = _tokenA;
            canonicalTokenB = _tokenB;
        } else {
            canonicalTokenA = _tokenB;
            canonicalTokenB = _tokenA;
        }

        TOKEN_A_ADDRESS = canonicalTokenA;
        TOKEN_B_ADDRESS = canonicalTokenB;
    }

    /**
     * @notice Internal function to validate if given tokens match the configured pair.
     * @param token1 Address of the first token.
     * @param token2 Address of the second token.
     */
    function _validateTokens(address token1, address token2) private view {
        require(
            (token1 == TOKEN_A_ADDRESS && token2 == TOKEN_B_ADDRESS) ||
            (token1 == TOKEN_B_ADDRESS && token2 == TOKEN_A_ADDRESS),
            "SimpleSwap: UNSUPPORTED_TOKEN_PAIR"
        );
    }

    /**
     * @notice Internal helper to map provided amounts to canonical token order.
     * @param _tokenA The token address corresponding to amountADesired.
     * @param _amountADesired Desired amount for token A parameter.
     * @param _amountBDesired Desired amount for token B parameter.
     * @param _amountAMin Minimum amount for token A.
     * @param _amountBMin Minimum amount for token B.
     * @return inputAmountA Amount mapped to TOKEN_A_ADDRESS.
     * @return inputAmountB Amount mapped to TOKEN_B_ADDRESS.
     * @return minAmountA Minimum amount mapped to TOKEN_A_ADDRESS.
     * @return minAmountB Minimum amount mapped to TOKEN_B_ADDRESS.
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
            inputAmountA = _amountBDesired;
            inputAmountB = _amountADesired;
            minAmountA = _amountBMin;
            minAmountB = _amountAMin;
        }
    }

    /**
     * @notice Adds liquidity to the TokenA-TokenB pool.
     * @dev Transfers tokens from caller, issues conceptual liquidity shares.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param amountADesired Desired amount of tokenA.
     * @param amountBDesired Desired amount of tokenB.
     * @param amountAMin Minimum acceptable amount of tokenA.
     * @param amountBMin Minimum acceptable amount of tokenB.
     * @param to Address to receive liquidity shares.
     * @param deadline Timestamp after which the transaction is invalid.
     * @return actualAmountA Actual amount of tokenA added.
     * @return actualAmountB Actual amount of tokenB added.
     * @return mintedLiquidity Amount of liquidity shares minted.
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

        (uint inputAmountA, uint inputAmountB, uint minAmountA, uint minAmountB) =
            _mapAmountsToCanonicalOrder(tokenA, amountADesired, amountBDesired, amountAMin, amountBMin);

        uint currentTokenAReserve = tokenAReserve;
        uint currentTokenBReserve = tokenBReserve;
        uint currentTotalLPSupply = totalLPSupply;

        if (currentTokenAReserve == 0 && currentTokenBReserve == 0) {
            require(inputAmountA > 0 && inputAmountB > 0, "SimpleSwap: INITIAL_LIQUIDITY_ZERO_AMOUNT");
            actualAmountA = inputAmountA;
            actualAmountB = inputAmountB;
            mintedLiquidity = sqrt(actualAmountA * actualAmountB);
        } else {
            uint optimalAmountB = inputAmountA * currentTokenBReserve / currentTokenAReserve;

            if (optimalAmountB <= inputAmountB) {
                require(optimalAmountB >= minAmountB, "SimpleSwap: INSUFFICIENT_TOKEN_B_AMOUNT");
                actualAmountA = inputAmountA;
                actualAmountB = optimalAmountB;
            } else {
                uint optimalAmountA = inputAmountB * currentTokenAReserve / currentTokenBReserve;
                require(optimalAmountA >= minAmountA, "SimpleSwap: INSUFFICIENT_TOKEN_A_AMOUNT");
                actualAmountA = optimalAmountA;
                actualAmountB = inputAmountB;
            }

            uint liquidityFromA = actualAmountA * currentTotalLPSupply / currentTokenAReserve;
            uint liquidityFromB = actualAmountB * currentTotalLPSupply / currentTokenBReserve;
            mintedLiquidity = liquidityFromA < liquidityFromB ? liquidityFromA : liquidityFromB;
        }

        require(mintedLiquidity > 0, "SimpleSwap: ZERO_LIQUIDITY_MINTED");
        require(actualAmountA >= minAmountA, "SimpleSwap: INSUFFICIENT_TOKEN_A_AMOUNT_FINAL");
        require(actualAmountB >= minAmountB, "SimpleSwap: INSUFFICIENT_TOKEN_B_AMOUNT_FINAL");

        IERC20(TOKEN_A_ADDRESS).transferFrom(msg.sender, address(this), actualAmountA);
        IERC20(TOKEN_B_ADDRESS).transferFrom(msg.sender, address(this), actualAmountB);

        tokenAReserve = currentTokenAReserve + actualAmountA;
        tokenBReserve = currentTokenBReserve + actualAmountB;
        totalLPSupply = currentTotalLPSupply + mintedLiquidity;

        emit AddLiquidity(to, actualAmountA, actualAmountB, mintedLiquidity);
    }

    /**
     * @notice Removes liquidity from the TokenA-TokenB pool.
     * @dev Burns liquidity shares and transfers tokens to caller.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param liquidityAmount Amount of liquidity shares to burn.
     * @param amountAMin Minimum amount of tokenA to receive.
     * @param amountBMin Minimum amount of tokenB to receive.
     * @param to Address to receive tokens.
     * @param deadline Timestamp after which the transaction is invalid.
     * @return amountTokenA Amount of tokenA returned.
     * @return amountTokenB Amount of tokenB returned.
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

        amountTokenA = liquidityAmount * currentTokenAReserve / currentTotalLPSupply;
        amountTokenB = liquidityAmount * currentTokenBReserve / currentTotalLPSupply;

        require(amountTokenA >= amountAMin, "SimpleSwap: INSUFFICIENT_TOKEN_A_RETURN");
        require(amountTokenB >= amountBMin, "SimpleSwap: INSUFFICIENT_TOKEN_B_RETURN");

        tokenAReserve = currentTokenAReserve - amountTokenA;
        tokenBReserve = currentTokenBReserve - amountTokenB;
        totalLPSupply = currentTotalLPSupply - liquidityAmount;

        IERC20(TOKEN_A_ADDRESS).transfer(to, amountTokenA);
        IERC20(TOKEN_B_ADDRESS).transfer(to, amountTokenB);

        emit RemoveLiquidity(to, liquidityAmount, amountTokenA, amountTokenB);
    }

    /**
     * @notice Swaps an exact amount of input tokens for output tokens.
     * @dev Uses constant product formula without fees.
     * @param amountIn Exact amount of input tokens to swap.
     * @param amountOutMin Minimum acceptable output amount (slippage protection).
     * @param path Array of token addresses: [tokenIn, tokenOut].
     * @param to Address to receive output tokens.
     * @param deadline Timestamp after which the transaction is invalid.
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        require(path.length == 2, "SimpleSwap: INVALID_PATH_LENGTH");

        _validateTokens(path[0], path[1]);
        require(block.timestamp <= deadline, "SimpleSwap: EXPIRED");

        address tokenIn = path[0];
        address tokenOut = path[1];

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
        } else {
            reserveIn = tokenBReserve;
            reserveOut = tokenAReserve;
        }

        require(reserveIn > 0 && reserveOut > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_FOR_SWAP");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

        require(amountOut >= amountOutMin, "SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        require(amountOut > 0, "SimpleSwap: ZERO_OUTPUT_AMOUNT");

        if (tokenIn == TOKEN_A_ADDRESS) {
            tokenAReserve += amountIn;
            tokenBReserve -= amountOut;
        } else {
            tokenBReserve += amountIn;
            tokenAReserve -= amountOut;
        }

        IERC20(tokenOut).transfer(to, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, to);
    }

    /**
     * @notice Calculates output token amount given an input amount and reserves.
     * @dev Constant product formula without fees: amountOut = (amountIn * reserveOut) / (reserveIn + amountIn).
     * @param amountIn Input token amount.
     * @param reserveIn Reserve of input token.
     * @param reserveOut Reserve of output token.
     * @return amountOut Calculated output token amount.
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

        require(amountOut > 0, "SimpleSwap: ZERO_OUTPUT_AMOUNT");
    }

    /**
     * @notice Gets the price of queryTokenA in terms of queryTokenB scaled by 1e18.
     * @param queryTokenA The token to price.
     * @param queryTokenB The token in which price is expressed.
     * @return price The price scaled by 1e18.
     */
    function getPrice(address queryTokenA, address queryTokenB) external view returns (uint price) {
        _validateTokens(queryTokenA, queryTokenB);

        uint _reserveA;
        uint _reserveB;

        if (queryTokenA == TOKEN_A_ADDRESS) {
            _reserveA = tokenAReserve;
            _reserveB = tokenBReserve;
        } else {
            _reserveA = tokenBReserve;
            _reserveB = tokenAReserve;
        }

        require(_reserveA > 0, "SimpleSwap: NO_RESERVE_A");
        require(_reserveB > 0, "SimpleSwap: NO_RESERVE_B");

        price = _reserveB * (10**18) / _reserveA;
    }

    /**
     * @notice Internal function to calculate integer square root.
     * @param y The number to compute sqrt of.
     * @return z The integer sqrt.
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
    }

    /**
     * @notice Returns the current block timestamp.
     * @return Current Unix timestamp (seconds).
     */
    function getCurrentTimestamp() external view returns (uint) {
        return block.timestamp;
    }
}
