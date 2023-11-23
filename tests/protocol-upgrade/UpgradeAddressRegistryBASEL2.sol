// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { AddressRegistryBaseL2 } from "../../contracts/Contracts.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract UpgradeAddressRegistryBASEL2 is AddressRegistryBaseL2, UpgradeAddressRegistry {

    address[] cashManagementUSDCOpenTermLoans = [
        0xB5E7D5d14c8f2aa6D204f334d07D3E5b1f2e0Eb5
    ];

    address[] cashManagementUSDCAllowedLenders = [
        0xD1A9FfeFe76ee44Ca724BEf30e16Ead1BA039601
    ];

    constructor() {
        protocol.governor                    = governor;
        protocol.mapleTreasury               = mapleTreasury;
        protocol.securityAdmin               = securityAdmin;
        protocol.usdc                        = usdc;
        protocol.fixedTermFeeManagerV1       = fixedTermFeeManagerV1;
        protocol.fixedTermLoanFactory        = fixedTermLoanFactory;
        protocol.fixedTermLoanManagerFactory = fixedTermLoanManagerFactory;
        protocol.fixedTermRefinancerV2       = fixedTermRefinancerV2;
        protocol.globals                     = globals;
        protocol.globalsImplementationV2     = globalsImplementationV2;
        protocol.liquidatorFactory           = liquidatorFactory;
        protocol.openTermLoanFactory         = openTermLoanFactory;
        protocol.openTermLoanManagerFactory  = openTermLoanManagerFactory;
        protocol.openTermRefinancerV1        = openTermRefinancerV1;
        protocol.poolDeployerV2              = poolDeployerV2;
        protocol.poolManagerFactory          = poolManagerFactory;
        protocol.withdrawalManagerFactory    = withdrawalManagerFactory;

        pools.push(Pool({
            name:                 "cashMgmtUSDC",
            pool:                 cashManagementUSDCPool,
            poolManager:          cashManagementUSDCPoolManager,
            withdrawalManager:    cashManagementUSDCWithdrawalManager,
            fixedTermLoanManager: cashManagementUSDCFixedTermLoanManager,
            openTermLoanManager:  cashManagementUSDCOpenTermLoanManager,
            lps:                  cashManagementUSDCAllowedLenders,
            otLoans:              cashManagementUSDCOpenTermLoans,
            ftLoans:              new address[](0)
        }));
    }

}
