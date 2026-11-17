// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMockERC20, IOpenTermLoan, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { IHealthChecker } from "../../contracts/interfaces/IHealthChecker.sol";
import { InvariantCall, InvariantResult, IHealthCheckerRouter } from "../../contracts/interfaces/IHealthCheckerRouter.sol";

import { HealthCheckerRouter } from "../../contracts/health-checkers/HealthCheckerRouter.sol";

import { AaveV3StrategyHealthChecker } from "../../contracts/health-checkers/AaveV3StrategyHealthChecker.sol";
import { AllocationStrategyHealthChecker } from "../../contracts/health-checkers/AllocationStrategyHealthChecker.sol";
import { OpenTermLoanHealthChecker } from "../../contracts/health-checkers/OpenTermLoanHealthChecker.sol";
import { OpenTermLoanManagerHealthChecker } from "../../contracts/health-checkers/OpenTermLoanManagerHealthChecker.sol";
import { PoolHealthChecker } from "../../contracts/health-checkers/PoolHealthChecker.sol";
import { PoolManagerHealthChecker } from "../../contracts/health-checkers/PoolManagerHealthChecker.sol";
import { PoolPermissionManagerHealthChecker } from "../../contracts/health-checkers/PoolPermissionManagerHealthChecker.sol";
import { SkyStrategyHealthChecker } from "../../contracts/health-checkers/SkyStrategyHealthChecker.sol";
import { StrategyManagerHealthChecker } from "../../contracts/health-checkers/StrategyManagerHealthChecker.sol";
import { WithdrawalManagerHealthChecker } from "../../contracts/health-checkers/WithdrawalManagerHealthChecker.sol";

import { AaveV3StrategyHandler } from "./handlers/AaveV3StrategyHandler.sol";
import { AllocationStrategyHandler } from "./handlers/AllocationStrategyHandler.sol";
import { DepositHandler } from "./handlers/DepositHandler.sol";
import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { OpenTermLoanHandler } from "./handlers/OpenTermLoanHandler.sol";
import { SkyStrategyHandler } from "./handlers/SkyStrategyHandler.sol";
import { StrategyManagerHandler } from "./handlers/StrategyManagerHandler.sol";
import { TransferHandler } from "./handlers/TransferHandler.sol";
import { WithdrawalHandler } from "./handlers/WithdrawalHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract HealthCheckerInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant BOOTSTRAP_MINT = 1e6;
    uint256 constant NUM_POOLS      = 2;
    uint256 constant NUM_LPS        = 2;
    uint256 constant NUM_WALLETS    = 3;
    uint256 constant NUM_BORROWERS  = 5;
    uint256 constant NUM_OT_LOANS   = 10;

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    IHealthCheckerRouter healthCheckerRouter;

    AaveV3StrategyHealthChecker aaveV3StrategyHealthChecker;
    AllocationStrategyHealthChecker allocationStrategyHealthChecker;
    OpenTermLoanHealthChecker openTermLoanHealthChecker;
    OpenTermLoanManagerHealthChecker openTermLoanManagerHealthChecker;
    PoolHealthChecker poolHealthChecker;
    PoolManagerHealthChecker poolManagerHealthChecker;
    PoolPermissionManagerHealthChecker poolPermissionManagerHealthChecker;
    SkyStrategyHealthChecker skyStrategyHealthChecker;
    StrategyManagerHealthChecker strategyManagerHealthChecker;
    WithdrawalManagerHealthChecker withdrawalManagerHealthChecker;

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
        _setupHealthCheckers();
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

            bytes[] memory strategyData_ = new bytes[](strategyFactories.length);

            for (uint256 j; j < strategyFactories.length; j++) {
                strategyData_[j] = abi.encode(new bytes(0));
            }

            (, address poolManager_,) = _createPoolWithMultipleStrategies({
                poolDelegate_:      poolDelegate_,
                fundsAsset_:        address(fundsAsset),
                name_:              string(abi.encodePacked("Pool ", vm.toString(i))),
                strategyFactories_: strategyFactories,
                strategyData_:      strategyData_
            });

            activatePool(poolManager_, HUNDRED_PERCENT);
            openPool(poolManager_);

            setupFees({
                delegateOriginationFee:     500e6,
                delegateServiceFee:         300e6,
                delegateManagementFeeRate:  0.02e6,
                platformOriginationFeeRate: 0.001e6,
                platformServiceFeeRate:     0.005e6,
                platformManagementFeeRate:  0.08e6
            });

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

        transferHandler = new TransferHandler({
            handlerName_: "transferHandler",
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

        address[] memory borrowers_ = new address[](NUM_BORROWERS);

        for (uint256 i; i < NUM_BORROWERS; i++) {
            borrowers_[i] = makeAddr(string(abi.encodePacked("borrower", vm.toString(i))));
        }

        otlHandler = new OpenTermLoanHandler({
            handlerName_:  "otlHandler",
            loanFactory_:  address(openTermLoanFactory),
            refinancer_:   openTermRefinancer,
            poolManagers_: poolManagers,
            borrowers_:    borrowers_,
            maxLoans_:     NUM_OT_LOANS
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

        transferHandler.addAction("transfer(uint256)", 10_000);

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

        otlHandler.addAction("callLoan(uint256)", 1_000);
        otlHandler.addAction("fundLoan(uint256)", 3_000);
        otlHandler.addAction("impairLoan(uint256)", 1_000);
        otlHandler.addAction("makePayment(uint256)", 3_000);
        otlHandler.addAction("refinance(uint256)", 500);
        otlHandler.addAction("removeLoanCall(uint256)", 500);
        otlHandler.addAction("removeLoanImpairment(uint256)", 500);
        otlHandler.addAction("triggerDefault(uint256)", 500);
    }

    function _targetContract() internal {
        address[] memory contracts = new address[](8);
        uint256[] memory weights   = new uint256[](8);

        contracts[0] = address(depositHandler);
        contracts[1] = address(withdrawalHandler);
        contracts[2] = address(transferHandler);
        contracts[3] = address(strategyManagerHandler);
        contracts[4] = address(allocationStrategyHandler);
        contracts[5] = address(aaveV3StrategyHandler);
        contracts[6] = address(skyStrategyHandler);
        contracts[7] = address(otlHandler);

        weights[0] = 15;
        weights[1] = 10;
        weights[2] = 5;
        weights[3] = 20;
        weights[4] = 10;
        weights[5] = 10;
        weights[6] = 10;
        weights[7] = 20;

        address distributionHandler = address(new DistributionHandler(contracts, weights));

        targetContract(distributionHandler);
    }

    function _setupHealthCheckers() internal {
        healthCheckerRouter = new HealthCheckerRouter();

        poolHealthChecker                  = new PoolHealthChecker();
        poolManagerHealthChecker           = new PoolManagerHealthChecker();
        withdrawalManagerHealthChecker     = new WithdrawalManagerHealthChecker();
        poolPermissionManagerHealthChecker = new PoolPermissionManagerHealthChecker();
        strategyManagerHealthChecker       = new StrategyManagerHealthChecker();
        allocationStrategyHealthChecker    = new AllocationStrategyHealthChecker();
        aaveV3StrategyHealthChecker        = new AaveV3StrategyHealthChecker();
        skyStrategyHealthChecker           = new SkyStrategyHealthChecker();
        openTermLoanHealthChecker          = new OpenTermLoanHealthChecker();
        openTermLoanManagerHealthChecker   = new OpenTermLoanManagerHealthChecker();
    }

    /**************************************************************************************************************************************/
    /*** Invariant Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_healthCheckerInvariants() external {
        address[][] memory loansByPool = new address[][](poolManagers.length);

        uint256 totalLoans;

        for (uint256 i; i < poolManagers.length; i++) {
            loansByPool[i] = _getActiveLoans(otlHandler, i);
            totalLoans    += loansByPool[i].length;
        }

        InvariantCall[] memory calls = new InvariantCall[](pools.length * 5 + strategyManagers.length + 3 + totalLoans);

        uint256 index;

        for (uint256 i; i < pools.length; i++) {
            calls[index++] = InvariantCall({
                target: address(poolHealthChecker),
                input:  abi.encode(pools[i], lps)
            });

            calls[index++] = InvariantCall({
                target: address(poolManagerHealthChecker),
                input:  abi.encode(poolManagers[i])
            });

            calls[index++] =
                InvariantCall({
                    target: address(withdrawalManagerHealthChecker),
                    input:  abi.encode(withdrawalManagers[i], lps)
                });

            calls[index++] = InvariantCall({
                target: address(poolPermissionManagerHealthChecker),
                input:  abi.encode(poolManagers[i], lps)
            });

            calls[index++] = InvariantCall({
                target: address(openTermLoanManagerHealthChecker),
                input:  abi.encode(address(otlHandler.loanManagers(i)), loansByPool[i], ALLOWED_OTL_AUM_DIFF)
            });
        }

        for (uint256 i; i < strategyManagers.length; i++) {
            calls[index++] =
                InvariantCall({
                    target: address(strategyManagerHealthChecker),
                    input:  abi.encode(strategyManagers[i], poolManagers)
                });
        }

        calls[index++] = InvariantCall({
            target: address(allocationStrategyHealthChecker),
            input:  abi.encode(allocationUnderlyingStrategy, managedWallets)
        });

        calls[index++] = InvariantCall({
            target: address(aaveV3StrategyHealthChecker),
            input:  abi.encode(aaveV3UnderlyingStrategy)
        });

        calls[index++] = InvariantCall({
            target: address(skyStrategyHealthChecker),
            input:  abi.encode(skyUnderlyingStrategy)
        });

        for (uint256 i; i < poolManagers.length; i++) {
            for (uint256 j; j < loansByPool[i].length; j++) {
                calls[index++] = InvariantCall({
                    target: address(openTermLoanHealthChecker),
                    input:  abi.encode(loansByPool[i][j])
                });
            }
        }

        assertHealthCheckerResults(address(healthCheckerRouter), calls);
    }

    function assertHealthCheckerResults(address router, InvariantCall[] memory calls) internal {
        InvariantResult[][] memory expectedResults = new InvariantResult[][](calls.length);

        for (uint256 i; i < calls.length; i++) {
            expectedResults[i] = IHealthChecker(calls[i].target).check(calls[i].input);

            for (uint256 j; j < expectedResults[i].length; j++) {
                assertTrue(expectedResults[i][j].valid, expectedResults[i][j].name);
            }
        }

        (bool success, bytes memory returnData) = router.staticcall(abi.encodeWithSelector(IHealthCheckerRouter.check.selector, calls));

        assertTrue(success, "router reverted");
        assertEq(returnData, abi.encode(expectedResults), "router results mismatch");
    }

    /**************************************************************************************************************************************/
    /*** Internal Helpers                                                                                                               ***/
    /**************************************************************************************************************************************/

    function _getActiveLoans(OpenTermLoanHandler handler_, uint256 poolIndex_) internal view returns (address[] memory loans_) {
        uint256 length;

        for (uint256 i; i < handler_.numLoans(); ++i) {
            address loan_ = handler_.loans(i);

            if (handler_.poolIndexOf(loan_) == poolIndex_ && IOpenTermLoan(loan_).dateFunded() != 0) length++;
        }

        loans_ = new address[](length);

        uint256 index;

        for (uint256 i; i < handler_.numLoans(); ++i) {
            address loan_ = handler_.loans(i);

            if (handler_.poolIndexOf(loan_) == poolIndex_ && IOpenTermLoan(loan_).dateFunded() != 0) {
                loans_[index++] = loan_;
            }
        }
    }

}
