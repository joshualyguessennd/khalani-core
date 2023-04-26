// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../src/PSM/IKaiPSM.sol";
import "../src/Nexus/facets/CrossChainRouter.sol";

contract FakeStable is ERC20PresetMinterPauser {

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint8 decimal;

    constructor(string memory name, string memory symbol, uint8 dec) ERC20PresetMinterPauser (name, symbol) {
        decimal = dec;
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

    function decimals() public view override returns(uint8) {
        return decimal;
    }
}