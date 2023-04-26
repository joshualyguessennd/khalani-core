pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./lib/ConfigLib.sol";
import "./lib/DeployLib.sol";
import "../src/USDMirror.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";

/**
 * @dev local/test-only script to mint some amount of a token.
 *
 * This is used to simplify the balancer pool bootstrap, which requires 150K of KAI/USDT.goerli token
 * to be provided to the liquidity when deploying the pool.
 *
 * This script must be called with --private-key of the admin/minter having permissions to mint this token.
*/
contract BridgeToken is Script {
    function run() public {
        string memory remote = vm.envString("REMOTE");
        address[] memory tokens = vm.envAddress("TOKENS",",");
        address[] memory mirrorTokens = vm.envAddress("MIRROR_TOKENS",",");
        address kaiAxon =  vm.envAddress("KAI_AXON");
        uint unscaledAmount = vm.envUint("AMOUNT");
        address poolDeployer = vm.envAddress("POOL_DEPLOYER");
        ConfigLib.DeployConfig memory deployConfig = ConfigLib.readDeployConfig(vm, remote);
        ConfigLib.NexusConfig memory remoteNexusConfig = ConfigLib.readNexusConfig(vm, deployConfig.chainName, deployConfig.chainId);
        uint fork = vm.createSelectFork(deployConfig.rpcUrl);
        Call[] memory calls = new Call[](tokens.length+1);
        address[] memory tokensToBridge = new address[](tokens.length+1);
        uint[] memory amountsToBridge = new uint[](tokens.length+1);
        vm.startBroadcast();
        for(uint i;i<tokens.length;){
            ERC20PresetMinterPauserUpgradeable token = ERC20PresetMinterPauserUpgradeable(tokens[i]);
            uint amount = unscaledAmount * (10**token.decimals());
            token.mint(msg.sender, amount*2);
            console.log("Minted %s of the token %s %s", amount, address(token), token.name());
            token.approve(remoteNexusConfig.psm,amount);
            IKaiPSM(remoteNexusConfig.psm).addWhiteListedAsset(address(token));
            IKaiPSM(remoteNexusConfig.psm).mintKai(address(token),amount);
            token.approve(remoteNexusConfig.nexusDiamond,amount);
            tokensToBridge[i] = tokens[i];
            amountsToBridge[i] = amount;
            calls[i] = Call(
                address(mirrorTokens[i]),
                abi.encodeWithSignature("transfer(address,uint256)", poolDeployer, amount)
            );
            unchecked{
                ++i;
            }
        }
        uint totalKaiAmount = unscaledAmount*tokens.length* 1e18;
        address kai = remoteNexusConfig.kai;
        ERC20PresetMinterPauserUpgradeable(kai).approve(remoteNexusConfig.nexusDiamond,totalKaiAmount);
        tokensToBridge[tokens.length] = kai;
        amountsToBridge[tokens.length] = totalKaiAmount;
        calls[tokens.length] = Call(
            address(kaiAxon),
            abi.encodeWithSignature("transfer(address,uint256)", poolDeployer, totalKaiAmount)
        );
        CrossChainRouter(remoteNexusConfig.nexusDiamond).depositMultiTokenAndCall(tokensToBridge,amountsToBridge,calls);
        vm.stopBroadcast();

    }
}