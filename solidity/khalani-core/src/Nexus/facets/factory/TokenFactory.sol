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

    /**
    * @notice initialize token factory with pan address on axon
    * @param pan - pan address on axon
    */
    function initTokenFactory(address pan) external onlyDiamondOwner {
        LibTokenFactory.TokenFactoryStorage storage s = LibTokenFactory.tokenFactoryStorage();
        s.panAddressAxon = pan;
    }

    /**
    * @notice register pan address of the supporting chain
    * @param chainId - chain id of the chain for which pan is being registered
    * @param token - address of the pan token for the  `chainId`
    */
    function registerPan(uint chainId, address token) external onlyDiamondOwner {
        LibTokenFactory.TokenFactoryStorage storage s = LibTokenFactory.tokenFactoryStorage();
        s.panTokenMap[chainId] = token;
    }

    /**
    * @notice deploys ERC-20 mirror token against an ERC-20 token (which exists on the given `chainId`)
    * @param name - name of the token to be deployed
    * @param symbol - symbol of the token to be deployed
    * @param _chainId - chain id of the chain for which pan is being registered
    * @param _sourceChainTokenAddr - address of the pan token for the  `chainId`
    */
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
