// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/ICustody.sol" ;
import "../interfaces/IAMB.sol" ;
// import "./utils/Errors.sol" ;
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../libraries/LibAppStorage.sol";
import {Custody} from "../libraries/LibCustody.sol";
import {HyperlaneClient} from "./bridges/HyperlaneClient.sol";
contract Gateway is Modifiers {

    event LogLockToChain(
        string recipientAddress,
        string recipientChain,
        address token,
        uint256 amount
    );

    function initGateway(address _psm, address _nexus) public onlyOwner {
        s.psm = _psm;
        s.nexus = _nexus;
    }

    function setPSM(address _psm) public onlyOwner {
        s.psm = _psm;
    }

    function setNexus(address _nexus) public onlyOwner {
        s.nexus = _nexus;
    }

    function deposit(address user, address token, uint256 amount,  bytes destination) external returns (bool) {
        Custody.depositIntoCustody(user,token,amount); //check effect
        _lock(owner, token, amount);
        HyperlaneClient.sendMintMessage(token, amount);
        return true;
    }

    function _lock(address calldata _user,address token, uint256 amount) internal returns(uint256) {

        require(_owner!=address(0));

        uint256 transferredAmount = IERC20Upgradeable(token).safeTransferFromWithFees(
            _msgSender(),
            address(this),
            _amount
        );

        emit LogLockToChain(
            _owner,
            token,
            amount
        );

        return transferredAmount;
    }
}