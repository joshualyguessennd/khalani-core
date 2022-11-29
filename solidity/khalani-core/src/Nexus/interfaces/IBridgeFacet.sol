// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.7.0;
import "../libraries/LibAppStorage.sol";

interface IBridgeFacet {
    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) external ;

    function bridgeMultiTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) external ;
}
