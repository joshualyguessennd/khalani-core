pragma solidity ^0.7.0;
import "forge-std/Test.sol";
import "../src/PSM.sol";


contract PSMTest is Test {
    PSM public psm;
    function setUp() public {
        psm = new PSM();
    }

    function test_shouldDepositLiqudity() public {
        // psm.deposit();
    }

    function test_shouldWithDrawLiqudity(uint256 x) public {
        // psm.withdraw(x);
    }
}