pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./IKaiPSM.sol";

contract KaiPSM is IKaiPSM,OwnableUpgradeable{

    error AssetNotWhiteListed();
    error RedeemFailedNotEnoughBalance();
    error MulOverflow();


    event WhiteListedTokenAdded(
        address indexed asset
    );

    event WhiteListedTokenRemoved(
        address indexed asset
    );

    mapping(address => bool) whiteListedTokens;
    address kai;
    uint256 internal constant ONE = 1e18;

    function initialize(address _kai) external initializer {
        kai = _kai;
        __Ownable_init();
    }

    function addWhiteListedAsset(address asset) external onlyOwner {
        whiteListedTokens[asset] = true;
        emit WhiteListedTokenAdded(asset);
    }

    function removeWhiteListedAddress(address asset) external onlyOwner {
        whiteListedTokens[asset] = false;
        emit WhiteListedTokenRemoved(asset);
    }

    function mintKai(address tokenIn, uint amount) external {
        if(!whiteListedTokens[tokenIn]){
            revert AssetNotWhiteListed();
        }
        SafeERC20.safeTransferFrom(IERC20(tokenIn),msg.sender,address(this),amount);
        uint scalingFactor = _computeScalingFactor(tokenIn);
        if(scalingFactor != ONE){
            amount = _upscale(amount, scalingFactor);
        }
        IERC20Mintable(kai).mint(msg.sender, amount);
    }

    function redeemKai(uint256 amount, address tokenOut) external {
        if(!whiteListedTokens[tokenOut]){
            revert AssetNotWhiteListed();
        }
        IERC20Mintable(kai).burn(msg.sender, amount);

        uint redeemedAmount = (amount*995)/1000;
        uint scalingFactor = _computeScalingFactor(tokenOut);
        if(scalingFactor != ONE){
            redeemedAmount = _downscale(redeemedAmount,scalingFactor);
        }

        if(IERC20(tokenOut).balanceOf(address(this)) <= redeemedAmount){
            revert RedeemFailedNotEnoughBalance();
        }
        SafeERC20.safeTransfer(IERC20(tokenOut),msg.sender,redeemedAmount);
    }

    function _computeScalingFactor(address token) internal view returns (uint256) {

        // Tokens that don't implement the `decimals` method are not supported.
        uint256 tokenDecimals = IERC20Mintable(address(token)).decimals();

        // Tokens with more than 18 decimals are not supported.
        uint256 decimalsDifference = 18 - tokenDecimals;

        return ONE * 10**decimalsDifference;
    }

    function _upscale(uint a, uint b) internal returns (uint){

        uint256 product = a * b;
        if(!(a == 0 || product / a == b)){
            revert MulOverflow();
        }

        return product / ONE;
    }

    function _downscale(uint a, uint b) internal returns (uint){
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            if(aInflated / a != ONE){
                revert MulOverflow();
            }
            return aInflated / b;
        }
    }
}