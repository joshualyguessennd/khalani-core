pragma solidity >=0.4.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Nexus.sol";
import "../src/Gateway.sol";
import "../src/balancer/vault/interfaces/IVault.sol";
import "../src/balancer/vault/interfaces/IBasePool.sol";
import "../src/balancer/vault/interfaces/IERC20.sol";
import "../src/balancer/vault/interfaces/IAuthorizer.sol";

import "../src/balancer/vault/interfaces/StablePoolUserData.sol";
import "./utils/Utilities.sol";
import "../src/balancer/vault/VaultAuthorization.sol";
import "../src/balancer/vault/Vault.sol";

// import "./balancer/vault/interfaces/IVault.sol";

contract NexusTest is Test {
    // IVault public vault;
    Nexus public nexus;
    Gateway public gateway;
    address public USDC_AVAX_CONTRACT_ADDRESS;
    address public USDC_ETH_CONTRACT_ADDRESS;
    address public OMNI_USD_USDC_ETH_POOL_ADDRESS;
    address public OMNI_USD_USDC_AVAX_POOL_ADDRESS;
    bytes32 public poolId;
    address public OmniUSD = 0x354D40DBa2A50D7AEb75228a2BbaE858Ede40FD7;
    address public USDCavax = 0x6c974538ac82bF2cbA2F2161A554CbC30847Deba;
    address public USDCeth = 0x68F31b0D47Dde4680AD9680964407933B02dBBc1;
    address public OmniUSDCeth = 0x38bC74F447dfaa039AEa6A4c4D9F81f6Bb13921c;
    address public OmniUSDCavax = 0xB955b6c65Ff69bfe07A557aa385055282b8a5eA3;
    address public alice;
    address public vault = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e;
    address public delegate = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    // address public vault;
    address public vaultAuthorisation;
    IAuthorizer public authorizer;
    IAsset[] public assets = new IAsset[](2);

    Utilities internal utils;

    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT
    }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT
    }

    function setUp() public {
        utils = new Utilities();
        // vaultAuthorisation = new VaultAuthorization(msg.sender);
        // vault = new Vault();
        nexus = new Nexus(vault);
        address payable[] memory users = utils.createUsers(1);
        alice = users[0];
        vm.label(alice, "Alice");
        deal(OmniUSD, alice, 10000e18);
        deal(USDCavax, alice, 10000e18);
        deal(OmniUSD, address(this), 10000e18);
        deal(USDCavax, address(this), 10000e18);
        // vm.deal(null, null);
        // poolId =
        // gateway = new Gateway();
    }

    function test_shouldDepositLiqudityAndMintUSDCavax() public {
        bytes32 poolIDOmniUSDCavax = IBasePool(OmniUSDCavax).getPoolId();
        console2.log(uint256(poolIDOmniUSDCavax));
        // bytes32 poolIDOmniUSDCavax = IVault(vault).getPoolId();

        IVault.JoinPoolRequest memory request;
        // request  = IVault.JoinPoolRequest([IAsset(OmniUSD), IAsset(USDCavax)],[100, 100] ,abi.encode([100, 100]), false);
        // vm.startPrank(alice);
        // IERC20(OmniUSD).mint();

        uint256[] memory maxAmountsIn = new uint256[](2);
        assets[0] = IAsset(OmniUSD);
        assets[1] = IAsset(USDCavax);

        maxAmountsIn[0] = 10e18;
        maxAmountsIn[1] = 10e18;
        request.maxAmountsIn = maxAmountsIn;
        request.userData = abi.encode(JoinKind.INIT, 100);
        request.assets = assets;
        request.fromInternalBalance = false;
        vm.startPrank(alice);
        IERC20(OmniUSD).approve(vault, 100e18);
        IERC20(USDCavax).approve(vault, 100e6);
        // Approve this contract as a relayer
        IVault(vault).setRelayerApproval(alice, address(this), true);
        // vm.prank(alice, alice);
        console.log("msg.sender", msg.sender);
        console.log("tx.origin", tx.origin);
        console.log("alice", alice);

        (address poolAddress, ) = IVault(vault).getPool(poolIDOmniUSDCavax);
        console.log(poolAddress);

        (IERC20[] memory _tokens, , ) = IVault(vault).getPoolTokens(
            poolIDOmniUSDCavax
        );

        console.log(address(_tokens[0]), address(_tokens[1]));
        IVault(vault).joinPool(poolIDOmniUSDCavax, alice, address(2), request);
        // /  // nexus.joinPool(poolIDOmniUSDCavax, msg.sender, msg.sender, request);
    }

    function test_shouldDepositLiqudityAndMintUSDCeth() public {
        // gateway.deposit();
    }

    function test_shouldWithDrawLiqudityAndBurnUSDCavax() public {
        // gateway.withdraw(x);
    }

    function test_shouldWithDrawLiqudityAndBurnUSDCeth() public {
        // gateway.withdraw(x);
    }
}
