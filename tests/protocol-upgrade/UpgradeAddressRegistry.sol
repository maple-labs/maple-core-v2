// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

contract UpgradeAddressRegistry is AddressRegistry {

    // TODO: Add all pool managers that need to be upgraded.
    address[] poolManagers = [
        syrupUSDCPoolManager
    ];

    // TODO: Populate and add the same data for other pools.
    address[] syrupUSDCAllowedLenders;
    address[] syrupUSDCFixedTermLoans;
    address[] syrupUSDCOpenTermLoans;

}
