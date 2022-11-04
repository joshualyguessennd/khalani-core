// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {AbacusConnectionClient} from "@hyperlane-xyz/contracts/AbacusConnectionClient.sol";

contract HyperlaneClient is AbacusConnectionClient{


    uint32 private khalaDomain;
    address gateway;
    address owner;
    address hostInbox;
    constructor(address owner, uint32 khalaDomain) {

    }

    ///events
    event MintMessageSent(uint32 _destination, address hostInbox, bytes _message);

    ///modifier

    modifier onlyOwner() {
        require(owner == _msgSender(), "caller not the owner");
    }

    modifier onlyGateway() {
        require(gateway == _msgSender(), "caller not the owner");
    }

    function setGateway(address _gateway) onlyOwner {
        gateway = _gateway;
    }
    /**
   * @notice Sends message to an address on a remote chain.
   * @param _destination The ID of the chain we're sending the message to.
   * @param _recipient The address of the recipient we're sending the message to.
   */
    function sendMintMessage(address _token, uint256 _amount) onlyGateway {
        bytes memory _message = abi.encode(_token,_amount);
        _outbox().dispatch(khalaDomain,hostInbox,_message);
        emit MintMessageSent(khalaDomain,hostInbox,_message);
    }

}
