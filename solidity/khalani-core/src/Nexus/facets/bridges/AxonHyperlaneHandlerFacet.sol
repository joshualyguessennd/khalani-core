// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../../../hyperlane-monorepo/solidity/interfaces/IMessageRecipient.sol";
import "../AxonReceiver.sol";
import "../../libraries/LibAppStorage.sol";
pragma experimental ABIEncoderV2;

contract AxonHyperlaneHandlerFacet is IMessageRecipient, AxonReceiver {

    event CrossChainMsgReceived(
        uint32 indexed msgFrom,
        bytes32 indexed sender,
        bytes message
    );

    function initialize(address _inbox) public onlyDiamondOwner {
        s.inbox = _inbox;
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override onlyInbox {
        (LibAppStorage.TokenBridgeAction action, bytes memory executionMsg) =
        abi.decode(_message, (LibAppStorage.TokenBridgeAction,bytes));

        if(action == LibAppStorage.TokenBridgeAction.DepositMulti) {
            (address account, address[] memory tokens, uint256[] memory amounts, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
            (address, address[], uint256[], bytes32, bytes));
            depositMultiTokenAndCall(account,tokens,amounts,_origin,toContract,data);
        } else {
            (address account, address token, uint256 amount, bytes32 toContract, bytes memory data) = abi.decode(executionMsg,
            (address, address, uint256, bytes32, bytes));
            if(action == LibAppStorage.TokenBridgeAction.Deposit) {
                depositTokenAndCall(account,token,amount,_origin,toContract,data);
            } else if (action == LibAppStorage.TokenBridgeAction.Withdraw) {
                withdrawTokenAndCall(account,token,amount,_origin,toContract,data);
            }
        }
    }

}