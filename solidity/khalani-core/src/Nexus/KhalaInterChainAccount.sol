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

    /**
    *@notice - sends calls to the destination contract with calldata in `Call[]` with ICA as proxy
    *@param token - address of the token bridged (mirror token)
    *@param amount - amount of token
    *@param chainId - source chain-Id
    *@param calls - list of `Call` struct (to, data)
    */
    function sendProxyCall(address token, uint256 amount, uint chainId, Call[] calldata calls) external onlyOwner {

        uint length  = calls.length;
        for(uint i ; i<length;) {

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

    /**
    *@notice - sends calls to the destination contract with calldata in `Call[]` with ICA as proxy
    *@param tokens - addresses of the token bridged (mirror tokens)
    *@param amounts - amounts of tokens
    *@param chainId - source chain-Id
    *@param calls - list of `Call` struct (to, data)
    */
    function sendProxyCallForMultiTokens(address[] calldata tokens, uint256[] calldata amounts, uint chainId, Call[] calldata calls) external {
        uint length  = calls.length;
        for(uint i; i<length; ) {
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