// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./bridges/HyperlaneFacet.sol";
import {Call} from "../Call.sol";

contract CrossChainRouter is Modifiers {

    event LogDepositAndCall(
        address indexed user,
        address indexed token,
        uint256 amount,
        Call[] calls
    );

    event LogDepositMultiTokenAndCall(
        address indexed user,
        address[]  tokens,
        uint256[] amounts,
        Call[] calls
    );

    event LogCrossChainMsg(
        address indexed recipient,
        bytes message
    );

    event LogLockToken(
        address indexed user,
        address token,
        uint256 amount
    );

    function initializeNexus(address _kai, address _axonReceiver, uint _axonChainId) public onlyDiamondOwner{
        s.kai = _kai;
        s.axonReceiver = _axonReceiver;
        s.axonChainId = _axonChainId;
    }

    function setKai(address _kai) external onlyDiamondOwner{
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        appStorage.kai = _kai;
    }

    /**
    * @notice locks token / burn kai token and calls hyperlane to bridge token and execute call on `toContract` with `data`
    * mirror token will be minted on axon chain
    * @param token - address of token to deposit
    * @param amount - amount of tokens to deposit
    * @param calls - address and data for cross-chain call
    **/
    function depositTokenAndCall(
        address token,
        uint256 amount,
        Call[] calldata calls
    ) public nonReentrant {

        _lockOrBurn(msg.sender, token, amount);

        IBridgeFacet(address(this)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            msg.sender,
            token,
            amount,
            calls
        );

        emit LogDepositAndCall(
            msg.sender,
            token,
            amount,
            calls
        );

    }

    /**
    * @notice locks tokens / burn kai tokens and calls hyperlane to bridge tokens and execute call on `toContract` with `data`
    * mirror token will be minted on axon chain
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param calls - address and data for cross-chain call
    **/
    function depositMultiTokenAndCall(
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) public nonReentrant {
        require(tokens.length == amounts.length, "array length do not match");

        for(uint i; i<tokens.length;) {
            _lockOrBurn(msg.sender, tokens[i], amounts[i]);
            unchecked {
                ++i;
            }
        }

        IBridgeFacet(address(this)).bridgeMultiTokenAndCall(
            LibAppStorage.TokenBridgeAction.DepositMulti,
            msg.sender,
            tokens,
            amounts,
            calls
        );

        emit LogDepositMultiTokenAndCall (
            msg.sender,
            tokens,
            amounts,
            calls
        );
    }

    // internal functions

    function  _lockOrBurn(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
        if(s.kai == _token) {
            IERC20Mintable(_token).burn(_user,_amount);
        } else {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(_token),
                _user,
                address(this),
                _amount
            );
        }

        emit LogLockToken(
            _user,
            _token,
            _amount
        );
    }

}
