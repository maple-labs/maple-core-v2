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

import { FuzzedUtil } from "../fuzz/FuzzedSetup.sol";

import { FixedTermLoanHealthChecker } from "../health-checkers/FixedTermLoanHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "../health-checkers/OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "../health-checkers/ProtocolHealthChecker.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

// TODO: Need to uncouple cycle wm from protocolHealthChecker and add back
contract ValidationLifecycleTestsBase is ProtocolUpgradeBase, FuzzedUtil {

    uint256 constant ALLOWED_DIFF = 1000;

    uint256 actionCount  = 10;
    uint256 ftlLoanCount = 3;
    uint256 otlLoanCount = 3;

    FixedTermLoanHealthChecker fixedTermLoanHealthChecker;
    OpenTermLoanHealthChecker  openTermLoanHealthChecker;
    ProtocolHealthChecker      protocolHealthChecker_;

    // Overriding fuzzed setups to work well with the deployed contracts.
    function fuzzedSetup(address pool, address[] storage deployedFTLs, address[] storage deployedOTLs) internal {
        uint256 decimals = pool == mavenWethPool ? 18 : 6;

        setLiquidityCap(_poolManager, 500_000_000 * 10 ** decimals);
        deposit(pool, makeAddr("lp"), decimals == 18 ? 400_000 * 10 ** decimals : 40_000_000 * 10 ** decimals);

        // Add loans to array so they can be paid back at the end of the lifecycle.
        for (uint256 i; i < deployedFTLs.length; ++i) {
            loans.push(deployedFTLs[i]);
        }

        for (uint256 i; i < deployedOTLs.length; ++i) {
            loans.push(deployedOTLs[i]);
        }

        uint256 remainingFTLs = deployedFTLs.length > ftlLoanCount ? 0 : ftlLoanCount - deployedFTLs.length;
        uint256 remainingOTLs = deployedOTLs.length > otlLoanCount ? 0 : otlLoanCount - deployedOTLs.length;

        super.fuzzedSetup(remainingFTLs, remainingOTLs, actionCount, seed);
    }

    function runLifecycleValidation(uint256 seed_, address pool, address[] storage deployedFTLs, address[] storage deployedOTLs) internal {
        seed = seed_;

        // For each pool, setUp the necessary addresses
        setAddresses(pool);

        _collateralAsset      = address(weth);
        _feeManager           = address(fixedTermFeeManagerV1);
        _fixedTermLoanFactory = address(fixedTermLoanFactoryV2);
        _openTermLoanFactory  = address(openTermLoanFactory);
        _liquidatorFactory    = address(liquidatorFactory);

        // Do the fuzzed transactions
        fuzzedSetup(_pool, deployedFTLs, deployedOTLs);

        // Assert the invariants
        fixedTermLoanHealthChecker = new FixedTermLoanHealthChecker();
        openTermLoanHealthChecker  = new OpenTermLoanHealthChecker();
        // protocolHealthChecker_     = new ProtocolHealthChecker();
        FixedTermLoanHealthChecker.Invariants memory FTLInvariants =
            fixedTermLoanHealthChecker.checkInvariants(address(_poolManager), getAllActiveFixedTermLoans());

        OpenTermLoanHealthChecker.Invariants memory OTLInvariants =
            openTermLoanHealthChecker.checkInvariants(address(_poolManager), getAllActiveOpenTermLoans());

        // ProtocolHealthChecker.Invariants memory protocolInvariants = protocolHealthChecker_.checkInvariants(address(_poolManager));

        assertFixedTermLoanHealthChecker(FTLInvariants);
        assertOpenTermLoanHealthChecker(OTLInvariants);
        // assertProtocolHealthChecker(protocolInvariants);

        ( uint256 lastDomainStartFTLM, uint256 lastDomainStartOTLM ) = payOffLoansAndRedeemAllLps();

        for (uint256 i = 0; i < lps.length; i++) {
            assertEq(IERC20(address(_pool)).balanceOf(lps[i]), 0);
        }

        assertFixedTermLoanManagerWithDiff({
            loanManager:       _fixedTermLoanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       lastDomainStartFTLM,
            domainEnd:         lastDomainStartFTLM,
            unrealizedLosses:  0,
            diff:              ALLOWED_DIFF
        });

        assertOpenTermLoanManagerWithDiff({
            loanManager:       _openTermLoanManager,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       lastDomainStartOTLM,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0,
            diff:              ALLOWED_DIFF
        });
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
        assertTrue(invariants_.fixedTermLoanManagerInvariantA, "ProtocolHealthChecker FTLM Invariant A");
        assertTrue(invariants_.fixedTermLoanManagerInvariantB, "ProtocolHealthChecker FTLM Invariant B");
        assertTrue(invariants_.fixedTermLoanManagerInvariantF, "ProtocolHealthChecker FTLM Invariant F");
        assertTrue(invariants_.fixedTermLoanManagerInvariantI, "ProtocolHealthChecker FTLM Invariant I");
        assertTrue(invariants_.fixedTermLoanManagerInvariantJ, "ProtocolHealthChecker FTLM Invariant J");
        assertTrue(invariants_.fixedTermLoanManagerInvariantK, "ProtocolHealthChecker FTLM Invariant K");
        assertTrue(invariants_.openTermLoanManagerInvariantE,  "ProtocolHealthChecker OTLM Invariant E");
        assertTrue(invariants_.openTermLoanManagerInvariantG,  "ProtocolHealthChecker OTLM Invariant G");
        assertTrue(invariants_.poolInvariantA,                 "ProtocolHealthChecker Pool Invariant A");
        assertTrue(invariants_.poolInvariantD,                 "ProtocolHealthChecker Pool Invariant D");
        assertTrue(invariants_.poolInvariantE,                 "ProtocolHealthChecker Pool Invariant E");
        assertTrue(invariants_.poolInvariantI,                 "ProtocolHealthChecker Pool Invariant I");
        assertTrue(invariants_.poolInvariantJ,                 "ProtocolHealthChecker Pool Invariant J");
        assertTrue(invariants_.poolInvariantK,                 "ProtocolHealthChecker Pool Invariant K");
        assertTrue(invariants_.poolManagerInvariantA,          "ProtocolHealthChecker PM Invariant A");
        assertTrue(invariants_.poolManagerInvariantB,          "ProtocolHealthChecker PM Invariant B");
        assertTrue(invariants_.withdrawalManagerInvariantC,    "ProtocolHealthChecker WM Invariant C");
        assertTrue(invariants_.withdrawalManagerInvariantD,    "ProtocolHealthChecker WM Invariant D");
        assertTrue(invariants_.withdrawalManagerInvariantE,    "ProtocolHealthChecker WM Invariant E");
        assertTrue(invariants_.withdrawalManagerInvariantM,    "ProtocolHealthChecker WM Invariant M");
        assertTrue(invariants_.withdrawalManagerInvariantN,    "ProtocolHealthChecker WM Invariant N");
    }

    function assertFixedTermLoanManagerWithDiff(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainEnd,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses,
        uint256 diff
    ) internal {
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).accountedInterest(), accountedInterest, diff, "accountedInterest");
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).accruedInterest(),   accruedInterest,   diff, "accruedInterest");
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).domainEnd(),         domainEnd,         diff, "domainEnd");
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).domainStart(),       domainStart,       diff, "domainStart");
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).issuanceRate(),      issuanceRate,      diff, "issuanceRate");
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).principalOut(),      principalOut,      diff, "principalOut");
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).unrealizedLosses(),  unrealizedLosses,  diff, "unrealizedLosses");

        assertApproxEqAbs(
            IFixedTermLoanManager(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            diff,
            "assetsUnderManagement"
        );
    }

    function assertOpenTermLoanManagerWithDiff(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses,
        uint256 diff
    ) internal {
        assertApproxEqAbs(IOpenTermLoanManager(loanManager).accountedInterest(), accountedInterest, diff, "accountedInterest");
        assertApproxEqAbs(IOpenTermLoanManager(loanManager).accruedInterest(),   accruedInterest,   diff, "accruedInterest");
        assertApproxEqAbs(IOpenTermLoanManager(loanManager).domainStart(),       domainStart,       diff, "domainStart");
        assertApproxEqAbs(IOpenTermLoanManager(loanManager).issuanceRate(),      issuanceRate,      diff, "issuanceRate");
        assertApproxEqAbs(IOpenTermLoanManager(loanManager).principalOut(),      principalOut,      diff, "principalOut");
        assertApproxEqAbs(IOpenTermLoanManager(loanManager).unrealizedLosses(),  unrealizedLosses,  diff, "unrealizedLosses");

        assertApproxEqAbs(
            IOpenTermLoanManager(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            diff,
            "assetsUnderManagement"
        );
    }

}

contract ValidationLifecycle is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18421300);

        // 1. Deploy all the new implementations and factories
        _deployAllNewContracts();

        // 2. Upgrade Globals, as the new version is needed to setup all the factories accordingly
        upgradeGlobals(globals, globalsImplementationV3);

        // 3. Configure globals factories, instances, and deployer.
        _enableGlobalsKeys();

        // 4. Register the factories on globals and set the default versions.
        _setupFactories();

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsSecurityAdmin();

        _addWMAndPMToAllowlists();

        _addLoanManagers();
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_aqruPool(uint256 seed_) external {
        runLifecycleValidation(seed_, aqruPool, aqruFixedTermLoans, aqruOpenTermLoans);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_cashMgmtUSDCPool(uint256 seed_) external {
        runLifecycleValidation(seed_, cashManagementUSDCPool, cashMgmtUSDCFixedTermLoans, cashMgmtUSDCOpenTermLoans);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_cashMgmtUSDTPool(uint256 seed_) external {
        runLifecycleValidation(seed_, cashManagementUSDTPool, cashMgmtUSDTFixedTermLoans, cashMgmtUSDTOpenTermLoans);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_cicadaPool(uint256 seed_) external {
        ftlLoanCount = 0;
        runLifecycleValidation(seed_, cicadaPool, cicadaFixedTermLoans, cicadaOpenTermLoans);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_mapleDirectPool(uint256 seed_) external {
        runLifecycleValidation(seed_, mapleDirectUSDCPool, mapleDirectFixedTermLoans, mapleDirectOpenTermLoans);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_mavenWethPool(uint256 seed_) external {
        runLifecycleValidation(seed_, mavenWethPool, mavenWethFixedTermLoans, mavenWethOpenTermLoans);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_mavenPermissioned(uint256 seed_) external {
        runLifecycleValidation(seed_, mavenPermissionedPool, mavenPermissionedFixedTermLoans, mavenPermissionedOpenTermLoans);
    }

}

contract ValidationLifecycleForCashMgt is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18421300);

        _performProtocolUpgrade();

        _upgradeToQueueWM(cashManagementUSDCPoolManager);
        _upgradeToQueueWM(cashManagementUSDTPoolManager);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_cash_USDC(uint256 seed_) external {
        runLifecycleValidation(seed_, cashManagementUSDCPool, cashMgmtUSDCFixedTermLoans, cashMgmtUSDCOpenTermLoans);
    }

    /// forge-config: default.fuzz.runs = 10
    function testFork_validationLifecycle_cash_USDT(uint256 seed_) external {
        runLifecycleValidation(seed_, cashManagementUSDTPool, cashMgmtUSDTFixedTermLoans, cashMgmtUSDTOpenTermLoans);
    }

}
