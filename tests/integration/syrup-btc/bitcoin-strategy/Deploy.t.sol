// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetControllerOracle,
    Permit
} from "../../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../../TestBase.sol";

contract DeployTestBase is TestBase {

    address poolDepositor = makeAddr("poolDepositor");

    uint32 deadline;

    uint32 fullDuration    = 19 days;
    uint32 partialDuration = 13 days;

    uint256 feeRate       = 0.015e6;  // 1.5% in 1e6 precision.
    uint256 depositAmount = 125e8;

    // Unique fractions used for testing purposes.
    uint256 partialDeposit = depositAmount * 4 / 7;
    uint256 yieldAmount    = depositAmount / 27;

    uint256 partialYield   = yieldAmount * partialDuration / fullDuration;
    uint256 feeAmount      = yieldAmount * feeRate / 1e6;
    uint256 partialFees    = partialYield * feeRate / 1e6;

    function setUp() public virtual override {
        _setupBitcoinPool();

        deadline = startingTime + fullDuration;

        // Set the strategy fee rate.
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        // Deposit assets into the pool.
        depositAsset.mint(poolDepositor, depositAmount);

        vm.startPrank(poolDepositor);
        depositAsset.approve(address(bitcoinRouter), depositAmount);
        bitcoinRouter.deposit(address(depositAsset), depositAmount, "", emptyPermit());
        vm.stopPrank();
    }

    function assertAccounting(
        uint256 outstandingAssets,
        uint256 realizedFees,
        uint256 accruedYield,
        uint256 accruedFees
    )
        internal view
    {
        assertEq(bitcoinStrategy.outstandingAssets(), outstandingAssets);
        assertEq(bitcoinStrategy.realizedFees(),      realizedFees);
        assertEq(bitcoinStrategy.accruedYield(),      accruedYield);
        assertEq(bitcoinStrategy.accruedFees(),       accruedFees);

        uint256 assetsUnderManagement = outstandingAssets + accruedYield - accruedFees;

        assertEq(bitcoinStrategy.assetsUnderManagement(), assetsUnderManagement);
    }

    function assertSchedule(
        uint256 remainingYield,
        uint32  lastUpdated,
        uint32  remainingDuration
    )
        internal view
    {
        ( uint256 remainingYield_, uint32 lastUpdated_, uint32 remainingDuration_ ) = bitcoinStrategy.schedules(0);

        assertEq(remainingYield_,    remainingYield);
        assertEq(lastUpdated_,       lastUpdated);
        assertEq(remainingDuration_, remainingDuration);
    }

    function emptyPermit() internal pure returns (Permit memory permit) {
        permit = Permit(false, 0, 0, 0, 0);
    }

}

contract DeployFailureTests is DeployTestBase {

    function test_deploy_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyManager);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    function test_deploy_notValidScheduler() external {
        vm.expectRevert("MBS:NOT_ALLOWED");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    function test_deploy_zeroDeploymentAmount() external {
        vm.prank(strategyManager);
        vm.expectRevert("MBS:D:ZERO_AMOUNT");
        bitcoinStrategy.deploy(address(depositAsset), 0);
    }

    function test_deploy_missingAssetController() external {
        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), address(0));

        vm.prank(strategyManager);
        vm.expectRevert("MBS:D:NO_CONTROLLER");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    // Mocked since the oracle contract always converts at a 1:1 exchange rate.
    function test_deploy_zeroPrincipalRequested() external {
        vm.prank(strategyManager);
        vm.mockCall(
            address(assetController),
            abi.encodeWithSignature("previewDeploy(address,uint256)", address(depositAsset), partialDeposit),
            abi.encode(0)
        );
        vm.expectRevert("PM:RF:INVALID_PRINCIPAL");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    function test_deploy_invalidStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", address(bitcoinStrategyFactory), false);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_FACTORY");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    function test_deploy_zeroPoolSupply() external {
        // Redeem all pool shares to get the total supply to zero.
        vm.prank(poolDepositor);
        pool.approve(address(bitcoinRouter), depositAmount);

        vm.prank(poolDepositor);
        ( , uint256 requestId ) = bitcoinRouter.requestRedeem(address(depositAsset), depositAmount, "", emptyPermit());

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = requestId;

        processRedemptionByIds(address(pool), requestIds);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        // Attempt to deploy without any remaining pool shares.
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:ZERO_SUPPLY");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    function test_deploy_insufficientPoolLiquidity() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        bitcoinStrategy.deploy(address(depositAsset), depositAmount + 1);
    }

    function test_deploy_notValidStrategy() external {
        address[] memory addresses = new address[](1);
        bool[]    memory allowed   = new bool[](1);

        addresses[0] = address(bitcoinStrategy);
        allowed[0]   = false;

        vm.prank(governor);
        assetController.setStrategies(addresses, allowed);

        vm.prank(strategyManager);
        vm.expectRevert("AC:NOT_STRATEGY");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    function test_deploy_cantDepositAsset() external {
        address[] memory addresses  = new address[](1);
        bool[]    memory notAllowed = new bool[](1);

        addresses[0]  = address(depositAsset);
        notAllowed[0] = false;

        vm.prank(governor);
        assetController.setAssets(addresses, notAllowed, notAllowed, notAllowed, notAllowed);

        vm.prank(strategyManager);
        vm.expectRevert("AC:D:INVALID_ASSET");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    // Mocked so `previewDeploy()` returns one amount less than the asset controller tries to pull.
    function test_deploy_failedPoolAssetPull() external {
        vm.prank(strategyManager);
        vm.mockCall(
            address(assetController),
            abi.encodeWithSignature("previewDeploy(address,uint256)", address(depositAsset), partialDeposit),
            abi.encode(partialDeposit - 1)
        );
        vm.expectRevert("AC:D:COMPOSITE_ASSET_FAILURE");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    function test_deploy_failedDepositAssetPush() external {
        // Manually burn deposit assets so the controller doesn't have enough to push to the strategy.
        depositAsset.burn(address(assetController), 1);

        vm.prank(strategyManager);
        vm.expectRevert("AC:D:DEPOSIT_ASSET_FAILURE");
        bitcoinStrategy.deploy(address(depositAsset), depositAmount);
    }

    function test_deploy_notAssetController() external {
        address[] memory addresses = new address[](1);
        bool[]    memory allowed   = new bool[](1);

        addresses[0] = address(assetController);
        allowed[0]   = false;

        vm.prank(governor);
        compositeAsset.setAssetControllers(addresses, allowed);

        vm.prank(strategyManager);
        vm.expectRevert("CT:NOT_CONTROLLER");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    // Mocked so `previewDeploy()` converts 1:1, but a direct `convert()` call from the asset controller returns zero.
    function test_deploy_zeroBurnAmount() external {
        vm.prank(strategyManager);
        vm.mockCall(
            address(assetController),
            abi.encodeWithSignature(
                "previewDeploy(address,uint256)",
                address(depositAsset),
                partialDeposit
            ),
            abi.encode(partialDeposit)
        );
        vm.mockCall(
            address(priceOracle),
            abi.encodeWithSignature(
                "convert(address,address,uint256,bytes32)",
                address(depositAsset),
                address(compositeAsset),
                partialDeposit,
                bytes32("")
            ),
            abi.encode(0)
        );
        vm.expectRevert("CT:B:ZERO_AMOUNT");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

    // Mocked to revert the transfer.
    function test_deploy_failedDeployerPush() external {
        vm.prank(strategyManager);
        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                address(strategyManager),
                partialDeposit
            ),
            abi.encode(false)
        );
        vm.expectRevert("MBS:D:TRANSFER_FAILED");
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);
    }

}

contract DeploySuccessTests is DeployTestBase {

    function test_deploy_emptySchedule_partial() external {
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount - partialDeposit);
        assertEq(depositAsset.balanceOf(address(strategyManager)), partialDeposit);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount - partialDeposit);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount - partialDeposit);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount - partialDeposit);

        assertAccounting({
            outstandingAssets: partialDeposit,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0
        });
    }

    function test_deploy_emptySchedule_all() external {
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), depositAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), depositAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets: depositAmount,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0
        });
    }

    function test_deploy_newSchedule_partial() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount - partialDeposit);
        assertEq(depositAsset.balanceOf(address(strategyManager)), partialDeposit);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount - partialDeposit);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount - partialDeposit);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount - partialDeposit);

        assertAccounting({
            outstandingAssets: partialDeposit,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });
    }

    function test_deploy_newSchedule_all() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), depositAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), depositAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets: depositAmount,
            realizedFees:      0,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });
    }

    function test_deploy_duringSchedule_partial() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + partialDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      partialYield,
            accruedFees:       partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount - partialDeposit);
        assertEq(depositAsset.balanceOf(address(strategyManager)), partialDeposit);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount - partialDeposit);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount - partialDeposit);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount - partialDeposit);

        assertAccounting({
            outstandingAssets: partialDeposit + partialYield - partialFees,
            realizedFees:      partialFees,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration
        });
    }

    function test_deploy_duringSchedule_all() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + partialDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      partialYield,
            accruedFees:       partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), depositAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), depositAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets: depositAmount + partialYield - partialFees,
            realizedFees:      partialFees,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            lastUpdated:       startingTime + partialDuration
        });
    }

    function test_deploy_pastSchedule_partial() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      yieldAmount,
            accruedFees:       feeAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), partialDeposit);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount - partialDeposit);
        assertEq(depositAsset.balanceOf(address(strategyManager)), partialDeposit);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount - partialDeposit);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount - partialDeposit);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount - partialDeposit);

        assertAccounting({
            outstandingAssets: partialDeposit + yieldAmount - feeAmount,
            realizedFees:      feeAmount,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0
        });
    }

    function test_deploy_pastSchedule_all() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), 0);

        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);

        assertAccounting({
            outstandingAssets: 0,
            realizedFees:      0,
            accruedYield:      yieldAmount,
            accruedFees:       feeAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), depositAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), depositAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets: depositAmount + yieldAmount - feeAmount,
            realizedFees:      feeAmount,
            accruedYield:      0,
            accruedFees:       0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            lastUpdated:       0
        });
    }

}
