// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract OmniUSD is ERC20PresetMinterPauser {

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(string memory name, string memory symbol) ERC20PresetMinterPauser (name, symbol) {

    }

    function mint(address _to, uint256 _amount) public override {
        super._mint(_to, _amount);
    }

    function burn(uint256 value) public override {
        require(hasRole(BURNER_ROLE, msg.sender), "Unauthorised");
        super._burn(msg.sender, value);
    }
}