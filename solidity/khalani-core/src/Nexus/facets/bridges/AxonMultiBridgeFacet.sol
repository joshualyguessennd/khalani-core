// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "@hyperlane-xyz/core/interfaces/IOutbox.sol";
import "../../interfaces/IMultiBridgeFacet.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "./libraries/LibAxonMultiBridgeFacet.sol";
import {Call} from "../../Call.sol";


// Hyperlane + Celer Facet on Axon chain
//routes messages from axon to other chain via Hyperlane or Celer
contract AxonMultiBridgeFacet is IMultiBridgeFacet, Modifiers, MessageApp{

    constructor(address _messageBus) MessageApp(_messageBus){

    }

    function initMultiBridgeFacet(
        address _celerMessageBus,
        address _hyperlaneMailbox,
        uint _godwokenChainId
    ) external onlyDiamondOwner {   
        s.godwokenChainId = _godwokenChainId;
        setCelerMessageBus(_celerMessageBus); // TODO : Do we need this ?
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();
        ds.hyperlaneMailbox = _hyperlaneMailbox;
    }

    function addChainInbox(uint chain, address chainInbox) public onlyDiamondOwner{
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();
        ds.chainInboxMap[chain] = chainInbox;
    }

    function setCelerMessageBus(address _celerMessageBus) internal {
        messageBus = _celerMessageBus;
    }

    /**
    *@notice - bridges token and amp using hyperlane
    *@param action - Nexus's Token bridge action
    *@param chainId - chainId to send msg to
    *@param account - address to bridge token
    *@param token  - mirror token's address
    *@param amount - amount of token to bridge
    *@param calls - Multicall crosschain execution
    */
    function bridgeTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainId,
        address account,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) public payable override validRouter  {
        bytes memory message = abi.encode(account,token,amount,calls);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(_getHyperlaneMailBox()).dispatch(
            chainId,
            TypeCasts.addressToBytes32(_getInboxForChain(chainId)),
            messageWithAction
        );
    }

    /**
    *@notice - bridges token and amp using hyperlane
    *@param action - Nexus's Token bridge action
    *@param chainId - chainId to send msg to
    *@param account - address to bridge token
    *@param tokens - list of mirror token's addresses on axon
    *@param amounts - amounts of tokens to bridge
    *@param calls - Multicall crosschain execution
    */
    function bridgeMultiTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainId,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) public payable override validRouter {
        bytes memory message = abi.encode(account,tokens,amounts,calls);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(_getHyperlaneMailBox()).dispatch(
            chainId,
            TypeCasts.addressToBytes32(_getInboxForChain(chainId)),
            messageWithAction
        );
    }


    /**
    *@notice - bridges token and amp using hyperlane
    *@param action - Nexus's Token bridge action
    *@param chainId - chainId to send msg to
    *@param account - address to bridge token
    *@param token  - mirror token's address
    *@param amount - amount of token to bridge
    *@param calls - Multicall crosschain execution
    */
    function bridgeTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address account,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) public payable override validRouter  {
        bytes memory message = abi.encode(account,token,amount,calls);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            _getInboxForChain(chainId),
            chainId,
            messageWithAction,
            msg.value
        );
    }

    /**
    *@notice - bridges token and amp using hyperlane
    *@param action - Nexus's Token bridge action
    *@param chainId - chainId to send msg to
    *@param account - address to bridge token
    *@param tokens - list of mirror token's addresses on axon
    *@param amounts - amounts of tokens to bridge
    *@param calls - Multicall crosschain execution
    */
    function bridgeMultiTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        Call[] calldata calls
    ) public payable override validRouter {
        bytes memory message = abi.encode(account,tokens,amounts,calls);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            _getInboxForChain(chainId),
            chainId,
            messageWithAction,
            msg.value
        );
    }

    function _getInboxForChain(uint _chain) internal returns (address) {
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();
        return ds.chainInboxMap[_chain];
    }

    function _getHyperlaneMailBox() internal returns (address) {
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();
        return ds.hyperlaneMailbox;
    }
}