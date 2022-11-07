// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDiamondCut.sol";
import {Khalani} from "../src/Khalani.sol";
import "../src/facets/DiamondCutFacet.sol";
import {HyperlaneClient} from "../src/facets/bridges/HyperlaneClient.sol";
import "./Mock/MockERC20.sol";
import "@hyperlane-xyz/core/contracts/mock/MockInbox.sol";
import "@hyperlane-xyz/core/contracts/mock/MockOutbox.sol";

contract GatewayTest is Test {
    Khalani public diamondContract;
    MockERC20 usdc;

    MockOutbox outbox;
    MockInbox inbox;

    address MOCK_ADDR_1 = 0x0000000000000000000000000000000000000001;
    address MOCK_ADDR_2 = 0x0000000000000000000000000000000000000002;
    address MOCK_ADDR_3 = 0x0000000000000000000000000000000000000003;
    address MOCK_ADDR_4 = 0x0000000000000000000000000000000000000004;
    address MOCK_ADDR_5 = 0x0000000000000000000000000000000000000005;

    function deployDiamond() internal returns (Diamond) {
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        Khalani diamond = new Khalani(address(this), address(diamondCutFacet));
        return diamond;
    }

    function setUp() public {

        usdc = new MockERC20();
        usdc.initialize("USDC","USDC");

        inbox = new MockInbox();
        outbox = new MockOutbox(address(inbox));

        Khalani diamond = deployDiamond();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);


        GatewayFacet gatewayFacet = new GatewayFacet();
        bytes4[] memory gatewayFacetfunctionSelectors = new bytes4[](2);
        gatewayFacetfunctionSelectors[0] = GatewayFacet.deposit.selector;
        gatewayFacetfunctionSelectors[1] = GatewayFacet.initGateway.selector;
        cut[0] = IDiamondCut.FacetCut({
        facetAddress: address(gatewayFacet),
        action: IDiamondCut.FacetCutAction.Add,
        functionSelectors: gatewayFacetfunctionSelectors
        });

        HyperlaneClient hyperlaneFacet = new HyperlaneClient();

        bytes4[] memory hyperlaneFacetfunctionSelectors = new bytes4[](2);
        hyperlaneFacetfunctionSelectors[0] = HyperlaneClient.initHyperlane.selector;
        hyperlaneFacetfunctionSelectors[1] = HyperlaneClient.sendMintMessage.selector;
        cut[1] = IDiamondCut.FacetCut({
        facetAddress: address(hyperlaneFacet),
        action: IDiamondCut.FacetCutAction.Add,
        functionSelectors: hyperlaneFacetfunctionSelectors
        });

        DiamondCutFacet(address(diamond)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
        diamondContract = diamond;

        //hyperlane init
        HyperlaneClient(address(diamondContract)).initHyperlane(1,inbox,outbox,MOCK_ADDR_2);
    }

    function testDeposit(uint256 amountToDeposit) public {
        GatewayFacet gateway = GatewayFacet(address(diamondContract));
        vm.assume(amountToDeposit>0 && amountToDeposit<=100e18);
        address user  = MOCK_ADDR_1;
        usdc.mint(user,100e18);
        vm.prank(user);
        gateway.deposit(user,amountToDeposit);
        assertEq(amountToDeposit,gateway.balance(user,token));
        //more checks to added
    }
}