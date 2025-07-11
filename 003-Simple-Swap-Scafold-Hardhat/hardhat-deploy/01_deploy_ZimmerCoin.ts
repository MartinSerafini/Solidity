/**
 * @title Deploy ZimmerCoin with gas limit
 * @notice This deploy script deploys the ZimmerCoin contract with a gas limit suitable for coverage tools.
 * @dev Ensures compatibility with coverage environments by setting gasLimit explicitly.
 */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * @notice Deploys the ZimmerCoin contract.
 * @dev Sets a gasLimit explicitly to prevent exceeding block gas limit in coverage tools.
 * @param hre Hardhat runtime environment injected automatically.
 */
const deployZimmerCoin: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  /**
   * @notice Deploy ZimmerCoin contract with no constructor arguments.
   * @param from Address of deployer.
   * @param args Constructor arguments (empty).
   * @param log Enables deployment logging.
   * @param autoMine Enables auto mining for coverage/test environments.
   * @param gasLimit Sets explicit gas limit for deployment.
   */
  await deploy("ZimmerCoin", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
    gasLimit: 6_000_000, ///< Gas limit to ensure compatibility with coverage tools.
  });

  const zimmerCoin = await hre.ethers.getContract<Contract>("ZimmerCoin", deployer);

  console.log("🚀 ZimmerCoin deployed to:", await zimmerCoin.getAddress());
  console.log("💰 Initial supply minted to deployer:", await zimmerCoin.balanceOf(deployer));
};

export default deployZimmerCoin;
deployZimmerCoin.tags = ["ZimmerCoin"];
