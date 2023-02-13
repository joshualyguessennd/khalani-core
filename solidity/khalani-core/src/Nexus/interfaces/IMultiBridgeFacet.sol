// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import {Call} from "../Call.sol";

interface IMultiBridgeFacet {

    function bridgeTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainDomain,
        address sender,
        address account,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external payable ;

    function bridgeMultiTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainDomain,
        address sender,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) external payable ;

    function bridgeTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address sender,
        address account,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external payable ;

    function bridgeMultiTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address sender,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) external payable ;

}
