// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/HyperlaneFacetLibrary.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "@hyperlane-xyz/core/interfaces/IOutbox.sol";
import "../../interfaces/IBridgeFacet.sol";


// Hyperlane Facet for non Axon chain //TODO : Should we make this all `internal` ?
contract HyperlaneFacet is IBridgeFacet, Modifiers, ReentrancyGuard {

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

    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) public payable override validRouter  {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        bytes memory message = abi.encode(account,token,amount,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(hs.hyperlaneOutbox).dispatch(
            hs.axonDomain,
            TypeCasts.addressToBytes32(hs.axonInbox),
            messageWithAction
        );
    }

    function bridgeMultiTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) public payable override validRouter {
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