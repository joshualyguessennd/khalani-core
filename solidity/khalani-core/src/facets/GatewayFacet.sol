// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/ICustody.sol" ;
import "../interfaces/IAMB.sol" ;
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../libraries/LibAppStorage.sol";
import {Custody} from "../libraries/LibCustody.sol";
import {HyperlaneClient} from "./bridges/HyperlaneClient.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

contract Gateway is Modifiers {

    event LogLockToChain(
        address userAddr,
        address token,
        uint256 amount
    );

    function initGateway(address _psm, address _nexus) public onlyDiamondOwner {
        s.psm = _psm;
        s.nexus = _nexus;
    }

    function setPSM(address _psm) public onlyDiamondOwner {
        s.psm = _psm;
    }

    function setNexus(address _nexus) public onlyDiamondOwner {
        s.nexus = _nexus;
    }

    function deposit(address user, address token, uint256 amount,  bytes calldata destination) external returns (bool) {
        Custody.depositIntoCustody(user,token,amount); //check effect
        _lock(user, token, amount);
        HyperlaneClient(address(this)).sendMintMessage(token, amount); // TODO : figure out - save gas
        return true;
    }

    function balance(address user, address token) external returns (uint256) {
        return Custody._balance(user,token);
    }

    function _lock(address _user,address token, uint256 amount) internal returns(uint256) {

        require(_user!=address(0));

        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(token),
            _user,
            address(this),
            amount
        );

        emit LogLockToChain(
            _user,
            token,
            amount
        );

        return amount;
    }
}