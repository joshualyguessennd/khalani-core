// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "../facets/GatewayFacet.sol";

library LibGateway {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("khalini.gateway.storage");

    struct GatewayState{

    }

    function diamondStorage() internal pure returns (GatewayState storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

}