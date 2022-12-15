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
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function withdrawTokenAndCall(
        uint chainId,
        address token,
        uint256 amount,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {
        IERC20Mintable(token).burn(msg.sender,amount);
        address _eoa = IKhalaInterchainAccount(msg.sender).eoa();

        AppStorage storage ds = LibAppStorage.diamondStorage();
        if(ds.godwokenChainId == chainId) {

            IMultiBridgeFacet(address(this)).bridgeTokenAndCallbackViaCeler(
                LibAppStorage.TokenBridgeAction.Withdraw,
                uint64(chainId),
                _eoa,
                token,
                amount,
                toContract,
                data
            );

        } else {

            IMultiBridgeFacet(address(this)).bridgeTokenAndCallbackViaHyperlane(
                LibAppStorage.TokenBridgeAction.Withdraw,
                uint32(chainId),
                _eoa,
                token,
                amount,
                toContract,
                data
            );

        }


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
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function withdrawMultiTokenAndCall(
        uint chainId,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {
        require(tokens.length == amounts.length , "array length do not match");

        address _eoa = IKhalaInterchainAccount(msg.sender).eoa();

        for(uint i; i<tokens.length;) {
            IERC20Mintable(tokens[i]).burn(msg.sender,amounts[i]);
            unchecked {
                ++i;
            }
        }

        AppStorage storage ds = LibAppStorage.diamondStorage();
        if(ds.godwokenChainId == chainId) {

            IMultiBridgeFacet(address(this)).bridgeMultiTokenAndCallbackViaCeler(
                LibAppStorage.TokenBridgeAction.WithdrawMulti,
                uint64(chainId),
                _eoa,
                tokens,
                amounts,
                toContract,
                data
            );

        } else {

            IMultiBridgeFacet(address(this)).bridgeMultiTokenAndCallbackViaHyperlane(
                LibAppStorage.TokenBridgeAction.WithdrawMulti,
                uint32(chainId),
                _eoa,
                tokens,
                amounts,
                toContract,
                data
            );

        }

        emit LogWithdrawMultiTokenAndCall (
            tokens,
            msg.sender,
            amounts,
            toContract,
            data
        );
    }
}
