// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, TestUtils, console } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }                   from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { WithdrawalManager }            from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

import { LoanManagerFactory }                     from "../modules/poolv2/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer }                 from "../modules/poolv2/contracts/proxy/LoanManagerInitializer.sol";
import { PoolManagerFactory, MapleProxyFactory }  from "../modules/poolv2/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer }                 from "../modules/poolv2/contracts/proxy/PoolManagerInitializer.sol";
import { LoanManager }                            from "../modules/poolv2/contracts/LoanManager.sol";
import { Pool }                                   from "../modules/poolv2/contracts/Pool.sol";
import { PoolDeployer }                           from "../modules/poolv2/contracts/PoolDeployer.sol";
import { PoolManager }                            from "../modules/poolv2/contracts/PoolManager.sol";
import { MockGlobals, MockLoanManager }           from "../modules/poolv2/tests/mocks/Mocks.sol";
import { GlobalsBootstrapper }                    from "../modules/poolv2/tests/bootstrap/GlobalsBootstrapper.sol";

contract PoolDeployerTests is GlobalsBootstrapper {

    address poolDelegate = address(new Address());

    address asset;

    address poolManagerFactory;
    address poolManagerImplementation;
    address poolManagerInitializer;

    address loanManagerFactory;
    address loanManagerImplementation;
    address loanManagerInitializer;

    address withdrawalManagerFactory;
    address withdrawalManagerImplementation;
    address withdrawalManagerInitializer;

    function setUp() public virtual {
        asset = address(new MockERC20("Asset", "AT", 18));
        _deployAndBootstrapGlobals(address(asset), poolDelegate);

        poolManagerFactory        = address(new PoolManagerFactory(globals));
        poolManagerImplementation = address(new PoolManager());
        poolManagerInitializer    = address(new PoolManagerInitializer());

        loanManagerFactory        = address(new LoanManagerFactory(globals));
        loanManagerImplementation = address(new LoanManager());
        loanManagerInitializer    = address(new LoanManagerInitializer());

        withdrawalManagerFactory        = address(new WithdrawalManagerFactory(globals));
        withdrawalManagerImplementation = address(new WithdrawalManager());
        withdrawalManagerInitializer    = address(new WithdrawalManagerInitializer());

        vm.startPrank(GOVERNOR);
        MapleProxyFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        MapleProxyFactory(poolManagerFactory).setDefaultVersion(1);

        MapleProxyFactory(loanManagerFactory).registerImplementation(1, loanManagerImplementation, loanManagerInitializer);
        MapleProxyFactory(loanManagerFactory).setDefaultVersion(1);

        MapleProxyFactory(withdrawalManagerFactory).registerImplementation(1, withdrawalManagerImplementation, withdrawalManagerInitializer);
        MapleProxyFactory(withdrawalManagerFactory).setDefaultVersion(1);
        vm.stopPrank();
    }

    function test_deployPool() external {
        string memory name   = "Pool";
        string memory symbol = "P2";

        address poolDeployer = address(new PoolDeployer(globals));
        MockGlobals(globals).setValidPoolDeployer(poolDeployer, true);

        address[3] memory factories = [
            poolManagerFactory,
            loanManagerFactory,
            withdrawalManagerFactory
        ];

        address[3] memory initializers = [
            poolManagerInitializer,
            loanManagerInitializer,
            withdrawalManagerInitializer
        ];

        uint256[6] memory configParams = [
            1_000_000e18,    // `liquidityCap`
            0.1e18,          // `managementFee`
            10e18,           // `coverAmountRequired`
            block.timestamp, // `cycleStart`
            1 days,          // `withdrawalWindow`
            3 days           // `cycleDuration`
        ];

        MockERC20(asset).mint(poolDelegate, configParams[2]);

        vm.prank(poolDelegate);
        MockERC20(asset).approve(poolDeployer, configParams[2]);

        assertEq(MockERC20(asset).balanceOf(poolDelegate), configParams[2]);

        vm.prank(poolDelegate);
        ( address poolManagerAddress, address loanManagerAddress, address withdrawalManagerAddress ) = PoolDeployer(poolDeployer).deployPool(
            factories,
            initializers,
            address(asset),
            name,
            symbol,
            configParams
        );

        PoolManager poolManager = PoolManager(poolManagerAddress);

        // Validate pool manager state.
        assertEq(poolManager.factory(),                   poolManagerFactory);
        assertEq(poolManager.implementation(),            poolManagerImplementation);
        assertEq(poolManager.globals(),                   address(globals));
        assertEq(poolManager.poolDelegate(),              poolDelegate);
        assertEq(poolManager.liquidityCap(),              configParams[0]);
        assertEq(poolManager.delegateManagementFeeRate(), configParams[1]);
        assertEq(poolManager.loanManagerList(0),          loanManagerAddress);
        assertEq(poolManager.withdrawalManager(),         withdrawalManagerAddress);

        assertTrue(poolManager.configured());
        assertTrue(poolManager.isLoanManager(poolManager.loanManagerList(0)));
        assertTrue(poolManager.poolDelegateCover() != address(0));

        // Assert pool delegate cover is posted.
        assertEq(MockERC20(asset).balanceOf(poolDelegate),                    0);
        assertEq(MockERC20(asset).balanceOf(poolManager.poolDelegateCover()), configParams[2]);

        // Validate pool state.
        Pool pool = Pool(poolManager.pool());

        assertEq(pool.manager(), poolManagerAddress);
        assertEq(pool.asset(),   address(asset));
        assertEq(pool.name(),    name);
        assertEq(pool.symbol(),  symbol);

        assertEq(MockERC20(asset).allowance(address(pool), poolManagerAddress), type(uint256).max);

        // Validate loan manager state.
        LoanManager loanManager = LoanManager(loanManagerAddress);

        assertEq(loanManager.poolManager(), poolManagerAddress);
        assertEq(loanManager.pool(),        address(pool));

        // Validate withdrawal manager state.
        WithdrawalManager withdrawalManager = WithdrawalManager(withdrawalManagerAddress);

        assertEq(withdrawalManager.asset(), address(asset));
        assertEq(withdrawalManager.pool(),  address(pool));

        ( , uint64 startingTime, uint64 withdrawalWindowDuration, uint64 cycleDuration ) = withdrawalManager.configurations(0);

        assertEq(startingTime,             configParams[3]);
        assertEq(withdrawalWindowDuration, configParams[4]);
        assertEq(cycleDuration,            configParams[5]);
    }
}

