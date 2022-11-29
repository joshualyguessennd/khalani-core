pragma solidity ^0.8.0;


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

    function _addChainMirrorTokenMapping(uint32 _domain, address token, address mirrorToken) internal {
        AccountsRegistryStorage storage ds = accountsRegistryStorage();
        ds.chainMirrorToken[_domain][token] = mirrorToken;
    }

    function _getMirrorToken(uint32 _domain, address _token) internal returns (address) {
        AccountsRegistryStorage storage ds = accountsRegistryStorage();
        return ds.chainMirrorToken[_domain][_token];
    }
}