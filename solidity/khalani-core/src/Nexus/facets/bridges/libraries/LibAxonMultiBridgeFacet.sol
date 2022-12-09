pragma solidity ^0.8.0;

library LibAxonMultiBridgeFacet {
    struct MultiBridgeStorage {
        mapping (uint => address) chainInboxMap;
        address hyperlaneOutbox;
    }

    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("axon.multiBridge.facet.storage");

    function multiBridgeFacetStorage() internal returns (MultiBridgeStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}