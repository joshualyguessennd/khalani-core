// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./bridges/HyperlaneFacet.sol";

contract CrossChainRouter is Modifiers {

    event LogDepositAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        bytes32 toContract,
        bytes data
    );

    event LogDepositMultiTokenAndCall(
        address[] indexed token,
        address indexed user,
        uint256[] amounts,
        bytes32 toContract,
        bytes data
    );

    event LogWithdrawTokenAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        bytes32 toContract,
        bytes data
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

    event LogReleaseToken(
        address indexed user,
        address token,
        uint256 amount
    );

    /**
    * @notice locks token / burn pan token and calls hyperlane to bridge token and execute call on `toContract` with `data`
    * mirror token will be minted on axon chain
    * @param token - address of token to deposit
    * @param amount - amount of tokens to deposit
    * @param isPan - true when token in a Pan token ex - pan, panEth, panBTC
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function depositTokenAndCall(
        address token,
        uint256 amount,
        bool isPan,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {
        require(data.length > 0 , "empty call data");
        emit LogDepositAndCall(
            token,
            msg.sender,
            amount,
            toContract,
            data
        );

        IBridgeFacet(address(this)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            msg.sender,
            token,
            amount,
            toContract,
            data
        );

        if(isPan) {
            IERC20Mintable(token).burn(msg.sender,amount);
        } else{
            _lock(msg.sender, token, amount);
        }
    }

    /**
    * @notice locks tokens / burn pan tokens and calls hyperlane to bridge tokens and execute call on `toContract` with `data`
    * mirror token will be minted on axon chain
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param isPan - true when token in a Pan token ex - pan, panEth, panBTC
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function depositMultiTokenAndCall(
        address[] memory tokens,
        uint256[] memory amounts,
        bool[] memory isPan,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {

        require(data.length > 0 , "empty call data");

        require(tokens.length == amounts.length && tokens.length == isPan.length, "array length do not match");

        emit LogDepositMultiTokenAndCall (
            tokens,
            msg.sender,
            amounts,
            toContract,
            data
        );

        IBridgeFacet(address(this)).bridgeMultiTokenAndCall(
            LibAppStorage.TokenBridgeAction.DepositMulti,
            msg.sender,
            tokens,
            amounts,
            toContract,
            data
        );

        for(uint i=0; i<tokens.length;i++) {
            if(isPan[i]) {
                IERC20Mintable(tokens[i]).burn(msg.sender,amounts[i]);
            } else {
                _lock(msg.sender, tokens[i], amounts[i]);
            }
        }
    }

    /**
    * @notice release tokens / mint pan tokens and calls hyperlane to bridge tokens and execute call on `toContract` with `data`
    * mirror token will be minted on axon chain
    * @param token - addresses of tokens to deposit
    * @param amount - amounts of tokens to deposit
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
        require(data.length>0,"empty call data");
        emit LogWithdrawTokenAndCall(
            token,
            msg.sender,
            amount,
            toContract,
            data
        );

        IBridgeFacet(address(this)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Withdraw,
            msg.sender,
            token,
            amount,
            toContract,
            data
        );

        if(isPan) {
            IERC20Mintable(token).mint(msg.sender, amount);
        } else {
            _release(msg.sender, token, amount);
        }
    }

    // internal functions

    function _lock(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
        s.balances[_user][_token] += _amount;
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(_token),
            _user,
            address(this),
            _amount
        );

        emit LogLockToken(
            _user,
            _token,
            _amount
        );
    }

    function _release(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
        require(s.balances[_user][_token] >= _amount, "CCR_InsufficientBalance");
        s.balances[_user][_token] -= _amount;
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
