// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/HyperlaneFacetLibrary.sol";


// Hyperlane Facet for non Axon chain
contract HyperlaneFacet is Modifiers, ReentrancyGuard {
    //calls[i].to.call(calls[i].data);

    function initHyperlaneFacet(
        uint32 _axonDomain,
        address _hyperlaneOutbox,
        address _axonInbox
    ) external onlyDiamondOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.axonDomain = _axonDomain;
        hs.hyperlaneOutbox = _hyperlaneOutbox;
        hs.axonInbox = _axonInbox;
    }

//    function bridgeTokenAndCallViaHyperlane(
//        address token,
//        uint256 amount,
//        bool isPan,
//        bytes32 calldata toContract,
//        bytes calldata data
//    ) public nonReentrant {
//        Hyperla
//    }


}