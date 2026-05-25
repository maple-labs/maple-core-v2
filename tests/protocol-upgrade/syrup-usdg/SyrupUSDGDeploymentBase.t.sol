// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IGlobals,
    IGovernorTimelock,
    IPool,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { Runner } from "../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract SyrupUSDGDeploymentBase is Runner, UpgradeAddressRegistry {

    address constant USDG = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;

    uint256 constant INITIAL_DEPOSIT = 10e6;
    uint256 constant BOOTSTRAP_MINT  = 0;
    uint256 constant COVER_AMOUNT    = 0;
    uint256 constant INITIAL_SUPPLY  = 0;
    uint256 constant LIQUIDITY_CAP   = 100_000_000e6;

    uint256 constant DELEGATE_MANAGEMENT_FEE_RATE  = 0.0333e6; // 3.33%
    uint256 constant PLATFORM_MANAGEMENT_FEE_RATE  = 0.01e6;   // 1%
    uint256 constant PLATFORM_ORIGINATION_FEE_RATE = 0.005e6;  // 0.5%
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

    function setupPool() internal {
        // Step 1: Assert pre-deployment state

        assertEq(IERC20(USDG).name(),     "Global Dollar");
        assertEq(IERC20(USDG).symbol(),   "USDG");
        assertEq(IERC20(USDG).decimals(), 6);

        assertEq(IPoolDeployer(poolDeployerV4).globals(), globals);
        assertTrue(IGlobals(globals).canDeployFrom(poolManagerFactory, poolDeployerV4));

        // Step 2: Governor whitelists USDG as pool asset

        address[] memory targets = new address[](1);
        bytes[]   memory data    = new bytes[](1);

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

        address[] memory strategyFactories      = new address[](1);
        bytes[]   memory strategyDeploymentData = new bytes[](1);

        strategyFactories[0]      = openTermLoanManagerFactory;
        strategyDeploymentData[0] = new bytes(0);

        uint256[4] memory configParams = [
            LIQUIDITY_CAP,
            DELEGATE_MANAGEMENT_FEE_RATE,
            COVER_AMOUNT,
            INITIAL_SUPPLY
        ];

        // NOTE: `deployPool` must be called by a valid pool delegate.
        vm.prank(poolDelegate);
        usdgPoolManager = IPoolDeployer(poolDeployerV4).deployPool(
            poolManagerFactory,
            withdrawalManagerQueueFactory,
            strategyFactories,
            strategyDeploymentData,
            USDG,
            poolPermissionManager,
            "Syrup USDG",
            "syrupUSDG",
            configParams
        );

        usdgPool                = IPoolManager(usdgPoolManager).pool();
        usdgWithdrawalManager   = IPoolManager(usdgPoolManager).withdrawalManager();
        usdgPoolDelegateCover   = IPoolManager(usdgPoolManager).poolDelegateCover();
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

        IPoolPermissionManager(poolPermissionManager).configurePool(
            usdgPoolManager,
            1,  // Function level pool permission
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

        lenders = new address[](2);
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
