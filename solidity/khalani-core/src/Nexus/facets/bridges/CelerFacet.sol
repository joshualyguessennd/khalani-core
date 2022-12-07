// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "../../interfaces/IBridgeFacet.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "./libraries/CelerFacetLibrary.sol";


contract CelerFacet is IBridgeFacet, Modifiers, MessageApp {

    constructor(address _messageBus) MessageApp(_messageBus){

    }

    function initCelerFacet(
        uint32 _axonDomain,
        address _axonInbox,
        address _messageBus
    ) external onlyDiamondOwner {
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        setMessageBusI(_messageBus);
        cs.axonDomain = _axonDomain;
        cs.axonInbox = _axonInbox;
    }

    function setMessageBusI(address _messageBus) internal {
        messageBus = _messageBus;
    }
    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) public payable override validRouter  {
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        bytes memory message = abi.encode(account,token,amount,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            cs.axonInbox,
            cs.axonDomain,
            messageWithAction,
            msg.value
        );
    }

    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        bool isPan,
        bytes32  toContract,
        bytes calldata data
    ) public payable override validRouter  {
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        bytes memory message = abi.encode(account,token,amount,isPan,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            cs.axonInbox,
            cs.axonDomain,
            messageWithAction,
            msg.value
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
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        bytes memory message = abi.encode(account,tokens,amounts,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            cs.axonInbox,
            cs.axonDomain,
            messageWithAction,
            msg.value
        );
    }

    function bridgeMultiTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bool[] memory isPan,
        bytes32 toContract,
        bytes calldata data
    ) public payable override validRouter {
        CelerFacetLibrary.CelerStorage storage cs = CelerFacetLibrary.celerStorage();
        bytes memory message = abi.encode(account,tokens,amounts,isPan,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            cs.axonInbox,
            cs.axonDomain,
            messageWithAction,
            msg.value
        );
    }
}