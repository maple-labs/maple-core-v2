// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAavePoolAddressesProviderLike,
    IAavePoolConfiguratorLike,
    IAavePoolLike,
    IAaveV3Strategy,
    IMockERC20
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AaveV3StrategyTestBase is TestBaseWithAssertions {

    address lp = makeAddr("lp");

    address aaveToken                   = AAVE_USDC;
    bool    useVirtualUnderlyingBalance = true;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), AAVE_V3_FORK_BLOCK);

        start      = block.timestamp;
        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
        _createPoolWithOTLM(poolDelegate);
        _configurePool();

        _deployAaveV3Strategy(aaveToken, useVirtualUnderlyingBalance);

        addStrategyManagerToPool(address(poolManager), aaveV3StrategyManager);
    }

    function setAaveV3ReserveFreeze(bool freeze_) internal {
        address aavePool_ = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        IAavePoolAddressesProviderLike addressesProvider_ = IAavePoolAddressesProviderLike(IAavePoolLike(aavePool_).ADDRESSES_PROVIDER());
        IAavePoolConfiguratorLike poolConfigurator_       = IAavePoolConfiguratorLike(addressesProvider_.getPoolConfigurator());

        vm.prank(addressesProvider_.getACLAdmin());
        poolConfigurator_.setReserveFreeze(address(fundsAsset), freeze_);
    }

    function setAaveV3ReservePause(bool pause_) internal {
        address aavePool_ = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        IAavePoolAddressesProviderLike addressesProvider_ = IAavePoolAddressesProviderLike(IAavePoolLike(aavePool_).ADDRESSES_PROVIDER());
        IAavePoolConfiguratorLike poolConfigurator_       = IAavePoolConfiguratorLike(addressesProvider_.getPoolConfigurator());

        vm.prank(addressesProvider_.getACLAdmin());
        poolConfigurator_.setReservePause(address(fundsAsset), pause_);
    }

    function setAaveV3SupplyCap(uint256 supplyCap_) internal {
        address aavePool_ = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        IAavePoolAddressesProviderLike addressesProvider_ = IAavePoolAddressesProviderLike(IAavePoolLike(aavePool_).ADDRESSES_PROVIDER());
        IAavePoolConfiguratorLike poolConfigurator_       = IAavePoolConfiguratorLike(addressesProvider_.getPoolConfigurator());

        vm.prank(addressesProvider_.getACLAdmin());
        poolConfigurator_.setSupplyCap(address(fundsAsset), supplyCap_);
    }

}
