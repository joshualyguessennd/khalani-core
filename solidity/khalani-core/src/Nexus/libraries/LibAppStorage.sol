// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../../diamondCommons/libraries/LibDiamond.sol";
    struct AppStorage {
        mapping(address => mapping(address => uint256)) balances; // user -> USDC -> balance
        mapping(address => address) mirrorToChainToken; //usdceth -> usdc
        address inbox;
        //mapping(address => bool) panToken; // checks if token is pan
    }

library LibAppStorage {

    enum TokenBridgeAction{
        Deposit,
        DepositMulti,
        Withdraw
    }

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyInbox() {
        require(msg.sender==s.inbox,"only inbox can call");
        _;
    }

    modifier validRouter() {
        require(msg.sender == address(this), "BridgeFacet : Invalid Router");
        _;
    }
}
