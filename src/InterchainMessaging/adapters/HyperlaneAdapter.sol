pragma solidity ^0.8.0;

import "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";
import "@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../interfaces/IRequestProcessorFacet.sol";
import "../interfaces/IAdapter.sol";
import "../Errors.sol";

contract HyperlaneAdapter is IAdapter, IMessageRecipient{
    IMailbox public immutable mailbox;
    IInterchainSecurityModule public immutable interchainSecurityModule;
    address public immutable nexus;

    constructor(address _mailbox, address _ism, address _nexus){
        mailbox = IMailbox(_mailbox);
        interchainSecurityModule = IInterchainSecurityModule(_ism);
        nexus = _nexus;
    }

    modifier onlyMailbox() {
        if(msg.sender != address(mailbox)){
            revert InvalidInbox();
        }
        _;
    }

    modifier onlyNexus() {
        if(msg.sender != nexus){
            revert InvalidNexus();
        }
        _;
    }

    /**
    * @dev Relay a message to another chain
    * @param chain The destination chain
    * @param receiver The destination address
    * @param payload The message payload
    */
    function relayMessage(uint chain, bytes32 receiver, bytes calldata payload) external override onlyNexus {
        //call hyperlane's mailbox to send message to destination chain
        mailbox.dispatch(
            uint32(chain),
            receiver,
            payload
        );
    }

    /**
    * @dev Relay a message to another chain
    */
    function payRelayer(bytes32 messageId) external override {
        // call hyperlaneIGP.payForGas() ?
    }

    /**
    * @dev hyperlane IMessageRecipient handle
    */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    )  external override onlyMailbox {
        //call nexus request processor facet
        IRequestProcessorFacet(nexus).processRequest(
            uint256(_origin),
            _sender,
            _message
        );
    }

}