// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { AddressRegistry } from "../../contracts/Contracts.sol";

contract UpgradeAddressRegistry is AddressRegistry {

    address fixedTermLoanImplementationV502;
    address fixedTermLoanInitializerV500;
    address fixedTermLoanFactoryV502;

    address globalsImplementationV3;

    address poolDeployerV3;

    address poolManagerImplementationV300;
    address poolManagerInitializer;
    address poolManagerMigrator;

    address poolPermissionManagerImplementation;
    address poolPermissionManagerInitializer;

    address[] mavenPermissionedLoans = [
        0x48a89E5267Dd3e22822C99D0bf60a8A4CFd48B48
    ];

    address[] mavenWethLoans = [
        0xE6E0586F009241b7A16EBe05d828d9e8231F3ADe
    ];

    address[] aqruLoans = [
        0x0cbc028614F164A085fa24a895FE5E954faC5000,
        0x1b42E16958ed30dd3750d765C243BdDE980fdf64,
        0x1F2bCA37106b30C4d72d8E60eBD2bFeAa10BFfE2,
        0x3E36372119f12DEe3De6C260CC7283557C24f471,
        0x69A8ebf9dC1677f5E61dE22101E7e46179a9B668,
        0x79c1f41B4cC890050375344918EF81Ce916B41C7,
        0xeB4F034958C6D3da0293142dd11F9EE2e2ad5019,
        0xfb520De9e8CaD09a28A06E5fE27b8e392bffc209,
        0xDD5d6d75e9cF52CbB86B53d2E89f786fDC030B33
    ];

    address[] cashMgmtLoans = [
        0x54096783F286CAD5f023a0dae8eeA2949A8C887E,
        0x55c6FfD8637B3D936Ed6F7924DdcE591D013A0fF,
        0xa6b5F3a55596fe8DF52Ca83Dd3aEaF7c2669a25B,
        0xcb8B7968b4b7333fE85e89e802F2a5eD98408320
    ];

}
