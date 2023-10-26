// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { AddressRegistry } from "../../contracts/Contracts.sol";

contract UpgradeAddressRegistry is AddressRegistry {

    address fixedTermLoanImplementationV502;
    address fixedTermLoanInitializerV500;
    address fixedTermLoanFactoryV2;

    address globalsImplementationV3;

    address poolDeployerV3;

    address poolManagerImplementationV300;
    address poolManagerImplementationV301;  // Same implementation as 301, but changes the WM in the migrator.
    address poolManagerInitializer;
    address poolManagerMigrator;
    address poolManagerWMMigrator;

    address poolPermissionManagerImplementation;
    address poolPermissionManagerInitializer;

    address cyclicalWMImplementation;
    address cyclicalWMInitializer;
    address queueWMFactory;
    address queueWMImplementation;
    address queueWMInitializer;

    address[] mavenPermissionedFixedTermLoans = [
        0x48a89E5267Dd3e22822C99D0bf60a8A4CFd48B48
    ];

    address[] mavenWethFixedTermLoans = [
        0xE6E0586F009241b7A16EBe05d828d9e8231F3ADe
    ];

    address[] aqruFixedTermLoans = [
        0x1F2bCA37106b30C4d72d8E60eBD2bFeAa10BFfE2,
        0x3E36372119f12DEe3De6C260CC7283557C24f471
    ];

    address[] cashMgmtFixedTermLoans = [
        0x55c6FfD8637B3D936Ed6F7924DdcE591D013A0fF,
        0xa6b5F3a55596fe8DF52Ca83Dd3aEaF7c2669a25B,
        0xcb8B7968b4b7333fE85e89e802F2a5eD98408320
    ];

}
