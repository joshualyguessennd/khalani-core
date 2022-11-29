// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "../../interfaces/IBridgeFacet.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "./libraries/CelerFacetLibrary.sol";

contract CelerFacet is IBridgeFacet, Modifiers, MessageApp {

    function initCelerFacet(
        uint64 _axonDomain,
        address _messageBus,
        address _axonInbox
    ) external onlyDiamondOwner {
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        cs.axonDomain = _axonDomain;
        messageBus = _messageBus;
        cs.axonInbox = _axonInbox;
    }

    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) public override validRouter  {
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        bytes memory message = abi.encode(account,token,amount,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            cs.axonInbox,
            cs.axonDomain,
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
    ) public override validRouter {
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        bytes memory message = abi.encode(account,tokens,amounts,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            cs.axonInbox,
            cs.axonDomain,
            messageWithAction
        );
    }
}