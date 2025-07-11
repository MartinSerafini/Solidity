/**
 * @title Deploy XmenCoin with gas limit
 * @notice This deploy script deploys the XmenCoin contract with an explicit gas limit.
 * @dev Useful for ensuring compatibility with coverage tools or constrained testing environments.
 */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * @notice Deploys the XmenCoin contract.
 * @dev Sets an explicit gasLimit to avoid out-of-gas errors in testing/coverage environments.
 * @param hre Hardhat runtime environment automatically injected.
 */
const deployXmenCoin: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  /**
   * @notice Deploy XmenCoin contract with no constructor arguments.
   * @param from Address of the deployer.
   * @param args Empty constructor arguments.
   * @param log Enables deployment logging.
   * @param autoMine Enables auto mining for local test/coverage environments.
   * @param gasLimit Limits gas to 6,000,000 to prevent out-of-gas during coverage.
   */
  await deploy("XmenCoin", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
    gasLimit: 6_000_000, ///< Explicit gas limit to prevent errors in test coverage.
  });

  const xmenCoin = await hre.ethers.getContract<Contract>("XmenCoin", deployer);

  console.log("🚀 XmenCoin deployed to:", await xmenCoin.getAddress());
  console.log("💰 Initial supply minted to deployer:", await xmenCoin.balanceOf(deployer));
};

export default deployXmenCoin;
deployXmenCoin.tags = ["XmenCoin"];
