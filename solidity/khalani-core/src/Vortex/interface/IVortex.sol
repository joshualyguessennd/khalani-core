pragma solidity ^0.8.0;
import {BatchSwapStep, FundManagement, IVault, IAsset, IBalancerPool} from "../BalancerTypes.sol";
interface IVortex {
    /**
    * @dev This function adds an address as a whitelisted asset
    * @param _asset to add in whiteList.
    * @param _bptAddress address of the BPT token for this asset/kai pool.
    */
    function addWhiteListedAsset(address _asset, address _bptAddress) external;
    /**
    * @dev This function removes an asset from whitelist
    * @param _asset to remove from whitelist.
    */
    function removeWhiteListedAsset(address _asset) external;


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
    ) external payable returns (address[] memory assetsWithdrawn);

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
    ) external returns (uint256);

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
    ) external returns(uint256);
}