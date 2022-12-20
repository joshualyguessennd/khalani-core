pragma solidity ^0.8.0;
import {KhalaInterChainAccount} from "../KhalaInterChainAccount.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";


library LibAccountsRegistry {

    event InterchainAccountCreated(
        address sender,
        address account
    );

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("axon.accounts.registry.storage");
    bytes constant bytecode = type(KhalaInterChainAccount).creationCode;
    bytes32 constant bytecodeHash = bytes32(keccak256(bytecode));

    function getInterchainAccount(address _sender) internal view returns (address)
    {
        return _getInterchainAccount(_salt(_sender));
    }

    function getDeployedInterchainAccount(address _sender) internal returns (address)
    {
        bytes32 salt = _salt(_sender);
        address interchainAccount = _getInterchainAccount(salt);
        if (!(interchainAccount.code.length>0)) {
            interchainAccount = Create2.deploy(0, salt, bytecode);

            KhalaInterChainAccount(interchainAccount).initialize(_sender);

            emit InterchainAccountCreated(_sender, interchainAccount);
        }
        return interchainAccount;
    }

    function _salt(address _sender) internal pure returns (bytes32)
    {
        return bytes32(abi.encodePacked(_sender));
    }

    function _getInterchainAccount(bytes32 salt) internal view returns (address)
    {
        return Create2.computeAddress(salt, bytecodeHash);
    }
}
