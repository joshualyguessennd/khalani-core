pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./Mock/MockERC20Decimal.sol";
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
    MockERC20Decimal usdc;
    MockERC20Decimal usdt;
    USDMirror pan;

    address user = 0x0000000000000000000000000000000000000001;
    address MOCK_ADDRESS_1 = 0x0000000000000000000000000000000000000002;

    function setUp() public {
        usdc = new MockERC20Decimal("USDC","USDC");
        usdt = new MockERC20Decimal("USDT","USDT");
        pan = new USDMirror();
        pan.initialize("PAN","PAN");

        psm = new PanPSM();
        psm.initialize(address(pan));
        pan.transferMinterBurnerRole(address(psm));

        psm.addWhiteListedAsset(address(usdc));
        psm.addWhiteListedAsset(address(usdt));
    }

    function testTokenAdd() public{
        MockERC20Decimal busd = new MockERC20Decimal("BUSD","BUSD");
        vm.expectEmit(true,false,false,true);
        emit WhiteListedTokenAdded(address(busd));
        psm.addWhiteListedAsset(address(busd));
    }

    function testTokenRemove() public{
        vm.expectEmit(true,false,false,true);
        emit WhiteListedTokenRemoved(address (usdc));
        psm.removeWhiteListedAddress(address(usdc));
    }

    function testMintPan(uint balanceAmount, uint mintAmount, uint8 dec) public{
        balanceAmount = bound(balanceAmount,0,1.15e30);
        dec = uint8(bound(dec,1,18));
        vm.assume(balanceAmount>0 && mintAmount>0 && balanceAmount>mintAmount);
        usdc.setDecimal(dec);
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
            _upscale6(mintAmount,dec)
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
        balanceAmount = bound(balanceAmount,0,1.15e30);
        vm.assume(balanceAmount>0 && mintAmount>0 && balanceAmount>mintAmount);
        MockERC20Decimal newAsset = new MockERC20Decimal("DUMMY","DUMMY");
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

    function testRedeem(uint balanceAmount, uint mintAmount, uint redeemAmount,uint8 dec) public{
        balanceAmount = bound(balanceAmount,0,1.15e30);
        dec = uint8(bound(dec,1,18));
        vm.assume(balanceAmount<10e18 && balanceAmount>0 && mintAmount>0 && redeemAmount>0 && balanceAmount>=mintAmount && mintAmount>=redeemAmount);
        usdc.setDecimal(dec);
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
            _upscale6(mintAmount,dec)
        );

        assertEq(
            usdc.balanceOf(address(psm)),
            mintAmount
        );


        vm.prank(user);
        psm.redeemPan(redeemAmount,address(usdc));

        assertEq(
            pan.balanceOf(user),
            _upscale6(mintAmount,dec) - redeemAmount
        );

        assertEq(
            balanceAmount + _downscale6((redeemAmount*995)/1000, dec) - mintAmount,
            usdc.balanceOf(user)
        );
    }

    function testRedeemInvalidAsset(uint redeemAmount) public{
        MockERC20Decimal newAsset = new MockERC20Decimal("DUMMY","DUMMY");
        newAsset.mint(user,redeemAmount);
        //trying with a non-whitelisted asset
        vm.startPrank(user);
        newAsset.approve(address(psm),redeemAmount);
        vm.expectRevert(AssetNotWhiteListed.selector);
        psm.redeemPan(redeemAmount,address(newAsset));
        vm.stopPrank();
    }

    function testRedeemPanLowBalance(uint balanceAmount, uint mintAmount, uint redeemAmount,uint8 dec) public{
        balanceAmount = bound(balanceAmount,0,1.15e30);
        dec = uint8(bound(dec,1,18));
        vm.assume(balanceAmount<10e18 && balanceAmount>0 && mintAmount>0 && redeemAmount>0 && balanceAmount>=mintAmount && mintAmount>=redeemAmount);
        usdc.setDecimal(dec);
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
            _upscale6(mintAmount,dec)
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

    function _upscale6(uint a, uint d) internal returns (uint){
        uint b = 1e18 * 10**(18-d);
        uint256 product = a * b;
        return product / 1e18;
    }

    function _downscale6(uint a, uint d) internal returns (uint){
        uint b = 1e18 * 10**(18-d);
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * 1e18;
            return aInflated / b;
        }
    }

}