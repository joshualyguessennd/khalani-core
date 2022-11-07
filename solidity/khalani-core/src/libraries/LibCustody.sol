// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./LibAppStorage.sol";

library Custody {
    event Deposit(address indexed _owner, uint256 indexed _amount);
    event Withdraw(address indexed _owner, uint256 indexed _amount);

    function depositIntoCustody(address _user,address _token, uint256 _amount) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.balances[_user][_token] += _amount;
        emit Deposit(_user, _amount);
        return true;
    }

    function withdrawFromCustody(address _user, address _token, uint256 _amount) internal returns (bool) {
        AppStorage storage s  =  LibAppStorage.diamondStorage();
        require(s.balances[_user][_token]>=_amount,"CS_InsufficientBalance");
        s.balances[_user][_token] -= _amount;
        emit Withdraw(_user,_amount);
        return true;
    }

    function _balance(address _user, address _token) internal view returns (uint256){
        AppStorage storage s  =  LibAppStorage.diamondStorage();
        return s.balances[_user][_token];
    }
}