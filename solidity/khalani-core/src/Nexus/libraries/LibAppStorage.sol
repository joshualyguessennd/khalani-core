// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../../diamondCommons/libraries/LibDiamond.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Errors.sol";
struct AppStorage {
   mapping(address => address) mirrorToChainToken; //usdceth -> usdc
   address pan;
   address axonReceiver;
   uint axonChainId;
   uint godwokenChainId;
}

library LibAppStorage {

    enum TokenBridgeAction{
        Deposit,
        DepositMulti,
        Withdraw,
        WithdrawMulti,
        MultiCall
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

    modifier validRouter() {
        if(msg.sender != address(this)){
            revert InvalidRouter();
        }
        _;
    }
}
