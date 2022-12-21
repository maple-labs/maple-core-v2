// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract FutureAddresses {

    /******************************************************************************************************************************/
    /*** Maple V2 Contracts                                                                                                     ***/
    /******************************************************************************************************************************/

    address loanV401Implementation;

    /******************************************************************************************************************************/
    /*** Maven 11 - USDC (Permissioned)                                                                                         ***/
    /******************************************************************************************************************************/

    address mavenPermissionedMigrationLoan     = 0x721A55F2972a46042991a946b60B548BeC31a65B;
    address mavenPermissionedPoolV2            = 0x00e0C1ea2085e30E5233E98CFA940ca8cbB1b0b7;
    address mavenPermissionedPoolManager       = 0x24617612DeC91855e126e6330580425F6A262ee9;
    address mavenPermissionedLoanManager       = 0x6B6491AAa92Ce7e901330D8F91Ec99C2a157EBd7;
    address mavenPermissionedWithdrawalManager = 0x1B56856eB74bB1AA9e9F1997386dDB28DEf532eE;
    address mavenPermissionedPoolDelegateCover = 0x9e71Da2edaD3F8053C00b697362A365383e9c518;

    /******************************************************************************************************************************/
    /*** Maven 11 - USDC 01                                                                                                     ***/
    /******************************************************************************************************************************/

    address mavenUsdcMigrationLoan     = 0x3F542d451344Ea0Cb58323d049033Fd46Ae56Ec3;
    address mavenUsdcPoolV2            = 0xd3cd37a7299B963bbc69592e5Ba933388f70dc88;
    address mavenUsdcPoolManager       = 0x00d950A41a0d277ed91bF9fD366a5523FEF0371e;
    address mavenUsdcLoanManager       = 0x74CB3c1938A15e532CC1b465e3B641C2c7e40C2b;
    address mavenUsdcWithdrawalManager = 0x7ED195a0AE212D265511b0978Af577F59876C9BB;
    address mavenUsdcPoolDelegateCover = 0x9c74C5147653041239bb31C799c54767D9953f7D;

    /******************************************************************************************************************************/
    /*** Maven 11 - WETH                                                                                                        ***/
    /******************************************************************************************************************************/

    address mavenWethMigrationLoan     = 0x508b8cDC6e217a9239CcCf390cD1497bfc4a21C4;
    address mavenWethPoolV2            = 0xFfF9A1CAf78b2e5b0A49355a8637EA78b43fB6c3;
    address mavenWethPoolManager       = 0x833A5c9Fc016a87419D21B10B64e24082Bd1e49d;
    address mavenWethLoanManager       = 0x373BDCf21F6a939713d5DE94096ffdb24A406391;
    address mavenWethWithdrawalManager = 0x1Bb73D6384ae73DA2101a4556a42eaB82803Ef3d;
    address mavenWethPoolDelegateCover = 0xdfDDE84b117f038785A2B1805B10D5C4d616dA08;

    /******************************************************************************************************************************/
    /*** Orthogonal Trading - USDC 01                                                                                           ***/
    /******************************************************************************************************************************/

    address orthogonalMigrationLoan     = 0x8E33448DB74EdA0De5C86e22DA58984867015141;
    address orthogonalPoolV2            = 0x79400A2c9a5E2431419CaC98Bf46893c86E8bDd7;
    address orthogonalPoolManager       = 0xE10A065D15A6eCA69bb8A0063Fe57eDdb66999DF;
    address orthogonalLoanManager       = 0xFdC7541201aA6831A64F96582111cED633fA5078;
    address orthogonalWithdrawalManager = 0xD8f8BD488ba6DDF2a710f6C357a884fd1706981A;
    address orthogonalPoolDelegateCover = 0xb9Bae8c63593e51A296857AC4C150bae31a4e2c3;

    /******************************************************************************************************************************/
    /*** Icebreaker Finance - USDC                                                                                              ***/
    /******************************************************************************************************************************/

    address icebreakerMigrationLoan     = 0xfcAf99650cF70763A3e14bbeE24a565d86F6bD1b;
    address icebreakerPoolV2            = 0x137F2EA5cfB0fE59408BAb2779E33EE868F1810E;
    address icebreakerPoolManager       = 0xC0323b64eF95E5698B30fEbD6A54BFD66ca2210E;
    address icebreakerLoanManager       = 0x7dCA0cd3F1eBAE3640AC4c66688A9d3A184aF822;
    address icebreakerWithdrawalManager = 0x4ec570457C3954feE01309A30C603ABD51899C77;
    address icebreakerPoolDelegateCover = 0xA198C1dc00297Ae477F2D42D5a9E1cd4a364191f;

}
