// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../balancer/vault/interfaces/IAsset.sol";

interface INexusVault {
    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }
}
