// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../../../../hyperlane-monorepo/solidity/interfaces/IMessageRecipient.sol";
import "../AxonReceiver.sol";
pragma experimental ABIEncoderV2;

contract AxonHyperlaneHandlerFacet is IMessageRecipient, AxonReceiver {

    event CrossChainMsgReceived(
        uint32 indexed msgFrom,
        bytes32 indexed sender,
        bytes message
    );

    enum TokenBridgeAction{
        Deposit,
        DepositMulti,
        Withdraw
    }

    function initialize(address _inbox) public onlyDiamondOwner {
        s.inbox = _inbox;
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override onlyInbox {

    }

}