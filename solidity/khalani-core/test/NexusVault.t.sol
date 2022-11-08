//pragma solidity >=0.4.0 <0.8.0;
//pragma experimental ABIEncoderV2;
//
//import "forge-std/Test.sol";
//import "../src/NexusVault.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "./utils/Utilities.sol";
//
//contract NexusVaultTest is Test {
//    address public token0 = 0x2350E62fc02C84E4fd6aDbb69aa9962571Dae058;
//    address public token1 = 0x471A4d4F7133F005fE5bDe657729b90AEe66664a;
//    address public Bvault = 0xA138f9F9e172a80B122ae5283bD065Ae81a1c842;
//    address public invalidToken = 0xc7009c9b8c2484d974D04f43c542dF1c2f9Af837;
//    address public alice;
//
//    Utilities internal utils;
//    NexusVault public nexusVault;
//
//    function setUp() public {
//        nexusVault = new NexusVault(token0, token1, Bvault);
//        // address payable[] memory users = utils.createUsers(1);
//        alice = address(20);
//        // alice = users[0];
//        // vm.label(alice, "Alice");
//        deal(token0, alice, 10000e18);
//        deal(token1, alice, 10000e18);
//        deal(invalidToken, alice, 10000e18);
//    }
//
//    function test_deposit_vault() public {
//        vm.startPrank(alice);
//        uint256 balance_before = IERC20(address(nexusVault)).balanceOf(alice);
//        assertEq(balance_before, 0);
//        IERC20(token0).approve(address(nexusVault), 100e18);
//        IERC20(token1).approve(address(nexusVault), 100e18);
//        nexusVault.deposit(100e18, 100e18);
//        // deposit a second time
//        IERC20(token0).approve(address(nexusVault), 100e18);
//        IERC20(token1).approve(address(nexusVault), 100e18);
//        nexusVault.deposit(100e18, 100e18);
//        uint256 new_balance = IERC20(address(nexusVault)).balanceOf(alice);
//        assert(new_balance > balance_before);
//        console.log(new_balance);
//    }
//
//    function test_invalid_deposit() public {
//        vm.startPrank(alice);
//        uint256 balance_before = IERC20(address(nexusVault)).balanceOf(alice);
//        assertEq(balance_before, 0);
//        IERC20(token0).approve(address(nexusVault), 100e18);
//        IERC20(token1).approve(address(nexusVault), 100e18);
//        vm.expectRevert("Invalid Amounts");
//        nexusVault.deposit(0, 0);
//    }
//
//    function test_invalid_token() public {
//        vm.startPrank(alice);
//        uint256 balance_before = IERC20(address(nexusVault)).balanceOf(alice);
//        assertEq(balance_before, 0);
//        IERC20(invalidToken).approve(address(nexusVault), 100e18);
//        IERC20(invalidToken).transfer(address(nexusVault), 100e18);
//        assertEq(IERC20(invalidToken).balanceOf(address(nexusVault)), 100e18);
//        assertEq(IERC20(address(nexusVault)).balanceOf(alice), 0);
//    }
//
//    function test_invalid_withdraw() public {
//        vm.prank(address(12));
//        vm.expectRevert();
//        nexusVault.withdraw(1000e18);
//        test_deposit_vault();
//        uint256 balanceShares = IERC20(address(nexusVault)).balanceOf(alice);
//        vm.expectRevert();
//        nexusVault.withdraw(balanceShares + 1);
//    }
//
//    function test_withdraw() public {
//        uint256 balanceBefore0 = IERC20(token0).balanceOf(alice);
//        uint256 balanceBefore1 = IERC20(token1).balanceOf(alice);
//        test_deposit_vault();
//        uint256 balanceAfter0 = IERC20(token0).balanceOf(alice);
//        uint256 balanceAfter1 = IERC20(token1).balanceOf(alice);
//        console.log("balance deposit", balanceAfter0);
//        assert(balanceAfter0 < balanceBefore0);
//        assert(balanceAfter1 < balanceBefore1);
//        // test withdraw
//        uint256 balanceShares = IERC20(address(nexusVault)).balanceOf(alice);
//        nexusVault.withdraw(balanceShares);
//        uint256 balanceAfterWithdraw0 = IERC20(token0).balanceOf(alice);
//        uint256 balanceAfterWithdraw1 = IERC20(token1).balanceOf(alice);
//        console.log("Balance withdraw", balanceAfterWithdraw0);
//        assertEq(IERC20(address(nexusVault)).balanceOf(alice), 0);
//    }
//}
