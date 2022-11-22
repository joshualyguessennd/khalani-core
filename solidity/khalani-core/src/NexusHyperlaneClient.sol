//// SPDX-License-Identifier: MIT
//pragma solidity ^0.7.0;
//pragma experimental ABIEncoderV2;
//
//import {AbacusConnectionClient}  from "@hyperlane-xyz/core/contracts/AbacusConnectionClient.sol";
//import {INexus} from "./interfaces/IVortex.sol";
//import "../hyperlane-monorepo/solidity/interfaces/IMessageRecipient.sol";
//import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
//import "@hyperlane-xyz/core/interfaces/IInbox.sol";
//
//contract NexusHyperlaneClient is IMessageRecipient {
//    using TypeCasts for bytes32;
//    IInbox inbox;
//
//    enum MirrorTokenAction {Mint, Burn}
//
//    address private gateway;
//    address private nexus;
//    address private owner;
//
//
//    constructor(address _inbox) {
//        inbox = IInbox(_inbox);
//        owner = msg.sender;
//    }
//
//    ///events
//    event MintMessageSent(uint32 _destination, address hostInbox, bytes _message);
//    event InterchainMessageReceived(uint32 _origin, address _sender, bytes _message);
//
//    ///modifier
//    modifier onlyGateway() {
//        require(gateway == msg.sender, "caller not the gateway");
//        _;
//    }
//
//    modifier onlyOwner() {
//        require(msg.sender == owner,"caller not the owner");
//        _;
//    }
//
//
//    ///setter
//    function setGateway(address _gateway) public onlyOwner {
//        gateway = _gateway;
//    }
//
//    function setNexus(address _nexus) public onlyOwner {
//        nexus = _nexus;
//    }
//
//    /**
//   * @notice Emits an event upon receipt of an inter-chain message
//   * @param _origin The chain ID from which the message was sent
//   * @param _sender The address that sent the message
//   * @param _message The contents of the message
//   */
//    function handle(
//        uint32 _origin,
//        bytes32 _sender,
//        bytes memory _message
//    ) external override {
//        (MirrorTokenAction action, address account, address token, uint256 amount) = abi.decode(
//            _message,
//            (MirrorTokenAction, address,address,uint256)
//        );
//
//        emit InterchainMessageReceived(_origin, TypeCasts.bytes32ToAddress(_sender), _message);
//
//        if(action == MirrorTokenAction.Mint) {
//            _mint(_origin, account, token, amount);
//        } else if (action == MirrorTokenAction.Burn) {
//            _burn(_origin, account, token, amount);
//        }
//
//    }
//
//    function _mint(uint32 _origin, address _account, address _token, uint256 _amount) internal {
//        INexus(nexus).mintToken(_origin, _account, _token, _amount);
//    }
//
//    function _burn(uint32 _origin, address _account, address _token, uint256 _amount) internal {
//        INexus(nexus).burnToken(_origin, _account, _token, _amount);
//    }
//}
