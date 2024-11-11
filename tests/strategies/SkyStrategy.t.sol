// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { stdStorage, StdStorage } from "../../modules/forge-std/src/Test.sol";

import {
    IERC20,
    IERC4626Like,
    IPool,
    IPoolManager,
    IPSMLike,
    ISkyStrategy
} from "../../contracts/interfaces/Interfaces.sol";

import { StrategyTestBase } from "./StrategyTestBase.sol";

contract SkyStrategyTestBase is StrategyTestBase {

    using stdStorage for StdStorage;

    uint256 constant USDC_PRECISION    = 1e6;   // USDC has 6 decimals.
    uint256 constant USDS_PRECISION    = 1e18;  // USDS has 18 decimals.
    uint256 constant CONVERSION_FACTOR = 1e12;  // Difference in precision between USDC and USDS.

    uint256 psmTin          = 3e16;
    uint256 psmTout         = 5e16;
    uint256 strategyFeeRate = 1e5;

    uint256 poolLiquidity = 13_000_000e6;

    IERC20       usdc;
    IERC20       usds;
    IERC4626Like susds;

    IPSMLike     litePsm;
    IPSMLike     psmWrapper;
    ISkyStrategy skyStrategy;

    function setUp() public virtual override {
        super.setUp();

        start = block.timestamp;

        usdc  = IERC20(USDC);
        usds  = IERC20(USDS);
        susds = IERC4626Like(SAVINGS_USDS);

        psmWrapper  = IPSMLike(USDS_LITE_PSM);
        litePsm     = IPSMLike(psmWrapper.psm());
        skyStrategy = ISkyStrategy(_getStrategy(skyStrategyFactory));

        // Adds an admin that is authorized to set tin/tout values on the PSM.
        stdstore
            .target(address(litePsm))
            .sig("wards(address)")
            .with_key(address(this))
            .checked_write(1);

        openPool(address(poolManager));
    }

    // Calculates the current total value of all sUSDS in the strategy.
    function _currentTotalAssets(uint256 psmTout_) internal view returns (uint256) {
        // Convert the sUSDS from the strategy into USDS.
        uint256 shares_  = susds.balanceOf(address(skyStrategy));
        uint256 usdsOut_ = susds.convertToAssets(shares_);

        // NOTE: Simplifies `_gemForUsds` function in the Sky Strategy
        // Convert the USDS into USDC and reduce by PSM output fees (if any).
        uint256 usdcOut_ = usdsOut_ * USDC_PRECISION / (USDS_PRECISION + psmTout_);

        return usdcOut_;
    }

    // Sets strategy and PSM fees.
    function _setFees(uint256 strategyFeeRate_, uint256 psmTin_, uint256 psmTout_) internal {
        // Set the strategy fee rate.
        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(strategyFeeRate_);

        // Set the PSM fee rates.
        litePsm.file("tin",  psmTin_);
        litePsm.file("tout", psmTout_);
    }

    // Calculates how much USDC will be withdrawable after it is deposited.
    function _reduceByPsmFees(uint256 usdcIn_, uint256 psmTin_, uint256 psmTout_) internal pure returns (uint256) {
        // Convert USDC to USDS and reduce it by the PSM input fee (if any).
        uint256 usdsOut_ = (usdcIn_ * CONVERSION_FACTOR) - ((usdcIn_ * psmTin_) / USDC_PRECISION);

        // NOTE: Simplifies `_gemForUsds` function in the Sky Strategy
        // Convert USDS to USDC and reduce it by the PSM output fee (if any).
        uint256 usdcOut_ = usdsOut_ * USDC_PRECISION / (USDS_PRECISION + psmTout_);

        return usdcOut_;
    }

}

contract SkyStrategyFundStrategyTests is SkyStrategyTestBase {

    uint256 initialUsdcIn = 5_000_000e6;
    uint256 smallUsdcIn   = 1_000;
    uint256 usdcIn        = 2_500_000e6;

    uint256 initialUsdcOut = _reduceByPsmFees(initialUsdcIn, psmTin, psmTout);
    uint256 smallUsdcOut   = _reduceByPsmFees(smallUsdcIn,   psmTin, psmTout);
    uint256 usdcOut        = _reduceByPsmFees(usdcIn,        psmTin, psmTout);

    uint256 initialUsdcDiff = initialUsdcIn - initialUsdcOut;
    uint256 smallUsdcDiff   = smallUsdcIn - smallUsdcOut;
    uint256 usdcDiff        = usdcIn - usdcOut;

    function setUp() public virtual override {
        super.setUp();
    }

    function test_fundStrategy_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_notPoolDelegate() external {
        vm.expectRevert("MS:NOT_MANAGER");
        skyStrategy.fundStrategy(usdcIn);

        deposit(address(this), poolLiquidity);

        vm.prank(poolDelegate);
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_notStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        skyStrategy.fundStrategy(usdcIn);

        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_strategyImpaired() external {
        vm.prank(governor);
        skyStrategy.impairStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_strategyInactive() external {
        vm.prank(governor);
        skyStrategy.deactivateStrategy();

        vm.prank(strategyManager);
        vm.expectRevert("MS:NOT_ACTIVE");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_invalidVault() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS, false);

        vm.prank(strategyManager);
        vm.expectRevert("MSS:FS:INVALID_STRATEGY_VAULT");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_invalidPsm() external {
        vm.prank(governor);
        globals.setValidInstanceOf("PSM", USDS_LITE_PSM, false);

        vm.prank(strategyManager);
        vm.expectRevert("MSS:FS:INVALID_PSM");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_zeroPrincipal() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_PRINCIPAL");
        skyStrategy.fundStrategy(0);
    }

    function test_fundStrategy_invalidStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", skyStrategyFactory, false);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INVALID_FACTORY");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_zeroSupply() external {
        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:ZERO_SUPPLY");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_insufficientCover() external {
        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), 1);

        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:INSUFFICIENT_COVER");
        skyStrategy.fundStrategy(usdcIn);
    }

    function test_fundStrategy_insufficientLiquidity() external {
        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        skyStrategy.fundStrategy(poolLiquidity + 1);
    }

    function test_fundStrategy_psmHalted() external {
        // TODO: https://github.com/makerdao/dss-lite-psm/blob/main/src/DssLitePsm.sol#L312
    }

    function test_fundStrategy_initialFund_noFees() external {
        deposit(address(this), poolLiquidity);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), 0, 1);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcIn, 1);
    }

    function test_fundStrategy_fundWhenStagnant_noFees() external {
        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn + usdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn + usdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn + usdcIn, 1);
    }

    function test_fundStrategy_fundAfterGain_noFees() external {
        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(0) - skyStrategy.lastRecordedTotalAssets();

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(yield, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn + usdcIn + yield, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn + usdcIn + yield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn + usdcIn + yield, 1);
    }

    function test_fundStrategy_fundAfterLoss_noFees() external {
        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 2);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn + usdcIn - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn + usdcIn - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn + usdcIn - loss, 1);
    }

    // TODO: Add this test for the AaveStrategy.
    function test_fundStrategy_fundAfterCompleteLoss_noFees() external {
        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance);

        uint256 currentTotalAssets = _currentTotalAssets(0);

        assertEq(currentTotalAssets, 0);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - currentTotalAssets;

        assertEq(loss, initialUsdcIn);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcIn, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcIn, 1);
    }

    function test_fundStrategy_initialFund_strategyFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcIn, 1);
    }

    function test_fundStrategy_fundWhenStagnant_strategyFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn + usdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn + usdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn + usdcIn, 1);
    }

    function test_fundStrategy_fundAfterGain_strategyFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(0) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(yield, 0);
        assertGt(fees,  0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    fees);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn + usdcIn + yield - fees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn + usdcIn + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn + usdcIn + yield - fees, 1);
    }

    function test_fundStrategy_fundAfterGain_strategyFeesRoundedToZero() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(smallUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - smallUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   smallUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), smallUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), smallUsdcIn, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(0) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(yield, 0);
        assertEq(fees,  0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - smallUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   smallUsdcIn + usdcIn + yield, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), smallUsdcIn + usdcIn + yield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);

        assertApproxEqAbs(_currentTotalAssets(0), smallUsdcIn + usdcIn + yield, 1);
    }

    function test_fundStrategy_fundAfterLoss_strategyFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 2);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn + usdcIn - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn + usdcIn - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn + usdcIn - loss, 1);
    }

    // TODO: Add this test for the AaveStrategy.
    function test_fundStrategy_fundAfterCompleteLoss_strategyFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), initialUsdcIn, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance);

        uint256 currentTotalAssets = _currentTotalAssets(0);

        assertEq(currentTotalAssets, 0);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - currentTotalAssets;

        assertEq(loss, initialUsdcIn);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcIn, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcIn, 1);
    }

    function test_fundStrategy_initialFund_psmFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - usdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcOut, 1);
    }

    function test_fundStrategy_fundWhenStagnant_psmFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut + usdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut + usdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff - usdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut + usdcOut, 1);
    }

    function test_fundStrategy_fundAfterGain_psmFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(yield, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut + usdcOut + yield, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut + usdcOut + yield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff - usdcDiff + yield, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut + usdcOut + yield, 1);
    }

    function test_fundStrategy_fundAfterLoss_psmFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 2);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut + usdcOut - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut + usdcOut - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff - usdcDiff - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut + usdcOut - loss, 1);
    }

    function test_fundStrategy_fundAfterCompleteLoss_psmFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance);

        uint256 currentTotalAssets = _currentTotalAssets(psmTout);

        assertEq(currentTotalAssets, 0);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - currentTotalAssets;

        assertEq(loss, initialUsdcOut);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcOut - initialUsdcDiff - usdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcOut, 1);
    }

    function test_fundStrategy_initialFund_allFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - usdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcOut, 1);
    }

    function test_fundStrategy_fundWhenStagnant_allFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut + usdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut + usdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff - usdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut + usdcOut, 1);
    }

    function test_fundStrategy_fundAfterGain_allFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(yield, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    fees);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut + usdcOut + yield - fees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut + usdcOut + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff - usdcDiff + yield - fees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut + usdcOut + yield - fees, 1);
    }

    function test_fundStrategy_fundAfterGain_allFees_withStrategyFeesRoundedToZero() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(smallUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - smallUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   smallUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), smallUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - smallUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), smallUsdcOut, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(yield, 0);
        assertEq(fees,  0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - smallUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   smallUsdcOut + usdcOut + yield, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), smallUsdcOut + usdcOut + yield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - smallUsdcDiff - usdcDiff + yield, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), smallUsdcOut + usdcOut + yield, 1);
    }

    function test_fundStrategy_fundAfterLoss_allFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 2);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut + usdcOut - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut + usdcOut - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff - usdcDiff - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut + usdcOut - loss, 1);
    }

    function test_fundStrategy_fundAfterCompleteLoss_allFees() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(initialUsdcIn);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   initialUsdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), initialUsdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), initialUsdcOut, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance);

        uint256 currentTotalAssets = _currentTotalAssets(psmTout);

        assertEq(currentTotalAssets, 0);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - currentTotalAssets;

        assertEq(loss, initialUsdcOut);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        assertGt(loss, 0);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - initialUsdcIn - usdcIn);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(usds.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcOut, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcOut, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - initialUsdcOut - initialUsdcDiff - usdcDiff, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcOut, 1);
    }

}

// TODO: Add tests for when the strategy is impaired or deactivated.
contract SkyStrategyWithdrawFromStrategyTests is SkyStrategyTestBase {

    uint256 usdcToFund     = 2_500_000e6;
    uint256 usdcToWithdraw = 875_000e6;

    uint256 psmFees = usdcToFund - _reduceByPsmFees(usdcToFund, psmTin, psmTout);

    function setUp() public virtual override {
        super.setUp();
    }

    function test_withdrawFromStrategy_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);
    }

    function test_withdrawFromStrategy_notPoolDelegate() external {
        deposit(address(this), poolLiquidity);

        vm.prank(poolDelegate);
        skyStrategy.fundStrategy(poolLiquidity);

        vm.expectRevert("MS:NOT_MANAGER");
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        vm.prank(poolDelegate);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);
    }

    function test_withdrawFromStrategy_notStrategyManager() external {
        deposit(address(this), poolLiquidity);

        vm.prank(poolDelegate);
        skyStrategy.fundStrategy(poolLiquidity);

        vm.expectRevert("MS:NOT_MANAGER");
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);
    }

    function test_withdrawFromStrategy_zeroAssets() external {
        vm.prank(strategyManager);
        vm.expectRevert("MSS:WFS:ZERO_ASSETS");
        skyStrategy.withdrawFromStrategy(0);
    }

    function test_withdrawFromStrategy_lowAssets() external {
        deposit(address(this), poolLiquidity);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        uint256 assetsAvailable = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        vm.expectRevert("MSS:WFS:LOW_ASSETS");
        skyStrategy.withdrawFromStrategy(assetsAvailable + 1);
    }

    function test_withdrawFromStrategy_activeStrategy_noFees_whenStagnant_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - usdcToWithdraw, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - usdcToWithdraw, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund - usdcToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_noFees_whenStagnant_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertApproxEqAbs(usdc.balanceOf(address(pool)), poolLiquidity, 1);

        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_noFees_afterGain_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(0) - skyStrategy.lastRecordedTotalAssets();

        assertGt(yield, 0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - usdcToWithdraw + yield, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - usdcToWithdraw + yield, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund - usdcToWithdraw + yield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_noFees_afterGain_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(0) - skyStrategy.lastRecordedTotalAssets();

        assertGt(yield, 0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity + yield);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertEq(pool.totalAssets(), poolLiquidity + yield);
    }

    function test_withdrawFromStrategy_activeStrategy_noFees_afterLoss_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(0);

        assertGt(loss, 0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - usdcToWithdraw - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_noFees_afterLoss_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(0);

        assertGt(loss, 0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - loss);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_strategyFees_whenStagnant_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - usdcToWithdraw, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - usdcToWithdraw, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund - usdcToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_strategyFees_whenStagnant_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertApproxEqAbs(usdc.balanceOf(address(pool)), poolLiquidity, 1);

        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_strategyFees_afterGain_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(0) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        assertGt(yield, 0);
        assertGt(fees,  0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    fees);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - usdcToWithdraw + yield - fees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - usdcToWithdraw + yield - fees, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund - usdcToWithdraw + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity + yield - fees, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_strategyFees_afterGain_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(0) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        assertGt(yield, 0);
        assertGt(fees,  0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity + yield - fees);
        assertEq(usdc.balanceOf(address(treasury)),    fees);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertEq(pool.totalAssets(), poolLiquidity + yield - fees);
    }

    function test_withdrawFromStrategy_activeStrategy_strategyFees_afterLoss_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(0);

        assertGt(loss, 0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - usdcToWithdraw - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - loss, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_strategyFees_afterLoss_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, 0, 0);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  0);
        assertEq(psmWrapper.tout(), 0);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund, 1);

        assertApproxEqAbs(_currentTotalAssets(0), usdcToFund, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(0);

        assertGt(loss, 0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - loss);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertEq(pool.totalAssets(), poolLiquidity - loss);
    }

    function test_withdrawFromStrategy_activeStrategy_psmFees_whenStagnant_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees - usdcToWithdraw, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees - usdcToWithdraw, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees - usdcToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_psmFees_whenStagnant_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - psmFees);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertEq(pool.totalAssets(), poolLiquidity - psmFees);
    }

    function test_withdrawFromStrategy_activeStrategy_psmFees_afterGain_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();

        assertGt(yield, 0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees - usdcToWithdraw + yield, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees - usdcToWithdraw + yield, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees - usdcToWithdraw + yield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees + yield, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_psmFees_afterGain_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();

        assertGt(yield, 0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - psmFees + yield);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(psmTout), 0);

        assertEq(pool.totalAssets(), poolLiquidity - psmFees + yield);
    }

    function test_withdrawFromStrategy_activeStrategy_psmFees_afterLoss_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        assertGt(loss, 0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees - usdcToWithdraw - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees - loss, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_psmFees_afterLoss_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(0, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        assertGt(loss, 0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - psmFees - loss);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(psmTout), 0);

        assertEq(pool.totalAssets(), poolLiquidity - psmFees - loss);
    }

    function test_withdrawFromStrategy_activeStrategy_allFees_whenStagnant_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees - usdcToWithdraw, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees - usdcToWithdraw, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees - usdcToWithdraw, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_allFees_whenStagnant_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - psmFees);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(0), 0);

        assertEq(pool.totalAssets(), poolLiquidity - psmFees);
    }

    function test_withdrawFromStrategy_activeStrategy_allFees_afterGain_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        assertGt(yield, 0);
        assertGt(fees,  0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    fees);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees - usdcToWithdraw + yield - fees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees - usdcToWithdraw + yield - fees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees - usdcToWithdraw + yield - fees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees + yield - fees, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_allFees_afterGain_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Accrue yield for 10 days.
        vm.warp(start + 10 days);

        uint256 yield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();
        uint256 fees  = yield * strategyFeeRate / 1e6;

        assertGt(yield, 0);
        assertGt(fees,  0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - psmFees + yield - fees);
        assertEq(usdc.balanceOf(address(treasury)),    fees);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(psmTout), 0);

        assertEq(pool.totalAssets(), poolLiquidity - psmFees + yield - fees);
    }

    function test_withdrawFromStrategy_activeStrategy_allFees_afterLoss_partialWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        assertGt(loss, 0);

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(usdcToWithdraw);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund + usdcToWithdraw);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees - usdcToWithdraw - loss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees - usdcToWithdraw - loss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees - loss, 1);
    }

    function test_withdrawFromStrategy_activeStrategy_allFees_afterLoss_fullWithdrawal() external {
        deposit(address(this), poolLiquidity);
        _setFees(strategyFeeRate, psmTin, psmTout);

        assertEq(skyStrategy.strategyFeeRate(), strategyFeeRate);

        assertEq(psmWrapper.tin(),  psmTin);
        assertEq(psmWrapper.tout(), psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcToFund);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - usdcToFund);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcToFund - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcToFund - psmFees, 1);

        assertApproxEqAbs(_currentTotalAssets(psmTout), usdcToFund - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Incur losses after 10 days by transferring out sUSDS shares.
        uint256 susdsBalance = susds.balanceOf(address(skyStrategy));

        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), susdsBalance / 3);

        uint256 loss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        assertGt(loss, 0);

        uint256 aum = skyStrategy.assetsUnderManagement();

        vm.prank(strategyManager);
        skyStrategy.withdrawFromStrategy(aum);

        assertEq(usdc.balanceOf(address(pool)),        poolLiquidity - psmFees - loss);
        assertEq(usdc.balanceOf(address(treasury)),    0);
        assertEq(usdc.balanceOf(address(skyStrategy)), 0);

        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);

        assertEq(_currentTotalAssets(psmTout), 0);

        assertEq(pool.totalAssets(), poolLiquidity - psmFees - loss);
    }

}

contract SkyStrategySetStrategyFeeTests is SkyStrategyTestBase {

    uint256 usdcIn  = 2_500_000e6;
    uint256 usdcOut = _reduceByPsmFees(usdcIn, psmTin, psmTout);
    uint256 psmFees = usdcIn - usdcOut;
    uint256 lostShares;

    uint256 oldFeeRate = 0.1e6;
    uint256 newFeeRate = 0.15e6;

    function setUp() public override virtual {
        super.setUp();

        deposit(address(this), poolLiquidity);

        _setFees(0, psmTin, psmTout);

        vm.prank(strategyManager);
        skyStrategy.fundStrategy(usdcIn);

        lostShares = susds.balanceOf(address(skyStrategy)) / 3;
    }

    function test_setStrategyFeeRate_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        skyStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_setStrategyFeeRate_notAdmin() external {
        vm.expectRevert("MS:NOT_ADMIN");
        skyStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(poolDelegate);
        skyStrategy.setStrategyFeeRate(strategyFeeRate);

        vm.prank(operationalAdmin);
        skyStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_setStrategyFeeRate_impaired() external {
        vm.prank(governor);
        skyStrategy.impairStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:NOT_ACTIVE");
        skyStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_setStrategyFeeRate_deactivated() external {
        vm.prank(governor);
        skyStrategy.deactivateStrategy();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:NOT_ACTIVE");
        skyStrategy.setStrategyFeeRate(strategyFeeRate);
    }

    function test_setStrategyFeeRate_invalidFeeRate() external {
        vm.prank(governor);
        vm.expectRevert("MSS:SSFR:INVALID_STRATEGY_FEE_RATE");
        skyStrategy.setStrategyFeeRate(1e6 + 1);
    }

    function test_setStrategyFeeRate_initialFeeRate_flat() external {
        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(0);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), newFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);
    }

    function test_setStrategyFeeRate_initialFeeRate_gain() external {
        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(0);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Accrue yield.
        vm.warp(start + 10 days);

        uint256 strategyYield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();

        assertGt(strategyYield, 0);

        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), newFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees + strategyYield, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees + strategyYield, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees + strategyYield, 1);

        // Accrue yield while charging fees.
        vm.warp(start + 20 days);

        uint256 newStrategyYield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();
        uint256 strategyFees     = newStrategyYield * newFeeRate / 1e6;

        assertGt(newStrategyYield, 0);
        assertGt(strategyFees,     0);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees + strategyYield + newStrategyYield - strategyFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees + strategyYield,                                   1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees + strategyYield + newStrategyYield - strategyFees, 1);
    }

    function test_setStrategyFeeRate_initialFeeRate_loss() external {
        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(0);

        assertEq(skyStrategy.strategyFeeRate(), 0);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Incur losses.
        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), lostShares);

        uint256 strategyLoss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        assertGt(strategyLoss, 0);

        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), newFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees - strategyLoss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees - strategyLoss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees - strategyLoss, 1);
    }

    function test_setStrategyFeeRate_updatedFeeRate_flat() external {
        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(oldFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), oldFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), newFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);
    }

    function test_setStrategyFeeRate_updatedFeeRate_gain() external {
        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(oldFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), oldFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Accrue yield.
        vm.warp(start + 10 days);

        uint256 strategyYield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();
        uint256 strategyFees  = strategyYield * oldFeeRate / 1e6;

        assertGt(strategyYield, 0);
        assertGt(strategyFees,  0);

        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), newFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), strategyFees);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees + strategyYield - strategyFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees + strategyYield - strategyFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees + strategyYield - strategyFees, 1);

        // Accrue yield while charging fees.
        vm.warp(start + 20 days);

        uint256 newStrategyYield = _currentTotalAssets(psmTout) - skyStrategy.lastRecordedTotalAssets();
        uint256 newStrategyFees  = newStrategyYield * newFeeRate / 1e6;

        assertGt(newStrategyYield, 0);
        assertGt(newStrategyFees,  0);

        uint256 lastRecordedTotalAssets = usdcIn - psmFees + strategyYield - strategyFees;
        uint256 assetsUnderManagement   = lastRecordedTotalAssets + newStrategyYield - newStrategyFees;
        uint256 poolTotalAssets         = poolLiquidity - psmFees + strategyYield - strategyFees + newStrategyYield - newStrategyFees;

        assertEq(usdc.balanceOf(address(treasury)), strategyFees);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   assetsUnderManagement,   1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), lastRecordedTotalAssets, 1);

        assertApproxEqAbs(pool.totalAssets(), poolTotalAssets, 1);
    }

    function test_setStrategyFeeRate_updatedFeeRate_loss() external {
        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(oldFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), oldFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees, 1);

        // Incur losses.
        vm.warp(start + 10 days);
        vm.prank(address(skyStrategy));
        susds.transfer(address(1), lostShares);

        uint256 strategyLoss = skyStrategy.lastRecordedTotalAssets() - _currentTotalAssets(psmTout);

        assertGt(strategyLoss, 0);

        vm.prank(governor);
        skyStrategy.setStrategyFeeRate(newFeeRate);

        assertEq(skyStrategy.strategyFeeRate(), newFeeRate);

        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),   usdcIn - psmFees - strategyLoss, 1);
        assertApproxEqAbs(skyStrategy.lastRecordedTotalAssets(), usdcIn - psmFees - strategyLoss, 1);

        assertApproxEqAbs(pool.totalAssets(), poolLiquidity - psmFees - strategyLoss, 1);
    }

}
