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
    * @notice burn mirror tokens and calls hyperplane  / celer to bridge token and execute call on `toContract` with `data`
    * pan will be minted and other chain token will be released
    * @param token - address of token to be withdrawn
    * @param amount - amount of tokens to be withdrawn
    * @param calls - contract address and calldata to execute crossChain
    **/
    function withdrawTokenAndCall(
        uint chainId,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external {
        IERC20Mintable(token).burn(msg.sender,amount);
        address _eoa = IKhalaInterchainAccount(msg.sender).eoa();

        if(s.godwokenChainId == chainId) {

            IMultiBridgeFacet(address(this)).bridgeTokenAndCallbackViaCeler(
                LibAppStorage.TokenBridgeAction.Withdraw,
                uint64(chainId),
                _eoa,
                token,
                amount,
                calls
            );

        } else {

            IMultiBridgeFacet(address(this)).bridgeTokenAndCallbackViaHyperlane(
                LibAppStorage.TokenBridgeAction.Withdraw,
                uint32(chainId),
                _eoa,
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
    * @notice burn mirror tokens and calls hyperplane  / celer to bridge token and execute call on `toContract` with `data`
    * pan will be minted and other chain token will be released
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param calls - contract address and calldata to execute crossChain
    **/
    function withdrawMultiTokenAndCall(
        uint chainId,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) external {
        require(tokens.length == amounts.length , "array length do not match");

        address _eoa = IKhalaInterchainAccount(msg.sender).eoa();

        for(uint i; i<tokens.length;) {
            IERC20Mintable(tokens[i]).burn(msg.sender,amounts[i]);
            unchecked {
                ++i;
            }
        }

        if(s.godwokenChainId == chainId) {

            IMultiBridgeFacet(address(this)).bridgeMultiTokenAndCallbackViaCeler(
                LibAppStorage.TokenBridgeAction.WithdrawMulti,
                uint64(chainId),
                _eoa,
                tokens,
                amounts,
                calls
            );

        } else {

            IMultiBridgeFacet(address(this)).bridgeMultiTokenAndCallbackViaHyperlane(
                LibAppStorage.TokenBridgeAction.WithdrawMulti,
                uint32(chainId),
                _eoa,
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
