// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
*@dev Call is used for sending cross-chain execution details through nexus
*@dev to - address on destination chain
*@dev data - calldata
*/
struct Call {
    address to;
    bytes data;
}
