// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";

interface IMultiBridgeFacet {

    function bridgeTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainDomain,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) external payable ;

    function bridgeMultiTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainDomain,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) external payable ;

    function bridgeTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) external payable ;

    function bridgeMultiTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) external payable ;

}
