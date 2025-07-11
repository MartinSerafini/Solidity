// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

/// @dev Imports the base ERC20 contract from OpenZeppelin.
/// This contract provides the standard implementation for all ERC-20 token functionalities,
/// such as `transfer`, `balanceOf`, `approve`, `allowance`, `transferFrom`, and related events.
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Imports the Ownable contract from OpenZeppelin.
/// This contract introduces a simple access control mechanism, allowing a single "owner"
/// (the contract deployer by default) to have special permissions,
/// typically enforced by the `onlyOwner` modifier.
/// This contract allows to transfer the Ownership to another address
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title XmenCoin (XCOIN)
 * @dev An ERC-20 compliant token with an initial supply and minting capabilities.
 * The contract deployer (owner) can mint new tokens.
 */
contract XmenCoin is ERC20, Ownable {
    // Define the initial supply for XCOIN (e.g., 500,000 XCOIN with 18 decimals)
    uint256 public constant INITIAL_SUPPLY = 500_000 * (10**18); // 500,000 tokens

    /**
     * @dev Constructor to initialize the token.
     * Mints the initial supply to the deployer's address.
     */
    constructor() ERC20("XmenCoin", "XCOIN") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Mints new tokens and assigns them to an account.
     * Only the contract owner can call this function.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}