// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./bridges/HyperlaneFacet.sol";

contract AxonCrossChainRouter is Modifiers {

    event LogWithdrawAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        bytes32 toContract,
        bytes data
    );

    event LogWithdrawMultiTokenAndCall(
        address[] indexed token,
        address indexed user,
        uint256[] amount,
        bytes32 toContract,
        bytes data
    );

    event LogCrossChainMsg(
        address indexed recipient,
        bytes message
    );

    event LogBurnToken(
        address indexed user,
        address token,
        uint256 amount
    );

    event LogReleaseToken(
        address indexed user,
        address token,
        uint256 amount
    );

    /**
    * @notice burn mirror tokens and calls hyperplane  / celer to bridge token and execute call on `toContract` with `data`
    * pan will be minted and other chain token will be released
    * @param token - address of token to be withdrawn
    * @param amount - amount of tokens to be withdrawn
    * @param isPan - true when token in a Pan token ex - pan, panEth, panBTC
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function withdrawTokenAndCall(
        address token,
        uint256 amount,
        bool isPan,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {
        IERC20Mintable(token).burn(msg.sender,amount);

        IBridgeFacet(address(this)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            msg.sender,
            token,
            amount,
            toContract,
            data
        );



        emit LogWithdrawAndCall(
            token,
            msg.sender,
            amount,
            toContract,
            data
        );
    }

    /**
    * @notice burn mirror tokens and calls hyperplane  / celer to bridge token and execute call on `toContract` with `data`
    * pan will be minted and other chain token will be released
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param isPan - true when token in a Pan token ex - pan, panEth, panBTC
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function withdrawMultiTokenAndCall(
        address[] memory tokens,
        uint256[] memory amounts,
        bool[] memory isPan,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {
        require(tokens.length == amounts.length && tokens.length == isPan.length, "array length do not match");

        for(uint i; i<tokens.length;) {
            IERC20Mintable(tokens[i]).burn(msg.sender,amounts[i]);
            unchecked {
                ++i;
            }
        }

        IBridgeFacet(address(this)).bridgeMultiTokenAndCall(
            LibAppStorage.TokenBridgeAction.WithdrawMulti,
            msg.sender,
            tokens,
            amounts,
            toContract,
            data
        );

        emit LogWithdrawMultiTokenAndCall (
            tokens,
            msg.sender,
            amounts,
            toContract,
            data
        );
    }

    function _release(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
        require(s.balances[_user][_token] >= _amount, "CCR_InsufficientBalance");
        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(_token),
            _user,
            _amount
        );

        emit LogReleaseToken(
            _user,
            _token,
            _amount
        );
    }

}
