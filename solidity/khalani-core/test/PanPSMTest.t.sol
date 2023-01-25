pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./Mock/MockERC20.sol";
import "../src/USDMirror.sol";
import "../src/PSM/PanPSM.sol";

contract PanPSMTest is Test {

    error AssetNotWhiteListed();
    error RedeemFailedNotEnoughBalance();

    event WhiteListedTokenAdded(
        address indexed asset
    );

    event WhiteListedTokenRemoved(
        address indexed asset
    );

    PanPSM psm;
    MockERC20 usdc;
    MockERC20 usdt;
    USDMirror pan;

    address user = 0x0000000000000000000000000000000000000001;
    address MOCK_ADDRESS_1 = 0x0000000000000000000000000000000000000002;

    function setUp() public {
        usdc = new MockERC20("USDC","USDC");
        usdt = new MockERC20("USDT","USDT");
        pan = new USDMirror();
        pan.initialize("PAN","PAN");

        psm = new PanPSM();
        psm.initialize(address(pan));
        pan.transferMinterBurnerRole(address(psm));

        psm.addWhiteListedAsset(address(usdc));
        psm.addWhiteListedAsset(address(usdt));
    }

    function testTokenAdd() public{
        MockERC20 busd = new MockERC20("BUSD","BUSD");
        vm.expectEmit(true,false,false,true);
        emit WhiteListedTokenAdded(address(busd));
        psm.addWhiteListedAsset(address(busd));
    }

    function testTokenRemove() public{
        vm.expectEmit(true,false,false,true);
        emit WhiteListedTokenRemoved(address (usdc));
        psm.removeWhiteListedAddress(address(usdc));
    }

    function testMintPan(uint balanceAmount, uint mintAmount) public{
        vm.assume(balanceAmount>0 && mintAmount>0 && balanceAmount>=mintAmount);
        usdc.mint(user,balanceAmount);

        vm.startPrank(user);
        IERC20(address(usdc)).approve(address(psm),mintAmount);
        psm.mintPan(address(usdc),mintAmount);
        vm.stopPrank();

        assertEq(
            usdc.balanceOf(user),
            balanceAmount - mintAmount
        );

        assertEq(
            pan.balanceOf(user),
            mintAmount
        );

        assertEq(
            usdc.balanceOf(address(psm)),
            mintAmount
        );

        vm.startPrank(user);
        vm.expectRevert();
        psm.mintPan(address(usdt),mintAmount);
        vm.stopPrank();

        assertEq(
            usdt.balanceOf(user),
            0
        );

        assertEq(
            usdt.balanceOf(address(psm)),
            0
        );

    }

    function testMintPanInvalidAsset(uint balanceAmount, uint mintAmount) public{
        vm.assume(balanceAmount>0 && mintAmount>0 && balanceAmount>=mintAmount);
        MockERC20 newAsset = new MockERC20("DUMMY","DUMMY");
        newAsset.mint(user,balanceAmount);
        //trying with a non-whitelisted asset
        vm.startPrank(user);
        newAsset.approve(address(psm),mintAmount);
        vm.expectRevert(AssetNotWhiteListed.selector);
        psm.mintPan(MOCK_ADDRESS_1,mintAmount);
        vm.stopPrank();

        assertEq(
            IERC20(newAsset).balanceOf(user),
            balanceAmount
        );

    }

    function testRedeem(uint balanceAmount, uint mintAmount, uint redeemAmount) public{
        vm.assume(balanceAmount<10e18 && balanceAmount>0 && mintAmount>0 && redeemAmount>0 && balanceAmount>=mintAmount && mintAmount>=redeemAmount);
        usdc.mint(user,balanceAmount);

        vm.startPrank(user);
        usdc.approve(address(psm),mintAmount);
        psm.mintPan(address(usdc),mintAmount);
        vm.stopPrank();

        assertEq(
            usdc.balanceOf(user),
            balanceAmount - mintAmount
        );

        assertEq(
            pan.balanceOf(user),
            mintAmount
        );

        assertEq(
            usdc.balanceOf(address(psm)),
            mintAmount
        );


        vm.prank(user);
        psm.redeemPan(redeemAmount,address(usdc));

        assertEq(
            pan.balanceOf(user),
            mintAmount - redeemAmount
        );

        assertEq(
            balanceAmount + (redeemAmount*995)/1000 - mintAmount,
            usdc.balanceOf(user)
        );
    }

    function testRedeemInvalidAsset(uint redeemAmount) public{
        MockERC20 newAsset = new MockERC20("DUMMY","DUMMY");
        newAsset.mint(user,redeemAmount);
        //trying with a non-whitelisted asset
        vm.startPrank(user);
        newAsset.approve(address(psm),redeemAmount);
        vm.expectRevert(AssetNotWhiteListed.selector);
        psm.redeemPan(redeemAmount,address(newAsset));
        vm.stopPrank();
    }

    function testRedeemPanLowBalance(uint balanceAmount, uint mintAmount, uint redeemAmount) public{

        vm.assume(balanceAmount<10e18 && balanceAmount>0 && mintAmount>0 && redeemAmount>0 && balanceAmount>=mintAmount && mintAmount>=redeemAmount);
        usdc.mint(user,balanceAmount);

        vm.startPrank(user);
        usdc.approve(address(psm),mintAmount);
        psm.mintPan(address(usdc),mintAmount);
        vm.stopPrank();

        assertEq(
            usdc.balanceOf(user),
            balanceAmount - mintAmount
        );

        assertEq(
            pan.balanceOf(user),
            mintAmount
        );

        assertEq(
            usdc.balanceOf(address(psm)),
            mintAmount
        );

        //trying to withdraw with asset of low balance
        vm.startPrank(user);
        vm.expectRevert(RedeemFailedNotEnoughBalance.selector);
        psm.redeemPan(redeemAmount,address(usdt));
        vm.stopPrank();
    }
}