pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./lib/ConfigLib.sol";
import "./lib/DeployLib.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployNexusMultiChain is Script{
    function run() public {
        string memory axon = vm.envString("AXON");
        string[] memory remotes = vm.envString("REMOTES",",");
        ConfigLib.prepareNetworksOutJson(axon,remotes,vm);

        ConfigLib.DeployConfig memory axonDeployConfig = ConfigLib.readDeployConfig(vm,axon);
        uint axonFork = vm.createFork(axonDeployConfig.rpcUrl);
        vm.selectFork(axonFork);
        vm.startBroadcast();
        ConfigLib.AxonNexusConfig memory axonContracts = DeployLib.deployCoreContractsAxon();
        DeployLib.initializeAxonNexus(axonDeployConfig,axonContracts);
        vm.stopBroadcast();
        axonContracts.chainName = axon;
        axonContracts.domainId = axonDeployConfig.chainId;

        //write to json file
        ConfigLib.writeAxonNexusConfig(axonContracts,vm);

        ConfigLib.DeployConfig memory  remoteDeployConfig;
        ConfigLib.NexusConfig memory nexusContracts;
        for(uint i; i<remotes.length;){
            remoteDeployConfig = ConfigLib.readDeployConfig(vm,remotes[i]);
            uint remoteFork = vm.createFork(remoteDeployConfig.rpcUrl);
            vm.selectFork(remoteFork);
            vm.startBroadcast();
            nexusContracts = DeployLib.deployCoreContracts();
            DeployLib.initializeRemoteNexus(remoteDeployConfig,nexusContracts,axonContracts.nexusDiamond,axonContracts.domainId);
            vm.stopBroadcast();
            nexusContracts.chainName = remotes[i];
            nexusContracts.domainId = remoteDeployConfig.chainId;
            ConfigLib.writeNexusConfig(nexusContracts,vm);
            unchecked{
                ++i;
            }
        }

        // TODO: this script ideally should perform "register" steps from PostDeployAxonLinker.
    }
}