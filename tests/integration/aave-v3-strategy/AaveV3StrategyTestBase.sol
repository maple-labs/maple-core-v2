// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAavePoolAddressesProviderLike,
    IAavePoolConfiguratorLike,
    IAavePoolLike,
    IAaveV3Strategy,
    IERC20,
    IMockERC20
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AaveV3StrategyTestBase is TestBaseWithAssertions {

    address lp        = makeAddr("lp");
    address aaveToken = AAVE_USDC;

    bool useVirtualUnderlyingBalance = true;

    uint256 forkBlock = MAINNET_FORK_BLOCK;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), forkBlock);

        start      = block.timestamp;
        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
        _createPoolWithOTLM(poolDelegate);
        _configurePool();

        (aaveV3StrategyManager, aaveV3UnderlyingStrategy) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   aaveToken,
            useVirtualUnderlyingBalance_: useVirtualUnderlyingBalance,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        addStrategyManagerToPool(address(poolManager), aaveV3StrategyManager);
    }

    function borrowOnAave() internal returns (address aavePool, address borrower, uint256 borrowAmount) {
        aavePool = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();
        borrower = makeAddr("borrower");

        // Aave tracks liquidity virtually, while Spark uses the USDC balance held by its aToken.
        uint256 aaveLiquidity = useVirtualUnderlyingBalance
            ? IAavePoolLike(aavePool).getVirtualUnderlyingBalance(address(fundsAsset))
            : fundsAsset.balanceOf(aaveToken);
        uint256 collateralAssets = 1_000_000e18;

        borrowAmount = aaveLiquidity - 1;

        IAavePoolAddressesProviderLike addressesProvider = IAavePoolAddressesProviderLike(IAavePoolLike(aavePool).ADDRESSES_PROVIDER());
        IAavePoolConfiguratorLike      poolConfigurator  = IAavePoolConfiguratorLike(addressesProvider.getPoolConfigurator());

        // Remove the WETH supply cap so the borrower can post enough collateral to drain lending-market liquidity.
        vm.prank(addressesProvider.getACLAdmin());
        poolConfigurator.setSupplyCap(WETH, 0);

        deal(WETH, borrower, collateralAssets);

        vm.startPrank(borrower);
        IERC20(WETH).approve(aavePool, collateralAssets);
        IAavePoolLike(aavePool).supply(WETH, collateralAssets, borrower, 0);
        IAavePoolLike(aavePool).borrow(address(fundsAsset), borrowAmount, 2, 0, borrower);
        vm.stopPrank();
    }

    function setAaveV3ReserveFreeze(bool freeze_) internal {
        address aavePool_ = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        IAavePoolAddressesProviderLike addressesProvider_ = IAavePoolAddressesProviderLike(IAavePoolLike(aavePool_).ADDRESSES_PROVIDER());
        IAavePoolConfiguratorLike      poolConfigurator_  = IAavePoolConfiguratorLike(addressesProvider_.getPoolConfigurator());

        vm.prank(addressesProvider_.getACLAdmin());
        poolConfigurator_.setReserveFreeze(address(fundsAsset), freeze_);
    }

    function setAaveV3ReservePause(bool pause_) internal {
        address aavePool_ = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        IAavePoolAddressesProviderLike addressesProvider_ = IAavePoolAddressesProviderLike(IAavePoolLike(aavePool_).ADDRESSES_PROVIDER());
        IAavePoolConfiguratorLike      poolConfigurator_  = IAavePoolConfiguratorLike(addressesProvider_.getPoolConfigurator());

        vm.prank(addressesProvider_.getACLAdmin());
        poolConfigurator_.setReservePause(address(fundsAsset), pause_);
    }

    function setAaveV3SupplyCap(uint256 supplyCap_) internal {
        address aavePool_ = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        IAavePoolAddressesProviderLike addressesProvider_ = IAavePoolAddressesProviderLike(IAavePoolLike(aavePool_).ADDRESSES_PROVIDER());
        IAavePoolConfiguratorLike      poolConfigurator_  = IAavePoolConfiguratorLike(addressesProvider_.getPoolConfigurator());

        vm.prank(addressesProvider_.getACLAdmin());
        poolConfigurator_.setSupplyCap(address(fundsAsset), supplyCap_);
    }

}
