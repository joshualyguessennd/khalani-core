// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {AbacusConnectionClient}  from "@hyperlane-xyz/core/contracts/AbacusConnectionClient.sol";

contract NexusHyperlaneClient is AbacusConnectionClient{

    address private gateway;
    address private owner;
    address private nexus;

    constructor() {
        owner = _msgSender();
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

    //event
    event InterchainMessageReceived(uint32 _origin, address _sender, address _message);

    ///setter
    function setGateway(address _gateway) onlyOwner {
        gateway = _gateway;
    }

    function setNexus(address _nexus) onlyOwner {
        nexus = _nexus;
    }
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
        (address token, uint256 amount) = abi.decode(
                _message,
                (address,uint256)
        );
        INexus(nexus).mintToken(_origin,token,amount);
        emit InterchainMessageReceived(_origin, _sender, _message);
    }
}
