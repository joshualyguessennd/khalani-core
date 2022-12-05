// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProxyCall {
    function sendProxyCall(address _to, bytes calldata data) external;
}