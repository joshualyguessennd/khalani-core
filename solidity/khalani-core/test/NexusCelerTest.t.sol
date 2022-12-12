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
import "../src/Nexus/facets/bridges/MsgHandlerFacet.sol";
import "./Mock/MockCounter.sol";
import "./Mock/MockLp.sol";
import "../src/Nexus/facets/bridges/AxonMultiBridgeFacet.sol";
import "../src/Nexus/facets/AxonCrossChainRouter.sol";

contract NexusCelerTest is Test {
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

    //gW
    Nexus gwNexus;
    MockERC20 usdc;
    MockERC20 panOnGw;
    MockCelerMessageBus chain1Bus;
    MockCelerMessageBus chain2Bus;

    //Axon
    Nexus axonNexus;
    MockERC20 usdcgW;

    address MOCK_ADDR_1 = 0x0000000000000000000000000000000000000001;
    address MOCK_ADDR_2 = 0x0000000000000000000000000000000000000002;
    address MOCK_ADDR_3 = 0x0000000000000000000000000000000000000003;
    address MOCK_ADDR_4 = 0x0000000000000000000000000000000000000004;
    address MOCK_ADDR_5 = 0x0000000000000000000000000000000000000005;

    MockLp mockLp = new MockLp();

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
        chain2Bus = new MockCelerMessageBus(2);
        chain1Bus.addChainBus(2,address(chain2Bus));
        chain2Bus.addChainBus(1,address (chain1Bus));
        gwNexus = deployDiamond();
        axonNexus = deployDiamond();
        //gW Setup
        usdc = new MockERC20("USDC", "USDC");
        usdcgW = new MockERC20("usdcgW","usdcgW");
        panOnGw  = new MockERC20("PanOnGw","PAN/GW");

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        CrossChainRouter ccr = new CrossChainRouter();
        bytes4[] memory ccrFunctionSelectors = new bytes4[](3);
        ccrFunctionSelectors[0] = ccr.depositTokenAndCall.selector;
        ccrFunctionSelectors[1] = ccr.depositMultiTokenAndCall.selector;
        ccrFunctionSelectors[2] = ccr.setPan.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(ccr),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: ccrFunctionSelectors
        });

        CelerFacet celerFacet = new CelerFacet(address(chain1Bus));
        bytes4[] memory celerFacetfunctionSelectors = new bytes4[](3);
        celerFacetfunctionSelectors[0] = celerFacet.bridgeTokenAndCall.selector;
        celerFacetfunctionSelectors[1] = celerFacet.bridgeMultiTokenAndCall.selector;
        celerFacetfunctionSelectors[2] = celerFacet.initCelerFacet.selector;

        cut[1] = IDiamond.FacetCut({
        facetAddress: address(celerFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: celerFacetfunctionSelectors
        });

        MsgHandlerFacet msgHandlerFacet = new MsgHandlerFacet(address(chain1Bus));
        bytes4[] memory msgHandlerFacetfunctionSelectors = new bytes4[](3);
        msgHandlerFacetfunctionSelectors[0] = msgHandlerFacet.initializeMsgHandler.selector;
        msgHandlerFacetfunctionSelectors[1] = msgHandlerFacet.addChainTokenForMirrorToken.selector;
        msgHandlerFacetfunctionSelectors[2] = bytes4(keccak256(bytes("executeMessage(address,uint64,bytes,address)")));
        cut[2] = IDiamond.FacetCut({
        facetAddress: address(msgHandlerFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: msgHandlerFacetfunctionSelectors
        });

        DiamondCutFacet(address(gwNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );

        CrossChainRouter(address (gwNexus)).setPan(address(panOnGw));
        CelerFacet(address(gwNexus)).initCelerFacet(2, address(axonNexus), address(chain1Bus));
        MsgHandlerFacet(address(gwNexus)).initializeMsgHandler(address(MOCK_ADDR_5), address(chain1Bus), address(axonNexus));
        MsgHandlerFacet(address(gwNexus)).addChainTokenForMirrorToken(address(usdc),address(usdcgW));






        //Axon side setup
        cut = new IDiamondCut.FacetCut[](3);

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

        AxonCrossChainRouter axonCrossChainRouter = new AxonCrossChainRouter();
        bytes4[] memory axonCrossChainRouterfunctionSelectors = new bytes4[](2);
        axonCrossChainRouterfunctionSelectors[0] = axonCrossChainRouter.withdrawTokenAndCall.selector;
        axonCrossChainRouterfunctionSelectors[1] = axonCrossChainRouter.withdrawMultiTokenAndCall.selector;
        cut[1] = IDiamond.FacetCut({
        facetAddress: address(axonCrossChainRouter),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: axonCrossChainRouterfunctionSelectors
        });

        AxonMultiBridgeFacet multiBridgeFacet = new AxonMultiBridgeFacet(address(chain2Bus));
        bytes4[] memory multiBridgeFacetfunctionSelectors = new bytes4[](4);
        multiBridgeFacetfunctionSelectors[0] = multiBridgeFacet.initMultiBridgeFacet.selector;
        multiBridgeFacetfunctionSelectors[1] = multiBridgeFacet.addChainInbox.selector;
        multiBridgeFacetfunctionSelectors[2] = multiBridgeFacet.bridgeTokenAndCallbackViaCeler.selector;
        multiBridgeFacetfunctionSelectors[3] = multiBridgeFacet.bridgeMultiTokenAndCallbackViaCeler.selector;
        cut[2] = IDiamond.FacetCut({
            facetAddress: address(multiBridgeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: multiBridgeFacetfunctionSelectors
        });


        DiamondCutFacet(address(axonNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );

        AxonHandlerFacet(address(axonNexus)).initializeAxonHandler(MOCK_ADDR_2, address(chain2Bus));
        AxonHandlerFacet(address (axonNexus)).addTokenMirror(1,address(usdc),address(usdcgW));
        AxonHandlerFacet(address (axonNexus)).addValidNexusForChain(1,TypeCasts.addressToBytes32(address(gwNexus)));
        AxonMultiBridgeFacet(address(axonNexus)).initMultiBridgeFacet(address(chain2Bus), MOCK_ADDR_5, 1);
        AxonMultiBridgeFacet(address(axonNexus)).addChainInbox(1,address(gwNexus));
    }

    // Tests for successful deposit and calling a contract on the other chain
    function testDepositAndCallCeler(uint256 amountToDeposit) public {
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(gwNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, TypeCasts.addressToBytes32(address(usdcgW)),abi.encodeWithSelector(usdcgW.balanceOf.selector,user));
        CrossChainRouter(address(gwNexus)).depositTokenAndCall(address(usdc),amountToDeposit,TypeCasts.addressToBytes32(address(usdcgW)),abi.encodeWithSelector(usdcgW.balanceOf.selector,user));
        vm.stopPrank();
//        vm.expectEmit(true, true, false, false, address(axonNexus));
//        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(gwNexus)), abi.encode(""));
        assertEq(usdcgW.balanceOf(address(userKhalaAccount)),amountToDeposit);
    }

    // Tests for successful deposit of multiple tokens and calling a contract on the other chain
    function testDepositMultiTokenAndCallCeler(uint256 amount1, uint256 amount2) public {
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        MockERC20 usdt = new MockERC20("USDT", "USDT");
        MockERC20 usdtgW =  new MockERC20("USDTgW" , "USDTGw");
        AxonHandlerFacet(address (axonNexus)).addTokenMirror(1,address(usdt),address(usdtgW));
        usdt.mint(user,amount2);
        usdc.mint(user,amount1);
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amount1);
        usdt.approve(address(gwNexus),amount2);
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(usdt);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        vm.expectEmit(true, true, true, true, address(gwNexus));
        emit LogDepositMultiTokenAndCall(tokens,
            user,
            amounts,
            TypeCasts.addressToBytes32(address(usdcgW)),
            abi.encodeWithSelector(usdcgW.balanceOf.selector,user)
        );

        CrossChainRouter(address(gwNexus)).depositMultiTokenAndCall(
            tokens,
            amounts,
            TypeCasts.addressToBytes32(address(usdcgW)),
            abi.encodeWithSelector(usdcgW.balanceOf.selector,user)
        );
        vm.stopPrank();
//        vm.expectEmit(true, true, false, false, address(axonNexus));
//        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(gwNexus)), abi.encode(""));
//        hyperlaneInboxAxon.processNextPendingMessage();
        assertEq(usdcgW.balanceOf(address(userKhalaAccount)),amount1);
        assertEq(usdtgW.balanceOf(address(userKhalaAccount)),amount2);
    }


    // Access control check tests
    //AxonHandlerFacet access test
    function testAccessAxonReceiverCeler(address caller) public {
        // caller - random address which is not hyperlane inbox
        vm.assume(caller!=address(0x0) && caller!=address(chain2Bus));
        //constructing a valid msg
        bytes memory message = abi.encode(MOCK_ADDR_1,address(usdc),100e18,TypeCasts.addressToBytes32(address(usdcgW)),abi.encodeWithSelector(usdcgW.balanceOf.selector,MOCK_ADDR_1));
        bytes memory messageWithAction = abi.encode(LibAppStorage.TokenBridgeAction.Deposit,message);
        address dummyExecuter = 0x0000000000000000000000000000000000000010;

        vm.startPrank(caller);
        vm.expectRevert("caller is not message bus");
        AxonHandlerFacet(address(axonNexus)).executeMessage(address(gwNexus),1,messageWithAction,dummyExecuter);
        vm.stopPrank();

        // trying a call with hyperlaneInboxAxon
        vm.startPrank(address(chain2Bus));
        AxonHandlerFacet(address(axonNexus)).executeMessage(address(gwNexus),1,messageWithAction,dummyExecuter);
        vm.stopPrank();

        //testing only nexus can pass message
        vm.startPrank(address(chain2Bus));
        vm.expectRevert("AxonHyperlaneHandler : invalid nexus");
        AxonHandlerFacet(address(axonNexus)).executeMessage(MOCK_ADDR_5,1,messageWithAction,dummyExecuter);
        vm.stopPrank();

    }

    //testing hyperlane facet security
    function testAccessCelerFacet(address caller) public {
        vm.assume(caller!=address(0x0) && caller!=address(gwNexus));

        //attempting to call hyperlane facet directly
        vm.startPrank(caller);
        vm.expectRevert("BridgeFacet : Invalid Router");
        IBridgeFacet(address(gwNexus)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            caller,
            address(usdc),
            100e18,
            TypeCasts.addressToBytes32(address(gwNexus)),
            abi.encodeWithSelector(usdcgW.balanceOf.selector,caller)
        );
        vm.stopPrank();
    }

    //testing
    //inter-chain account call test
    function testICACreationAndCallCeler(uint256 amountToDeposit,uint256 countToIncrease) public {
        address user = MOCK_ADDR_1;

        address userKhalaAccount = 0x5300D4541528A33ef8EdcdCACb4369C1eb9261E4;

        // dummy contract for ica call - call to this contract is only possible through `userKhalaAccount` - this will test if the call is going correctly from ICA proxy
        MockCounter counter = new MockCounter(userKhalaAccount);

        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(gwNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, TypeCasts.addressToBytes32(address(counter)),abi.encodeWithSelector(counter.increaseCount.selector,countToIncrease));
        CrossChainRouter(address(gwNexus)).depositTokenAndCall(address(usdc),amountToDeposit,TypeCasts.addressToBytes32(address(counter)),abi.encodeWithSelector(counter.increaseCount.selector,countToIncrease));
        vm.stopPrank();
        assertEq(usdcgW.balanceOf(userKhalaAccount),amountToDeposit);
        assertEq(counter.getCount(),countToIncrease);
    }

    //testing scenario - adding liquidity fail
    //successful withdrawal should refund back tokens to user's address on source chain
    function testWithdrawAndCallCeler(uint amountToDeposit) public{
        mockLp.setFail(true);
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        usdc.mint(user,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(gwNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, TypeCasts.addressToBytes32(address(mockLp)),abi.encodeWithSelector(mockLp.addLiquidity.selector,amountToDeposit));
        CrossChainRouter(address(gwNexus)).depositTokenAndCall(address(usdc),amountToDeposit,TypeCasts.addressToBytes32(address(mockLp)),abi.encodeWithSelector(mockLp.addLiquidity.selector,amountToDeposit));
        vm.stopPrank();
        assertEq(usdc.balanceOf(user),amountToDeposit);
    }

    //scenario : user tried to deposit both usdc and usdt and add liquidity call fails
    function testWithdrawMultiTokenAndCallCeler(
        uint amount1,
        uint amount2
    ) public {
        mockLp.setFail(true);
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        // usdt new token
        MockERC20 usdt  = new MockERC20("USDT","USDT");
        MockERC20 usdtGw = new MockERC20("USDTGw", "USDTGw");
        AxonHandlerFacet(address(axonNexus)).addTokenMirror(1,address(usdt),address(usdtGw));
        MsgHandlerFacet(address(gwNexus)).addChainTokenForMirrorToken(address(usdt),address(usdtGw));
        usdc.mint(user,amount1);
        usdt.mint(user,amount2);
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amount1);
        usdt.approve(address (gwNexus),amount2);
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(usdt);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        vm.expectEmit(true, true, true , true,address(gwNexus));
        emit LogDepositMultiTokenAndCall(tokens,user,amounts,TypeCasts.addressToBytes32(address(mockLp)),abi.encodeWithSelector(mockLp.addLiqiuidity2.selector,[amount1,amount2]));
        CrossChainRouter(address(gwNexus)).depositMultiTokenAndCall(tokens,amounts,TypeCasts.addressToBytes32(address(mockLp)),abi.encodeWithSelector(mockLp.addLiqiuidity2.selector,[amount1,amount2]));
        vm.stopPrank();
        assertEq(usdc.balanceOf(user),amount1);
        assertEq(usdt.balanceOf(user),amount2);
    }
}