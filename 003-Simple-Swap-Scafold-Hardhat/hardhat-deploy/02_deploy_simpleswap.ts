/**
 * @title Deploy SimpleSwap with gas limit
 * @notice Deploys the SimpleSwap contract using addresses from already-deployed ZimmerCoin and XmenCoin.
 *
 * @dev Uses explicit gasLimit to ensure compatibility with coverage tools.
 */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

const deploySimpleSwap: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, get } = hre.deployments;

  const token1Deployment = await get("ZimmerCoin");
  const token2Deployment = await get("XmenCoin");

  const token1Address = token1Deployment.address;
  const token2Address = token2Deployment.address;

  console.log("Found Token 1 (ZimmerCoin) at address:", token1Address);
  console.log("Found Token 2 (XmenCoin) at address:", token2Address);

  await deploy("SimpleSwap", {
    from: deployer,
    args: [token1Address, token2Address],
    log: true,
    autoMine: true,
    gasLimit: 6_000_000, ///< Set gas limit to ensure compatibility with coverage environments
  });

  const simpleSwap = await hre.ethers.getContract<Contract>("SimpleSwap", deployer);
  console.log("🚀 SimpleSwap deployed to:", await simpleSwap.getAddress());
  console.log("Internal TOKEN_A_ADDRESS:", await simpleSwap.TOKEN_A_ADDRESS());
  console.log("Internal TOKEN_B_ADDRESS:", await simpleSwap.TOKEN_B_ADDRESS());
};

export default deploySimpleSwap;
deploySimpleSwap.tags = ["SimpleSwap"];
