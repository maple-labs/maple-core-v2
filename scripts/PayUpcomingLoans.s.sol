// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { IDebtLockerLike, IERC20Like, IMapleLoanLike, IMapleLoanV4Like, IPoolLike } from "../simulations/mainnet/Interfaces.sol";

import { SimulationBase } from "../simulations/mainnet/SimulationBase.sol";

contract PayUpcomingLoans is SimulationBase {

    address scriptDeployer = 0x632a45c25d2139E6B2745eC3e7D309dEf99f2b9F;  // TODO: Needs to be borrower multisig

    address usdcWhale = 0x6555e1CC97d3cbA6eAddebBCD7Ca51d75771e0B8;
    address wethWhale = 0xB17Fe9F5A2b3E016c653E101845121421e2b225a;

    uint256 EARLY_TOLERANCE = 1 days;

    function run() external {
        console.log("mavenPermissionedLoans");
        payUpcomingLoans(mavenPermissionedLoans);

        console.log("mavenUsdcLoans");
        payUpcomingLoans(mavenUsdcLoans);

        console.log("mavenWethLoans");
        payUpcomingLoans(mavenWethLoans);

        console.log("orthogonalLoans");
        payUpcomingLoans(orthogonalLoans);

        console.log("icebreakerLoans");
        payUpcomingLoans(icebreakerLoans);
    }

    function payUpcomingLoans(IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {

            IMapleLoanLike loan       = loans[i];
            IERC20Like     fundsAsset = IERC20Like(loan.fundsAsset());

            console.log("loan", address(loan));

            uint256 paymentDueDate = loan.nextPaymentDueDate();

            // If the loan is more than 5 days early, skip it
            if (paymentDueDate > block.timestamp && paymentDueDate - block.timestamp >= EARLY_TOLERANCE) continue;

            ( uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee ) = loan.getNextPaymentBreakdown();

            uint256 paymentAmount = principal + interest + delegateFee + treasuryFee;

            address sender = fundsAsset == usdc ? usdcWhale : wethWhale;

            address borrower = loan.borrower();

            console.log("msg.sender", msg.sender);

            // vm.setEnv("ETH_FROM", vm.toString(sender));
            vm.broadcast(sender);
            fundsAsset.transfer(borrower, paymentAmount);

            // vm.setEnv("ETH_FROM", vm.toString(loan.borrower()));
            vm.startBroadcast(loan.borrower());

            fundsAsset.approve(address(loan), paymentAmount);
            loan.makePayment(paymentAmount);

            vm.stopBroadcast();

            IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());

            IPoolLike pool = IPoolLike(debtLocker.pool());

            // vm.setEnv("ETH_FROM", vm.toString(debtLocker.poolDelegate()));
            vm.broadcast(debtLocker.poolDelegate());
            pool.claim(address(loan), address(debtLockerFactory));

            console.log("PAID", address(loan));
        }
    }

}
