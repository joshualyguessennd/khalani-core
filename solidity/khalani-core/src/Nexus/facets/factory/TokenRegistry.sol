pragma solidity ^0.8.0;
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "../../libraries/LibAppStorage.sol";
import "../../libraries/LibTokenRegistry.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";


contract StableTokenRegistry is Modifiers{

    error TokenAlreadyExist(
        uint chain,
        address tokenOnChain,
        address tokenOnAxon
    );

    event MirrorTokenRegistered(
        uint indexed chainId,
        address token,
        address mirrorToken
    );

    /**
    * @notice initialize token factory with pan address on axon
    * @param pan - pan address on axon
    */
    function initTokenFactory(address pan) external onlyDiamondOwner {
        LibTokenRegistry.TokenRegistryStorage storage s = LibTokenRegistry.tokenRegistryStorage();
        s.panAddressAxon = pan;
    }

    /**
    * @notice register pan address of the supporting chain
    * @param chainId - chain id of the chain for which pan is being registered
    * @param token - address of the pan token for the  `chainId`
    */
    function registerPan(uint chainId, address token) external onlyDiamondOwner {
        LibTokenRegistry.TokenRegistryStorage storage s = LibTokenRegistry.tokenRegistryStorage();
        s.panTokenMap[chainId] = token;
    }

    /**
    * @notice deploys ERC-20 mirror token against an ERC-20 token (which exists on the given `chainId`)

    * @param _chainId - chain id of the chain for which pan is being registered
    * @param _sourceChainTokenAddr - address of the pan token for the  `chainId`
    */
    function registerMirrorToken(uint _chainId, address _sourceChainTokenAddr, address _mirrorTokenAddr)  public onlyDiamondOwner
    {
        LibTokenRegistry.TokenRegistryStorage storage s = LibTokenRegistry.tokenRegistryStorage();
        s.mirrorTokenMap[_chainId][_sourceChainTokenAddr] = _mirrorTokenAddr;
        emit MirrorTokenRegistered(
            _chainId,
            _sourceChainTokenAddr,
            _mirrorTokenAddr
        );
    }
}
