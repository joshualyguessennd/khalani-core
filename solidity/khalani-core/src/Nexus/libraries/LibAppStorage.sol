// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../../diamondCommons/libraries/LibDiamond.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
struct AppStorage {
   mapping(address => mapping(address => uint256)) balances; // user -> USDC -> balance
   mapping(address => address) mirrorToChainToken; //usdceth -> usdc
   address hyperlaneInbox;
   //mapping(address => bool) panToken; // checks if token is pan
}

library LibAppStorage {

    enum TokenBridgeAction{
        Deposit,
        DepositMulti,
        Withdraw,
        WithdrawMulti
    }

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers is ReentrancyGuard {
    AppStorage internal s;

    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyInbox() {
        require(msg.sender==s.hyperlaneInbox,"only inbox can call");
        _;
    }

    modifier validRouter() {
        require(msg.sender == address(this), "BridgeFacet : Invalid Router");
        _;
    }
}
