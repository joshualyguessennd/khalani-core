pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./lib/ConfigLib.sol";
import "./lib/DeployLib.sol";
import "../src/PSM/KaiPSM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Deploy is Script{
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
    }

    function deployMirrorTokensAndRegister(
        uint axonFork,
        uint remoteFork,
        uint chainId,
        address axonNexus,
        string memory remote,
        address remoteNexus,
        address[] memory tokens
    ) private{
        for(uint i; i<tokens.length;){
            vm.selectFork(remoteFork);
            string memory nameSuffix = string.concat('/',remote);
            string memory name = string.concat(ERC20(tokens[i]).name(),nameSuffix);
            string memory symbolSuffix = string.concat('.',remote);
            string memory symbol = string.concat(ERC20(tokens[i]).symbol(),symbolSuffix);
            vm.selectFork(axonFork);
            vm.startBroadcast();
            address mirrorToken = DeployLib.deployMirrorToken(tokens[i],name,symbol,chainId,axonNexus);
            vm.stopBroadcast();
            vm.selectFork(remoteFork);
            vm.startBroadcast();
            MsgHandlerFacet(remoteNexus).addChainTokenForMirrorToken(tokens[i],mirrorToken);
            vm.stopBroadcast();
            unchecked{
                ++i;
            }
        }

    }
}