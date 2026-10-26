// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPoolManager, IStrategyManager } from "../../contracts/interfaces/Interfaces.sol";

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

import { ModularReleaseBase } from "../protocol-upgrade/modular-release/ModularReleaseBase.sol";

import { HealthCheckerAddressRegistry } from "./HealthCheckerAddressRegistry.sol";

contract ModularReleaseHealthCheckers is ModularReleaseBase, HealthCheckerAddressRegistry {

    // TODO: See how much this can be decreased by.
    uint256 constant OTLM_TOLERANCE = 1e6;

    address aaveV3StrategyHealthChecker;
    address allocationStrategyHealthChecker;
    address healthCheckerRouter;
    address openTermLoanHealthChecker;
    address openTermLoanManagerHealthChecker;
    address poolHealthChecker;
    address poolManagerHealthChecker;
    address poolPermissionManagerHealthChecker;
    address skyStrategyHealthChecker;
    address strategyManagerHealthChecker;
    address withdrawalManagerHealthChecker;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 26_096_404);

        startingTime = block.timestamp;

        upgradeProtocol({
            attachAaveAndSkyStrategies: true
        });
    }

    function testFork_modularRelease_healthCheckers() external {
        healthCheckerRouter = address(new HealthCheckerRouter());

        // Total of 10 separate health checker contracts.
        aaveV3StrategyHealthChecker        = address(new AaveV3StrategyHealthChecker());
        allocationStrategyHealthChecker    = address(new AllocationStrategyHealthChecker());
        openTermLoanHealthChecker          = address(new OpenTermLoanHealthChecker());
        openTermLoanManagerHealthChecker   = address(new OpenTermLoanManagerHealthChecker());
        poolHealthChecker                  = address(new PoolHealthChecker());
        poolManagerHealthChecker           = address(new PoolManagerHealthChecker());
        poolPermissionManagerHealthChecker = address(new PoolPermissionManagerHealthChecker());
        skyStrategyHealthChecker           = address(new SkyStrategyHealthChecker());
        strategyManagerHealthChecker       = address(new StrategyManagerHealthChecker());
        withdrawalManagerHealthChecker     = address(new WithdrawalManagerHealthChecker());

        // Total number of invariant calls made to health checkers:
        // - 5 calls per pool manager: Pool, PoolManager, WithdrawalManager, OpenTermLoanManager, PoolPermissionManager
        // - 2 calls per strategy: StrategyManager, plus one of Aave/Sky/Allocation
        // - 1 call per loan: OpenTermLoanHealth
        uint256 callCount = poolManagers.length * 5 + specs.length * 2 + securedLendingUSDCLoans.length + syrupUSDCLoans.length
            + syrupUSDTLoans.length + syrupUSDGLoans.length + securedLending2USDCLoans.length;

        InvariantCall[] memory calls = new InvariantCall[](callCount);

        // Generate all of the inariant calls.
        uint256 index = 0;

        index = addPoolHealthCheckerCalls(calls, index);
        index = addPoolManagerHealthCheckerCalls(calls, index);
        index = addWithdrawalManagerHealthCheckerCalls(calls, index);
        index = addOpenTermLoanManagerHealthCheckerCalls(calls, index);
        index = addPoolPermissionManagerHealthCheckerCalls(calls, index);
        index = addStrategyManagerHealthCheckerCalls(calls, index);
        index = addAaveV3StrategyHealthCheckerCalls(calls, index);
        index = addSkyStrategyHealthCheckerCalls(calls, index);
        index = addAllocationStrategyHealthCheckerCalls(calls, index);
        index = addOpenTermLoanHealthCheckerCalls(calls, index);

        // Assert all invariants are passing and that the router forwards the results unchanged.
        assertHealthCheckerResults(healthCheckerRouter, calls);
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
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function addAaveV3StrategyHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < specs.length; i++) {
            if (specs[i].kind != StrategyKind.Aave) continue;

            address underlyingStrategy = IStrategyManager(strategyManagers[specs[i].name]).underlyingStrategy();

            calls[index++] = InvariantCall({
                target: aaveV3StrategyHealthChecker,
                input:  abi.encode(underlyingStrategy)
            });
        }

        newIndex = index;
    }

    function addAllocationStrategyHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < specs.length; i++) {
            if (specs[i].kind != StrategyKind.Allocation) continue;

            address underlyingStrategy = IStrategyManager(strategyManagers[specs[i].name]).underlyingStrategy();

            address[] memory wallets = new address[](1);
            wallets[0]               = managedWallets[specs[i].name];

            calls[index++] = InvariantCall({
                target: allocationStrategyHealthChecker,
                input:  abi.encode(underlyingStrategy, wallets)
            });
        }

        newIndex = index;
    }

    function addOpenTermLoanHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < poolManagers.length; i++) {
            address[] storage poolLoans = loansForPoolManager(i);

            for (uint256 j; j < poolLoans.length; j++) {
                calls[index++] = InvariantCall({
                    target: openTermLoanHealthChecker,
                    input:  abi.encode(poolLoans[j])
                });
            }
        }

        newIndex = index;
    }

    function addOpenTermLoanManagerHealthCheckerCalls(InvariantCall[] memory calls, uint256 index)
        internal
        view
        returns (uint256 newIndex)
    {
        for (uint256 i; i < poolManagers.length; i++) {
            calls[index++] = InvariantCall({
                target: openTermLoanManagerHealthChecker,
                input:  abi.encode(openTermLoanManagers[i], loansForPoolManager(i), OTLM_TOLERANCE)
            });
        }

        newIndex = index;
    }

    function addPoolHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < poolManagers.length; i++) {
            calls[index++] = InvariantCall({
                target: poolHealthChecker,
                input:  abi.encode(IPoolManager(poolManagers[i]).pool(), lpsForPoolManager(i))
            });
        }

        newIndex = index;
    }

    function addPoolManagerHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < poolManagers.length; i++) {
            calls[index++] = InvariantCall({
                target: poolManagerHealthChecker,
                input:  abi.encode(poolManagers[i])
            });
        }

        newIndex = index;
    }

    function addPoolPermissionManagerHealthCheckerCalls(
        InvariantCall[] memory calls,
        uint256 index
    )
        internal
        view
        returns (uint256 newIndex)
    {
        for (uint256 i; i < poolManagers.length; i++) {
            calls[index++] =
                InvariantCall({
                    target: poolPermissionManagerHealthChecker,
                    input:  abi.encode(poolManagers[i], lpsForPoolManager(i))
                });
        }

        newIndex = index;
    }

    function addSkyStrategyHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < specs.length; i++) {
            if (specs[i].kind != StrategyKind.Sky) continue;

            address underlyingStrategy = IStrategyManager(strategyManagers[specs[i].name]).underlyingStrategy();

            calls[index++] = InvariantCall({
                target: skyStrategyHealthChecker,
                input:  abi.encode(underlyingStrategy)
            });
        }

        newIndex = index;
    }

    function addStrategyManagerHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < specs.length; i++) {
            address strategyManager = strategyManagers[specs[i].name];

            calls[index++] = InvariantCall({
                target: strategyManagerHealthChecker,
                input:  abi.encode(strategyManager, poolManagers)
            });
        }

        newIndex = index;
    }

    function addWithdrawalManagerHealthCheckerCalls(InvariantCall[] memory calls, uint256 index) internal view returns (uint256 newIndex) {
        for (uint256 i; i < poolManagers.length; i++) {
            address withdrawalManager = IPoolManager(poolManagers[i]).withdrawalManager();

            calls[index++] =
                InvariantCall({
                    target: withdrawalManagerHealthChecker,
                    input:  abi.encode(withdrawalManager, lpsForPoolManager(i))
                });
        }

        newIndex = index;
    }

    function loansForPoolManager(uint256 index) internal view returns (address[] storage loans_) {
        if (index == 0) return syrupUSDCLoans;
        if (index == 1) return syrupUSDTLoans;
        if (index == 2) return syrupUSDGLoans;
        if (index == 3) return securedLendingUSDCLoans;

        return securedLending2USDCLoans;
    }

    function lpsForPoolManager(uint256 index) internal view returns (address[] storage lps_) {
        if (index == 0) return syrupUSDCLPs;
        if (index == 1) return syrupUSDTLPs;
        if (index == 2) return syrupUSDGLPs;
        if (index == 3) return securedLendingUSDCLPs;

        return securedLending2USDCLPs;
    }

}
