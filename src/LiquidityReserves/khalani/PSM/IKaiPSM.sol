pragma solidity ^0.8.0;

interface IKaiPSM {
    function addWhiteListedAsset(address asset) external;
    function removeWhiteListedAddress(address asset) external;
    function mintKai(address tokenIn, uint amount) external;
    function redeemKai(uint256 amount, address tokenOut) external;
}