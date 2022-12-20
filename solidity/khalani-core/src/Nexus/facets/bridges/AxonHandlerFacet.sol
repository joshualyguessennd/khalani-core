// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@hyperlane-xyz/core/interfaces/IMessageRecipient.sol";
import "../AxonReceiver.sol";
import "../../libraries/LibAppStorage.sol";
import "../../libraries/LibTokenFactory.sol";
import "./libraries/AxonMsgHandlerLibrary.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "@hyperlane-xyz/core/contracts/libs/Message.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "./libraries/LibAxonMultiBridgeFacet.sol";
import {Call} from "../../Call.sol";


//This is a facet of Nexus diamond on all non-axon chain ,
//this contract is used to handle the cross-chain messages from axon
contract AxonHandlerFacet is IMessageRecipient, AxonReceiver, MessageApp {

    event CrossChainMsgReceived(
        uint indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    constructor(address _celerMessageBus) MessageApp(_celerMessageBus) {

    }

    modifier onlyInbox() {
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();    
        require(msg.sender==ds.hyperlaneMailbox,"only inbox can call");
        _;
    }

    function setCelerMessageBus(address _celerMessageBus) internal {
        messageBus = _celerMessageBus;
    }

    function _onlyNexus(uint32 _origin, bytes32 _sender) internal {
        AxonMsgHandlerStorage storage ds = AxonMsgHandlerLibrary.axonMsgHandlerStorage();
        require(ds.chainNexusMap[_origin]==_sender, "AxonHyperlaneHandler : invalid nexus");
    }

    function addValidNexusForChain(uint32 chainId, bytes32 nexus) public onlyDiamondOwner{
        AxonMsgHandlerLibrary._setChainNexusMapping(chainId,nexus);
    }

    /**
    *@notice - hyperlane receiver's handle function
    *@param _origin - chain id of origin chain
    *@param _sender - sender's address
    *@param _message - message body
    */
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
            (address account, address[] memory tokens, uint256[] memory amounts, Call[] memory calls) = abi.decode(executionMsg,
            (address, address[], uint256[], Call[]));
            uint length = tokens.length;
            for(uint i; i<length;){
                tokens[i] = LibTokenFactory.getMirrorToken(_origin,tokens[i]);

                unchecked {
                    ++i;
                }
            }
            depositMultiTokenAndCall(account,tokens,amounts,_origin,calls);
        } else {
            (address account, address token, uint256 amount,Call[] memory calls) = abi.decode(executionMsg,
            (address, address, uint256, Call[]));
            token = LibTokenFactory.getMirrorToken(_origin,token);
            if(action == LibAppStorage.TokenBridgeAction.Deposit) {
                depositTokenAndCall(account,token,amount,_origin, calls);
            }
        }
    }

    /**
    *@notice - celer receiver's executeMessage function
    *@param _sender - sender's address
    *@param _origin - chain id of origin chain
    *@param _message - message body
    */
    function executeMessage(
        address _sender,
        uint64 _origin,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        _onlyNexus(uint32(_origin), TypeCasts.addressToBytes32(_sender)); //keeping as function to avoid deep stack
        emit CrossChainMsgReceived(_origin, TypeCasts.addressToBytes32(_sender), _message);
        (LibAppStorage.TokenBridgeAction action, bytes memory executionMsg) =
        abi.decode(_message, (LibAppStorage.TokenBridgeAction,bytes));

        if(action == LibAppStorage.TokenBridgeAction.DepositMulti) {
            (address account, address[] memory tokens, uint256[] memory amounts, Call[] memory calls) = abi.decode(executionMsg,
                (address, address[], uint256[], Call[]));
            uint length = tokens.length;
            for(uint i; i<length;){
                tokens[i] = LibTokenFactory.getMirrorToken(_origin,tokens[i]);
                unchecked{
                    ++i;
                }
            }
            depositMultiTokenAndCall(account,tokens,amounts,uint32(_origin), calls);
        } else {
            (address account, address token, uint256 amount, Call[] memory calls) = abi.decode(executionMsg,
                (address, address, uint256, Call[]));
            token = LibTokenFactory.getMirrorToken(_origin,token);
            if(action == LibAppStorage.TokenBridgeAction.Deposit) {
                depositTokenAndCall(account,token,amount,uint32(_origin),calls);
            }
        }
        return ExecutionStatus.Success;
    }
}