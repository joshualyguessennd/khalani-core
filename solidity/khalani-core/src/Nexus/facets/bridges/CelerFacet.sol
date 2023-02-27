// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "../../interfaces/IBridgeFacet.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "../../libraries/LibNexusABI.sol";
import {Call} from "../../Call.sol";

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

    /**
     * @notice Bridge token to Axon chain
     * @param action Action to be performed on Axon chain
     * @param account Account to be credited on Axon chain
     * @param token Token to be bridged
     * @param amount Amount to be bridged
     * @param calls Array of calls to be executed on Axon chain
     */
    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) public payable override validRouter  {
        bytes memory messageWithAction = LibNexusABI.encodeData1(action,account,token,amount,calls);
        sendMessage(
            s.axonReceiver,
            uint64(s.axonChainId),
            messageWithAction,
            msg.value
        );
    }

    /**
     * @notice Bridge multiple tokens to Axon chain
     * @param action Action to be performed on Axon chain
     * @param account Account to be credited on Axon chain
     * @param tokens Array of tokens to be bridged
     * @param amounts Array of amounts to be bridged
     * @param calls Array of calls to be executed on Axon chain
     */
    function bridgeMultiTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) public payable override validRouter {
        bytes memory messageWithAction = LibNexusABI.encodeData2(action,account,tokens,amounts,calls);
        sendMessage(
            s.axonReceiver,
            uint64(s.axonChainId),
            messageWithAction,
            msg.value
        );
    }

    //function to pass an arbitrary message to axon using celer message bus
    function sendMultiCall(
        Call[] calldata calls
    ) public payable override  {
        bytes memory message = LibNexusABI.encodeData3(LibAppStorage.TokenBridgeAction.MultiCall, msg.sender, calls);
        sendMessage(
            s.axonReceiver,
            uint64(s.axonChainId),
            message,
            msg.value
        );
    }
}