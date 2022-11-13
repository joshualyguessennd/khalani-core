// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import {LibDiamond} from "./LibDiamond.sol";
struct AppStorage {
    address gateway;
    address psm;
    address nexus;
    mapping(address => mapping(address => uint256)) balances; // user -> USDC -> balance
}

library LibAppStorage {
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

    modifier onlyGateway() {
        require(s.gateway == msg.sender,"LibAppStorage: only Gateway can call this function");
        _;
    }
}
