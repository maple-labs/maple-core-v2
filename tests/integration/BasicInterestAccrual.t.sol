// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract BasicInterestAccrualTest is TestBaseWithAssertions {

    address borrower;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
    }

    function test_basicInterestAccrual() external {
        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,   // 1,000,000 * 0.20% * 3  / 12 = 500
            delegateServiceFee:         275e6,   // 1,000,000 * 0.33%      / 12 = 275
            delegateManagementFeeRate:  2_0000,  // 1,000,000 * 2.00% * 2% / 12 = 125
            platformOriginationFeeRate: 1000,    // 1,000,000 * 0.10% * 3  / 12 = 250
            platformServiceFeeRate:     6600,    // 1,000,000 * 0.66%      / 12 = 550
            platformManagementFeeRate:  8_0000   // 1,000,000 * 8.50% * 8% / 12 = 500
        });

        /******************************/
        /*** Fund and Drawdown Loan ***/
        /******************************/

        address loanManager = poolManager.loanManagerList(0);

        address loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(ONE_MONTH), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), uint256(0), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        // +--------------+--------------+--------+--------+
        // |   BORROWER   |     POOL     |   PD   |   MT   |
        // +--------------+--------------+--------+--------+
        // |           0  |    1,500,000 |     0  |    250 |
        // | + 1,000,000  | -  1,000,000 |        |        | Principal borrowed
        // | -       750  |              | + 500  | +  250 | Origination fees paid
        // | =   999,250  | =    500,000 | = 500  | =  250 |
        // +--------------+--------------+--------+--------+

        assertPoolManager({ totalAssets: 1_500_000e6, unrealizedLosses: 0 });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      uint256(5_625e6) * 12e30 / ONE_YEAR,
            domainStart:       start,
            domainEnd:         start + ONE_MONTH,
            unrealizedLosses:  0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(500_000e6), uint256(500e6),        uint256(250e6)   ]
        );

        /************************/
        /*** Make 1st Payment ***/
        /************************/

        vm.warp(start + ONE_MONTH);
        makePayment(loan);

        // +------------+--------+--------+
        // |    POOL    |   PD   |   MT   |
        // +------------+--------+--------+
        // |   500,000  |   500  |    250 |
        // | +   6,250  | + 275  | +  550 | Interest and service fees paid
        // | -     625  | + 125  | +  500 | Management fee distribution
        // | = 505,625  | = 900  | = 1300 |
        // +------------+--------+--------+

        assertAssetBalances(
            [address(pool),      address(poolDelegate), address(treasury)],
            [uint256(505_625e6), uint256(900e6),        uint256(1300e6)  ]
        );

        assertPoolManager({ totalAssets: 1_505_625e6, unrealizedLosses: 0 });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      uint256(5_625e6) * 12e30 / ONE_YEAR,
            domainStart:       start +     ONE_MONTH,
            domainEnd:         start + 2 * ONE_MONTH,
            unrealizedLosses:  0
        });

        /************************/
        /*** Make 2nd Payment ***/
        /************************/

        vm.warp(start + 2 * ONE_MONTH);
        makePayment(loan);

        // +------------+--------+--------+
        // |    POOL    |   PD   |   MT   |
        // +------------+--------+--------+
        // |   505,625  |    900 |   1300 |
        // | +   6,250  | +  275 | +  550 | Interest and service fees paid
        // | -     625  | +  125 | +  500 | Management fee distribution
        // | = 511,250  | = 1300 | = 2350 |
        // +------------+--------+--------+

        assertAssetBalances(
            [address(pool),      address(poolDelegate), address(treasury)],
            [uint256(511_250e6), uint256(1300e6),       uint256(2350e6)  ]
        );

        assertPoolManager({ totalAssets: 1_511_250e6, unrealizedLosses: 0 });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      uint256(5_625e6) * 12e30 / ONE_YEAR,
            domainStart:       start + 2 * ONE_MONTH,
            domainEnd:         start + 3 * ONE_MONTH,
            unrealizedLosses:  0
        });

        /************************/
        /*** Make 3rd Payment ***/
        /************************/

        vm.warp(start + 3 * ONE_MONTH);
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

        assertAssetBalances(
            [address(pool),        address(poolDelegate), address(treasury)],
            [uint256(1_516_875e6), uint256(1700e6),       uint256(3400e6)  ]
        );

        assertPoolManager({ totalAssets: 1_516_875e6, unrealizedLosses: 0 });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  0
        });
    }

}
