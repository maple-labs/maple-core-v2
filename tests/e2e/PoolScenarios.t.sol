// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { Refinancer }        from "../../modules/loan/contracts/Refinancer.sol";
import { MapleLoan as Loan } from "../../modules/loan/contracts/MapleLoan.sol";

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

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 800_00s of loan2 at 0.15 IR + 200_000s of loan3 at 0.36 IR
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 120_000e6 + 72_000e6);

        closeLoan(loan2);

        // Deposits + 1e6s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 1% of loan2 principal + 200_000s of loan3 at 0.36 IR
        assertTotalAssets(4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 72_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     72_000e6 + 90_000e6, // 72_000e6 from 200_000s of loan3 and 90_000e6 from loan1
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
            accountedInterest:     90_000e6, // 90_000e6 from loan1
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

        // Deposits + 90_000s of loan1 at 0.09 IR and 1_000_000s of loan2 at 0.18 IR + 1% of loan2 Principal + 1_000_000 of loan3 at 0.36 IR + 100_000s of loan3 at 0.30
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
            uint256 redeemableShares1 = 4_000_000e6 * 7_558_000e6  / ((4_000_000e6 + 5_893_909.626719e6) * totalAssets / 11_803_930.790178e6);
            assertEq(redeemableShares1, 2_844_951.367431e6);

            vm.prank(lp1);
            uint256 assets1 = pool.redeem(4_000_000e6, lp1, lp1);

            assertEq(assets1, totalAssets * redeemableShares1 / 11_803_930.790178e6);
            assertEq(assets1, 3_055_617.156473e6);
        }

        // Remove withdrawn assets from total assets
        totalAssets = (4_000_000e6 + 6_000_000e6 + 2_000_000e6 + 90_000e6 + 180_000e6 + 18_000e6 + 360_000e6 + 30_000e6) - 3_055_617.156473e6;
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
            accountedInterest:     90_000e6, // 90_000e6 from loan1
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
            uint256 assets1 = pool.redeem(1_155_048.632569e6, lp1, lp1); // Original lp1 shares - lp1 shares previously withdrawn

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
            uint256 assets2 = pool.redeem(1701938.063706e6, lp2, lp2); // Original lp2 shares - lp2 shares previously withdrawn

            assertEq(assets2, (totalAssets * redeemableShares2 / 2_276_968.369674e6));
            assertEq(assets2, 1_685_155.111355e6);

            assertEq(fundsAsset.balanceOf(address(pool)), 0);  // All cash withdrawn
        }

        totalAssets -= 1_685_155.111355e6;
        assertTotalAssets(totalAssets);

        assertEq(pool.totalAssets(), 1_090_000e6);  // Exact value of loan1

        assertEq(pool.totalSupply(), 894_326.775750e6);

        // Since the loan1 was never finalized, LPS still have a balance greater than 0, but are locked in the withdrawal manager until they remove.
        assertEq(pool.balanceOf(address(withdrawalManager)), 894_326.775750e6);  // All funds are in WM
        assertEq(withdrawalManager.lockedShares(lp1),        216_695.870826e6);
        assertEq(withdrawalManager.lockedShares(lp2),        319_296.469782e6);
        assertEq(withdrawalManager.lockedShares(lp3),        358_334.435142e6);


    }

}
