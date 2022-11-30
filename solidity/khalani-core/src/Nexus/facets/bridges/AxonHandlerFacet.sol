// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@hyperlane-xyz/core/interfaces/IMessageRecipient.sol";
import "../AxonReceiver.sol";
import "../../libraries/LibAppStorage.sol";
import "./libraries/AxonMsgHandlerLibrary.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "@hyperlane-xyz/core/contracts/libs/Message.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

contract AxonHandlerFacet is IMessageRecipient, MessageApp, AxonReceiver {

    event CrossChainMsgReceived(
        uint32 indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    constructor(address _messageBus) MessageApp(_messageBus) {

    }

    function setBus(address _messageBus) internal {
        messageBus = _messageBus;
    }

    function _onlyNexus(uint32 _origin, bytes32 _sender) internal {
        AxonMsgHandlerStorage storage ds = AxonMsgHandlerLibrary.axonMsgHandlerStorage();
        require(ds.chainNexusMap[_origin]==_sender, "AxonHyperlaneHandler : invalid nexus");
    }

    function initializeAxonHandler(address _inbox, address _messageBus) public onlyDiamondOwner {
        s.inbox = _inbox;
        setBus(_messageBus);
    }

    function addTokenMirror(uint32 chainDomain, address token, address mirrorToken) public onlyDiamondOwner {
        LibAccountsRegistry._addChainMirrorTokenMapping(chainDomain,token,mirrorToken);
    }

    function addValidNexusForChain(uint32 chainId, bytes32 nexus) public onlyDiamondOwner{
        AxonMsgHandlerLibrary._setChainNexusMapping(chainId,nexus);
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override onlyInbox {
        _onlyNexus(_origin, _sender); //keeping as function to avoid deep stack
        emit CrossChainMsgReceived(_origin, _sender, _message);
        (LibAppStorage.TokenBridgeAction action, bytes memory executionMsg) =
        abi.decode(_message, (LibAppStorage.TokenBridgeAction,bytes));

        if(action == LibAppStorage.TokenBridgeAction.DepositMulti) {
            (address account, address[] memory tokens, uint256[] memory amounts, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
            (address, address[], uint256[], bytes32, bytes));
            for(uint i=0; i<tokens.length; i++){
                tokens[i] = LibAccountsRegistry._getMirrorToken(_origin,tokens[i]);
            }
            depositMultiTokenAndCall(account,tokens,amounts,_origin,toContract,data);
        } else {
            (address account, address token, uint256 amount, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
            (address, address, uint256, bytes32, bytes));
            token = LibAccountsRegistry._getMirrorToken(_origin,token);
            if(action == LibAppStorage.TokenBridgeAction.Deposit) {
                depositTokenAndCall(account,token,amount,_origin,toContract,data);
            } else if (action == LibAppStorage.TokenBridgeAction.Withdraw) {
                withdrawTokenAndCall(account,token,amount,_origin,toContract,data);
            }
        }
    }

    function executeMessage(
        address _sender,
        uint64 _origin,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        _onlyNexus(uint32(_origin), TypeCasts.addressToBytes32(_sender)); //keeping as function to avoid deep stack
        emit CrossChainMsgReceived(uint32(_origin), TypeCasts.addressToBytes32(_sender), _message);
        (LibAppStorage.TokenBridgeAction action, bytes memory executionMsg) =
        abi.decode(_message, (LibAppStorage.TokenBridgeAction,bytes));

        if(action == LibAppStorage.TokenBridgeAction.DepositMulti) {
            (address account, address[] memory tokens, uint256[] memory amounts, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
                (address, address[], uint256[], bytes32, bytes));
            for(uint i=0; i<tokens.length; i++){
                tokens[i] = LibAccountsRegistry._getMirrorToken(uint32(_origin),tokens[i]);
            }
            depositMultiTokenAndCall(account,tokens,amounts,uint32(_origin),toContract,data);
        } else {
            (address account, address token, uint256 amount, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
                (address, address, uint256, bytes32, bytes));
            token = LibAccountsRegistry._getMirrorToken(uint32(_origin),token);
            if(action == LibAppStorage.TokenBridgeAction.Deposit) {
                depositTokenAndCall(account,token,amount,uint32(_origin),toContract,data);
            } else if (action == LibAppStorage.TokenBridgeAction.Withdraw) {
                withdrawTokenAndCall(account,token,amount,uint32(_origin),toContract,data);
            }
        }
        return ExecutionStatus.Success;
    }
}