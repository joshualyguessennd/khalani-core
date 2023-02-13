// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";

contract USDMirror is ERC20PresetMinterPauserUpgradeable {

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint public chainId;

    function initialize(string memory name, string memory symbol, uint _chainId) public initializer {
        __ERC20PresetMinterPauser_init(name, symbol);
        _setupRole(BURNER_ROLE, msg.sender);
        chainId = _chainId;
    }

    function burn(address account, uint256 value) external {
        require(hasRole(BURNER_ROLE, msg.sender), "Unauthorised");
        _burn(account, value);
    }

    function transferMinterBurnerRole(address account) external {
        require(hasRole(DEFAULT_ADMIN_ROLE,msg.sender),"Unauthorised");
        _setupRole(MINTER_ROLE, account);
        _setupRole(BURNER_ROLE,account);
    }
}
