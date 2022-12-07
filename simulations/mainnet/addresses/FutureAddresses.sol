// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract FutureAddresses {

    /******************************************************************************************************************************/
    /*** Maple V1 Contracts                                                                                                     ***/
    /******************************************************************************************************************************/

    // TODO: unclear what this really is.
    address[] unorderedMigrationLoans = [
        0xfcAf99650cF70763A3e14bbeE24a565d86F6bD1b,
        0x132aCcE7BD6F8Ce8D4575Bf309E5055F5c70aC55,
        0x4165cb429CAEC4b1078C26A77DbE67d01E28cABb,
        0x163CF4362477c7eB3d7609C8a4d86051A4FE17b5
    ];

    /******************************************************************************************************************************/
    /*** Maple V2 Contracts                                                                                                     ***/
    /******************************************************************************************************************************/

    address loanV401Implementation;

    /******************************************************************************************************************************/
    /*** Maven 11 - USDC (Permissioned)                                                                                         ***/
    /******************************************************************************************************************************/

    address mavenPermissionedMigrationLoan     = 0x2224e35C0828C7eE4e7B011687961616Bc30f3dA;
    address mavenPermissionedPoolV2            = 0x9CFA4AbD53B359bAb5F83F428d2D679c71A136Bd;
    address mavenPermissionedPoolManager       = 0xB1F34F2Db96C39D7befb20fBE55908F14aaac90F;
    address mavenPermissionedLoanManager       = 0x736ab4BeFa3A9E9E73d94Ff3c39E0ed4418925c7;
    address mavenPermissionedWithdrawalManager = 0x794067c5d8df53D154E580d26d48B928a11C2381;
    address mavenPermissionedPoolDelegateCover = 0x161F93a5f526bdb4422D6589a178a2C12D12b8de;

    /******************************************************************************************************************************/
    /*** Maven 11 - USDC 01                                                                                                     ***/
    /******************************************************************************************************************************/

    address mavenUsdcMigrationLoan     = 0xEA1CaF3948A8649820a554186e37dBd431787fd9;
    address mavenUsdcPoolV2            = 0x07bFf372d96Ef9438e74425b8FFB67BFA07cccB1;
    address mavenUsdcPoolManager       = 0xa6B74a422e18FBBdbb2Ff0aFAdBDd433d6D46E54;
    address mavenUsdcLoanManager       = 0x03071a242d7776813E4EC25412B72dD5D6ceF678;
    address mavenUsdcWithdrawalManager = 0xae57d5F81dc126C95c09090E01Df4BC7CE7Eed69;
    address mavenUsdcPoolDelegateCover = 0x037DD1FCb1f1791F5f47B40b8E40D4D9d2e5d14C;

    /******************************************************************************************************************************/
    /*** Maven 11 - WETH                                                                                                        ***/
    /******************************************************************************************************************************/

    address mavenWethMigrationLoan     = 0xe7e41510F3b22Cad96C9A9cCdE7ABEfe200926d3;
    address mavenWethPoolV2            = 0xe09d10B512992AAb0d0f65d6dE65394328160C4A;
    address mavenWethPoolManager       = 0xa4F71F8e9a0E0365873C2a1aC736B29cd07B0D4B;
    address mavenWethLoanManager       = 0x0884457e58f989fB7927b8B48dd02e2AFe434794;
    address mavenWethWithdrawalManager = 0x1881E67BEfc48385c854Eb47581AE7CBbBA6C856;
    address mavenWethPoolDelegateCover = 0x5a63770E1ADAB97D74d7912d763E3034293DfdAa;

    /******************************************************************************************************************************/
    /*** Orthogonal Trading - USDC 01                                                                                           ***/
    /******************************************************************************************************************************/

    address orthogonalMigrationLoan     = 0x076f4579b7F35d5006732EE8e7a97D47Ee82EDB5;
    address orthogonalPoolV2            = 0xE2a335198aa8e50D32E2e6c26333CAA16959C7aD;
    address orthogonalPoolManager       = 0x8000A0d516e924e7757795B7D9b8A6579244258B;
    address orthogonalLoanManager       = 0x9f31Ab72A2c8E7E7A85f3620FDa21A0f21F3209c;
    address orthogonalWithdrawalManager = 0x88700b0A0af205c731a8595B9590731BCe00782c;
    address orthogonalPoolDelegateCover = 0xFa82E38872dc147130242616D8459039000c1958;

    /******************************************************************************************************************************/
    /*** Icebreaker Finance - USDC                                                                                              ***/
    /******************************************************************************************************************************/

    address icebreakerMigrationLoan     = 0x4b88a81425AA6a20A837d3817861112034B0Cd01;
    address icebreakerPoolV2            = 0x42bea539c35D145e73661d8f7d7813fd7357F58a;
    address icebreakerPoolManager       = 0xc4237Da460FB1a5530E5f8A3aB365B9344F7CD2E;
    address icebreakerLoanManager       = 0x5E81BF711B8cFc1883C9D7e634EcaD857d9aA82c;
    address icebreakerWithdrawalManager = 0x9C858eFbD33A27E8B5A8f1269889799e7538B89F;
    address icebreakerPoolDelegateCover = 0xEaDEf0c89b6A92E0895cc0AFfa4900c24d192134;

}
