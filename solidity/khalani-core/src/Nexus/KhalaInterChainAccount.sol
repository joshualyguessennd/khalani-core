pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./facets/AxonCrossChainRouter.sol";
import "./interfaces/IKhalaInterchainAccount.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
/*This is not a facet of nexus diamond*/
/*Khala interchain account contract - multi-call support*/

contract KhalaInterChainAccount is IKhalaInterchainAccount, OwnableUpgradeable{

    address private eoa;

    constructor() {
        _transferOwnership(msg.sender);
    }

    function initialize(address _eoa) public initializer {
        eoa = _eoa;
    }

    function getEOA() external returns (address){
        return eoa;
    }

    function sendProxyCall(address token, uint256 amount, uint chainId, address to, bytes calldata data) external onlyOwner {
        (bool success, bytes memory returnData) = to.call(data);
        if (!success) {
            // pull refund logic from application wrapper
            AxonCrossChainRouter(owner()).withdrawTokenAndCall(
                chainId,
                token,
                amount,
                TypeCasts.addressToBytes32(address(0)),
                abi.encode("")
            );
        }
    }

    function sendProxyCallForMultiTokens(address[] calldata tokens, uint256[] calldata amounts, uint chainId, address to, bytes calldata data) external {
        (bool success, bytes memory returnData) = to.call(data);
        if (!success) {
            // pull refund logic from application wrapper
            AxonCrossChainRouter(owner()).withdrawMultiTokenAndCall(
                chainId,
                tokens,
                amounts,
                TypeCasts.addressToBytes32(address(0)),
                abi.encode("")
            );
        }
    }
}