// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;


library HyperlaneFacetLibrary {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("bridges.hyperlane.storage");

    struct HyperlaneStorage {
        uint32 khalaDomain;
        address khalaInbox;
    }

    function hyperlaneStorage() internal pure returns (HyperlaneStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds := position
        }
    }
}