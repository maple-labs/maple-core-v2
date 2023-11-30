// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IPoolDeployer, IPoolDeployerV2Like } from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

import { UpgradeAddressRegistryETH }    from "./UpgradeAddressRegistryETH.sol";
import { UpgradeAddressRegistryBASEL2 } from "./UpgradeAddressRegistryBASEL2.sol";

contract DeprecatePoolDeployerV2TestsETH is ProtocolUpgradeBase, UpgradeAddressRegistryETH {

    address poolDelegate = makeAddr("poolDelegate");

    address[] loanManagerFactories = [fixedTermLoanManagerFactory, openTermLoanManagerFactory];

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18382132);
    }

    function testFork_deprecatePoolDeployerV2_ETH() external {
        IGlobals globals_ = IGlobals(protocol.globals);

        IPoolDeployerV2Like poolDeployerV2_ = IPoolDeployerV2Like(protocol.poolDeployerV2);

        IPoolDeployer poolDeployerV3_;

        _performProtocolUpgrade();

        _deprecatePoolDeployerV2();

        _assertPoolDeployerV2Deprecated();

        vm.prank(protocol.governor);
        globals_.setValidPoolDelegate(poolDelegate, true);

        vm.prank(poolDelegate);
        vm.expectRevert("PMF:CI:NOT_DEPLOYER");
        poolDeployerV2_.deployPool({
            poolManagerFactory_:       protocol.poolManagerFactory,
            withdrawalManagerFactory_: protocol.withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    protocol.usdc,
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 0, 1 weeks, 2 days, 0]
        });

        poolDeployerV3_ = IPoolDeployer(poolDeployerV3);

        vm.prank(poolDelegate);
        poolDeployerV3_.deployPool({
            poolManagerFactory_:       protocol.poolManagerFactory,
            withdrawalManagerFactory_: protocol.withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    protocol.usdc,
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, block.timestamp]
        });
    }

}

contract DeprecatePoolDeployerV2TestsBASEL2 is ProtocolUpgradeBase, UpgradeAddressRegistryBASEL2 {

    address poolDelegate = makeAddr("poolDelegate");

    address[] loanManagerFactories = [fixedTermLoanManagerFactory, openTermLoanManagerFactory];

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 5944426);
    }

    function testFork_deprecatePoolDeployerV2_BASEL2() external {
        IGlobals globals_ = IGlobals(protocol.globals);

        IPoolDeployerV2Like poolDeployerV2_ = IPoolDeployerV2Like(protocol.poolDeployerV2);

        IPoolDeployer poolDeployerV3_;

        _performProtocolUpgrade();

        _deprecatePoolDeployerV2();

        _assertPoolDeployerV2Deprecated();

        vm.prank(protocol.governor);
        globals_.setValidPoolDelegate(poolDelegate, true);

        vm.prank(poolDelegate);
        vm.expectRevert("PMF:CI:NOT_DEPLOYER");
        poolDeployerV2_.deployPool({
            poolManagerFactory_:       protocol.poolManagerFactory,
            withdrawalManagerFactory_: protocol.withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    protocol.usdc,
            name_:                     "Maple Pool1",
            symbol_:                   "MP1",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 0, 1 weeks, 2 days, 0]
        });

        poolDeployerV3_ = IPoolDeployer(poolDeployerV3);

        vm.prank(poolDelegate);
        poolDeployerV3_.deployPool({
            poolManagerFactory_:       protocol.poolManagerFactory,
            withdrawalManagerFactory_: protocol.withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    protocol.usdc,
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, block.timestamp]
        });
    }

}
