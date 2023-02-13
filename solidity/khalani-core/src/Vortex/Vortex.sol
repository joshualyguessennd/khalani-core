pragma solidity ^0.8.0;
import {BatchSwapStep, FundManagement, IVault,IAsset} from "./BalancerTypes.sol";
import {AxonCrossChainRouter} from "../Nexus/facets/AxonCrossChainRouter.sol";
import "../USDMirror.sol";
import {Call} from "../Nexus/Call.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../Nexus/interfaces/IKhalaInterchainAccount.sol";

contract Vortex{

    event SwapAndWithdrawExecuted(
        address indexed sender,
        address[] indexed tokens,
        uint[] amounts,
        address[] assetsWithdrawn
    );

    //for compatibility with AxonCrossChainRouter
    address public eoa;
    address public nexus;

    constructor(address _nexus){
        eoa = address(this);
        nexus = _nexus;
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
                SafeERC20Upgradeable.safeIncreaseAllowance(
                    IERC20Upgradeable(address (assets[i])),
                    balancerVault,
                    uint256(limits[i])
                );
            }
        unchecked{
            ++i;
        }
        }
    }

}