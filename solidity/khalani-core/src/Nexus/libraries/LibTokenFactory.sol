pragma solidity ^0.8.0;
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "../../USDMirror.sol";

library LibTokenFactory {


    struct TokenFactoryStorage {
        // mapping of pan on source chain (1 => PanOnEth)
        mapping(uint => address) panTokenMap;
        // address of pan token deployed on AXON chain
        address panAddressAxon;
    }

    function tokenFactoryStorage() internal pure returns (TokenFactoryStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("axon.token.factory.storage");
    bytes constant bytecode = type(USDMirror).creationCode;
    bytes32 constant bytecodeHash = bytes32(keccak256(bytecode));

    function _salt(uint _chain, address _token) internal pure returns (bytes32)
    {
        return keccak256((abi.encodePacked(_chain,_token)));
    }

    function _checkMirrorToken(bytes32 salt) internal view returns (address)
    {
        return Create2.computeAddress(salt, bytecodeHash);
    }

    function _deployMirrorToken(bytes32 salt) internal returns (address){
        address mirrorTokenAddress = Create2.deploy(0, salt, bytecode);
        return mirrorTokenAddress;
    }

    /**
    * @notice resolves the address of mirror / pan token for a given
    * chain id and token address on the chain id
    */
    function getMirrorToken(uint _chain, address _token) internal view returns (address) {
        TokenFactoryStorage storage s = tokenFactoryStorage();
        if(s.panTokenMap[_chain] == _token){
            return s.panAddressAxon;
        }
        bytes32 salt = _salt(_chain, _token);
        return _checkMirrorToken(salt);
    }
}
