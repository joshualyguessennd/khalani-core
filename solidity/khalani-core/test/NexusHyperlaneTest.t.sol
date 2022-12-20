// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./Mock/MockERC20.sol";
import "../src/Nexus/facets/CrossChainRouter.sol";
import "../src/Nexus/facets/AxonCrossChainRouter.sol";
import "../src/Nexus/facets/bridges/AxonHandlerFacet.sol";
import "forge-std/Test.sol";
import "../src/Nexus/NexusGateway.sol";
import "../src/diamondCommons/interfaces/IDiamondCut.sol";
import "../src/diamondCommons/sharedFacets/DiamondCutFacet.sol";
import "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import "../src/Nexus/libraries/LibAppStorage.sol";
import "./Mock/MockCounter.sol";
import "../src/Nexus/facets/bridges/MsgHandlerFacet.sol";
import "./Mock/MockLp.sol";
import "../src/Nexus/facets/bridges/AxonMultiBridgeFacet.sol";
import "./Mock/MockMailbox.sol";
import "../src/Nexus/facets/factory/TokenFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract NexusHyperlaneTest is Test {
    //events
    event LogDepositAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        Call[] calls
    );

    event LogDepositMultiTokenAndCall(
        address[] indexed token,
        address indexed user,
        uint256[] amounts,
        Call[] calls
    );

    event LogWithdrawTokenAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        Call[] calls
    );

    event CrossChainMsgReceived(
        uint indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    event InterchainAccountCreated(
        address sender,
        address account
    );

    event MirrorTokenDeployed(
        uint indexed chainId,
        address token
    );

    //Eth
    Nexus ethNexus;
    MockERC20 usdc;
    MockERC20 panOnEth;
    MockERC20 usdt;
    MockMailbox mailboxEth;

    //Axon
    Nexus axonNexus;
    address usdcEth;
    address usdtEth;
    address panOnAxon;
    MockMailbox mailboxAxon;

    address MOCK_ADDR_1 = 0x0000000000000000000000000000000000000001;
    address MOCK_ADDR_2 = 0x0000000000000000000000000000000000000002;
    address MOCK_ADDR_3 = 0x0000000000000000000000000000000000000003;
    address MOCK_ADDR_4 = 0x0000000000000000000000000000000000000004;
    address MOCK_ADDR_5 = 0x0000000000000000000000000000000000000005;
    bytes4 approveSelector = usdc.approve.selector;

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
        ethNexus = deployDiamond();
        axonNexus = deployDiamond();
        //Eth Setup
        usdc = new MockERC20("USDC", "USDC");
        panOnEth = new MockERC20("PanOnEth","Pan/Eth");

        mailboxEth = new MockMailbox(1);
        mailboxAxon = new MockMailbox(2);
        mailboxEth.addRemoteMailbox(2,mailboxAxon);
        mailboxAxon.addRemoteMailbox(1,mailboxEth);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        CrossChainRouter ccr = new CrossChainRouter();
        bytes4[] memory ccrFunctionSelectors = new bytes4[](4);
        ccrFunctionSelectors[0] = ccr.initializeNexus.selector;
        ccrFunctionSelectors[1] = ccr.depositTokenAndCall.selector;
        ccrFunctionSelectors[2] = ccr.depositMultiTokenAndCall.selector;
        ccrFunctionSelectors[3] = ccr.setPan.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(ccr),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: ccrFunctionSelectors
        });

        HyperlaneFacet hyperlaneFacet = new HyperlaneFacet();
        bytes4[] memory hyperlaneFacetfunctionSelectors = new bytes4[](3);
        hyperlaneFacetfunctionSelectors[0] = hyperlaneFacet.bridgeTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[1] = hyperlaneFacet.bridgeMultiTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[2] = hyperlaneFacet.initHyperlaneFacet.selector;
        cut[1] = IDiamond.FacetCut({
        facetAddress: address(hyperlaneFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: hyperlaneFacetfunctionSelectors
        });

        MsgHandlerFacet msgHandlerFacet = new MsgHandlerFacet(MOCK_ADDR_5);
        bytes4[] memory msgHandlerFacetfunctionSelectors = new bytes4[](3);
        msgHandlerFacetfunctionSelectors[1] = msgHandlerFacet.addChainTokenForMirrorToken.selector;
        msgHandlerFacetfunctionSelectors[2] = msgHandlerFacet.handle.selector;
        cut[2] = IDiamond.FacetCut({
        facetAddress: address(msgHandlerFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: msgHandlerFacetfunctionSelectors
        });

        DiamondCutFacet(address(ethNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );

        CrossChainRouter(address (ethNexus)).initializeNexus(address(panOnEth),address(axonNexus),2);
        HyperlaneFacet(address(ethNexus)).initHyperlaneFacet(address(mailboxEth));

        //Axon side setup
        cut = new IDiamondCut.FacetCut[](3);

        AxonHandlerFacet axonhyperlanehandler = new AxonHandlerFacet(MOCK_ADDR_5);
        bytes4[] memory axonHyperlaneFunctionSelectors = new bytes4[](2);
        axonHyperlaneFunctionSelectors[0] = axonhyperlanehandler.handle.selector;
        axonHyperlaneFunctionSelectors[1] = axonhyperlanehandler.addValidNexusForChain.selector;
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

        AxonMultiBridgeFacet multiBridgeFacet = new AxonMultiBridgeFacet(MOCK_ADDR_5);
        bytes4[] memory multiBridgeFacetfunctionSelectors = new bytes4[](4);
        multiBridgeFacetfunctionSelectors[0] = multiBridgeFacet.initMultiBridgeFacet.selector;
        multiBridgeFacetfunctionSelectors[1] = multiBridgeFacet.addChainInbox.selector;
        multiBridgeFacetfunctionSelectors[2] = multiBridgeFacet.bridgeTokenAndCallbackViaHyperlane.selector;
        multiBridgeFacetfunctionSelectors[3] = multiBridgeFacet.bridgeMultiTokenAndCallbackViaHyperlane.selector;
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

        AxonMultiBridgeFacet(address(axonNexus)).initMultiBridgeFacet(MOCK_ADDR_5, address(mailboxAxon), 3);
        AxonMultiBridgeFacet(address(axonNexus)).addChainInbox(1,address(ethNexus));
        AxonHandlerFacet(address (axonNexus)).addValidNexusForChain(1,TypeCasts.addressToBytes32(address(ethNexus)));
        deployTokenFactory();

    }

    function deployTokenFactory() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        StableTokenFactory tokenFactory = new StableTokenFactory();
        bytes4[] memory tokenFactoryfunctionSelectors = new bytes4[](1);
        tokenFactoryfunctionSelectors[0] = tokenFactory.deployMirrorToken.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(tokenFactory),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: tokenFactoryfunctionSelectors
        });

        DiamondCutFacet(address(axonNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );

        usdcEth = StableTokenFactory(address(axonNexus)).deployMirrorToken("USDCeth","USDCETH",1,address(usdc));
        MsgHandlerFacet(address(ethNexus)).addChainTokenForMirrorToken(address(usdc),address(usdcEth));
        panOnAxon = StableTokenFactory(address(axonNexus)).deployMirrorToken("PanonAxon","PAN/Axon",1,address(panOnEth));
        MsgHandlerFacet(address(ethNexus)).addChainTokenForMirrorToken(address(panOnEth),address(panOnAxon));
        usdt = new MockERC20("USDT", "USDT");
        usdtEth =  StableTokenFactory(address(axonNexus)).deployMirrorToken("USDTEth","USDTEth",1,address(usdt));
        MsgHandlerFacet(address(ethNexus)).addChainTokenForMirrorToken(address(usdt), usdtEth);
    }

    // Tests for successful deposit and calling a contract on the other chain
    function testDepositAndCall(uint256 amountToDeposit) public {
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        Call[] memory calls =  new Call[](2);
        calls[0] = Call({to:address(usdcEth),data:abi.encodeWithSelector(approveSelector,mockLp,amountToDeposit)});
        calls[1] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity.selector,address(usdcEth),amountToDeposit)});
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit,calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        assertEq(IERC20(usdcEth).balanceOf(address(mockLp)),amountToDeposit);
    }

    // Tests for successful deposit of multiple tokens and calling a contract on the other chain
    function testDepositMultiTokenAndCall(uint256 amount1, uint256 amount2) public {
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        usdt.mint(user,amount2);
        usdc.mint(user,amount1);
        Call[] memory calls = new Call[](3);
        calls[0] = Call({to:address(usdcEth),data:abi.encodeWithSelector(approveSelector,mockLp,amount1)});
        calls[1] = Call({to:address(usdtEth),data:abi.encodeWithSelector(approveSelector,mockLp,amount2)});
        calls[2] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity2.selector,[address(usdcEth),address(usdtEth)],[amount1,amount2])});
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amount1);
        usdt.approve(address(ethNexus),amount2);
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(usdt);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        vm.expectEmit(true, true, true, true, address(ethNexus));
        emit LogDepositMultiTokenAndCall(tokens,
            user,
            amounts,
            calls
        );

        CrossChainRouter(address(ethNexus)).depositMultiTokenAndCall(
            tokens,
            amounts,
            calls
        );
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        assertEq(IERC20(usdcEth).balanceOf(address(mockLp)),amount1);
        assertEq(IERC20(usdtEth).balanceOf(address(mockLp)),amount2);
    }

    // Access control check tests

    //AxonHyperlaneHandlerFacet access test
    function testAccessAxonReceiver(address caller) public {
        // caller - random address which is not hyperlane inbox
        vm.assume(caller!=address(0x0) && caller!=address(mailboxAxon));
        //constructing a valid msg
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(usdcEth),data:abi.encodeWithSelector(approveSelector,mockLp,100e18)});
        bytes memory message = abi.encode(MOCK_ADDR_1,address(usdc),100e18,calls);
        bytes memory messageWithAction = abi.encode(LibAppStorage.TokenBridgeAction.Deposit,message);


        vm.startPrank(caller);
        vm.expectRevert("only inbox can call");
        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
        vm.stopPrank();

        // trying a call with mailboxAxon
        vm.startPrank(address(mailboxAxon));
        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
        vm.stopPrank();

        //testing only nexus can pass message
        vm.startPrank(address(mailboxAxon));
        vm.expectRevert("AxonHyperlaneHandler : invalid nexus");
        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(MOCK_ADDR_5)),messageWithAction);
        vm.stopPrank();

    }

    //testing hyperlane facet security
    function testAccessHyperlaneFacet(address caller) public {
        vm.assume(caller!=address(0x0) && caller!=address(ethNexus));

        //attempting to call hyperlane facet directly
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(usdcEth),data:abi.encodeWithSelector(approveSelector,mockLp,100e18)});
        vm.startPrank(caller);
        vm.expectRevert("BridgeFacet : Invalid Router");
        HyperlaneFacet(address(ethNexus)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            caller,
            address(usdc),
            100e18,
            calls
            );
        vm.stopPrank();
    }

    //inter-chain account call test
    function testICACreationAndCall(uint256 amountToDeposit,uint256 countToIncrease) public {
        address user = MOCK_ADDR_1;

        address userKhalaAccount = 0x554c7E9691cE9929938aE07a8f923Fd18863D2CD;
        MockCounter counter = new MockCounter(userKhalaAccount);
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(counter),data:abi.encodeWithSelector(counter.increaseCount.selector,countToIncrease)});
        // dummy contract for ica call - call to this contract is only possible through `userKhalaAccount` - this will test if the call is going correctly from ICA proxy


        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, true, address(axonNexus));
        emit InterchainAccountCreated(MOCK_ADDR_1, userKhalaAccount);
        mailboxAxon.processNextPendingMessage();
        assertEq(IERC20(usdcEth).balanceOf(userKhalaAccount),amountToDeposit);
        assertEq(counter.getCount(),countToIncrease);
    }

    //testing scenario - adding liquidity fail
    //successful withdrawal should refund back tokens to user's address on source chain
    function testWithdrawAndCall(uint amountToDeposit) public{
        mockLp.setFail(true);
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        usdc.mint(user,amountToDeposit);
        Call[] memory calls =  new Call[](2);
        calls[0] = Call({to:address(usdcEth),data:abi.encodeWithSelector(approveSelector,mockLp,amountToDeposit)});
        calls[1] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity.selector,address(usdcEth),amountToDeposit)});
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit, calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        mailboxEth.processNextPendingMessage();
        assertEq(usdc.balanceOf(user),amountToDeposit);
    }

    //Test scenario : depositAndCall with Pan
    //first cross chain call for add liquidity successful and second call fails
    function testWithdrawAndCallWithPan(uint amountToDeposit) public{
        amountToDeposit = bound(amountToDeposit,0,100e18); // limiting here because of multiple deposits
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        panOnEth.mint(user,amountToDeposit);
        Call[] memory calls =  new Call[](2);
        calls[0] = Call({to:address(panOnAxon),data:abi.encodeWithSelector(approveSelector,mockLp,amountToDeposit)});
        calls[1] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity.selector,address(panOnAxon),amountToDeposit)});
        vm.startPrank(user);
        panOnEth.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(address(panOnEth), user, amountToDeposit, calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(panOnEth),amountToDeposit,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        vm.expectRevert();
        mailboxEth.processNextPendingMessage();
        assertEq(IERC20(panOnAxon).balanceOf(address(mockLp)),amountToDeposit);
        assertEq(panOnEth.balanceOf(user),0);

        //failing call
        mockLp.setFail(true);
        panOnEth.mint(user,amountToDeposit);
        vm.startPrank(user);
        panOnEth.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(address(panOnEth), user, amountToDeposit, calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(panOnEth),amountToDeposit,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        mailboxEth.processNextPendingMessage();
        assertEq(IERC20(panOnAxon).balanceOf(address(mockLp)),amountToDeposit);
        assertEq(panOnEth.balanceOf(user),amountToDeposit);
    }

    //scenario : user tried to deposit both usdc and usdt and add liquidity call fails
    function testWithdrawMultiTokenAndCall(
        uint amount1,
        uint amount2
    ) public {
        mockLp.setFail(true);
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        usdc.mint(user,amount1);
        usdt.mint(user,amount2);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amount1);
        usdt.approve(address (ethNexus),amount2);
        Call[] memory calls = new Call[](3);
        calls[0] = Call({to:address(usdcEth),data:abi.encodeWithSelector(approveSelector,mockLp,amount1)});
        calls[1] = Call({to:address(usdtEth),data:abi.encodeWithSelector(approveSelector,mockLp,amount2)});
        calls[2] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity2.selector,[address(usdcEth),address(usdtEth)],[amount1,amount2])});
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(usdt);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositMultiTokenAndCall(tokens,user,amounts,calls);
        CrossChainRouter(address(ethNexus)).depositMultiTokenAndCall(tokens,amounts,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        mailboxEth.processNextPendingMessage();
        assertEq(usdc.balanceOf(user),amount1);
        assertEq(usdt.balanceOf(user),amount2);
    }
}