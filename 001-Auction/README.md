---

# Auction Contract

---
## Author

Martin Nicolas Serafini

---

This repository contains a Solidity smart contract that implements an auction system. It allows participants to place bids, enforces bid increments, and handles auction extensions for last-minute bids.

---

## Features

* **Bid Increment Enforcement**: Requires new bids to be at least 5% higher than the current highest bid.
* **Auction Extension**: Bids placed within the last 60 seconds of the auction automatically extend the auction duration by a predefined `extensionTime`.
* **Automatic Refunds (for test purposes)**: Overbid amounts (minus a 2% commission) are immediately refunded to the previous highest bidder.
* **Time-Based Conclusion**: The auction automatically concludes when the `block.timestamp` surpasses `auctionEndTime`.
* **Commission Handling**: A 2% commission is applied to both overbids and the winning bid. The designated `commissionRecipient` (set during deployment) can claim accumulated commissions via the `claimCommission()` function.
* **Proceeds Claim**: The `proceedsRecipient` (set during deployment) can claim the net proceeds from the winning bid using `claimProceeds()` once the auction has officially ended.
* **Detailed History Tracking**:
    * **Bid History**: Tracks all bids made on the contract in order of completion.
    * **Participant-Specific History**: Maintains detailed records of all bids, refunds, and commissions for each individual participant.

---

## Pending Features

The following features are planned for future development:

* **Optimized Commission Calculation for Recurring Bidders**: In cases where the same bidder places multiple consecutive bids, the commission should ideally be calculated only on the difference between their previous and current bid, rather than the full bid amount.

---
