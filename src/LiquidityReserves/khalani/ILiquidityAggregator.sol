pragma solidity ^0.8.0;

import "../../InterchainMessaging/Token.sol";

interface ILiquidityAggregator {

    //------------EVENTS------------//
    event Deposit(
        address indexed sender,
        Token[] tokens,
        address receiver
    );

    /**
    *@dev deposit mirror tokens to the liquidity aggregator and redeem kln(Token) 1:1 mint
    *@param token -> mirror tokens address and amount struct
    *@param receiver address to receive kln(Token)
    */
    function deposit(
        Token memory token,
        address receiver
    ) external returns (Token memory);
}