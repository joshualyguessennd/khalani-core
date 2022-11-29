// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@hyperlane-xyz/core/contracts/mock/MockOutbox.sol";
import "@hyperlane-xyz/core/contracts/mock/MockInbox.sol";
import "./Mock/MockERC20.sol";
import "../src/Nexus/facets/CrossChainRouter.sol";
import "../src/Nexus/facets/bridges/AxonHyperlaneHandlerFacet.sol";
import "forge-std/Test.sol";
import "../src/Nexus/NexusGateway.sol";
import "../src/diamondCommons/interfaces/IDiamondCut.sol";
import "../src/diamondCommons/sharedFacets/DiamondCutFacet.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../src/Nexus/libraries/LibAppStorage.sol";


contract NexusTest is Test {
    //events
    event LogDepositAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        bytes32 toContract,
        bytes data
    );

    event LogDepositMultiTokenAndCall(
        address[] indexed token,
        address indexed user,
        uint256[] amounts,
        bytes32 toContract,
        bytes data
    );

    event LogWithdrawTokenAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        bytes32 toContract,
        bytes data
    );

    event CrossChainMsgReceived(
        uint32 indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    //Eth
    Nexus ethNexus;
    MockERC20 usdc;
    MockOutbox hyperlaneOutboxEth;

    //Axon
    Nexus axonNexus;
    MockERC20 usdcEth;
    MockInbox hyperlaneInboxAxon;

    address MOCK_ADDR_1 = 0x0000000000000000000000000000000000000001;
    address MOCK_ADDR_2 = 0x0000000000000000000000000000000000000002;
    address MOCK_ADDR_3 = 0x0000000000000000000000000000000000000003;
    address MOCK_ADDR_4 = 0x0000000000000000000000000000000000000004;
    address MOCK_ADDR_5 = 0x0000000000000000000000000000000000000005;

    function deployDiamond() internal returns (Nexus) {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        bytes4[] memory diamondCutFacetfunctionSelectors = new bytes4[](1);
        diamondCutFacetfunctionSelectors[0] = diamondCutFacet.diamondCut.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(diamondCutFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: diamondCutFacetfunctionSelectors
        });
        DiamondArgs memory args;
        args.owner  = address(this);
        args.init = address(0);
        args.initCalldata = "";
        Nexus diamond = new Nexus(cut, args);
        return diamond;
    }

    function setUp() public {
        ethNexus = deployDiamond();
        axonNexus = deployDiamond();
        //Eth Setup
        usdc = new MockERC20("USDC", "USDC");
        usdcEth = new MockERC20("USDCeth","USDCETH");
        hyperlaneInboxAxon = new MockInbox();
        hyperlaneOutboxEth = new MockOutbox(1,address(hyperlaneInboxAxon));

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);

        CrossChainRouter ccr = new CrossChainRouter();
        bytes4[] memory ccrFunctionSelectors = new bytes4[](3);
        ccrFunctionSelectors[0] = ccr.depositTokenAndCall.selector;
        ccrFunctionSelectors[1] = ccr.depositMultiTokenAndCall.selector;
        ccrFunctionSelectors[2] = ccr.withdrawTokenAndCall.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(ccr),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: ccrFunctionSelectors
        });

        HyperlaneFacet hyperlaneFacet = new HyperlaneFacet();
        bytes4[] memory hyperlaneFacetfunctionSelectors = new bytes4[](3);
        hyperlaneFacetfunctionSelectors[0] = hyperlaneFacet.bridgeTokenAndCallViaHyperlane.selector;
        hyperlaneFacetfunctionSelectors[1] = hyperlaneFacet.bridgeMultiTokenAndCallViaHyperlane.selector;
        hyperlaneFacetfunctionSelectors[2] = hyperlaneFacet.initHyperlaneFacet.selector;

        cut[1] = IDiamond.FacetCut({
        facetAddress: address(hyperlaneFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: hyperlaneFacetfunctionSelectors
        });

        DiamondCutFacet(address(ethNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );

        HyperlaneFacet(address(ethNexus)).initHyperlaneFacet(2, address(hyperlaneOutboxEth), address(axonNexus));

        //Axon side setup
        cut = new IDiamondCut.FacetCut[](1);

        AxonHyperlaneHandlerFacet axonhyperlanehandler = new AxonHyperlaneHandlerFacet();
        bytes4[] memory axonHyperlaneFunctionSelectors = new bytes4[](3);
        axonHyperlaneFunctionSelectors[0] = axonhyperlanehandler.initializeAxonHandler.selector;
        axonHyperlaneFunctionSelectors[1] = axonhyperlanehandler.handle.selector;
        axonHyperlaneFunctionSelectors[2] = axonhyperlanehandler.addTokenMirror.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(axonhyperlanehandler),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonHyperlaneFunctionSelectors
        });


        DiamondCutFacet(address(axonNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
        AxonHyperlaneHandlerFacet(address(axonNexus)).initializeAxonHandler(address (hyperlaneInboxAxon));
        AxonHyperlaneHandlerFacet(address (axonNexus)).addTokenMirror(1,address(usdc),address(usdcEth));
    }

    // Tests for successful deposit and calling a contract on the other chain
    function testDepositAndCall(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit>0 && amountToDeposit<=100e18);
        address user = MOCK_ADDR_1;

        usdc.mint(MOCK_ADDR_1,100e18);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit);
    }

    // Tests for successful deposit of multiple tokens and calling a contract on the other chain
    function testDepositMultiTokenAndCall(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1>0 && amount1<=100e18 && amount2>0 && amount2<=100e18);
        address user = MOCK_ADDR_1;
        MockERC20 usdt = new MockERC20("USDT", "USDT");
        MockERC20 usdtEth =  new MockERC20("USDTEth" , "USDTETH");
        AxonHyperlaneHandlerFacet(address (axonNexus)).addTokenMirror(1,address(usdt),address(usdtEth));
        usdt.mint(user,100e18);
        usdc.mint(user,100e18);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amount1);
        usdt.approve(address(ethNexus),amount2);
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(usdt);
        bool[] memory isPan = new bool[](2);
        isPan[0] = false;
        isPan[1] = false;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        vm.expectEmit(true, true, true, true, address(ethNexus));
        LogDepositMultiTokenAndCall(tokens,
            user,
            amounts,
            TypeCasts.addressToBytes32(address(usdcEth)),
            abi.encodeWithSelector(usdcEth.balanceOf.selector,user)
        );

        CrossChainRouter(address(ethNexus)).depositMultiTokenAndCall(
            tokens,
            amounts,
            isPan,
            TypeCasts.addressToBytes32(address(usdcEth)),
            abi.encodeWithSelector(usdcEth.balanceOf.selector,user)
        );
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amount1);
        assertEq(usdtEth.balanceOf(address(axonNexus)),amount2);
    }

    // Tests for successful withdrawal of a token and calling a contract on the other chain
    function testWithDrawAndCall(uint256 amountToDeposit, uint256 amountToWithdraw) public {
        vm.assume(amountToDeposit>0 && amountToDeposit<=100e18);
        vm.assume(amountToWithdraw>0 && amountToWithdraw<amountToDeposit);
        address user = MOCK_ADDR_1;
        usdc.mint(MOCK_ADDR_1,100e18);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true, true, address(ethNexus));
        LogWithdrawTokenAndCall(address(usdc), user, amountToWithdraw, TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.stopPrank();
        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(address(ethNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(user),100e18 - amountToDeposit);
        vm.prank(user);
        CrossChainRouter(address(ethNexus)).withdrawTokenAndCall(address(usdc),amountToWithdraw,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit - amountToWithdraw);
        assertEq(usdc.balanceOf(address(ethNexus)),amountToDeposit - amountToWithdraw);
        assertEq(usdc.balanceOf(user),100e18-amountToDeposit+amountToWithdraw);
    }

    // Failing test -  Attempting to withdraw more amounts of token than locked
    function testWithdrawFail(uint256 amountToDeposit, uint256 amountToWithdraw) public {
        vm.assume(amountToWithdraw>0 && amountToWithdraw<=100e18);
        vm.assume(amountToDeposit>0 && amountToDeposit<amountToWithdraw);
        address user = MOCK_ADDR_1;
        usdc.mint(MOCK_ADDR_1,100e18);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true, true, address(ethNexus));
        LogWithdrawTokenAndCall(address(usdc), user, amountToWithdraw, TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.stopPrank();
        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(address(ethNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(user),100e18 - amountToDeposit);

        vm.expectRevert("CCR_InsufficientBalance");
        //trying to withdraw more than available
        vm.prank(user);
        CrossChainRouter(address(ethNexus)).withdrawTokenAndCall(address(usdc),amountToWithdraw,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        //check if balance is still same i.e withdraw did not take place
        assertEq(usdc.balanceOf(user),100e18 - amountToDeposit);
        assertEq(usdc.balanceOf(address(ethNexus)), amountToDeposit);
    }

    // Access control check tests

    //AxonHyperlaneHandlerFacet access test
    function testAccessAxonReceiver(address caller) public {
        // caller - random address which is not hyperlane inbox

        //constructing a valid msg
        bytes memory message = abi.encode(MOCK_ADDR_1,address(usdc),100e18,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,MOCK_ADDR_1));
        bytes memory messageWithAction = abi.encode(LibAppStorage.TokenBridgeAction.Deposit,message);

        vm.assume(caller!=address(0x0) && caller!=address(hyperlaneInboxAxon));
        vm.startPrank(caller);
        vm.expectRevert("only inbox can call");
        AxonHyperlaneHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
        vm.stopPrank();

        // trying a call with hyperlaneInboxAxon
        vm.startPrank(address(hyperlaneInboxAxon));
        AxonHyperlaneHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
        vm.stopPrank();
    }
}