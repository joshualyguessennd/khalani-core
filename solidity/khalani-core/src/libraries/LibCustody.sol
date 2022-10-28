// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

library LibCustody {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("khalini.custody.storage");

    struct CustodyStorage{
        address public gateway;
        uint256 public number;

        /// @dev stores all user balances
        mapping(address => uint) public balances;
    }



    function custodyStorage() internal pure returns (CustodyStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

}