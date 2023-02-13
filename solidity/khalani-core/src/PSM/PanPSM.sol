pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IERC20Mintable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract PanPSM is Ownable{

    error AssetNotWhiteListed();
    error RedeemFailedNotEnoughBalance();

    event WhiteListedTokenAdded(
        address indexed asset
    );

    event WhiteListedTokenRemoved(
        address indexed asset
    );

    mapping(address => bool) whiteListedTokens;
    address pan;

    function initialize(address _pan) external onlyOwner {
        pan = _pan;
    }

    function addWhiteListedAsset(address asset) external onlyOwner {
        whiteListedTokens[asset] = true;
        emit WhiteListedTokenAdded(asset);
    }

    function removeWhiteListedAddress(address asset) external onlyOwner {
        whiteListedTokens[asset] = false;
        emit WhiteListedTokenRemoved(asset);
    }

    function mintPan(address tokenIn, uint amount) external {
        if(!whiteListedTokens[tokenIn]){
            revert AssetNotWhiteListed();
        }
        SafeERC20.safeTransferFrom(IERC20(tokenIn),msg.sender,address(this),amount);
        IERC20Mintable(pan).mint(msg.sender, amount);
    }

    function redeemPan(uint256 amount, address tokenOut) external {
        if(!whiteListedTokens[tokenOut]){
            revert AssetNotWhiteListed();
        }
        IERC20Mintable(pan).burn(msg.sender, amount);
        uint redeemedAmount = (amount*995)/1000;

        if(IERC20(tokenOut).balanceOf(address(this)) <= redeemedAmount){
            revert RedeemFailedNotEnoughBalance();
        }
        SafeERC20.safeTransfer(IERC20(tokenOut),msg.sender,redeemedAmount);
    }
}