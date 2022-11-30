// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { IERC20Like, IMapleLoanLike, IPoolLike } from "../simulations/mainnet/Interfaces.sol";
import { SimulationBase }                        from "../simulations/mainnet/SimulationBase.sol";

contract MigrationLoan is SimulationBase {

    address scriptDeployer = 0x632a45c25d2139E6B2745eC3e7D309dEf99f2b9F;

    function run() external {

        /******************************************************************************************************************************/
        /*** Create and Fund Migration Loan                                                                                         ***/
        /******************************************************************************************************************************/

        createMigrationLoan(mavenUsdcPoolV1);
        createMigrationLoan(mavenPermissionedPoolV1);
        createMigrationLoan(mavenWethPoolV1);
        createMigrationLoan(orthogonalPoolV1);

    }

    function createMigrationLoan(IPoolLike  poolV1_) internal {
        // Check if a migration loan needs to be funded.
        uint256 availableLiquidity = calculateAvailableLiquidity(poolV1_);

        if (availableLiquidity == 0) return;

        // Create a loan using all of the available cash in the pool (if there is any).
        IMapleLoanLike migrationLoan = createMigrationLoanInScript(poolV1_, availableLiquidity);
    }

    function createMigrationLoanInScript(IPoolLike poolV1_, uint256 liquidity) internal returns (IMapleLoanLike migrationLoan) {
        IERC20Like asset = IERC20Like(poolV1_.liquidityAsset());

        address[2] memory assets      = [address(asset), address(asset)];
        uint256[3] memory termDetails = [uint256(0), uint256(30 days), uint256(1)];
        uint256[3] memory requests    = [uint256(0), liquidity, liquidity];
        uint256[4] memory rates       = [uint256(0), uint256(0), uint256(0), uint256(0)];

        bytes memory args = abi.encode(address(this), assets, termDetails, requests, rates);
        bytes32 salt      = keccak256(abi.encode(address(poolV1_)));

        vm.setEnv("ETH_FROM", vm.toString(scriptDeployer));
        vm.broadcast(scriptDeployer);
        migrationLoan = IMapleLoanLike(loanFactory.createInstance(args, salt));

        vm.setEnv("ETH_FROM", vm.toString(poolV1_.poolDelegate()));
        vm.broadcast(poolV1_.poolDelegate());
        poolV1_.fundLoan(address(migrationLoan), address(debtLockerFactory), liquidity);

        assertEq(asset.balanceOf(poolV1_.liquidityLocker()), 0);
    }

}
