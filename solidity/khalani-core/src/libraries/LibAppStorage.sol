// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

struct AppStorage {
    address gateway;
    address psm;
    address nexus;
    mapping(address => (address => uint256)) balances; // user -> USDC -> balance
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyGateway() {
        require(s.gateway == _msgSender(),"LibAppStorage: only Gateway can call this function");
        _;
    }
}
