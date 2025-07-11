/**
 * @title Deploy SimpleSwap with gas limit
 * @notice Deploys the SimpleSwap contract using addresses of pre-deployed ZimmerCoin and XmenCoin contracts.
 * @dev Uses explicit gasLimit to ensure compatibility with coverage tools.
 */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * @notice Deploys the SimpleSwap contract.
 * @dev Retrieves addresses of ZimmerCoin and XmenCoin contracts and deploys SimpleSwap with those addresses.
 *      Sets gasLimit explicitly for coverage compatibility.
 * @param hre Hardhat runtime environment injected automatically.
 */
const deploySimpleSwap: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, get } = hre.deployments;

  /**
   * @notice Retrieves deployment info for ZimmerCoin contract.
   * @return Deployment object containing address and metadata.
   */
  const token1Deployment = await get("ZimmerCoin");
  /**
   * @notice Retrieves deployment info for XmenCoin contract.
   * @return Deployment object containing address and metadata.
   */
  const token2Deployment = await get("XmenCoin");

  const token1Address = token1Deployment.address;
  const token2Address = token2Deployment.address;

  console.log("Found Token 1 (ZimmerCoin) at address:", token1Address);
  console.log("Found Token 2 (XmenCoin) at address:", token2Address);

  /**
   * @notice Deploys SimpleSwap contract.
   * @param from Address deploying the contract.
   * @param args Constructor arguments, token1 and token2 addresses.
   * @param log Enables deployment logging.
   * @param autoMine Auto-mining for tests and coverage.
   * @param gasLimit Gas limit for deployment transaction.
   */
  await deploy("SimpleSwap", {
    from: deployer,
    args: [token1Address, token2Address],
    log: true,
    autoMine: true,
    gasLimit: 6_000_000, ///< Gas limit set for coverage tool compatibility.
  });

  const simpleSwap = await hre.ethers.getContract<Contract>("SimpleSwap", deployer);

  console.log("🚀 SimpleSwap deployed to:", await simpleSwap.getAddress());
  console.log("Internal TOKEN_A_ADDRESS:", await simpleSwap.TOKEN_A_ADDRESS());
  console.log("Internal TOKEN_B_ADDRESS:", await simpleSwap.TOKEN_B_ADDRESS());
};

export default deploySimpleSwap;
deploySimpleSwap.tags = ["SimpleSwap"];

