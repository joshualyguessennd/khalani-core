// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IMultiBridgeFacet.sol";
import "../interfaces/IKhalaInterchainAccount.sol";

contract AxonCrossChainRouter is Modifiers {

    event LogWithdrawAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        Call[] calls
    );

    event LogWithdrawMultiTokenAndCall(
        address[] indexed token,
        address indexed user,
        uint256[] amount,
        Call[] calls
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
    * @dev This function allows a user to withdraw multiple tokens and make a call to a smart contract.
    *
    * @param chainId Destination chain id
    * @param token  Tokens to be withdrawn.
    * @param amount Amount of token to be withdrawn.
    * @param receiver The address to receive the withdrawn tokens.
    * @param calls An array of calls to be executed after the tokens have been withdrawn.
    */
    function withdrawTokenAndCall(
        uint chainId,
        address token,
        uint256 amount,
        address receiver,
        Call[] calldata calls
    ) external {
        IERC20Mintable(token).burn(msg.sender,amount);
        _bridgeTokenAndSendMessage(chainId,receiver,token,amount,calls);
    }

    /**
    * @dev This function allows a user to withdraw multiple tokens and make a call to a smart contract.
    *
    * @param chainId Destination chain id
    * @param tokens An array of addresses representing the tokens to be withdrawn.
    * @param amounts Amount of each token to be withdrawn.
    * @param receiver The address to receive the withdrawn tokens.
    * @param calls An array of calls to be executed after the tokens have been withdrawn.
    */
    function withdrawMultiTokenAndCall(
        uint chainId,
        address[] memory tokens,
        uint256[] memory amounts,
        address receiver,
        Call[] calldata calls
    ) external {
        require(tokens.length == amounts.length , "array length do not match");

        for(uint i; i<tokens.length;) {
            IERC20Mintable(tokens[i]).burn(msg.sender,amounts[i]);
            unchecked {
                ++i;
            }
        }

        _bridgeTokensAndSendMessage(chainId,receiver,tokens,amounts,calls);
    }

    /*
    * @dev This function bridges a token from axon to  and executes a message call.
    *
    * @param Destination chain id.
    * @param receiver The address to receive the bridged token.
    * @param token The address of the token to be bridged.
    * @param amount The amount of the token to be bridged.
    * @param calls An array of calls to be executed after the token has been bridged.
    */
    function _bridgeTokenAndSendMessage(
        uint chainId,
        address receiver,
        address token,
        uint amount,
        Call[] calldata calls
    ) internal {
        if(s.godwokenChainId == chainId) {

            IMultiBridgeFacet(address(this)).bridgeTokenAndCallbackViaCeler(
                LibAppStorage.TokenBridgeAction.Withdraw,
                uint64(chainId),
                msg.sender,
                receiver,
                token,
                amount,
                calls
            );

        } else {

            IMultiBridgeFacet(address(this)).bridgeTokenAndCallbackViaHyperlane(
                LibAppStorage.TokenBridgeAction.Withdraw,
                uint32(chainId),
                msg.sender,
                receiver,
                token,
                amount,
                calls
            );

        }


        emit LogWithdrawAndCall(
            token,
            msg.sender,
            amount,
            calls
        );
    }

    /**
    * @dev This function bridges multiple tokens from axon to a destination and executes a message call.
    *
    * @param chainId The chain identifier for the blockchain the tokens are being bridged from.
    * @param receiver The address to receive the bridged tokens.
    * @param tokens An array of addresses representing the tokens to be bridged.
    * @param amounts An array of uint values representing the amount of each token to be bridged.
    * @param calls An array of calls to be executed after the tokens have been bridged.
    */
    function _bridgeTokensAndSendMessage(
        uint chainId,
        address receiver,
        address[] memory tokens,
        uint[] memory amounts,
        Call[] calldata calls
    ) internal {
        if(s.godwokenChainId == chainId) {

            IMultiBridgeFacet(address(this)).bridgeMultiTokenAndCallbackViaCeler(
                LibAppStorage.TokenBridgeAction.WithdrawMulti,
                uint64(chainId),
                msg.sender,
                receiver,
                tokens,
                amounts,
                calls
            );

        } else {

            IMultiBridgeFacet(address(this)).bridgeMultiTokenAndCallbackViaHyperlane(
                LibAppStorage.TokenBridgeAction.WithdrawMulti,
                uint32(chainId),
                msg.sender,
                receiver,
                tokens,
                amounts,
                calls
            );

        }

        emit LogWithdrawMultiTokenAndCall (
            tokens,
            msg.sender,
            amounts,
            calls
        );
    }
}
