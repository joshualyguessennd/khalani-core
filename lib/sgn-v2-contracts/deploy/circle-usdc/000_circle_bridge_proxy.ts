import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('CircleBridgeProxy', {
    from: deployer,
    log: true,
    args: [
      process.env.CIRCLE_BRIDGE,
      process.env.CIRCLE_BRIDGE_FEE_COLLECTOR
    ]
  });
};

deployFunc.tags = ['CircleBridgeProxy'];
deployFunc.dependencies = [];
export default deployFunc;
