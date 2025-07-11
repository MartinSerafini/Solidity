# SimpleSwap Exchange, Token Contracts, and Frontend

This repository houses a decentralized exchange (DEX) implementation, **`SimpleSwap`**, alongside two custom ERC20 tokens, **ZimmerCoin (ZMC)** and **XmenCoin (XMC)**. The entire project is developed using **Hardhat** for smart contract development and **Scaffold-ETH** for the rapid prototyping and creation of the accompanying frontend. This setup provides a robust and integrated environment for building, testing, and interacting with decentralized applications.

-----

## Project Overview and Features

The `SimpleSwap` contract is designed to facilitate the permissionless swapping of **ZMC** and **XMC** tokens. This implementation serves as a foundational example of core DEX functionalities, including liquidity provision and token exchange mechanisms, within a controlled development environment.

### Contracts

  * **`SimpleSwap.sol`**: The core exchange contract. It manages liquidity pools for ZMC and XMC, calculates swap rates based on liquidity, and executes token exchanges.
  * **`ZimmerCoin.sol` (ZMC)**: A standard **ERC20 token contract** representing ZimmerCoin.
  * **`XmenCoin.sol` (XMC)**: A standard **ERC20 token contract** representing XmenCoin.

### Key Features

  * **ERC20 Standard Compliance**: Both ZMC and XMC are fully compliant with the ERC20 token standard, ensuring interoperability.
  * **Liquidity Pools**: The `SimpleSwap` contract implements a basic automated market maker (AMM) model, allowing users to add and remove liquidity to the ZMC/XMC pair.
  * **Token Swapping**: Users can exchange ZMC for XMC, and vice versa, through the `SimpleSwap` contract.
  * **Automated Testing**: Comprehensive **unit tests** have been developed for all smart contracts (`SimpleSwap`, `ZimmerCoin`, and `XmenCoin`) to ensure functional correctness, security, and adherence to expected behavior.
  * **Scaffold-ETH Frontend**: A user-friendly **frontend interface** has been generated and integrated using Scaffold-ETH, enabling easy interaction with the deployed contracts, including viewing token balances, providing liquidity, and executing swaps.

-----

## Technical Stack and Prerequisites

This project leverages the power of Hardhat for blockchain development and Scaffold-ETH for rapid frontend prototyping.

### Prerequisites

Ensure you have the following installed:

  * **Node.js** (v18+ recommended)
  * **Yarn** (recommended) or npm
  * **Git**

### Installation

To set up the project locally, follow these steps:

1.  **Clone the repository**:
    ```bash
    git clone [repository_url]
    cd [project_directory]
    ```
2.  **Install dependencies**:
    ```bash
    yarn install
    # or
    npm install
    ```

-----

## Development and Deployment

This section outlines the primary commands for building, deploying, and interacting with the contracts and frontend.

### 1\. Start Your Local Blockchain (Hardhat Node)

In your first terminal, start the local development blockchain:

```bash
yarn chain
# or
npm run chain
```

This will run a local Hardhat network. Keep this terminal open.

### 2\. Deploy Contracts

In your second terminal, deploy the smart contracts to your local network:

```bash
yarn deploy
# or
npm run deploy
```

This command will deploy `ZimmerCoin`, `XmenCoin`, and `SimpleSwap` to your local Hardhat node. You'll see the contract addresses printed in the console.

*Note: Ensure your `packages/hardhat/deploy/00_deploy_your_contracts.js` script correctly handles the deployment and initial setup (e.g., minting initial tokens, adding initial liquidity to `SimpleSwap`).*

### 3\. Start the Frontend

In your third terminal, launch the Scaffold-ETH frontend:

```bash
yarn start
# or
npm run start
```

This will open the frontend in your web browser (usually at `http://localhost:3000`). You can now interact with your deployed `SimpleSwap` exchange and tokens\!

-----

## Testing

A robust suite of **unit tests** has been developed for all smart contracts to ensure their reliability and correctness. These tests cover ERC20 functionalities, liquidity pool operations, swap logic, and various edge cases.

### Running Tests & Coverage

To execute the tests, open a terminal in the `packages/hardhat` directory (or from the project root if using `yarn hardhat test`):

```bash
cd packages/hardhat
npx hardhat test
# or from project root:
# yarn hardhat test
```

This command will run all test files located in the `packages/hardhat/test/` directory, providing detailed output on test outcomes.

```bash
cd packages/hardhat
npx hardhat coverage
# or from project root:
# yarn hardhat coverage
```
This command will run all test files located in the `packages/hardhat/test/` directory, indicating the amount of coverage does test give to the contract.
