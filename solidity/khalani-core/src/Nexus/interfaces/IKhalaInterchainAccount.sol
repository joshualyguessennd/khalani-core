// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKhalaInterchainAccount {

    function sendProxyCall(
        address token,
        uint amount,
        uint chainId,
        address to,
        bytes calldata data
    ) external;

    function sendProxyCallForMultiTokens(
        address[] calldata tokens,
        uint[] calldata amounts,
        uint chainId,
        address to,
        bytes calldata data) external;

    function getEOA(
    ) external returns (address);
}