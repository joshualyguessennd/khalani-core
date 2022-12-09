// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "@hyperlane-xyz/core/interfaces/IOutbox.sol";
import "../../interfaces/IMultiBridgeFacet.sol";
import "@sgn-v2-contracts/message/framework/MessageApp.sol";
import "./libraries/LibAxonMultiBridgeFacet.sol";


// Hyperlane Facet for non Axon chain //TODO : Should we make this all `internal` ?
contract AxonMultiBridgeFacet is IMultiBridgeFacet, Modifiers, MessageApp{

    constructor(address _messageBus) MessageApp(_messageBus){

    }

    function initMultiBridgeFacet(
        address _celerMessageBus,
        address hyperlaneOutbox,
        uint _godwokenChainId
    ) external onlyDiamondOwner {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        appStorage.godwokenChainId = _godwokenChainId;
        setCelerMessageBus(_celerMessageBus);
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();
        ds.hyperlaneOutbox = hyperlaneOutbox;
    }

    function addChainInbox(uint chain, address chainInbox) public onlyDiamondOwner{
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();
        ds.chainInboxMap[chain] = chainInbox;
    }

    function setCelerMessageBus(address _celerMessageBus) internal {
        messageBus = _celerMessageBus;
    }

    function bridgeTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainId,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) public payable override validRouter  {
        bytes memory message = abi.encode(account,token,amount,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(_getHyperlaneOutBox()).dispatch(
            chainId,
            TypeCasts.addressToBytes32(_getInboxForChain(chainId)),
            messageWithAction
        );
    }

    function bridgeMultiTokenAndCallbackViaHyperlane(
        LibAppStorage.TokenBridgeAction action,
        uint32 chainId,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) public payable override validRouter {
        bytes memory message = abi.encode(account,tokens,amounts,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        IOutbox(_getHyperlaneOutBox()).dispatch(
            chainId,
            TypeCasts.addressToBytes32(_getInboxForChain(chainId)),
            messageWithAction
        );
    }

    function bridgeTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address account,
        address token,
        uint256 amount,
        bytes32  toContract,
        bytes calldata data
    ) public payable override validRouter  {
        bytes memory message = abi.encode(account,token,amount,toContract,data);
        bytes memory messageWithAction = abi.encode(action,message);
        sendMessage(
            _getInboxForChain(chainId),
            chainId,
            messageWithAction,
            msg.value
        );
    }

    function bridgeMultiTokenAndCallbackViaCeler(
        LibAppStorage.TokenBridgeAction action,
        uint64 chainId,
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32 toContract,
        bytes calldata data
    ) public payable override validRouter {
        bytes memory message = abi.encode(account,tokens,amounts,toContract,data);
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

    function _getHyperlaneOutBox() internal returns (address) {
        LibAxonMultiBridgeFacet.MultiBridgeStorage storage ds = LibAxonMultiBridgeFacet.multiBridgeFacetStorage();
        return ds.hyperlaneOutbox;
    }
}