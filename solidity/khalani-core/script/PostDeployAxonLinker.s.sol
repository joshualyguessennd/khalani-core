pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./lib/ConfigLib.sol";
import "./lib/DeployLib.sol";
import "../src/Nexus/facets/bridges/AxonMultiBridgeFacet.sol";
import "../src/Nexus/facets/bridges/AxonHandlerFacet.sol";
import "../src/Nexus/facets/factory/TokenRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

/**
 * @dev after all the contracts on Axon and remote chains are deployed,
 * this script registers the end-chains's Nexus addresses and KAI addresses
 * into the Axon's contracts.
 *
 * TODO: this script should be part of the DeployNexusMultiChain.
*/
contract PostDeployAxonLinker is Script {
    function run() public {
        string memory axon = vm.envString("AXON");
        string[] memory remotes = vm.envString("REMOTES",",");
        ConfigLib.DeployConfig memory axonDeployConfig = ConfigLib.readDeployConfig(vm, axon);
        ConfigLib.AxonNexusConfig memory axonNexusConfig = ConfigLib.readAxonNexusConfig(vm, axon, axonDeployConfig.chainId);

        uint axonFork = vm.createFork(axonDeployConfig.rpcUrl);
        vm.selectFork(axonFork);

        ConfigLib.DeployConfig memory remoteDeployConfig;
        ConfigLib.NexusConfig memory remoteNexusConfig;
        for (uint i; i < remotes.length; ){
            string memory chainName = remotes[i];
            remoteDeployConfig = ConfigLib.readDeployConfig(vm, chainName);
            remoteNexusConfig = ConfigLib.readNexusConfig(vm, chainName, remoteDeployConfig.chainId);

            uint chainId = remoteDeployConfig.chainId;
            address remoteNexus = remoteNexusConfig.nexusDiamond;

            vm.startBroadcast();
            AxonMultiBridgeFacet(axonNexusConfig.nexusDiamond).addChainInbox(chainId, remoteNexus);
            AxonHandlerFacet(axonNexusConfig.nexusDiamond).addValidNexusForChain(uint32(chainId), TypeCasts.addressToBytes32(remoteNexus));
            StableTokenRegistry(axonNexusConfig.nexusDiamond).registerKai(chainId, remoteNexusConfig.kai);
            vm.stopBroadcast();
            unchecked {
                ++i;
            }
        }
    }
}