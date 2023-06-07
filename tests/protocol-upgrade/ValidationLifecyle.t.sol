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

contract ValidationLifecycleTestsBase is ProtocolUpgradeBase, FuzzedUtil {

    uint256 constant ALLOWED_DIFF = 1000;

    uint256 actionCount  = 10;
    uint256 ftlLoanCount = 1;
    uint256 otlLoanCount = 3;

    FixedTermLoanHealthChecker fixedTermLoanHealthChecker;
    OpenTermLoanHealthChecker  openTermLoanHealthChecker;
    ProtocolHealthChecker      protocolHealthChecker;

    // Overriding fuzzed setups to work well with the deployed contracts.
    function fuzzedSetup(address pool, address[] storage deployedLoans) internal {
        uint256 decimals = pool == mavenWethPool ? 18 : 6;

        setLiquidityCap(_poolManager, 500_000_000 * 10 ** decimals);
        deposit(pool, makeAddr("lp"), decimals == 18 ? 400_000 * 10 ** decimals : 400_000_000 * 10 ** decimals);

        // Add loans to array so they can be paid back at the end of the lifecycle.
        for (uint256 i; i < deployedLoans.length; ++i) {
            loans.push(deployedLoans[i]);
        }

        // There's a need for more fixed term loans
        if (deployedLoans.length < ftlLoanCount) {
            // Create and fund fixed loans.
            for (uint256 i = deployedLoans.length ; i < ftlLoanCount; ++i) {
                vm.warp(block.timestamp + 1 days);
                createAndFundLoan(createSomeFixedTermLoan);
            }
        }

        // Create and fund open loans.
        for (uint256 i; i < otlLoanCount; ++i) {
            vm.warp(block.timestamp + 1 days);
            createAndFundLoan(createSomeOpenTermLoan);
        }

        // Perform random loan actions.
        for (uint256 i; i < actionCount; ++i) {
            // Get loan and due date of active loan with earliest due date.
            ( address loan, uint256 dueDate ) = getEarliestDueDate();

            // If no active loans are remaining: no further actions can be performed.
            if (loan == address(0)) return;

            uint256 maxDate = dueDate < block.timestamp
                ? 1 days
                : (dueDate - block.timestamp) + 10 days;

            // Warp to anytime from 1 day from now to 11 days past the loan's due date.
            vm.warp(block.timestamp + 1 days + getSomeValue(0, maxDate));

            performSomeLoanAction(loan);

            if (ILoanLike(loan).principal() == 0) {
                removeLoan(loan);
            }
        }
    }

    function runLifecycleValidation(uint256 seed_, address pool, address[] storage loans) internal {
        seed = seed_;

        // For each pool, setUp the necessary addresses
        setAddresses(pool);

        _collateralAsset      = address(weth);
        _feeManager           = address(fixedTermFeeManagerV1);
        _fixedTermLoanFactory = address(fixedTermLoanFactory);
        _liquidatorFactory    = address(liquidatorFactory);
        _openTermLoanFactory  = address(openTermLoanFactory);

        // Do the fuzzed transactions
        fuzzedSetup(_pool, loans);

        // Assert the invariants
        fixedTermLoanHealthChecker = new FixedTermLoanHealthChecker();
        openTermLoanHealthChecker  = new OpenTermLoanHealthChecker();
        protocolHealthChecker      = new ProtocolHealthChecker();

        FixedTermLoanHealthChecker.Invariants memory FTLInvariants =
            fixedTermLoanHealthChecker.checkInvariants(address(_poolManager), getAllActiveFixedTermLoans());

        OpenTermLoanHealthChecker.Invariants memory OTLInvariants =
            openTermLoanHealthChecker.checkInvariants(address(_poolManager), getAllActiveOpenTermLoans());

        ProtocolHealthChecker.Invariants memory protocolInvariants = protocolHealthChecker.checkInvariants(address(_poolManager));

        assertFixedTermLoanHealthChecker(FTLInvariants);
        assertOpenTermLoanHealthChecker(OTLInvariants);
        assertProtocolHealthChecker(protocolInvariants);

        // Wind down pool
        ( uint256 lastDomainStartFTLM, uint256 lastDomainStartOTLM ) = payOffLoansAndRedeemAllLps();

        for (uint256 i = 0; i < lps.length; i++) {
            assertEq(IERC20(address(_pool)).balanceOf(lps[i]), 0);
        }

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
    }

    /**************************************************************************************************************************************/
    /*** Assertion Helpers                                                                                                              ***/
    /**************************************************************************************************************************************/

    // TODO: Make Test Base with Assertions Stateless and move all assertion helpers together
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

    // TODO: Need to use current Lps  any have them all redeem to assert this.
    function assertPoolStateWithDiff(
        address pool,
        address poolManager,
        uint256 totalAssets,
        uint256 totalSupply,
        uint256 unrealizedLosses,
        uint256 availableLiquidity,
        uint256 diff
    )
        internal
    {
        assertApproxEqAbs(IPool(pool).totalAssets(),                            totalAssets,        diff, "totalAssets");
        assertApproxEqAbs(IPool(pool).totalSupply(),                            totalSupply,        diff, "totalSupply");
        assertApproxEqAbs(IPool(pool).unrealizedLosses(),                       unrealizedLosses,   diff, "unrealizedLosses");
        assertApproxEqAbs(IPoolManager(poolManager).totalAssets(),              totalAssets,        diff, "totalAssets");
        assertApproxEqAbs(IPoolManager(poolManager).unrealizedLosses(),         unrealizedLosses,   diff, "unrealizedLosses");
        assertApproxEqAbs(IERC20(IPool(pool).asset()).balanceOf(address(pool)), availableLiquidity, diff, "availableLiquidity");
    }

}

contract ValidationLifecycleBeforeProcedure is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17421835);

        // 1. Deploy all the new implementations and factories
        _deployAllNewContracts();

        // 2. Upgrade Globals, as the new version is needed to setup all the factories accordingly
        upgradeGlobals(mapleGlobalsProxy, globalsImplementationV2);

        // 3. Configure globals factories, instances, and deployers.
        _enableGlobalsKeys();

        // 4. Register the factories on globals and set the default versions.
        _setupFactories();

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsGovernor();

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();

        _addLoanManagers();
    }

    function test_validationLifecycle_beforeProcedure_mavenPermissioned(uint256 seed) external {
        runLifecycleValidation(seed, mavenPermissionedPool, mavenPermissionedLoans);
    }

    function test_validationLifecycle_beforeProcedure_mavenUsdcPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenUsdcPool, mavenUsdcLoans);
    }

    function test_validationLifecycle_beforeProcedure_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethLoans);
    }

    function test_validationLifecycle_beforeProcedure_orthogonalPool(uint256 seed) external {
        runLifecycleValidation(seed, orthogonalPool, orthogonalLoans);
    }

    function test_validationLifecycle_beforeProcedure_icebreakerPool(uint256 seed) external {
        runLifecycleValidation(seed, icebreakerPool, icebreakerLoans);
    }

    function test_validationLifecycle_beforeProcedure_aqruPool(uint256 seed) external {
        runLifecycleValidation(seed, aqruPool, aqruLoans);
    }

    function test_validationLifecycle_beforeProcedure_mavenUsdc3Pool(uint256 seed) external {
        runLifecycleValidation(seed, mavenUsdc3Pool, mavenUsdc3Loans);
    }

    function test_validationLifecycle_beforeProcedure_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashMgmtPool, cashMgmtLoans);
    }

}

//TODO: Uncomment and use when each txn is done as it will fail CI for now
contract ValidationLifecycleAfterDeployment is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17421835);

        // 2. Upgrade Globals, as the new version is needed to setup all the factories accordingly
        upgradeGlobals(mapleGlobalsProxy, globalsImplementationV2);

        // 3. Configure globals factories, instances, and deployers.
        _enableGlobalsKeys();

        // 4. Register the factories on globals and set the default versions.
        _setupFactories();

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsGovernor();

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();

        _addLoanManagers();
    }

    function test_validationLifecycle_afterDeployment_mavenPermissioned(uint256 seed) external {
        runLifecycleValidation(seed, mavenPermissionedPool, mavenPermissionedLoans);
    }

    function test_validationLifecycle_afterDeployment_mavenUsdcPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenUsdcPool, mavenUsdcLoans);
    }

    function test_validationLifecycle_afterDeployment_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethLoans);
    }

    function test_validationLifecycle_afterDeployment_orthogonalPool(uint256 seed) external {
        runLifecycleValidation(seed, orthogonalPool, orthogonalLoans);
    }

    function test_validationLifecycle_afterDeployment_icebreakerPool(uint256 seed) external {
        runLifecycleValidation(seed, icebreakerPool, icebreakerLoans);
    }

    function test_validationLifecycle_afterDeployment_aqruPool(uint256 seed) external {
        runLifecycleValidation(seed, aqruPool, aqruLoans);
    }

    function test_validationLifecycle_afterDeployment_mavenUsdc3Pool(uint256 seed) external {
        runLifecycleValidation(seed, mavenUsdc3Pool, mavenUsdc3Loans);
    }

    function test_validationLifecycle_afterDeployment_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashMgmtPool, cashMgmtLoans);
    }

}

contract ValidationLifecycleAfterGlobalsUpgrade is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17421940);

        // 3. Configure globals factories, instances, and deployers.
        _enableGlobalsKeys();

        // 4. Register the factories on globals and set the default versions.
        _setupFactories();

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsGovernor();

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();

        _addLoanManagers();
    }

    function test_validationLifecycle_afterGlobalsUpgrade_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethLoans);
    }

    function test_validationLifecycle_afterGlobalsUpgrade_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashMgmtPool, cashMgmtLoans);
    }

}

contract ValidationLifecycleAfterEnablingGlobalsKeys is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17421973);

        // 4. Register the factories on globals and set the default versions.
        _setupFactories();

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsGovernor();

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();

        _addLoanManagers();
    }

    function test_validationLifecycle_enablingGlobalsKey_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethLoans);
    }

    function test_validationLifecycle_enablingGlobalsKey_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashMgmtPool, cashMgmtLoans);
    }

}

contract ValidationLifecycleAfterSetupFactories is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17422018);

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsGovernor();

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();

        _addLoanManagers();
    }

    function test_validationLifecycle_setupFactories_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethLoans);
    }

    function test_validationLifecycle_setupFactories_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashMgmtPool, cashMgmtLoans);
    }

}

contract ValidationLifecycleAfterPoolUpgrades is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17422049);

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();

        _addLoanManagers();
    }

    function test_validationLifecycle_poolUpgrades_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethLoans);
    }

    function test_validationLifecycle_poolUpgrades_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashMgmtPool, cashMgmtLoans);
    }

}

contract ValidationLifecycleAfterLoanUpgrades is ValidationLifecycleTestsBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17422134);

        _addLoanManagers();
    }

    function test_validationLifecycle_loanUpgrades_mavenPermissioned(uint256 seed) external {
        runLifecycleValidation(seed, mavenPermissionedPool, mavenPermissionedLoans);
    }

    function test_validationLifecycle_loanUpgrades_mavenUsdcPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenUsdcPool, mavenUsdcLoans);
    }

    function test_validationLifecycle_loanUpgrades_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethLoans);
    }

    function test_validationLifecycle_loanUpgrades_orthogonalPool(uint256 seed) external {
        runLifecycleValidation(seed, orthogonalPool, orthogonalLoans);
    }

    function test_validationLifecycle_loanUpgrades_icebreakerPool(uint256 seed) external {
        runLifecycleValidation(seed, icebreakerPool, icebreakerLoans);
    }

    function test_validationLifecycle_loanUpgrades_aqruPool(uint256 seed) external {
        runLifecycleValidation(seed, aqruPool, aqruLoans);
    }

    function test_validationLifecycle_loanUpgrades_mavenUsdc3Pool(uint256 seed) external {
        runLifecycleValidation(seed, mavenUsdc3Pool, mavenUsdc3Loans);
    }

    function test_validationLifecycle_loanUpgrades_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashMgmtPool, cashMgmtLoans);
    }

}
