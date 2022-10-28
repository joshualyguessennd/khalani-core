// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

library LibCustody {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("khalini.custody.storage");

    struct CustodyState{

    }

    function diamondStorage() internal pure returns (CustodyState storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

}