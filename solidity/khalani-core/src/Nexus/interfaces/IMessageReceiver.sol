pragma solidity ^0.8.0;
import "../Call.sol";

interface IMessageReceiver{
    function collect(
        address sender,
        Call[] calldata calls
    ) external;
}