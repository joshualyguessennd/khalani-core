// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/ICustody.sol" ;
import "../interfaces/IAMB.sol" ;
// import "./utils/Errors.sol" ;
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract Gateway {
    address public owner;
    address public custody;
    address public psm;
    address public nexus;
    address public bridge;

    event LogLockToChain(
        string recipientAddress,
        string recipientChain,
        address token,
        uint256 amount
    );

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

    function deposit(address user, address token, uint256 amount,  bytes destination) external returns (bool) {
        _lock(_owner, _destination, token, amount);
        _transferFromCustody(user,amount);
        return true;
    }

    function _transferToCustody(address _owner,  uint256 _amount) private returns (bool) {
        return ICustody(custody).deposit(_owner, _amount);
    }

    function _transferFromCustody(address _owner,  uint256 _amount) private returns (bool) {
        return ICustody(custody).withdraw(_owner,_amount);
    }

    function _lock(address calldata _owner, address calldata _destination,address token, uint256 amount) internal returns(uint256) {

        require(_owner!=address(0));

        uint256 transferredAmount = IERC20Upgradeable(token).safeTransferFromWithFees(
            _msgSender(),
            address(this),
            _amount
        );

        emit LogLockToChain(
            _owner,
            _destination,
            token,
            amount
        );

        return transferredAmount;
    }
}