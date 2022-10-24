// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 < 0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";


/// @title Custody Contract
/// @author Samuel Dare (sam@tunnelvisionlabs.xyz)
/// @notice This contract implements the logic for the Realioverse Land NFT
contract Custody is Ownable {
    // address public owner;
    address public gateway;
    uint256 public number;

    /// @dev stores all user balances
    mapping(address => uint) public balances;

    event Deposit(address indexed _owner, uint256 indexed _amount);
    event Withdraw(address indexed _owner, uint256 indexed _amount);
    event GateWayChanged(address indexed _gateway);

    /// @dev This function is used in lieu of a modifier to reduce bytecode size
    function _isGateway() internal view {
        //        if (msg.sender != gateway) {
        //     revert CS_OnlyGateway();
        // }
        require(msg.sender == gateway, "CS_OnlyGateway");
    }
    constructor(address _gateway) {
        // owner = msg.sender;
        gateway = _gateway;
    }

    /// State Changing Functions
    function setGateway(address _gateway) public onlyOwner {
        gateway = _gateway;
        emit GateWayChanged(_gateway);
    }

    // TODO: Should this be called via a delegate call so we dont have to deal with the extra state variable?

    function deposit(address _owner, uint256 _amount) public returns  (bool) {
        _isGateway();  
        balances[_owner] += _amount;
        emit Deposit(_owner, _amount); 
        return true;
    }

    function withdraw(address _owner, uint256 _amount) public returns (bool) {
        _isGateway();
        // check
        // if (balances[_owner] < _amount) {
        //     revert CS_InsufficientBalance();
        // }
        require(balances[_owner] >= _amount, "CS_InsufficientBalance");
        // effect
        balances[_owner] -= _amount;
        // Interaction  
        
        emit Withdraw(_owner, _amount);
        return true;
    }
}