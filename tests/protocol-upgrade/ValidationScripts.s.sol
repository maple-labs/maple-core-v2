// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IProxiedLike, IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import { console2, Test } from "../../contracts/Contracts.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

contract ValidationBase is AddressRegistry, Test {

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

}

contract ValidateUpgradeMapleGlobals is ValidationBase {

    // TODO: Replace this with the address of the new MapleGlobals implementation.
    address constant newImplementation = address(0);

    // TODO: Replace this with the code hash of the new MapleGlobals implementation.
    bytes32 constant expectedCodeHash = bytes32(0);

    function run() external view {
        bytes32 computedCodeHash = keccak256(abi.encode(newImplementation.code));

        console2.log("computed code hash:", uint256(computedCodeHash));
        console2.log("expected code hash:", uint256(expectedCodeHash));

        require(computedCodeHash == expectedCodeHash, "implementation code hash does not match");

        address implementation = IProxiedLike(mapleGlobalsV2Proxy).implementation();

        console2.log("current implementation address: ", implementation);
        console2.log("expected implementation address:", newImplementation);

        require(implementation == newImplementation, "implementation address does not match");
    }

}

contract ValidateRemoveGlobalConfiguration is ValidationBase {

    IGlobals globals = IGlobals(mapleGlobalsV2Proxy);

    function run() external {
        require(!globals.isInstanceOf("LIQUIDATOR",         liquidatorFactory),           "LIQ factory is not removed");
        require(!globals.isInstanceOf("LOAN_MANAGER",       fixedTermLoanManagerFactory), "FT-LM factory is not removed");
        require(!globals.isInstanceOf("POOL_MANAGER",       poolManagerFactory),          "PM factory is not removed");
        require(!globals.isInstanceOf("WITHDRAWAL_MANAGER", withdrawalManagerFactory),    "WM factory is not removed");
        require(!globals.isInstanceOf("LOAN",               fixedTermLoanFactory),        "FTL factory is not removed");

        require(!globals.canDeployFrom(poolManagerFactory,       poolDeployer), "PD can deploy PM");
        require(!globals.canDeployFrom(withdrawalManagerFactory, poolDeployer), "PD can deploy WM");
    }

}

contract ValidateAddGlobalConfiguration is ValidationBase {

    // TODO: Replace this with the address of the new PD.
    address constant newPoolDeployer = address(0);

    // TODO: Replace this with the address of the OTL factory.
    address constant openTermLoanFactory = address(0);

    // TODO: Replace this with the address of the OT-LM factory.
    address constant openTermLoanManagerFactory = address(0);

    // TODO: Replace this with the address of the OTL refinancer.
    address constant openTermLoanRefinancer = address(0);

    IGlobals globals = IGlobals(mapleGlobalsV2Proxy);

    function run() external {
        require(globals.isInstanceOf("LIQUIDATOR_FACTORY",         liquidatorFactory),        "LIQ factory is not added");
        require(globals.isInstanceOf("POOL_MANAGER_FACTORY",       poolManagerFactory),       "PM factory is not added");
        require(globals.isInstanceOf("WITHDRAWAL_MANAGER_FACTORY", withdrawalManagerFactory), "WM factory is not added");

        require(globals.isInstanceOf("FT_LOAN_FACTORY", fixedTermLoanFactory), "FTL factory is not added");
        require(globals.isInstanceOf("LOAN_FACTORY",    fixedTermLoanFactory), "FTL factory is not added");

        require(globals.isInstanceOf("OT_LOAN_FACTORY", openTermLoanFactory), "OTL factory is not added");
        require(globals.isInstanceOf("LOAN_FACTORY",    openTermLoanFactory), "OTL factory is not added");

        require(globals.isInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory), "FT-LM factory is not added");
        require(globals.isInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory), "FT-LM factory is not added");

        require(globals.isInstanceOf("OT_LOAN_MANAGER_FACTORY", openTermLoanManagerFactory), "OT-LM factory is not added");
        require(globals.isInstanceOf("LOAN_MANAGER_FACTORY",    openTermLoanManagerFactory), "OT-LM factory is not added");

        require(globals.isInstanceOf("FT_REFINANCER", address(fixedTermRefinancer)), "FT-REF is not added");
        require(globals.isInstanceOf("REFINANCER",    address(fixedTermRefinancer)), "FT-REF is not added");

        require(globals.isInstanceOf("OT_REFINANCER", openTermLoanRefinancer), "OT-REF is not added");
        require(globals.isInstanceOf("REFINANCER",    openTermLoanRefinancer), "OT-REF is not added");

        require(globals.isInstanceOf("FEE_MANAGER", feeManager), "FM is not added");

        require(globals.canDeployFrom(poolManagerFactory,       newPoolDeployer), "PD can't deploy PM");
        require(globals.canDeployFrom(withdrawalManagerFactory, newPoolDeployer), "PD can't deploy WM");

        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenPermissionedPoolManager), "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenUsdcPoolManager),         "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenWethPoolManager),         "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, orthogonalPoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, icebreakerPoolManager),        "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, aqruPoolManager),              "PM can't deploy FT-LM");
        require(globals.canDeployFrom(fixedTermLoanManagerFactory, mavenUsdc3PoolManager),        "PM can't deploy FT-LM");

        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenPermissionedPoolManager), "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenUsdcPoolManager),         "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenWethPoolManager),         "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, orthogonalPoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, icebreakerPoolManager),        "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, aqruPoolManager),              "PM can't deploy OT-LM");
        require(globals.canDeployFrom(openTermLoanManagerFactory, mavenUsdc3PoolManager),        "PM can't deploy OT-LM");
    }

}
