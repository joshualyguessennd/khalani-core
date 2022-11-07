// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockERC20 is ERC20Upgradeable {
    function initialize(string memory _name, string memory _symbol)
    public
    initializer
    {
        __ERC20_init(_name, _symbol);
        _mint(msg.sender, 100000e18);
    }

    function mint(address receiver, uint256 amount) public {
        _mint(receiver, amount);
    }
}
