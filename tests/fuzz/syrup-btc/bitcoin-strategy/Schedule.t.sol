
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IBitcoinStrategy } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBtcFuzzBase } from "../SyrupBtcFuzzBase.t.sol";

contract SyrupBtcScheduleFuzzTests is SyrupBtcFuzzBase {

    function testFuzz_schedule(
        uint256 totalDeposited,
        uint256 strategyIndex,
        uint256 yieldAmount,
        uint256 deadline,
        uint256 timestampToCheckSystemState,
        uint256[4] memory deployedAssets,
        uint256[4] memory defaultedAssets
    ) external {
        strategyIndex               = bound(strategyIndex,               0,                3);
        totalDeposited              = bound(totalDeposited,              1,                1e30);
        yieldAmount                 = bound(yieldAmount,                 0,                1e30);
        deadline                    = bound(deadline,                    startingTime + 1, type(uint32).max);
        timestampToCheckSystemState = bound(timestampToCheckSystemState, startingTime + 1, type(uint32).max);

        deployedAssets  = _boundDeployedAssets(totalDeposited, deployedAssets);
        defaultedAssets = _boundDefaultedAssets(deployedAssets, defaultedAssets);

        _setUpSyrupBtcState(totalDeposited, deployedAssets, defaultedAssets);

        address targetStrategy = poolManager.strategyList(strategyIndex);

        if (yieldAmount == 0 && deadline != 0) {
            vm.prank(strategyManager);
            vm.expectRevert("MBS:S:INVALID_DEADLINE");
            IBitcoinStrategy(targetStrategy).schedule(yieldAmount, uint32(deadline));
            return;
        }

        vm.prank(strategyManager);
        IBitcoinStrategy(targetStrategy).schedule(yieldAmount, uint32(deadline));

        vm.warp(timestampToCheckSystemState);

        if (timestampToCheckSystemState > deadline) {
            uint256 expectedStrategyAum = deployedAssets[strategyIndex] - defaultedAssets[strategyIndex] + yieldAmount;
            assertEq(IBitcoinStrategy(targetStrategy).assetsUnderManagement(), expectedStrategyAum);
        } else {
            uint256 expectedStrategyYield = yieldAmount * (timestampToCheckSystemState - startingTime) / (deadline - startingTime);
            uint256 expectedStrategyAum   = deployedAssets[strategyIndex] - defaultedAssets[strategyIndex] + expectedStrategyYield;
            assertEq(IBitcoinStrategy(targetStrategy).assetsUnderManagement(), expectedStrategyAum);
        }
    }

    function testFuzz_schedule_overrideCurrentSchedule(
        uint256 totalDeposited,
        uint256 strategyIndex,
        uint256 firstYieldAmount,
        uint256 secondYieldAmount,
        uint256 firstScheduleDeadline,
        uint256 secondScheduleDeadline,
        uint256 timestampToScheduleSecondYield,
        uint256 timestampToCheckSystemState,
        uint256[4] memory deployedAssets,
        uint256[4] memory defaultedAssets
    ) external {
        strategyIndex                  = bound(strategyIndex,                  0,                                  3);
        totalDeposited                 = bound(totalDeposited,                 1,                                  1e30);
        firstYieldAmount               = bound(firstYieldAmount,               0,                                  1e30);
        secondYieldAmount              = bound(secondYieldAmount,              0,                                  1e30);
        firstScheduleDeadline          = bound(firstScheduleDeadline,          startingTime + 1,                   type(uint32).max - 1);
        timestampToScheduleSecondYield = bound(timestampToScheduleSecondYield, startingTime + 1,                   firstScheduleDeadline);
        secondScheduleDeadline         = bound(secondScheduleDeadline,         timestampToScheduleSecondYield + 1, type(uint32).max);
        timestampToCheckSystemState    = bound(timestampToCheckSystemState,    timestampToScheduleSecondYield,     type(uint32).max);

        deployedAssets  = _boundDeployedAssets(totalDeposited, deployedAssets);
        defaultedAssets = _boundDefaultedAssets(deployedAssets, defaultedAssets);

        _setUpSyrupBtcState(totalDeposited, deployedAssets, defaultedAssets);

        address targetStrategy = poolManager.strategyList(strategyIndex);

        if (firstYieldAmount == 0 && firstScheduleDeadline != 0) {
            vm.prank(strategyManager);
            vm.expectRevert("MBS:S:INVALID_DEADLINE");
            IBitcoinStrategy(targetStrategy).schedule(firstYieldAmount, uint32(firstScheduleDeadline));
            return;
        } else {
            vm.prank(strategyManager);
            IBitcoinStrategy(targetStrategy).schedule(firstYieldAmount, uint32(firstScheduleDeadline));
        }

        vm.warp(timestampToScheduleSecondYield);

        if (secondYieldAmount == 0 && secondScheduleDeadline != 0) {
            vm.prank(strategyManager);
            vm.expectRevert("MBS:S:INVALID_DEADLINE");
            IBitcoinStrategy(targetStrategy).schedule(secondYieldAmount, uint32(secondScheduleDeadline));
            return;
        } else {
            vm.prank(strategyManager);
            IBitcoinStrategy(targetStrategy).schedule(secondYieldAmount, uint32(secondScheduleDeadline));
        }

        vm.warp(timestampToCheckSystemState);

        uint256 expectedStrategyAum            = deployedAssets[strategyIndex]  - defaultedAssets[strategyIndex];
        uint256 firstScheduleActualDuration    = timestampToScheduleSecondYield - startingTime;
        uint256 firstScheduleExpectedDuration  = firstScheduleDeadline          - startingTime;
        uint256 expectedYieldFromFirstSchedule = firstYieldAmount * firstScheduleActualDuration / firstScheduleExpectedDuration;

        if (timestampToCheckSystemState > secondScheduleDeadline) {
            uint256 expectedAccrualFromSecondYield = secondYieldAmount;

            expectedStrategyAum += expectedYieldFromFirstSchedule + expectedAccrualFromSecondYield;

            assertEq(IBitcoinStrategy(targetStrategy).assetsUnderManagement(), expectedStrategyAum);
        } else {
            uint256 secondYieldAmount_             = secondYieldAmount; // Avoid stack too deep error
            uint256 secondScheduleActualDuration   = timestampToCheckSystemState - timestampToScheduleSecondYield;
            uint256 secondScheduleExpectedDuration = secondScheduleDeadline      - timestampToScheduleSecondYield;
            uint256 expectedYieldFromSecondYield   = secondYieldAmount_ * secondScheduleActualDuration / secondScheduleExpectedDuration;

            expectedStrategyAum += expectedYieldFromFirstSchedule + expectedYieldFromSecondYield;

            assertEq(IBitcoinStrategy(targetStrategy).assetsUnderManagement(), expectedStrategyAum);
        }
    }

}
