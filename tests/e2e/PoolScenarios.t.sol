// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../../modules/loan-v400/contracts/MapleLoan.sol";
import { Refinancer }        from "../../modules/loan-v400/contracts/Refinancer.sol";

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

contract PoolScenarioTests is TestBaseWithAssertions {

    function setUp() public override {
        super.setUp();

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });
    }

    // Test 11
    function test_poolScenario_fundLoanAndNeverTouchIt() external {
        // Create 3 actors
        address lp1 = address(new Address());
        address lp2 = address(new Address());
        address lp3 = address(new Address());

        depositLiquidity(lp1, 4_000_000e6);

        assertTotalAssets(4_000_000e6);
        assertEq(pool.balanceOf(lp1), 4_000_000e6);

        // This loan will be funded and then never interacted with again.
        Loan loan1 = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        // Warp to a little before the first loan1 payment is due.
        vm.warp(start + 800_000);

        assertTotalAssets(4_000_000e6 + 72_000e6);

        uint256 shares2 = depositLiquidity(lp2, 6_000_000e6);

        // Incoming assets * totalSupply / totalAssets
        assertEq(shares2, 6_000_000e6 * 4_000_000e6 / uint256(4_000_000e6 + 72_000e6));
        assertEq(shares2, 5_893_909.626719e6);

        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 72_000e6);

        address borrower2 = address(new Address());

        Loan loan2 = fundAndDrawdownLoan({
            borrower:    borrower2,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0.01e18), uint256(0), uint256(0)]
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     72_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_072_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 800_000,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 800_000,
            paymentDueDate:      start + 1_800_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // Loan 1 will be in a late state
        vm.warp(start + 1_600_000);

        // Deposits + 1e6s of loan1 at 0.09 IR and 200_000s of loan2 at 0.18 IR.
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 90_000e6 + 36_000e6);

        makePayment(loan2);

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR.s
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 90_000e6 + 180_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_090_000e6,
            issuanceRate:          0.15e6 * 1e30,
            domainStart:           start + 1_600_000,
            domainEnd:             start + 2_800_000,  // Loan 2 due date (funded at 800k)
            unrealizedLosses:      0
        });

        // Loan1 has been adjusted to be late
        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        vm.warp(start + 2_200_000);

        uint256 shares3 = depositLiquidity(lp3, 2_000_000e6);

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 600_00s of loan2 at 0.15 IR
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 90_000e6);

        Loan loan3 = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(4_000_000e6), uint256(4_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     180_000e6,  // 90_000e6 from loan1 and 90_000e6 of loan2 at 0.15 IR
            principalOut:          7_000_000e6,
            assetsUnderManagement: 7_180_000e6,
            issuanceRate:          0.51e6 * 1e30,
            domainStart:           start + 2_200_000,
            domainEnd:             start + 2_800_000,  // Loan 2 due date (funded at 800k)
            unrealizedLosses:      0
        });

        // Loan1 has still the same state.
        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        vm.warp(start + 2_400_000);

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR
        // + 800_00s of loan2 at 0.15 IR + 200_000s of loan3 at 0.36 IR
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 120_000e6 + 72_000e6);

        closeLoan(loan2);

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 1% of loan2 principal + 200_000s of loan3 at 0.36 IR
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 72_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     72_000e6 + 90_000e6,  // 72_000e6 from 200_000s of loan3 and 90_000e6 from loan1
            principalOut:          5_000_000e6,
            assetsUnderManagement: 5_162_000e6,
            issuanceRate:          0.36e6 * 1e30,
            domainStart:           start + 2_400_000,
            domainEnd:             start + 3_200_000,  // Loan 3 due date (funded at 2.2m)
            unrealizedLosses:      0
        });

        // LPs 1 and 2 request to withdraw all their shares
        vm.prank(lp1);
        pool.requestRedeem(4_000_000e6, lp1);

        vm.prank(lp2);
        pool.requestRedeem(shares2, lp2);

        vm.warp(start + 3_000_000);

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 1% of loan2 Principal + 800_000 of loan3 at 0.36 IR
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 288_000e6);

        makePayment(loan3);

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 1% of loan2 Principal + 1_000_000 of loan3 at 0.36 IR
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 360_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,           // 90_000e6 from loan1
            principalOut:          5_000_000e6,
            assetsUnderManagement: 5_090_000e6,
            issuanceRate:          0.30e6 * 1e30,
            domainStart:           start + 3_000_000,
            domainEnd:             start + 4_200_000,
            unrealizedLosses:      0
        });

        // LP3 request to withdraw
        vm.prank(lp3);
        pool.requestRedeem(shares3, lp3);

        vm.warp(start + 3_100_000);

        // Deposits + 90_000s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 1% of loan2 Principal
        // + 1_000_000 of loan3 at 0.36 IR + 100_000s of loan3 at 0.30
        uint256 totalAssets =  4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 360_000e6 + 30_000e6;
        assertTotalAssets(totalAssets);

        // Withdraw partial shares for lp1 and lp2.
        assertTrue( withdrawalManager.isInExitWindow(lp1));
        assertTrue( withdrawalManager.isInExitWindow(lp2));
        assertTrue(!withdrawalManager.isInExitWindow(lp3));

        {
            assertEq(withdrawalManager.totalCycleShares(withdrawalManager.getCurrentCycleId()), 4_000_000e6 + 5_893_909.626719e6);
            assertEq(pool.totalSupply(),                                                        11_803_930.790178e6);
            assertEq(fundsAsset.balanceOf(address(pool)),                                       7_558_000e6);

            // Requested shares * available liquidity / (total cycle shares * total assets / totalSupply)
            uint256 redeemableShares1 =
                4_000_000e6 * 7_558_000e6 / ((4_000_000e6 + 5_893_909.626719e6) * totalAssets / 11_803_930.790178e6);
            assertEq(redeemableShares1, 2_844_951.367431e6);

            vm.prank(lp1);
            uint256 assets1 = pool.redeem(4_000_000e6, lp1, lp1);

            assertEq(assets1, totalAssets * redeemableShares1 / 11_803_930.790178e6);
            assertEq(assets1, 3_055_617.156473e6);
        }

        // Remove withdrawn assets from total assets
        totalAssets =
            (4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 360_000e6 + 30_000e6) - 3_055_617.156473e6;
        assertTotalAssets(totalAssets);

        {
            assertEq(withdrawalManager.totalCycleShares(withdrawalManager.getCurrentCycleId()), 5_893_909.626719e6);
            assertEq(pool.totalSupply(),                                                        8_958_979.422747e6);
            assertEq(fundsAsset.balanceOf(address(pool)),                                       4_502_382.843527e6);

            // Requested shares * available liquidity / (total cycle shares * total assets / totalSupply)
            uint256 redeemableShares2 = 5_893_909.626719e6 * 4_502_382.843527e6 / (5_893_909.626719e6 * totalAssets / 8_958_979.422747e6);
            assertEq(redeemableShares2, 4_191_971.563013e6);

            vm.prank(lp2);
            uint256 assets2 = pool.redeem(shares2, lp2, lp2);

            assertEq(assets2, totalAssets * redeemableShares2 / 8_958_979.422747e6);
            assertEq(assets2, 4_502_382.843527e6);

            assertEq(fundsAsset.balanceOf(address(pool)), 0);  // All cash withdrawn
        }

        // Remove withdrawn assets from total assets
        totalAssets -= 4_502_382.843527e6;
        assertTotalAssets(totalAssets);

        // Make 2 loan payments in sequence
        makePayment(loan3);

        vm.warp(start + 3_200_000);

        makePayment(loan3);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,           // 90_000e6 from loan1
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,
            issuanceRate:          0,
            domainStart:           start + 3_200_000,
            domainEnd:             start + 3_200_000,
            unrealizedLosses:      0
        });

        // Deposits + 90_000s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 1% of loan2 Principal + 1_000_000 of loan3 at 0.36 IR + 100_000s of loan3 at 0.30 - withdrawn assets
        totalAssets =  (4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 360_000e6 + 360_000e6 + 360_000e6) - (3_055_617.156473e6 + 4_502_382.843527e6);
        assertTotalAssets(totalAssets);

        // At this point, both loan 2 and 3 are finalized. Now all LPs will proceed to withdraw their shares.
        vm.warp(withdrawalManager.getWindowStart(withdrawalManager.exitCycleId(lp3)));

        assertTrue(withdrawalManager.isInExitWindow(lp3));

        {
            assertEq(withdrawalManager.totalCycleShares(withdrawalManager.getCurrentCycleId()), 4_767_007.859734e6);
            assertEq(pool.totalSupply(),                                                        4_767_007.859734e6);
            assertEq(withdrawalManager.lockedShares(lp3),                                       1_910_021.163459e6);
            assertEq(fundsAsset.balanceOf(address(pool)),                                       4_720_000e6);

            // Requested shares * available liquidity / (total cycle shares * total assets / totalSupply)
            uint256 redeemableShares3 = 1_910_021.163459e6 * 4_720_000e6 / (4_767_007.859734e6 * totalAssets / 4_767_007.859734e6);
            assertEq(redeemableShares3, 1_551_686.728317e6);

            vm.prank(lp3);
            uint256 assets3 = pool.redeem(shares3, lp3, lp3);

            assertEq(assets3, (redeemableShares3 * totalAssets / 4_767_007.859734e6));
            assertEq(assets3, 1_891_186.286406e6);
        }

        totalAssets -= 1_891_186.286406e6;
        assertTotalAssets(totalAssets);

        {
            assertEq(withdrawalManager.totalCycleShares(withdrawalManager.getCurrentCycleId()), 2_856_986.696275e6);
            assertEq(pool.totalSupply(),                                                        3_215_321.131417e6);
            assertEq(fundsAsset.balanceOf(address(pool)),                                       2_828_813.713594e6);

            // Requested shares * available liquidity / (total cycle shares * total assets / totalSupply)
            uint256 redeemableShares1 = 1_155_048.632569e6 * 2_828_813.713594e6 / (2_856_986.696275e6 * totalAssets / 3_215_321.131417e6);
            assertEq(redeemableShares1, 938_352.761743e6);

            vm.prank(lp1);
            uint256 assets1 = pool.redeem(1_155_048.632569e6, lp1, lp1);  // Original lp1 shares - lp1 shares previously withdrawn

            assertEq(assets1, (redeemableShares1 * totalAssets / 3_215_321.131417e6));
            assertEq(assets1, 1_143_658.602239e6);
        }

        totalAssets -= 1_143_658.602239e6;
        assertTotalAssets(totalAssets);

        {
            assertEq(withdrawalManager.totalCycleShares(withdrawalManager.getCurrentCycleId()), 1_701_938.063706e6);
            assertEq(pool.totalSupply(),                                                        2_276_968.369674e6);
            assertEq(fundsAsset.balanceOf(address(pool)),                                       1_685_155.111355e6);

            // Requested shares * available liquidity / (total cycle shares * total assets / totalSupply)
            uint256 redeemableShares2 = 1701938.063706e6 * 1_685_155.111355e6 / (1_701_938.063706e6 * totalAssets / 2_276_968.369674e6);

            vm.prank(lp2);
            uint256 assets2 = pool.redeem(1701938.063706e6, lp2, lp2);  // Original lp2 shares - lp2 shares previously withdrawn

            assertEq(assets2, (totalAssets * redeemableShares2 / 2_276_968.369674e6));
            assertEq(assets2, 1_685_155.111355e6);

            assertEq(fundsAsset.balanceOf(address(pool)), 0);  // All cash withdrawn
        }

        totalAssets -= 1_685_155.111355e6;
        assertTotalAssets(totalAssets);

        assertEq(pool.totalAssets(), 1_090_000e6);  // Exact value of loan1

        assertEq(pool.totalSupply(), 894_326.775750e6);

        // Since the loan1 was never finalized, LPS still have a balance greater than 0,
        // but are locked in the withdrawal manager until they remove.
        assertEq(pool.balanceOf(address(withdrawalManager)), 894_326.775750e6);  // All funds are in WM
        assertEq(withdrawalManager.lockedShares(lp1),        216_695.870826e6);
        assertEq(withdrawalManager.lockedShares(lp2),        319_296.469782e6);
        assertEq(withdrawalManager.lockedShares(lp3),        358_334.435142e6);
    }

    // Test 12
    function test_poolScenario_loanWithVeryHighInterestRate() external {
        address lp1 = address(new Address());

        depositLiquidity(lp1, 4_000_000e6);

        assertTotalAssets(4_000_000e6);
        assertEq(pool.balanceOf(lp1), 4_000_000e6);

        // This loan will be funded and then never interacted with again.
        Loan loan1 = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e30), uint256(0.1e18), uint256(0), uint256(0)]
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          90_000_000_000e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000_000_000_000_000e6,
            refinanceInterest:   0,
            issuanceRate:        90_000_000_000e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000_000_000_000_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertTotalAssets(4_000_000e6);

        vm.warp(start + 800_000);

        assertTotalAssets(4_000_000e6 + 72_000_000_000_000_000e6);

        // Although the values here don't revert, if they were a bit higher, they would in the `getNextPaymentBreakdown` function.
        // Currently, the way out of the situation would be to either:
        // 1. Refinance using a custom refinancer that can manually alter the storage of the interest rate.
        // 2. Close the loan, paying only the closing interest.

        closeLoan(loan1);

        // TotalAssets went down due to the loan closure.
        assertTotalAssets(4_000_000e6 + 90_000e6);  // 1% of 1_000_000e6, removing management fees

        // Loan Manager should be in a coherent state
        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 800_000,
            domainEnd:             start + 800_000,
            unrealizedLosses:      0
        });

        assertLoanInfoWasDeleted(loan1);
    }

    // Test 13
    function test_poolScenario_loanWithZeroInterestRate() external {
        address lp1 = address(new Address());

        depositLiquidity(lp1, 4_000_000e6);

        assertTotalAssets(4_000_000e6);
        assertEq(pool.balanceOf(lp1), 4_000_000e6);

        // This loan will be funded and then never interacted with again.
        Loan loan1 = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0), uint256(0.1e18), uint256(0.01e18), uint256(0)]
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  0,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertTotalAssets(4_000_000e6);

        // Perform early payment
        vm.warp(start + 800_000);

        assertTotalAssets(4_000_000e6);

        makePayment(loan1);

        assertTotalAssets(4_000_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0,
            domainStart:           start + 800_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 800_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  0,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        // Second payment will be made late
        vm.warp(start + 2_100_000);

        assertTotalAssets(4_000_000e6);

        makePayment(loan1);

        assertTotalAssets(4_000_000e6 + 9_000e6);  // 1 day worth of late interest

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0,
            domainStart:           start + 2_100_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 1_000_000e6,
            incomingInterest:  0,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 1
        });

        vm.warp(start + 2_900_000);

        makePayment(loan1);

        assertTotalAssets(4_000_000e6 + 9_000e6);  // 1 day worth of late interest

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 2_900_000,
            domainEnd:             start + 2_900_000,
            unrealizedLosses:      0
        });
    }

    // Test 14
    function test_poolScenario_loanWithZeroInterestRateAndDefaultWithCover() external {
        depositCover({ cover: 200_000e6 });

        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 0.5e6);

        address lp1 = address(new Address());

        depositLiquidity(lp1, 4_000_000e6);

        assertTotalAssets(4_000_000e6);
        assertEq(pool.balanceOf(lp1), 4_000_000e6);

        // This loan will be funded and then never interacted with again.
        Loan loan1 = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0), uint256(0.1e18), uint256(0.01e18), uint256(0)]
        });

        // Burn to reset fee assertions
        fundsAsset.burn(treasury,     fundsAsset.balanceOf(treasury));
        fundsAsset.burn(poolDelegate, fundsAsset.balanceOf(poolDelegate));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  0,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertTotalAssets(4_000_000e6);

        // Perform late payment
        vm.warp(start + 1_100_000);

        address poolCover = address(poolManager.poolDelegateCover());

        uint256 initialCover = fundsAsset.balanceOf(poolCover);

        assertEq(fundsAsset.balanceOf(poolCover),     200_000e6);
        assertEq(fundsAsset.balanceOf(treasury),      0);
        assertEq(fundsAsset.balanceOf(poolDelegate),  0);
        assertEq(fundsAsset.balanceOf(address(pool)), 3_000_000e6);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan1), address(liquidatorFactory));

        // No management fee to recover since interest rate is zero.
        uint256 platformServiceFee    = uint256(1_000_000e6) * 0.31536e6 * 1_000_000 seconds / 1e6 / 365 days;
        uint256 platformManagementFee = uint256(1_000_000e6) * 0.01e6 * 0.08e6 / 1e6 / 1e6;  // 1% flat late fee, net

        assertEq(platformServiceFee,    10_000e6);
        assertEq(platformManagementFee, 800e6);

        assertEq(fundsAsset.balanceOf(poolCover),     100_000e6);
        assertEq(fundsAsset.balanceOf(treasury),      10_800e6);  // Both platform fees are recovered first, remainder goes to pool
        assertEq(fundsAsset.balanceOf(poolDelegate),  0);
        assertEq(fundsAsset.balanceOf(address(pool)), 3_000_000e6 + 100_000e6 - 10_800e6);  // Remaining cover goes to pool, up to 50%

        assertTotalAssets(3_000_000e6 + 100_000e6 - 10_800e6);

        assertLoanInfoWasDeleted(loan1);

        assertLoanState({
            loan:              loan1,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan1,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        uint256 finalCover = fundsAsset.balanceOf(address(poolManager.poolDelegateCover()));

        assertEq(initialCover, 200_000e6);
        assertEq(finalCover,   100_000e6);
    }

    // Test 15
    function test_poolScenario_intendToWithdrawAndChangeWMToZero() external {
        address lp1 = address(new Address());

        depositLiquidity(lp1, 4_000_000e6);

        assertTotalAssets(4_000_000e6);
        assertEq(pool.balanceOf(lp1), 4_000_000e6);

        vm.prank(lp1);
        pool.requestRedeem(2_000_000e6, lp1);  // Request half of the shares

        vm.prank(poolDelegate);
        poolManager.setWithdrawalManager(address(0));

        vm.warp(start + 2 weeks);

        vm.prank(lp1);
        try pool.redeem(2_000_000e6, lp1, lp1) { assertTrue(false, "Did not fail" ); } catch { }
    }

    function test_poolScenario_impairLoanWithLatePaymentAndRefinance() external {
        depositCover({ cover: 200_000e6 });

        address lp1      = address(new Address());
        address borrower = address(new Address());

        depositLiquidity(lp1, 1_000_000e6);

        assertTotalAssets(1_000_000e6);
        assertEq(pool.balanceOf(lp1), 1_000_000e6);

        // This loan will be refinanced
        Loan loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(0), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e18), uint256(0.05e18), uint256(0), uint256(0)]
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e18 * 0.9e6 / 1e6 / 1e18;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest      = annualLoanInterest * 1 days / 365 days;
        uint256 dailyLoanInterestGross = (1_000_000e6 * 0.031536e18 / 1e18) * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest,     28382.4e6);
        assertEq(dailyLoanInterestGross, 86.4e6);
        assertEq(dailyLoanInterest,      77.76e6);
        assertEq(issuanceRate,           900e30);

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        1_000_000e6 ,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          issuanceRate,
            domainStart:           start,
            domainEnd:             start + 30 days,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: dailyLoanInterest * 30,
            refinanceInterest:   0,
            issuanceRate:        issuanceRate,
            startDate:           start,
            paymentDueDate:      start + 30 days,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        uint256 platformServiceFee = uint256(1_000_000e6) * 0.31536e6 * 30 days / 1e6 / 365 days;

        assertEq(platformServiceFee, 25920e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  dailyLoanInterestGross * 30,
            incomingFees:      platformServiceFee + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 30 days,
            paymentsRemaining: 3
        });

        vm.warp(start + 10 days);

        {
            // Refinance Loan and stack too deep
            bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 60 days);

            Refinancer refinancer = new Refinancer();

            vm.startPrank(borrower);
            loan.proposeNewTerms(address(refinancer), block.timestamp, data);
            fundsAsset.mint(borrower, 30_000e6);
            fundsAsset.approve(address(loan), 30_000e6);
            loan.returnFunds(30_000e6);  // Return funds to pay origination fees.
            vm.stopPrank();

            vm.prank(poolDelegate);
            poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp, data, 0);
        }

        platformServiceFee = uint256(1_000_000e6) * 0.31536e6 * 70 days / 1e6 / 365 days;

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  dailyLoanInterestGross * 70,
            incomingFees:      platformServiceFee + 400e6,
            refinanceInterest: dailyLoanInterestGross * 10,
            paymentDueDate:    start + 70 days,
            paymentsRemaining: 3
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     dailyLoanInterest * 10,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + dailyLoanInterest * 10,
            issuanceRate:          issuanceRate,
            domainStart:           start + 10 days,
            domainEnd:             start + 70 days,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: dailyLoanInterest * 60,
            refinanceInterest:   dailyLoanInterest * 10,
            issuanceRate:        issuanceRate,
            startDate:           start + 10 days,
            paymentDueDate:      start + 70 days,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        1_000_000e6 + dailyLoanInterest * 10 ,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        vm.warp(start + 75 days);
        vm.prank(poolDelegate);
        loanManager.updateAccounting();

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     dailyLoanInterest * 70,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + dailyLoanInterest * 70,
            issuanceRate:          0,
            domainStart:           start + 75 days,
            domainEnd:             start + 75 days,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: dailyLoanInterest * 60,
            refinanceInterest:   dailyLoanInterest * 10,
            issuanceRate:        0,
            startDate:           start + 10 days,
            paymentDueDate:      start + 70 days,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // Impair Loan
        vm.prank(poolDelegate);
        poolManager.impairLoan(address(loan));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     dailyLoanInterest * 70,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + dailyLoanInterest * 70,
            issuanceRate:          0,
            domainStart:           start + 75 days,
            domainEnd:             start + 75 days,
            // Note: 10 days from refinance interest and 60 days from accrued interest after refinance
            unrealizedLosses:      1_000_000e6 + (dailyLoanInterest * 70)
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: dailyLoanInterest * 60,
            refinanceInterest:   dailyLoanInterest * 10,
            issuanceRate:        0,
            startDate:           start + 10 days,
            paymentDueDate:      start + 70 days,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // NOTE: 10 days from refinance interest and 60 days from payment interval
        platformServiceFee = uint256(1_000_000e6) * 0.31536e6 * 70 days / 1e6 / 365 days;

        uint256 platformManagementFee = dailyLoanInterestGross * 75 * 0.08e6 / 1e6;

        assertEq(platformManagementFee, 518.4e6);

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            dailyLoanInterest * 70,
            lateInterest:        dailyLoanInterest * 5,
            platformFees:        platformServiceFee + platformManagementFee,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        1_000_000e6 + dailyLoanInterest * 70,
            unrealizedLosses:   1_000_000e6 + dailyLoanInterest * 70,
            availableLiquidity: 0
        });

        makePayment(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     dailyLoanInterest * 5,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + dailyLoanInterest * 5,
            issuanceRate:          issuanceRate,
            domainStart:           start + 75 days,
            domainEnd:             start + 75 days + 55 days,
            unrealizedLosses:      0
        });

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        1_000_000e6 + dailyLoanInterest * 75 + dailyLoanInterest * 5,
            unrealizedLosses:   0,
            availableLiquidity: dailyLoanInterest * 75
        });
    }

    // Test 19
    function test_poolScenarios_refinanceATwoPeriodsLateLoan() external {
        address lp1      = address(new Address());
        address borrower = address(new Address());

        Refinancer refinancer = new Refinancer();

        depositLiquidity(lp1, 2_500_000e6);

        Loan loan1 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0.31536e18)]
        });

        // Loan Manager should be in a coherent state
        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        // Make the loan late
        vm.warp(start + 2_500_000);  // Two and a half periods late

        assertTotalAssets(2_500_000e6 + 90_000e6);

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        vm.startPrank(borrower);
        loan1.proposeNewTerms(address(refinancer), block.timestamp + 1, data);
        fundsAsset.mint(borrower, 10_000e6);
        fundsAsset.approve(address(loan1), 10_000e6);
        loan1.returnFunds(10_000e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan1), address(refinancer), block.timestamp + 1, data, 0);

        // Late interest accrues at 0.99e6/s because the lateInterestPremium is 10% of the interest rate.
        uint256 grossRefinanceInterest = 250_000e6 + 18 days * 0.11e6;
        uint256 netRefinanceInterest   = grossRefinanceInterest * 0.9e6 / 1e6;

        assertEq(grossRefinanceInterest, 421_072e6);
        assertEq(netRefinanceInterest,   378_964.8e6);

        // Principal + 225_000e6 (period from start to refinance) + late interest(18 * 86400 * 0.099)
        assertTotalAssets(2_500_000e6 + netRefinanceInterest);

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6 + grossRefinanceInterest,
            // 2_500_000s of platform fees + 2_500_000s of delegate service fees + service fees for period after refinance
            incomingFees:      25_000e6 + 750e6 + 20_000e6 + 300e6,
            refinanceInterest: grossRefinanceInterest,
            paymentDueDate:    start + 4_500_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   netRefinanceInterest,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 2_500_000,
            paymentDueDate:      start + 4_500_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     netRefinanceInterest,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + netRefinanceInterest,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 2_500_000,
            domainEnd:             start + 4_500_000,
            unrealizedLosses:      0
        });

        // Warp to next payment, 200 sec early
        vm.warp(start + 2_500_000 + 1_800_000);

        // Principal + accountedInterest + accruedInterest up to domainEnd
        assertTotalAssets(2_500_000e6 + netRefinanceInterest + 1_800_000 * 0.09e6);

        makePayment(loan1);

        // Principal + refinanceInterest + installment + 10 days of late interest
        assertTotalAssets(2_500_000e6 + netRefinanceInterest + 180_000e6);

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 6_500_000,
            paymentsRemaining: 2
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.081818181818181818181818181818181818e6 * 1e30,
            domainStart:           start + 4_300_000,
            domainEnd:             start + 6_500_000,
            unrealizedLosses:      0
        });
    }

    // Test 20
    function test_poolScenarios_refinanceLateLoanAndDefault() external {
        address lp1      = address(new Address());
        address borrower = address(new Address());

        Refinancer refinancer = new Refinancer();

        depositLiquidity(lp1, 2_500_000e6);

        Loan loan1 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0.31536e18)]
        });

        // Loan Manager should be in a coherent state
        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        // Make the loan late
        vm.warp(start + 1_500_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        vm.startPrank(borrower);
        loan1.proposeNewTerms(address(refinancer), block.timestamp + 1, data);
        fundsAsset.mint(borrower, 10_000e6);
        fundsAsset.approve(address(loan1), 10_000e6);
        loan1.returnFunds(10_000e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan1), address(refinancer), block.timestamp + 1, data, 0);

        // Late interest accrues at 0.99e6/s because the lateInterestPremium is 10% of the interest rate.
        uint256 grossRefinanceInterest = 150_000e6 + 6 days * 0.11e6;
        uint256 netRefinanceInterest   = grossRefinanceInterest * 0.9e6 / 1e6;

        assertEq(grossRefinanceInterest, 207_024e6);
        assertEq(netRefinanceInterest,   186_321.6e6);

        // Principal + 135_000e6 (period from start to refinance) + late interest(6 * 86400 * 0.09)
        assertTotalAssets(2_500_000e6 + netRefinanceInterest);

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6 + grossRefinanceInterest,
            incomingFees:      15_000e6 + 450e6 + 20_000e6 + 300e6,  // 10_000e6 of platform service fees + 300e6 of delegate service fees.
            refinanceInterest: grossRefinanceInterest,
            paymentDueDate:    start + 3_500_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   netRefinanceInterest,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_500_000,
            paymentDueDate:      start + 3_500_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     netRefinanceInterest,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + netRefinanceInterest,  // Principal + refinanceInterest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 3_500_000,
            unrealizedLosses:      0
        });

        // Move the loan to default (100k seconds late)
        vm.warp(start + 3_600_000);

        // Pre default assertions
        assertTotalAssets(2_500_000e6 + netRefinanceInterest + 180_000e6);

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            // Refinance interest + installment + late interest
            incomingInterest:  grossRefinanceInterest + 200_000e6 + 2 days * 0.11e6,
            // 10_000e6 of platform service fees + 300e6 of delegate service fees.
            incomingFees:      15_000e6 + 450e6 + 20_000e6 + 300e6,
            refinanceInterest: grossRefinanceInterest,
            paymentDueDate:    start + 3_500_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   netRefinanceInterest,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_500_000,
            paymentDueDate:      start + 3_500_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       180_000e6,
            accountedInterest:     netRefinanceInterest,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + netRefinanceInterest + 180_000e6,  // principal + accounted interest + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 3_500_000,
            unrealizedLosses:      0
        });

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan1), liquidatorFactory);

        assertTotalAssets(1_500_000e6);  // Only the amount in the pool

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 3_600_000,
            domainEnd:             start + 3_600_000,
            unrealizedLosses:      0
        });
    }

    // Test 21
    function test_poolScenarios_stressTestAdvanceGlobalPaymentAccounting() external {
        address lp1 = address(new Address());

        depositLiquidity(lp1, 400_000_000e6);

        assertTotalAssets(400_000_000e6);

        for (uint256 i; i < 150; ++i) {
            fundAndDrawdownLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
                amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
                rates:       [uint256(3.1536e18), uint256(0.1e18), uint256(0.01e18), uint256(0.31536e18)]
            });
        }

        assertTotalAssets(400_000_000e6);

        // Advance another 2_000_000 seconds so all loans are surely late
        vm.warp(start + 2_000_000);

        // Loan Manager should be in a coherent state
        assertLoanManager({
            accruedInterest:       150 * 90_000e6,
            accountedInterest:     0,
            principalOut:          150_000_000e6,
            assetsUnderManagement: 150_000_000e6 + 150 * 90_000e6,
            issuanceRate:          150 * 0.09e6 * 1e30,             // All loans are late
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertTotalAssets(400_000_000e6 + 150 * 90_000e6);

        // Advance accounting for all loans
        vm.prank(poolDelegate);
        loanManager.updateAccounting();

        // Loan Manager should be in a coherent state
        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     150 * 90_000e6,
            principalOut:          150_000_000e6,
            assetsUnderManagement: 150_000_000e6 + 150 * 90_000e6,
            issuanceRate:          0,                               // All loans are late
            domainStart:           start + 2_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertTotalAssets(400_000_000e6 + 150 * 90_000e6);
    }

}
