pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./lib/ConfigLib.sol";
import "./lib/DeployLib.sol";
import "../src/FakeStable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployFakeStable is Script {
    function run() public {
        string memory remote = vm.envString("REMOTE");
        string[] memory tokens = vm.envString("TOKENS",",");
        uint[] memory decimals = vm.envUint("DECIMALS",",");
        ConfigLib.DeployConfig memory remoteDeployConfig = ConfigLib.readDeployConfig(vm, remote);
        uint remoteFork = vm.createSelectFork(remoteDeployConfig.rpcUrl);
        vm.startBroadcast();
        for(uint i;i<tokens.length;){
            FakeStable token = new FakeStable(tokens[i],tokens[i],uint8(decimals[i]));
            token.mint(vm.envAddress("FAUCET"),vm.envUint("FAUCET_AMOUNT")*10**decimals[i]);
            console.log("Token %s deployed at address %s", tokens[i], address(token));
            unchecked{
                ++i;
            }
        }
        vm.stopBroadcast();
    }
}


