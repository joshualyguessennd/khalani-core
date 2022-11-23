pragma solidity ^0.7.0;


library LibAccountsRegistry {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("axon.accounts.registry.storage");

    struct AccountsRegistryStorage {
        mapping(uint32 => mapping(address => address)) chainMirrorToken;
    }

    function accountsRegistryStorage() internal pure returns (AccountsRegistryStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}