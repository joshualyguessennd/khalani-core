// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;
pragma abicoder v2;

import "@hyperlane-xyz/core/interfaces/IOutbox.sol";
import {Modifiers} from "../../libraries/LibAppStorage.sol";
import "./libraries/HyerlaneFacetLibrary.sol";
import "../../../hyperlane-monorepo/solidity/interfaces/IMessageRecipient.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

contract HyperlaneClient is Modifiers, IMessageRecipient{

    ///events
    event MintMessageSent(uint32 destination, address hostInbox, bytes message);

    /**
   * @notice Sends message to an address on a remote chain.
   * @param _khalaDomain The ID of the chain we're sending the message to.
   * @param _outbox The ID of the chain we're sending the message to.
   * @param _khalaInbox The address of the recipient we're sending the message to.
   */
    function initHyperlane(uint32 _khalaDomain , address _outbox, address _khalaInbox)
        external onlyDiamondOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.khalaDomain = _khalaDomain;
        hs.outbox = _outbox;
        hs.khalaInbox = _khalaInbox;
    }

    function setKhalaDomain(uint32 _khalaDomain) external onlyDiamondOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.khalaDomain = _khalaDomain;
    }

    function setKhalaInbox(address _khalaInbox) external onlyDiamondOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.khalaInbox = _khalaInbox;
    }

    function setHyperlaneOutBox(address _outbox) external onlyDiamondOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.outbox = _outbox;
    }

    function sendMintMessage(address _token, uint256 _amount) public {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        require(_token!=address(0x0) , "token address can not be null");
        bytes memory _message = abi.encode(_token,_amount);
        IOutbox(hs.outbox).dispatch (
                hs.khalaDomain,
                TypeCasts.addressToBytes32(hs.khalaInbox),
                _message
            );
        emit MintMessageSent(hs.khalaDomain, hs.khalaInbox, _message);
    }

    /**
  * @notice Emits an event upon receipt of an inter-chain message
   * @param _origin The chain ID from which the message was sent
   * @param _sender The address that sent the message
   * @param _message The contents of the message
   */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override {
        (address token, uint256 amount) = abi.decode(
            _message,
            (address,uint256)
        );
        //TBI
        //INexus(nexus).mintToken(_origin,token,amount);
        //emit InterchainMessageReceived(_origin, _sender, _message);
    }
}
