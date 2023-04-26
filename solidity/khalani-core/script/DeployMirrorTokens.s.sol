pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./lib/ConfigLib.sol";
import "./lib/DeployLib.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployMirrorTokens is Script {

    string  axon = vm.envString("AXON");
    string  remote = vm.envString("REMOTE");

    uint axonFork;
    uint remoteFork;
    string  chainName;
    uint chainId;
    address axonNexus;
    address remoteNexus;



    function run() public {

        ConfigLib.DeployConfig memory axonDeployConfig = ConfigLib.readDeployConfig(vm, axon);
        ConfigLib.DeployConfig memory remoteDeployConfig = ConfigLib.readDeployConfig(vm, remote);

        axonFork = vm.createFork(axonDeployConfig.rpcUrl);
        remoteFork = vm.createFork(remoteDeployConfig.rpcUrl);
        chainName = remoteDeployConfig.chainName;
        chainId = remoteDeployConfig.chainId;


        ConfigLib.NexusConfig memory remoteNexusConfig = ConfigLib.readNexusConfig(vm, remoteDeployConfig.chainName, remoteDeployConfig.chainId);
        ConfigLib.AxonNexusConfig memory axonNexusConfig = ConfigLib.readAxonNexusConfig(vm, axon, axonDeployConfig.chainId);
        remoteNexus = remoteNexusConfig.nexusDiamond;
        axonNexus = axonNexusConfig.nexusDiamond;

        deployMirrorTokensAndRegister(remoteDeployConfig.tokens);
    }

    function deployMirrorTokensAndRegister(address[] memory tokens) private {
        uint len = tokens.length;
        address[] memory mirrorTokens = new address[](len);
        for (uint i; i <len; ) {
            address token = tokens[i];
            vm.selectFork(remoteFork);
            string memory nameSuffix = string.concat('/', chainName);
            string memory name = string.concat(ERC20(token).name(), nameSuffix);
            string memory symbolSuffix = string.concat('.', chainName);
            string memory symbol = string.concat(ERC20(token).symbol(), symbolSuffix);
            uint8 decimals = ERC20(token).decimals();
            console.log("Deploying mirror token for %s: %s %s to axon", token, name, symbol);
            vm.selectFork(axonFork);
            vm.startBroadcast();
            address mirrorToken = DeployLib.deployMirrorToken(token, name, symbol, decimals, chainId, axonNexus);
            vm.stopBroadcast();
            vm.selectFork(remoteFork);
            vm.startBroadcast();
            MsgHandlerFacet(remoteNexus).addChainTokenForMirrorToken(token, mirrorToken);
            vm.stopBroadcast();
            mirrorTokens[i] = mirrorToken;
            unchecked {
                ++i;
            }
        }
        ConfigLib.writeMirrorTokens(chainName, tokens, mirrorTokens, vm);
    }
}