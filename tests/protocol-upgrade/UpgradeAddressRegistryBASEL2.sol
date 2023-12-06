// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { AddressRegistryBaseL2 } from "../../contracts/Contracts.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract UpgradeAddressRegistryBASEL2 is AddressRegistryBaseL2, UpgradeAddressRegistry {

    address[] cashManagementUSDCOpenTermLoans = [
        0xB5E7D5d14c8f2aa6D204f334d07D3E5b1f2e0Eb5
    ];

    address[] cashManagementUSDCAllowedLenders = [
        0x6495F96B89904F574817a3b191c7817D91FE96eb,
        0xD84C0427fA38E12B4ff9b3897EF0e7dab7251746,
        0xFCEfe182bD1316D664E6f4073aa7CfB6b761BFb9
    ];

    constructor() {
        protocol.governor                    = governor;
        protocol.mapleTreasury               = mapleTreasury;
        protocol.operationalAdmin            = operationalAdmin;
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

        fixedTermLoanInitializerV500 = 0x42F53CDF5D74aCa6A62BAD32C97Cd460449090dC;

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

        cashPools.push(0);

    }

}
