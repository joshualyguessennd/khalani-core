// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@sgn-v2-contracts/message/interfaces/IMessageBus.sol";
import "@sgn-v2-contracts/message/libraries/MsgDataTypes.sol";
import "@sgn-v2-contracts/message/framework/MessageReceiverApp.sol";
pragma abicoder v2;

contract MockCelerMessageBus is IMessageBus{
    uint64 _chainIdThis;
    MockCelerMessageBus otherBus;
    mapping(uint => address) chainMessageBus;
    uint totalMsg = 0;
    uint msgProcessed = 0;
    struct Params{
        bytes _message;
        MsgDataTypes.RouteInfo _route;
        bytes[] _sigs;
        address[] _signers;
        uint256[] _powers;
        uint chainId;
    }

    mapping(uint => Params) pendingMsg;

    constructor(uint64 _chainId) {
        _chainIdThis = _chainId;
    }

    function addChainBus(uint chain, address bus) external {
        chainMessageBus[chain] = bus;
    }

    /**
  * @notice Send a message to a contract on another chain.
     * Sender needs to make sure the uniqueness of the message Id, which is computed as
     * hash(type.MessageOnly, sender, receiver, srcChainId, srcTxHash, dstChainId, message).
     * If messages with the same Id are sent, only one of them will succeed at dst chain..
     * A fee is charged in the native gas token.
     * @param _receiver The address of the destination app contract.
     * @param _dstChainId The destination chain ID.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     */
    function sendMessage(
        address _receiver,
        uint256 _dstChainId,
        bytes calldata _message
    ) external payable {
        MsgDataTypes.RouteInfo memory _route;
        _route.sender = msg.sender;
        _route.srcChainId = _chainIdThis;
        _route.receiver = _receiver;
        bytes[] memory _sigs;
        address[] memory _signers;
        uint256[] memory _powers;
        MockCelerMessageBus(chainMessageBus[_dstChainId]).addMsg(Params({
            _message : _message,
            _route : _route,
            _sigs : _sigs,
            _signers : _signers,
            _powers : _powers,
            chainId : _dstChainId
            })
        );
    }

    function addMsg(Params calldata p) external {
        pendingMsg[totalMsg] = p;
        ++totalMsg;
    }
    // same as above, except that receiver is an non-evm chain address,
    function sendMessage(
        bytes calldata _receiver,
        uint256 _dstChainId,
        bytes calldata _message
    ) external payable {}

    /**
     * @notice Send a message associated with a token transfer to a contract on another chain.
     * If messages with the same srcTransferId are sent, only one of them will succeed at dst chain..
     * A fee is charged in the native token.
     * @param _receiver The address of the destination app contract.
     * @param _dstChainId The destination chain ID.
     * @param _srcBridge The bridge contract to send the transfer with.
     * @param _srcTransferId The transfer ID.
     * @param _dstChainId The destination chain ID.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     */
    function sendMessageWithTransfer(
        address _receiver,
        uint256 _dstChainId,
        address _srcBridge,
        bytes32 _srcTransferId,
        bytes calldata _message
    ) external payable {}

    /**
     * @notice Execute a message not associated with a transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {
        MessageReceiverApp(_route.receiver).executeMessage(_route.sender,_route.srcChainId,_message,address(0x0));
    }

    /**
     * @notice Execute a message with a successful transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransfer(
        bytes calldata _message,
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {}

    /**
     * @notice Execute a message with a refunded transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransferRefund(
        bytes calldata _message, // the same message associated with the original transfer
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable {}

    /**
     * @notice Withdraws message fee in the form of native gas token.
     * @param _account The address receiving the fee.
     * @param _cumulativeFee The cumulative fee credited to the account. Tracked by SGN.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A withdrawal must be
     * signed-off by +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function withdrawFee(
        address _account,
        uint256 _cumulativeFee,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external {}

    /**
     * @notice Calculates the required fee for the message.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     @ @return The required fee.
     */
    function calcFee(bytes calldata _message) external virtual view returns (uint256){return 0;}

    function liquidityBridge() external virtual view returns (address){return address(0x0);}

    function pegBridge() external virtual view returns (address){return address(0x0);}

    function pegBridgeV2() external virtual view returns (address){return address(0x0);}

    function pegVault() external virtual view returns (address){return address(0x0);}

    function pegVaultV2() external virtual view returns (address){return address(0x0);}

    function processNextPendingMsg() external {
        Params memory params = pendingMsg[msgProcessed];
        IMessageBus(address(this)).executeMessage(params._message, params._route, params._sigs, params._signers, params._powers);
        ++msgProcessed;
    }
}