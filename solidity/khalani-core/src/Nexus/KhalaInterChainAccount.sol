pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./facets/AxonCrossChainRouter.sol";
import "./interfaces/IKhalaInterchainAccount.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {Call} from "../Nexus/Call.sol";

/*This is not a facet of nexus diamond*/
/*Khala interchain account contract - multi-call support*/
contract KhalaInterChainAccount is IKhalaInterchainAccount, OwnableUpgradeable{

    address public eoa;

    constructor() {
        _transferOwnership(msg.sender);
    }

    function initialize(address _eoa) public initializer {
        eoa = _eoa;
    }

    function sendProxyCall(address token, uint256 amount, uint chainId, Call[] calldata calls) external onlyOwner {

        for(uint i ; i<calls.length;) {

            (bool success, bytes memory returnData) = calls[i].to.call(
                calls[i].data
            );

            if (!success) {
                // pull refund logic from application wrapper
                Call[] memory callBacks;
                AxonCrossChainRouter(owner()).withdrawTokenAndCall(
                    chainId,
                    token,
                    amount,
                    callBacks
                );
            }

            unchecked{
                ++i;
            }
        }


    }

    function sendProxyCallForMultiTokens(address[] calldata tokens, uint256[] calldata amounts, uint chainId, Call[] calldata calls) external {
        for(uint i; i<calls.length; ) {
            (bool success, bytes memory returnData) = calls[i].to.call(
                calls[i].data
            );
            if (!success) {
                // pull refund logic from application wrapper
                Call[] memory callBacks;
                AxonCrossChainRouter(owner()).withdrawMultiTokenAndCall(
                    chainId,
                    tokens,
                    amounts,
                    callBacks
                );
            }
            unchecked{
                ++i;
            }
        }
    }
}