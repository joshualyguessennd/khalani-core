// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract OmniUSD is ERC20PresetMinterPauser {

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20PresetMinterPauser("OMNI_USD", "OmniUSD") {
        grantRole(BURNER_ROLE, msg.sender);
    }

    function mint(address _to, uint256 _amount) public override {
        super._mint(_to, _amount);
    }

    function burn(uint256 value) public override {
        require(hasRole(BURNER_ROLE, msg.sender), "Unauthorised");
        super._burn(msg.sender, value);
    }
}
