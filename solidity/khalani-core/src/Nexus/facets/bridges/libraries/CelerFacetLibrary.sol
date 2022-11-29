// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


library CelerFacetLibrary {
    struct CelerStorage {
        uint64 axonDomain;
        address axonInbox;
    }

    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("nexus.bridges.celer.storage");


    function celerStorage() internal pure returns (CelerStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}