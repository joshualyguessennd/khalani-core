// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 < 0.9.0;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract USDCavax is ERC20PresetMinterPauser {

    // address public nexus;

     bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    constructor() ERC20PresetMinterPauser("USDC_AVAX", "USDCavax") {

        // nexus = _nexus;

        // grantRole(MINTER_ROLE, nexus);
        // grantRole(BURNER_ROLE, nexus);
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