// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../libraries/LibAccountsRegistry.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../interfaces/IProxyCall.sol";

contract Receiver is Modifiers {


    event LogWithdrawAndCall(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    event LogWithdrawMultiTokenAndCall(
        address[]  indexed token,
        address indexed user,
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
    * @param token - address of token to deposit
    * @param amount - amount of tokens to deposit
    * @param isPan - if token is a pan token pass true
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function withdrawTokenAndCall(
        address account,
        address token,
        uint256 amount,
        bool isPan,
        bytes32 toContract,
        bytes memory data
    ) internal nonReentrant {
        if(isPan){
            IERC20Mintable(token).mint(account,amount);
        } else{
            _release(account,token,amount);
        }
        // call ?
        emit LogWithdrawAndCall(
            token,
            account,
            amount
        );
    }

    /**
    * @notice mint mirror tokens and execute call on `toContract` with `data`
    * @notice account - address of account
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param isPan - if token is a pan token pass true
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function withdrawMultiTokenAndCall(
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bool[] memory isPan,
        bytes32 toContract,
        bytes memory data
    ) internal nonReentrant {
        require(tokens.length == amounts.length, "array length do not match");
        for(uint i; i<tokens.length;) {
            if(isPan[i]){
                IERC20Mintable(tokens[i]).mint(account,amounts[i]);
            } else{
                _release(account,tokens[i],amounts[i]);
            }

            unchecked {
                ++i;
            }
        }
        //call ?
        emit LogWithdrawMultiTokenAndCall(
            tokens,
            account,
            amounts
        );
    }

    function _release(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
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
