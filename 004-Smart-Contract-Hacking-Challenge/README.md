# Grader5 Contract Hacking Challenge

---
This repository contains the `Grader5.sol` smart contract, which was part of a Solidity hacking challenge, and `Grader5Hacker.sol`, a contract designed to exploit a specific vulnerability in `Grader5.sol` to successfully register a student's name.

---
Autor: Martin Nicolas Serafini

---

## 📝 Table of Contents

* [Overview](#overview)
* [Vulnerability Explained](#vulnerability-explained)
* [The Hack](#the-hack)
* [Usage Instructions](#usage-instructions)
* [Contract Addresses](#contract-addresses)

---

## Overview

The `Grader5.sol` contract is designed to manage student grading. A key requirement for a user to call the `gradeMe` function (which registers a student's name and assigns a grade) is that `counter[msg.sender]` must be greater than 1. The `retrieve` function is intended to interact with this `counter`.

The challenge was to find a way to satisfy this `counter` requirement despite the seemingly restrictive logic within the `retrieve` function.

---

## Vulnerability Explained

The `Grader5.sol` contract contains a **re-entrancy vulnerability** within its `retrieve` function, combined with a flawed state management logic for the `counter` variable.

Let's break down the `retrieve` function's relevant parts:

```solidity
function retrieve() external payable {
    // ...
    counter[msg.sender]++; // 1. Increments the counter
    // ...
    (bool sent, ) = payable(msg.sender).call{value: 1, gas: gasleft()}(""); // 2. Sends 1 wei back to msg.sender
    require(sent, "Failed to send Ether");
    if(counter[msg.sender]<2) { // 3. Resets counter to 0 if it's less than 2
        counter[msg.sender]=0;
    }
}
```
Normally, if a user calls retrieve():
* counter[msg.sender] goes from 0 to 1.
* Ether is sent back.
* The if (1 < 2) condition is true, so counter[msg.sender] is reset to 0.

This loop makes it seem impossible for counter[msg.sender] to ever be greater than 1 (specifically, 2 or 3) when retrieve finishes.

---

The flaw lies in the sequence: the counter is incremented, then Ether is sent before the final reset condition is evaluated. This creates a window for a re-entrancy attack.

## The Hack
The Grader5Hacker.sol contract exploits this re-entrancy vulnerability. Here's the methodology:

*  Initial Call: The Hacker contract calls Grader5.retrieve() for the first time.
    * Inside Grader5.retrieve(), counter[address(Hacker)] becomes 1.
    * Grader5 then attempts to send 1 wei back to the Hacker contract.
* Re-entrancy: When the Hacker contract receives this 1 wei, its receive() function (or fallback()) is automatically triggered.
    * Inside Hacker's receive() function, a second call to Grader5.retrieve() is immediately made (re-entering the Grader5 contract).
* Counter Manipulation:
    * During this nested (re-entrant) call to Grader5.retrieve(), counter[address(Hacker)] is still 1 (because the outer call hasn't finished its execution, and thus the reset to 0 hasn't occurred yet).
    * counter[address(Hacker)] is incremented again, becoming 2.
    * Now, when the if (counter[msg.sender] < 2) check is performed, it's if (2 < 2), which is false. Therefore, counter[address(Hacker)] remains 2 and is not reset to 0.
    * The inner retrieve call finishes.
* Completion & Grade: The outer retrieve call in Grader5 resumes. It also finds counter[address(Hacker)] to be 2. Its if (2 < 2) condition is also false. The outer retrieve call finishes.
    * At this point, counter[address(Hacker)] is successfully set to 2.
    * The hackAndGrade function in Grader5Hacker.sol then proceeds to call Grader5.gradeMe("Martin Serafini"), which now successfully passes the require(counter[msg.sender] > 1) check, registering the name.

This method effectively bypasses the intended counter reset logic by performing a nested call that changes the state before the reset condition is met.

--- 

## Usage Instructions
These instructions detail how to deploy and execute the Hacker contract using Remix IDE.

**Prerequisites**
* MetaMask installed in your browser.
* Access to Remix Ethereum IDE.
* Connected to the correct Ethereum testnet where the Grader5 contract is deployed (e.g., Sepolia).
* Some test Ether in your MetaMask wallet on that network.
**Step-by-Step Guide**
* Open Remix IDE: Go to Remix Ethereum IDE.
* Create IGrader.sol (Optional but Recommended):
    * In the "File Explorers" panel, click "Create new file".
    * Name it IGrader.sol.
    * Paste the IGrader interface definition (from Grader5Hacker.sol or directly from this README) into this file.
* Create Hacker.sol:
    * Create a new file named Hacker.sol.
    * Paste the entire Grader5Hacker.sol contract code (including the NatSpec comments) into this file.
* Compile the Contracts:
    * Navigate to the "Solidity Compiler" tab (the icon resembling a Solidity logo).
    * Ensure Hacker.sol is selected in the "CONTRACT" dropdown.
    * Verify that the compiler version is compatible (0.8.22 or a recent 0.8.x).
    * Click "Compile Hacker.sol".
* Deploy the Hacker Contract:
    * Go to the "Deploy & run transactions" tab (the Ethereum logo icon).
    * In the "Environment" dropdown, select "Injected Provider - Metamask". Confirm your MetaMask is connected to the target testnet.
    * In the "CONTRACT" dropdown, ensure Hacker - Hacker.sol is selected.
    * In the "Deploy" section, next to the "Deploy" button, there's an input field for the _graderAddress constructor argument.
    * Paste the Grader5 contract address: 0x5733eE985e22eFF46F595376d79e31413b1A1e16.
    * Click the "Deploy" button.
    * Confirm the transaction in your MetaMask wallet.

* Execute the Hack:
    * Once your Hacker contract is deployed, it will appear under "Deployed Contracts" in Remix. Expand it.
    * Locate the hackAndGrade function.
    * In the input field next to hackAndGrade, enter the name to be registered: "Martin Serafini" (include the double quotes).
    * In the "VALUE" field (above the transact button), input 8 and select "wei" as the unit (e.g., 0.000000000000000008 Ether). This amount is necessary for the retrieve calls.
    * Click the "transact" button next to hackAndGrade.
    * Confirm the transaction in your MetaMask wallet.

**Verification (Optional)**
* To verify the name was successfully registered:
* In Remix's "Deploy & run transactions" tab, in the "At Address" field, paste the Grader5 contract address: 0x5733eE985e22eFF46F595376d79e31413b1A1e16.
* Make sure Grader5 - Grader5.sol is selected in the "CONTRACT" dropdown (you might need to compile Grader5.sol first, as described in Step 2 of "How to Load the Full Grader5 Interface" section above, if you haven't already).
* Click "At Address".
* Expand the Grader5 contract.
* Call the students function and input "Martin Serafini". It should return a non-zero value (the grade).
* Call the isGraded function and input the address of your deployed Hacker contract. It should return true.
* Call the counter function and input the address of your deployed Hacker contract. It should return 2.

---

## Contract Addresses
* Grader5 Contract Address: 0x5733eE985e22eFF46F595376d79e31413b1A1e16
(Note: This is the challenge contract address. Ensure you are on the correct network where it's deployed.)
