// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { IDebtLockerLike, IERC20Like, IMapleLoanLike, IPoolV1Like } from "../simulations/mainnet/Interfaces.sol";

import { SimulationBase } from "../simulations/mainnet/SimulationBase.sol";

contract PayAndRefiUpcomingLoans is SimulationBase {

    // Maven Permissioned loans to
    address constant mavenPermissionedLoan1 = 0x500055809685ecebA5eC55786f65440583954501;
    address constant mavenPermissionedLoan2 = 0xa83b134809183c634A692D5b5F457b78Cd6913e6;

    // Maven USDC loans
    address constant mavenUsdcLoan1 = 0x245De7E3B9B21B68c2C8D2e4759652F0dbCE65A6;
    address constant mavenUsdcLoan2 = 0x502EE6D0b16d834547Fc44344D4BE3E019Fc2573;
    address constant mavenUsdcLoan3 = 0x726893373DE92b8272298D76a7D60a5F51b90dA9;
    address constant mavenUsdcLoan4 = 0xF6950F28353cA676100C2a92DD360DEa16A213cE;
    address constant mavenUsdcLoan5 = 0xa58fD39138083783689d700758D00873538C6C2A;
    address constant mavenUsdcLoan6 = 0xd027CdD569b6cd1aD13dc82d42d0CD7cDeda3521;

    // Maven WETH loans
    address constant mavenWethLoan1  = 0x0104AE451AD2542aC9250Ebe4a37D0717FdfC60C;
    address constant mavenWethLoan2  = 0x91A4eEe4D33d9cd7840CAe21A4f408c0919F555D;
    address constant mavenWethLoan3  = 0xC8c17328796F472A97B7784cc5F52b802A89deC1;
    address constant mavenWethLoan4  = 0x4DbE67c683A731807EAAa99A1DF2D3E79ebECA00;
    address constant mavenWethLoan5  = 0xFcF8725d0D9A786448c5B9b9cc67226d7e4d5c3D;
    address constant mavenWethLoan6  = 0x64982f1aA56340C0051bDCeFb7a69911Fd9D141d;
    address constant mavenWethLoan7  = 0x2cB5c20309B2DbfDda758237f20c94b5F72d0331;
    address constant mavenWethLoan8  = 0x40d9fBe05d8F9f1215D5a6d01994ad1a6a097616;
    address constant mavenWethLoan9  = 0x2872C1140117a5DE85E0DD06Ed1B439D23707AD1;
    address constant mavenWethLoan10 = 0xdeF9146F12e22e5c69Fb7b7D181534240c04FdCE;

    // Orthogonal loans
    address constant orthogonalLoan1 = 0x249B5907564f0Cf3Fb771b013A6f9f33e1225657;

    address constant usdcWhale = 0x6555e1CC97d3cbA6eAddebBCD7Ca51d75771e0B8;
    address constant wethWhale = 0x2fEb1512183545f48f6b9C5b4EbfCaF49CfCa6F3;

    function run() external {
        payAllHealthyLoans();
        claimAllLoans();
        assertNoClaimableLoans();
        refinanceAllLoans();
    }

    function payLoan(address loan) internal {
        address fundsAsset = IMapleLoanLike(loan).fundsAsset();

        ( uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee ) = IMapleLoanLike(loan).getNextPaymentBreakdown();

        uint256 paymentAmount = principal + interest + delegateFee + treasuryFee;

        address sender = address(fundsAsset) == usdc ? usdcWhale : wethWhale;

        address borrower = IMapleLoanLike(loan).borrower();

        vm.broadcast(sender);
        IERC20Like(fundsAsset).transfer(borrower, paymentAmount);

        vm.startBroadcast(IMapleLoanLike(loan).borrower());

        IERC20Like(fundsAsset).approve(address(loan), paymentAmount);
        IMapleLoanLike(loan).makePayment(paymentAmount);

        vm.stopBroadcast();
    }

    function payAllHealthyLoans() internal {
        payLoan(mavenPermissionedLoan2);
    }

    function assertNotClaimable(address loan) internal {
        assertEq(IMapleLoanLike(loan).claimableFunds(), 0);
    }

    function assertNoClaimableLoans() internal {
        assertNotClaimable(mavenPermissionedLoan1);
        assertNotClaimable(mavenPermissionedLoan1);

        assertNotClaimable(mavenUsdcLoan1);
        assertNotClaimable(mavenUsdcLoan2);
        assertNotClaimable(mavenUsdcLoan3);
        assertNotClaimable(mavenUsdcLoan4);
        assertNotClaimable(mavenUsdcLoan5);
        assertNotClaimable(mavenUsdcLoan6);

        assertNotClaimable(mavenWethLoan1);
        assertNotClaimable(mavenWethLoan2);
        assertNotClaimable(mavenWethLoan3);
        assertNotClaimable(mavenWethLoan4);
        assertNotClaimable(mavenWethLoan5);
        assertNotClaimable(mavenWethLoan6);
        assertNotClaimable(mavenWethLoan7);
        assertNotClaimable(mavenWethLoan8);
        assertNotClaimable(mavenWethLoan9);
        assertNotClaimable(mavenWethLoan10);

        assertNotClaimable(orthogonalLoan1);
    }

    function refinanceLoan(address poolV1, address loan) internal {
        address borrower     = IMapleLoanLike(loan).borrower();
        address debtLocker   = IMapleLoanLike(loan).lender();
        address poolDelegate = IPoolV1Like(poolV1).poolDelegate();

        bytes[] memory calls = new bytes[](4);

        calls[0] = abi.encodeWithSignature("setGracePeriod(uint256)",         0 seconds);
        calls[3] = abi.encodeWithSignature("setLateInterestPremium(uint256)", 0.05e18);
        calls[1] = abi.encodeWithSignature("setPaymentInterval(uint256)",     10 days);
        calls[2] = abi.encodeWithSignature("setPaymentsRemaining(uint256)",   1);

        vm.broadcast(borrower);
        IMapleLoanLike(loan).proposeNewTerms(refinancer, type(uint256).max, calls);

        vm.broadcast(poolDelegate);
        IDebtLockerLike(debtLocker).acceptNewTerms(refinancer, type(uint256).max, calls, 0);

        assertEq(IMapleLoanLike(loan).gracePeriod(),         0 seconds);
        assertEq(IMapleLoanLike(loan).lateInterestPremium(), 0.05e18);
        assertEq(IMapleLoanLike(loan).paymentInterval(),     10 days);
        assertEq(IMapleLoanLike(loan).paymentsRemaining(),   1);
        assertEq(IMapleLoanLike(loan).nextPaymentDueDate(),  block.timestamp + 10 days);
    }

    function refinanceAllLoans() internal {
        refinanceLoan(mavenPermissionedPoolV1, mavenPermissionedLoan1);

        refinanceLoan(mavenUsdcPoolV1, mavenUsdcLoan1);
        refinanceLoan(mavenUsdcPoolV1, mavenUsdcLoan3);

        refinanceLoan(mavenWethPoolV1, mavenWethLoan1);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan2);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan5);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan6);
        refinanceLoan(mavenWethPoolV1, mavenWethLoan7);
    }

}
