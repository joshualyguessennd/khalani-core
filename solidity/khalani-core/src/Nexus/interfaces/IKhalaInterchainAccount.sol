// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Call} from "../Call.sol";
interface IKhalaInterchainAccount {

    function sendProxyCall(
        address token,
        uint amount,
        uint chainId,
        Call[] calldata calls
    ) external;

    function sendProxyCallForMultiTokens(
        address[] calldata tokens,
        uint[] calldata amounts,
        uint chainId,
        Call[] calldata calls
    ) external;

    function eoa(
    ) external returns (address);
}