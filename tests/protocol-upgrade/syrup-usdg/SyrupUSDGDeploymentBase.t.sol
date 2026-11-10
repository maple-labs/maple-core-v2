// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IGlobals,
    IGovernorTimelock,
    IMapleProxyFactory,
    IPool,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager
} from "../../../contracts/interfaces/Interfaces.sol";

import {
    PoolConfigParams,
    PoolManagerInitParams,
    StrategyDeployParams,
    StrategyManagerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract SyrupUSDGDeploymentBase is ProtocolActions, UpgradeAddressRegistry {

    uint256 constant INITIAL_DEPOSIT = 10e6;
    uint256 constant BOOTSTRAP_MINT  = 0;
    uint256 constant INITIAL_SUPPLY  = 0;
    uint256 constant LIQUIDITY_CAP   = 100_000_000e6;

    uint256 constant DELEGATE_MANAGEMENT_FEE_RATE  = 0.0333e6; // 3.33%
    uint256 constant PLATFORM_MANAGEMENT_FEE_RATE  = 0.01e6; // 1%
    uint256 constant PLATFORM_ORIGINATION_FEE_RATE = 0.005e6; // 0.5%
    uint256 constant PLATFORM_SERVICE_FEE_RATE     = 0.0025e6; // 0.25%

    uint256 constant SYRUP_USDG_LENDER_BITMAP = 2 ** 4; // Keep the same as syrupUSDC and syrupUSDT

    bytes32 constant DEPOSIT_DATA = "USDG";

    address firstLender  = makeAddr("firstLender");
    address poolDelegate = makeAddr("syrupUSDGPoolDelegate");

    uint256 startingTime;

    address usdgOpenTermLoanManager;
    address usdgPool;
    address usdgPoolDelegateCover;
    address usdgPoolManager;
    address usdgSyrupRouter;
    address usdgWithdrawalManager;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 25_070_219);

        startingTime = block.timestamp;

        setupPool();
    }

    // TODO: Update the procedure once modular strategies are released.
    function setupPool() internal {
        // Step -2: Deploy the modular pool deployer and the new pool manager version

        address poolDeployer = deployFromFile("Contracts@34", "PoolDeployer", abi.encode(globals));

        deployFromFileTo("Contracts@34", "PoolManager", PoolManagerV500Implementation);
        deployFromFileTo("Contracts@34", "PoolManagerInitializer", PoolManagerV500Initializer);

        // Step -1: Whitelist the modular pool deployer, register the modular pool manager and register the
        //          open-term loan manager factory as a valid strategy factory.

        vm.startPrank(governor);
        IGlobals(globals).setCanDeployFrom(poolManagerFactory, poolDeployer, true);
        IGlobals(globals).setCanDeployFrom(withdrawalManagerQueueFactory, poolDeployer, true);
        IGlobals(globals).setCanDeployFrom(openTermLoanManagerFactory, poolDeployer, true);

        IMapleProxyFactory(poolManagerFactory).registerImplementation(500, PoolManagerV500Implementation, PoolManagerV500Initializer);
        IMapleProxyFactory(poolManagerFactory).setDefaultVersion(500);

        IGlobals(globals).setValidInstanceOf("STRATEGY_FACTORY", openTermLoanManagerFactory, true);
        vm.stopPrank();

        // Step 1: Assert pre-deployment state

        assertEq(IERC20(USDG).name(),     "Global Dollar");
        assertEq(IERC20(USDG).symbol(),   "USDG");
        assertEq(IERC20(USDG).decimals(), 6);

        assertEq(IPoolDeployer(poolDeployer).globals(), globals);

        assertEq(IGlobals(globals).canDeployFrom(poolManagerFactory, poolDeployer),            true);
        assertEq(IGlobals(globals).canDeployFrom(withdrawalManagerQueueFactory, poolDeployer), true);
        assertEq(IGlobals(globals).canDeployFrom(openTermLoanManagerFactory, poolDeployer),    true);

        assertEq(IMapleProxyFactory(poolManagerFactory).defaultVersion(), 500);

        // Step 2: Governor whitelists USDG as pool asset

        address[] memory targets = new address[](1);
        bytes[] memory   data    = new bytes[](1);

        targets[0] = globals;
        data[0]    = abi.encodeWithSignature("setValidPoolAsset(address,bool)", USDG, true);

        uint256 latestProposalId = IGovernorTimelock(timelock).latestProposalId();

        vm.prank(daoMultisig);
        IGovernorTimelock(timelock).scheduleProposals(targets, data);

        uint256[] memory proposalIds = new uint256[](targets.length);

        for (uint256 i; i < targets.length; ++i) {
            proposalIds[i] = latestProposalId + i + 1;
        }

        vm.warp(block.timestamp + 3 days);

        vm.prank(executor);
        IGovernorTimelock(timelock).executeProposals(proposalIds, targets, data);

        // Step 3: Operational sets valid pool delegate

        vm.prank(operationalAdmin);
        IGlobals(globals).setValidPoolDelegate(poolDelegate, true);

        // Step 4: Pool delegate deploys Syrup USDG pool

        StrategyDeployParams[] memory strategiesParams = new StrategyDeployParams[](1);

        strategiesParams[0] = StrategyDeployParams({
            factory:        openTermLoanManagerFactory,
            cap:            type(uint256).max,
            salt:           keccak256("Syrup USDG"),
            deploymentData: new bytes(0)
        });

        // NOTE: `deployPool` must be called by a valid pool delegate.
        vm.prank(poolDelegate);
        usdgPoolManager = IPoolDeployer(poolDeployer).deployPool({
            poolManagerFactory: poolManagerFactory,
            withdrawalManagerFactory: withdrawalManagerQueueFactory,
            poolManagerInitParams: PoolManagerInitParams({
                asset: USDG,
                initialSupply: INITIAL_SUPPLY,
                name: "Syrup USDG",
                symbol: "syrupUSDG"
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager: poolPermissionManager,
                delegateManagementFeeRate: DELEGATE_MANAGEMENT_FEE_RATE,
                liquidityCap: LIQUIDITY_CAP
            }),
            strategiesParams: strategiesParams,
            strategyManagersParams: new StrategyManagerParams[](0)
        });

        usdgPool                = IPoolManager(usdgPoolManager).pool();
        usdgWithdrawalManager   = IPoolManager(usdgPoolManager).withdrawalManager();
        usdgOpenTermLoanManager = IPoolManager(usdgPoolManager).strategyList(0);

        // Step 5: Operational admin executes post-deploy workflow (config, seed burn, router, allowlist)

        vm.startPrank(operationalAdmin);

        IGlobals(globals).activatePoolManager(usdgPoolManager);
        IGlobals(globals).setPlatformOriginationFeeRate(usdgPoolManager, PLATFORM_ORIGINATION_FEE_RATE);
        IGlobals(globals).setPlatformServiceFeeRate(usdgPoolManager, PLATFORM_SERVICE_FEE_RATE);
        IGlobals(globals).setPlatformManagementFeeRate(usdgPoolManager, PLATFORM_MANAGEMENT_FEE_RATE);

        bytes32[] memory functionIdsToSet = new bytes32[](11);
        uint256[] memory bitmaps          = new uint256[](11);

        functionIdsToSet[0]  = "P:deposit";
        functionIdsToSet[1]  = "P:depositWithPermit";
        functionIdsToSet[2]  = "P:mint";
        functionIdsToSet[3]  = "P:mintWithPermit";
        functionIdsToSet[4]  = "P:redeem";
        functionIdsToSet[5]  = "P:withdraw";
        functionIdsToSet[6]  = "P:transfer";
        functionIdsToSet[7]  = "P:transferFrom";
        functionIdsToSet[8]  = "P:removeShares";
        functionIdsToSet[9]  = "P:requestRedeem";
        functionIdsToSet[10] = "P:requestWithdraw";

        bitmaps[0]  = SYRUP_USDG_LENDER_BITMAP;
        bitmaps[1]  = SYRUP_USDG_LENDER_BITMAP;
        bitmaps[2]  = SYRUP_USDG_LENDER_BITMAP;
        bitmaps[3]  = SYRUP_USDG_LENDER_BITMAP;
        bitmaps[4]  = SYRUP_USDG_LENDER_BITMAP;
        bitmaps[5]  = SYRUP_USDG_LENDER_BITMAP;
        bitmaps[6]  = 0;
        bitmaps[7]  = 0;
        bitmaps[8]  = SYRUP_USDG_LENDER_BITMAP;
        bitmaps[9]  = 0;
        bitmaps[10] = SYRUP_USDG_LENDER_BITMAP;

        IPoolPermissionManager(poolPermissionManager)
            .configurePool(
                usdgPoolManager,
                1, // Function level pool permission
                functionIdsToSet,
                bitmaps
            );

        address[] memory lenders       = new address[](2);
        uint256[] memory lenderBitmaps = new uint256[](2);

        lenders[0]       = operationalAdmin;
        lenders[1]       = firstLender;
        lenderBitmaps[0] = SYRUP_USDG_LENDER_BITMAP;
        lenderBitmaps[1] = SYRUP_USDG_LENDER_BITMAP;

        IPoolPermissionManager(poolPermissionManager).setLenderBitmaps(lenders, lenderBitmaps);

        deal(USDG, operationalAdmin, INITIAL_DEPOSIT);
        IERC20(USDG).approve(usdgPool, INITIAL_DEPOSIT);
        uint256 initialShares = IPool(usdgPool).deposit(INITIAL_DEPOSIT, operationalAdmin);
        IPool(usdgPool).transfer(address(0), initialShares);

        usdgSyrupRouter = deployFromFile("Contracts@7", "SyrupRouter", abi.encode(usdgPool));

        lenders               = new address[](2);
        bool[] memory allowed = new bool[](2);

        lenders[0] = usdgSyrupRouter;
        lenders[1] = usdgWithdrawalManager;

        allowed[0] = true;
        allowed[1] = true;

        IPoolPermissionManager(poolPermissionManager).setLenderAllowlist(usdgPoolManager, lenders, allowed);
        vm.stopPrank();
    }

    function _setLenderBitmap(address lender_) internal {
        _setLenderBitmap(lender_, SYRUP_USDG_LENDER_BITMAP);
    }

    function _setLenderBitmap(address lender_, uint256 bitmap_) internal {
        address[] memory lenders = new address[](1);
        uint256[] memory bitmaps = new uint256[](1);

        lenders[0] = lender_;
        bitmaps[0] = bitmap_;

        vm.prank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setLenderBitmaps(lenders, bitmaps);
    }

    function _getPermitDigest(address owner_, address spender_, uint256 value_, uint256 deadline_) internal view returns (bytes32 digest_) {
        digest_ = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IERC20(USDG).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(IERC20(USDG).PERMIT_TYPEHASH(), owner_, spender_, value_, IERC20(USDG).nonces(owner_), deadline_))
            )
        );
    }

}
