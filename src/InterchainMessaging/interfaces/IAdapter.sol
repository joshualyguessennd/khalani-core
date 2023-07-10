pragma solidity ^0.8.0;

interface IAdapter {
    /**
    * @dev send a message to another chain
    * @param chain the chain to send the message to
    * @param receiver the address of the receiver on the other chain
    * @param payload the message payload
    */
    function relayMessage(uint chain, bytes32 receiver, bytes calldata payload) external;

    function payRelayer(bytes32 messageId) external; //maybe
}