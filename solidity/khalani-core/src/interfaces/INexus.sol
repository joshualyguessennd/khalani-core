// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface INexus {
    function mintToken(uint32 origin, address token, uint256 amount) external returns (bool);
    function burnToken(uint32 chainDomain, address token, uint256 amount) external returns(bool);
}