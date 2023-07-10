pragma solidity ^0.8.0;

// simple counter contract which should emit and event and increase the counter
// does not have the actual interchainLiquidityHub functionality as its not possible to uint test with composable stable pool
contract MockVortex {
    event CountIncreased();
    uint public count;
    function increaseCount(uint value) external {
        emit CountIncreased();
        count = count + value;
    }
}