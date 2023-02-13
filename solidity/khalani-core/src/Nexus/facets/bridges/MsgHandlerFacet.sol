// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@hyperlane-xyz/core/interfaces/IMessageRecipient.sol";
import "../../libraries/LibAppStorage.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "@hyperlane-xyz/core/contracts/libs/Message.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../../libraries/LibAppReceiver.sol";
import "../Receiver.sol";
import {HyperlaneStorage} from "./libraries/HyperlaneFacetLibrary.sol";
import "./libraries/HyperlaneFacetLibrary.sol";
import {Call} from "../../Call.sol";
import "../../Errors.sol";

contract MsgHandlerFacet is IMessageRecipient, Receiver, MessageApp {

    event CrossChainMsgReceived(
        uint indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    constructor(address _celerMessageBus) MessageApp(_celerMessageBus) {

    }

    modifier onlyInbox() {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        if(msg.sender!=hs.hyperlaneMailbox){
            revert InvalidInbox();
        }
        _;
    }


    function addChainTokenForMirrorToken(address token, address mirrorToken) public onlyDiamondOwner {
        LibAppReceiver._addChainTokenForMirrorToken(mirrorToken,token);
    }

    function _onlyNexus(address _sender) internal {
        if(_sender != s.axonReceiver){
            revert InvalidNexus();
        }
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
            (address source, address account, address[] memory tokens, uint256[] memory amounts, Call[] memory calls) = abi.decode(executionMsg,
                (address, address, address[], uint256[], Call[]));
            uint length = tokens.length;
            for(uint i; i<length;){
                tokens[i] = LibAppReceiver._getChainToken(tokens[i]);

                unchecked {
                    ++i;
               }
            }
            withdrawMultiTokenAndCall(source,account,tokens,amounts,calls);
        } else {
            (address source, address account, address token, uint256 amount, Call[] memory calls) = abi.decode(executionMsg,
                (address, address, address, uint256, Call[]));
            token = LibAppReceiver._getChainToken(token);
            if(action == LibAppStorage.TokenBridgeAction.Withdraw) {
                withdrawTokenAndCall(source,account,token,amount,calls);
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
        emit CrossChainMsgReceived(_origin, TypeCasts.addressToBytes32(_sender), _message);
        (LibAppStorage.TokenBridgeAction action, bytes memory executionMsg) =
        abi.decode(_message, (LibAppStorage.TokenBridgeAction,bytes));

        if(action == LibAppStorage.TokenBridgeAction.WithdrawMulti) {
            (address source, address account, address[] memory tokens, uint256[] memory amounts, Call[] memory calls) = abi.decode(executionMsg,
                (address, address, address[], uint256[], Call[]));
            uint length = tokens.length;
            for(uint i; i<length;){
                tokens[i] = LibAppReceiver._getChainToken(tokens[i]);
                unchecked{
                    ++i;
                }
            }
            withdrawMultiTokenAndCall(source,account,tokens,amounts,calls);
        } else {
            (address source, address account, address token, uint256 amount, Call[] memory calls) = abi.decode(executionMsg,
                (address, address, address, uint256, Call[]));
            token = LibAppReceiver._getChainToken(token);
            if(action == LibAppStorage.TokenBridgeAction.Withdraw) {
                withdrawTokenAndCall(source,account,token,amount,calls);
            }
        }
        return ExecutionStatus.Success;
    }
}