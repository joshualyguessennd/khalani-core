// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/ICustody.sol" ;
import "../interfaces/IAMB.sol" ;
// import "./utils/Errors.sol" ;

contract Gateway {
    address public owner;
    address public custody;
    address public psm;
    address public nexus;
    address public bridge;

    constructor(address _bridge, address _custody) {
        owner = msg.sender;
        custody = _custody;
        bridge = _bridge;
    }

    function initGateway(address _bridge, address _custody) {

    }

    function setCustody(address _custody) public {
        custody = _custody;
    }

    function setPSM(address _psm) public {
        psm = _psm;
    }

    function setNexus(address _nexus) public {
        nexus = _nexus;
    }

    function depositLiquidity (address _contract, bytes calldata _data, uint256 _gas) external returns (bytes32) {    
    }
    
    function removeLiquidity (address _contract, bytes calldata _data, uint256 _gas) external returns (bytes32) {

    }
    function _transferToCustody(address _owner,  uint256 _amount) private returns (bool) {}
    function _transferFromCustody(address _owner,  uint256 _amount) private returns (bool) {}
}