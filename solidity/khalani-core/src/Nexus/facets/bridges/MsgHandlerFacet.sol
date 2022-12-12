// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@hyperlane-xyz/core/interfaces/IMessageRecipient.sol";
import "../../libraries/LibAppStorage.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "@hyperlane-xyz/core/contracts/libs/Message.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../../libraries/LibAppReceiver.sol";
import "../Receiver.sol";

contract MsgHandlerFacet is IMessageRecipient, MessageApp, Receiver {

    event CrossChainMsgReceived(
        uint32 indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    constructor(address _celerMessageBus) MessageApp(_celerMessageBus) {

    }

    function setCelerMessageBus(address _celerMessageBus) internal {
        messageBus = _celerMessageBus;
    }

    function initializeMsgHandler(address _hyperlaneInbox, address _celerMessageBus, address _axonNexus) public onlyDiamondOwner {
        LibAppReceiver.AppReceiverStorage storage ds = LibAppReceiver.appReceiverStorage();
        s.hyperlaneInbox = _hyperlaneInbox;
        setCelerMessageBus(_celerMessageBus);
        ds.axonNexus = _axonNexus;
    }

    function addChainTokenForMirrorToken(address token, address mirrorToken) public onlyDiamondOwner {
        LibAppReceiver._addChainTokenForMirrorToken(mirrorToken,token);
    }

    function _onlyNexus(address _sender) internal {
        LibAppReceiver.AppReceiverStorage storage ds = LibAppReceiver.appReceiverStorage();
        require(_sender == ds.axonNexus,"invalid nexus");
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override onlyInbox {
        _onlyNexus(TypeCasts.bytes32ToAddress(_sender)); //keeping as function to avoid deep stack
        emit CrossChainMsgReceived(_origin, _sender, _message);
        (LibAppStorage.TokenBridgeAction action, bytes memory executionMsg) =
        abi.decode(_message, (LibAppStorage.TokenBridgeAction,bytes));

        if(action == LibAppStorage.TokenBridgeAction.WithdrawMulti) {
            (address account, address[] memory tokens, uint256[] memory amounts, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
                (address, address[], uint256[], bytes32, bytes));
            for(uint i; i<tokens.length;){
                tokens[i] = LibAppReceiver._getChainToken(tokens[i]);

                unchecked {
                    ++i;
               }
            }
            withdrawMultiTokenAndCall(account,tokens,amounts,toContract,data);
        } else {
            (address account, address token, uint256 amount, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
                (address, address, uint256, bytes32, bytes));
            token = LibAppReceiver._getChainToken(token);
            if(action == LibAppStorage.TokenBridgeAction.Withdraw) {
                withdrawTokenAndCall(account,token,amount,toContract,data);
            }
        }
    }

    function executeMessage(
        address _sender,
        uint64 _origin,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        _onlyNexus(_sender); //keeping as function to avoid deep stack
        emit CrossChainMsgReceived(uint32(_origin), TypeCasts.addressToBytes32(_sender), _message);
        (LibAppStorage.TokenBridgeAction action, bytes memory executionMsg) =
        abi.decode(_message, (LibAppStorage.TokenBridgeAction,bytes));

        if(action == LibAppStorage.TokenBridgeAction.WithdrawMulti) {
            (address account, address[] memory tokens, uint256[] memory amounts, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
                (address, address[], uint256[], bytes32, bytes));
            for(uint i; i<tokens.length;){
                tokens[i] = LibAppReceiver._getChainToken(tokens[i]);
                unchecked{
                    ++i;
                }
            }
            withdrawMultiTokenAndCall(account,tokens,amounts,toContract,data);
        } else {
            (address account, address token, uint256 amount, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
                (address, address, uint256, bytes32, bytes));
            token = LibAppReceiver._getChainToken(token);
            if(action == LibAppStorage.TokenBridgeAction.Withdraw) {
                withdrawTokenAndCall(account,token,amount,toContract,data);
            }
        }
        return ExecutionStatus.Success;
    }
}