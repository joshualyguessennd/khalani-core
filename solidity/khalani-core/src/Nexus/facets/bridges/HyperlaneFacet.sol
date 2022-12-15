// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/LibAppStorage.sol";
import "./libraries/HyperlaneFacetLibrary.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "@hyperlane-xyz/core/interfaces/IOutbox.sol";
import "../../interfaces/IBridgeFacet.sol";
import {Call} from "../../Call.sol";

// Hyperlane Facet for non Axon chain //TODO : Should we make this all `internal` ?
contract HyperlaneFacet is IBridgeFacet, Modifiers {

    function initHyperlaneFacet(
        address _hyperlaneMailbox
    ) external onlyDiamondOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.hyperlaneMailbox = _hyperlaneMailbox;
    }

    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) public payable override validRouter  {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        bytes memory message = abi.encode(account,token,amount,calls);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(hs.hyperlaneMailbox).dispatch(
            uint32(s.axonChainId),
            TypeCasts.addressToBytes32(s.axonReceiver),
            messageWithAction
        );
    }


    function bridgeMultiTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) public payable override validRouter {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        bytes memory message = abi.encode(account,tokens,amounts,calls);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(hs.hyperlaneMailbox).dispatch(
            uint32(s.axonChainId),
            TypeCasts.addressToBytes32(s.axonReceiver),
            messageWithAction
        );
    }


}