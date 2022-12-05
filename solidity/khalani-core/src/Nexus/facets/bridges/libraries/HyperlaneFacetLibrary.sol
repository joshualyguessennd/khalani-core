// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct HyperlaneStorage {
    uint32 axonDomain;
    address hyperlaneOutbox;
    address axonInbox;
}

library HyperlaneFacetLibrary {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("nexus.bridges.hyperlane.storage");


    function hyperlaneStorage() internal pure returns (HyperlaneStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}