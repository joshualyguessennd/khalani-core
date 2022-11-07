// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

import {AbacusConnectionClient} from "@hyperlane-xyz/core/contracts/AbacusConnectionClient.sol";
import {Modifiers} from "../../libraries/LibAppStorage.sol";
import "./libraries/HyerlaneFacetLibrary.sol";

contract HyperlaneClient is Modifiers, AbacusConnectionClient{
    ///events
    event MintMessageSent(uint32 _destination, address hostInbox, bytes _message);

    /**
   * @notice Sends message to an address on a remote chain.
   * @param _destination The ID of the chain we're sending the message to.
   * @param _recipient The address of the recipient we're sending the message to.
   */
    function initHyperlane(uint32 _khalaDomain , address _khalaInbox) external onlyOwner{
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.khalaDomain = _khalaDomain;
        hs.khalaInbox - _khalaInbox;
    }

    function setKhalaDomain(uint32 _khalaDomain) external onlyOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.khalaDomain = _khalaDomain;
    }

    function setKhalaInbox(address _khalaInbox) external onlyOwner {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        hs.khalaInbox = _khalaInbox;
    }

    function sendMintMessage(address _token, uint256 _amount) onlyGateway {
        HyperlaneStorage storage hs = HyperlaneFacetLibrary.hyperlaneStorage();
        require(_token!=address(0x0) , "token address can not be null");
        bytes memory _message = abi.encode(_token,_amount);
        _outbox().dispatch (
                s.khalaDomain,
                s.khalaInbox ,
                _message
            );
        emit MintMessageSent(hs.khalaDomain, hs.khalaInbox, _message);
    }
}
