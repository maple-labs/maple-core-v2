// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { IGlobals, IPoolManager, IStrategyLike } from "../../contracts/interfaces/Interfaces.sol";

// import { ProtocolUpgradeBase } from "../protocol-upgrade/ProtocolUpgradeBase.sol";

import { LPHealthChecker }           from "./LPHealthChecker.sol";
import { OpenTermLoanHealthChecker } from "./OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }     from "./ProtocolHealthChecker.sol";

// TODO: Update once protocol upgrade tests are being done.
// contract HealthCheckerMainnetTests is ProtocolUpgradeBase, ProtocolActions {

//     address syrupUsdcCoreStrategy;
//     address blueChipCoreStrategy;

//     uint256 fundingAmount = 1_250_000e6;

//     LPHealthChecker           lpHealthChecker_;
//     OpenTermLoanHealthChecker openTermHealthChecker_;
//     ProtocolHealthChecker     protocolHealthChecker_;

//     function setUp() external {
//         vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22446028);

//         upgradeProtocol();

//         // Allow pool to be used as a vault.
//         vm.prank(governor);
//         IGlobals(globals).setValidInstanceOf("STRATEGY_VAULT", highYieldCorpUSDCPool, true);

//         // Open the pool.
//         openPool(highYieldCorpUSDCPoolManager);

//         // Remove liquidity cap.
//         setLiquidityCap(highYieldCorpUSDCPoolManager, type(uint256).max);

//         // Add core strategies to other pools.
//         vm.prank(syrupUSDCPoolDelegate);
//         IPoolManager(syrupUSDCPoolManager).addStrategy(coreStrategyFactory, abi.encode(highYieldCorpUSDCPool));

//         syrupUsdcCoreStrategy = IPoolManager(syrupUSDCPoolManager).strategyList(4);

//         vm.prank(blueChipPoolDelegate);
//         IPoolManager(blueChipSecuredUSDCPoolManager).addStrategy(coreStrategyFactory, abi.encode(highYieldCorpUSDCPool));

//         blueChipCoreStrategy = IPoolManager(blueChipSecuredUSDCPoolManager).strategyList(2);

//         // Fund other pools to enable core strategy funding.
//         erc20_mint(USDC, syrupUSDCPool,           fundingAmount);
//         erc20_mint(USDC, blueChipSecuredUSDCPool, fundingAmount);

//         openTermHealthChecker_ = new OpenTermLoanHealthChecker();
//         lpHealthChecker_       = new LPHealthChecker();
//         protocolHealthChecker_ = new ProtocolHealthChecker();
//     }

//     function testFork_healthChecker_coreStrategies_unfunded() external {
//         checkInvariants();
//     }

//     function testFork_healthChecker_coreStrategies_funded() external {
//         vm.prank(syrupUSDCPoolDelegate);
//         IStrategyLike(syrupUsdcCoreStrategy).fundStrategy(fundingAmount);

//         vm.prank(blueChipPoolDelegate);
//         IStrategyLike(blueChipCoreStrategy).fundStrategy(fundingAmount);

//         checkInvariants();
//     }

//     function testFork_healthChecker_coreStrategies_ongoing() external {
//         vm.prank(syrupUSDCPoolDelegate);
//         IStrategyLike(syrupUsdcCoreStrategy).fundStrategy(fundingAmount);

//         vm.prank(blueChipPoolDelegate);
//         IStrategyLike(blueChipCoreStrategy).fundStrategy(fundingAmount);

//         vm.warp(block.timestamp + 15 days);

//         checkInvariants();
//     }

//     function testFork_healthChecker_coreStrategies_impaired() external {
//         vm.startPrank(governor);
//         IStrategyLike(syrupUsdcCoreStrategy).impairStrategy();
//         IStrategyLike(blueChipCoreStrategy).impairStrategy();
//         vm.stopPrank();

//         checkInvariants();
//     }

//     function testFork_healthChecker_coreStrategies_inactive() external {
//         vm.startPrank(governor);
//         IStrategyLike(syrupUsdcCoreStrategy).deactivateStrategy();
//         IStrategyLike(blueChipCoreStrategy).deactivateStrategy();
//         vm.stopPrank();

//         checkInvariants();
//     }

//     /**************************************************************************************************************************************/
//     /*** Internal Functions                                                                                                             ***/
//     /**************************************************************************************************************************************/

//     function checkInvariants() internal {
//         checkLPInvariants(syrupUSDCPoolManager,           syrupUsdcLps);
//         checkLPInvariants(blueChipSecuredUSDCPoolManager, blueChipUsdcLps);

//         checkProtocolInvariants(syrupUSDCPoolManager);
//         checkProtocolInvariants(blueChipSecuredUSDCPoolManager);

//         checkOpenTermLoanInvariants(syrupUSDCPoolManager,           syrupUSDCOpenTermLoans);
//         checkOpenTermLoanInvariants(blueChipSecuredUSDCPoolManager, blueChipUSDCOpenTermLoans);
//     }

//     function checkLPInvariants(address poolManager_, address[] memory lenders_) internal {
//         LPHealthChecker.Invariants memory results;

//         results = lpHealthChecker_.checkInvariants(poolManager_, lenders_);

//         assertTrue(results.poolInvariantB);
//         assertTrue(results.poolInvariantG);
//         assertTrue(results.withdrawalManagerCyclicalInvariantA);
//         assertTrue(results.withdrawalManagerCyclicalInvariantB);
//         assertTrue(results.withdrawalManagerCyclicalInvariantF);
//         assertTrue(results.withdrawalManagerCyclicalInvariantG);
//         assertTrue(results.withdrawalManagerCyclicalInvariantH);
//         assertTrue(results.withdrawalManagerCyclicalInvariantI);
//         assertTrue(results.withdrawalManagerCyclicalInvariantJ);
//         assertTrue(results.withdrawalManagerCyclicalInvariantK);
//         assertTrue(results.withdrawalManagerCyclicalInvariantL);
//         assertTrue(results.withdrawalManagerQueueInvariantC);
//         assertTrue(results.withdrawalManagerQueueInvariantG);
//         assertTrue(results.withdrawalManagerQueueInvariantH);
//     }

//     function checkProtocolInvariants(address poolManager_) internal {
//         ProtocolHealthChecker.Invariants memory results;

//         results = protocolHealthChecker_.checkInvariants(poolManager_);

//         assertTrue(results.fixedTermLoanManagerInvariantA);
//         assertTrue(results.fixedTermLoanManagerInvariantB);
//         assertTrue(results.fixedTermLoanManagerInvariantF);
//         assertTrue(results.fixedTermLoanManagerInvariantI);
//         assertTrue(results.fixedTermLoanManagerInvariantJ);
//         assertTrue(results.fixedTermLoanManagerInvariantK);
//         assertTrue(results.openTermLoanManagerInvariantE);
//         assertTrue(results.openTermLoanManagerInvariantG);
//         assertTrue(results.poolInvariantA);
//         assertTrue(results.poolInvariantD);
//         assertTrue(results.poolInvariantE);
//         assertTrue(results.poolInvariantI);
//         assertTrue(results.poolInvariantJ);
//         assertTrue(results.poolInvariantK);
//         assertTrue(results.poolManagerInvariantA);
//         assertTrue(results.poolManagerInvariantB);
//         assertTrue(results.poolPermissionManagerInvariantA);
//         assertTrue(results.withdrawalManagerCyclicalInvariantC);
//         assertTrue(results.withdrawalManagerCyclicalInvariantD);
//         assertTrue(results.withdrawalManagerCyclicalInvariantE);
//         assertTrue(results.withdrawalManagerCyclicalInvariantM);
//         assertTrue(results.withdrawalManagerCyclicalInvariantN);
//         assertTrue(results.withdrawalManagerQueueInvariantA);
//         assertTrue(results.withdrawalManagerQueueInvariantB);
//         assertTrue(results.withdrawalManagerQueueInvariantD);
//         assertTrue(results.withdrawalManagerQueueInvariantE);
//         assertTrue(results.withdrawalManagerQueueInvariantF);
//         assertTrue(results.withdrawalManagerQueueInvariantI);
//         assertTrue(results.strategiesInvariantA);
//         assertTrue(results.strategiesInvariantB);
//         assertTrue(results.strategiesInvariantC);
//         assertTrue(results.strategiesInvariantD);
//         assertTrue(results.strategiesInvariantE);
//         assertTrue(results.strategiesInvariantF);
//         assertTrue(results.strategiesInvariantG);
//     }

//     function checkOpenTermLoanInvariants(address poolManager_, address[] memory loans_) internal {
//         OpenTermLoanHealthChecker.Invariants memory results;

//         results = openTermHealthChecker_.checkInvariants(poolManager_, loans_);

//         assertTrue(results.openTermLoanInvariantA);
//         assertTrue(results.openTermLoanInvariantB);
//         assertTrue(results.openTermLoanInvariantC);
//         assertTrue(results.openTermLoanInvariantD);
//         assertTrue(results.openTermLoanInvariantE);
//         assertTrue(results.openTermLoanInvariantF);
//         assertTrue(results.openTermLoanInvariantG);
//         assertTrue(results.openTermLoanInvariantH);
//         assertTrue(results.openTermLoanInvariantI);
//         assertTrue(results.openTermLoanManagerInvariantA);
//         assertTrue(results.openTermLoanManagerInvariantB);
//         assertTrue(results.openTermLoanManagerInvariantC);
//         assertTrue(results.openTermLoanManagerInvariantD);
//         assertTrue(results.openTermLoanManagerInvariantF);
//         assertTrue(results.openTermLoanManagerInvariantH);
//         assertTrue(results.openTermLoanManagerInvariantI);
//         assertTrue(results.openTermLoanManagerInvariantJ);
//         assertTrue(results.openTermLoanManagerInvariantK);
//     }

// }
