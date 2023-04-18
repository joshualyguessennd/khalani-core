pragma solidity ^0.8.0;

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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/Nexus/Errors.sol";
import "../src/Nexus/Call.sol";
import "../src/Nexus/facets/factory/TokenRegistry.sol";
import "./lib/Create2Lib.sol";
import "forge-std/console.sol";
import "@hyperlane-xyz/core/contracts/Mailbox.sol";
import "../src/Vortex/Vortex.sol";
import {IBalancerPool} from "../src/Vortex/BalancerTypes.sol";
import {Kai} from "../src/KaiToken.sol";
import "./Mock/MockERC20Decimal.sol";
// mocking mailbox contracts in tests as relayer is involved
// making use of foundry's persistent contracts
contract NexusVortexTests is Test{

    //Eth
    address ethNexus;
    address usdcE;
    address kaiOnEth;
    MockMailbox mailboxEth;

    //Avax
    address avaxNexus;
    address usdcA;
    address kaiOnAvax;
    MockMailbox mailboxAvax;

    //Axon
    address axonNexus;
    address usdcEth = vm.envAddress("USDC_ETH_MIRROR");
    address usdcAvax = vm.envAddress("USDC_AVAX_MIRROR");
    address kaiOnAxon = vm.envAddress("AXON_TEST_KAI");
    MockMailbox mailboxAxon;
    address usdcEthKaiBptAddr = vm.envAddress("AXON_USDCETH_KAI_BPT");
    address usdcAvaxKaiBptAddr = vm.envAddress("AXON_USDCAVAX_KAI_BPT");
    bytes4 approveSelector = IERC20.approve.selector;
    //Original token deployer
    address tokenAdmin = vm.envAddress("TOKEN_ADMIN");
    Vortex vortex;

    //Forks
    uint eth;
    uint axon;
    uint avax;

    address MOCK_ADDR_CELER_BUS = 0x0000000000000000000000000000000000000005;

    bytes32 usdcEthKaiPoolId;
    address usdcEthKaiBalancerVault;

    bytes32 usdcAvaxKaiPoolId;
    address usdcAvaxKaiBalancerVault;

    address user1 = 0x0000000000000000000000000000000000000001;
    address MOCK_ISM    = 0x0000000000000000000000000000000000000006;

    event CrossChainMsgReceived(
        uint indexed msgOriginChain,
        bytes32 indexed sender,
        bytes message
    );

    function deployDiamond() internal returns (address) {
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
        return address(diamond);
    }

    function setUp() public {
        eth  = vm.createFork(vm.envString("GOERLI_INFURA_URL"));
        avax = vm.createFork(vm.envString("FUJI_INFURA_URL"));
        axon = vm.createFork(vm.envString("AXON_RPC_URL"));

        vm.selectFork(eth);
        ethNexus = deployDiamond();
        mailboxEth = new MockMailbox(5);
        vm.makePersistent(address (mailboxEth));
        //make facet cuts to nexus diamond on ethereum
        makeSourceChainFacetCut(ethNexus);

        vm.selectFork(avax);
        avaxNexus = deployDiamond();
        mailboxAvax = new MockMailbox(43113);
        vm.makePersistent(address (mailboxAvax));
        //make facet cuts to nexus diamonds in avax
        makeSourceChainFacetCut(avaxNexus);

        vm.selectFork(axon);

        usdcEthKaiPoolId = IBalancerPool(usdcEthKaiBptAddr).getPoolId();
        usdcEthKaiBalancerVault = IBalancerPool(usdcEthKaiBptAddr).getVault();

        usdcAvaxKaiPoolId = IBalancerPool(usdcAvaxKaiBptAddr).getPoolId();
        usdcAvaxKaiBalancerVault = IBalancerPool(usdcAvaxKaiBptAddr).getVault();

        axonNexus = deployDiamond();
        mailboxAxon = new MockMailbox(10012);
        vm.makePersistent(address(mailboxAxon));
        //make facet cuts to nexus diamond on axon
        makeAxonFacetCut(axonNexus);

        vm.selectFork(eth);
        mailboxEth.addRemoteMailbox(10012,mailboxAxon);
        CrossChainRouter(ethNexus).initializeNexus(kaiOnEth,axonNexus,10012);
        HyperlaneFacet(ethNexus).initHyperlaneFacet(address(mailboxEth),MOCK_ISM);

        vm.selectFork(avax);
        mailboxAvax.addRemoteMailbox(10012,mailboxAxon);
        CrossChainRouter(avaxNexus).initializeNexus(kaiOnAvax,axonNexus,10012);
        HyperlaneFacet(avaxNexus).initHyperlaneFacet(address(mailboxAvax),MOCK_ISM);

        vm.selectFork(axon);
        mailboxAxon.addRemoteMailbox(5,mailboxEth);
        mailboxAxon.addRemoteMailbox(43113,mailboxAvax);
        AxonMultiBridgeFacet(axonNexus).initMultiBridgeFacet(MOCK_ADDR_CELER_BUS, address(mailboxAxon), 3);
        AxonMultiBridgeFacet(axonNexus).addChainInbox(5,ethNexus);
        AxonMultiBridgeFacet(axonNexus).addChainInbox(43113,avaxNexus);
        AxonHandlerFacet(axonNexus).addValidNexusForChain(5,TypeCasts.addressToBytes32(address(ethNexus)));
        AxonHandlerFacet(axonNexus).addValidNexusForChain(43113,TypeCasts.addressToBytes32(address(axonNexus)));
        //deploy Vortex
        _vortexSetup();
        //token registry setup
        _registerTokens();
    }

    function _registerTokens() internal {
        vm.selectFork(eth);
        usdcE = address(new MockERC20Decimal("USDC","USDC"));
        MockERC20Decimal(usdcE).setDecimal(6);
        kaiOnEth = address(new MockERC20Decimal("Kai/Eth","KaiOnEth"));
        MockERC20Decimal(kaiOnEth).setDecimal(18);

        vm.selectFork(avax);
        usdcA = address(new MockERC20Decimal("USDCA","USDCA"));
        MockERC20Decimal(usdcA).setDecimal(6);
        kaiOnAvax = address(new MockERC20Decimal("Kai/Avax","Kai/Avax"));
        MockERC20Decimal(kaiOnAvax).setDecimal(18);

        vm.selectFork(axon);
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

        StableTokenRegistry(axonNexus).initTokenFactory(kaiOnAxon);
        StableTokenRegistry(axonNexus).registerKai(5,kaiOnEth);
        StableTokenRegistry(axonNexus).registerKai(43113,kaiOnAvax);
        StableTokenRegistry(axonNexus).registerMirrorToken(5, usdcE, usdcEth);
        StableTokenRegistry(axonNexus).registerMirrorToken(5, usdcA, usdcAvax);

        vm.startPrank(tokenAdmin);
        USDMirror(usdcEth).transferMinterBurnerRole(axonNexus); //transferOwnership
        USDMirror(usdcAvax).transferMinterBurnerRole(axonNexus);
        USDMirror(kaiOnAxon).transferMinterBurnerRole(axonNexus);
        vm.stopPrank();

        vm.selectFork(eth);
        MsgHandlerFacet(ethNexus).addChainTokenForMirrorToken(kaiOnEth,kaiOnAxon);
        MsgHandlerFacet(ethNexus).addChainTokenForMirrorToken(usdcE,usdcEth);

        vm.selectFork(avax);
        MsgHandlerFacet(avaxNexus).addChainTokenForMirrorToken(kaiOnAvax,kaiOnAxon);
        MsgHandlerFacet(avaxNexus).addChainTokenForMirrorToken(usdcA,usdcAvax);

        vm.selectFork(eth);
        IERC20Mintable(usdcE).mint(ethNexus, 15e20);
        IERC20Mintable(kaiOnEth).mint(ethNexus,15e20);

        vm.selectFork(avax);
        IERC20Mintable(usdcA).mint(avaxNexus, 15e20);
        IERC20Mintable(kaiOnAvax).mint(avaxNexus,15e20);
    }

    function _vortexSetup() internal {
        vortex = new Vortex(axonNexus,kaiOnAxon);
        vortex.addWhiteListedAsset(usdcEth,usdcEthKaiBptAddr);
        vortex.addWhiteListedAsset(usdcAvax,usdcAvaxKaiBptAddr);
        vm.startPrank(tokenAdmin);
        Kai(kaiOnAxon).transferMinterBurnerRole(address(vortex));
        vm.stopPrank();
    }

    //--------- fork test start here -----------//
    function testAddLiquidityVortex(uint amount) public { //balanced
        //pool size : 150000000000 usdc.eth,kai | usdc.avax,kai ie 150000e6
        amount = bound(amount,1e6, 1e16);
        vm.selectFork(eth);
        address userICA = Create2Lib.computeAddress(user1, axonNexus);
        IERC20Mintable(usdcE).mint(user1,amount);

        Call[] memory calls = new Call[](2);
        calls[0] = Call({to : usdcEth, data : abi.encodeWithSelector(IERC20.approve.selector,address(vortex),amount)});

        //preparation for calls[1] i.e batchSwap call to balancer vault

        //queryBatchSwap
        vm.selectFork(axon);

        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] = BatchSwapStep(
        {
        poolId : usdcEthKaiPoolId,
        assetInIndex : 0,
        assetOutIndex : 1,
        amount : amount,
        userData : abi.encode("")
        }
        );

        swaps[1] = BatchSwapStep(
        {
        poolId : usdcEthKaiPoolId,
        assetInIndex : 2,
        assetOutIndex : 1,
        amount : amount* 1e18 / 1e6,
        userData : abi.encode("")
        }
        );

        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(usdcEth);
        assets[1] = IAsset(usdcEthKaiBptAddr);
        assets[2] = IAsset(kaiOnAxon);

        FundManagement memory funds;
        funds.sender = userICA;
        funds.fromInternalBalance = false;
        funds.recipient = payable(userICA);
        funds.toInternalBalance = false;

        int256[] memory assetDeltas = IVault(usdcEthKaiBalancerVault).queryBatchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds
        );
        emit log_named_int("BPT out from queryBatchSwap - ", assetDeltas[2]);

        uint expectedBpt = uint(assetDeltas[1] * -1);
        //limits with 1% slippage tolerange
        assetDeltas[1] = (assetDeltas[1]*99)/100;

        emit log_named_int("limits[2] - ", assetDeltas[1]);

        vm.selectFork(eth);

        calls[1] = Call({
            to : address(vortex),
            data : abi.encodeWithSelector(
                    IVortex.addLiquidityVortex.selector,
                    usdcEth,
                    amount,
                    assetDeltas[1]
                )
            }
        );

        vm.startPrank(user1);
        IERC20(usdcE).approve(ethNexus,amount);
        CrossChainRouter(ethNexus).depositTokenAndCall(usdcE, amount, calls);
        vm.stopPrank();

        vm.selectFork(axon);

        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(5, TypeCasts.addressToBytes32(ethNexus), abi.encode(""));
        mailboxAxon.processNextPendingMessage();

        assertEq(
            expectedBpt/2, IERC20(usdcEthKaiBptAddr).balanceOf(userICA),
            "BPT balance is not around the expected value"
        );

        emit log_named_int("BPT balance userICA - ",int(IERC20(usdcEthKaiBptAddr).balanceOf(userICA)));
    }

    function testWithdrawLiquidityVortex(uint amount) public {
        //pool size : 150000000000, 150000000000000000000000 usdc.eth,kai | usdc.avax,kai
        amount = bound(amount,1e6, 1e16);
        vm.selectFork(eth);
        address userICA = Create2Lib.computeAddress(user1, axonNexus);
        IERC20Mintable(usdcE).mint(user1,amount);

        Call[] memory calls = new Call[](2);
        calls[0] = Call({to : usdcEth, data : abi.encodeWithSelector(IERC20.approve.selector,address(vortex),amount)});

        //preparation for calls[1] i.e batchSwap call to balancer vault

        //queryBatchSwap
        vm.selectFork(axon);

        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] = BatchSwapStep(
        {
        poolId : usdcEthKaiPoolId,
        assetInIndex : 0,
        assetOutIndex : 1,
        amount : amount,
        userData : abi.encode("")
        }
        );

        swaps[1] = BatchSwapStep(
        {
        poolId : usdcEthKaiPoolId,
        assetInIndex : 2,
        assetOutIndex : 1,
        amount : amount* 1e18 / 1e6,
        userData : abi.encode("")
        }
        );

        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(usdcEth);
        assets[1] = IAsset(usdcEthKaiBptAddr);
        assets[2] = IAsset(kaiOnAxon);

        FundManagement memory funds;
        funds.sender = userICA;
        funds.fromInternalBalance = false;
        funds.recipient = payable(userICA);
        funds.toInternalBalance = false;

        int256[] memory assetDeltas = IVault(usdcEthKaiBalancerVault).queryBatchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds
        );
        emit log_named_int("BPT out from queryBatchSwap - ", assetDeltas[2]);

        uint expectedBpt = uint(assetDeltas[1] * -1);
        //limits with 1% slippage tolerange
        assetDeltas[1] = (assetDeltas[1]*99)/100;

        emit log_named_int("limits[2] - ", assetDeltas[1]);

        vm.selectFork(eth);

        calls[1] = Call({
        to : address(vortex),
        data : abi.encodeWithSelector(
                IVortex.addLiquidityVortex.selector,
                usdcEth,
                amount,
                assetDeltas[1]
            )
        }
        );

        vm.startPrank(user1);
        IERC20(usdcE).approve(ethNexus,amount);
        CrossChainRouter(ethNexus).depositTokenAndCall(usdcE, amount, calls);
        vm.stopPrank();

        vm.selectFork(axon);

        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(5, TypeCasts.addressToBytes32(ethNexus), abi.encode(""));
        mailboxAxon.processNextPendingMessage();

        assertEq(
            expectedBpt/2, IERC20(usdcEthKaiBptAddr).balanceOf(userICA),
            "BPT balance is not around the expected value"
        );

        emit log_named_int("BPT balance userICA - ",int(IERC20(usdcEthKaiBptAddr).balanceOf(userICA)));

        //attempt to withdraw completely
        uint bptAmountIn =  IERC20(usdcEthKaiBptAddr).balanceOf(userICA);

        swaps[0] = BatchSwapStep({
            poolId : usdcEthKaiPoolId,
            assetInIndex : 1,
            assetOutIndex : 0,
            amount : bptAmountIn,
            userData : abi.encode("")
        });

        swaps[1] = BatchSwapStep({
            poolId : usdcEthKaiPoolId,
            assetInIndex : 1,
            assetOutIndex : 2,
            amount : bptAmountIn,
            userData : abi.encode("")
        });

        assetDeltas = IVault(usdcEthKaiBalancerVault).queryBatchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds
        );

        emit log_named_int("Token 1 out from queryBatchSwap - ", assetDeltas[0]);
        emit log_named_int("Token 2 out from queryBatchSwap - ", assetDeltas[2]);

        calls = new Call[](3);
        calls[0] = Call(
            {
                to : usdcEthKaiBptAddr,
                data : abi.encodeWithSelector(IERC20.approve.selector, address(vortex), IERC20(usdcEthKaiBptAddr).balanceOf(userICA))
            // approval for complete withdrawal
            }
        );

        uint expectedUsdcEth = uint(assetDeltas[0] * -1);
        calls[1] = Call(
            {
                to : address(vortex),
                data : abi.encodeWithSelector(
                    IVortex.withdrawLiquidityVortex.selector,
                    usdcEth,
                    bptAmountIn,
                    expectedUsdcEth*99/100 //1% slippage
                )
            }
        );

        Call[] memory emptyCall;

        calls[2] = Call({
            to : axonNexus,
            data : abi.encodeWithSelector(
                AxonCrossChainRouter.withdrawTokenAndCall.selector,
                5,
                usdcEth,
                expectedUsdcEth,
                KhalaInterChainAccount(userICA).eoa(),
                emptyCall
            )
        });

        vm.prank(user1);
        KhalaInterChainAccount(userICA).sendProxyCall(address(0x0),0,0,calls);

        vm.selectFork(eth);
        mailboxEth.processNextPendingMessage();

        assertEq(
            IERC20(usdcE).balanceOf(user1),
            expectedUsdcEth,
            "Token1 balance is not around the expected value of withdrawal"
        );
    }

    function testRefundOnAddLiquidityFail(uint amount) public { //balanced
        //pool size : 150000000000,150000000000000000000000 -> usdc,kai
        amount = bound(amount,1e6, 1e16);
        vm.selectFork(eth);
        address userICA = Create2Lib.computeAddress(user1, axonNexus);
        IERC20Mintable(usdcE).mint(user1,amount);
        IERC20Mintable(kaiOnEth).mint(user1,amount*1e18/1e6);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount*1e18/1e6;

        Call[] memory calls = new Call[](3);
        //approving with 0 amount so call fails
        calls[0] = Call({to : usdcEth, data : abi.encodeWithSelector(IERC20.approve.selector,usdcEthKaiBalancerVault,0)});
        calls[1] = Call({to : kaiOnAxon, data : abi.encodeWithSelector(IERC20.approve.selector,usdcEthKaiBalancerVault,0)});


        //preparation for calls[2] i.e batchSwap call to balancer vault

        //queryBatchSwap
        vm.selectFork(axon);

        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] = BatchSwapStep(
        {
        poolId : usdcEthKaiPoolId,
        assetInIndex : 0,
        assetOutIndex : 2,
        amount : amounts[0],
        userData : abi.encode("")
        }
        );

        swaps[1] = BatchSwapStep(
        {
        poolId : usdcEthKaiPoolId,
        assetInIndex : 1,
        assetOutIndex : 2,
        amount : amounts[1],
        userData : abi.encode("")
        }
        );

        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(usdcEth);
        assets[1] = IAsset(kaiOnAxon);
        assets[2] = IAsset(usdcEthKaiBptAddr);

        FundManagement memory funds;
        funds.sender = userICA;
        funds.fromInternalBalance = false;
        funds.recipient = payable(userICA);
        funds.toInternalBalance = false;

        int256[] memory assetDeltas = IVault(usdcEthKaiBalancerVault).queryBatchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds
        );

        emit log_named_int("BPT out from queryBatchSwap - ", assetDeltas[2]);
        //limits with 1% slippage tolerange
        assetDeltas[2] = (assetDeltas[2]*99)/100;

        emit log_named_int("limits[2] - ", assetDeltas[2]);

        vm.selectFork(eth);

        calls[2] = Call({
        to : usdcEthKaiBalancerVault,
        data : abi.encodeWithSelector(
                IVault.batchSwap.selector,
                IVault.SwapKind.GIVEN_IN,
                swaps,
                assets,
                funds,
                assetDeltas,
                block.timestamp + 1 hours
            )
        }
        );

        address[] memory tokens = new address[](2);
        tokens[0] = usdcE;
        tokens[1] = kaiOnEth;

        vm.startPrank(user1);
        IERC20(usdcE).approve(ethNexus,amounts[0]);
        IERC20(kaiOnEth).approve(ethNexus,amounts[1]);
        CrossChainRouter(ethNexus).depositMultiTokenAndCall(tokens, amounts, calls);
        vm.stopPrank();

        vm.selectFork(axon);

        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(5, TypeCasts.addressToBytes32(ethNexus), abi.encode(""));
        mailboxAxon.processNextPendingMessage();

        vm.selectFork(eth);
        mailboxEth.processNextPendingMessage();

        assertEq(
            IERC20(usdcE).balanceOf(user1),
            amounts[0]
        );

        assertEq(
            IERC20(kaiOnEth).balanceOf(user1),
            amounts[1]
        );
    }

    function testVortexSwap(uint amount) public{
        amount = bound(amount,100e6,30000e6);

        vm.selectFork(eth);
        address userICA = Create2Lib.computeAddress(user1, axonNexus);
        IERC20Mintable(usdcE).mint(user1,amount);

        Call[] memory calls = new Call[](2);
        calls[0] = Call({to : usdcEth, data : abi.encodeWithSelector(IERC20.approve.selector,usdcEthKaiBalancerVault,amount)});


        //preparation for calls[2] i.e batchSwap call to balancer vault

        //queryBatchSwap
        vm.selectFork(axon);

        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] = BatchSwapStep(
        {
            poolId : usdcEthKaiPoolId,
            assetInIndex : 0,
            assetOutIndex : 1,
            amount : amount,
            userData : abi.encode("")
        }
        );

        swaps[1] = BatchSwapStep(
        {
            poolId : usdcAvaxKaiPoolId,
            assetInIndex : 1,
            assetOutIndex : 2,
            amount : 0,
            userData : abi.encode("")
        }
        );

        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(usdcEth);
        assets[1] = IAsset(kaiOnAxon);
        assets[2] = IAsset(usdcAvax);

        FundManagement memory funds;
        funds.sender = userICA;
        funds.fromInternalBalance = false;
        funds.recipient = payable(userICA);
        funds.toInternalBalance = false;

        int256[] memory assetDeltas = IVault(usdcEthKaiBalancerVault).queryBatchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds
        );

        emit log_named_int("USDC.avax out from queryBatchSwap - ", assetDeltas[2]);

        uint expected = uint(assetDeltas[2] * -1);
        //limits with 1% slippage tolerange
        assetDeltas[2] = (assetDeltas[2]*99)/100;

        emit log_named_int("limits[2] - ", assetDeltas[2]);

        vm.selectFork(eth);

        calls[1] = Call({
        to : usdcEthKaiBalancerVault,
        data : abi.encodeWithSelector(
                IVault.batchSwap.selector,
                IVault.SwapKind.GIVEN_IN,
                swaps,
                assets,
                funds,
                assetDeltas,
                block.timestamp + 1 hours
            )
        }
        );

        vm.startPrank(user1);
        IERC20(usdcE).approve(ethNexus,amount);
        CrossChainRouter(ethNexus).depositTokenAndCall(usdcE, amount, calls);
        vm.stopPrank();

        vm.selectFork(axon);

        vm.expectEmit(true, true, false, false, address(axonNexus));
        emit CrossChainMsgReceived(5, TypeCasts.addressToBytes32(ethNexus), abi.encode(""));
        mailboxAxon.processNextPendingMessage();
        console.log("USDCAvax Balance" , IERC20(usdcAvax).balanceOf(userICA));

        assertEq(
            expected,
            IERC20(usdcAvax).balanceOf(userICA)
        );

        assertApproxEqRel(
            IERC20(usdcAvax).balanceOf(userICA),
            amount,
            2e16
        );

    }

    function testExecuteSwap_Vortex(uint amount) public{
        amount = bound(amount,100e6,30000e6);

        vm.selectFork(eth);
        address userICA = Create2Lib.computeAddress(user1, axonNexus);
        IERC20Mintable(usdcE).mint(user1,amount);

        //preparation for calls[2] i.e batchSwap call to balancer vault

        //queryBatchSwap
        vm.selectFork(axon);
        Call[] memory calls = new Call[](2);
        calls[0] = Call({to : usdcEth, data : abi.encodeWithSelector(IERC20.approve.selector,address(vortex),amount)});

        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] = BatchSwapStep(
        {
        poolId : usdcEthKaiPoolId,
        assetInIndex : 0,
        assetOutIndex : 1,
        amount : amount,
        userData : abi.encode("")
        }
        );

        swaps[1] = BatchSwapStep(
        {
        poolId : usdcAvaxKaiPoolId,
        assetInIndex : 1,
        assetOutIndex : 2,
        amount : 0,
        userData : abi.encode("")
        }
        );

        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(usdcEth);
        assets[1] = IAsset(kaiOnAxon);
        assets[2] = IAsset(usdcAvax);

        FundManagement memory funds;
        funds.sender = userICA;
        funds.fromInternalBalance = false;
        funds.recipient = payable(userICA);
        funds.toInternalBalance = false;

        int256[] memory assetDeltas = IVault(usdcEthKaiBalancerVault).queryBatchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds
        );

        emit log_named_int("USDC.avax out from queryBatchSwap - ", assetDeltas[2]);

        uint expected = uint(assetDeltas[2] * -1);
        //limits with 1% slippage tolerange
        assetDeltas[2] = (assetDeltas[2]*99)/100;

        emit log_named_int("limits[2] - ", assetDeltas[2]);

        vm.selectFork(eth);

        uint [] memory assetWithdrawIndexes = new uint[](1);
        assetWithdrawIndexes[0] = 2;
        calls[1] = Call({
        to : address(vortex),
        data : abi.encodeWithSelector(
                Vortex.executeSwapAndWithdraw.selector,
                usdcEthKaiBalancerVault,
                IVault.SwapKind.GIVEN_IN,
                swaps,
                assets,
                assetDeltas,
                block.timestamp + 1 hours,
                assetWithdrawIndexes
            )
        }
        );

        vm.startPrank(user1);
        IERC20(usdcE).approve(ethNexus,amount);
        CrossChainRouter(ethNexus).depositTokenAndCall(usdcE, amount, calls);
        vm.stopPrank();

        vm.selectFork(axon);

        mailboxAxon.processNextPendingMessage();

        vm.selectFork(avax);
        mailboxAvax.processNextPendingMessage();

        assertEq(
            IERC20(usdcA).balanceOf(user1),
            expected,
            "User did not receive the expected amount on destination chain"
        );

    }

    function makeSourceChainFacetCut(address nexus) internal {
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
        bytes4[] memory hyperlaneFacetfunctionSelectors = new bytes4[](3);
        hyperlaneFacetfunctionSelectors[0] = hyperlaneFacet.bridgeTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[1] = hyperlaneFacet.bridgeMultiTokenAndCall.selector;
        hyperlaneFacetfunctionSelectors[2] = hyperlaneFacet.initHyperlaneFacet.selector;
        cut[1] = IDiamond.FacetCut({
        facetAddress: address(hyperlaneFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: hyperlaneFacetfunctionSelectors
        });

        MsgHandlerFacet msgHandlerFacet = new MsgHandlerFacet(MOCK_ADDR_CELER_BUS);
        bytes4[] memory msgHandlerFacetfunctionSelectors = new bytes4[](3);
        msgHandlerFacetfunctionSelectors[0] = msgHandlerFacet.addChainTokenForMirrorToken.selector;
        msgHandlerFacetfunctionSelectors[1] = msgHandlerFacet.handle.selector;
        cut[2] = IDiamond.FacetCut({
        facetAddress: address(msgHandlerFacet),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: msgHandlerFacetfunctionSelectors
        });

        DiamondCutFacet(nexus).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
    }

    function makeAxonFacetCut(address nexus) internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        AxonHandlerFacet axonhyperlanehandler = new AxonHandlerFacet(MOCK_ADDR_CELER_BUS);
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

        AxonMultiBridgeFacet multiBridgeFacet = new AxonMultiBridgeFacet(MOCK_ADDR_CELER_BUS);
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

        DiamondCutFacet(nexus).diamondCut(
            cut, //array of of cuts
            address(0), //initializer address
            "" //initializer data
        );
    }
}


