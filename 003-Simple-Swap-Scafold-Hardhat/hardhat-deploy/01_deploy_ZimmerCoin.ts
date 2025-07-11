/**
 * @title Deploy ZimmerCoin with gas limit
 * @notice This deploy script deploys the ZimmerCoin contract with a gas limit suitable for coverage tools.
 *
 * @dev Ensures compatibility with coverage environments by setting gasLimit explicitly.
 */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

const deployZimmerCoin: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("ZimmerCoin", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
    gasLimit: 6_000_000, ///< Limit gas to avoid exceeding block gas limit during coverage
  });

  const zimmerCoin = await hre.ethers.getContract<Contract>("ZimmerCoin", deployer);
  console.log("🚀 ZimmerCoin deployed to:", await zimmerCoin.getAddress());
  console.log("💰 Initial supply minted to deployer:", await zimmerCoin.balanceOf(deployer));
};

export default deployZimmerCoin;
deployZimmerCoin.tags = ["ZimmerCoin"];
