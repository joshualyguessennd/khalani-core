pragma solidity ^0.7.0;

interface IERC20Mintable {
    function mint(address account, uint256 amount) external;
    function burn (address account, uint256 amount) external;
    function burn (uint256 amount) external;
}