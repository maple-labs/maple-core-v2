// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IMapleProxyFactory, IPool, IPoolManager, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

interface IMainnetController {
    function RELAYER() external view returns (bytes32);
    function proxy() external view returns (address);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function depositERC4626(address token, uint256 amount) external returns (uint256 shares);
    function requestMapleRedemption(address mapleToken, uint256 shares) external;
    function cancelMapleRedemption(address mapleToken, uint256 shares) external;
}

contract SparkFork_MainnetController_SyrupUSDC is MapleWithdrawalManagerUpgradeBaseTest {
    address constant CONTROLLER   = 0x577Fa18a498e1775939b668B0224A5e5a1e56fc3;
    address constant RELAYER_ADDR = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;
    address constant USDC_WHALE   = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;
    uint256 constant USDC_DEPOSIT = 1_000_000;

    IMainnetController controller;

    address owner;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23716737);

        _upgradeSyrupUSDCWithdrawalManager();

        controller = IMainnetController(CONTROLLER);

        bytes32 relayerRole = controller.RELAYER();
        require(controller.hasRole(relayerRole, RELAYER_ADDR), "Provided relayer lacks RELAYER role");

        require(IPool(syrupUSDCPool).asset() == USDC, "Pool asset mismatch");

        owner = controller.proxy();

        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(owner, USDC_DEPOSIT * 10);
    }

    function _upgradeSyrupUSDCWithdrawalManager() internal {
        mapleWithdrawalManagerV200Implementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");
        mapleWithdrawalManagerV200Migrator       = deployFromFile("Contracts@7", "WithdrawalManagerQueueMigrator");
        mapleWithdrawalManagerV200Initializer    = deployFromFile("Contracts@7", "WithdrawalManagerQueueInitializer");

        vm.startPrank(governorTimelock);

        IMapleProxyFactory(withdrawalManagerQueueFactory).registerImplementation(
            200,
            mapleWithdrawalManagerV200Implementation,
            mapleWithdrawalManagerV200Initializer
        );

        IMapleProxyFactory(withdrawalManagerQueueFactory).enableUpgradePath(100, 200, mapleWithdrawalManagerV200Migrator);
        IMapleProxyFactory(withdrawalManagerQueueFactory).setDefaultVersion(200);
        vm.stopPrank();

        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue);

        vm.prank(securityAdmin);
        wm.upgrade(200, "");

        assertEq(wm.implementation(), mapleWithdrawalManagerV200Implementation);        
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(wm.implementation()), 200);
    }

    function testFork_deposit_USDC() external {
        uint256 sharesBefore   = IERC20(syrupUSDCPool).balanceOf(owner);
        uint256 expectedMinted = IPool(syrupUSDCPool).previewDeposit(USDC_DEPOSIT);

        vm.prank(RELAYER_ADDR);
        uint256 sharesMinted = controller.depositERC4626(syrupUSDCPool, USDC_DEPOSIT);

        uint256 sharesAfter = IERC20(syrupUSDCPool).balanceOf(owner);

        assertEq(sharesMinted, expectedMinted,                "minted shares mismatch");
        assertEq(sharesAfter,  sharesBefore + expectedMinted, "proxy share balance mismatch");
    }

    function testFork_deposit_requestRedemption_USDC() external {
        uint256 sharesBefore   = IERC20(syrupUSDCPool).balanceOf(owner);
        uint256 expectedMinted = IPool(syrupUSDCPool).previewDeposit(USDC_DEPOSIT);

        vm.prank(RELAYER_ADDR);
        uint256 sharesMinted       = controller.depositERC4626(syrupUSDCPool, USDC_DEPOSIT);
        uint256 sharesAfterDeposit = IERC20(syrupUSDCPool).balanceOf(owner);

        assertEq(sharesMinted,       expectedMinted,                "minted shares mismatch");
        assertEq(sharesAfterDeposit, sharesBefore + expectedMinted, "post-deposit shares mismatch");

        uint256 partialRequestShares = expectedMinted / 2;
        uint256 expectedAfterRequest = sharesAfterDeposit - partialRequestShares;

        vm.prank(RELAYER_ADDR);
        controller.requestMapleRedemption(syrupUSDCPool, partialRequestShares);

        uint256 sharesAfterRequest = IERC20(syrupUSDCPool).balanceOf(owner);
        assertEq(sharesAfterRequest, expectedAfterRequest, "post-request shares mismatch");
    }

    function testFork_deposit_requestAndCancelRedemption_USDC() external {
        uint256 sharesBefore   = IERC20(syrupUSDCPool).balanceOf(owner);
        uint256 expectedMinted = IPool(syrupUSDCPool).previewDeposit(USDC_DEPOSIT);

        vm.prank(RELAYER_ADDR);
        uint256 sharesMinted        = controller.depositERC4626(syrupUSDCPool, USDC_DEPOSIT);
        uint256 sharesBeforeRequest = IERC20(syrupUSDCPool).balanceOf(owner);

        assertEq(sharesMinted,        expectedMinted,                "minted shares mismatch");
        assertEq(sharesBeforeRequest, sharesBefore + expectedMinted, "post-deposit shares mismatch");

        uint256 partialRequestShares = expectedMinted / 2;
        uint256 expectedAfterRequest = sharesBeforeRequest - partialRequestShares;
        uint256 expectedAfterCancel  = sharesBeforeRequest;

        vm.prank(RELAYER_ADDR);
        controller.requestMapleRedemption(syrupUSDCPool, partialRequestShares);
        uint256 sharesAfterRequest = IERC20(syrupUSDCPool).balanceOf(owner);

        assertEq(sharesAfterRequest, expectedAfterRequest, "post-request shares mismatch");

        vm.prank(RELAYER_ADDR);
        controller.cancelMapleRedemption(syrupUSDCPool, partialRequestShares);
        uint256 sharesAfterCancel = IERC20(syrupUSDCPool).balanceOf(owner);

        assertEq(sharesAfterCancel, expectedAfterCancel, "post-cancel shares mismatch");
    }

    function testFork_deposit_requestAndProcessRedemption_partial_USDC() external {
        uint256 sharesBefore   = IERC20(syrupUSDCPool).balanceOf(owner);
        uint256 expectedMinted = IPool(syrupUSDCPool).previewDeposit(USDC_DEPOSIT);

        vm.prank(RELAYER_ADDR);
        uint256 sharesMinted       = controller.depositERC4626(syrupUSDCPool, USDC_DEPOSIT);
        uint256 sharesAfterDeposit = IERC20(syrupUSDCPool).balanceOf(owner);

        assertEq(sharesMinted,       expectedMinted,                "minted shares mismatch");
        assertEq(sharesAfterDeposit, sharesBefore + expectedMinted, "post-deposit shares mismatch");

        uint256 partialRequestShares = expectedMinted / 2;
        uint256 expectedExitAssets = IPool(syrupUSDCPool).convertToExitAssets(partialRequestShares);

        vm.prank(RELAYER_ADDR);
        controller.requestMapleRedemption(syrupUSDCPool, partialRequestShares);

        address poolManager       = IPool(syrupUSDCPool).manager();
        address withdrawalManager = IPoolManager(poolManager).withdrawalManager();
        address poolDelegate      = IPoolManager(poolManager).poolDelegate();
        uint256 userAssetBefore   = IERC20(USDC).balanceOf(owner);

        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(syrupUSDCPool, expectedExitAssets);

        vm.prank(poolDelegate);
        IWithdrawalManagerQueue(withdrawalManager).processRedemptions(partialRequestShares);

        uint256 userAssetAfter = IERC20(USDC).balanceOf(owner);
        assertEq(userAssetAfter - userAssetBefore, expectedExitAssets, "owner asset receipt mismatch (partial)");
    }

    function testFork_deposit_requestAndProcessRedemption_full_USDC() external {
        uint256 sharesBefore   = IERC20(syrupUSDCPool).balanceOf(owner);
        uint256 expectedMinted = IPool(syrupUSDCPool).previewDeposit(USDC_DEPOSIT);

        vm.prank(RELAYER_ADDR);
        uint256 sharesMinted       = controller.depositERC4626(syrupUSDCPool, USDC_DEPOSIT);
        uint256 sharesAfterDeposit = IERC20(syrupUSDCPool).balanceOf(owner);

        assertEq(sharesMinted,       expectedMinted,                "minted shares mismatch");
        assertEq(sharesAfterDeposit, sharesBefore + expectedMinted, "post-deposit shares mismatch");

        uint256 requestShares = expectedMinted;
        uint256 expectedExitAssets = IPool(syrupUSDCPool).convertToExitAssets(requestShares);

        vm.prank(RELAYER_ADDR);
        controller.requestMapleRedemption(syrupUSDCPool, requestShares);

        address poolManager       = IPool(syrupUSDCPool).manager();
        address withdrawalManager = IPoolManager(poolManager).withdrawalManager();
        address poolDelegate      = IPoolManager(poolManager).poolDelegate();
        uint256 userAssetBefore   = IERC20(USDC).balanceOf(owner);

        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(syrupUSDCPool, expectedExitAssets);

        vm.prank(poolDelegate);
        IWithdrawalManagerQueue(withdrawalManager).processRedemptions(requestShares);

        uint256 userAssetAfter = IERC20(USDC).balanceOf(owner);
        assertEq(userAssetAfter - userAssetBefore, expectedExitAssets, "owner asset receipt mismatch (full)");
    }

}
