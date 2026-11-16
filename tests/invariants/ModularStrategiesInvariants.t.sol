// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMockERC20, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyHandler } from "./handlers/AaveV3StrategyHandler.sol";
import { AllocationStrategyHandler } from "./handlers/AllocationStrategyHandler.sol";
import { DepositHandler } from "./handlers/DepositHandler.sol";
import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { SkyStrategyHandler } from "./handlers/SkyStrategyHandler.sol";
import { StrategyManagerHandler } from "./handlers/StrategyManagerHandler.sol";
import { WithdrawalHandler } from "./handlers/WithdrawalHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract ModularStrategiesInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant BOOTSTRAP_MINT = 1e6;
    uint256 constant NUM_POOLS      = 2;
    uint256 constant NUM_LPS        = 2;
    uint256 constant NUM_WALLETS    = 3;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();

        _setupAllocationStrategy();
        _setupAaveV3Strategy();
        _setupSkyStrategy();
        _setupManagedWallets();
        _setupPools();
        _setupLps();
        _createHandlers();
        _setupHandlers();
        _targetContract();
    }

    function _setupAllocationStrategy() internal {
        (allocationStrategyManager, allocationUnderlyingStrategy) = _deployAllocationStrategy({
            strategyDelegate_:        makeAddr("allocationStrategyDelegate"),
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           BOOTSTRAP_MINT
        });
    }

    function _setupAaveV3Strategy() internal {
        (aaveV3StrategyManager, aaveV3UnderlyingStrategy) = _deployAaveV3Strategy({
            strategyDelegate_:            makeAddr("aaveV3StrategyDelegate"),
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        type(uint256).max,
            bootstrapMint_:               BOOTSTRAP_MINT
        });
    }

    function _setupSkyStrategy() internal {
        (skyStrategyManager, skyUnderlyingStrategy) = _deploySkyStrategy({
            strategyDelegate_:        makeAddr("skyStrategyDelegate"),
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           BOOTSTRAP_MINT
        });
    }

    function _setupManagedWallets() internal {
        for (uint256 i; i < NUM_WALLETS; i++) {
            address managedWallet = makeAddr(string(abi.encodePacked("managedWallet", vm.toString(i))));

            _setManagedWallet({
                strategy_:        allocationUnderlyingStrategy,
                managedWallet_:   managedWallet,
                canDeployAssets_: true,
                canReturnAssets_: true,
                canRealizeYield_: true,
                deploymentCap_:   type(uint256).max
            });
        }
    }

    function _setupPools() internal {
        for (uint256 i; i < NUM_POOLS; i++) {
            address poolDelegate_ = makeAddr(string(abi.encodePacked("poolDelegate", vm.toString(i))));

            vm.prank(governor);
            globals.setValidPoolDelegate(poolDelegate_, true);

            (, address poolManager_,) = _createPoolWithMultipleStrategies({
                poolDelegate_:      poolDelegate_,
                fundsAsset_:        address(fundsAsset),
                name_:              string(abi.encodePacked("Pool ", vm.toString(i))),
                strategyFactories_: new address[](0),
                strategyData_:      new bytes[](0)
            });

            activatePool(poolManager_, HUNDRED_PERCENT);
            openPool(poolManager_);

            vm.startPrank(governor);
            IPoolManager(poolManager_).addStrategyManager(allocationStrategyManager);
            IPoolManager(poolManager_).setStrategyCap(allocationStrategyManager, type(uint256).max);
            IPoolManager(poolManager_).addStrategyManager(aaveV3StrategyManager);
            IPoolManager(poolManager_).setStrategyCap(aaveV3StrategyManager, type(uint256).max);
            IPoolManager(poolManager_).addStrategyManager(skyStrategyManager);
            IPoolManager(poolManager_).setStrategyCap(skyStrategyManager, type(uint256).max);
            vm.stopPrank();
        }
    }

    function _setupLps() internal {
        for (uint256 i; i < NUM_LPS; i++) {
            address lp = makeAddr(string(abi.encodePacked("lp", vm.toString(i))));

            lps.push(lp);

            for (uint256 j; j < poolManagers.length; j++) {
                allowLender(poolManagers[j], lp);
            }
        }
    }

    function _createHandlers() internal {
        depositHandler = new DepositHandler({
            handlerName_: "depositHandler",
            pools_:       pools,
            lps_:         lps
        });

        withdrawalHandler = new WithdrawalHandler({
            handlerName_: "withdrawalHandler",
            pools_:       pools,
            lps_:         lps
        });

        allocationStrategyHandler = new AllocationStrategyHandler({
            handlerName_:        "allocationStrategyHandler",
            underlyingStrategy_: allocationUnderlyingStrategy,
            managedWallets_:     managedWallets
        });

        aaveV3StrategyHandler =
            new AaveV3StrategyHandler({
                handlerName_:        "aaveV3StrategyHandler",
                underlyingStrategy_: aaveV3UnderlyingStrategy
            });

        skyStrategyHandler = new SkyStrategyHandler({
            handlerName_:        "skyStrategyHandler",
            underlyingStrategy_: skyUnderlyingStrategy
        });

        address[] memory strategyHandlers_ = new address[](3);

        strategyHandlers_[0] = address(allocationStrategyHandler);
        strategyHandlers_[1] = address(aaveV3StrategyHandler);
        strategyHandlers_[2] = address(skyStrategyHandler);

        strategyManagerHandler = new StrategyManagerHandler({
            handlerName_:      "strategyManagerHandler",
            strategyManagers_: strategyManagers,
            poolManagers_:     poolManagers,
            strategyHandlers_: strategyHandlers_
        });
    }

    function _setupHandlers() internal {
        depositHandler.addAction("deposit(uint256)", 7_500);
        depositHandler.addAction("mint(uint256)", 2_500);

        withdrawalHandler.addAction("requestRedeem(uint256)", 5_000);
        withdrawalHandler.addAction("removeShares(uint256)", 1_000);
        withdrawalHandler.addAction("removeSharesById(uint256)", 500);
        withdrawalHandler.addAction("processRedemptions(uint256)", 3_000);
        withdrawalHandler.addAction("removeRequest(uint256)", 500);

        strategyManagerHandler.addAction("fundStrategyManager(uint256)", 5_000);
        strategyManagerHandler.addAction("requestRedeem(uint256)", 3_000);
        strategyManagerHandler.addAction("cancelRedemption(uint256)", 500);
        strategyManagerHandler.addAction("processRedemption(uint256)", 1_500);

        allocationStrategyHandler.addAction("deployAssets(uint256)", 2_000);
        allocationStrategyHandler.addAction("returnAssets(uint256)", 1_000);
        allocationStrategyHandler.addAction("realizeYield(uint256)", 3_500);
        allocationStrategyHandler.addAction("cancelYield(uint256)", 500);
        allocationStrategyHandler.addAction("recognizeLoss(uint256)", 500);
        allocationStrategyHandler.addAction("impair(uint256)", 1_000);
        allocationStrategyHandler.addAction("removeImpairment(uint256)", 500);
        allocationStrategyHandler.addAction("setStrategyDelegateFeeRate(uint256)", 500);
        allocationStrategyHandler.addAction("setStrategyProtocolFeeRate(uint256)", 500);

        aaveV3StrategyHandler.addAction("impair(uint256)", 3_500);
        aaveV3StrategyHandler.addAction("removeImpairment(uint256)", 2_500);
        aaveV3StrategyHandler.addAction("setStrategyDelegateFeeRate(uint256)", 2_000);
        aaveV3StrategyHandler.addAction("setStrategyProtocolFeeRate(uint256)", 2_000);

        skyStrategyHandler.addAction("impair(uint256)", 3_500);
        skyStrategyHandler.addAction("removeImpairment(uint256)", 2_500);
        skyStrategyHandler.addAction("setStrategyDelegateFeeRate(uint256)", 2_000);
        skyStrategyHandler.addAction("setStrategyProtocolFeeRate(uint256)", 2_000);
    }

    function _targetContract() internal {
        address[] memory contracts = new address[](6);
        uint256[] memory weights   = new uint256[](6);

        contracts[0] = address(depositHandler);
        contracts[1] = address(withdrawalHandler);
        contracts[2] = address(strategyManagerHandler);
        contracts[3] = address(allocationStrategyHandler);
        contracts[4] = address(aaveV3StrategyHandler);
        contracts[5] = address(skyStrategyHandler);

        weights[0] = 20;
        weights[1] = 10;
        weights[2] = 20;
        weights[3] = 20;
        weights[4] = 15;
        weights[5] = 15;

        address distributionHandler = address(new DistributionHandler(contracts, weights));

        targetContract(distributionHandler);
    }

    /**************************************************************************************************************************************/
    /*** Invariant Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_modularStrategiesInvariants() external {
        for (uint256 i; i < pools.length; i++) {
            assert_pool_invariants(pools[i]);
            assert_pool_manager_invariants(poolManagers[i]);
            assert_wm_invariants(withdrawalManagers[i], lps);
        }

        assert_strategyManager_invariants(allocationStrategyManager, poolManagers);
        assert_strategyManager_invariants(aaveV3StrategyManager, poolManagers);
        assert_strategyManager_invariants(skyStrategyManager, poolManagers);

        assert_allocationStrategy_invariants({
            strategy_:    allocationUnderlyingStrategy,
            fundings_:    strategyManagerHandler.totalFundingsOf(allocationStrategyManager) + BOOTSTRAP_MINT,
            yield_:       allocationStrategyHandler.totalYield(),
            withdrawals_: strategyManagerHandler.totalWithdrawalsOf(allocationStrategyManager),
            fees_:        allocationStrategyHandler.totalFees(),
            losses_:      allocationStrategyHandler.totalLosses(),
            walletInfo_:  allocationStrategyHandler.getManagedWalletInfo()
        });

        assert_aaveV3Strategy_invariants({
            strategy_:         aaveV3UnderlyingStrategy,
            totalFundings_:    strategyManagerHandler.totalFundingsOf(aaveV3StrategyManager) + BOOTSTRAP_MINT,
            totalYield_:       aaveV3StrategyHandler.totalYield(),
            totalWithdrawals_: strategyManagerHandler.totalWithdrawalsOf(aaveV3StrategyManager),
            totalFees_:        aaveV3StrategyHandler.totalFees()
        });

        assert_skyStrategy_invariants({
            strategy_:    skyUnderlyingStrategy,
            fundings_:    strategyManagerHandler.totalFundingsOf(skyStrategyManager) + BOOTSTRAP_MINT,
            yield_:       skyStrategyHandler.totalYield(),
            withdrawals_: strategyManagerHandler.totalWithdrawalsOf(skyStrategyManager),
            fees_:        skyStrategyHandler.totalFees()
        });
    }

}
