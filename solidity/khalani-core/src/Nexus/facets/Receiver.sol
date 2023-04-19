// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../libraries/LibAccountsRegistry.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../interfaces/IKhalaInterchainAccount.sol";
import "../interfaces/IMessageReceiver.sol";
import {Call} from "../Call.sol";

contract Receiver is Modifiers {


    event LogWithdrawAndCall(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event LogWithdrawMultiTokenAndCall(
        address indexed user,
        address[]  tokens,
        uint256[]  amounts
    );

    event LogCrossChainMsg(
        address indexed recipient,
        bytes message,
        uint32 fromChainId
    );

    event LogReleaseToken(
        address indexed user,
        address token,
        uint256 amount
    );


    /**
    * @notice mint mirror token and calls and execute call on `toContract` with `data`
    * @param account - address of account
    * @param token - address of token to deposit
    * @param amount - amount of tokens to deposit
    * @param calls - contract address and calldata to execute crossChain
    **/
    function withdrawTokenAndCall(
        address sender,
        address account,
        address token,
        uint256 amount,
        Call[] memory calls
    ) internal nonReentrant {
        _releaseOrMint(account,token,amount);

        if(calls.length!=0){
            IMessageReceiver(account).collect(sender,calls);
        }

        emit LogWithdrawAndCall(
            account,
            token,
            amount
        );
    }

    /**
    * @notice mint mirror tokens and execute call on `toContract` with `data`
    * @param account - address of account
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param calls - contract address and calldata to execute crossChain
    **/
    function withdrawMultiTokenAndCall(
        address sender,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] memory calls
    ) internal nonReentrant {
        require(tokens.length == amounts.length, "array length do not match");
        for(uint i; i<tokens.length;) {
            _releaseOrMint(account,tokens[i],amounts[i]);
            unchecked {
                ++i;
            }
        }

        if(calls.length!=0){
            IMessageReceiver(account).collect(sender,calls);
        }

    emit LogWithdrawMultiTokenAndCall(
            account,
            tokens,
            amounts
        );
    }

    /**
    * @notice mints if token is kai and unlocks and transfers in case of other tokens
    * @param _user - address of user
    * @param _token - address of token
    * @param _amount - amount of tokens
    **/
    function _releaseOrMint(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
        if(s.kai == _token){
            IERC20Mintable(_token).mint(_user,_amount);
        } else {
            SafeERC20Upgradeable.safeTransfer(
                IERC20Upgradeable(_token),
                _user,
                _amount
            );
        }

        emit LogReleaseToken(
            _user,
            _token,
            _amount
        );
    }
}
