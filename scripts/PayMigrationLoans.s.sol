// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { IERC20Like, IMapleLoanLike, IMapleLoanV4Like, IPoolLike } from "../simulations/mainnet/Interfaces.sol";

import { SimulationBase } from "../simulations/mainnet/SimulationBase.sol";

contract PayMigrationLoans is SimulationBase {

    address scriptDeployer = 0x632a45c25d2139E6B2745eC3e7D309dEf99f2b9F;  // TODO: Needs to be borrower multisig

    address usdcWhale = 0x6555e1CC97d3cbA6eAddebBCD7Ca51d75771e0B8;
    address wethWhale = 0xB17Fe9F5A2b3E016c653E101845121421e2b225a;

    IMapleLoanLike icebreakerLoan = IMapleLoanLike(0x8487bA9c9ba75E9a61832Fb429e75a560299a227);
    IMapleLoanLike mavenUsdcLoan  = IMapleLoanLike(0xA01F04945251b84797F37D5D44AB9a49b6a7A72B);
    IMapleLoanLike mavenWethLoan  = IMapleLoanLike(0x925a2B680C119Aa3cBbaEFf20ea9147623B0CD0E);
    IMapleLoanLike orthogonalLoan = IMapleLoanLike(0x061fE80139a79DD67eE040c44f19eEe1Fcd04BCC);

    function run() external {
        console.log("icebreakerLoans");
        payMigrationLoans(icebreakerLoans);

        console.log("mavenUsdcLoans");
        payMigrationLoans(mavenUsdcLoans);

        console.log("mavenWethLoans");
        payMigrationLoans(mavenWethLoans);

        console.log("orthogonalLoans");
        payMigrationLoans(orthogonalLoans);
    }

    function payMigrationLoans(IMapleLoanLike[] storage migrationLoans) internal {

        for (uint256 i; i < migrationLoans.length; ++i) {
            console.log("address", address(migrationLoans[i]));

            console.log("version", loanFactory.versionOf(migrationLoans[i].implementation()));
        }

        console.log("address", address(migrationLoan));

        console.log("version", loanFactory.versionOf(migrationLoan.implementation()));

        ( uint256 principal, uint256 interest, uint256 fees ) = IMapleLoanV4Like(address(migrationLoan)).getClosingPaymentBreakdown();

        IERC20Like fundsAsset = IERC20Like(migrationLoan.fundsAsset());

        address sender = fundsAsset == usdc ? usdcWhale : wethWhale;

        address borrower = migrationLoan.borrower();

        console.log("borrower", borrower);

        console.log("principal", principal);
        console.log("interest ", interest);
        console.log("fees     ", fees);

        vm.broadcast(sender);
        fundsAsset.transfer(borrower, fees);

        vm.broadcast(borrower);
        fundsAsset.approve(address(migrationLoan), fees);

        vm.broadcast(borrower);
        migrationLoan.returnFunds(fees);

        vm.broadcast(borrower);
        migrationLoan.closeLoan(0);

        console.log("paid loan", address(migrationLoan));
        console.log("fees     ", fees);
    }

}
