// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { HealthCheckerRouter } from "../contracts/health-checkers/HealthCheckerRouter.sol";

import { AaveV3StrategyHealthChecker }        from "../contracts/health-checkers/AaveV3StrategyHealthChecker.sol";
import { AllocationStrategyHealthChecker }    from "../contracts/health-checkers/AllocationStrategyHealthChecker.sol";
import { OpenTermLoanHealthChecker }          from "../contracts/health-checkers/OpenTermLoanHealthChecker.sol";
import { OpenTermLoanManagerHealthChecker }   from "../contracts/health-checkers/OpenTermLoanManagerHealthChecker.sol";
import { PoolHealthChecker }                  from "../contracts/health-checkers/PoolHealthChecker.sol";
import { PoolManagerHealthChecker }           from "../contracts/health-checkers/PoolManagerHealthChecker.sol";
import { PoolPermissionManagerHealthChecker } from "../contracts/health-checkers/PoolPermissionManagerHealthChecker.sol";
import { SkyStrategyHealthChecker }           from "../contracts/health-checkers/SkyStrategyHealthChecker.sol";
import { StrategyManagerHealthChecker }       from "../contracts/health-checkers/StrategyManagerHealthChecker.sol";
import { WithdrawalManagerHealthChecker }     from "../contracts/health-checkers/WithdrawalManagerHealthChecker.sol";

contract HealthCheckerDeployment is Script {

    function run() external {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(ETH_SENDER);

        address healthCheckerRouter                = address(new HealthCheckerRouter());
        address poolHealthChecker                  = address(new PoolHealthChecker());
        address poolManagerHealthChecker           = address(new PoolManagerHealthChecker());
        address withdrawalManagerHealthChecker     = address(new WithdrawalManagerHealthChecker());
        address openTermLoanHealthChecker          = address(new OpenTermLoanHealthChecker());
        address openTermLoanManagerHealthChecker   = address(new OpenTermLoanManagerHealthChecker());
        address strategyManagerHealthChecker       = address(new StrategyManagerHealthChecker());
        address allocationStrategyHealthChecker    = address(new AllocationStrategyHealthChecker());
        address aaveV3StrategyHealthChecker        = address(new AaveV3StrategyHealthChecker());
        address skyStrategyHealthChecker           = address(new SkyStrategyHealthChecker());
        address poolPermissionManagerHealthChecker = address(new PoolPermissionManagerHealthChecker());

        vm.stopBroadcast();

        console.log("HealthCheckerRouter deployed at:                %s", healthCheckerRouter);
        console.log("--------------------------------------------------------------------------------");
        console.log("PoolHealthChecker deployed at:                  %s", poolHealthChecker);
        console.log("PoolManagerHealthChecker deployed at:           %s", poolManagerHealthChecker);
        console.log("WithdrawalManagerHealthChecker deployed at:     %s", withdrawalManagerHealthChecker);
        console.log("OpenTermLoanHealthChecker deployed at:          %s", openTermLoanHealthChecker);
        console.log("OpenTermLoanManagerHealthChecker deployed at:   %s", openTermLoanManagerHealthChecker);
        console.log("StrategyManagerHealthChecker deployed at:       %s", strategyManagerHealthChecker);
        console.log("AllocationStrategyHealthChecker deployed at:    %s", allocationStrategyHealthChecker);
        console.log("AaveV3StrategyHealthChecker deployed at:        %s", aaveV3StrategyHealthChecker);
        console.log("SkyStrategyHealthChecker deployed at:           %s", skyStrategyHealthChecker);
        console.log("PoolPermissionManagerHealthChecker deployed at: %s", poolPermissionManagerHealthChecker);
    }

}
