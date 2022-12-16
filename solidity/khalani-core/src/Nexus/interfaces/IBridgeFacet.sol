// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import {Call} from "../Call.sol";

interface IBridgeFacet {
    function bridgeTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external payable ;

    function bridgeMultiTokenAndCall(
        LibAppStorage.TokenBridgeAction action,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) external payable ;
}
