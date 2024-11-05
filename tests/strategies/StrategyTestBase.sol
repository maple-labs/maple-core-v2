// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxied, IMockERC20 } from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../contracts/Runner.sol";

import { TestBase } from "../TestBase.sol";

contract StrategyTestBase is TestBase {

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        start = block.timestamp;

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _setTreasury();
        _createFactories();

        ( address poolManager_, address pool_, , address wm_ , ) =
            deployer.getDeploymentAddresses({
                poolDelegate_:             address(poolDelegate),
                poolManagerFactory_:       address(poolManagerFactory),
                withdrawalManagerFactory_: address(queueWMFactory),
                strategyFactories_:        new address[](0),
                strategyDeploymentData_:   new bytes[](0),
                asset_:                    address(fundsAsset),
                name_:                     POOL_NAME,
                symbol_:                   POOL_SYMBOL,
                configParams_:             [type(uint256).max, 0, 0, 0]
            });

        address[] memory factories = new address[](4);

        bytes[] memory deploymentData = new bytes[](4);

        // Add both aave and sky strategy factories
        factories[0] = (fixedTermLoanManagerFactory);
        factories[1] = (openTermLoanManagerFactory);
        factories[2] = (aaveStrategyFactory);
        factories[3] = (skyStrategyFactory);

        deploymentData[0] = (abi.encode(poolManager_));
        deploymentData[1] = (abi.encode(poolManager_));
        deploymentData[2] = (abi.encode(pool_, AAVE_USDC));
        deploymentData[3] = (abi.encode(pool_, SAVINGS_USDS, USDS_LITE_PSM));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC),     true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS),  true);
        globals.setValidInstanceOf("PSM",            address(USDS_LITE_PSM), true);
        vm.stopPrank();

        _createPoolWithQueueAndStrategies(address(fundsAsset), factories, deploymentData);

        activatePool(address(poolManager), HUNDRED_PERCENT);
        allowLender(address(poolManager), wm_);
    }

    function _getStrategy(address factory_) internal view returns (address strategy_) {
        uint256 length = poolManager.strategyListLength();

        for (uint256 i; i < length; i++) {
            strategy_ = poolManager.strategyList(i);
            if (IMapleProxied(strategy_).factory() == factory_) {
                return strategy_;
            }
        }

        require(false, "STRATEGY_NOT_FOUND");
    }

}
