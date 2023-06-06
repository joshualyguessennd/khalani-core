// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Call} from "../Call.sol";
interface IKhalaInterchainAccount {

    event ProxyCallSuccess(
        address indexed caller,
        uint indexed chainId // source chain id of the call
    );

    event ProxyCallFailedRefundInitiated(
        address indexed caller,
        uint indexed chainId // source chain id of the call (refunding back to the same chain)
    );

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