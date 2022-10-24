// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;

import "forge-std/Script.sol";
import "../src/USDCavax.sol";
import "../src/USDCeth.sol";
import "../src/OmniUSD.sol";

contract MintScript is Script {
    address _USDCavax = vm.envAddress("USDC_AVAX_CONTRACT_ADDRESS");
    address _OmniUsd = vm.envAddress("OMNI_USD_USDC_AVAX_POOL_ADDRESS");
    address _USDCeth = vm.envAddress("USDC_ETH_CONTRACT_ADDRESS");
    address to = 0x27a1876A09581E02E583E002E42EC1322abE9655;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        USDCavax usdca = USDCavax(_USDCavax);
        USDCeth usdce = USDCeth(_USDCeth);
        OmniUSD omni = OmniUSD(_OmniUsd);

        omni.mint(to, 1000000e18);
        usdca.mint(to, 1000000e18);
        usdce.mint(to, 1000000e18);
        vm.stopBroadcast();
    }
}
