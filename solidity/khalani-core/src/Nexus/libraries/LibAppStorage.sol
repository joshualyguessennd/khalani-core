// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import {LibDiamond} from "../../diamondCommons/libraries/LibDiamond.sol";
    struct AppStorage {
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

}
