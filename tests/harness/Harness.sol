// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { console }   from "../../modules/contract-test-utils/contracts/log.sol";
import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }                          from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { ConstructableMapleLoan as MockLoan } from "../../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
import { MockFactory }                        from "../../modules/loan/contracts/test/mocks/Mocks.sol";
import { MockLiquidationStrategy }            from "../../modules/poolV2/tests/mocks/Mocks.sol";
import { MockAuctioneer }                     from "../../modules/pool-cover/tests/mocks/MockAuctioneer.sol";
import { MockConverter }                      from "../../modules/pool-cover/tests/mocks/MockConverter.sol";
import { MockOracle }                         from "../../modules/pool-cover/tests/mocks/MockOracle.sol";

import { PB_ST_05 as InvestmentManager } from "../../modules/poolV2/contracts/InvestmentManager.sol";
import { IPool, Pool }                   from "../../modules/poolV2/contracts/Pool.sol";
import { IPoolManager }     from "../../modules/poolV2/contracts/PoolManager.sol";

import { IPoolCover }        from "../../modules/pool-cover/contracts/PoolCover.sol";
import { IPoolCoverManager } from "../../modules/pool-cover/contracts/PoolCoverManager.sol";

import { IWithdrawalManager } from "../../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

/**
 *  @dev Contains common utility functions used in E2E protocol tests.
 */
contract Harness is TestUtils {

    function _claimLoan(address poolManager_, address loan_, address borrower_) internal {
        vm.prank(borrower_);
        IPoolManager(poolManager_).claim(loan_);
    }

    function _convertLiquidity(address poolCoverManager_, address poolCover_, address converter_) internal {
        uint256 liquidity = IPoolCoverManager(poolCoverManager_).liquidity(poolCover_);

        vm.prank(converter_);
        IPoolCoverManager(poolCoverManager_).convertLiquidity(poolCover_, liquidity, type(uint256).max, "");
    }

    function _depositCover(address poolCover_, address account_, uint256 assetAmount_) internal returns (uint256 shares_) {
        address asset = IPoolCover(poolCover_).asset();
        MockERC20(asset).mint(account_, assetAmount_);

        vm.startPrank(account_);
        MockERC20(asset).approve(poolCover_, assetAmount_);
        shares_ = IPoolCover(poolCover_).deposit(assetAmount_, account_);
        vm.stopPrank();
    }

    function _depositLiquidity(address pool_, address account_, uint256 assetAmount_) internal returns (uint256 shares_) {
        address liquidityAsset = IPool(pool_).asset();
        MockERC20(liquidityAsset).mint(account_, assetAmount_);

        vm.startPrank(account_);
        MockERC20(liquidityAsset).approve(pool_, assetAmount_);
        shares_ = IPool(pool_).deposit(assetAmount_, account_);
        vm.stopPrank();
    }

    function _fundAndDrawdownLoan(address poolManager_, address poolDelegate_, address borrower_, address investmentManager_, address collateralAsset_, uint256 collateralAmount_, address liquidityAsset_, uint256 principalAmount_, uint256 interestRate_) internal returns (address loan_) {
        address[2] memory assets      = [collateralAsset_, liquidityAsset_];
        uint256[3] memory termDetails = [uint256(5 days), 30 days, 3];  // gracePeriod, paymentInterval, paymentsRemaining
        uint256[3] memory amounts     = [0, principalAmount_, principalAmount_];
        uint256[4] memory rates       = [interestRate_, 0, 0, 0];

        loan_ = address(new MockLoan(address(new MockFactory()), borrower_, assets, termDetails, amounts, rates));

        vm.prank(poolDelegate_);
        IPoolManager(poolManager_).fund(principalAmount_, loan_, investmentManager_);

        vm.startPrank(borrower_);
        MockERC20(collateralAsset_).mint(borrower_, collateralAmount_);
        MockERC20(collateralAsset_).approve(loan_, collateralAmount_);
        MockLoan(loan_).postCollateral(collateralAmount_);
        MockLoan(loan_).drawdownFunds(principalAmount_, borrower_);
        vm.stopPrank();
    }

    function _liquidateCollateral(address investmentManager_, address loan_, address liquidator_, uint256 swapAmount_, address collateralAsset_, address fundsAsset_) internal {
        MockConverter(liquidator_).liquidateCollateral(investmentManager_, loan_, swapAmount_, collateralAsset_, fundsAsset_);

    }

    function _liquidatePoolCover(address liquidator_, address poolCoverManager_, address poolCover_, uint256 coverAssetAmount_) internal {
        MockConverter(liquidator_).convertCoverToLiquidityAsset(poolCoverManager_, poolCover_, coverAssetAmount_);
    }

    function _makePayment(address loan_, address borrower_) internal {
        ( uint256 principal, uint256 interest ) = MockLoan(loan_).getNextPaymentBreakdown();
        uint256 payment = principal + interest;

        address fundsAsset = MockLoan(loan_).fundsAsset();
        MockERC20(fundsAsset).mint(borrower_, payment);

        vm.startPrank(borrower_);
        MockERC20(fundsAsset).approve(loan_, payment);
        MockLoan(loan_).makePayment(payment);
        vm.stopPrank();
    }

    function _payClaimAndConvert(address loan_, address poolManager_, address poolCoverManager_, address borrower_, address[] memory converters_, address[] memory poolCovers_) internal {
        _makePayment(loan_, borrower_);
        _claimLoan(poolManager_, loan_, borrower_);

        uint256 length = converters_.length;
        require(length == poolCovers_.length, "converters_ and poolCovers_ different length.");

        for (uint256 i = 1; i < length; i++) {
            // 0 is liquidityAsset, no coversion needed
            // TODO: make this more flexible
            _convertLiquidity(poolCoverManager_, poolCovers_[i], converters_[i]);
        }
    }

    function _setManagersOnPoolManager(address poolManager_, address poolDelegate_, address investmentManager_, address poolCoverManager_, address withdrawalManager_) internal {
        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setInvestmentManager(investmentManager_, true);
        IPoolManager(poolManager_).setPoolCoverManager(poolCoverManager_);
        IPoolManager(poolManager_).setWithdrawalManager(withdrawalManager_);
        vm.stopPrank();
    }

    function _requestCoverWithdrawal(address poolCover_, address account_, uint256 shares_) internal {
        vm.startPrank(account_);
        IPoolCover(poolCover_).approve(IPoolCover(poolCover_).escrow(), shares_);
        IPoolCover(poolCover_).makeExitRequest(shares_, account_);
        vm.stopPrank();
    }

    function _requestLiquidityWithdrawal(address pool_, address withdrawalManager_, address account_, uint256 shares_) internal {
        vm.startPrank(account_);
        IPool(pool_).approve(withdrawalManager_, shares_);
        shares_ = IWithdrawalManager(withdrawalManager_).lockShares(shares_);
        vm.stopPrank();
    }

    function _updatePCMSettings(address poolCoverManager_, address poolDelegate_, address[] memory poolCovers_, address[] memory converterAuctioneers_, uint16[] memory weights_) internal {
        uint256 length = poolCovers_.length;
        require(length == converterAuctioneers_.length && length == weights_.length, "Arrays have mismatched length.");

        IPoolCoverManager.Settings[] memory settings = new IPoolCoverManager.Settings[](length);
        for (uint256 i = 0; i < length; i++) {
            settings[i] = IPoolCoverManager.Settings(poolCovers_[i], converterAuctioneers_[i], weights_[i]);
        }
        
        vm.prank(poolDelegate_);
        IPoolCoverManager(poolCoverManager_).updateSettings(settings);
    }

    function _updatePCMLiquidationSettings(address poolCoverManager_, address poolDelegate_, address poolManager_, address[] memory poolCovers_, address[] memory liquidationAuctioneers_, address[] memory oracles_) internal {
        uint256 length = poolCovers_.length;
        require(length == liquidationAuctioneers_.length && length == oracles_.length, "Arrays have mismatched length.");
        
        vm.prank(poolDelegate_);
        IPoolCoverManager(poolCoverManager_).updateOracles(oracles_);

        vm.prank(poolDelegate_);
        IPoolCoverManager(poolCoverManager_).setPoolManager(poolManager_);

        vm.prank(poolDelegate_);
        IPoolCoverManager(poolCoverManager_).updateLiquidationAuctioneers(liquidationAuctioneers_);
    }

    function _withdrawCover(address account_, address poolCover_, uint256 shares_) internal returns (uint256 assets_) {
        vm.prank(account_);
        assets_ = IPoolCover(poolCover_).redeem(shares_, account_, account_);
    }

    function _withdrawLiquidity(address withdrawalManager_, address account_) internal returns (uint256 assets_) {
        vm.prank(account_);
        ( assets_, , ) = IWithdrawalManager(withdrawalManager_).redeemPosition(0);
    }

}
