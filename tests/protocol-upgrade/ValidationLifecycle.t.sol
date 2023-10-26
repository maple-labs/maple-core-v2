// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IFixedTermLoanManager,
    IPool,
    IPoolManager,
    ILoanLike
} from "../../contracts/interfaces/Interfaces.sol";

import { FuzzedUtil } from "../fuzz/FuzzedSetup.sol";

import { FixedTermLoanHealthChecker } from "../health-checkers/FixedTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "../health-checkers/ProtocolHealthChecker.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

// TODO: Add OTL Healthchecker and assert invariants
contract ValidationLifecycleTestsBase is ProtocolUpgradeBase, FuzzedUtil {

    uint256 constant ALLOWED_DIFF = 1000;

    uint256 actionCount  = 10;
    uint256 ftlLoanCount = 3;
    uint256 otlLoanCount = 3;

    FixedTermLoanHealthChecker fixedTermLoanHealthChecker;
    ProtocolHealthChecker      protocolHealthChecker_;

    // Overriding fuzzed setups to work well with the deployed contracts.
    function fuzzedSetup(address pool, address[] storage deployedLoans) internal {
        uint256 decimals = pool == mavenWethPool ? 18 : 6;

        setLiquidityCap(_poolManager, 500_000_000 * 10 ** decimals);
        deposit(pool, makeAddr("lp"), decimals == 18 ? 400_000 * 10 ** decimals : 40_000_000 * 10 ** decimals);

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
        _fixedTermLoanFactory = address(fixedTermLoanFactoryV2);
        _liquidatorFactory    = address(liquidatorFactory);

        // Do the fuzzed transactions
        fuzzedSetup(_pool, loans);

        // Assert the invariants
        fixedTermLoanHealthChecker = new FixedTermLoanHealthChecker();
        protocolHealthChecker_     = new ProtocolHealthChecker();

        FixedTermLoanHealthChecker.Invariants memory FTLInvariants =
            fixedTermLoanHealthChecker.checkInvariants(address(_poolManager), getAllActiveFixedTermLoans());

        ProtocolHealthChecker.Invariants memory protocolInvariants = protocolHealthChecker_.checkInvariants(address(_poolManager));

        assertFixedTermLoanHealthChecker(FTLInvariants);
        assertProtocolHealthChecker(protocolInvariants);

        ( uint256 lastDomainStartFTLM, ) = payOffLoansAndRedeemAllLps();

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

    function testFork_validationLifecycle_aqruPool(uint256 seed) external {
        runLifecycleValidation(seed, aqruPool, aqruFixedTermLoans);
    }

    function testFork_validationLifecycle_cashMgmtPool(uint256 seed) external {
        runLifecycleValidation(seed, cashManagementUSDCPool, cashMgmtFixedTermLoans);
    }

    function testFork_validationLifecycle_mavenWethPool(uint256 seed) external {
        runLifecycleValidation(seed, mavenWethPool, mavenWethFixedTermLoans);
    }

    function testFork_validationLifecycle_mavenPermissioned(uint256 seed) external {
        runLifecycleValidation(seed, mavenPermissionedPool, mavenPermissionedFixedTermLoans);
    }

}
