// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console as console, Test } from "../../../contracts/Runner.sol";

import {
    IERC20Like,
    IGlobals,
    IGovernorTimelock,
    IOpenTermLoanManager,
    IPool,
    IPoolDeployer,
    IPoolDelegateCover,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupRouter,
    IWithdrawalManagerQueue as IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract SyrupUSDGValidationScriptBase is UpgradeAddressRegistry, Test {

    address constant FIRST_LENDER            = 0xCe1cE7c7F436DCc4E28Bc8bf86115514d3DC34E8;
    address constant PERMISSION_ADMIN_SIGNER = 0x4575e7E9eA9e3C6132b2ea94A69E61d407708655;
    address constant POOL_DELEGATE           = 0x54e28Bb2D530Ee10386dbcA6E7e84EfaC809292C;
    address constant USDG                    = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;

    uint256 constant DELEGATE_MANAGEMENT_FEE_RATE  = 0;
    uint256 constant INITIAL_DEPOSIT               = 10e6;
    uint256 constant LENDER_BITMAP                 = 2 ** 4;
    uint256 constant LIQUIDITY_CAP                 = 10_000_000e6;
    uint256 constant PERMISSION_LEVEL              = 1;
    uint256 constant PLATFORM_MANAGEMENT_FEE_RATE  = 0.0833e6;
    uint256 constant PLATFORM_ORIGINATION_FEE_RATE = 0;
    uint256 constant PLATFORM_SERVICE_FEE_RATE     = 0.0025e6;

    IGovernorTimelock tl = IGovernorTimelock(timelock);

    function _proposalHash(address target_, bytes memory calldata_) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(target_, calldata_));
    }

}

contract ValidateUSDGPreDeployment is SyrupUSDGValidationScriptBase {

    function run() public virtual {
        assertEq(IERC20Like(USDG).name(),     "Global Dollar", "Invalid USDG name!");
        assertEq(IERC20Like(USDG).symbol(),   "USDG",          "Invalid USDG symbol!");
        assertEq(IERC20Like(USDG).decimals(), 6,               "Invalid USDG decimals!");

        assertEq(IPoolDeployer(poolDeployerV4).globals(),                             globals, "Invalid globals on pool deployer!");
        assertEq(IGlobals(globals).canDeployFrom(poolManagerFactory, poolDeployerV4), true,    "Pool deployer cannot deploy!");
    }

}

contract ValidateUSDGWhitelistProposalScheduling is SyrupUSDGValidationScriptBase {

    uint32 proposalTimestamp = uint32(block.timestamp);

    function run() external view {
        uint256 proposalId = tl.latestProposalId();

        bytes32 expectedHash = _proposalHash(
            globals,
            abi.encodeWithSignature("setValidPoolAsset(address,bool)", USDG, true)
        );

        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = tl.proposals(proposalId);

        assertEq(proposalHash,    expectedHash,               "Invalid proposal hash!");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable!");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid!");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid!");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid!");
    }

}

contract ValidateUSDGWhitelistProposalExecution is SyrupUSDGValidationScriptBase {

    function run() external view {
        assertEq(IGlobals(globals).isPoolAsset(USDG), true, "USDG is not a valid pool asset!");
    }

}

contract ValidateUSDGPoolDelegate is SyrupUSDGValidationScriptBase {

    function run() external view {
        ( address ownedPoolManager, bool isPoolDelegate ) = IGlobals(globals).poolDelegates(POOL_DELEGATE);

        assertEq(isPoolDelegate,   true,       "Pool delegate is not registered!");
        assertEq(ownedPoolManager, address(0), "Pool delegate already owns a pool manager!");
    }

}

contract ValidateUSDGPoolDeployment is SyrupUSDGValidationScriptBase {

    function run() external view {
        address poolManager = syrupUSDGPoolManager;

        assertEq(IPoolManager(poolManager).asset(),                     USDG,                          "Invalid PM asset!");
        assertEq(IPoolManager(poolManager).poolDelegate(),              POOL_DELEGATE,                 "Invalid PM delegate!");
        assertEq(IPoolManager(poolManager).poolPermissionManager(),     poolPermissionManager,         "Invalid PM PPM!");
        assertEq(IPoolManager(poolManager).globals(),                   globals,                       "Invalid PM globals!");
        assertEq(IPoolManager(poolManager).governor(),                  timelock,                      "Invalid PM governor!");
        assertEq(IPoolManager(poolManager).factory(),                   poolManagerFactory,            "Invalid PM factory!");
        assertEq(IPoolManager(poolManager).implementation(),            PoolManagerV400Implementation, "Invalid PM implementation!");
        assertEq(IPoolManager(poolManager).liquidityCap(),              LIQUIDITY_CAP,                 "Invalid liquidity cap!");
        assertEq(IPoolManager(poolManager).delegateManagementFeeRate(), DELEGATE_MANAGEMENT_FEE_RATE,  "Invalid delegate fee rate!");
        assertEq(IPoolManager(poolManager).strategyListLength(),        1,                             "Invalid strategy count!");
        assertEq(IPoolManager(poolManager).pendingPoolDelegate(),       address(0),                    "Pending delegate must be unset!");
        assertEq(IPoolManager(poolManager).totalAssets(),               0,                             "Invalid PM assets!");
        assertEq(IPoolManager(poolManager).unrealizedLosses(),          0,                             "Invalid PM losses!");

        assertEq(IPoolManager(poolManager).pool(),              syrupUSDGPool,                   "Invalid PM pool!");
        assertEq(IPoolManager(poolManager).withdrawalManager(), syrupUSDGWithdrawalManagerQueue, "Invalid PM WM!");
        assertEq(IPoolManager(poolManager).poolDelegateCover(), syrupUSDGPoolDelegateCover,      "Invalid PM PDC!");
        assertEq(IPoolManager(poolManager).strategyList(0),     syrupUSDGOpenTermLoanManager,    "Invalid PM strategy!");

        assertEq(IPoolManager(poolManager).configured(), true,  "PM not configured!");
        assertEq(IPoolManager(poolManager).active(),     false, "PM already active!");

        assertEq(IPool(syrupUSDGPool).name(),           "syrupUSDG", "Invalid pool name!");
        assertEq(IPool(syrupUSDGPool).symbol(),         "syrupUSDG", "Invalid pool symbol!");
        assertEq(IPool(syrupUSDGPool).decimals(),       6,           "Invalid pool decimals!");
        assertEq(IPool(syrupUSDGPool).asset(),          USDG,        "Invalid pool asset!");
        assertEq(IPool(syrupUSDGPool).manager(),        poolManager, "Invalid pool manager!");
        assertEq(IPool(syrupUSDGPool).BOOTSTRAP_MINT(), 0,           "Invalid BOOTSTRAP_MINT!");
        assertEq(IPool(syrupUSDGPool).totalSupply(),    0,           "Invalid pool supply!");

        assertEq(IWithdrawalManager(syrupUSDGWithdrawalManagerQueue).asset(),       USDG,                          "Invalid WM asset!");
        assertEq(IWithdrawalManager(syrupUSDGWithdrawalManagerQueue).pool(),        syrupUSDGPool,                 "Invalid WM pool!");
        assertEq(IWithdrawalManager(syrupUSDGWithdrawalManagerQueue).poolManager(), poolManager,                   "Invalid WM PM!");
        assertEq(IWithdrawalManager(syrupUSDGWithdrawalManagerQueue).factory(),     withdrawalManagerQueueFactory, "Invalid WM factory!");
        assertEq(IWithdrawalManager(syrupUSDGWithdrawalManagerQueue).totalShares(), 0,                             "Invalid WM shares!");

        assertEq(
            IWithdrawalManager(syrupUSDGWithdrawalManagerQueue).implementation(),
            mapleWithdrawalManagerV200Implementation,
            "Invalid WM implementation!"
        );

        assertEq(IPoolDelegateCover(syrupUSDGPoolDelegateCover).asset(),       USDG,        "Invalid PDC asset!");
        assertEq(IPoolDelegateCover(syrupUSDGPoolDelegateCover).poolManager(), poolManager, "Invalid PDC PM!");
        assertEq(IERC20Like(USDG).balanceOf(syrupUSDGPoolDelegateCover),       0,           "Invalid PDC balance!");

        address otlm = syrupUSDGOpenTermLoanManager;

        assertEq(IOpenTermLoanManager(otlm).fundsAsset(),            USDG,                                  "Invalid OTLM asset!");
        assertEq(IOpenTermLoanManager(otlm).poolManager(),           poolManager,                           "Invalid OTLM PM!");
        assertEq(IOpenTermLoanManager(otlm).implementation(),        OpenTermLoanManagerV100Implementation, "Invalid OTLM impl!");
        assertEq(IOpenTermLoanManager(otlm).assetsUnderManagement(), 0,                                     "Invalid OTLM AUM!");
        assertEq(IOpenTermLoanManager(otlm).unrealizedLosses(),      0,                                     "Invalid OTLM losses!");
    }

}

contract ValidateUSDGPoolActivation is SyrupUSDGValidationScriptBase {

    function run() external view {
        IPoolPermissionManager ppm = IPoolPermissionManager(poolPermissionManager);

        assertEq(IPoolManager(syrupUSDGPoolManager).active(), true, "PM is not active!");

        ( address ownedPoolManager, ) = IGlobals(globals).poolDelegates(POOL_DELEGATE);

        assertEq(ownedPoolManager, syrupUSDGPoolManager, "PD does not own the PM!");

        assertEq(
            IGlobals(globals).platformOriginationFeeRate(syrupUSDGPoolManager),
            PLATFORM_ORIGINATION_FEE_RATE,
            "Invalid origination fee rate!"
        );

        assertEq(
            IGlobals(globals).platformServiceFeeRate(syrupUSDGPoolManager),
            PLATFORM_SERVICE_FEE_RATE,
            "Invalid service fee rate!"
        );

        assertEq(
            IGlobals(globals).platformManagementFeeRate(syrupUSDGPoolManager),
            PLATFORM_MANAGEMENT_FEE_RATE,
            "Invalid management fee rate!"
        );

        assertEq(ppm.permissionLevels(syrupUSDGPoolManager), PERMISSION_LEVEL, "Invalid permission level!");

        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:deposit"),           LENDER_BITMAP, "Invalid deposit bitmap!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:depositWithPermit"), LENDER_BITMAP, "Invalid depositWithPermit bitmap!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:mint"),              LENDER_BITMAP, "Invalid mint bitmap!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:mintWithPermit"),    LENDER_BITMAP, "Invalid mintWithPermit bitmap!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:redeem"),            LENDER_BITMAP, "Invalid redeem bitmap!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:withdraw"),          LENDER_BITMAP, "Invalid withdraw bitmap!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:removeShares"),      LENDER_BITMAP, "Invalid removeShares bitmap!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:requestWithdraw"),   LENDER_BITMAP, "Invalid requestWithdraw bitmap!");

        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:transfer"),      0, "Transfer bitmap not 0!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:transferFrom"),  0, "TransferFrom bitmap not 0!");
        assertEq(ppm.poolBitmaps(syrupUSDGPoolManager, "P:requestRedeem"), 0, "RequestRedeem bitmap not 0!");

        assertEq(ppm.lenderBitmaps(FIRST_LENDER), LENDER_BITMAP, "Invalid first lender bitmap!");

        assertEq(IPool(syrupUSDGPool).totalSupply(),           INITIAL_DEPOSIT, "Invalid pool supply!");
        assertEq(IPool(syrupUSDGPool).balanceOf(address(0)),   INITIAL_DEPOSIT, "Bootstrap shares not burned!");
        assertEq(IPool(syrupUSDGPool).balanceOf(FIRST_LENDER), 0,               "First lender holds shares!");

        assertEq(IERC20Like(USDG).balanceOf(syrupUSDGPool), INITIAL_DEPOSIT, "Invalid USDG on pool!");
        assertEq(IERC20Like(USDG).balanceOf(FIRST_LENDER),  0,               "First lender holds USDG!");
    }

}

contract ValidateUSDGRouterDeployment is SyrupUSDGValidationScriptBase {

    function run() external view {
        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).asset(),                 USDG,                  "Invalid router asset!");
        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).pool(),                  syrupUSDGPool,         "Invalid router pool!");
        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).poolManager(),           syrupUSDGPoolManager,  "Invalid router PM!");
        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).poolPermissionManager(), poolPermissionManager, "Invalid router PPM!");

        assertEq(IERC20Like(USDG).allowance(syrupUSDGSyrupRouter, syrupUSDGPool), type(uint256).max, "Invalid router USDG allowance!");
    }

}

contract ValidateUSDGRouterAllowlist is SyrupUSDGValidationScriptBase {

    function run() external view {
        IPoolPermissionManager ppm = IPoolPermissionManager(poolPermissionManager);

        assertEq(ppm.lenderAllowlist(syrupUSDGPoolManager, syrupUSDGPoolManager),            true, "PM not allowlisted!");
        assertEq(ppm.lenderAllowlist(syrupUSDGPoolManager, syrupUSDGSyrupRouter),            true, "Router not allowlisted!");
        assertEq(ppm.lenderAllowlist(syrupUSDGPoolManager, syrupUSDGWithdrawalManagerQueue), true, "WM not allowlisted!");

        assertEq(ppm.lenderBitmaps(syrupUSDGSyrupRouter),            0, "Router bitmap must be 0!");
        assertEq(ppm.lenderBitmaps(syrupUSDGWithdrawalManagerQueue), 0, "WM bitmap must be 0!");

        assertEq(ppm.permissionAdmins(PERMISSION_ADMIN_SIGNER), true, "Signer is not a permission admin!");
        assertEq(ppm.permissionAdmins(syrupUSDGSyrupRouter),    true, "Router is not a permission admin!");
    }

}
