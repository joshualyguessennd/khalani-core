// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {AbacusConnectionClient}  from "@hyperlane-xyz/contracts/AbacusConnectionClient.sol";

contract NexusHyperlaneClient is AbacusConnectionClient{

    //event
    event InterchainMessageReceived(uint32 _origin, address _sender, address _message);

    /**
   * @notice Emits an event upon receipt of an interchain message
   * @param _origin The chain ID from which the message was sent
   * @param _sender The address that sent the message
   * @param _message The contents of the message
   */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override onlyInbox {
        ()
        emit InterchainMessageReceived(_origin, _sender, _message);
    }
}
