pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/*This is not a facet of nexus diamond*/
/*Khala interchain account contract - multi-call support*/

contract KhalaInterChainAccount is OwnableUpgradeable{
    constructor() {
        _transferOwnership(msg.sender);
    }

    function sendProxyCall(address to, bytes calldata data) external onlyOwner {
        (bool success, bytes memory returnData) = to.call(data);
        if (!success) {
            assembly {
                revert(add(returnData, 32), returnData)
            }
        }
    }
}