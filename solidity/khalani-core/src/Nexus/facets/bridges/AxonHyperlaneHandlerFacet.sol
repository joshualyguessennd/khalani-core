// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../../../hyperlane-monorepo/solidity/interfaces/IMessageRecipient.sol";
import "../AxonReceiver.sol";
import "../../libraries/LibAppStorage.sol";
pragma experimental ABIEncoderV2;

contract AxonHyperlaneHandlerFacet is IMessageRecipient, AxonReceiver {

    event CrossChainMsgReceived(
        uint32 indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    function initializeAxonHandler(address _inbox) public onlyDiamondOwner {
        s.inbox = _inbox;
    }

    function addTokenMirror(uint32 chainDomain, address token, address mirrorToken) public onlyDiamondOwner {
        LibAccountsRegistry._addChainMirrorTokenMapping(chainDomain,token,mirrorToken);
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override onlyInbox {
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
}