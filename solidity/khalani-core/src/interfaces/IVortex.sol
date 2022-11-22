// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IVortex {
    function mintToken(uint32 origin, address account, address token, uint256 amount) external returns (bool);
    function burnToken(uint32 origin, address account, address token, uint256 amount) external returns (bool);
}