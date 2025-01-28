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

import { ProtocolHealthChecker }      from "../health-checkers/ProtocolHealthChecker.sol";
import { FixedTermLoanHealthChecker } from "../health-checkers/FixedTermLoanHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "../health-checkers/OpenTermLoanHealthChecker.sol";
import { LPHealthChecker }            from "../health-checkers/LPHealthChecker.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract ValidationLifecycleETH is ProtocolUpgradeBase, FuzzedUtil {

    uint256 ftlCount = 3;
    uint256 otlCount = 3;

    uint256 loanActionCount     = 10;
    uint256 strategyActionCount = 10;

    ProtocolHealthChecker      protocolHealthChecker_;
    FixedTermLoanHealthChecker fixedTermLoanHealthChecker_;
    OpenTermLoanHealthChecker  openTermLoanHealthChecker_;
    LPHealthChecker            lpHealthChecker_;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21646000);

        upgradeProtocol();

        protocolHealthChecker_      = new ProtocolHealthChecker();
        fixedTermLoanHealthChecker_ = new FixedTermLoanHealthChecker();
        openTermLoanHealthChecker_  = new OpenTermLoanHealthChecker();
        lpHealthChecker_            = new LPHealthChecker();
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    function testFork_validationLifecycle_aqru(uint256 seed_) external {
        runLifecycleValidation(seed_, aqruPool, aqruAllowedLenders, aqruFixedTermLoans, aqruOpenTermLoans);
    }

    function testFork_validationLifecycle_blueChipSecuredUsdc(uint256 seed_) external {
        runLifecycleValidation(seed_, blueChipSecuredUSDCPool, blueChipAllowedLenders, blueChipFixedTermLoans, blueChipOpenTermLoans);
    }

    function testFork_validationLifecycle_cashUsdc(uint256 seed_) external {
        runLifecycleValidation(seed_, cashUSDCPool, cashUSDCAllowedLenders, cashUSDCFixedTermLoans, cashUSDCOpenTermLoans);
    }

    function testFork_validationLifecycle_highYieldCorpUsdc(uint256 seed_) external {
        runLifecycleValidation(seed_, highYieldCorpUSDCPool, highYieldCorpUSDCAllowedLenders, highYieldCorpUSDCFixedTermLoans, highYieldCorpUSDCOpenTermLoans);
    }

    // Skipping this for now as the fuzzed util doesn't play nicely with WETH.
    function skip_testFork_validationLifecycle_highYieldCorpWeth(uint256 seed_) external {
        runLifecycleValidation(seed_, highYieldCorpWETHPool, highYieldCorpWETHAllowedLenders, highYieldCorpWETHFixedTermLoans, highYieldCorpWETHOpenTermLoans);
    }

    function testFork_validationLifecycle_securedLendingUsdc(uint256 seed_) external {
        runLifecycleValidation(seed_, securedLendingUSDCPool, securedLendingUSDCAllowedLenders, securedLendingUSDCFixedTermLoans, securedLendingUSDCOpenTermLoans);
    }

    function testFork_validationLifecycle_syrupUsdc(uint256 seed_) external {
        runLifecycleValidation(seed_, syrupUSDCPool, syrupUSDCAllowedLenders, syrupUSDCFixedTermLoans, syrupUSDCOpenTermLoans);
    }

    function testFork_validationLifecycle_syrupUsdt(uint256 seed_) external {
        runLifecycleValidation(seed_, syrupUSDTPool, syrupUSDTAllowedLenders, syrupUSDTFixedTermLoans, syrupUSDTOpenTermLoans);
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Setup                                                                                                                ***/
    /**************************************************************************************************************************************/

    function runLifecycleValidation(uint256 seed_, address pool, address[] storage lenders, address[] storage ftls, address[] storage otls) internal {
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

        lps.push(depositor);

        for (uint256 i; i < lenders.length; ++i) {
            lps.push(lenders[i]);
        }

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

        _checkProtocolInvariants(_poolManager);
        _checkFixedTermLoanInvariants(_poolManager, getAllActiveFixedTermLoans());
        _checkOpenTermLoanInvariants(_poolManager, getAllActiveOpenTermLoans());
    }

    /**************************************************************************************************************************************/
    /*** Invariant Assertions                                                                                                            ***/
    /**************************************************************************************************************************************/

    function _checkFixedTermLoanInvariants(address poolManager_, address[] memory loans_) internal {
        FixedTermLoanHealthChecker.Invariants memory results;

        results = fixedTermLoanHealthChecker_.checkInvariants(poolManager_, loans_);

        assertTrue(results.fixedTermLoanInvariantA);
        assertTrue(results.fixedTermLoanInvariantB);
        assertTrue(results.fixedTermLoanInvariantC);
        assertTrue(results.fixedTermLoanManagerInvariantD);
        assertTrue(results.fixedTermLoanManagerInvariantE);
        assertTrue(results.fixedTermLoanManagerInvariantM);
        assertTrue(results.fixedTermLoanManagerInvariantN);
    }

    function _checkLPInvariants(address poolManager_, address[] memory lenders_) internal {
        LPHealthChecker.Invariants memory results;

        results = lpHealthChecker_.checkInvariants(poolManager_, lenders_);

        assertTrue(results.poolInvariantB);
        assertTrue(results.poolInvariantG);
        assertTrue(results.withdrawalManagerCyclicalInvariantA);
        assertTrue(results.withdrawalManagerCyclicalInvariantB);
        assertTrue(results.withdrawalManagerCyclicalInvariantF);
        assertTrue(results.withdrawalManagerCyclicalInvariantG);
        assertTrue(results.withdrawalManagerCyclicalInvariantH);
        assertTrue(results.withdrawalManagerCyclicalInvariantI);
        assertTrue(results.withdrawalManagerCyclicalInvariantJ);
        assertTrue(results.withdrawalManagerCyclicalInvariantK);
        assertTrue(results.withdrawalManagerCyclicalInvariantL);
        assertTrue(results.withdrawalManagerQueueInvariantC);
        assertTrue(results.withdrawalManagerQueueInvariantG);
        assertTrue(results.withdrawalManagerQueueInvariantH);
    }

    function _checkOpenTermLoanInvariants(address poolManager_, address[] memory loans_) internal {
        OpenTermLoanHealthChecker.Invariants memory results;

        results = openTermLoanHealthChecker_.checkInvariants(poolManager_, loans_);

        assertTrue(results.openTermLoanInvariantA, "OTL A");
        assertTrue(results.openTermLoanInvariantB, "OTL B");
        assertTrue(results.openTermLoanInvariantC, "OTL C");
        assertTrue(results.openTermLoanInvariantD, "OTL D");
        assertTrue(results.openTermLoanInvariantE, "OTL E");
        assertTrue(results.openTermLoanInvariantF, "OTL F");
        assertTrue(results.openTermLoanInvariantG, "OTL G");
        assertTrue(results.openTermLoanInvariantH, "OTL H");
        assertTrue(results.openTermLoanInvariantI, "OTL I");
        assertTrue(results.openTermLoanManagerInvariantA, "OTL LM A");
        assertTrue(results.openTermLoanManagerInvariantB, "OTL LM B");
        assertTrue(results.openTermLoanManagerInvariantC, "OTL LM C");
        assertTrue(results.openTermLoanManagerInvariantD, "OTL LM D");
        assertTrue(results.openTermLoanManagerInvariantF, "OTL LM F");
        assertTrue(results.openTermLoanManagerInvariantH, "OTL LM H");
        assertTrue(results.openTermLoanManagerInvariantI, "OTL LM I");
        assertTrue(results.openTermLoanManagerInvariantJ, "OTL LM J");
        assertTrue(results.openTermLoanManagerInvariantK, "OTL LM K");
    }

    function _checkProtocolInvariants(address poolManager_) internal {
        ProtocolHealthChecker.Invariants memory results;

        results = protocolHealthChecker_.checkInvariants(poolManager_);

        assertTrue(results.fixedTermLoanManagerInvariantA);
        assertTrue(results.fixedTermLoanManagerInvariantB);
        assertTrue(results.fixedTermLoanManagerInvariantF);
        assertTrue(results.fixedTermLoanManagerInvariantI);
        assertTrue(results.fixedTermLoanManagerInvariantJ);
        assertTrue(results.fixedTermLoanManagerInvariantK);
        assertTrue(results.openTermLoanManagerInvariantE);
        assertTrue(results.openTermLoanManagerInvariantG);
        assertTrue(results.poolInvariantA);
        assertTrue(results.poolInvariantD);
        assertTrue(results.poolInvariantE);
        assertTrue(results.poolInvariantI);
        assertTrue(results.poolInvariantJ);
        assertTrue(results.poolInvariantK);
        assertTrue(results.poolManagerInvariantA);
        assertTrue(results.poolManagerInvariantB);
        assertTrue(results.poolPermissionManagerInvariantA);
        assertTrue(results.withdrawalManagerCyclicalInvariantC);
        assertTrue(results.withdrawalManagerCyclicalInvariantD);
        assertTrue(results.withdrawalManagerCyclicalInvariantE);
        assertTrue(results.withdrawalManagerCyclicalInvariantM);
        assertTrue(results.withdrawalManagerCyclicalInvariantN);
        assertTrue(results.withdrawalManagerQueueInvariantA);
        assertTrue(results.withdrawalManagerQueueInvariantB);
        assertTrue(results.withdrawalManagerQueueInvariantD);
        assertTrue(results.withdrawalManagerQueueInvariantE);
        assertTrue(results.withdrawalManagerQueueInvariantF);
        assertTrue(results.withdrawalManagerQueueInvariantI);
        assertTrue(results.strategiesInvariantA);
        assertTrue(results.strategiesInvariantB);
        assertTrue(results.strategiesInvariantC);
        assertTrue(results.strategiesInvariantD);
        assertTrue(results.strategiesInvariantE);
        assertTrue(results.strategiesInvariantF);
        assertTrue(results.strategiesInvariantG);
    }

}

