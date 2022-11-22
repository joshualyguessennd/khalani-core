//// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.7.0;
//pragma abicoder v2;
//
//import "forge-std/Test.sol";
//import "../src/interfaces/IDiamondCut.sol";
//import "../src/Khalani.sol";
//import "../src/facets/DiamondCutFacet.sol";
//import {HyperlaneClient} from "../src/facets/bridges/HyperlaneClient.sol";
//import "./Mock/MockERC20.sol";
//import "@hyperlane-xyz/core/contracts/mock/MockInbox.sol";
//import "@hyperlane-xyz/core/contracts/mock/MockOutbox.sol";
//import {Gateway} from "../src/facets/GatewayFacet.sol";
//import "../src/NexusHyperlaneClient.sol";
//import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
//import "../src/Vortex.sol";
//
//contract GatewayTest is Test {
//
//    event LogLockToChain(
//        address userAddr,
//        address token,
//        uint256 amount
//    );
//
//    event InterchainMessageReceived(uint32 _origin, address _sender, bytes _message);
//
//    Khalani public diamondContract;
//    MockERC20 usdc;
//    MockERC20 usdcEth;
//
//    MockOutbox outbox;
//    MockInbox inbox;
//
//    NexusHyperlaneClient nexusSideClient;
//
//    address MOCK_ADDR_1 = 0x0000000000000000000000000000000000000001;
//    address MOCK_ADDR_2 = 0x0000000000000000000000000000000000000002;
//    address MOCK_ADDR_3 = 0x0000000000000000000000000000000000000003;
//    address MOCK_ADDR_4 = 0x0000000000000000000000000000000000000004;
//    address MOCK_ADDR_5 = 0x0000000000000000000000000000000000000005;
//
//    function deployDiamond() internal returns (Khalani) {
//        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
//        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
//        bytes4[] memory diamondCutFacetfunctionSelectors = new bytes4[](1);
//        diamondCutFacetfunctionSelectors[0] = diamondCutFacet.diamondCut.selector;
//        cut[0] = IDiamond.FacetCut({
//        facetAddress: address(diamondCutFacet),
//        action: IDiamond.FacetCutAction.Add,
//        functionSelectors: diamondCutFacetfunctionSelectors
//        });
//        DiamondArgs memory args;
//        args.owner  = address(this);
//        args.init = address(0);
//        args.initCalldata = "";
//        Khalani diamond = new Khalani(cut, args);
//        return diamond;
//    }
//
//    function setUp() public {
//
//        usdc = new MockERC20();
//        usdc.initialize("USDC","USDC");
//
//        inbox = new MockInbox();
//        outbox = new MockOutbox(1,address(inbox));
//
//        Khalani diamond = deployDiamond();
//        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
//
//
//        Gateway gatewayFacet = new Gateway();
//        bytes4[] memory gatewayFacetfunctionSelectors = new bytes4[](4);
//        gatewayFacetfunctionSelectors[0] = gatewayFacet.deposit.selector;
//        gatewayFacetfunctionSelectors[1] = gatewayFacet.initGateway.selector;
//        gatewayFacetfunctionSelectors[2] = gatewayFacet.balance.selector;
//        gatewayFacetfunctionSelectors[3] = gatewayFacet.withdraw.selector;
//        cut[0] = IDiamond.FacetCut({
//        facetAddress: address(gatewayFacet),
//        action: IDiamond.FacetCutAction.Add,
//        functionSelectors: gatewayFacetfunctionSelectors
//        });
//
//        HyperlaneClient hyperlaneFacet = new HyperlaneClient();
//
//        bytes4[] memory hyperlaneFacetfunctionSelectors = new bytes4[](3);
//        hyperlaneFacetfunctionSelectors[0] = hyperlaneFacet.initHyperlane.selector;
//        hyperlaneFacetfunctionSelectors[1] = hyperlaneFacet.sendMintMessage.selector;
//        hyperlaneFacetfunctionSelectors[2] = hyperlaneFacet.sendBurnMessage.selector;
//        cut[1] = IDiamond.FacetCut({
//        facetAddress: address(hyperlaneFacet),
//        action: IDiamond.FacetCutAction.Add,
//        functionSelectors: hyperlaneFacetfunctionSelectors
//        });
//
//        DiamondCutFacet(address(diamond)).diamondCut(
//            cut, //array of of cuts
//            address(0), //initializer address
//            "" //initializer data
//        );
//        diamondContract = diamond;
//        diamondContract.setGateway(address(gatewayFacet));
//
//        nexusSideClient = new NexusHyperlaneClient(address(inbox));
//        usdcEth = new MockERC20();
//        address nexusOwner = address(nexusSideClient);
//        address nexusGateway = address(nexusSideClient);
//        vm.prank(nexusOwner);
//        Nexus nexus = new Nexus(MOCK_ADDR_4);
//        vm.startPrank(nexusOwner);
//        nexus.addTokenRepresentationMapping(1,address(usdc),address(usdcEth));
//        nexus.setGateway(nexusGateway);
//        vm.stopPrank();
//        nexusSideClient.setNexus(address (nexus));
//        //hyperlane init
//        HyperlaneClient(address(diamondContract)).initHyperlane(2,address(outbox),address(nexusSideClient));
//    }
//
//    function testDeposit(uint256 amountToDeposit) public {
//        vm.assume(amountToDeposit>0 && amountToDeposit<=100e18);
//        address user  = MOCK_ADDR_1;
//        usdc.mint(user,100e18);
//        vm.prank(user);
//        usdc.approve(address(diamondContract),100e18);
//        vm.expectEmit(false,false,false,true);
//        emit LogLockToChain(user, address(usdc), amountToDeposit);
//        vm.prank(user);
//        Gateway(address(diamondContract)).deposit(address(usdc), amountToDeposit, abi.encodePacked(MOCK_ADDR_3));
//        bytes memory _message = abi.encode(address (usdc), amountToDeposit);
//        vm.expectEmit(false,false,false,false);
//        emit InterchainMessageReceived(1, address(diamondContract), _message);
//        inbox.processNextPendingMessage();
//        assertEq(amountToDeposit,Gateway(address (diamondContract)).balance(user,address(usdc)));
//        assertEq(usdcEth.balanceOf(address(user)),amountToDeposit); // to be minted to ?
//    }
//
//    function testWithdraw(uint256 amountToDeposit, uint256 amountToWithdraw) public {
//        vm.assume(amountToDeposit>0 && amountToDeposit<=100e18);
//        amountToWithdraw = bound(amountToWithdraw,0,amountToDeposit);
//        address user  = MOCK_ADDR_1;
//        usdc.mint(user,100e18);
//        vm.prank(user);
//        usdc.approve(address(diamondContract),100e18);
//        vm.expectEmit(false,false,false,true);
//        emit LogLockToChain(user, address(usdc), amountToDeposit);
//        vm.prank(user);
//        Gateway(address(diamondContract)).deposit(address(usdc), amountToDeposit, abi.encodePacked(MOCK_ADDR_3));
//        inbox.processNextPendingMessage();
//        vm.prank(user);
//        Gateway(address(diamondContract)).withdraw(address(usdc), amountToWithdraw);
//        inbox.processNextPendingMessage();
//        assertEq(amountToDeposit-amountToWithdraw,Gateway(address (diamondContract)).balance(user,address(usdc)));
//        assertEq(usdcEth.balanceOf(address(user)),amountToDeposit-amountToWithdraw);
//    }
//}