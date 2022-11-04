// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./balancer/vault/interfaces/IVault.sol";
import "./balancer/vault/interfaces/IERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "./interfaces/INexus.sol";

contract Nexus is INexus{
    address public owner;
    address public custody;
    address public psm;
    address public gateway;
    address private omniusd;
    address private usdcavax;
    address private usdceth;
    address public vault;
    mapping(uint32=>mapping(address=>address)) private chainTokenRepresentation;

    constructor(address _vault) {
        owner = msg.sender;
        vault = _vault;
    }
    ///modifier
    modifier onlyOwner() {
        require(owner == _msgSender(), "caller not the owner");
    }

    modifier onlyGateway() {
        require(gateway == _msgSender(), "caller not gateway");
    }

    /// STATE CHANGING METHODS
    function setCustody(address _custody) public {
        custody = _custody;
    }

    function setPSM(address _psm) public {
        psm = _psm;
    }

    function setGateway(address _gateway) public {
        gateway = _gateway;
    }

    function joinPool(
        bytes32 _poolId,
        address _sender,
        address _recipient,
        IVault.JoinPoolRequest memory _request
    ) external {
        // IERC20()

        IVault(vault).joinPool(_poolId, _sender, _recipient, _request);
    }

    function exitPool(
        bytes32 _poolId,
        address _sender,
        address payable _recipient,
        IVault.ExitPoolRequest memory _request
    ) external {
        IVault(vault).exitPool(_poolId, _sender, _recipient, _request);
    }

    function addTokenRepresentationMapping(
        uint32 domain,
        address token,
        address tokenRepresentation
    ) public onlyOwner {
        chainTokenRepresentation[domain][token] = tokenRepresentation;
    }

    function mintToken(uint32 origin, address token, uint256 amount) public onlyGateway returns (bool) {
        address tokenToMint = chainTokenRepresentation[origin][token];
        ERC20PresetMinterPauser(tokenToMint).mint(gateway,amount);
        return true;
    }
}
