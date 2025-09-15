// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract ScheduleTestBase is SyrupBitcoinTestBase {

    address poolDepositor = makeAddr("poolDepositor");

    uint32 deadline;
    uint32 extension       = 2 days;
    uint32 fullDuration    = 19 days;
    uint32 partialDuration = 13 days;
    uint32 yieldGap        = 1 hours;

    uint256 feeRate    = 0.015e6;  // 1.5% fee rate
    uint256 precision  = 1e30;
    uint256 totalYield = 6e8;
    uint256 yieldDelta = 0.7e8;

    uint256 partialYield = totalYield * partialDuration / fullDuration;
    uint256 partialFees  = partialYield * feeRate / 1e6;
    uint256 totalFees    = totalYield * feeRate / 1e6;

    function setUp() public virtual override {
        super.setUp();

        deadline = startingTime + fullDuration;

        // Set the strategy fee rate.
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);
    }

}

contract ScheduleFailureTests is ScheduleTestBase {

    function test_schedule_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyManager);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.schedule(totalYield, deadline);
    }

    function test_schedule_notScheduler() external {
        vm.expectRevert("MBS:NOT_ALLOWED");
        bitcoinStrategy.schedule(totalYield, deadline);
    }

    function test_schedule_deadlineElapsed() external {
        vm.prank(strategyManager);
        vm.expectRevert("MBS:S:INVALID_DEADLINE");
        bitcoinStrategy.schedule(totalYield, startingTime);
    }

    function test_schedule_deadlineIgnored() external {
        vm.prank(strategyManager);
        vm.expectRevert("MBS:S:INVALID_DEADLINE");
        bitcoinStrategy.schedule(0, deadline);
    }

}

contract ScheduleSuccessTests is ScheduleTestBase {

    function test_schedule_createSchedule() external {
        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });
    }

    function test_schedule_createSchedule_minimumDuration() external {
        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, startingTime + 1 seconds);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: 1 seconds,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield
        });
    }

    function test_schedule_createSchedule_maximumDuration() external {
        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, type(uint32).max);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: type(uint32).max - startingTime,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / (type(uint32).max - startingTime)
        });
    }

    function test_schedule_extendDuration() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield() + yieldDelta;

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline + extension);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield + yieldDelta,
            remainingDuration: fullDuration - partialDuration + extension,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield + yieldDelta) / (fullDuration - partialDuration + extension)
        });
    }

    function test_schedule_extendDuration_minimumDuration() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield();

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline + 1 seconds);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield,
            remainingDuration: fullDuration - partialDuration + 1 seconds,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield) / (fullDuration - partialDuration + 1 seconds)
        });
    }

    function test_schedule_extendDuration_maximumDuration() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield();

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, type(uint32).max);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield,
            remainingDuration: type(uint32).max - startingTime - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield) / (type(uint32).max - startingTime - partialDuration)
        });
    }

    function test_schedule_increaseYield() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield() + yieldDelta;

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield + yieldDelta,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield + yieldDelta) / (fullDuration - partialDuration)
        });
    }

    function test_schedule_increaseYield_minimumAmount() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield() + 1;

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield + 1,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield + 1) / (fullDuration - partialDuration)
        });
    }

    function test_schedule_increaseYield_maximumAmount() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(type(uint256).max, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        ( uint256 remainingYield, uint32 lastUpdated, uint32 remainingDuration ) = bitcoinStrategy.schedules(0);

        assertEq(remainingYield,    type(uint256).max);
        assertEq(remainingDuration, fullDuration - partialDuration);
        assertEq(lastUpdated,       startingTime + partialDuration);

        vm.expectRevert(arithmeticError);
        bitcoinStrategy.yieldRate();
    }

    function test_schedule_increaseYield_duplicate() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield() + yieldDelta;

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield + yieldDelta,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield + yieldDelta) / (fullDuration - partialDuration)
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield + yieldDelta,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield + yieldDelta) / (fullDuration - partialDuration)
        });
    }

    function test_schedule_decreaseYield() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield() - yieldDelta;

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield - yieldDelta,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield - yieldDelta) / (fullDuration - partialDuration)
        });
    }

    function test_schedule_decreaseYield_minimumAmount() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield() - 1;

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield - 1,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield - 1) / (fullDuration - partialDuration)
        });
    }

    function test_schedule_decreaseYield_maximumAmount() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(0, 0);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_schedule_updateSchedule_yieldGap() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + fullDuration + yieldGap);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          totalYield,
            accruedFees:           totalFees,
            assetsUnderManagement: totalYield - totalFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, startingTime + fullDuration + yieldGap + fullDuration);

        assertAccounting({
            outstandingAssets:     totalYield - totalFees,
            realizedFees:          totalFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: totalYield - totalFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime + fullDuration + yieldGap,
            yieldRate:         precision * totalYield / fullDuration
        });
    }

    function test_schedule_updateSchedule_removeFees() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield();

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(0);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield) / (fullDuration - partialDuration)
        });

        vm.warp(startingTime + fullDuration);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          totalYield - partialYield,
            accruedFees:           0,
            assetsUnderManagement: totalYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        assertAccounting({
            outstandingAssets:     totalYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: totalYield - partialFees
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_schedule_updateSchedule_maxFees() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        uint256 updatedYield = totalYield - bitcoinStrategy.accruedYield();

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(1e6 - 1);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(updatedYield, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (totalYield - partialYield) / (fullDuration - partialDuration)
        });

        vm.warp(startingTime + fullDuration);

        uint256 remainingFees = (totalYield - partialYield) * (1e6 - 1) / 1e6;

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          totalYield - partialYield,
            accruedFees:           remainingFees,
            assetsUnderManagement: totalYield - partialFees - remainingFees
        });

        assertSchedule({
            remainingYield:    totalYield - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        assertAccounting({
            outstandingAssets:     totalYield - partialFees - remainingFees,
            realizedFees:          partialFees + remainingFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: totalYield - partialFees - remainingFees
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_schedule_updateSchedule_yieldRounding() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(totalYield, deadline);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    totalYield,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * totalYield / fullDuration
        });

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(1e6 - 1);

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(1, deadline);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    1,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * 1 / (fullDuration - partialDuration)
        });

        vm.warp(startingTime + fullDuration);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          1,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees + 1
        });

        assertSchedule({
            remainingYield:    1,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         0
        });
    }

}
