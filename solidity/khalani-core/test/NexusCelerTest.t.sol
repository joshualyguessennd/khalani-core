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
import {Call} from "../src/Nexus/Call.sol";
import "../src/Nexus/facets/factory/TokenFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NexusCelerTest is Test {
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

    event MirrorTokenDeployed(
        uint indexed chainId,
        address token
    );

    //gW
    Nexus gwNexus;
    MockERC20 usdc;
    MockERC20 usdt;
    MockERC20 panOnGw;
    MockCelerMessageBus chain1Bus;
    MockCelerMessageBus chain2Bus;

    //Axon
    Nexus axonNexus;
    address usdcgW;
    address usdtgW;

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
        chain1Bus = new MockCelerMessageBus(1);
        chain2Bus = new MockCelerMessageBus(2);
        chain1Bus.addChainBus(2,address(chain2Bus));
        chain2Bus.addChainBus(1,address (chain1Bus));
        gwNexus = deployDiamond();
        axonNexus = deployDiamond();
        //gW Setup
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
        bytes4[] memory msgHandlerFacetfunctionSelectors = new bytes4[](2);
        msgHandlerFacetfunctionSelectors[0] = msgHandlerFacet.addChainTokenForMirrorToken.selector;
        msgHandlerFacetfunctionSelectors[1] = bytes4(keccak256(bytes("executeMessage(address,uint64,bytes,address)")));
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

        CrossChainRouter(address (gwNexus)).initializeNexus(address(panOnGw),address(axonNexus),2);
        CelerFacet(address(gwNexus)).initCelerFacet(address(chain1Bus));

        //Axon side setup
        cut = new IDiamondCut.FacetCut[](3);

        AxonHandlerFacet axonhyperlanehandler = new AxonHandlerFacet(address(chain2Bus));
        bytes4[] memory axonHyperlaneFunctionSelectors = new bytes4[](2);
        axonHyperlaneFunctionSelectors[0] = axonhyperlanehandler.addValidNexusForChain.selector;
        axonHyperlaneFunctionSelectors[1] = bytes4(keccak256(bytes("executeMessage(address,uint64,bytes,address)")));
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

        AxonMultiBridgeFacet(address(axonNexus)).initMultiBridgeFacet(address(chain2Bus), MOCK_ADDR_5, 1);
        AxonMultiBridgeFacet(address(axonNexus)).addChainInbox(1,address(gwNexus));
        AxonHandlerFacet(address (axonNexus)).addValidNexusForChain(1,TypeCasts.addressToBytes32(address(gwNexus)));
        deployTokenFactory();

    }

    function deployTokenFactory() internal {
        usdc = new MockERC20("USDC", "USDC");
        panOnGw  = new MockERC20("PanOnGw","PAN/GW");
        usdt = new MockERC20("USDT", "USDT");
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        StableTokenFactory tokenFactory = new StableTokenFactory();
        bytes4[] memory tokenFactoryfunctionSelectors = new bytes4[](3);
        tokenFactoryfunctionSelectors[0] = tokenFactory.deployMirrorToken.selector;
        tokenFactoryfunctionSelectors[1] = tokenFactory.initTokenFactory.selector;
        tokenFactoryfunctionSelectors[2] = tokenFactory.registerPan.selector;
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
        usdcgW = StableTokenFactory(address(axonNexus)).deployMirrorToken("USDCgW","USDCgW",1,address(usdc));
        console.log("usdc salt");
        uint chainId =1;
        console.logBytes32(bytes32(abi.encodePacked(chainId,address(usdc))));
        MsgHandlerFacet(address(gwNexus)).addChainTokenForMirrorToken(address(usdc),usdcgW);

        console.log("usdt salt");
        console.logBytes32(bytes32(abi.encodePacked(chainId,address(usdt))));
        usdtgW =  StableTokenFactory(address(axonNexus)).deployMirrorToken("USDTgW","USDTGw",1,address(usdt));
        MsgHandlerFacet(address(gwNexus)).addChainTokenForMirrorToken(address(usdt), usdtgW);
    }

    // Tests for successful deposit and calling a contract on the other chain
    function testDepositAndCallCeler(uint256 amountToDeposit) public {
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);
        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        Call[] memory calls =  new Call[](2);
        calls[0] = Call({to:address(usdcgW),data:abi.encodeWithSelector(approveSelector,mockLp,amountToDeposit)});
        calls[1] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity.selector,address(usdcgW),amountToDeposit)});
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(gwNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, calls);
        CrossChainRouter(address(gwNexus)).depositTokenAndCall(address(usdc),amountToDeposit,calls);
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(gwNexus)), abi.encode(""));
        chain2Bus.processNextPendingMsg();
        assertEq(IERC20(usdcgW).balanceOf(address(mockLp)),amountToDeposit);
    }

    // Tests for successful deposit of multiple tokens and calling a contract on the other chain
    function testDepositMultiTokenAndCallCeler(uint256 amount1, uint256 amount2) public {
        address user = MOCK_ADDR_1;
        vm.prank(address(axonNexus));
        address userKhalaAccount = LibAccountsRegistry.getDeployedInterchainAccount(user);

        usdt.mint(user,amount2);
        usdc.mint(user,amount1);
        Call[] memory calls = new Call[](3);
        calls[0] = Call({to:address(usdcgW),data:abi.encodeWithSelector(approveSelector,mockLp,amount1)});
        calls[1] = Call({to:address(usdtgW),data:abi.encodeWithSelector(approveSelector,mockLp,amount2)});
        calls[2] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity2.selector,[address(usdcgW),address(usdtgW)],[amount1,amount2])});
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
            calls
        );

        CrossChainRouter(address(gwNexus)).depositMultiTokenAndCall(
            tokens,
            amounts,
            calls
        );
        vm.stopPrank();
        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(1, TypeCasts.addressToBytes32(address(gwNexus)), abi.encode(""));
        chain2Bus.processNextPendingMsg();
        assertEq(IERC20(usdcgW).balanceOf(address(mockLp)),amount1);
        assertEq(IERC20(usdtgW).balanceOf(address(mockLp)),amount2);
    }


    // Access control check tests
    //AxonHandlerFacet access test
    function testAccessAxonReceiverCeler(address caller) public {
        // caller - random address which is not hyperlane inbox
        vm.assume(caller!=address(0x0) && caller!=address(chain2Bus));
        //constructing a valid msg
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(usdcgW),data:abi.encodeWithSelector(approveSelector,mockLp,100e18)});
        bytes memory message = abi.encode(MOCK_ADDR_1,address(usdc),100e18,calls);
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
        vm.expectRevert(InvalidNexus.selector);
        AxonHandlerFacet(address(axonNexus)).executeMessage(MOCK_ADDR_5,1,messageWithAction,dummyExecuter);
        vm.stopPrank();

    }

    //testing hyperlane facet security
    function testAccessCelerFacet(address caller) public {
        vm.assume(caller!=address(0x0) && caller!=address(gwNexus));

        //attempting to call hyperlane facet directly
        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(usdcgW),data:abi.encodeWithSelector(approveSelector,mockLp,100e18)});
        vm.startPrank(caller);
        vm.expectRevert(InvalidRouter.selector);
        IBridgeFacet(address(gwNexus)).bridgeTokenAndCall(
            LibAppStorage.TokenBridgeAction.Deposit,
            caller,
            address(usdc),
            100e18,
            calls
        );
        vm.stopPrank();
    }

    //testing
    //inter-chain account call test , tokens should be minted to ICA
    function testICACreationAndCallCeler(uint256 amountToDeposit,uint256 countToIncrease) public {
        address user = MOCK_ADDR_1;


        // dummy contract for ica call - call to this contract is only possible through `userKhalaAccount` - this will test if the call is going correctly from ICA proxy
        address userKhalaAccount = 0xe5c852452A9c70B939f2EA797DC384E0B0C845F7;
        MockCounter counter = new MockCounter(userKhalaAccount);

        Call[] memory calls = new Call[](1);
        calls[0] = Call({to:address(counter),data:abi.encodeWithSelector(counter.increaseCount.selector,countToIncrease)});

        usdc.mint(MOCK_ADDR_1,amountToDeposit);
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(gwNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, calls);
        CrossChainRouter(address(gwNexus)).depositTokenAndCall(address(usdc),amountToDeposit,calls);
        vm.stopPrank();
        chain2Bus.processNextPendingMsg();
        assertEq(IERC20(usdcgW).balanceOf(userKhalaAccount),amountToDeposit);
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
        Call[] memory calls =  new Call[](2);
        calls[0] = Call({to:address(usdcgW),data:abi.encodeWithSelector(approveSelector,mockLp,amountToDeposit)});
        calls[1] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity.selector,address(usdcgW),amountToDeposit)});
        vm.startPrank(user);
        usdc.approve(address(gwNexus),amountToDeposit);
        vm.expectEmit(true, true, true , true,address(gwNexus));
        emit LogDepositAndCall(address(usdc), user, amountToDeposit, calls);
        CrossChainRouter(address(gwNexus)).depositTokenAndCall(address(usdc),amountToDeposit,calls);
        vm.stopPrank();
        chain2Bus.processNextPendingMsg();
        chain1Bus.processNextPendingMsg();
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
        usdc.mint(user,amount1);
        usdt.mint(user,amount2);
        Call[] memory calls = new Call[](3);
        calls[0] = Call({to:address(usdcgW),data:abi.encodeWithSelector(approveSelector,mockLp,amount1)});
        calls[1] = Call({to:address(usdtgW),data:abi.encodeWithSelector(approveSelector,mockLp,amount2)});
        calls[2] = Call({to:address(mockLp),data:abi.encodeWithSelector(mockLp.addLiquidity2.selector,[address(usdcgW),address(usdtgW)],[amount1,amount2])});
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
        emit LogDepositMultiTokenAndCall(tokens,user,amounts,calls);
        CrossChainRouter(address(gwNexus)).depositMultiTokenAndCall(tokens,amounts,calls);
        vm.stopPrank();
        chain2Bus.processNextPendingMsg();
        chain1Bus.processNextPendingMsg();
        assertEq(usdc.balanceOf(user),amount1);
        assertEq(usdt.balanceOf(user),amount2);
    }
}