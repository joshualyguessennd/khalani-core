pragma solidity ^0.8.0;
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "../../libraries/LibAppStorage.sol";
import "../../libraries/LibTokenFactory.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";


contract StableTokenFactory is Modifiers{

    error TokenAlreadyExist(
        uint chain,
        address tokenOnChain,
        address tokenOnAxon
    );

    event MirrorTokenDeployed(
        uint indexed chainId,
        address token
    );

    function initTokenFactory(address pan) external onlyDiamondOwner {
        LibTokenFactory.TokenFactoryStorage storage s = LibTokenFactory.tokenFactoryStorage();
        s.panAddressAxon = pan;
    }

    function registerPan(uint chainId, address token) external onlyDiamondOwner {
        LibTokenFactory.TokenFactoryStorage storage s = LibTokenFactory.tokenFactoryStorage();
        s.panTokenMap[chainId] = token;
    }

    function deployMirrorToken(string calldata name, string calldata symbol, uint _chainId, address _sourceChainTokenAddr)  public onlyDiamondOwner returns (address)
    {
        bytes32 salt = LibTokenFactory._salt(_chainId,_sourceChainTokenAddr);
        address mirrorToken = LibTokenFactory._checkMirrorToken(salt);
        if (!(mirrorToken.code.length>0)) {
            mirrorToken = LibTokenFactory._deployMirrorToken(salt);
            USDMirror(mirrorToken).initialize(name, symbol);
            emit MirrorTokenDeployed(_chainId, mirrorToken);
        } else {
            revert TokenAlreadyExist(
                _chainId,
                _sourceChainTokenAddr,
                mirrorToken
            );
        }
        return mirrorToken;
    }
}