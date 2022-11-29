// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICustody {
    
    function setGateway(address _gateway) external ;

    function deposit(address _owner, uint256 _amount) external  returns  (bool);

    function withdraw(address _owner, uint256 _amount) external  returns (bool) ;
} 