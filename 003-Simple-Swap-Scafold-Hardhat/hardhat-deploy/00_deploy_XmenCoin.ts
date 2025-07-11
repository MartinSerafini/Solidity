/**
 * @title Deploy XmenCoin with gas limit
 * @notice This deploy script deploys the XmenCoin contract with an explicit gas limit.
 *
 * @dev Useful for ensuring compatibility with coverage tools or constrained testing environments.
 */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

const deployXmenCoin: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("XmenCoin", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
    gasLimit: 6_000_000, ///< Limit gas to prevent out-of-gas errors during test coverage
  });

  const xmenCoin = await hre.ethers.getContract<Contract>("XmenCoin", deployer);
  console.log("🚀 XmenCoin deployed to:", await xmenCoin.getAddress());
  console.log("💰 Initial supply minted to deployer:", await xmenCoin.balanceOf(deployer));
};

export default deployXmenCoin;
deployXmenCoin.tags = ["XmenCoin"];