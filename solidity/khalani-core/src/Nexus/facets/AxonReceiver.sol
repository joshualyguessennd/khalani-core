// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../libraries/LibAccountsRegistry.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../interfaces/IProxyCall.sol";

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
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function depositTokenAndCall(
        address account,
        address token,
        uint256 amount,
        uint32 chainId,
        bytes32 toContract,
        bytes memory data
    ) internal nonReentrant {
        address khalaInterChainAddress = LibAccountsRegistry.getDeployedInterchainAccount(account);
        s.balances[account][token] += amount;
        IERC20Mintable(token).mint(khalaInterChainAddress,amount);
        _proxyCall(khalaInterChainAddress,toContract,data);
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
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function depositMultiTokenAndCall(
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        uint32 chainId,
        bytes32 toContract,
        bytes memory data
    ) internal nonReentrant {
        require(tokens.length == amounts.length, "array length do not match");
        address khalaInterChainAddress = LibAccountsRegistry.getDeployedInterchainAccount(account);
        for(uint i; i<tokens.length;) {
            s.balances[account][tokens[i]] += amounts[i];
            IERC20Mintable(tokens[i]).mint(khalaInterChainAddress,amounts[i]);
            unchecked {
                ++i;
            }
        }
        _proxyCall(khalaInterChainAddress,toContract,data);
        emit LogDepositMultiTokenAndCall(
            tokens,
            account,
            amounts,
            chainId
        );
    }

    function _proxyCall(address ica, bytes32 toContract, bytes memory data) internal {
        IProxyCall(ica).sendProxyCall(TypeCasts.bytes32ToAddress(toContract),data);
    }
}
