// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct AxonMsgHandlerStorage {
    mapping(uint32 => bytes32) chainNexusMap;
}

library AxonMsgHandlerLibrary {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("axon.msg.handler.storage");

    function axonMsgHandlerStorage() internal pure returns (AxonMsgHandlerStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function _setChainNexusMapping(uint32 chainDomain, bytes32 nexus) internal {
        AxonMsgHandlerStorage storage ds = axonMsgHandlerStorage();
        ds.chainNexusMap[chainDomain] = nexus;
    }
}