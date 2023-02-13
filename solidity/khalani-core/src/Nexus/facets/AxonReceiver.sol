// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../libraries/LibAccountsRegistry.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../interfaces/IKhalaInterchainAccount.sol";
import {Call} from "../Call.sol";

contract AxonReceiver is Modifiers {


    event LogDepositAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        uint32 fromChainId
    );

    event LogDepositMultiTokenAndCall(
        address[]  indexed token,
        address indexed user,
        uint256[]  amounts,
        uint32 fromChainId
    );

    event LogWithdrawTokenAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        uint32 fromChainId
    );

    event LogCrossChainMsg(
        address indexed recipient,
        bytes message,
        uint32 fromChainId
    );


    /**
    * @notice mint mirror token and calls and execute call on `toContract` with `data`
    * @param token - address of token to deposit
    * @param amount - amount of tokens to deposit
    * @param chainId - chain's domain from where call was received on axon
    * @param calls - contract address and calldata to execute crossChain
    **/
    function depositTokenAndCall(
        address account,
        address token,
        uint256 amount,
        uint32 chainId,
        Call[] memory calls
    ) internal nonReentrant {
        address khalaInterChainAddress = LibAccountsRegistry.getDeployedInterchainAccount(account);
        IERC20Mintable(token).mint(khalaInterChainAddress,amount);

        IKhalaInterchainAccount(khalaInterChainAddress).sendProxyCall(
                token,
                amount,
                chainId,
                calls
        );

        emit LogDepositAndCall(
            token,
            account,
            amount,
            chainId
        );
    }

    /**
    * @notice mint mirror tokens and execute call on `toContract` with `data`
    * @notice account - address of account
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param chainId - chain's domain from where call was received on axon
    * @param calls - contract address and calldata to execute crossChain
    **/
    function depositMultiTokenAndCall(
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        uint32 chainId,
        Call[] memory calls
    ) internal nonReentrant {
        require(tokens.length == amounts.length, "array length do not match");
        address khalaInterChainAddress = LibAccountsRegistry.getDeployedInterchainAccount(account);
        for(uint i; i<tokens.length;) {
            IERC20Mintable(tokens[i]).mint(khalaInterChainAddress,amounts[i]);
            unchecked {
                ++i;
            }
        }

        IKhalaInterchainAccount(khalaInterChainAddress).sendProxyCallForMultiTokens(
                tokens,
                amounts,
                chainId,
                calls
        );

        emit LogDepositMultiTokenAndCall(
            tokens,
            account,
            amounts,
            chainId
        );
    }
}
