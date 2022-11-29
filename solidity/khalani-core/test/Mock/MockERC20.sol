// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MockERC20 is ERC20PresetMinterPauser {

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(string memory name, string memory symbol) ERC20PresetMinterPauser (name, symbol) {

    }

    function mint(address _to, uint256 _amount) public override {
        super._mint(_to, _amount);
    }

    function burn(address _account, uint256 value) public {
        //require(hasRole(BURNER_ROLE, msg.sender), "Unauthorised");
        super._burn(_account, value);
    }

    function burn(uint256 value) public override {
        //require(hasRole(BURNER_ROLE, msg.sender), "Unauthorised");
        super._burn(msg.sender, value);
    }
}