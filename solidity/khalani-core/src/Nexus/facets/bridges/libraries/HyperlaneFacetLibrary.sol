// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@hyperlane-xyz/core/interfaces/IInterchainSecurityModule.sol";

struct HyperlaneStorage {
    address hyperlaneMailbox;
    IInterchainSecurityModule interchainSecurityModule;
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