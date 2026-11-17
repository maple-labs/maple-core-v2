// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console } from "../../modules/forge-std/src/Test.sol";

import { Action, ActionType } from "../../modules/strategy-manager/contracts/interfaces/IMapleLiquidityRouter.sol";

import { IMockERC20, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../tests/TestBaseWithAssertions.sol";

contract ExecuteActionsGasTests is TestBaseWithAssertions {

    uint256 constant ACTION_AMOUNT          = 100e6;
    uint256 constant ACTION_TYPE_COUNT      = uint256(ActionType.PROCESS_REDEMPTION) + 1;
    uint256 constant INITIAL_POOL_LIQUIDITY = 100_000e6;
    uint256 constant MIN_TRANSACTION_GAS    = 16_000_000;
    uint256 constant POSITION_LIQUIDITY     = 10_000e6;
    uint256 constant STRATEGY_COUNT         = 3;
    uint256 constant TOTAL_POOL_COUNT       = 450;
    uint256 constant TRANSACTION_GAS_LIMIT  = 2 ** 24;

    uint32  constant DELEGATE_FEE_RATE = 0.1e6;
    uint32  constant PROTOCOL_FEE_RATE = 0.05e6;

    address allocationStrategyDelegate = makeAddr("allocationStrategyDelegate");
    address lp                         = makeAddr("lp");
    address skyStrategyDelegate        = makeAddr("skyStrategyDelegate");

    address[STRATEGY_COUNT] strategyManagers;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
        _createPoolWithOTLM(poolDelegate);
        _configurePool();

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     DELEGATE_FEE_RATE,
            strategyProtocolFeeRate_:     PROTOCOL_FEE_RATE,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        ( skyStrategyManager, skyUnderlyingStrategy ) = _deploySkyStrategy({
            strategyDelegate_:        skyStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: DELEGATE_FEE_RATE,
            strategyProtocolFeeRate_: PROTOCOL_FEE_RATE,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        allocationStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: DELEGATE_FEE_RATE,
            strategyProtocolFeeRate_: PROTOCOL_FEE_RATE,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        strategyManagers[0] = aaveV3StrategyManager;
        strategyManagers[1] = skyStrategyManager;
        strategyManagers[2] = allocationStrategyManager;

        addStrategyManagerToPool(address(poolManager), aaveV3StrategyManager);
        addStrategyManagerToPool(address(poolManager), skyStrategyManager);
        addStrategyManagerToPool(address(poolManager), allocationStrategyManager);

        deposit(address(pool), lp, INITIAL_POOL_LIQUIDITY);

        for (uint256 i_ = 1; i_ < TOTAL_POOL_COUNT; ++i_) {
            address poolDelegate_ = makeAddr(string(abi.encode(i_)));

            vm.prank(governor);
            globals.setValidPoolDelegate(poolDelegate_, true);

            ( address pool_, address poolManager_, ) = _createPoolWithOTLM(poolDelegate_);

            activatePool(poolManager_, HUNDRED_PERCENT);

            vm.startPrank(governor);
            IPoolManager(poolManager_).addStrategyManager(aaveV3StrategyManager);
            IPoolManager(poolManager_).addStrategyManager(skyStrategyManager);
            IPoolManager(poolManager_).addStrategyManager(allocationStrategyManager);
            IPoolManager(poolManager_).setStrategyCap(aaveV3StrategyManager, type(uint256).max);
            IPoolManager(poolManager_).setStrategyCap(skyStrategyManager, type(uint256).max);
            IPoolManager(poolManager_).setStrategyCap(allocationStrategyManager, type(uint256).max);
            vm.stopPrank();

            deposit(pool_, lp, INITIAL_POOL_LIQUIDITY);
        }
    }

    function testFork_executeActions_gas_tenPoolsTenActions() external {
        uint256 actionsPerPool_ = 10;
        uint256 poolCount_      = 10;

        Action[] memory setupActions_ = new Action[](poolCount_ * STRATEGY_COUNT);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            uint256 actionIndex_ = poolIndex_ * STRATEGY_COUNT;

            setupActions_[actionIndex_    ] = _action(ActionType.FUND_STRATEGY, aaveV3StrategyManager,     poolIndex_, POSITION_LIQUIDITY);
            setupActions_[actionIndex_ + 1] = _action(ActionType.FUND_STRATEGY, skyStrategyManager,        poolIndex_, POSITION_LIQUIDITY);
            setupActions_[actionIndex_ + 2] = _action(ActionType.FUND_STRATEGY, allocationStrategyManager, poolIndex_, POSITION_LIQUIDITY);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        Action[] memory actions_ = new Action[](actionsPerPool_ * poolCount_);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            uint256 actionIndex_    = poolIndex_ * actionsPerPool_;
            address processManager_ = strategyManagers[poolIndex_ % STRATEGY_COUNT];
            address fundManager_    = strategyManagers[(poolIndex_ + 1) % STRATEGY_COUNT];
            address cancelManager_  = strategyManagers[(poolIndex_ + 2) % STRATEGY_COUNT];

            actions_[actionIndex_    ] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 1] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 2] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 3] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 4] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 5] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 6] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 7] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 8] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 9] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);

        console.log("Gas used: ", transactionGasUsed_);
    }

    function testFork_executeActions_gas_threePoolsThirtyThreeActions() external {
        uint256 actionsPerPool_ = 33;
        uint256 poolCount_      = 3;

        Action[] memory setupActions_ = new Action[](poolCount_ * STRATEGY_COUNT);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            uint256 actionIndex_ = poolIndex_ * STRATEGY_COUNT;

            setupActions_[actionIndex_    ] = _action(ActionType.FUND_STRATEGY, aaveV3StrategyManager,     poolIndex_, POSITION_LIQUIDITY);
            setupActions_[actionIndex_ + 1] = _action(ActionType.FUND_STRATEGY, skyStrategyManager,        poolIndex_, POSITION_LIQUIDITY);
            setupActions_[actionIndex_ + 2] = _action(ActionType.FUND_STRATEGY, allocationStrategyManager, poolIndex_, POSITION_LIQUIDITY);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        Action[] memory actions_ = new Action[](actionsPerPool_ * poolCount_);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            uint256 actionIndex_    = poolIndex_ * actionsPerPool_;
            address processManager_ = strategyManagers[poolIndex_ % STRATEGY_COUNT];
            address fundManager_    = strategyManagers[(poolIndex_ + 1) % STRATEGY_COUNT];
            address cancelManager_  = strategyManagers[(poolIndex_ + 2) % STRATEGY_COUNT];

            actions_[actionIndex_     ] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  1] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  2] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  3] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  4] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  5] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  6] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  7] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  8] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ +  9] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 10] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 11] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 12] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 13] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 14] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 15] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 16] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 17] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 18] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 19] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 20] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 21] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 22] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 23] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 24] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 25] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 26] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 27] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 28] = _action(ActionType.REQUEST_REDEEM,     cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 29] = _action(ActionType.CANCEL_REDEMPTION,  cancelManager_,  poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 30] = _action(ActionType.REQUEST_REDEEM,     processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 31] = _action(ActionType.PROCESS_REDEMPTION, processManager_, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 32] = _action(ActionType.FUND_STRATEGY,      fundManager_,    poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);

        console.log("Gas used: ", transactionGasUsed_);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsAaveV3Strategy() external {
        uint256 poolCount_ = 79;

        Action[] memory setupActions_ = new Action[](1);
        Action[] memory actions_      = new Action[](poolCount_);

        setupActions_[0] = _action(ActionType.FUND_STRATEGY, aaveV3StrategyManager, 0, POSITION_LIQUIDITY);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            actions_[poolIndex_] = _action(ActionType.FUND_STRATEGY, aaveV3StrategyManager, poolIndex_ + 1, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsSkyStrategy() external {
        uint256 poolCount_ = 54;

        Action[] memory setupActions_ = new Action[](1);
        Action[] memory actions_      = new Action[](poolCount_);

        setupActions_[0] = _action(ActionType.FUND_STRATEGY, skyStrategyManager, 0, POSITION_LIQUIDITY);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            actions_[poolIndex_] = _action(ActionType.FUND_STRATEGY, skyStrategyManager, poolIndex_ + 1, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsAllocationStrategy() external {
        uint256 poolCount_ = 129;

        Action[] memory setupActions_ = new Action[](1);
        Action[] memory actions_      = new Action[](poolCount_);

        setupActions_[0] = _action(ActionType.FUND_STRATEGY, allocationStrategyManager, 0, POSITION_LIQUIDITY);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            actions_[poolIndex_] = _action(ActionType.FUND_STRATEGY, allocationStrategyManager, poolIndex_ + 1, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsWithdrawalsAaveV3Strategy() external {
        uint256 poolCount_ = 84;

        Action[] memory setupActions_ = new Action[](poolCount_);
        Action[] memory actions_      = new Action[](poolCount_ * 2);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            uint256 actionIndex_ = poolIndex_ * 2;

            setupActions_[poolIndex_]  = _action(ActionType.FUND_STRATEGY,      aaveV3StrategyManager, poolIndex_, POSITION_LIQUIDITY);
            actions_[actionIndex_]     = _action(ActionType.REQUEST_REDEEM,     aaveV3StrategyManager, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 1] = _action(ActionType.PROCESS_REDEMPTION, aaveV3StrategyManager, poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsWithdrawalsSkyStrategy() external {
        uint256 poolCount_ = 63;

        Action[] memory setupActions_ = new Action[](poolCount_);
        Action[] memory actions_      = new Action[](poolCount_ * 2);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            uint256 actionIndex_ = poolIndex_ * 2;

            setupActions_[poolIndex_]  = _action(ActionType.FUND_STRATEGY,      skyStrategyManager, poolIndex_, POSITION_LIQUIDITY);
            actions_[actionIndex_]     = _action(ActionType.REQUEST_REDEEM,     skyStrategyManager, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 1] = _action(ActionType.PROCESS_REDEMPTION, skyStrategyManager, poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsWithdrawalsAllocationStrategy() external {
        uint256 poolCount_ = 133;

        Action[] memory setupActions_ = new Action[](poolCount_);
        Action[] memory actions_      = new Action[](poolCount_ * 2);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            uint256 actionIndex_ = poolIndex_ * 2;

            setupActions_[poolIndex_]  = _action(ActionType.FUND_STRATEGY,      allocationStrategyManager, poolIndex_, POSITION_LIQUIDITY);
            actions_[actionIndex_]     = _action(ActionType.REQUEST_REDEEM,     allocationStrategyManager, poolIndex_, ACTION_AMOUNT);
            actions_[actionIndex_ + 1] = _action(ActionType.PROCESS_REDEMPTION, allocationStrategyManager, poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitRequestRedeemAndWithdrawalOperationsAaveV3Strategy() external {
        uint256 operationCount_ = 92;

        Action[] memory setupActions_ = new Action[](1);
        Action[] memory actions_      = new Action[](operationCount_ * 2);

        setupActions_[0] = _action(ActionType.FUND_STRATEGY, aaveV3StrategyManager, 0, (operationCount_ + 1) * ACTION_AMOUNT);

        for (uint256 operationIndex_; operationIndex_ < operationCount_; ++operationIndex_) {
            uint256 actionIndex_ = operationIndex_ * 2;

            actions_[actionIndex_]     = _action(ActionType.REQUEST_REDEEM,     aaveV3StrategyManager, 0, ACTION_AMOUNT);
            actions_[actionIndex_ + 1] = _action(ActionType.PROCESS_REDEMPTION, aaveV3StrategyManager, 0, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitRequestRedeemAndWithdrawalOperationsSkyStrategy() external {
        uint256 operationCount_ = 67;

        Action[] memory setupActions_ = new Action[](1);
        Action[] memory actions_      = new Action[](operationCount_ * 2);

        setupActions_[0] = _action(ActionType.FUND_STRATEGY, skyStrategyManager, 0, (operationCount_ + 1) * ACTION_AMOUNT);

        for (uint256 operationIndex_; operationIndex_ < operationCount_; ++operationIndex_) {
            uint256 actionIndex_ = operationIndex_ * 2;

            actions_[actionIndex_]     = _action(ActionType.REQUEST_REDEEM,     skyStrategyManager, 0, ACTION_AMOUNT);
            actions_[actionIndex_ + 1] = _action(ActionType.PROCESS_REDEMPTION, skyStrategyManager, 0, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitRequestRedeemAndWithdrawalOperationsAllocationStrategy() external {
        uint256 operationCount_ = 156;

        Action[] memory setupActions_ = new Action[](1);
        Action[] memory actions_      = new Action[](operationCount_ * 2);

        setupActions_[0] = _action(ActionType.FUND_STRATEGY, allocationStrategyManager, 0, (operationCount_ + 1) * ACTION_AMOUNT);

        for (uint256 operationIndex_; operationIndex_ < operationCount_; ++operationIndex_) {
            uint256 actionIndex_ = operationIndex_ * 2;

            actions_[actionIndex_]     = _action(ActionType.REQUEST_REDEEM,     allocationStrategyManager, 0, ACTION_AMOUNT);
            actions_[actionIndex_ + 1] = _action(ActionType.PROCESS_REDEMPTION, allocationStrategyManager, 0, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsRequestRedeem() external {
        uint256 poolCount_ = 269;

        Action[] memory actions_      = new Action[](poolCount_);
        Action[] memory setupActions_ = new Action[](1);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            actions_[poolIndex_] = _action(ActionType.REQUEST_REDEEM, aaveV3StrategyManager, poolIndex_, ACTION_AMOUNT);
            setupActions_[0]     = _action(ActionType.FUND_STRATEGY,  aaveV3StrategyManager, poolIndex_, POSITION_LIQUIDITY);

            vm.prank(liquidityRouterBot);
            liquidityRouter.executeActions(setupActions_, block.timestamp);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPoolsCancelRedemption() external {
        uint256 poolCount_ = TOTAL_POOL_COUNT;

        Action[] memory actions_        = new Action[](poolCount_);
        Action[] memory requestActions_ = new Action[](poolCount_);
        Action[] memory setupActions_   = new Action[](1);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            requestActions_[poolIndex_] = _action(ActionType.REQUEST_REDEEM,    aaveV3StrategyManager, poolIndex_, ACTION_AMOUNT);
            actions_[poolIndex_]        = _action(ActionType.CANCEL_REDEMPTION, aaveV3StrategyManager, poolIndex_, ACTION_AMOUNT);
            setupActions_[0]            = _action(ActionType.FUND_STRATEGY,     aaveV3StrategyManager, poolIndex_, POSITION_LIQUIDITY);

            vm.prank(liquidityRouterBot);
            liquidityRouter.executeActions(setupActions_, block.timestamp);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(requestActions_, block.timestamp);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPrefundedPoolsAaveV3Strategy() external {
        uint256 poolCount_ = 86;

        Action[] memory setupActions_ = new Action[](poolCount_);
        Action[] memory actions_      = new Action[](poolCount_);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            setupActions_[poolIndex_] = _action(ActionType.FUND_STRATEGY, aaveV3StrategyManager, poolIndex_, POSITION_LIQUIDITY);
            actions_[poolIndex_]      = _action(ActionType.FUND_STRATEGY, aaveV3StrategyManager, poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPrefundedPoolsSkyStrategy() external {
        uint256 poolCount_ = 57;

        Action[] memory setupActions_ = new Action[](poolCount_);
        Action[] memory actions_      = new Action[](poolCount_);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            setupActions_[poolIndex_] = _action(ActionType.FUND_STRATEGY, skyStrategyManager, poolIndex_, POSITION_LIQUIDITY);
            actions_[poolIndex_]      = _action(ActionType.FUND_STRATEGY, skyStrategyManager, poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFork_executeActions_gas_nearTransactionLimitPrefundedPoolsAllocationStrategy() external {
        uint256 poolCount_ = 149;

        Action[] memory setupActions_ = new Action[](poolCount_);
        Action[] memory actions_      = new Action[](poolCount_);

        for (uint256 poolIndex_; poolIndex_ < poolCount_; ++poolIndex_) {
            setupActions_[poolIndex_] = _action(ActionType.FUND_STRATEGY, allocationStrategyManager, poolIndex_, POSITION_LIQUIDITY);
            actions_[poolIndex_]      = _action(ActionType.FUND_STRATEGY, allocationStrategyManager, poolIndex_, ACTION_AMOUNT);
        }

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertGt(transactionGasUsed_, MIN_TRANSACTION_GAS);
        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function testFuzz_executeActions_gas_randomizedActions(uint256 seed_, uint8 strategyIndex_) external {
        uint256 actionAmount_ = 1e6;
        uint256 actionCount_  = 100;
        address manager_      = strategyManagers[strategyIndex_ % STRATEGY_COUNT];

        vm.pauseGasMetering();

        Action[] memory setupActions_ = new Action[](2);

        // Seed enough pending shares for any process/cancel sequence; 1e6 keeps requests below the position balance.
        setupActions_[0] = _action(ActionType.FUND_STRATEGY,  manager_, 0, POSITION_LIQUIDITY);
        setupActions_[1] = _action(ActionType.REQUEST_REDEEM, manager_, 0, actionCount_ * actionAmount_);

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(setupActions_, block.timestamp);

        vm.warp(block.timestamp + 365 days);

        Action[] memory actions_ = new Action[](actionCount_);

        for (uint256 i_; i_ < actionCount_; ++i_) {
            ActionType actionType_ = ActionType(uint256(keccak256(abi.encode(seed_, i_))) % ACTION_TYPE_COUNT);

            actions_[i_] = _action(actionType_, manager_, 0, actionAmount_);
        }

        vm.resumeGasMetering();

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions_, block.timestamp);

        uint256 transactionGasUsed_ = vm.lastCallGas().gasTotalUsed;

        assertLt(transactionGasUsed_, TRANSACTION_GAS_LIMIT);
    }

    function _action(ActionType actionType_, address strategyManager_, uint256 poolIndex_, uint256 amount_)
        internal view returns (Action memory action_)
    {
        action_ = Action({
            actionType:      actionType_,
            strategyManager: strategyManager_,
            poolManager:     poolManagers[poolIndex_],
            amount:          amount_,
            strategyData:    ""
        });
    }

}
