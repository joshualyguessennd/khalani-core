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
import "../src/Nexus/facets/factory/TokenRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/Nexus/Errors.sol";
import "./lib/Create2Lib.sol";
import "../src/Nexus/libraries/LibNexusABI.sol";
contract NexusHyperlaneTest is Test {
    //events
    event LogDepositAndCall(
        address indexed token,
        address indexed user,
        uint256 amount,
        Call[] calls
    );

    event LogDepositMultiTokenAndCall(
        address indexed user,
        address[] tokens,
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

    error TokenAlreadyExist(
        uint chain,
        address tokenOnChain,
        address tokenOnAxon
    );

    event LogCrossChainMsg(
        address indexed recipient,
        Call[] calls,
        uint fromChainId
    );
    //Eth
    Nexus ethNexus;
    MockERC20 usdc;
    MockERC20 kaiOnEth;
    MockERC20 usdt;
    MockMailbox mailboxEth;

    //Axon
    Nexus axonNexus;
    address usdcEth;
    address usdtEth;
    address kaiOnAxon;
    MockMailbox mailboxAxon;

    address MOCK_ADDR_1 = 0x0000000000000000000000000000000000000001;
    address MOCK_ADDR_2 = 0x0000000000000000000000000000000000000002;
    address MOCK_ADDR_3 = 0x0000000000000000000000000000000000000003;
    address MOCK_ADDR_4 = 0x0000000000000000000000000000000000000004;
    address MOCK_ADDR_5 = 0x0000000000000000000000000000000000000005;
    address MOCK_ISM    = 0x0000000000000000000000000000000000000006;
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
        ccrFunctionSelectors[3] = ccr.setKai.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(ccr),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: ccrFunctionSelectors
        });

        HyperlaneFacet hyperlaneFacet = new HyperlaneFacet();
        bytes4[] memory hyperlaneFacetfunctionSelectors = new bytes4[](4);
        hyperlaneFacetfunctionSelectors[0] = hyperlaneFacet.bridgeTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[1] = hyperlaneFacet.bridgeMultiTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[2] = hyperlaneFacet.initHyperlaneFacet.selector;
        hyperlaneFacetfunctionSelectors[3] = hyperlaneFacet.sendMultiCall.selector;
        cut[1] = IDiamond.FacetCut({
        facetAddress: address(hyperlaneFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: hyperlaneFacetfunctionSelectors
        });

        MsgHandlerFacet msgHandlerFacet = new MsgHandlerFacet(MOCK_ADDR_5);
        bytes4[] memory msgHandlerFacetfunctionSelectors = new bytes4[](2);
        msgHandlerFacetfunctionSelectors[0] = msgHandlerFacet.addChainTokenForMirrorToken.selector;
        msgHandlerFacetfunctionSelectors[1] = msgHandlerFacet.handle.selector;
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

        CrossChainRouter(address (ethNexus)).initializeNexus(address(kaiOnEth),address(axonNexus),2);
        HyperlaneFacet(address(ethNexus)).initHyperlaneFacet(address(mailboxEth), MOCK_ISM);

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
        deployTokens();
    }

    function deployTokens() internal {

        usdc = new MockERC20("USDC", "USDC");
        kaiOnEth = new MockERC20("KaiOnEth","Kai/Eth");
        usdt = new MockERC20("USDT", "USDT");
        kaiOnAxon = address(new MockERC20("KaiOnAxon","Kai/Axon"));

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        StableTokenRegistry tokenRegistry = new StableTokenRegistry();
        bytes4[] memory tokenRegistryfunctionSelectors = new bytes4[](3);
        tokenRegistryfunctionSelectors[0] = tokenRegistry.initTokenFactory.selector;
        tokenRegistryfunctionSelectors[1] = tokenRegistry.registerMirrorToken.selector;
        tokenRegistryfunctionSelectors[2] = tokenRegistry.registerKai.selector;
        cut[0] = IDiamond.FacetCut({
        facetAddress: address(tokenRegistry),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: tokenRegistryfunctionSelectors
        });

        DiamondCutFacet(address(axonNexus)).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
        StableTokenRegistry(address(axonNexus)).initTokenFactory(kaiOnAxon);
        StableTokenRegistry(address(axonNexus)).registerKai(1,address(kaiOnEth));
        MsgHandlerFacet(address(ethNexus)).addChainTokenForMirrorToken(address(kaiOnEth),address(kaiOnAxon));
        //deploying USDMirror for USDC on Godwoken
        usdcEth = address(new USDMirror());
        USDMirror(usdcEth).initialize("USDCeth","USDCETH"); //init
        USDMirror(usdcEth).transferMinterBurnerRole(address(axonNexus)); //transferOwnership
        //Adding mapping to nexus on GW
        MsgHandlerFacet(address(ethNexus)).addChainTokenForMirrorToken(address(usdc),usdcEth);
        //Registering tokens - nexus axon
        StableTokenRegistry(address(axonNexus)).registerMirrorToken(1, address(usdc), usdcEth);

        //deploying USDMirror for USDT on Eth
        usdtEth = address(new USDMirror());
        USDMirror(usdtEth).initialize("USDTEth","USDTEth"); //init
        USDMirror(usdtEth).transferMinterBurnerRole(address(axonNexus)); //transferOwnership
        //Adding mapping to nexus on GW
        MsgHandlerFacet(address(ethNexus)).addChainTokenForMirrorToken(address(usdt),usdtEth);
        //Registering tokens - nexus axon
        StableTokenRegistry(address(axonNexus)).registerMirrorToken(1, address(usdt), usdtEth);
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
        emit LogDepositAndCall(user,address(usdc),amountToDeposit,calls);
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
        emit LogDepositMultiTokenAndCall(
            user,
            tokens,
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

        bytes memory messageWithAction = LibNexusABI.encodeData1(LibAppStorage.TokenBridgeAction.Deposit,MOCK_ADDR_1,address(usdc),100e18,calls);

        vm.startPrank(caller);
        vm.expectRevert(InvalidInbox.selector);
        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
        vm.stopPrank();

        // trying a call with mailboxAxon
        vm.startPrank(address(mailboxAxon));
        AxonHandlerFacet(address(axonNexus)).handle(1,TypeCasts.addressToBytes32(address(ethNexus)),messageWithAction);
        vm.stopPrank();

        //testing only nexus can pass message
        vm.startPrank(address(mailboxAxon));
        vm.expectRevert(InvalidNexus.selector);
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
        vm.expectRevert(InvalidRouter.selector);
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

        address userKhalaAccount = Create2Lib.computeAddress(user,address(axonNexus));
        MockCounter counter = new MockCounter(userKhalaAccount);
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(counter),data:abi.encodeWithSelector(counter.increaseCount.selector,countToIncrease)});
        // dummy contract for ica call - call to this contract is only possible through `userKhalaAccount` - this will test if the call is going correctly from ICA proxy


        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(user, address(usdc), amountToDeposit, calls);
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
        emit LogDepositAndCall(user,address(usdc),amountToDeposit,calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(usdc),amountToDeposit, calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        mailboxEth.processNextPendingMessage();
        assertEq(usdc.balanceOf(user),amountToDeposit);
    }

    //Test scenario : depositAndCall with Kai
    //first cross chain call for add liquidity successful and second call fails
    function testWithdrawAndCallWithKai(uint amountToDeposit) public{
        amountToDeposit = bound(amountToDeposit,0,100e18); // limiting here because of multiple deposits
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        kaiOnEth.mint(user,amountToDeposit);
        Call[] memory calls =  new Call[](2);
        calls[0] = Call({to:address(kaiOnAxon),data:abi.encodeWithSelector(approveSelector,mockLp,amountToDeposit)});
        calls[1] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity.selector,address(kaiOnAxon),amountToDeposit)});
        vm.startPrank(user);
        kaiOnEth.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(user,address(kaiOnEth), amountToDeposit, calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(kaiOnEth),amountToDeposit,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        vm.expectRevert();
        mailboxEth.processNextPendingMessage();
        assertEq(IERC20(kaiOnAxon).balanceOf(address(mockLp)),amountToDeposit);
        assertEq(kaiOnEth.balanceOf(user),0);

        //failing call
        mockLp.setFail(true);
        kaiOnEth.mint(user,amountToDeposit);
        vm.startPrank(user);
        kaiOnEth.approve(address(ethNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(ethNexus));
        emit LogDepositAndCall(user,address(kaiOnEth), amountToDeposit, calls);
        CrossChainRouter(address(ethNexus)).depositTokenAndCall(address(kaiOnEth),amountToDeposit,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        mailboxEth.processNextPendingMessage();
        assertEq(IERC20(kaiOnAxon).balanceOf(address(mockLp)),amountToDeposit);
        assertEq(kaiOnEth.balanceOf(user),amountToDeposit);
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
        emit LogDepositMultiTokenAndCall(user,tokens,amounts,calls);
        CrossChainRouter(address(ethNexus)).depositMultiTokenAndCall(tokens,amounts,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(ethNexus)), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        mailboxEth.processNextPendingMessage();
        assertEq(usdc.balanceOf(user),amount1);
        assertEq(usdt.balanceOf(user),amount2);
    }

    function testPassMessage(uint countToIncrease) public{
        address user = MOCK_ADDR_1;
        MockCounter counter = new MockCounter(Create2Lib.computeAddress(user,address(axonNexus)));
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(counter),data:abi.encodeWithSelector(counter.increaseCount.selector,countToIncrease)});
        vm.prank(user);
        HyperlaneFacet(address(ethNexus)).sendMultiCall(calls);
        vm.expectEmit(true, false, false, true, address(axonNexus));
        emit LogCrossChainMsg(user,calls,1);
        mailboxAxon.processNextPendingMessage();
        assertEq(counter.getCount(),countToIncrease);
    }
}
