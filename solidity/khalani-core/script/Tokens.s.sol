// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;

import "forge-std/Script.sol";
import "../src/USDCavax.sol";
import "../src/USDCeth.sol";
import "../src/OmniUSD.sol";

contract TokenScript is Script {
    // function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        USDCavax usdcavax = new USDCavax();
        USDCeth usdceth = new USDCeth();
        OmniUSD omniusd = new OmniUSD();

        vm.stopBroadcast();
    }
}
