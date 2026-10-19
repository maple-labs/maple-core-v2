// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IGlobals,
    IGovernorTimelock,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager,
    IStrategyDeployer
} from "../../../contracts/interfaces/Interfaces.sol";

import {
    AllocationStrategyInitializerParams,
    PoolConfigParams,
    PoolManagerInitParams,
    StrategyDeployParams,
    StrategyManagerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { ModularReleaseBase } from "../modular-release/ModularReleaseBase.sol";

contract SyrupUSD1Deployment is ModularReleaseBase {

    /**************************************************************************************************************************************/
    /*** Variables                                                                                                                      ***/
    /**************************************************************************************************************************************/

    address public managedWallet    = makeAddr("allocationStrategyUSD1ManagedWallet");
    address public poolDelegate     = makeAddr("syrupUSD1PoolDelegate");
    address public strategyDelegate = makeAddr("allocationStrategyUSD1Delegate");

    address public allocationStrategy;
    address public openTermLoanManager;
    address public pool;
    address public poolManager;
    address public strategyManager;
    address public withdrawalManager;

    bytes32[] functionIds;

    /**************************************************************************************************************************************/
    /*** Deployment Function                                                                                                            ***/
    /**************************************************************************************************************************************/

    function upgradeProtocolAndDeploySyrupUSD1() external {
        startingTime = block.timestamp;

        deployContracts();
        configureGlobals();
        upgradeGlobalsAndSetupFactories();
        setupModularStrategies();
        upgradePools();

        configureSyrupUSD1Globals();
        deploySyrupUSD1Pool();
        configureSyrupUSD1Permissions();
        deployUSD1AllocationStrategy();
        attachUSD1AllocationStrategy();
        configureUSD1AllocationStrategy();
    }

    /**************************************************************************************************************************************/
    /*** Deployment Steps                                                                                                               ***/
    /**************************************************************************************************************************************/

    function configureSyrupUSD1Globals() internal {
        Proposal[] memory proposals = new Proposal[](1);

        proposals[0] = Proposal(globals, abi.encodeWithSignature("setValidPoolAsset(address,bool)", USD1, true));

        scheduleAndExecuteProposals(proposals);

        vm.startPrank(operationalAdmin);
        IGlobals(globals).setBootstrapMint(USD1, 1e18);
        IGlobals(globals).setValidPoolDelegate(poolDelegate, true);
        vm.stopPrank();
    }

    function deploySyrupUSD1Pool() internal {
        StrategyDeployParams[] memory strategiesParams = new StrategyDeployParams[](1);

        strategiesParams[0] = StrategyDeployParams({
            factory:        openTermLoanManagerFactory,
            cap:            type(uint256).max,
            salt:           keccak256("Syrup USD1"),
            deploymentData: new bytes(0)
        });

        vm.prank(poolDelegate);
        poolManager = IPoolDeployer(poolDeployerV500).deployPool({
            poolManagerFactory: poolManagerFactory,
            withdrawalManagerFactory: withdrawalManagerQueueFactory,
            poolManagerInitParams: PoolManagerInitParams({ asset: USD1, initialSupply: 0, name: "Syrup USD1", symbol: "syrupUSD1" }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager: poolPermissionManager,
                delegateManagementFeeRate: 0,
                liquidityCap: type(uint256).max
            }),
            strategiesParams: strategiesParams,
            strategyManagersParams: new StrategyManagerParams[](0)
        });

        pool                = IPoolManager(poolManager).pool();
        withdrawalManager   = IPoolManager(poolManager).withdrawalManager();
        openTermLoanManager = IPoolManager(poolManager).strategyList(0);

        vm.startPrank(operationalAdmin);
        IGlobals(globals).activatePoolManager(poolManager);
        IGlobals(globals).setPlatformManagementFeeRate(poolManager, 0.15e6);
        IGlobals(globals).setPlatformOriginationFeeRate(poolManager, 0);
        IGlobals(globals).setPlatformServiceFeeRate(poolManager, 0.0025e6);
        vm.stopPrank();
    }

    function configureSyrupUSD1Permissions() internal {
        functionIds.push("P:deposit");
        functionIds.push("P:depositWithPermit");
        functionIds.push("P:mint");
        functionIds.push("P:mintWithPermit");
        functionIds.push("P:redeem");
        functionIds.push("P:withdraw");
        functionIds.push("P:transfer");
        functionIds.push("P:transferFrom");
        functionIds.push("P:removeShares");
        functionIds.push("P:requestRedeem");
        functionIds.push("P:requestWithdraw");

        IPoolPermissionManager ppm = IPoolPermissionManager(poolPermissionManager);

        uint256 permissionLevel = ppm.permissionLevels(syrupUSDCPoolManager);

        uint256[] memory bitmaps = new uint256[](functionIds.length);

        for (uint256 i; i < functionIds.length; i++) {
            bitmaps[i] = ppm.poolBitmaps(syrupUSDCPoolManager, functionIds[i]);
        }

        address[] memory lenders = new address[](1);
        bool[] memory    allowed = new bool[](1);

        lenders[0] = withdrawalManager;
        allowed[0] = true;

        vm.startPrank(operationalAdmin);
        ppm.configurePool(poolManager, permissionLevel, functionIds, bitmaps);
        ppm.setLenderAllowlist(poolManager, lenders, allowed);
        vm.stopPrank();
    }

    function deployUSD1AllocationStrategy() internal {
        vm.prank(operationalAdmin);
        IGlobals(globals).setValidStrategyDelegate(strategyDelegate, true);

        erc20_mint(USD1, strategyDelegate, 1e18);
        erc20_approve(USD1, strategyDelegate, strategyDeployerV100, 1e18);

        bytes memory deploymentData = abi.encode(
            AllocationStrategyInitializerParams({
                fundsAsset: USD1,
                strategyMetadata: "Allocation Strategy USD1",
                strategyDelegateFeeRate: 0,
                strategyProtocolFeeRate: 0.15e6,
                yieldCap: type(uint256).max
            })
        );

        vm.prank(strategyDelegate);
        (strategyManager, allocationStrategy) = IStrategyDeployer(strategyDeployerV100).deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        allocationStrategyFactory,
            strategyLiquidityCap:   type(uint256).max,
            strategyDeploymentData: deploymentData,
            bootstrapFundingData:   ""
        });

        vm.prank(operationalAdmin);
        IGlobals(globals).activateStrategyManager(strategyManager);
    }

    function attachUSD1AllocationStrategy() internal {
        Proposal[] memory proposals = new Proposal[](1);

        proposals[0] = Proposal(poolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManager));

        scheduleAndExecuteProposals(proposals);
    }

    function configureUSD1AllocationStrategy() internal {
        vm.startPrank(operationalAdmin);
        IPoolManager(poolManager).setStrategyCap(strategyManager, type(uint256).max);
        IGlobals(globals).setValidMapleManagedWallet(managedWallet, true);
        vm.stopPrank();

        address[] memory wallets = new address[](1);
        bool[] memory    flags   = new bool[](1);
        uint256[] memory caps    = new uint256[](1);

        wallets[0] = managedWallet;
        flags[0]   = true;
        caps[0]    = type(uint256).max;

        vm.startPrank(strategyDelegate);
        IAllocationStrategy(allocationStrategy).setPermissions(wallets, flags, flags, flags);
        IAllocationStrategy(allocationStrategy).setDeploymentCaps(wallets, caps);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function scheduleAndExecuteProposals(Proposal[] memory proposals_) internal {
        uint256[] memory proposalIds = scheduleProposals(proposals_);

        (,,, uint32 delayedUntil,) = IGovernorTimelock(timelock).proposals(proposalIds[0]);

        vm.warp(delayedUntil);

        executeProposals(proposalIds, proposals_);
    }

}
