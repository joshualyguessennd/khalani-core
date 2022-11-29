// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

    struct CelerStorage {
        uint32 axonDomain;
        address axonInbox;
    }

library CelerFacetLibrary {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("nexus.bridges.celer.storage");


    function celerStorage() internal pure returns (CelerStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}