pragma solidity ^0.8.0;

library LibAppReceiver {

    struct AppReceiverStorage {
        address axonNexus;
        mapping(address => address) mirrorChainToken;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("app.receiver.storage");

    function appReceiverStorage() internal pure returns (AppReceiverStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function _addChainTokenForMirrorToken(address _mirrorToken,address _chainToken) internal {
        AppReceiverStorage storage ds = appReceiverStorage();
        ds.mirrorChainToken[_mirrorToken] = _chainToken;
    }

    function _getChainToken(address _mirrorToken) internal returns (address){
        AppReceiverStorage storage ds = appReceiverStorage();
        return ds.mirrorChainToken[_mirrorToken];
    }
}
