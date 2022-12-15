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

    event LogCrossChainMsg(
        address indexed recipient,
        bytes message
    );

    event LogLockToken(
        address indexed user,
        address token,
        uint256 amount
    );

    function setPan(address _pan) external onlyDiamondOwner{
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        appStorage.pan = _pan;
    }

    /**
    * @notice locks token / burn pan token and calls hyperlane to bridge token and execute call on `toContract` with `data`
    * mirror token will be minted on axon chain
    * @param token - address of token to deposit
    * @param amount - amount of tokens to deposit
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function depositTokenAndCall(
        address token,
        uint256 amount,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {

        _lockOrBurn(msg.sender, token, amount);

        IBridgeFacet(address(this)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            msg.sender,
            token,
            amount,
            toContract,
            data
        );

        emit LogDepositAndCall(
            token,
            msg.sender,
            amount,
            toContract,
            data
        );

    }

    /**
    * @notice locks tokens / burn pan tokens and calls hyperlane to bridge tokens and execute call on `toContract` with `data`
    * mirror token will be minted on axon chain
    * @param tokens - addresses of tokens to deposit
    * @param amounts - amounts of tokens to deposit
    * @param toContract - contract address to execute crossChain call on
    * @param data - call data to be executed on `toContract`
    **/
    function depositMultiTokenAndCall(
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) public nonReentrant {
        require(tokens.length == amounts.length, "array length do not match");

        for(uint i; i<tokens.length;) {
            _lockOrBurn(msg.sender, tokens[i], amounts[i]);
            unchecked {
                ++i;
            }
        }

        IBridgeFacet(address(this)).bridgeMultiTokenAndCall(
            LibAppStorage.TokenBridgeAction.DepositMulti,
            msg.sender,
            tokens,
            amounts,
            toContract,
            data
        );

        emit LogDepositMultiTokenAndCall (
            tokens,
            msg.sender,
            amounts,
            toContract,
            data
        );
    }

    // internal functions

    function  _lockOrBurn(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        if(ds.pan == _token) {
            IERC20Mintable(_token).burn(_user,_amount);
        } else {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(_token),
                _user,
                address(this),
                _amount
            );
        }

        emit LogLockToken(
            _user,
            _token,
            _amount
        );
    }

}
