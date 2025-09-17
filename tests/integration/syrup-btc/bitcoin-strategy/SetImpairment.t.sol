// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SetImpairmentTestBase is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    uint32 deadline;
    uint32 fullDuration    = 12 days;
    uint32 partialDuration = 7 days;
    uint32 yieldGap        = 2 days;

    uint256 feeRate = 0.015e6;  // 1.5% in 1e6 precision.

    // Unique amounts used for testing purposes.
    uint256 principalAmount  = 89e8;
    uint256 partialPrincipal = principalAmount * 4 / 7;
    uint256 yieldAmount      = principalAmount / 27;
    uint256 feeAmount        = yieldAmount * feeRate / 1e6;

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

contract SetImpairmentFailureTests is SetImpairmentTestBase {

    function test_setImpairment_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.setImpairment(partialPrincipal);
    }

    function test_setImpairment_notAuthorized() external {
        vm.expectRevert("MBS:NOT_ADMIN");
        bitcoinStrategy.setImpairment(partialPrincipal);
    }

    function test_setImpairment_overImpaired() external {
        vm.prank(governor);
        vm.expectRevert("MBS:SI:OVER_IMPAIRED");
        bitcoinStrategy.setImpairment(principalAmount + 1);
    }

    function test_setImpairment_overImpaired_withSchedule() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration);
        vm.prank(governor);
        vm.expectRevert("MBS:SI:OVER_IMPAIRED");
        bitcoinStrategy.setImpairment(principalAmount + yieldAmount - feeAmount + 1);
    }

}

contract SetImpairmentSuccessTests is SetImpairmentTestBase {

    function test_setImpairment_partialImpairment() external {
        assertImpairment({
            impairedAssets:   0,
            unrealizedLosses: 0
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.prank(governor);
        bitcoinStrategy.setImpairment(partialPrincipal);

        assertImpairment({
            impairedAssets:   partialPrincipal,
            unrealizedLosses: partialPrincipal
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });
    }

    function test_setImpairment_principalImpairment() external {
        assertImpairment({
            impairedAssets:   0,
            unrealizedLosses: 0
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.prank(governor);
        bitcoinStrategy.setImpairment(principalAmount);

        assertImpairment({
            impairedAssets:   principalAmount,
            unrealizedLosses: principalAmount
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });
    }

    function test_setImpairment_yieldImpairment() external {
        assertImpairment({
            impairedAssets:   0,
            unrealizedLosses: 0
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.prank(governor);
        bitcoinStrategy.setImpairment(principalAmount);

        assertImpairment({
            impairedAssets:   principalAmount,
            unrealizedLosses: principalAmount
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration);
        vm.prank(governor);
        bitcoinStrategy.setImpairment(principalAmount + yieldAmount - feeAmount);

        assertImpairment({
            impairedAssets:   principalAmount + yieldAmount - feeAmount,
            unrealizedLosses: principalAmount + yieldAmount - feeAmount
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          yieldAmount,
            accruedFees:           feeAmount,
            assetsUnderManagement: principalAmount + yieldAmount - feeAmount
        });
    }

    function test_setImpairment_removeImpairment() external {
        assertImpairment({
            impairedAssets:   0,
            unrealizedLosses: 0
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.prank(governor);
        bitcoinStrategy.setImpairment(partialPrincipal);

        assertImpairment({
            impairedAssets:   partialPrincipal,
            unrealizedLosses: partialPrincipal
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.warp(startingTime + partialDuration);

        assertImpairment({
            impairedAssets:   partialPrincipal,
            unrealizedLosses: partialPrincipal
        });

        vm.prank(governor);
        bitcoinStrategy.setImpairment(0);

        assertImpairment({
            impairedAssets:   0,
            unrealizedLosses: 0
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });
    }

    function test_setImpairment_overImpairment() external {
        assertImpairment({
            impairedAssets:   0,
            unrealizedLosses: 0
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.prank(governor);
        bitcoinStrategy.setImpairment(principalAmount);

        assertImpairment({
            impairedAssets:   principalAmount,
            unrealizedLosses: principalAmount
        });

        assertAccounting({
            outstandingAssets:     principalAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount
        });

        vm.warp(startingTime + fullDuration);

        assertImpairment({
            impairedAssets:   principalAmount,
            unrealizedLosses: principalAmount
        });

        vm.startPrank(strategyManager);
        depositAsset.approve(address(bitcoinStrategy), partialPrincipal);
        bitcoinStrategy.reconcile(address(depositAsset), partialPrincipal);
        vm.stopPrank();

        assertImpairment({
            impairedAssets:   principalAmount,
            unrealizedLosses: principalAmount - partialPrincipal
        });

        assertAccounting({
            outstandingAssets:     principalAmount - partialPrincipal,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: principalAmount - partialPrincipal
        });

        assertEq(bitcoinStrategy.unrealizedLosses(), bitcoinStrategy.assetsUnderManagement());
    }

}
