// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "../../interfaces/IBridgeFacet.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";


contract CelerFacet is IBridgeFacet, Modifiers, MessageApp {

    constructor(address _messageBus) MessageApp(_messageBus){

    }

    function initCelerFacet(
        address _messageBus
    ) external onlyDiamondOwner {
        setCelerMessageBus(_messageBus);
    }

    function setCelerMessageBus(address _celerMessageBus) internal {
        messageBus = _celerMessageBus;
    }
    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) public payable override validRouter  {
        bytes memory message = abi.encode(account,token,amount,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            s.axonReceiver,
            uint64(s.axonChainId),
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
        bytes memory message = abi.encode(account,tokens,amounts,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            s.axonReceiver,
            uint64(s.axonChainId),
            messageWithAction,
            msg.value
        );
    }

}