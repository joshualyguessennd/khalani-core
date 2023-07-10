pragma solidity ^0.8.0;

import "./AbstractRequestProcessor.sol";
import "../../libraries/LibAppStorage.sol";
import "../../interfaces/IMessageReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../LiquidityReserves/khalani/ILiquidityAggregator.sol";

contract RemoteRequestProcessor is KhalaniStorage, AbstractRequestProcessor{
    /**
    * @dev process cross-chain message from Bridge's Adapter
    * @param _origin origin chain id
    * @param _sender sender address on origin chain
    * @param _message arbitrary message received from origin chain
    */
    function processRequest(
        uint256 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external override nonReentrant onlyHyperlaneAdapter(s.hyperlaneAdapter) {
        //validate
        isValidSender(_origin,_sender);
        // decode the message
        address user;
        uint256 destinationChainId;
        Token[] memory tokens;
        bytes memory interchainLiquidityHubPayload;
        address target;
        bytes memory message;

        (
            user,
            destinationChainId,
            tokens,
            interchainLiquidityHubPayload,
            target,
            message
        ) = decodeMessage(_message);

        if(target==address(0x0)) {
            revert ZeroTargetAddress();
        }

        emit MessageProcessed(_origin, user, tokens, destinationChainId, target);
        // check if the destinationChainId is Khalani chain itself
            // if the contract is  then exchange mirror token with aggregator, transfer to target contract and call the target contract
        // else -> the destinationChainId is not Khalani chain mint exact amount of mirror tokens, approve to swap executor and call the executor then bridge token to destination.
        tokens = mintTokens(_origin, tokens, address(this));
        if(destinationChainId == block.chainid){
            //for situations like add liquidity
            if(interchainLiquidityHubPayload.length!=0){
                executeILHPayload(tokens,interchainLiquidityHubPayload);
            } else {
                tokens = depositToLiquidityAggregator(tokens,target);
                if(target.code.length > 0){ //if a contract
                    IMessageReceiver(target).onMessageReceive(_origin,user,tokens,message);
                }
            }
        } else {
            executeILHPayload(tokens,interchainLiquidityHubPayload);
        }
    }

    /**
    * @dev decode the message received from origin chain
    * @param _message arbitrary message received from origin chain
    */
    function decodeMessage(
        bytes memory _message
    ) internal pure returns (
        address user,
        uint256 destinationChainId,
        Token[] memory approvedTokens,
        bytes memory interchainLiquidityHubPayload,
        address target,
        bytes memory message
    ) {
        (
            user,
            destinationChainId,
            approvedTokens,
            interchainLiquidityHubPayload,
            target,
            message
        ) = abi.decode(
            _message,(address,uint256, Token[], bytes, address, bytes)
        );
    }

    /**
    * @dev approve tokens to an address
    * @param tokens array of tokens to approve
    * @param to address to approve tokens to
    */
    function approveTokens(
        Token[] memory tokens,
        address to
    ) private {
        for(uint i; i<tokens.length;){
            SafeERC20.forceApprove(
                IERC20(tokens[i].tokenAddress),
                to,
                tokens[i].amount
            );

            unchecked{
                ++i;
            }
        }
    }

    /**
    * @dev exchange mirror tokens with kln(Token)
    * @param tokens array of tokens to approve
    * @param receiver address which will receive kln tokens
    */
    function depositToLiquidityAggregator( //transfer case
        Token[] memory tokens,
        address receiver
    ) private returns (Token[] memory){
        address kai = address(IAssetReserves(s.liquidityProjector).kai());
        for(uint i; i<tokens.length;){
            if(tokens[i].tokenAddress == kai){
                IERC20(kai).transfer(receiver,tokens[i].amount);
                unchecked{
                    ++i;
                }
                continue;
            }
            SafeERC20.forceApprove(
                IERC20(tokens[i].tokenAddress),
                s.liquidityAggregator,
                tokens[i].amount
            );
            tokens[i] = ILiquidityAggregator(s.liquidityAggregator).deposit(tokens[i], receiver);
            unchecked{
                ++i;
            }
        }
        return tokens;
    }

    function isValidSender(uint256 _origin, bytes32 _sender) internal virtual override view {
        if(s.chainIdToAdapter[_origin] != TypeCasts.bytes32ToAddress(_sender)){
            revert InvalidSender(_sender);
        }
    }

    function executeILHPayload(Token[] memory tokens, bytes memory interchainLiquidityHubPayload) private {
        // approveTokens to swap executor
        approveTokens(tokens,s.interchainLiquidityHub);
        // call the executor
        (bool success,) = s.interchainLiquidityHub.call(interchainLiquidityHubPayload);
        require(success,"RemoteRequestProcessor: meta transaction failed");
    }

    function mintTokens(uint256 chainId, Token[] memory tokens, address to) internal returns(Token[] memory){
        return ILiquidityProjector(s.liquidityProjector).mintOrUnlock(
            chainId,
            to,
            tokens
        );
    }
}