// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAllocationStrategy, IAaveV3Strategy, IERC20, IStrategyManager, ISkyStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";
import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";
import { SkyStrategyTestBase } from "../../integration/sky-strategy/SkyStrategyTestBase.sol";

contract AaveV3StrategyFeeRecipientAndRateChangeTests is AaveV3StrategyTestBase {

    address newStrategyDelegate = makeAddr("newStrategyDelegate");
    address newTreasury         = makeAddr("newTreasury");

    bool isSparkLend;

    uint32 delegateFeeRate    = 0.1e6; // 10% of accrued yield.
    uint32 newDelegateFeeRate = 0.2e6; // 20% of future accrued yield.
    uint32 newProtocolFeeRate = 0.1e6; // 10% of future accrued yield.
    uint32 protocolFeeRate    = 0.05e6; // 5% of accrued yield.

    uint256 collectionFunding = 10_000e6;
    uint256 fundAmount        = 500_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 roundingError     = 1;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function testFork_changeMapleTreasury_afterYieldAccrues() external {
        /**********************************************************************************************************************************/
        /*** Set nonzero fees, fund the strategy and accrue one year of yield                                                           ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = isSparkLend ? fundAmount : fundAmount - roundingError; // 500_000e6 for Spark, 500_000e6 - 1 for Aave.

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield  = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy) - fundedAssets;
        uint256 delegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAssets   = fundedAssets + grossYield - delegateFee - protocolFee;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAssets,
            aTokenBalance:           fundedAssets + grossYield,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegate(),        strategyDelegate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).mapleTreasury(),           treasury);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);
        assertEq(fundsAsset.balanceOf(newTreasury),      0);

        /**********************************************************************************************************************************/
        /*** Rotate the treasury and collect every unpaid fee into the current recipients                                               ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        globals.setMapleTreasury(newTreasury);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, collectionFunding);

        uint256 firstRecordedAssets = isSparkLend ? netAssets + collectionFunding - roundingError : netAssets + collectionFunding;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     firstRecordedAssets,
            aTokenBalance:           firstRecordedAssets,
            lastRecordedTotalAssets: firstRecordedAssets,
            unrealizedLosses:        0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegate(),        strategyDelegate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).mapleTreasury(),           newTreasury);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         0);
        assertEq(fundsAsset.balanceOf(newTreasury),      protocolFee);

        /**********************************************************************************************************************************/
        /*** Trigger collection again without new yield and prove no recipient is paid twice                                            ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, collectionFunding);

        uint256 secondRecordedAssets =
            isSparkLend ? firstRecordedAssets + collectionFunding : firstRecordedAssets + collectionFunding - roundingError;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     secondRecordedAssets,
            aTokenBalance:           secondRecordedAssets,
            lastRecordedTotalAssets: secondRecordedAssets,
            unrealizedLosses:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         0);
        assertEq(fundsAsset.balanceOf(newTreasury),      protocolFee);
    }

    function testFork_changeStrategyDelegate_afterYieldAccrues() external {
        /**********************************************************************************************************************************/
        /*** Set nonzero fees, fund the strategy and accrue one year of yield                                                           ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 fundedAssets = isSparkLend ? fundAmount : fundAmount - roundingError; // 500_000e6 for Spark, 500_000e6 - 1 for Aave.

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield  = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy) - fundedAssets;
        uint256 delegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAssets   = fundedAssets + grossYield - delegateFee - protocolFee;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAssets,
            aTokenBalance:           fundedAssets + grossYield,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegate(),        strategyDelegate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).mapleTreasury(),           treasury);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate),    0);
        assertEq(fundsAsset.balanceOf(newStrategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),            0);

        /**********************************************************************************************************************************/
        /*** Rotate the Strategy Delegate and collect every unpaid fee into the current recipients                                      ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        globals.setValidStrategyDelegate(newStrategyDelegate, true);

        vm.prank(operationalAdmin);
        IStrategyManager(aaveV3StrategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        IStrategyManager(aaveV3StrategyManager).acceptStrategyDelegate();

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, collectionFunding);

        uint256 firstRecordedAssets = isSparkLend ? netAssets + collectionFunding - roundingError : netAssets + collectionFunding;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     firstRecordedAssets,
            aTokenBalance:           firstRecordedAssets,
            lastRecordedTotalAssets: firstRecordedAssets,
            unrealizedLosses:        0
        });

        assertEq(IStrategyManager(aaveV3StrategyManager).strategyDelegate(),        newStrategyDelegate);
        assertEq(IStrategyManager(aaveV3StrategyManager).pendingStrategyDelegate(), address(0));

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegate(),        newStrategyDelegate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).mapleTreasury(),           treasury);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate),    0);
        assertEq(fundsAsset.balanceOf(newStrategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),            protocolFee);

        /**********************************************************************************************************************************/
        /*** Trigger collection again without new yield and prove no recipient is paid twice                                            ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, collectionFunding);

        uint256 secondRecordedAssets =
            isSparkLend ? firstRecordedAssets + collectionFunding : firstRecordedAssets + collectionFunding - roundingError;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     secondRecordedAssets,
            aTokenBalance:           secondRecordedAssets,
            lastRecordedTotalAssets: secondRecordedAssets,
            unrealizedLosses:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate),    0);
        assertEq(fundsAsset.balanceOf(newStrategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),            protocolFee);
    }

    function testFork_changeNonzeroFeeRates_afterFeesCollected() external {
        /**********************************************************************************************************************************/
        /*** Set the old rates, fund the strategy and collect the first yield tranche                                                   ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        uint256 recordedAssets = isSparkLend ? fundAmount : fundAmount - roundingError; // 500_000e6 for Spark, 500_000e6 - 1 for Aave.

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield  = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy) - recordedAssets;
        uint256 delegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAssets   = recordedAssets + grossYield - delegateFee - protocolFee;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAssets,
            aTokenBalance:           recordedAssets + grossYield,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, collectionFunding);

        recordedAssets = isSparkLend ? netAssets + collectionFunding - roundingError : netAssets + collectionFunding;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     recordedAssets,
            aTokenBalance:           recordedAssets,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        /**********************************************************************************************************************************/
        /*** Accrue tranche two and change the delegate rate after collecting both fees at the old rates                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        grossYield = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy) - recordedAssets;
        netAssets =
            recordedAssets + grossYield - grossYield * delegateFeeRate / HUNDRED_PERCENT - grossYield * protocolFeeRate / HUNDRED_PERCENT;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAssets,
            aTokenBalance:           recordedAssets + grossYield,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyDelegateFeeRate(newDelegateFeeRate);

        recordedAssets = netAssets;
        delegateFee   += grossYield * delegateFeeRate / HUNDRED_PERCENT;
        protocolFee   += grossYield * protocolFeeRate / HUNDRED_PERCENT;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     recordedAssets,
            aTokenBalance:           recordedAssets,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        /**********************************************************************************************************************************/
        /*** Accrue tranche three and change the protocol rate after using the new delegate and old protocol rates                      ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        grossYield = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy) - recordedAssets;
        netAssets = recordedAssets + grossYield - grossYield * newDelegateFeeRate / HUNDRED_PERCENT - grossYield * protocolFeeRate
            / HUNDRED_PERCENT;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAssets,
            aTokenBalance:           recordedAssets + grossYield,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyProtocolFeeRate(newProtocolFeeRate);

        recordedAssets = isSparkLend ? netAssets - roundingError : netAssets;
        delegateFee   += grossYield * newDelegateFeeRate / HUNDRED_PERCENT;
        protocolFee   += grossYield * protocolFeeRate / HUNDRED_PERCENT;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     recordedAssets,
            aTokenBalance:           recordedAssets,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        /**********************************************************************************************************************************/
        /*** Accrue and collect tranche four using both new rates                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        grossYield = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy) - recordedAssets;
        netAssets = recordedAssets + grossYield - grossYield * newDelegateFeeRate / HUNDRED_PERCENT - grossYield * newProtocolFeeRate
            / HUNDRED_PERCENT;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAssets,
            aTokenBalance:           recordedAssets + grossYield,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, collectionFunding);

        recordedAssets = isSparkLend ? netAssets + collectionFunding + roundingError : netAssets + collectionFunding - roundingError;
        delegateFee   += grossYield * newDelegateFeeRate / HUNDRED_PERCENT;
        protocolFee   += grossYield * newProtocolFeeRate / HUNDRED_PERCENT;

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     recordedAssets,
            aTokenBalance:           recordedAssets,
            lastRecordedTotalAssets: recordedAssets,
            unrealizedLosses:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);
    }

}

contract SparkLendStrategyFeeRecipientAndRateChangeTests is AaveV3StrategyFeeRecipientAndRateChangeTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        isSparkLend                 = true;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract SkyStrategyFeeRecipientAndRateChangeTests is SkyStrategyTestBase {

    address newStrategyDelegate = makeAddr("newStrategyDelegate");
    address newTreasury         = makeAddr("newTreasury");

    uint32 delegateFeeRate    = 0.1e6; // 10% of accrued yield.
    uint32 newDelegateFeeRate = 0.2e6; // 20% of future accrued yield.
    uint32 newProtocolFeeRate = 0.1e6; // 10% of future accrued yield.
    uint32 protocolFeeRate    = 0.05e6; // 5% of accrued yield.

    uint256 collectionFunding = 10_000e6;
    uint256 fundAmount        = 500_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 roundingError     = 1;

    function setUp() public override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function testFork_changeMapleTreasury_afterYieldAccrues() external {
        /**********************************************************************************************************************************/
        /*** Set nonzero fees, fund the strategy and accrue one year of yield                                                           ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - roundingError; // 500_000e6 - 1.

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield  = (fundedAssets + roundingError) * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 delegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAssets   = fundedAssets + grossYield - delegateFee - protocolFee;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAssets
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegate(),        strategyDelegate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).mapleTreasury(),           treasury);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);
        assertEq(fundsAsset.balanceOf(newTreasury),      0);

        /**********************************************************************************************************************************/
        /*** Rotate the treasury and collect every unpaid fee into the current recipients                                               ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        globals.setMapleTreasury(newTreasury);

        fundStrategyManager(address(poolManager), skyStrategyManager, collectionFunding);

        uint256 firstRecordedAssets = netAssets + collectionFunding;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstRecordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: firstRecordedAssets
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegate(),        strategyDelegate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).mapleTreasury(),           newTreasury);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         0);
        assertEq(fundsAsset.balanceOf(newTreasury),      protocolFee);

        /**********************************************************************************************************************************/
        /*** Trigger collection again without new yield and prove no recipient is paid twice                                            ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, collectionFunding);

        uint256 secondRecordedAssets = firstRecordedAssets + collectionFunding;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              secondRecordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: secondRecordedAssets
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         0);
        assertEq(fundsAsset.balanceOf(newTreasury),      protocolFee);
    }

    function testFork_changeStrategyDelegate_afterYieldAccrues() external {
        /**********************************************************************************************************************************/
        /*** Set nonzero fees, fund the strategy and accrue one year of yield                                                           ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 fundedAssets = fundAmount - roundingError; // 500_000e6 - 1.

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield  = (fundedAssets + roundingError) * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 delegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAssets   = fundedAssets + grossYield - delegateFee - protocolFee;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAssets
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegate(),        strategyDelegate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).mapleTreasury(),           treasury);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate),    0);
        assertEq(fundsAsset.balanceOf(newStrategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),            0);

        /**********************************************************************************************************************************/
        /*** Rotate the Strategy Delegate and collect every unpaid fee into the current recipients                                      ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        globals.setValidStrategyDelegate(newStrategyDelegate, true);

        vm.prank(operationalAdmin);
        IStrategyManager(skyStrategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        IStrategyManager(skyStrategyManager).acceptStrategyDelegate();

        fundStrategyManager(address(poolManager), skyStrategyManager, collectionFunding);

        uint256 firstRecordedAssets = netAssets + collectionFunding;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstRecordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: firstRecordedAssets
        });

        assertEq(IStrategyManager(skyStrategyManager).strategyDelegate(),        newStrategyDelegate);
        assertEq(IStrategyManager(skyStrategyManager).pendingStrategyDelegate(), address(0));

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegate(),        newStrategyDelegate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).mapleTreasury(),           treasury);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate),    0);
        assertEq(fundsAsset.balanceOf(newStrategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),            protocolFee);

        /**********************************************************************************************************************************/
        /*** Trigger collection again without new yield and prove no recipient is paid twice                                            ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), skyStrategyManager, collectionFunding);

        uint256 secondRecordedAssets = firstRecordedAssets + collectionFunding;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              secondRecordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: secondRecordedAssets
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate),    0);
        assertEq(fundsAsset.balanceOf(newStrategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),            protocolFee);
    }

    function testFork_changeNonzeroFeeRates_afterFeesCollected() external {
        /**********************************************************************************************************************************/
        /*** Set the old rates, fund the strategy and collect the first yield tranche                                                   ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 recordedAssets = fundAmount - roundingError; // 500_000e6 - 1.

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield  = (recordedAssets + roundingError) * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 delegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAssets   = recordedAssets + grossYield - delegateFee - protocolFee;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        fundStrategyManager(address(poolManager), skyStrategyManager, collectionFunding);

        recordedAssets = netAssets + collectionFunding;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              recordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        /**********************************************************************************************************************************/
        /*** Accrue tranche two and change the delegate rate after collecting both fees at the old rates                                ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        grossYield = (recordedAssets + roundingError) * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        netAssets =
            recordedAssets + grossYield - grossYield * delegateFeeRate / HUNDRED_PERCENT - grossYield * protocolFeeRate / HUNDRED_PERCENT;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).setStrategyDelegateFeeRate(newDelegateFeeRate);

        recordedAssets = netAssets;
        delegateFee   += grossYield * delegateFeeRate / HUNDRED_PERCENT;
        protocolFee   += grossYield * protocolFeeRate / HUNDRED_PERCENT;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              recordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        /**********************************************************************************************************************************/
        /*** Accrue tranche three and change the protocol rate after using the new delegate and old protocol rates                      ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        grossYield = (recordedAssets + roundingError) * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        netAssets = recordedAssets + grossYield - grossYield * newDelegateFeeRate / HUNDRED_PERCENT - grossYield * protocolFeeRate
            / HUNDRED_PERCENT;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        vm.prank(governor);
        ISkyStrategy(skyUnderlyingStrategy).setStrategyProtocolFeeRate(newProtocolFeeRate);

        recordedAssets = netAssets;
        delegateFee   += grossYield * newDelegateFeeRate / HUNDRED_PERCENT;
        protocolFee   += grossYield * protocolFeeRate / HUNDRED_PERCENT;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              recordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        /**********************************************************************************************************************************/
        /*** Accrue and collect tranche four using both new rates                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        grossYield = (recordedAssets + roundingError) * SKY_ANNUAL_APY / HUNDRED_PERCENT + roundingError;
        netAssets = recordedAssets + grossYield - grossYield * newDelegateFeeRate / HUNDRED_PERCENT - grossYield * newProtocolFeeRate
            / HUNDRED_PERCENT;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        fundStrategyManager(address(poolManager), skyStrategyManager, collectionFunding);

        recordedAssets = netAssets + collectionFunding;
        delegateFee   += grossYield * newDelegateFeeRate / HUNDRED_PERCENT;
        protocolFee   += grossYield * newProtocolFeeRate / HUNDRED_PERCENT;

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              recordedAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: recordedAssets
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);
    }

}

contract AllocationStrategyFeeRateChangeTests is AllocationStrategyTestBase {

    uint32 delegateFeeRate    = 0.1e6; // 10% of realized yield.
    uint32 newDelegateFeeRate = 0.2e6; // 20% of future realized yield.
    uint32 newProtocolFeeRate = 0.1e6; // 10% of future realized yield.
    uint32 protocolFeeRate    = 0.05e6; // 5% of realized yield.
    uint32 yieldDuration      = 10 days;

    uint256 fundAmount;
    uint256 mixedNetYield;
    uint256 newDelegateFee;
    uint256 newNetYield;
    uint256 newProtocolFee;
    uint256 oldDelegateFee;
    uint256 oldNetYield;
    uint256 oldProtocolFee;
    uint256 poolLiquidity;
    uint256 yieldAmount;

    function setUp() public override {
        super.setUp();

        fundAmount    = 500_000e6;
        poolLiquidity = 1_000_000e6;
        yieldAmount   = 100_000e6;

        mixedNetYield = yieldAmount - yieldAmount * newDelegateFeeRate / HUNDRED_PERCENT - yieldAmount * protocolFeeRate / HUNDRED_PERCENT; // 75_000e6.
        newDelegateFee = yieldAmount * newDelegateFeeRate / HUNDRED_PERCENT; // 20_000e6 per new-delegate tranche.
        newNetYield = yieldAmount - yieldAmount * newDelegateFeeRate / HUNDRED_PERCENT - yieldAmount * newProtocolFeeRate / HUNDRED_PERCENT; // 70_000e6.
        newProtocolFee = yieldAmount * newProtocolFeeRate / HUNDRED_PERCENT; // 10_000e6 for the final tranche.
        oldDelegateFee = yieldAmount * delegateFeeRate / HUNDRED_PERCENT; // 10_000e6 per old-rate tranche.
        oldNetYield = yieldAmount - yieldAmount * delegateFeeRate / HUNDRED_PERCENT - yieldAmount * protocolFeeRate / HUNDRED_PERCENT; // 85_000e6
        // per old-rate tranche.
        oldProtocolFee = yieldAmount * protocolFeeRate / HUNDRED_PERCENT; //  5_000e6 per old-rate tranche.

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), allocationStrategyManager, fundAmount);

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);
    }

    function test_changeNonzeroFeeRates_afterFeesCollected_immediateYield() external {
        /**********************************************************************************************************************************/
        /*** Realize and collect two immediate-yield tranches at the old rates                                                          ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, 0);

        uint256 firstTimestamp = block.timestamp;
        uint256 recordedAssets = fundAmount + oldNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: recordedAssets,
            availableToWithdraw:   recordedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: oldNetYield,
            yieldStart:           uint32(firstTimestamp),
            yieldDeadline:        uint32(firstTimestamp),
            yieldLastRealized:    uint32(firstTimestamp),
            realizedYield:        oldNetYield
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), oldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         oldProtocolFee);

        vm.warp(firstTimestamp + 1 hours);

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, 0);

        uint256 secondTimestamp = block.timestamp;
        recordedAssets         += oldNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: recordedAssets,
            availableToWithdraw:   recordedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: oldNetYield,
            yieldStart:           uint32(secondTimestamp),
            yieldDeadline:        uint32(secondTimestamp),
            yieldLastRealized:    uint32(secondTimestamp),
            realizedYield:        oldNetYield
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         2 * oldProtocolFee);

        /**********************************************************************************************************************************/
        /*** Change the delegate rate without collecting fees, then apply it only to the next realization                               ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, newDelegateFeeRate);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: recordedAssets,
            availableToWithdraw:   recordedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: oldNetYield,
            yieldStart:           uint32(secondTimestamp),
            yieldDeadline:        uint32(secondTimestamp),
            yieldLastRealized:    uint32(secondTimestamp),
            realizedYield:        oldNetYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         2 * oldProtocolFee);

        vm.warp(secondTimestamp + 1 hours);

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, 0);

        uint256 thirdTimestamp = block.timestamp;
        recordedAssets        += mixedNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: recordedAssets,
            availableToWithdraw:   recordedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: mixedNetYield,
            yieldStart:           uint32(thirdTimestamp),
            yieldDeadline:        uint32(thirdTimestamp),
            yieldLastRealized:    uint32(thirdTimestamp),
            realizedYield:        mixedNetYield
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee + newDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         3 * oldProtocolFee);

        /**********************************************************************************************************************************/
        /*** Change the protocol rate without collecting fees, then apply both new rates only to the final realization                  ***/
        /**********************************************************************************************************************************/

        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, newProtocolFeeRate);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: recordedAssets,
            availableToWithdraw:   recordedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: mixedNetYield,
            yieldStart:           uint32(thirdTimestamp),
            yieldDeadline:        uint32(thirdTimestamp),
            yieldLastRealized:    uint32(thirdTimestamp),
            realizedYield:        mixedNetYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee + newDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         3 * oldProtocolFee);

        vm.warp(thirdTimestamp + 1 hours);

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, 0);

        uint256 fourthTimestamp = block.timestamp;
        recordedAssets         += newNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: recordedAssets,
            availableToWithdraw:   recordedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: newNetYield,
            yieldStart:           uint32(fourthTimestamp),
            yieldDeadline:        uint32(fourthTimestamp),
            yieldLastRealized:    uint32(fourthTimestamp),
            realizedYield:        newNetYield
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee + 2 * newDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         3 * oldProtocolFee + newProtocolFee);
    }

    function test_changeNonzeroFeeRates_afterFeesCollected_vestingYield() external {
        /**********************************************************************************************************************************/
        /*** Schedule and collect two vesting-yield tranches at the old rates                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, yieldDuration);

        uint256 firstTimestamp = block.timestamp;
        uint256 recordedAssets = fundAmount + oldNetYield;
        uint256 vestedAssets   = fundAmount;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: oldNetYield,
            yieldStart:           uint32(firstTimestamp),
            yieldDeadline:        uint32(firstTimestamp + yieldDuration),
            yieldLastRealized:    uint32(firstTimestamp),
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), oldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         oldProtocolFee);

        vm.warp(firstTimestamp + yieldDuration);

        vestedAssets += oldNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, yieldDuration);

        uint256 secondTimestamp = block.timestamp;
        recordedAssets         += oldNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: oldNetYield,
            yieldStart:           uint32(secondTimestamp),
            yieldDeadline:        uint32(secondTimestamp + yieldDuration),
            yieldLastRealized:    uint32(secondTimestamp),
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         2 * oldProtocolFee);

        /**********************************************************************************************************************************/
        /*** Change the delegate rate without collecting fees, then apply it only to the next vesting realization                       ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, newDelegateFeeRate);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: oldNetYield,
            yieldStart:           uint32(secondTimestamp),
            yieldDeadline:        uint32(secondTimestamp + yieldDuration),
            yieldLastRealized:    uint32(secondTimestamp),
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         2 * oldProtocolFee);

        vm.warp(secondTimestamp + yieldDuration);

        vestedAssets += oldNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, yieldDuration);

        uint256 thirdTimestamp = block.timestamp;
        recordedAssets        += mixedNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: mixedNetYield,
            yieldStart:           uint32(thirdTimestamp),
            yieldDeadline:        uint32(thirdTimestamp + yieldDuration),
            yieldLastRealized:    uint32(thirdTimestamp),
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee + newDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         3 * oldProtocolFee);

        /**********************************************************************************************************************************/
        /*** Change the protocol rate without collecting fees, then apply both new rates only to the final vesting realization          ***/
        /**********************************************************************************************************************************/

        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, newProtocolFeeRate);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: mixedNetYield,
            yieldStart:           uint32(thirdTimestamp),
            yieldDeadline:        uint32(thirdTimestamp + yieldDuration),
            yieldLastRealized:    uint32(thirdTimestamp),
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee + newDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         3 * oldProtocolFee);

        vm.warp(thirdTimestamp + yieldDuration);

        vestedAssets += mixedNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, yieldDuration);

        uint256 fourthTimestamp = block.timestamp;
        recordedAssets         += newNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: newNetYield,
            yieldStart:           uint32(fourthTimestamp),
            yieldDeadline:        uint32(fourthTimestamp + yieldDuration),
            yieldLastRealized:    uint32(fourthTimestamp),
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee + 2 * newDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         3 * oldProtocolFee + newProtocolFee);

        /**********************************************************************************************************************************/
        /*** Let the final net yield vest without paying either recipient again                                                         ***/
        /**********************************************************************************************************************************/

        vm.warp(fourthTimestamp + yieldDuration);

        vestedAssets += newNetYield;

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: vestedAssets,
            availableToWithdraw:   vestedAssets,
            recordedAssets:        recordedAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: newNetYield,
            yieldStart:           uint32(fourthTimestamp),
            yieldDeadline:        uint32(fourthTimestamp + yieldDuration),
            yieldLastRealized:    uint32(fourthTimestamp),
            realizedYield:        newNetYield
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 2 * oldDelegateFee + 2 * newDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         3 * oldProtocolFee + newProtocolFee);
    }

}
