pragma solidity ^0.8.0;

import "../../libraries/LibAppStorage.sol";
import "../../interfaces/IAdapter.sol";
import "../../../LiquidityReserves/khalani/ILiquidityProjector.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../../Token.sol";
//Khalani Nexus Facet
contract BridgeFacet is KhalaniStorage{
    //------------EVENTS------------//
    event BridgeRequest(
        address indexed sender,
        uint256 indexed destinationChainId,
        Token[] approvedTokens,
        address target
    );
    //------------FUNCTIONS------------//
    /**
    * @dev send cross-chain message from Khalani to Destination
    * @param destinationChainId destination chain id
    * @param tokens array of tokens (address , amount) to be sent
    * @param target target address on destination chain
    * @param message arbitrary message to be sent
    */
    function send(
        uint256 destinationChainId,
        Token[] calldata tokens,
        address target,
        bytes calldata message
    ) external nonReentrant {
        if(target==address(0x0)){
            revert ZeroTargetAddress();
        }
        emit BridgeRequest(
            msg.sender,
            destinationChainId,
            tokens,
            target
        );
        ILiquidityProjector(s.liquidityProjector).lockOrBurn(destinationChainId, msg.sender, tokens);

        IAdapter(s.hyperlaneAdapter).relayMessage(
            destinationChainId,
            TypeCasts.addressToBytes32(s.chainIdToAdapter[destinationChainId]),
            prepareOutgoingMessage(
                tokens,
                target,
                message
            )
        );
    }

    /**
    * @dev send cross-chain message from Khalani to Destination
    * @param tokens array of tokens (address , amount) to be sent
    * @param target target address on destination chain
    * @param message arbitrary message to be sent
    */
    function prepareOutgoingMessage(
        Token[] calldata tokens,
        address target,
        bytes calldata message
    ) internal pure returns (bytes memory){
        return abi.encode(
            tokens,
            target,
            message
        );
    }
}

