pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "./utils/LibDiamondDeployer.sol";
import "../src/InterchainMessaging/adapters/HyperlaneAdapter.sol";
import "../src/Tokens/ERC20MintableBurnable.sol";
import "../src/LiquidityReserves/remote/AssetReserves.sol";
import "@hyperlane-xyz/core/contracts/mock/MockMailbox.sol";
import "@hyperlane-xyz/core/contracts/test/TestMultisigIsm.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/LiquidityReserves/khalani/LiquidityProjector.sol";
import "./Mock/MockLiquidityAggregator.sol";
import "./Mock/MockKhalaniReceiver.sol";
import "./Mock/MockVortex.sol";


contract BridgeFacetTest is Test {
    // chain id : 1 (remote)
    address interChainGateway1;
    address hyperlaneAdapter1;
    address assetReserves;
    address mailbox1;
    // tokens on remote chain
    address usdc;
    address kai;

    // chain id : 2 (khalani)
    address interChainGateway2;
    address mailbox2;
    address hyperlaneAdapter2;
    address liquidityProjector;
    address liquidityAggregator;
    address interchainLiquidityHub;
    // mirror token ans kai on khalani chain
    address usdcMirror;
    address kaiKhalani;
    // klnUsdc on khalani chain (Khalani USDC)
    address klnUsdc;

    function setUp() public {
        interChainGateway1 = LibDiamondDeployer.deployDiamond();
        LibDiamondDeployer.addRemoteChainFacets(interChainGateway1);

        interChainGateway2 = LibDiamondDeployer.deployDiamond();
        LibDiamondDeployer.addKhalaniFacets(interChainGateway2);

        (mailbox1, hyperlaneAdapter1) = deployHyperlaneAdapter(1, interChainGateway1);
        (mailbox2, hyperlaneAdapter2) = deployHyperlaneAdapter(2, interChainGateway2);
        registerRemoteAdapter();

        deployAssets();
        deployAssetReserves();
        deployLiquidityProjector();

        deployLiquidityAggregator();

        initialiseRemoteDiamond();
        initialiseKhalaniDiamond();
    }

    //------------------------TESTS------------------------//
    function test_RemoteToKhalani(uint256 amount) public {
        //mint both kai and usdc on remote chain to users
        address user = getUserWithTokens(amount);
        // deposit kai assetProjector
        IERC20MintableBurnable(kaiKhalani).mint(liquidityProjector, amount);

        //prepare request parameters for send function
        uint256 destination = 2;
        Token[] memory tokens = new Token[](2);
        tokens[0] = Token(kai, amount);
        tokens[1] = Token(usdc, amount);

        // add even check
        assertEq(ERC20(usdc).balanceOf(user), amount); // assert user's usdc balance
        assertEq(ERC20(kai).balanceOf(user), amount); // assert user's kai balance
        assertEq(ERC20(kai).totalSupply(), amount); // assert total supply of kai
        assertEq(ERC20(usdc).balanceOf(assetReserves), 0); // assert assetReserves usdc balance

        vm.prank(user);
        vm.expectEmit(interChainGateway1);
        emit RemoteBridgeRequest(user, destination, tokens, user);
        RemoteBridgeFacet(interChainGateway1).send(destination, tokens, "", user, "");

        assertEq(ERC20(usdc).balanceOf(user), 0); // assert user's usdc balance
        assertEq(ERC20(kai).balanceOf(user), 0); // assert user's kai balance
        assertEq(ERC20(usdc).balanceOf(assetReserves), amount); // assert assetReserves usdc balance
        assertEq(ERC20(kai).totalSupply(), 0); // assert total supply of kai

        // process hyperlane cross-chain relay
        vm.chainId(destination);
        MockMailbox(mailbox2).processNextInboundMessage();

        assertEq(ERC20(klnUsdc).balanceOf(user), amount); // assert user's usdc balance on Khalani chain
        assertEq(ERC20(kaiKhalani).balanceOf(user), amount); // assert user's kai balance on khalani chain
        assertEq(ERC20(usdcMirror).balanceOf(liquidityAggregator), amount); // assert liquidity aggregator's usdc balance
        assertEq(ERC20(kaiKhalani).totalSupply(), amount); // assert total supply of kaiKhalani
        assertEq(ERC20(usdcMirror).totalSupply(), amount); // assert total supply of usdcMirror
        assertEq(ERC20(klnUsdc).totalSupply(), amount); // assert total supply of klnUsdc
    }

    function test_remoteToKhalani_withTargetContract(uint256 amount) public{
        //mint both kai and usdc on remote chain to users
        address user = getUserWithTokens(amount);
        // deposit kai assetProjector
        IERC20MintableBurnable(kaiKhalani).mint(liquidityProjector, amount);
        //deploy a target contract with IMessageReceiver interface
        address target = address(new MockKhalaniReceiver());
        bytes memory message = abi.encode("hello world");

        //prepare request parameters for send function
        uint256 destination = 2;
        Token[] memory tokens = new Token[](2);
        tokens[0] = Token(kai, amount);
        tokens[1] = Token(usdc, amount);

        // add even check
        assertEq(ERC20(usdc).balanceOf(user), amount); // assert user's usdc balance
        assertEq(ERC20(kai).balanceOf(user), amount); // assert user's kai balance
        assertEq(ERC20(kai).totalSupply(), amount); // assert total supply of kai
        assertEq(ERC20(usdc).balanceOf(assetReserves), 0); // assert assetReserves usdc balance

        vm.prank(user);
        vm.expectEmit(interChainGateway1);
        emit RemoteBridgeRequest(user, destination, tokens, target);
        RemoteBridgeFacet(interChainGateway1).send(destination, tokens, "", target, message);

        assertEq(ERC20(usdc).balanceOf(user), 0); // assert user's usdc balance
        assertEq(ERC20(kai).balanceOf(user), 0); // assert user's kai balance
        assertEq(ERC20(usdc).balanceOf(assetReserves), amount); // assert assetReserves usdc balance
        assertEq(ERC20(kai).totalSupply(), 0); // assert total supply of kai

        // process hyperlane cross-chain relay
        vm.chainId(destination);
        vm.expectEmit(interChainGateway2);
        emit MessageProcessed(1, user, tokens, 2, target);
        MockMailbox(mailbox2).processNextInboundMessage();

        assertEq(ERC20(klnUsdc).balanceOf(target), amount); // assert user's usdc balance on Khalani chain
        assertEq(ERC20(kaiKhalani).balanceOf(target), amount); // assert user's kai balance on khalani chain
        assertEq(ERC20(usdcMirror).balanceOf(liquidityAggregator), amount); // assert liquidity aggregator's usdc balance
        assertEq(ERC20(kaiKhalani).totalSupply(), amount); // assert total supply of kaiKhalani
        assertEq(ERC20(usdcMirror).totalSupply(), amount); // assert total supply of usdcMirror
        assertEq(ERC20(klnUsdc).totalSupply(), amount); // assert total supply of klnUsdc
    }

    function test_remoteToKhalani_withVortex(uint256 amount, uint256 value) public {
        //mint both kai and usdc on remote chain to users
        address user = getUserWithTokens(amount);
        // deposit kai assetProjector
        IERC20MintableBurnable(kaiKhalani).mint(liquidityProjector, amount);
        //deploy a interchainLiquidityHub (mock counter contract) contract
        bytes memory interchainLiquidityHubPayload = abi.encodeWithSelector(MockVortex.increaseCount.selector, value);

        uint256 destination = 3;
        Token[] memory tokens = new Token[](2);
        tokens[0] = Token(kai, amount);
        tokens[1] = Token(usdc, amount);

        assertEq(ERC20(usdc).balanceOf(user), amount); // assert user's usdc balance
        assertEq(ERC20(kai).balanceOf(user), amount); // assert user's kai balance
        assertEq(ERC20(kai).totalSupply(), amount); // assert total supply of kai
        assertEq(ERC20(usdc).balanceOf(assetReserves), 0); // assert assetReserves usdc balance

        vm.prank(user);
        vm.expectEmit(interChainGateway1);
        emit RemoteBridgeRequest(user, destination, tokens, user);
        RemoteBridgeFacet(interChainGateway1).send(destination, tokens, interchainLiquidityHubPayload, user, "");

        assertEq(ERC20(usdcMirror).allowance(interChainGateway2,interchainLiquidityHub), 0); // assert user's usdc balance
        assertEq(ERC20(kaiKhalani).allowance(interChainGateway2,interchainLiquidityHub), 0); // assert user's kai balance
        assertEq(MockVortex(interchainLiquidityHub).count(), 0); //check interchainLiquidityHub count

        // process hyperlane cross-chain relay
        vm.chainId(2);
        emit MessageProcessed(1, user, tokens, 3, address(0x0));
        MockMailbox(mailbox2).processNextInboundMessage();

        assertEq(ERC20(usdcMirror).allowance(interChainGateway2,interchainLiquidityHub), amount); //check allowance for interchainLiquidityHub for usdcMirror
        assertEq(ERC20(kaiKhalani).allowance(interChainGateway2,interchainLiquidityHub), amount); //check allowance for interchainLiquidityHub for kaiKhalani
        assertEq(MockVortex(interchainLiquidityHub).count(), value); //check interchainLiquidityHub count

    }

    //------------------------SETUP HELPERS------------------------//
    function deployInterchainGatewayRemote() private {
        interChainGateway1 = LibDiamondDeployer.deployDiamond();
        LibDiamondDeployer.addRemoteChainFacets(interChainGateway1);
    }

    function deployInterchainGatewayKhalani() private {
        interChainGateway2 = LibDiamondDeployer.deployDiamond();
        LibDiamondDeployer.addKhalaniFacets(interChainGateway2);
    }

    function deployHyperlaneAdapter(uint256 chainId, address interChainGateway) private  returns (address , address){
        MockMailbox mailbox = new MockMailbox(uint32(chainId));
        address ism = address(new TestMultisigIsm());
        HyperlaneAdapter adapter = new HyperlaneAdapter(address(mailbox), ism, interChainGateway);
        return (address(mailbox),address (adapter));
    }

    function registerRemoteAdapter() private {
        MockMailbox(mailbox1).addRemoteMailbox(2, MockMailbox(mailbox2));
        MockMailbox(mailbox2).addRemoteMailbox(1, MockMailbox(mailbox1));
    }

    function deployAssets() private {
        usdc = address(new ERC20("USDC", "USDC"));
        kai = address(new ERC20MintableBurnable("KAI", "KAI"));
        usdcMirror = address (new ERC20MintableBurnable("USDC1", "USDC1"));
        kaiKhalani = address (new ERC20MintableBurnable("KAI", "KAI"));
        klnUsdc = address (new ERC20MintableBurnable("KLNUSDC", "KLNUSDC"));
    }

    function deployAssetReserves() private {
        assetReserves = address(new AssetReserves(interChainGateway1, kai));
        AssetReserves(assetReserves).addWhiteListedAsset(usdc);
        ERC20MintableBurnable(kai).addMinterRole(assetReserves);
    }

    function deployLiquidityProjector() private {
        liquidityProjector = address(new LiquidityProjector(interChainGateway2, kaiKhalani));
        LiquidityProjector(liquidityProjector).setMirrorToken(1, usdc, usdcMirror);
        LiquidityProjector(liquidityProjector).setMirrorToken(1, kai, kaiKhalani);
        ERC20MintableBurnable(usdcMirror).addMinterRole(liquidityProjector);
        ERC20MintableBurnable(kaiKhalani).addMinterRole(liquidityProjector);
    }

    function deployLiquidityAggregator() private {
        liquidityAggregator = address(new MockLiquidityAggregator(klnUsdc));
        ERC20MintableBurnable(klnUsdc).addMinterRole(liquidityAggregator);
        interchainLiquidityHub = address(new MockVortex());
    }

    function initialiseRemoteDiamond() private {
        RemoteSetter(interChainGateway1).initialize(
            assetReserves,
            hyperlaneAdapter2,
            2,
            hyperlaneAdapter1
        );
    }

    function initialiseKhalaniDiamond() private {
        KhalaniSetter(interChainGateway2).
            initializeRemoteRequestProcessor(
                hyperlaneAdapter2,
                liquidityProjector,
                interchainLiquidityHub,
                liquidityAggregator
            );

        KhalaniSetter(interChainGateway2).
            registerRemoteAdapter(
                1,
                hyperlaneAdapter1
        );
    }

    function getUserWithTokens(uint256 amount) internal returns (address) {
        address user = vm.addr(1);
        IERC20MintableBurnable(kai).mint(user, amount);
        deal(usdc, user, amount);

        vm.startPrank(user);
        IERC20(kai).approve(assetReserves, amount);
        IERC20(usdc).approve(assetReserves, amount);
        vm.stopPrank();

        return user;
    }

    event RemoteBridgeRequest(
        address indexed sender,
        uint256 indexed destinationChainId,
        Token[] approvedTokens,
        address target
    );

    event BridgeRequest(
        address indexed sender,
        uint256 indexed destinationChainId,
        Token[] approvedTokens,
        address target
    );

    event MessageProcessed(
        uint256 indexed origin,
        address indexed sender,
        Token[] tokens,
        uint destination,
        address target
    );

}