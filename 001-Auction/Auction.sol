// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Auction Contract
 * @dev This contract implements a comprehensive auction system.
 * It allows users to place bids, with a 5% increment requirement over the current highest bid.
 * Bids placed in the last 60 seconds automatically extend the auction duration by a predefined `extensionTime`.
 * * Key features include:
 * - **Automatic Refunds (for test purposes)**: Overbid amounts (minus a 2% commission) are immediately sent to previous bidders.
 * - **Time-Based Conclusion**: The auction automatically ends when `block.timestamp` surpasses `auctionEndTime`.
 * - **Commission Handling**: A 2% commission is applied to overbids and the winning bid. The address indicated in the deploy of the contract can claim accumulated commissions via `claimCommission()`
 * - **Proceeds Claim**: The address indicated in the deploy of the contract can claim the net proceeds from the winning bid using `claimProceeds()` once the auction has concluded.
 * - **Bid History**: List all bids in order of completion.
 * - **Detailed History**: Tracks all bids, refunds, and commissions for each participant.
 * - **This contract implements automatic refunds for testing purposes, but for security purposes is recomended to use a pull payment system where users withdraw their refunds.
 * 
 * Pending features
 * - **In the case of recurring bids from the same bidder, the commission should be calculated only by the difference between the previous and current bid.
 */

contract Auction {
    // Variables 
    address public owner;                       // Owner of the auction, controls claim functions
    address public commissionRecipient;         // Address to receive accumulated commissions
    address public proceedsRecipient;           // Address to receive the net proceeds from the winning bid
    address public highestBidder;               // Current highest bidder
    uint256 public highestBid;                  // Highest bid amount
    uint256 public auctionEndTime;              // Current auction end time (may be extended)
    uint256 public initialEndTime;              // Original auction end time (fixed)
    uint256 public extensionTime;               // Duration to extend auction on late bids
    uint256 public commissionTotal;             // Total commission accumulated
    uint256 public ownerProceedsPending;        // Proceeds from the winning bid pending transfer to proceedsRecipient

    // A flag to ensure the winner's commission is only processed once.
    bool private _winnerCommissionProcessed;

    // Defines a structure to hold information about an individual bid.
    // This allows grouping related data (bidder's address and bid amount) together.
    struct Bid {
        address bidder; // The address of the participant who placed the bid.
        uint256 amount; // The amount of Ether (in wei) that was bid.
    }

    // Array of all bids in order (Changed to private, with a custom getter)
    Bid[] private _allBids;

    // Bid history per address
    // This variable is kept internal/private, a public view function will be provided for access.
    mapping(address => Bid[]) private _bidHistory;
    // Refund history per address (all refunds ever processed for address)
    // This variable is kept internal/private, a public view function will be provided for access.
    mapping(address => uint256[]) private _refundHistory;
    // Commission history per address (all commissions charged to a bidder)
    // This variable is kept internal/private, a public view function will be provided for access.
    mapping(address => uint256[]) private _commissionHistory;


    // Event emitted when a new bid is successfully placed.
    // @param bidder The address of the new bidder.
    // @param amount The amount of the new bid.
    event NewBid(address indexed bidder, uint256 amount);

    // Event emitted when the auction officially ends.
    // @param winner The address of the highest bidder at the auction's end.
    // @param amount The final winning bid amount.
    event AuctionEnded(address winner, uint256 amount);

    // Event emitted when a bidder's overbid amount (minus commission) is made available for withdrawal.
    // @param bidder The Address of the bidder who is being refunded.
    // @param amount The amount refunded to the bidder.
    event Refunded(address indexed bidder, uint256 amount);

    // Event emitted when the auction owner successfully claims their accumulated commissions.
    // @param recipient The address receiving the commission.
    // @param amount The total commission amount claimed.
    event CommissionClaimed(address indexed recipient, uint256 amount);

    // Event emitted when the net proceeds from the winning bid are transferred to the designated recipient.
    // @param recipient The address receiving the proceeds.
    // @param amount The net amount transferred to the recipient.
    event ProceedsTransferred(address indexed recipient, uint256 amount);

    // Ensures that only the contract's owner can call the function this modifier is applied to.
    // Reverts if the caller is not the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    // Ensures the auction is still active (not ended by time) before allowing a function to execute.
    // Reverts if the current block timestamp is at or past the auctionEndTime.
    modifier auctionOngoing() {
        // Auction is ongoing if current time is before the end time
        require(block.timestamp < auctionEndTime, "Auction has ended");
        _;
    }

    // Ensures the auction has concluded (current time is at or past the end time) before allowing a function to execute.
    // Reverts if the current block timestamp is before the auctionEndTime.
    modifier auctionEnded() {
        // Auction is ended if current time is at or past the end time
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        _;
    }

    /**
     * @dev Constructor sets initial auction parameters and designates recipients for commissions and proceeds.
     * The time unit is set to seconds to make it simpler for testing purposes
     * @param _durationSeconds Duration in seconds (>=120 seconds) for the auction.
     * @param _extensionSeconds Extension time (>=30 seconds) added if bid is in last 60 seconds.
     * @param _commissionRecipient The address to which all accumulated commissions will be sent.
     * @param _proceedsRecipient The address to which the net proceeds of the winning bid will be sent.
     */
    constructor(
        uint256 _durationSeconds,
        uint256 _extensionSeconds,
        address _commissionRecipient,
        address _proceedsRecipient
    ) {
        require(_durationSeconds >= 120, "Duration must be >= 120 seconds");
        require(_extensionSeconds >= 30, "Extension must be >= 30 seconds");
        require(_commissionRecipient != address(0), "Commission recipient cannot be zero address");
        require(_proceedsRecipient != address(0), "Proceeds recipient cannot be zero address");

        // The deployer is still the contract owner
        owner = msg.sender; 
        // Calculates and sets the initial end time for the auction based on the provided duration.
        initialEndTime = block.timestamp + _durationSeconds;
        // Sets the current auction end time, which can be extended by late bids.
        auctionEndTime = initialEndTime;
        // Stores the duration by which the auction will be extended if a bid comes in late.
        extensionTime = _extensionSeconds;
        // Assigns the address that will receive accumulated commissions.
        commissionRecipient = _commissionRecipient;
        // Assigns the address that will receive the net proceeds from the winning bid.
        proceedsRecipient = _proceedsRecipient;
        // Initializes a flag to ensure the winner's commission is processed only once.
        _winnerCommissionProcessed = false; // Initialize the new flag
    }

    /**
     * @dev Place a bid with ETH. Must be >= 5% higher than current highest bid.
     * Attempts to automatically refund previous highest bidder minus 2% commission.
     * Extends auction if bid in last 60 seconds.
     * The contract implements automatic refunds to outbid bids. 
     */
    function bid() external payable auctionOngoing {
        require(msg.sender != address(0), "Invalid address");
        require(msg.value > 0, "Bid amount must be greater than 0");

        uint256 minRequiredBid = highestBid == 0 ? 1 : highestBid + (highestBid * 5) / 100;
        require(msg.value >= minRequiredBid, "Bid must be at least 5% higher than current highest");

        // Process refund for the previous highest bidder, if one exists
        if (highestBidder != address(0)) {
            uint256 commissionAmount = (highestBid * 2) / 100;
            uint256 refundAmount = highestBid - commissionAmount;

            // Convert to payable for the transfer 
            address payable previousHighestBidder = payable(highestBidder); 

            // Update histories and total commission before the transfer 
            _refundHistory[previousHighestBidder].push(refundAmount);
            _commissionHistory[previousHighestBidder].push(commissionAmount);
            commissionTotal += commissionAmount;

            // Attempts to send the refund amount to the previous highest bidder.
            // Used call() for better compatibility and to avoid gas limitation
            (bool successRefund, ) = previousHighestBidder.call{value: refundAmount}("");
            // Reverts the transaction if the refund transfer was not successful.
            require(successRefund, "Automatic refund failed for previous bidder");
            
            // Emits an event to log that the refund was processed for the previous bidder.
            emit Refunded(previousHighestBidder, refundAmount);
        }

        // Update highest bid and bidder
        highestBidder = msg.sender;
        highestBid = msg.value;

        // Update records
        // Adds the new bid to a global array tracking all bids made in the auction.
        _allBids.push(Bid(msg.sender, msg.value));
        // Records the specific bid in a separate history for the bidder who placed it.
        _bidHistory[msg.sender].push(Bid(msg.sender, msg.value));

        // Extend auction if bid in last 60 seconds
        if (auctionEndTime - block.timestamp <= 60) {
            auctionEndTime = block.timestamp + extensionTime;
        }

        // Emits an event to signal that a new bid has been successfully placed,
        // It includes the address of the bidder and the amount of their bid.
        emit NewBid(msg.sender, msg.value);
    }

    /**
    * @dev Internal function to calculate and add the winning bid's 2% commission to the total.
    * This is designed to run only once after the auction concludes and a winner is determined.
    */
    function _processWinnerCommission() internal {
        // Checks if the winner's commission hasn't been processed yet, if there's a highest bidder, and if there's a winning bid amount.
        if (!_winnerCommissionProcessed && highestBidder != address(0) && highestBid > 0) {
            // Calculates 2% of the highest bid as the winner's commission.
            uint256 winnerCommission = (highestBid * 2) / 100;
            // Adds the calculated winner's commission to the overall total commission.
            commissionTotal += winnerCommission;
            // Sets the flag to true to prevent this commission from being processed again.
            _winnerCommissionProcessed = true;
        }
    }

    /**
     * @dev Owner claims all accumulated commissions, which are then sent to the designated commissionRecipient.
     * Can only be called by the contract owner after the auction has ended.
     * Commissions are calculated each time a refund is issued for the outbid bid. 
     * The winning bid's commission is calculated once the bid concludes and is added to the accumulated amount.
     */
    function claimCommission() external onlyOwner auctionEnded {
        // Calls an internal function to ensure the commission from the winning bid is calculated and added to the total.
        _processWinnerCommission();
        // Ensures there are commissions to claim before proceeding.
        require(commissionTotal > 0, "No commissions to claim");
        
        uint256 amount = commissionTotal;
        // Update state before external call and helps preventing reentrancy
        commissionTotal = 0; 

        // Used call() for better compatibility and to avoid gas limitation
        (bool success, ) = payable(commissionRecipient).call{value: amount}("");
        // Reverts the transaction if the refund transfer was not successful.
        require(success, "Commission transfer failed");

        // Emits an event to signal that the accumulated commissions have been successfully claimed
        // and sent to the designated commission recipient.
        emit CommissionClaimed(commissionRecipient, amount);
    }

    /**
     * @dev Owner claims the net proceeds from the highest bid, which are then sent to the designated proceedsRecipient.
     * Can only be called by the contract owner after the auction has ended.
     */
    function claimProceeds() external onlyOwner auctionEnded {
        // Ensure proceeds haven't been claimed yet and there's a winner
        require(highestBid > 0, "No winning bid to claim proceeds from");
        // Ensures that the proceeds haven't already been claimed to prevent double claiming.
        require(ownerProceedsPending == 0, "Proceeds already claimed");

        // Calls an internal function to ensure the commission from the winning bid is calculated and added to the total.       
        _processWinnerCommission(); // Ensure winner's commission is added
        // Recalculates the winner's 2% commission for the purpose of determining the net proceeds.
        uint256 winnerCommission = (highestBid * 2) / 100; 

        // Calculate the net proceeds for the winner.
        uint256 netProceeds = highestBid - winnerCommission;
        
        // Update state before external call and helps preventing reentrancy
        // ownerProceedsPending is used as a temporary holder before transfer and then reset.
        ownerProceedsPending = netProceeds; 
        uint256 amountToTransfer = ownerProceedsPending; 
        ownerProceedsPending = 0; // Reset BEFORE the transfer to prevent reentrancy issues

        // Used call() for better compatibility and to avoid gas limitation
        (bool success, ) = payable(proceedsRecipient).call{value: amountToTransfer}("");
        // Reverts the transaction if the refund transfer was not successful.
        require(success, "Proceeds transfer failed");
        
        // Emits an event indicating the successful transfer of auction proceeds to the designated recipient.
        emit ProceedsTransferred(proceedsRecipient, amountToTransfer);
        // Emits an event signaling the official end of the auction,
        // including the final winner and their winning bid amount.
        emit AuctionEnded(highestBidder, highestBid); // Emit here to signal final conclusion
    }

    // ---------------------------
    // Public read-only getters
    // ---------------------------

    /**
     * @dev Returns all bids (address + amount) recorded in the auction.
     */
    function getAllBids() external view returns (Bid[] memory) {
        return _allBids;
    }

    /**
     * @dev Returns bid history for a specific address.
     * @param bidder The address to query the bid history for.
     * @return An array of Bid structs representing all bids made by the specified address.
     */
    function getBidHistory(address bidder) external view returns (Bid[] memory) {
        return _bidHistory[bidder];
    }

    /**
     * @dev Returns refund history for a specific address.
     * @param bidder The address to query the refund history for.
     * @return An array of uint256 representing all refund amounts processed for the specified address.
     */
    function getRefundHistory(address bidder) external view returns (uint256[] memory) {
        return _refundHistory[bidder];
    }

    /**
     * @dev Returns commission history for a specific address.
     * @param bidder The address to query the commission history for.
     * @return An array of uint256 representing all commission amounts charged to the specified address.
     */
    function getCommissionHistory(address bidder) external view returns (uint256[] memory) {
        return _commissionHistory[bidder];
    }

    /**
     * @dev Returns how many seconds left until auction ends (0 if ended)
     */
    function getTimeLeft() external view returns (uint256) {
        if (block.timestamp >= auctionEndTime) {
            return 0;
        }
        return auctionEndTime - block.timestamp;
    }

    /**
     * @dev Returns whether auction ended and seconds left (0 if ended)
     */
    function getAuctionState() external view returns (bool isEnded, uint256 timeLeft) {
        isEnded = block.timestamp >= auctionEndTime; // State determined by time
        timeLeft = isEnded ? 0 : auctionEndTime - block.timestamp;
    }
}