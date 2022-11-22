//// SPDX-License-Identifier: MIT
//pragma solidity ^0.7.0;
//pragma experimental ABIEncoderV2;
//
//import "./balancer/vault/interfaces/IVault.sol";
//import "./balancer/vault/interfaces/IERC20.sol";
//import "./interfaces/IVortex.sol";
//import "./interfaces/IERC20Mintable.sol";
//
//contract Vortex is IVortex{
//    address public owner;
//    address public custody;
//    address public psm;
//    address public gateway;
//    address private omniusd;
//    address private usdcavax;
//    address private usdceth;
//    address public vault;
//    mapping(uint32=>mapping(address=>address)) private chainTokenRepresentation; //{ eth -> { { usdc -> usdc.eth} , . . . . }, {avax -> {usdc -> usdc.avax } , . . .} }
//
//    constructor(address _vault) {
//        owner = msg.sender;
//        vault = _vault;
//    }
//    ///modifier
//    modifier onlyOwner() {
//        require(owner == msg.sender, "caller not the owner");
//        _;
//    }
//
//    modifier onlyGateway() {
//        require(gateway == msg.sender, "caller not gateway");
//        _;
//    }
//
//    /// STATE CHANGING METHODS
//    function setCustody(address _custody) public {
//        custody = _custody;
//    }
//
//    function setPSM(address _psm) public {
//        psm = _psm;
//    }
//
//    function setGateway(address _gateway) public {
//        gateway = _gateway;
//    }
//
//    function joinPool(
//        bytes32 _poolId,
//        address _sender,
//        address _recipient,
//        IVault.JoinPoolRequest memory _request
//    ) external {
//        // IERC20()
//
//        IVault(vault).joinPool(_poolId, _sender, _recipient, _request);
//    }
//
//    function exitPool(
//        bytes32 _poolId,
//        address _sender,
//        address payable _recipient,
//        IVault.ExitPoolRequest memory _request
//    ) external {
//        IVault(vault).exitPool(_poolId, _sender, _recipient, _request);
//    }
//
//    function addTokenRepresentationMapping(
//        uint32 domain,
//        address token,
//        address tokenRepresentation
//    ) public onlyOwner {
//        chainTokenRepresentation[domain][token] = tokenRepresentation;
//    }
//
//    function mintToken(uint32 origin,address account, address token, uint256 amount) public override onlyGateway returns (bool) {
//        address tokenToMint = chainTokenRepresentation[origin][token];
//        IERC20Minter(tokenToMint).mint(account,amount);
//        return true;
//    }
//
//    function burnToken(uint32 origin, address account, address token, uint256 amount) public override onlyGateway returns (bool) {
//        address tokenToBurn = chainTokenRepresentation[origin][token];
//        IERC20Minter(tokenToBurn).burn(account,amount);
//        return true;
//    }
//}
