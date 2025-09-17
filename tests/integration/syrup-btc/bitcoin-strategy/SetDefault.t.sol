// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SetDefaultTestBase is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    uint32 deadline;
    uint32 fullDuration    = 12 days;
    uint32 partialDuration = 7 days;
    uint32 yieldGap        = 2 days;

    uint256 feeRate   = 0.015e6;  // 1.5% in 1e6 precision.
    uint256 precision = 1e30;

    // Unique amounts used for testing purposes.
    uint256 principalAmount  = 89e8;
    uint256 partialPrincipal = principalAmount * 4 / 7;
    uint256 yieldAmount      = principalAmount / 27;

    uint256 partialYield = yieldAmount * partialDuration / fullDuration;
    uint256 feeAmount    = yieldAmount * feeRate / 1e6;
    uint256 partialFees  = partialYield * feeRate / 1e6;

    function setUp() public virtual override {
        super.setUp();

        deadline = startingTime + fullDuration;

        // Set the strategy fee rate.
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        // Deposit assets into the pool.
        depositAsset.mint(depositor, principalAmount);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), principalAmount);
        bitcoinRouter.deposit(address(depositAsset), principalAmount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        // Deploy assets from the pool.
        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), principalAmount);
    }

}

contract SetDefaultFailureTests is SetDefaultTestBase {

    function test_setDefault_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.setDefault(partialPrincipal);
    }

    function test_setDefault_notAuthorized() external {
        vm.expectRevert("MBS:NOT_ADMIN");
        bitcoinStrategy.setDefault(partialPrincipal);
    }

    function test_setDefault_overDefaulted() external {
        vm.prank(governor);
        vm.expectRevert("MBS:SD:OVER_DEFAULTED");
        bitcoinStrategy.setDefault(principalAmount + 1);
    }

    function test_setDefault_overDefaulted_withSchedule() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + partialDuration);
        vm.prank(governor);
        vm.expectRevert("MBS:SD:OVER_DEFAULTED");
        bitcoinStrategy.setDefault(principalAmount + partialYield - partialFees + 1);
    }

}

contract SetDefaultSuccessTests is SetDefaultTestBase {

    function test_setDefault_noOperation() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(0);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_setDefault_noSchedule_partialDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(partialPrincipal);

        assertAccounting({
            outstandingAssets:     principalAmount - partialPrincipal,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount - partialPrincipal
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_setDefault_noSchedule_fullDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(principalAmount);

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
    }

    function test_setDefault_newSchedule_partialDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(partialPrincipal);

        assertAccounting({
            outstandingAssets:     principalAmount - partialPrincipal,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount - partialPrincipal
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });
    }

    function test_setDefault_newSchedule_fullDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(principalAmount);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });
    }

    function test_setDefault_duringSchedule_partialDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: principalAmount + partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(partialPrincipal);

        assertAccounting({
            outstandingAssets:     principalAmount + partialYield - partialFees - partialPrincipal,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount + partialYield - partialFees - partialPrincipal
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (yieldAmount - partialYield) / (fullDuration - partialDuration)
        });
    }

    function test_setDefault_duringSchedule_fullDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: principalAmount + partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(principalAmount + partialYield - partialFees);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (yieldAmount - partialYield) / (fullDuration - partialDuration)
        });
    }

    function test_setDefault_pastSchedule_partialDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.warp(startingTime + fullDuration + yieldGap);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          yieldAmount,
            accruedFees:           feeAmount,
            assetsUnderManagement: principalAmount + yieldAmount - feeAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(partialPrincipal);

        assertAccounting({
            outstandingAssets:     principalAmount + yieldAmount - feeAmount - partialPrincipal,
            realizedFees:          feeAmount,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount + yieldAmount - feeAmount - partialPrincipal
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

    function test_setDefault_pastSchedule_fullDefault() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.warp(startingTime + fullDuration + yieldGap);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          yieldAmount,
            accruedFees:           feeAmount,
            assetsUnderManagement: principalAmount + yieldAmount - feeAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(principalAmount + yieldAmount - feeAmount);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          feeAmount,
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
    }

    function test_setDefault_multipleDefaults() external {
        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.warp(startingTime + partialDuration);

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: principalAmount + partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime,
            yieldRate:         precision * yieldAmount / fullDuration
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(principalAmount);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         precision * (yieldAmount - partialYield) / (fullDuration - partialDuration)
        });

        vm.warp(startingTime + fullDuration + yieldGap);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees,
            realizedFees:          partialFees,
            accruedYield:          yieldAmount - partialYield,
            accruedFees:           feeAmount - partialFees,
            assetsUnderManagement: yieldAmount - feeAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration,
            yieldRate:         0
        });

        vm.prank(governor);
        bitcoinStrategy.setDefault(partialYield);

        assertAccounting({
            outstandingAssets:     yieldAmount - feeAmount - partialYield,
            realizedFees:          feeAmount,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: yieldAmount - feeAmount - partialYield
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0,
            yieldRate:         0
        });
    }

}
