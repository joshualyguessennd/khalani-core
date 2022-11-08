// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
import "@hyperlane-xyz/core/interfaces/IOutbox.sol";

struct HyperlaneStorage {
    uint32 khalaDomain;
    address khalaInbox;
    address outbox;
}

library HyperlaneFacetLibrary {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("bridges.hyperlane.storage");


    function hyperlaneStorage() internal pure returns (HyperlaneStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}