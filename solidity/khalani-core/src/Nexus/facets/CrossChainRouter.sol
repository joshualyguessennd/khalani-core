// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./bridges/HyperlaneFacet.sol";
import {Call} from "../Call.sol";

contract CrossChainRouter is Modifiers {

    event LogDepositAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        Call[] calls
    );

    event LogDepositMultiTokenAndCall(
        address[] indexed token,
        address indexed user,
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

    function initializeNexus(address _pan, address _axonReceiver, uint _axonChainId) public onlyDiamondOwner{
        s.pan = _pan;
        s.axonReceiver = _axonReceiver;
        s.axonChainId = _axonChainId;
    }

    function setPan(address _pan) external onlyDiamondOwner{
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        appStorage.pan = _pan;
    }

    /**
    * @notice locks token / burn pan token and calls hyperlane to bridge token and execute call on `toContract` with `data`
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
            token,
            msg.sender,
            amount,
            calls
        );

    }

    /**
    * @notice locks tokens / burn pan tokens and calls hyperlane to bridge tokens and execute call on `toContract` with `data`
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
            tokens,
            msg.sender,
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
        if(s.pan == _token) {
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
