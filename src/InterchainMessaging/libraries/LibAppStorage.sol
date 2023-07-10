// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../../diamondCommons/libraries/LibDiamond.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Errors.sol";

struct RemoteAppStorage {
   address hyperlaneAdapter;
   address assetReserves;
   address khalaniReceiver;
   uint256 khalaniChainId;
}

struct KhalaniAppStorage {
    address hyperlaneAdapter;
    address liquidityProjector;
    address interchainLiquidityHub;
    address liquidityAggregator;
    mapping(uint => address) chainIdToAdapter;
}

abstract contract Modifiers is ReentrancyGuard {
    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyHyperlaneAdapter(address hyperlaneAdapter) {
        if(msg.sender != hyperlaneAdapter){
            revert InvalidHyperlaneAdapter();
        }
        _;
    }
}

contract RemoteStorage is Modifiers {
    RemoteAppStorage internal s;
}

contract KhalaniStorage is Modifiers {
    KhalaniAppStorage internal s;
}
