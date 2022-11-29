// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/HyperlaneFacetLibrary.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "@hyperlane-xyz/core/interfaces/IOutbox.sol";
import "forge-std/console.sol";


// Hyperlane Facet for non Axon chain
contract HyperlaneFacet is Modifiers, ReentrancyGuard {

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

    function bridgeTokenAndCallViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) public {
        console.log(msg.sender);
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        bytes memory message = abi.encode(account,token,amount,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(hs.hyperlaneOutbox).dispatch(
            hs.axonDomain,
            TypeCasts.addressToBytes32(hs.axonInbox),
            messageWithAction
        );
    }

    function bridgeMultiTokenAndCallViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) public {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        bytes memory message = abi.encode(account,tokens,amounts,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(hs.hyperlaneOutbox).dispatch(
            hs.axonDomain,
            TypeCasts.addressToBytes32(hs.axonInbox),
            messageWithAction
        );
    }
}