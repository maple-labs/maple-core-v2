// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IMockERC20,
    IPoolManager,
    PoolConfigParams,
    PoolManagerInitParams,
    StrategyDeployParams,
    StrategyManagerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AllStrategyManagersTestBase is TestBaseWithAssertions {

    address sparkLendStrategyManager;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        start      = block.timestamp;
        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        ( sparkLendStrategyManager, ) = _deployAaveV3Strategy({
            strategyDelegate_:            makeAddr("sparkStrategyDelegate"),
            aaveToken_:                   SPARK_USDC,
            useVirtualUnderlyingBalance_: false,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        ( skyStrategyManager, skyUnderlyingStrategy ) = _deploySkyStrategy({
            strategyDelegate_:        makeAddr("skyStrategyDelegate"),
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        makeAddr("allocationStrategyDelegate"),
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });
    }

}

contract DeployPoolWithAllStrategyManagersSuccessTests is AllStrategyManagersTestBase {

    function testFork_deployPool_success_allStrategyManagers() external {
        uint256 sparkLendCap = 100_000e6;
        uint256 skyCap       = 200_000e6;

        /**********************************************************************************************************************************/
        /*** Configure all Strategy Managers with zero, finite and maximum Pool Manager caps                                            ***/
        /**********************************************************************************************************************************/

        StrategyManagerParams[] memory managers = new StrategyManagerParams[](4);

        managers[0] = StrategyManagerParams({
            instance: aaveV3StrategyManager,
            cap:      0
        });
        managers[1] = StrategyManagerParams({
            instance: sparkLendStrategyManager,
            cap:      sparkLendCap
        });
        managers[2] = StrategyManagerParams({
            instance: skyStrategyManager,
            cap:      skyCap
        });
        managers[3] = StrategyManagerParams({
            instance: allocationStrategyManager,
            cap:      type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Deploy the Pool                                                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        address poolManagerAddress = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    PoolManagerInitParams({
                asset:         address(fundsAsset),
                initialSupply: 0,
                name:          POOL_NAME,
                symbol:        POOL_SYMBOL
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: 0,
                liquidityCap:              type(uint256).max
            }),
            strategiesParams:       new StrategyDeployParams[](0),
            strategyManagersParams: managers
        });

        /**********************************************************************************************************************************/
        /*** Assert each Strategy Manager was added once and in order with its exact cap                                                ***/
        /**********************************************************************************************************************************/

        ( IPoolManager deployedPoolManager, ) = assertDeployedPool({
            poolManager_:               poolManagerAddress,
            initialSupply_:             0,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0,
            strategyListLength_:        4
        });

        assertEq(deployedPoolManager.strategyListLength(), 4);
        assertEq(deployedPoolManager.strategyList(0),      aaveV3StrategyManager);
        assertEq(deployedPoolManager.strategyList(1),      sparkLendStrategyManager);
        assertEq(deployedPoolManager.strategyList(2),      skyStrategyManager);
        assertEq(deployedPoolManager.strategyList(3),      allocationStrategyManager);

        assertEq(deployedPoolManager.isStrategyManager(aaveV3StrategyManager),     true);
        assertEq(deployedPoolManager.isStrategyManager(sparkLendStrategyManager),  true);
        assertEq(deployedPoolManager.isStrategyManager(skyStrategyManager),        true);
        assertEq(deployedPoolManager.isStrategyManager(allocationStrategyManager), true);

        assertEq(deployedPoolManager.isStrategy(aaveV3StrategyManager),     false);
        assertEq(deployedPoolManager.isStrategy(sparkLendStrategyManager),  false);
        assertEq(deployedPoolManager.isStrategy(skyStrategyManager),        false);
        assertEq(deployedPoolManager.isStrategy(allocationStrategyManager), false);

        assertEq(deployedPoolManager.strategyCapOf(aaveV3StrategyManager),     0);
        assertEq(deployedPoolManager.strategyCapOf(sparkLendStrategyManager),  sparkLendCap);
        assertEq(deployedPoolManager.strategyCapOf(skyStrategyManager),        skyCap);
        assertEq(deployedPoolManager.strategyCapOf(allocationStrategyManager), type(uint256).max);
    }

}

contract DeployPoolWithAllStrategyManagersFailureTests is AllStrategyManagersTestBase {

    function testFork_deployPool_revert_duplicateStrategyManager() external {
        /**********************************************************************************************************************************/
        /*** Configure all Strategy Managers followed by a duplicate                                                                    ***/
        /**********************************************************************************************************************************/

        StrategyManagerParams[] memory managers = new StrategyManagerParams[](5);

        managers[0] = StrategyManagerParams({
            instance: aaveV3StrategyManager,
            cap:      0
        });
        managers[1] = StrategyManagerParams({
            instance: sparkLendStrategyManager,
            cap:      100_000e6
        });
        managers[2] = StrategyManagerParams({
            instance: skyStrategyManager,
            cap:      200_000e6
        });
        managers[3] = StrategyManagerParams({
            instance: allocationStrategyManager,
            cap:      type(uint256).max
        });
        managers[4] = StrategyManagerParams({
            instance: allocationStrategyManager,
            cap:      type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Confirm the entire Pool deployment reverts                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ASM:ALREADY_STRATEGY_MANAGER");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    PoolManagerInitParams({
                asset:         address(fundsAsset),
                initialSupply: 0,
                name:          POOL_NAME,
                symbol:        POOL_SYMBOL
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: 0,
                liquidityCap:              type(uint256).max
            }),
            strategiesParams:       new StrategyDeployParams[](0),
            strategyManagersParams: managers
        });
    }

    function testFork_deployPool_revert_invalidManagementFeeRate() external {
        /**********************************************************************************************************************************/
        /*** Configure all Strategy Managers with an invalid Pool configuration                                                         ***/
        /**********************************************************************************************************************************/

        StrategyManagerParams[] memory managers = new StrategyManagerParams[](4);

        managers[0] = StrategyManagerParams({
            instance: aaveV3StrategyManager,
            cap:      0
        });
        managers[1] = StrategyManagerParams({
            instance: sparkLendStrategyManager,
            cap:      100_000e6
        });
        managers[2] = StrategyManagerParams({
            instance: skyStrategyManager,
            cap:      200_000e6
        });
        managers[3] = StrategyManagerParams({
            instance: allocationStrategyManager,
            cap:      type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Confirm the entire Pool deployment reverts after Strategy Manager registration                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        vm.expectRevert("PM:SDMFR:OOB");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    PoolManagerInitParams({
                asset:         address(fundsAsset),
                initialSupply: 0,
                name:          POOL_NAME,
                symbol:        POOL_SYMBOL
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: HUNDRED_PERCENT + 1,
                liquidityCap:              type(uint256).max
            }),
            strategiesParams:       new StrategyDeployParams[](0),
            strategyManagersParams: managers
        });
    }

    function testFork_deployPool_revert_invalidStrategyManager() external {
        /**********************************************************************************************************************************/
        /*** Configure all Strategy Managers followed by an invalid manager                                                             ***/
        /**********************************************************************************************************************************/

        StrategyManagerParams[] memory managers = new StrategyManagerParams[](5);

        managers[0] = StrategyManagerParams({
            instance: aaveV3StrategyManager,
            cap:      0
        });
        managers[1] = StrategyManagerParams({
            instance: sparkLendStrategyManager,
            cap:      100_000e6
        });
        managers[2] = StrategyManagerParams({
            instance: skyStrategyManager,
            cap:      200_000e6
        });
        managers[3] = StrategyManagerParams({
            instance: allocationStrategyManager,
            cap:      type(uint256).max
        });
        managers[4] = StrategyManagerParams({
            instance: address(0),
            cap:      type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Confirm the entire Pool deployment reverts                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ASM:INVALID_STRATEGY_MANAGER");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    PoolManagerInitParams({
                asset:         address(fundsAsset),
                initialSupply: 0,
                name:          POOL_NAME,
                symbol:        POOL_SYMBOL
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: 0,
                liquidityCap:              type(uint256).max
            }),
            strategiesParams:       new StrategyDeployParams[](0),
            strategyManagersParams: managers
        });
    }

    function testFork_deployPool_revert_strategyManagerAssetNotSupported() external {
        /**********************************************************************************************************************************/
        /*** Deploy a Strategy Manager that does not support the Pool asset                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        globals.setValidPoolAsset(address(collateralAsset), true);

        ( address incompatibleStrategyManager, ) = _deployAllocationStrategy({
            strategyDelegate_:        makeAddr("incompatibleStrategyDelegate"),
            fundsAsset_:              address(collateralAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        StrategyManagerParams[] memory managers = new StrategyManagerParams[](5);

        managers[0] = StrategyManagerParams({
            instance: aaveV3StrategyManager,
            cap:      0
        });
        managers[1] = StrategyManagerParams({
            instance: sparkLendStrategyManager,
            cap:      100_000e6
        });
        managers[2] = StrategyManagerParams({
            instance: skyStrategyManager,
            cap:      200_000e6
        });
        managers[3] = StrategyManagerParams({
            instance: allocationStrategyManager,
            cap:      type(uint256).max
        });
        managers[4] = StrategyManagerParams({
            instance: incompatibleStrategyManager,
            cap:      type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Confirm the entire Pool deployment reverts                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ASM:ASSET_NOT_SUPPORTED");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    PoolManagerInitParams({
                asset:         address(fundsAsset),
                initialSupply: 0,
                name:          POOL_NAME,
                symbol:        POOL_SYMBOL
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: 0,
                liquidityCap:              type(uint256).max
            }),
            strategiesParams:       new StrategyDeployParams[](0),
            strategyManagersParams: managers
        });
    }

}
