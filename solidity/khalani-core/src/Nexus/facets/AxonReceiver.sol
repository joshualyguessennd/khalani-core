// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Mintable} from "../../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../libraries/LibAccountsRegistry.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
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
        require(data.length > 0 , "empty call data");
        emit LogDepositAndCall(
            token,
            account,
            amount,
            chainId
        );
        s.balances[account][token] += amount;
        address khalaInterChainAddress = LibAccountsRegistry.getDeployedInterchainAccount(account);
        IERC20Mintable(token).mint(khalaInterChainAddress,amount);
        _proxyCall(toContract,data);
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
        require(data.length > 0 , "empty call data");
        require(tokens.length == amounts.length, "array length do not match");
        emit LogDepositMultiTokenAndCall(
            tokens,
            account,
            amounts,
            chainId
        );
        address khalaInterChainAddress = LibAccountsRegistry.getDeployedInterchainAccount(account);
        for(uint i=0; i<tokens.length;i++) {
            s.balances[account][tokens[i]] += amounts[i];
            IERC20Mintable(tokens[i]).mint(khalaInterChainAddress,amounts[i]);
        }
        _proxyCall(toContract,data);
    }

    /**
    * @notice burn mirror tokens and calls execute call on `toContract` with `data`
    * @notice account - address of account
    * @param token - addresses of tokens to deposit
    * @param amount - amounts of tokens to deposit
    * @param chainId - chain's domain from where call was received on axon
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function withdrawTokenAndCall(
        address account,
        address token,
        uint256 amount,
        uint32 chainId,
        bytes32 toContract,
        bytes memory data
    ) internal nonReentrant {
        require(data.length>0,"empty call data");
        require(s.balances[account][token] >= amount, "CCR_InsufficientBalance");
        emit LogWithdrawTokenAndCall(
            token,
            account,
            amount,
            chainId
        );
        s.balances[account][token] -= amount;
        address khalaInterChainAddress = LibAccountsRegistry.getInterchainAccount(account);
        IERC20Mintable(token).burn(khalaInterChainAddress, amount);
        _proxyCall(toContract,data);
    }

    function _proxyCall(bytes32 toContract, bytes memory data) internal {
        (bool success, bytes memory returnData) = TypeCasts.bytes32ToAddress(toContract).call(data);
        if (!success) {
            assembly {
                revert(add(returnData, 32), returnData)
            }
        }
    }
}
