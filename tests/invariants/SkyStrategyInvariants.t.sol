// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMockERC20, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { DepositHandler }         from "./handlers/DepositHandler.sol";
import { DistributionHandler }    from "./handlers/DistributionHandler.sol";
import { SkyStrategyHandler }     from "./handlers/SkyStrategyHandler.sol";
import { StrategyManagerHandler } from "./handlers/StrategyManagerHandler.sol";
import { WithdrawalHandler }      from "./handlers/WithdrawalHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract SkyStrategyInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant BOOTSTRAP_MINT = 1e6;
    uint256 constant NUM_POOLS      = 2;
    uint256 constant NUM_LPS        = 2;

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

        _setupSkyStrategy();
        _setupPools();
        _setupLps();
        _createHandlers();
        _setupHandlers();
        _targetContract();
    }

    function _setupSkyStrategy() internal {
        ( skyStrategyManager, skyUnderlyingStrategy ) = _deploySkyStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           BOOTSTRAP_MINT
        });
    }

    function _setupPools() internal {
        for (uint256 i; i < NUM_POOLS; i++) {
            address poolDelegate_ = makeAddr(string(abi.encodePacked("poolDelegate", vm.toString(i))));

            vm.prank(governor);
            globals.setValidPoolDelegate(poolDelegate_, true);

            ( , address poolManager_, ) = _createPoolWithMultipleStrategies({
                poolDelegate_:      poolDelegate_,
                fundsAsset_:        address(fundsAsset),
                name_:              string(abi.encodePacked("Pool ", vm.toString(i))),
                strategyFactories_: new address[](0),
                strategyData_:      new bytes[](0)
            });

            activatePool(poolManager_, HUNDRED_PERCENT);
            openPool(poolManager_);

            vm.startPrank(governor);
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

        skyStrategyHandler = new SkyStrategyHandler({
            handlerName_:        "skyStrategyHandler",
            underlyingStrategy_: skyUnderlyingStrategy
        });

        address[] memory strategyHandlers_ = new address[](1);

        strategyHandlers_[0] = address(skyStrategyHandler);

        strategyManagerHandler = new StrategyManagerHandler({
            handlerName_:      "strategyManagerHandler",
            strategyManagers_: strategyManagers,
            poolManagers_:     poolManagers,
            strategyHandlers_: strategyHandlers_
        });
    }

    function _setupHandlers() internal {
        depositHandler.addAction("deposit(uint256)", 7_500);
        depositHandler.addAction("mint(uint256)",    2_500);

        strategyManagerHandler.addAction("fundStrategyManager(uint256)", 4_500);
        strategyManagerHandler.addAction("requestRedeem(uint256)",       3_000);
        strategyManagerHandler.addAction("cancelRedemption(uint256)",    500);
        strategyManagerHandler.addAction("processRedemption(uint256)",   2_000);

        withdrawalHandler.addAction("requestRedeem(uint256)",      5_000);
        withdrawalHandler.addAction("removeShares(uint256)",       500);
        withdrawalHandler.addAction("removeSharesById(uint256)",   500);
        withdrawalHandler.addAction("processRedemptions(uint256)", 3_000);
        withdrawalHandler.addAction("removeRequest(uint256)",      1_000);

        skyStrategyHandler.addAction("impair(uint256)",                     2_500);
        skyStrategyHandler.addAction("removeImpairment(uint256)",           2_500);
        skyStrategyHandler.addAction("setStrategyDelegateFeeRate(uint256)", 2_500);
        skyStrategyHandler.addAction("setStrategyProtocolFeeRate(uint256)", 2_500);
    }

    function _targetContract() internal {
        address[] memory contracts = new address[](4);
        uint256[] memory weights   = new uint256[](4);

        contracts[0] = address(depositHandler);
        contracts[1] = address(withdrawalHandler);
        contracts[2] = address(strategyManagerHandler);
        contracts[3] = address(skyStrategyHandler);

        weights[0] = 30;
        weights[1] = 20;
        weights[2] = 30;
        weights[3] = 20;

        address distributionHandler = address(new DistributionHandler(contracts, weights));

        targetContract(distributionHandler);
    }

    /**************************************************************************************************************************************/
    /*** Invariant Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_skyStrategyInvariants() external {
        for (uint256 i; i < pools.length; i++) {
            assert_pool_invariants_A_B_D_E_G_I_J_K(pools[i]);
            assert_pool_manager_invariants(poolManagers[i]);
            assert_wm_queue_invariants(withdrawalManagers[i], lps);
        }

        assert_strategyManager_invariants(skyStrategyManager, poolManagers);

        assert_skyStrategy_invariants({
            strategy_:    skyUnderlyingStrategy,
            fundings_:    strategyManagerHandler.totalFundingsOf(skyStrategyManager) + BOOTSTRAP_MINT,
            yield_:       skyStrategyHandler.totalYield(),
            withdrawals_: strategyManagerHandler.totalWithdrawalsOf(skyStrategyManager),
            fees_:        skyStrategyHandler.totalFees()
        });
    }

}
