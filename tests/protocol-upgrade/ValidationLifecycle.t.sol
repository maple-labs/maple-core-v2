// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IFixedTermLoanManager,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    ILoanLike
} from "../../contracts/interfaces/Interfaces.sol";

import { FixedTermLoanHealthChecker } from "../health-checkers/FixedTermLoanHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "../health-checkers/OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "../health-checkers/ProtocolHealthChecker.sol";

import { FuzzedUtil } from "../fuzz/FuzzedSetup.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract ValidationLifecycleETH is ProtocolUpgradeBase, FuzzedUtil {

    uint256 ftlCount = 3;
    uint256 otlCount = 3;

    uint256 loanActionCount     = 10;
    uint256 strategyActionCount = 10;

    uint256 allowedDiff = 1000;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21229159);

        upgradeProtocol();
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    function testFork_validationLifecycle_syrupUsdc(uint256 seed_) external {
        runLifecycleValidation(seed_, syrupUSDCPool, syrupUSDCFixedTermLoans, syrupUSDCOpenTermLoans);
    }

    // function testFork_validationLifecycle_syrupUsdt(uint256 seed_) external {
    //     runLifecycleValidation(seed_, syrupUSDTPool, syrupUSDTFixedTermLoans, syrupUSDTOpenTermLoans);
    // }

    // function testFork_validationLifecycle_aqru(uint256 seed_) external {
    //     runLifecycleValidation(seed_, aqruPool, aqruFixedTermLoans, aqruOpenTermLoans);
    // }

    // function testFork_validationLifecycle_cashUsdc(uint256 seed_) external {
    //     runLifecycleValidation(seed_, cashUSDCPool, cashUSDCFixedTermLoans, cashUSDCOpenTermLoans);
    // }

    // function testFork_validationLifecycle_blueChip(uint256 seed_) external {
    //     runLifecycleValidation(seed_, blueChipSecuredUSDCPool, blueChipFixedTermLoans, blueChipOpenTermLoans);
    // }

    // function testFork_validationLifecycle_highYieldCorpUsdc(uint256 seed_) external {
    //     runLifecycleValidation(seed_, highYieldCorpUSDCPool, highYieldCorpUSDCFixedTermLoans, highYieldCorpUSDCOpenTermLoans);
    // }

    // function testFork_validationLifecycle_highYieldCorpWeth(uint256 seed_) external {
    //     runLifecycleValidation(seed_, highYieldCorpWETHPool, highYieldCorpWETHFixedTermLoans, highYieldCorpWETHOpenTermLoans);
    // }

    // function testFork_validationLifecycle_securedLending(uint256 seed_) external {
    //     runLifecycleValidation(seed_, securedLendingUSDCPool, securedLendingUSDCFixedTermLoans, securedLendingUSDCOpenTermLoans);
    // }

    /**************************************************************************************************************************************/
    /*** Lifecycle Setup                                                                                                                ***/
    /**************************************************************************************************************************************/

    function runLifecycleValidation(uint256 seed_, address pool, address[] storage ftls, address[] storage otls) internal {
        setAddresses(pool);

        _collateralAsset      = usdc;
        _feeManager           = feeManager;
        _fixedTermLoanFactory = fixedTermLoanFactoryV2;
        _openTermLoanFactory  = openTermLoanFactory;
        _liquidatorFactory    = liquidatorFactory;

        address depositor    = makeAddr("depositor");
        uint256 decimals     = IPool(_pool).decimals();
        uint256 liquidityCap = 500_000_000 * 10 ** decimals;
        uint256 liquidity    = 250_000_000 * 10 ** decimals;

        if (_fundsAsset == WETH) {
            liquidity /= 1_000;
        }

        setLiquidityCap(_poolManager, liquidityCap);
        deposit(pool, depositor, liquidity);

        // Add existing loans to the array so they can be paid back at the end of the lifecycle.
        for (uint256 i; i < ftls.length; ++i) {
            loans.push(ftls[i]);
        }

        for (uint256 i; i < otls.length; ++i) {
            loans.push(otls[i]);
        }

        uint256 newFtlCount = ftls.length < ftlCount ? ftlCount - ftls.length : 0;
        uint256 newOtlCount = otls.length < otlCount ? otlCount - otls.length : 0;

        super.fuzzedSetup(newFtlCount, newOtlCount, loanActionCount, strategyActionCount, seed_);

        ProtocolHealthChecker protocolHealthChecker = new ProtocolHealthChecker();

        // ProtocolHealthChecker.Invariants memory protocolInvariants = protocolHealthChecker.checkInvariants(address(_poolManager));

        // assertProtocolHealthChecker(protocolInvariants);
    }

    /**************************************************************************************************************************************/
    /*** Assertion Helpers                                                                                                              ***/
    /**************************************************************************************************************************************/

    function assertProtocolHealthChecker(ProtocolHealthChecker.Invariants memory invariants_) internal {
        assertTrue(invariants_.fixedTermLoanManagerInvariantA,      "ProtocolHealthChecker FTLM Invariant A");
        assertTrue(invariants_.fixedTermLoanManagerInvariantB,      "ProtocolHealthChecker FTLM Invariant B");
        assertTrue(invariants_.fixedTermLoanManagerInvariantF,      "ProtocolHealthChecker FTLM Invariant F");
        assertTrue(invariants_.fixedTermLoanManagerInvariantI,      "ProtocolHealthChecker FTLM Invariant I");
        assertTrue(invariants_.fixedTermLoanManagerInvariantJ,      "ProtocolHealthChecker FTLM Invariant J");
        assertTrue(invariants_.fixedTermLoanManagerInvariantK,      "ProtocolHealthChecker FTLM Invariant K");
        assertTrue(invariants_.openTermLoanManagerInvariantE,       "ProtocolHealthChecker OTLM Invariant E");
        assertTrue(invariants_.openTermLoanManagerInvariantG,       "ProtocolHealthChecker OTLM Invariant G");
        assertTrue(invariants_.poolInvariantA,                      "ProtocolHealthChecker Pool Invariant A");
        assertTrue(invariants_.poolInvariantD,                      "ProtocolHealthChecker Pool Invariant D");
        assertTrue(invariants_.poolInvariantE,                      "ProtocolHealthChecker Pool Invariant E");
        assertTrue(invariants_.poolInvariantI,                      "ProtocolHealthChecker Pool Invariant I");
        assertTrue(invariants_.poolInvariantJ,                      "ProtocolHealthChecker Pool Invariant J");
        assertTrue(invariants_.poolInvariantK,                      "ProtocolHealthChecker Pool Invariant K");
        assertTrue(invariants_.poolManagerInvariantA,               "ProtocolHealthChecker PM Invariant A");
        assertTrue(invariants_.poolManagerInvariantB,               "ProtocolHealthChecker PM Invariant B");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantC, "ProtocolHealthChecker WM Invariant C");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantD, "ProtocolHealthChecker WM Invariant D");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantE, "ProtocolHealthChecker WM Invariant E");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantM, "ProtocolHealthChecker WM Invariant M");
        assertTrue(invariants_.withdrawalManagerCyclicalInvariantN, "ProtocolHealthChecker WM Invariant N");
    }

}

