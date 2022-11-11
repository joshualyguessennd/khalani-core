// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract USDCeth is ERC20PresetMinterPauser {
    // address public nexus;
    address gateway;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20PresetMinterPauser("USDC_ETH", "USDCeth") {
        // nexus = _nexus;

        // grantRole(MINTER_ROLE, nexus);
        // grantRole(BURNER_ROLE, nexus);
        grantRole(BURNER_ROLE, msg.sender);
    }

    function burn(address _account, uint256 _value) public {
        require(hasRole(BURNER_ROLE, msg.sender), "ERC20PresetMinterPauser: must have burner role to burn");
        super._burn(_account, _value);
    }
}
