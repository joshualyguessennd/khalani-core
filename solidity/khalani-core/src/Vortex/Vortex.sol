pragma solidity ^0.8.0;
import {BatchSwapStep, FundManagement, IVault, IAsset, IBalancerPool} from "./BalancerTypes.sol";
import {AxonCrossChainRouter} from "../Nexus/facets/AxonCrossChainRouter.sol";
import "../USDMirror.sol";
import {Call} from "../Nexus/Call.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../Nexus/interfaces/IKhalaInterchainAccount.sol";
import "../util/Owned.sol";
import "../interfaces/IERC20Mintable.sol";
import "./interface/IVortex.sol";

contract Vortex is IVortex,Owned{

    event SwapAndWithdrawExecuted(
        address indexed sender,
        address[] indexed tokens,
        uint[] amounts,
        address[] assetsWithdrawn
    );
    error MulOverflow();

    address public immutable nexus;
    address public immutable kai;
    mapping (address => address) public assetBptMap;
    uint256 internal constant ONE = 1e18;

    constructor(address _nexus, address _kai) Owned(msg.sender){
        nexus = _nexus;
        kai = _kai;
    }

    /**
    * @dev This function adds an address as a whitelisted asset
    * @param _asset to add in whiteList.
    * @param _bptAddress address of the BPT token for this asset/kai pool.
    */
    function addWhiteListedAsset(address _asset, address _bptAddress) external onlyOwner{
        assetBptMap[_asset] = _bptAddress;
    }

    /**
    * @dev This function removes an asset from whitelist
    * @param _asset to remove from whitelist.
    */
    function removeWhiteListedAsset(address _asset) external onlyOwner{
        delete assetBptMap[_asset];
    }

    /**
    * @dev This function executes batch-swaps and withdraws assets from a Balancer vault to source chain
    *
    * @param balancerVault The address of the Balancer vault to initiate swap.
    * @param kind The type of swap to be executed (GIVEN_IN or GIVEN_OUT).
    * @param swaps An array of BatchSwapStep structs representing the token-swaps to be executed.
    * @param assets An array of IAsset addresses representing the assets to be swapped.
    * @param limits An array representing the limits of each asset in the swap.(slippage)
    * @param deadline The deadline for the token swaps to be executed.
    * @param assetWithdrawIndexes An array representing the indexes of assets in `assets` to be withdrawn.
    *
    * @return assetsWithdrawn An array of addresses representing the assets that were withdrawn.
    */
    function executeSwapAndWithdraw(
        address balancerVault,
        IVault.SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        int256[] memory limits,
        uint256 deadline,
        uint[] memory assetWithdrawIndexes
    ) external payable returns (address[] memory assetsWithdrawn) {

        _receiveAssets(
            assets,
            limits
        );

        FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.toInternalBalance = false;
        funds.recipient = payable(address(this));

        _approveAssetsToBalancerVault(balancerVault,assets,limits);

        int[] memory assetDeltas = IVault(balancerVault).batchSwap(
            kind,
            swaps,
            assets,
            funds,
            limits,
            deadline
        );

        uint size = assetWithdrawIndexes.length;
        uint index;
        uint chainId;
        address[] memory tokens = new address[](size);
        uint[] memory amounts = new uint[](size);
        chainId = USDMirror(address (assets[assetWithdrawIndexes[0]])).chainId();
        for(uint i; i<size; ){
            index = assetWithdrawIndexes[i];
            tokens[i] = address(assets[index]);
            amounts[i] = uint(assetDeltas[index]*-1);
            unchecked{
                ++i;
            }
        }

        Call[] memory emptyCalls;

        AxonCrossChainRouter(nexus).withdrawMultiTokenAndCall(
            chainId,
            tokens,
            amounts,
            IKhalaInterchainAccount(msg.sender).eoa(),
            emptyCalls
        );

        emit SwapAndWithdrawExecuted(
            msg.sender,
            tokens,
            amounts,
            assetsWithdrawn
        );

        return tokens;

    }

    /**
    * @dev This function adds liquidity to corresponding Balancer pool
    * @param asset address of asset to deposit
    * @param amount amount of asset to deposit
    * @param minAmountsOut min expected amount of asset to receive
    */
    function addLiquidityVortex(
        address asset,
        uint256 amount,
        uint256 minAmountsOut
    ) public returns (uint256) {
        address _bpt = assetBptMap[asset];
        require(_bpt!= address(0), "Asset not whitelisted");

        (bytes32 poolId ,address balancerVault) = _getPoolIdAndVault(_bpt);

        _receiveAsset(asset, amount);
        uint256 kaiAmount = _supportAssetWithKai(asset, amount);

        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(asset);
        assets[1] = IAsset(_bpt);
        assets[2] = IAsset(kai);

        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] = BatchSwapStep(
            {
                poolId: poolId,
                assetInIndex: 0,
                assetOutIndex: 1,
                amount: amount,
                userData: ""
            }
        );
        swaps[1] = BatchSwapStep(
            {
                poolId: poolId,
                assetInIndex: 2,
                assetOutIndex: 1,
                amount: kaiAmount,
                userData: ""
            }
        );

        int256[] memory limits = new int256[](3);
        limits[0] = int256(amount);
        limits[1] = int256(minAmountsOut)*-1;
        limits[2] = int256(kaiAmount);

        FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.toInternalBalance = false;
        funds.recipient = payable(address(this));

        _approveAssetsToBalancerVault(balancerVault,assets,limits);
        int[] memory assetDeltas = IVault(balancerVault).batchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds,
            limits,
            block.timestamp + 1 hours
        );

        _transferReceivedAsset(_bpt, uint256(assetDeltas[1]/-2));

        return uint(assetDeltas[1]/2);
    }

    /**
    * @dev This function executes batch-swaps and withdraws assets from a Balancer vault to source chain
    * @param assetOut The address of the asset to be withdrawn.
    * @param bptAmount The amount of BPT to withdraw asset against.
    * @param minAmountsOut The minimum expected amount of asset from this swap.
    */
    function withdrawLiquidityVortex(
        address assetOut,
        uint256 bptAmount,
        uint256 minAmountsOut
    ) public returns(uint256){
        address _bpt = assetBptMap[assetOut];
        require(_bpt!= address(0), "Asset not whitelisted");

        (bytes32 poolId ,address balancerVault) = _getPoolIdAndVault(_bpt);

        _receiveAsset(_bpt, bptAmount);


        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(assetOut);
        assets[1] = IAsset(_bpt);
        assets[2] = IAsset(kai);

        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] = BatchSwapStep(
            {
                poolId: poolId,
                assetInIndex: 1,
                assetOutIndex: 0,
                amount: bptAmount,
                userData: ""
            }
        );
        swaps[1] = BatchSwapStep(
            {
                poolId: poolId,
                assetInIndex: 1,
                assetOutIndex: 2,
                amount: bptAmount,
                userData: ""
            }
        );

        int256[] memory limits = new int256[](3);
        limits[0] = int256(minAmountsOut)*-1;
        limits[1] = int256(bptAmount)*2;
        limits[2] = int256(minAmountsOut)*-1;

        FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.toInternalBalance = false;
        funds.recipient = payable(address(this));

        _approveAssetsToBalancerVault(balancerVault,assets,limits);
        int[] memory assetDeltas = IVault(balancerVault).batchSwap(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds,
            limits,
            block.timestamp + 1 hours
        );

        _burnKai(uint256(assetDeltas[2]*-1));
        uint256 amountToTransfer = uint256(assetDeltas[0]*-1);
        _transferReceivedAsset(assetOut, amountToTransfer);
        return  amountToTransfer;
    }

    /**
    * @dev Receive the assets from the caller.
    *
    * @param assets The assets used in balancer pool swaps.
    * @param limits assets with positive limits are incoming in the swaps, these assets are transferred to vortex to execute batch swaps.
    */
    function _receiveAssets(
        IAsset[] memory assets,
        int256[] memory limits
    ) internal {
        uint size = limits.length;
        for(uint i; i<size;){
            if(limits[i]>0){
                SafeERC20Upgradeable.safeTransferFrom(
                    IERC20Upgradeable(address (assets[i])),
                    msg.sender,
                    address(this),
                    uint256(limits[i])
                );
            }
            unchecked{
                ++i;
            }
        }
    }

    /**
     * @dev Approve the assets to be transferred to the Balancer Vault.
    *
    * @param balancerVault The address of the Balancer Vault contract.
    * @param assets The assets to be approved.
    * @param limits assets with positive limits are incoming in the swaps, these assets are transferred to vortex to execute batch swaps.
    */
    function _approveAssetsToBalancerVault(
        address balancerVault,
        IAsset[] memory assets,
        int256[] memory limits
    ) internal {
        uint size = limits.length;
        for(uint i; i<size;){
            if(limits[i]>0){
                IERC20Upgradeable(address (assets[i])).approve(
                    balancerVault,
                    uint256(limits[i])
                );
            }
            unchecked{
                ++i;
            }
        }
    }

    /**
    * @dev Transfer asset from caller to vortex.
    * @param asset The asset to be pulled from caller.
    * @param amount The amount of the asset to be transferred .
    */
    function _receiveAsset(
        address asset,
        uint256 amount
    ) internal {
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(address (asset)),
            msg.sender,
            address(this),
            amount
        );
    }

    /**
    * @dev Transfer the received asset to the caller.
    * @param assetOut The asset to be transferred to the caller.
    * @param amount The amount of the asset to be transferred .
    */
    function _transferReceivedAsset(
        address assetOut,
        uint256 amount
    ) internal {
        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(assetOut),
            msg.sender,
            amount
        );
    }

    /**
    * @dev Get the pool id and vault address of the balancer pool.
    * @param _bpt The address of the balancer pool.
    */
    function _getPoolIdAndVault(address _bpt) internal returns(bytes32, address){
        return (IBalancerPool(_bpt).getPoolId(), IBalancerPool(_bpt).getVault());
    }

    /**
    * @dev evaluate the amount of kai to be minted for the given asset and amount.
    * @param asset The address of the asset.
    * @param amount The amount of the asset.
    */
    function _supportAssetWithKai(address asset, uint256 amount) internal returns (uint256 kaiAmount) {
        kaiAmount = _upscale(amount, _computeScalingFactor(asset));
        IERC20Mintable(kai).mint(address(this), kaiAmount);
    }

    /**
    * @dev burn the kai for the given amount.
    * @param amount The amount of the asset.
    */
    function _burnKai(uint256 amount) internal {
        IERC20Mintable(kai).burn(amount);
    }

    /**
    * @dev evaluates the scaling factor for the given asset.
    * @param token The address of the asset.
    */
    function _computeScalingFactor(address token) internal view returns (uint256) {

        // Tokens that don't implement the `decimals` method are not supported.
        uint256 tokenDecimals = IERC20Mintable(address(token)).decimals();

        // Tokens with more than 18 decimals are not supported.
        uint256 decimalsDifference = 18 - tokenDecimals;

        return ONE * 10**decimalsDifference;
    }

    /**
    * @dev upscales the given amount to the given scaling factor.
    * @param a The amount to be upscaled.
    * @param b The scaling factor.
    */
    function _upscale(uint a, uint b) internal returns (uint){

        uint256 product = a * b;
        if(!(a == 0 || product / a == b)){
            revert MulOverflow();
        }

        return product / ONE;
    }
}