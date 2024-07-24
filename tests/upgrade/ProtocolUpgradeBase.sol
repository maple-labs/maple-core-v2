// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import {
    console2 as console,
    FixedTermLoan,
    FixedTermLoanManager,
    FixedTermRefinancer,
    Pool,
    PoolManager,
    OpenTermLoan,
    OpenTermLoanManager
} from "../../contracts/Contracts.sol";

import { IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import { FixedTermLoanHealthChecker } from "../health-checkers/FixedTermLoanHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "../health-checkers/OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "../health-checkers/ProtocolHealthChecker.sol";

import { FuzzedUtil } from "../fuzz/FuzzedSetup.sol";

contract ProtocolUpgradeBase is AddressRegistry, FuzzedUtil {

    // Main addresses deployed during upgrade
    address fixedTermLoanV600Implementation;
    address openTermLoanV200Implementation;

    // Addresses needed for testing
    address poolDelegate;

    FixedTermLoanHealthChecker fixedTermLoanHC;
    OpenTermLoanHealthChecker  openTermLoanHC;
    ProtocolHealthChecker      protocolHC;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 19920370);
    }

    function _activatePoolManager(address poolManager_) internal {
        activatePoolManager(poolManager_);
        setLiquidityCap(poolManager_, 100_000_000e6);
    }

    function _upgradeAndAssert() internal {
        fixedTermLoanV600Implementation = address(new FixedTermLoan());
        openTermLoanV200Implementation  = address(new OpenTermLoan());

        IProxyFactoryLike fixedTermLoanFactory = IProxyFactoryLike(fixedTermLoanFactoryV2);
        IProxyFactoryLike openTermLoanFactory  = IProxyFactoryLike(openTermLoanFactory);

        vm.startPrank(governor);
        fixedTermLoanFactory.registerImplementation(600, fixedTermLoanV600Implementation, fixedTermLoanV501Initializer);
        fixedTermLoanFactory.setDefaultVersion(600);

        openTermLoanFactory.registerImplementation(200, openTermLoanV200Implementation, openTermLoanV101Initializer);
        openTermLoanFactory.setDefaultVersion(200);
        vm.stopPrank();

        assertEq(fixedTermLoanFactory.implementationOf(600), fixedTermLoanV600Implementation);
        assertEq(fixedTermLoanFactory.defaultVersion(),      600);

        assertEq(openTermLoanFactory.implementationOf(200), openTermLoanV200Implementation);
        assertEq(openTermLoanFactory.defaultVersion(),      200);
    }

    function _setUpAddresses() internal {
        // Using SyrupUSDC pool
        setAddresses(syrupUSDCPool);

        _collateralAsset      = address(weth);
        _feeManager           = address(feeManager);
        _fixedTermLoanFactory = address(fixedTermLoanFactoryV2);
        _liquidatorFactory    = address(liquidatorFactory);
        _openTermLoanFactory  = address(openTermLoanFactory);

        poolDelegate = PoolManager(syrupUSDCPoolManager).poolDelegate();
    }

    /**************************************************************************************************************************************/
    /*** Assertion Helpers                                                                                                              ***/
    /**************************************************************************************************************************************/

    function assertFixedTermLoanHealthChecker(FixedTermLoanHealthChecker.Invariants memory invariants_) internal {
        assertTrue(invariants_.fixedTermLoanInvariantA,        "FTLHealthChecker FTL Invariant A");
        assertTrue(invariants_.fixedTermLoanInvariantB,        "FTLHealthChecker FTL Invariant B");
        assertTrue(invariants_.fixedTermLoanInvariantC,        "FTLHealthChecker FTL Invariant C");
        assertTrue(invariants_.fixedTermLoanManagerInvariantD, "FTLHealthChecker FTLM Invariant D");
        assertTrue(invariants_.fixedTermLoanManagerInvariantE, "FTLHealthChecker FTLM Invariant E");
        assertTrue(invariants_.fixedTermLoanManagerInvariantM, "FTLHealthChecker FTLM Invariant M");
        assertTrue(invariants_.fixedTermLoanManagerInvariantN, "FTLHealthChecker FTLM Invariant N");
    }

    function assertOpenTermLoanHealthChecker(OpenTermLoanHealthChecker.Invariants memory invariants_) internal {
        assertTrue(invariants_.openTermLoanInvariantA,        "OTLHealthChecker OTL Invariant A");
        assertTrue(invariants_.openTermLoanInvariantB,        "OTLHealthChecker OTL Invariant B");
        assertTrue(invariants_.openTermLoanInvariantC,        "OTLHealthChecker OTL Invariant C");
        assertTrue(invariants_.openTermLoanInvariantD,        "OTLHealthChecker OTL Invariant D");
        assertTrue(invariants_.openTermLoanInvariantE,        "OTLHealthChecker OTL Invariant E");
        assertTrue(invariants_.openTermLoanInvariantF,        "OTLHealthChecker OTL Invariant F");
        assertTrue(invariants_.openTermLoanInvariantG,        "OTLHealthChecker OTL Invariant G");
        assertTrue(invariants_.openTermLoanInvariantH,        "OTLHealthChecker OTL Invariant H");
        assertTrue(invariants_.openTermLoanInvariantI,        "OTLHealthChecker OTL Invariant I");
        assertTrue(invariants_.openTermLoanManagerInvariantA, "OTLHealthChecker OTLM Invariant A");
        assertTrue(invariants_.openTermLoanManagerInvariantB, "OTLHealthChecker OTLM Invariant B");
        assertTrue(invariants_.openTermLoanManagerInvariantC, "OTLHealthChecker OTLM Invariant C");
        assertTrue(invariants_.openTermLoanManagerInvariantD, "OTLHealthChecker OTLM Invariant D");
        assertTrue(invariants_.openTermLoanManagerInvariantF, "OTLHealthChecker OTLM Invariant F");
        assertTrue(invariants_.openTermLoanManagerInvariantH, "OTLHealthChecker OTLM Invariant H");
        assertTrue(invariants_.openTermLoanManagerInvariantI, "OTLHealthChecker OTLM Invariant I");
        assertTrue(invariants_.openTermLoanManagerInvariantJ, "OTLHealthChecker OTLM Invariant J");
        assertTrue(invariants_.openTermLoanManagerInvariantK, "OTLHealthChecker OTLM Invariant K");
    }

    function assertProtocolHealthChecker(ProtocolHealthChecker.Invariants memory invariants_) internal {
        assertTrue(invariants_.fixedTermLoanManagerInvariantA,      "PHC fixedTermLoanManagerInvariantA");
        assertTrue(invariants_.fixedTermLoanManagerInvariantB,      "PHC fixedTermLoanManagerInvariantB");
        assertTrue(invariants_.fixedTermLoanManagerInvariantF,      "PHC fixedTermLoanManagerInvariantF");
        assertTrue(invariants_.fixedTermLoanManagerInvariantI,      "PHC fixedTermLoanManagerInvariantI");
        assertTrue(invariants_.fixedTermLoanManagerInvariantJ,      "PHC fixedTermLoanManagerInvariantJ");
        assertTrue(invariants_.fixedTermLoanManagerInvariantK,      "PHC fixedTermLoanManagerInvariantK");
        assertTrue(invariants_.openTermLoanManagerInvariantE,       "PHC openTermLoanManagerInvariantE");
        assertTrue(invariants_.openTermLoanManagerInvariantG,       "PHC openTermLoanManagerInvariantG");
        assertTrue(invariants_.poolInvariantA,                      "PHC poolInvariantA");
        assertTrue(invariants_.poolInvariantD,                      "PHC poolInvariantD");
        assertTrue(invariants_.poolInvariantE,                      "PHC poolInvariantE");
        assertTrue(invariants_.poolInvariantI,                      "PHC poolInvariantI");
        assertTrue(invariants_.poolInvariantJ,                      "PHC poolInvariantJ");
        assertTrue(invariants_.poolInvariantK,                      "PHC poolInvariantK");
        assertTrue(invariants_.poolManagerInvariantA,               "PHC poolManagerInvariantA");
        assertTrue(invariants_.poolManagerInvariantB,               "PHC poolManagerInvariantB");
        assertTrue(invariants_.poolPermissionManagerInvariantA,     "PHC poolPermissionManagerInvariantA");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantC, "PHC withdrawalManagerCyclicalInvariantC");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantD, "PHC withdrawalManagerCyclicalInvariantD");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantE, "PHC withdrawalManagerCyclicalInvariantE");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantM, "PHC withdrawalManagerCyclicalInvariantM");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantN, "PHC withdrawalManagerCyclicalInvariantN");
        assertTrue(invariants_.withdrawalManagerQueueInvariantA,    "PHC withdrawalManagerQueueInvariantA");
        assertTrue(invariants_.withdrawalManagerQueueInvariantB,    "PHC withdrawalManagerQueueInvariantB");
        assertTrue(invariants_.withdrawalManagerQueueInvariantD,    "PHC withdrawalManagerQueueInvariantD");
        assertTrue(invariants_.withdrawalManagerQueueInvariantE,    "PHC withdrawalManagerQueueInvariantE");
        assertTrue(invariants_.withdrawalManagerQueueInvariantF,    "PHC withdrawalManagerQueueInvariantF");
        assertTrue(invariants_.withdrawalManagerQueueInvariantI,    "PHC withdrawalManagerQueueInvariantI");
    }

}
