// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@hyperlane-xyz/core/contracts/mock/MockOutbox.sol";
import "@hyperlane-xyz/core/contracts/mock/MockInbox.sol";
import "./Mock/MockERC20.sol";
import "../src/Nexus/facets/CrossChainRouter.sol";
import "../src/Nexus/facets/bridges/AxonHandlerFacet.sol";
import "forge-std/Test.sol";
import "../src/Nexus/NexusGateway.sol";
import "../src/diamondCommons/interfaces/IDiamondCut.sol";
import "../src/diamondCommons/sharedFacets/DiamondCutFacet.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../src/Nexus/libraries/LibAppStorage.sol";
import "./Mock/MockCelerMessageBus.sol";
import "../src/Nexus/facets/bridges/CelerFacet.sol";


contract NexusTest2 is Test {
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
    MockCelerMessageBus chain1Bus;
    MockCelerMessageBus chain2Bus;

    //Axon
    Nexus axonNexus;
    MockERC20 usdcEth;

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
        chain1Bus = new MockCelerMessageBus(1);
        console.log("chain1bus is ",address(chain1Bus));
        chain2Bus = new MockCelerMessageBus(2);
        chain1Bus.addChainBus(2,address(chain2Bus));
        chain2Bus.addChainBus(1,address (chain1Bus));
        ethNexus = deployDiamond();
        axonNexus = deployDiamond();
        //Eth Setup
        usdc = new MockERC20("USDC", "USDC");
        usdcEth = new MockERC20("USDCeth","USDCETH");

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

        CelerFacet celerFacet = new CelerFacet(address(chain1Bus));
        bytes4[] memory celerFacetfunctionSelectors = new bytes4[](4);
        celerFacetfunctionSelectors[0] = celerFacet.bridgeTokenAndCall.selector;
        celerFacetfunctionSelectors[1] = celerFacet.bridgeMultiTokenAndCall.selector;
        celerFacetfunctionSelectors[2] = celerFacet.initCelerFacet.selector;

        cut[1] = IDiamond.FacetCut({
        facetAddress: address(celerFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: celerFacetfunctionSelectors
        });

        DiamondCutFacet(address(ethNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );

        CelerFacet(address(ethNexus)).initCelerFacet(2, address(axonNexus), address(chain1Bus));

        //Axon side setup
        cut = new IDiamondCut.FacetCut[](1);

        AxonHandlerFacet axonhyperlanehandler = new AxonHandlerFacet(address(chain2Bus));
        bytes4[] memory axonHyperlaneFunctionSelectors = new bytes4[](5);
        axonHyperlaneFunctionSelectors[0] = axonhyperlanehandler.initializeAxonHandler.selector;
        axonHyperlaneFunctionSelectors[1] = axonhyperlanehandler.handle.selector;
        axonHyperlaneFunctionSelectors[2] = axonhyperlanehandler.addTokenMirror.selector;
        axonHyperlaneFunctionSelectors[3] = axonhyperlanehandler.addValidNexusForChain.selector;
        axonHyperlaneFunctionSelectors[4] = bytes4(keccak256(bytes("executeMessage(address,uint64,bytes,address)")));
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

        AxonHandlerFacet(address(axonNexus)).initializeAxonHandler(MOCK_ADDR_2, address(chain2Bus));
        AxonHandlerFacet(address (axonNexus)).addTokenMirror(1,address(usdc),address(usdcEth));
        AxonHandlerFacet(address (axonNexus)).addValidNexusForChain(1,TypeCasts.addressToBytes32(address(ethNexus)));
    }

    // Tests for successful deposit and calling a contract on the other chain
    function testDepositAndCallCeler(uint256 amountToDeposit) public {
        address user = MOCK_ADDR_1;

        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.stopPrank();
//        vm.expectEmit(true, true, false, false, address(axonNexus));
//        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit);
    }

    // Tests for successful deposit of multiple tokens and calling a contract on the other chain
    function testDepositMultiTokenAndCallCeler(uint256 amount1, uint256 amount2) public {
        address user = MOCK_ADDR_1;
        MockERC20 usdt = new MockERC20("USDT", "USDT");
        MockERC20 usdtEth =  new MockERC20("USDTEth" , "USDTETH");
        AxonHandlerFacet(address (axonNexus)).addTokenMirror(1,address(usdt),address(usdtEth));
        usdt.mint(user,amount2);
        usdc.mint(user,amount1);
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
        emit LogDepositMultiTokenAndCall(tokens,
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
//        vm.expectEmit(true, true, false, false, address(axonNexus));
//        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
//        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amount1);
        assertEq(usdtEth.balanceOf(address(axonNexus)),amount2);
    }

    // Tests for successful withdrawal of a token and calling a contract on the other chain
    function testWithDrawAndCall(uint256 amountToDeposit, uint256 amountToWithdraw) public {
        vm.assume(amountToWithdraw<amountToDeposit);
        address user = MOCK_ADDR_1;
        usdc.mint(MOCK_ADDR_1,type(uint256).max);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true, true, address(ethNexus));
        emit LogWithdrawTokenAndCall(address(usdc), user, amountToWithdraw, TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.stopPrank();
        //hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(address(ethNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(user),type(uint256).max - amountToDeposit);
        vm.prank(user);
        CrossChainRouter(address(ethNexus)).withdrawTokenAndCall(address(usdc),amountToWithdraw,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
//        vm.expectEmit(true, true, false, false, address(axonNexus));
//        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
//        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit - amountToWithdraw);
        assertEq(usdc.balanceOf(address(ethNexus)),amountToDeposit - amountToWithdraw);
        assertEq(usdc.balanceOf(user),type(uint256).max - amountToDeposit+amountToWithdraw);
    }

    // Failing test -  Attempting to withdraw more amounts of token than locked
    function testWithdrawFail(uint256 amountToDeposit, uint256 amountToWithdraw) public {
        vm.assume(amountToDeposit>0 && amountToDeposit<amountToWithdraw);
        address user = MOCK_ADDR_1;
        usdc.mint(MOCK_ADDR_1,type(uint256).max);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true, true, address(ethNexus));
        emit LogWithdrawTokenAndCall(address(usdc), user, amountToWithdraw, TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.stopPrank();
        //hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(address(ethNexus)),amountToDeposit);
        assertEq(usdc.balanceOf(user),type(uint256).max - amountToDeposit);

        vm.expectRevert("CCR_InsufficientBalance");
        //trying to withdraw more than available
        vm.prank(user);
        CrossChainRouter(address(ethNexus)).withdrawTokenAndCall(address(usdc),amountToWithdraw,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        //check if balance is still same i.e withdraw did not take place
        assertEq(usdc.balanceOf(user), type(uint256).max - amountToDeposit);
        assertEq(usdc.balanceOf(address(ethNexus)), amountToDeposit);
    }

    // Access control check tests

    //AxonHyperlaneHandlerFacet access test
//    function testAccessAxonReceiver(address caller) public {
//        // caller - random address which is not hyperlane inbox
//        vm.assume(caller!=address(0x0) && caller!=address(hyperlaneInboxAxon));
//        //constructing a valid msg
//        bytes memory message = abi.encode(MOCK_ADDR_1,address(usdc),100e18,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,MOCK_ADDR_1));
//        bytes memory messageWithAction = abi.encode(LibAppStorage.TokenBridgeAction.Deposit,message);
//
//
//        vm.startPrank(caller);
//        vm.expectRevert("only inbox can call");
//        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
//        vm.stopPrank();
//
//        // trying a call with hyperlaneInboxAxon
//        vm.startPrank(address(hyperlaneInboxAxon));
//        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
//        vm.stopPrank();
//
//        //testing only nexus can pass message
//        vm.startPrank(address(hyperlaneInboxAxon));
//        vm.expectRevert("AxonHyperlaneHandler : invalid nexus");
//        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(MOCK_ADDR_5)),messageWithAction);
//        vm.stopPrank();
//
//    }

    //testing hyperlane facet security
    function testAccessCelerFacet(address caller) public {
        vm.assume(caller!=address(0x0) && caller!=address(ethNexus));

        //attempting to call hyperlane facet directly
        vm.startPrank(caller);
        vm.expectRevert("BridgeFacet : Invalid Router");
        IBridgeFacet(address(ethNexus)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            caller,
            address(usdc),
            100e18,
            TypeCasts.addressToBytes32(address(ethNexus)),
            abi.encodeWithSelector(usdcEth.balanceOf.selector,caller)
        );
        vm.stopPrank();
    }

}