// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;
pragma abicoder v2;

import "@hyperlane-xyz/core/contracts/mock/MockOutbox.sol";
import "@hyperlane-xyz/core/contracts/mock/MockInbox.sol";
import "./mock/MockERC20.sol";
import "../src/Nexus/facets/CrossChainRouter.sol";
import "../src/Nexus/facets/bridges/AxonHyperlaneHandlerFacet.sol";
import "forge-std/Test.sol";
import "../src/Nexus/NexusGateway.sol";
import "../src/diamondCommons/interfaces/IDiamondCut.sol";
import "../src/diamondCommons/sharedFacets/DiamondCutFacet.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";


contract NexusDeposit is Test {
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
        bytes4[] memory ccrFunctionSelectors = new bytes4[](1);
        ccrFunctionSelectors[0] = ccr.depositTokenAndCall.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(ccr),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: ccrFunctionSelectors
        });

        HyperlaneFacet hyperlaneFacet = new HyperlaneFacet();
        bytes4[] memory hyperlaneFacetfunctionSelectors = new bytes4[](2);
        hyperlaneFacetfunctionSelectors[0] = hyperlaneFacet.bridgeTokenAndCallViaHyperlane.selector;
        hyperlaneFacetfunctionSelectors[1] = hyperlaneFacet.initHyperlaneFacet.selector;
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

    function testDepositAndCall(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit>0 && amountToDeposit<=100e18);
        address user = MOCK_ADDR_1;
        usdc.mint(MOCK_ADDR_1,100e18);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,false,TypeCasts.addressToBytes32(address(usdcEth)),abi.encodeWithSelector(usdcEth.balanceOf.selector,user));
        vm.stopPrank();
        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcEth.balanceOf(address(axonNexus)),amountToDeposit);
    }
}