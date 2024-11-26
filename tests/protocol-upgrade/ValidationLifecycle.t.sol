// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPool } from "../../contracts/interfaces/Interfaces.sol";

import { FuzzedUtil } from "../fuzz/FuzzedSetup.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract ValidationLifecycleETH is ProtocolUpgradeBase, FuzzedUtil {

    uint256 ftlCount = 3;
    uint256 otlCount = 3;

    uint256 loanActionCount     = 10;
    uint256 strategyActionCount = 10;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21229159);

        upgradeProtocol();
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Setup                                                                                                                ***/
    /**************************************************************************************************************************************/

    function runLifecycleValidation(uint256 seed_, address pool, address[] storage ftls, address[] storage otls) internal {
        setAddresses(pool);

        _collateralAsset      = usdc;
        _feeManager           = feeManager;
        _fixedTermLoanFactory = fixedTermLoanFactoryV2;
        _openTermLoanFactory  = openTermLoanFactory;
        _liquidatorFactory    = liquidatorFactory;

        address depositor    = makeAddr("depositor");
        uint256 decimals     = IPool(_pool).decimals();
        uint256 liquidityCap = 500_000_000 * 10 ** decimals;
        uint256 liquidity    = 250_000_000 * 10 ** decimals;

        setLiquidityCap(_poolManager, liquidityCap);
        deposit(pool, depositor, liquidity);

        // Add existing loans to the array so they can be paid back at the end of the lifecycle.
        for (uint256 i; i < ftls.length; ++i) {
            loans.push(ftls[i]);
        }

        for (uint256 i; i < otls.length; ++i) {
            loans.push(otls[i]);
        }

        uint256 newFtlCount = ftls.length < ftlCount ? ftlCount - ftls.length : 0;
        uint256 newOtlCount = otls.length < otlCount ? otlCount - otls.length : 0;

        super.fuzzedSetup(newFtlCount, newOtlCount, loanActionCount, strategyActionCount, seed_);

        // TODO: Add assertions.
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    function testFork_validationLifecycle_syrupUsdc(uint256 seed_) external {
        runLifecycleValidation(seed_, syrupUSDCPool, syrupUSDCFixedTermLoans, syrupUSDCOpenTermLoans);
    }

}
