// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";
import { Address           } from "../modules/contract-test-utils/contracts/test.sol";

import { TestBaseWithAssertions } from "../contracts/TestBaseWithAssertions.sol";

contract BasicInterestAccrualTest is TestBaseWithAssertions {

    address borrower;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
    }

    function test_basicInterestAccrual() external {
        depositLiquidity({
            lp:        lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,      // 1,000,000 * 0.20% * 3  / 12 = 500
            delegateServiceFee:         275e6,      // 1,000,000 * 0.33%      / 12 = 275
            delegateManagementFeeRate:  0.02e18,    // 1,000,000 * 7.50% * 2% / 12 = 125
            platformOriginationFeeRate: 0.001e18,   // 1,000,000 * 0.10% * 3  / 12 = 250
            platformServiceFeeRate:     0.0066e18,  // 1,000,000 * 0.66%      / 12 = 550
            platformManagementFeeRate:  0.08e18     // 1,000,000 * 7.50% * 8% / 12 = 500
        });

        /******************************/
        /*** Fund and Drawdown Loan ***/
        /******************************/

        Loan loan = fundAndDrawdownLoan({
            borrower:         borrower,
            principal:        1_000_000e6,
            interestRate:     0.075e18,
            paymentInterval:  365 days / 12,
            numberOfPayments: 3
        });

        // +--------------+--------------+--------+--------+
        // |   BORROWER   |     POOL     |   PD   |   MT   |
        // +--------------+--------------+--------+--------+
        // |           0  |    1,500,000 |     0  |    250 |
        // | + 1,000,000  | -  1,000,000 |        |        | Principal borrowed
        // | -       750  |              | + 500  | +  250 | Origination fees paid
        // | =   999,250  | =    500,000 | = 500  | =  250 |
        // +--------------+--------------+--------+--------+

        assertTotalAssets(1_500_000e6);
        assertLoanManagerState({
            principalOut:      1_000_000e6,
            accountedInterest: 0,
            issuanceRate:      uint256(6_250e6 - 625e6) * 12e30 / 365 days,
            domainStart:       start,
            domainEnd:         start + 365 days / 12
        });
        assertAssetBalances(
            [borrower,  address(pool), poolDelegate, treasury],
            [999_250e6, 500_000e6,     500e6,        250e6   ]
        );

        /************************/
        /*** Make 1st Payment ***/
        /************************/

        vm.warp(start + 365 days / 12);
        makePayment(loan);

        // +------------+--------+--------+
        // |    POOL    |   PD   |   MT   |
        // +------------+--------+--------+
        // |   500,000  |   500  |    250 |
        // | +   6,250  | + 275  | +  550 | Interest and service fees paid
        // | -     625  | + 125  | +  500 | Management fee distribution
        // | = 505,625  | = 900  | = 1300 |
        // +------------+--------+--------+

        assertTotalAssets(1_505_625e6);
        assertLoanManagerState({
            principalOut:      1_000_000e6,
            accountedInterest: 0,
            issuanceRate:      uint256(6_250e6 - 625e6) * 12e30 / 365 days,
            domainStart:       start + 365 days / 12,
            domainEnd:         start + 2 * 365 days / 12
        });
        assertAssetBalances(
            [address(pool), poolDelegate, treasury],
            [505_625e6,     900e6,        1300e6  ]
        );

        /************************/
        /*** Make 2nd Payment ***/
        /************************/

        vm.warp(start + 2 * 365 days / 12);
        makePayment(loan);

        // +------------+--------+--------+
        // |    POOL    |   PD   |   MT   |
        // +------------+--------+--------+
        // |   505,625  |    900 |   1300 |
        // | +   6,250  | +  275 | +  550 | Interest and service fees paid
        // | -     625  | +  125 | +  500 | Management fee distribution
        // | = 511,250  | = 1300 | = 2350 |
        // +------------+--------+--------+

        assertTotalAssets(1_511_250e6);
        assertAssetBalances(
            [address(pool), poolDelegate, treasury],
            [511_250e6,     1300e6,       2350e6  ]
        );
        assertLoanManagerState({
            principalOut:      1_000_000e6,
            accountedInterest: 0,
            issuanceRate:      uint256(6_250e6 - 625e6) * 12e30 / 365 days,
            domainStart:       start + 2 * 365 days / 12,
            domainEnd:         start + 3 * 365 days / 12
        });

        /************************/
        /*** Make 3rd Payment ***/
        /************************/

        vm.warp(start + 3 * 365 days / 12);
        fundsAsset.mint(borrower, 1_000e6);  // Borrower makes some some money.
        makePayment(loan);

        // +--------------+--------+--------+
        // |     POOL     |   PD   |   MT   |
        // +--------------+--------+--------+
        // |     511,250  |   1300 |   2350 |
        // | +     6,250  | +  275 | +  550 | Interest and service fees paid
        // | -       625  | +  125 | +  500 | Management fee distribution
        // | + 1,000,000  |        |        | Principal returned
        // | = 1,516,875  | = 1700 | = 3400 |
        // +--------------+--------+--------+

        assertTotalAssets(1_516_875e6);
        assertAssetBalances(
            [address(pool), poolDelegate, treasury],
            [1_516_875e6,   1700e6,       3400e6  ]
        );
        assertLoanManagerState({
            principalOut:      0,
            accountedInterest: 0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         0
        });
    }

}
