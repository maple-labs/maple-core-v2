// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SetFeeRateTests is SyrupBitcoinTestBase {

    uint256 constant ONE_HUNDRED = 1e6;

    uint256 newRateA = 0.015e6;
    uint256 newRateB = 0.055e6;

    uint32 startTime;

    function setUp() public virtual override {
        super.setUp();

        startTime = uint32(block.timestamp);
    }

    function test_setFeeRate_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.setFeeRate(newRateA);
    }

    function test_setFeeRate_revert_notAdmin() external {
        vm.expectRevert("MBS:NOT_ADMIN");
        bitcoinStrategy.setFeeRate(newRateA);
    }

    function test_setFeeRate_revert_rateTooHigh() external {
        vm.prank(governor);
        vm.expectRevert("MBS:SFR:INVALID_RATE");
        bitcoinStrategy.setFeeRate(ONE_HUNDRED + 1);
    }

    function test_setFeeRate_success_zero() external {
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(0);

        assertEq(bitcoinStrategy.feeRate(), 0);
    }

    function test_setFeeRate_success_max() external {
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(ONE_HUNDRED);

        assertEq(bitcoinStrategy.feeRate(), ONE_HUNDRED);
    }

    function test_setFeeRate_success_update_overwrite() external {
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(newRateA);

        assertEq(bitcoinStrategy.feeRate(), newRateA);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(newRateB);

        assertEq(bitcoinStrategy.feeRate(), newRateB);
    }

    function test_setFeeRate_success_updateAccounting() external {
        uint256 yieldAmount = 5e8;
        uint32  duration    = 10 days;
        uint256 initialRate = 0.02e6;
        uint256 newRate     = 0.05e6;

        assertEq(bitcoinStrategy.feeRate(), 0);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(initialRate);

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, startTime + duration);

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: duration,
            lastUpdated:       startTime,
            yieldRate:         yieldAmount * bitcoinStrategy.PRECISION() / duration
        });

        vm.warp(startTime + duration / 3);

        startTime = uint32(block.timestamp);

        uint256 expectedAccruedYield = yieldAmount * (duration / 3) / duration;
        uint256 expectedFees         = expectedAccruedYield * initialRate / ONE_HUNDRED;

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(newRate);

        assertEq(bitcoinStrategy.feeRate(),      newRate);
        assertEq(bitcoinStrategy.realizedFees(), expectedFees);

        assertSchedule({
            remainingYield:    yieldAmount - expectedAccruedYield,
            remainingDuration: duration - (duration / 3),
            lastUpdated:       startTime,
            yieldRate:         (yieldAmount - expectedAccruedYield) * bitcoinStrategy.PRECISION() / (duration - (duration / 3))
        });
    }

    function test_setFeeRate_success_noSchedule_noAccountingChange() external {
        assertEq(bitcoinStrategy.feeRate(), 0);

        uint256 startOutstanding = bitcoinStrategy.outstandingAssets();
        uint256 startRealized    = bitcoinStrategy.realizedFees();

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(newRateA);

        assertEq(bitcoinStrategy.feeRate(), newRateA);

        assertAccounting({
            outstandingAssets:     startOutstanding,
            realizedFees:          startRealized,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: startOutstanding
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_setFeeRate_success_activeSchedule_zeroElapsed_noAccountingChange() external {
        uint256 yieldAmount = 5e8;
        uint32  duration    = 10 days;
        uint256 initialRate = 0.02e6;
        uint256 newRate     = 0.03e6;

        assertEq(bitcoinStrategy.feeRate(), 0);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(initialRate);

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, startTime + duration);

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: duration,
            lastUpdated:       startTime,
            yieldRate:         yieldAmount * bitcoinStrategy.PRECISION() / duration
        });

        uint256 startOutstanding = bitcoinStrategy.outstandingAssets();
        uint256 startRealized    = bitcoinStrategy.realizedFees();

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(newRate);

        assertEq(bitcoinStrategy.feeRate(), newRate);

        assertAccounting({
            outstandingAssets:     startOutstanding,
            realizedFees:          startRealized,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: startOutstanding
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: duration,
            lastUpdated:       startTime,
            yieldRate:         yieldAmount * bitcoinStrategy.PRECISION() / duration
        });
    }

    function test_setFeeRate_success_activeSchedule_fullElapsed_clearsSchedule() external {
        uint256 yieldAmount = 7e8;
        uint32  duration    = 8 days;
        uint256 initialRate = 0.04e6;
        uint256 newRate     = 0.01e6;

        assertEq(bitcoinStrategy.feeRate(), 0);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(initialRate);

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, startTime + duration);

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: duration,
            lastUpdated:       startTime,
            yieldRate:         yieldAmount * bitcoinStrategy.PRECISION() / duration
        });

        uint256 outstandingBefore = bitcoinStrategy.outstandingAssets();
        uint256 realisedBefore    = bitcoinStrategy.realizedFees();

        vm.warp(block.timestamp + duration);

        startTime = uint32(block.timestamp);

        uint256 expectedAccruedYield = yieldAmount;
        uint256 expectedFees         = expectedAccruedYield * initialRate / ONE_HUNDRED;

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(newRate);

        assertEq(bitcoinStrategy.feeRate(), newRate);

        assertAccounting({
            outstandingAssets:     outstandingBefore + expectedAccruedYield - expectedFees,
            realizedFees:          realisedBefore + expectedFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: outstandingBefore + expectedAccruedYield - expectedFees
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_setFeeRate_success_updateAccounting_zeroInitialRate_noFees() external {
        uint256 yieldAmount  = 9e8;
        uint32  duration     = 6 days;
        uint256 initialRate  = 0;
        uint256 newRate      = 0.05e6;

        assertEq(bitcoinStrategy.feeRate(), 0);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(initialRate);

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, startTime + duration);

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: duration,
            lastUpdated:       startTime,
            yieldRate:         yieldAmount * bitcoinStrategy.PRECISION() / duration
        });

        vm.warp(block.timestamp + duration / 3);

        startTime = uint32(block.timestamp);

        uint256 outstandingBefore  = bitcoinStrategy.outstandingAssets();
        uint256 realisedBefore     = bitcoinStrategy.realizedFees();

        uint256 accruedYield = yieldAmount * (duration / 3) / duration;
        uint256 accruedFees  = 0;

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(newRate);

        assertEq(bitcoinStrategy.feeRate(), newRate);

        assertAccounting({
            outstandingAssets:     outstandingBefore + accruedYield - accruedFees,
            realizedFees:          realisedBefore + accruedFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: outstandingBefore + accruedYield - accruedFees
        });

        assertSchedule({
            remainingYield:    yieldAmount - accruedYield,
            remainingDuration: duration - (duration / 3),
            lastUpdated:       startTime,
            yieldRate:         (yieldAmount - accruedYield) * bitcoinStrategy.PRECISION() / (duration - (duration / 3))
        });
    }

    function test_setFeeRate_success_updateAccounting_noTimeElapsed_noExtraAccrual() external {
        uint256 yieldAmount = 4e8;
        uint32  duration    = 5 days;
        uint256 initialRate = 0.03e6;
        uint256 midRate     = 0.02e6;
        uint256 finalRate   = 0.01e6;

        assertEq(bitcoinStrategy.feeRate(), 0);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(initialRate);

        assertEq(bitcoinStrategy.feeRate(), initialRate);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, startTime + duration);

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: duration,
            lastUpdated:       startTime,
            yieldRate:         yieldAmount * bitcoinStrategy.PRECISION() / duration
        });

        vm.warp(block.timestamp + duration / 3);

        startTime = uint32(block.timestamp);

        uint256 accruedYield  = yieldAmount * (duration / 3) / duration;
        uint256 accruedFees   = accruedYield * initialRate / ONE_HUNDRED;

        {   // Stack-too-deep workaround block.
            uint256 beforeOutstanding = bitcoinStrategy.outstandingAssets();
            uint256 beforeRealized    = bitcoinStrategy.realizedFees();

            assertEq(bitcoinStrategy.feeRate(), initialRate);

            vm.prank(governor);
            bitcoinStrategy.setFeeRate(midRate);

            assertEq(bitcoinStrategy.feeRate(), midRate);

            assertAccounting({
                outstandingAssets:     beforeOutstanding + accruedYield - accruedFees,
                realizedFees:          beforeRealized + accruedFees,
                accruedYield:          0,
                accruedFees:           0,
                assetsUnderManagement: beforeOutstanding + accruedYield - accruedFees
            });

            uint256 afterFirstOutstanding = bitcoinStrategy.outstandingAssets();
            uint256 afterFirstRealized    = bitcoinStrategy.realizedFees();

            assertEq(bitcoinStrategy.feeRate(), midRate);

            vm.prank(governor);
            bitcoinStrategy.setFeeRate(finalRate);

            assertEq(bitcoinStrategy.feeRate(), finalRate);

            assertAccounting({
                outstandingAssets:     afterFirstOutstanding,
                realizedFees:          afterFirstRealized,
                accruedYield:          0,
                accruedFees:           0,
                assetsUnderManagement: afterFirstOutstanding
            });
        }

        assertSchedule({
            remainingYield:    yieldAmount - accruedYield,
            remainingDuration: duration - (duration / 3),
            lastUpdated:       startTime,
            yieldRate:         (yieldAmount - accruedYield) * bitcoinStrategy.PRECISION() / (duration - (duration / 3))
        });
    }

}
