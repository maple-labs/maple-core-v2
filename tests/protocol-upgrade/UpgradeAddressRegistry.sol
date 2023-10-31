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

    address[] aqruFixedTermLoans = [
        0x1F2bCA37106b30C4d72d8E60eBD2bFeAa10BFfE2,
        0x3E36372119f12DEe3De6C260CC7283557C24f471
    ];

    address[] aqruOpenTermLoans = [
        0x2603E1294aa3C1c7fC0A60E360D23936B6398b99,
        0x29356F80d6016583C03991Cda7Dd42259517c005,
        0x51d8cd0f68f3A9D4ab7Ce4062bc89B5C47A96818,
        0xf2FDA7D97CF9920E0857Ec60416eD0006ea610f9
    ];

    address[] cashMgmtUSDCFixedTermLoans = [
        0x55c6FfD8637B3D936Ed6F7924DdcE591D013A0fF,
        0xa6b5F3a55596fe8DF52Ca83Dd3aEaF7c2669a25B,
        0xcb8B7968b4b7333fE85e89e802F2a5eD98408320
    ];

    address[] cashMgmtUSDCOpenTermLoans = [
        0xDA8f7941192590408DCe701A60FB3892455669Ce
    ];

    address[] cashMgmtUSDTFixedTermLoans;

    address[] cashMgmtUSDTOpenTermLoans = [
        0xD7141b6cbCf155beABcCB2040Fa66fBD259A257B
    ];

    address[] cicadaFixedTermLoans;

    address[] cicadaOpenTermLoans = [
        0x8405494208e2ea178aCeA0EDD6C1a76668e18a7D];

    address[] mapleDirectFixedTermLoans;

    address[] mapleDirectOpenTermLoans = [
        0x07BC04A9Bc791f469060dB77a123497c0AAB6F81,
        0xaa4F38aA3970A4dB0d268fafe2966E3F6a7fac5D
    ];

    address[] mavenPermissionedFixedTermLoans = [
        0x48a89E5267Dd3e22822C99D0bf60a8A4CFd48B48
    ];

    address[] mavenPermissionedOpenTermLoans;

    address[] mavenWethFixedTermLoans = [
        0xE6E0586F009241b7A16EBe05d828d9e8231F3ADe
    ];

    address[] mavenWethOpenTermLoans;

}
