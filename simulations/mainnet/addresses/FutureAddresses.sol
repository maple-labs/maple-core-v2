// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract FutureAddresses {

    address[] unorderedMigrationLoans = [
        0xfcAf99650cF70763A3e14bbeE24a565d86F6bD1b,
        0x721A55F2972a46042991a946b60B548BeC31a65B,
        0x3F542d451344Ea0Cb58323d049033Fd46Ae56Ec3,
        0xF8d7Bcc836439BD8a9207630b6c3DC97D65f9269,
        0xE8aE93F16b56FEe7Bf1d222A3B328B11d9d1Ffb0
    ];

    /******************************************************************************************************************************/
    /*** Maple V2 Contracts                                                                                                     ***/
    /******************************************************************************************************************************/

    address loanV401Implementation;

    /******************************************************************************************************************************/
    /*** Maven 11 - USDC (Permissioned)                                                                                         ***/
    /******************************************************************************************************************************/

    address mavenPermissionedMigrationLoan     = 0x721A55F2972a46042991a946b60B548BeC31a65B;
    address mavenPermissionedPoolV2            = 0x6CD2b9Cb726c4aeEE17678C94B5b15efF28B5465;
    address mavenPermissionedPoolManager       = 0x64f1835caaF7579700225028EFD3fE6269ACbBEd;
    address mavenPermissionedLoanManager       = 0x05CC16452e9dc1026143A3808491d12f9Bf45B11;
    address mavenPermissionedWithdrawalManager = 0xFE3847457f41D29191b177B6fa662C78f3524068;
    address mavenPermissionedPoolDelegateCover = 0x4eA0434bB5265e8d13AB4F96bE14B9ED0Ae37983;

    /******************************************************************************************************************************/
    /*** Maven 11 - USDC 01                                                                                                     ***/
    /******************************************************************************************************************************/

    address mavenUsdcMigrationLoan     = 0x3F542d451344Ea0Cb58323d049033Fd46Ae56Ec3;
    address mavenUsdcPoolV2            = 0x9e01E88d125189B39b0DD0415166176e76D5d7A0;
    address mavenUsdcPoolManager       = 0xaC7B0f4367De0A0bAc86D894037aE61dbF45dD0d;
    address mavenUsdcLoanManager       = 0xBA7f48898b1ac0e1661c033BD08EC09AeDF183BA;
    address mavenUsdcWithdrawalManager = 0x597fe1acf32294F911C06cD8894A08CAEE763C23;
    address mavenUsdcPoolDelegateCover = 0xaCE40E3A605A13c55005678F99c3761d9716d0fb;

    /******************************************************************************************************************************/
    /*** Maven 11 - WETH                                                                                                        ***/
    /******************************************************************************************************************************/

    address mavenWethMigrationLoan     = 0xF8d7Bcc836439BD8a9207630b6c3DC97D65f9269;
    address mavenWethPoolV2            = 0x19DbAEF9C6fb471a24F92bc3C189ae8C2ebbC7D8;
    address mavenWethPoolManager       = 0xa3aBf146158AAa4bd402946fFC68742CdeF22cd8;
    address mavenWethLoanManager       = 0x821893613DEfE66999Bd8d7fEb56726567dfa8fE;
    address mavenWethWithdrawalManager = 0x4662b56A004D053306Fa9072B57cAA67C08F697e;
    address mavenWethPoolDelegateCover = 0x4E62c96Cf48E177556f06938cdf99Ee228B9415F;

    /******************************************************************************************************************************/
    /*** Orthogonal Trading - USDC 01                                                                                           ***/
    /******************************************************************************************************************************/

    address orthogonalMigrationLoan     = 0xE8aE93F16b56FEe7Bf1d222A3B328B11d9d1Ffb0;
    address orthogonalPoolV2            = 0x516aa6a7ceE5090495B89171e917E4d605D59147;
    address orthogonalPoolManager       = 0x44923d165a0043265f4Be2644BF8A267F75F05d3;
    address orthogonalLoanManager       = 0xC8e16BE1b7EAD76bE3B7B10BE45f21A7C30b2453;
    address orthogonalWithdrawalManager = 0x3753d1F59d6Fb8A1fe94D6200f25e7780d68aa80;
    address orthogonalPoolDelegateCover = 0xF2C1e6526133C4aC2aAaA4b743dC6F3d2eb0Afb6;

    /******************************************************************************************************************************/
    /*** Icebreaker Finance - USDC                                                                                              ***/
    /******************************************************************************************************************************/

    address icebreakerMigrationLoan     = 0xfcAf99650cF70763A3e14bbeE24a565d86F6bD1b;
    address icebreakerPoolV2            = 0x88C9a4899bE1c81299D876b73978Bf9980F5F6A8;
    address icebreakerPoolManager       = 0x0bd62656c15fEf2cDc15Df416e6A61c52Bdd38c6;
    address icebreakerLoanManager       = 0x5d3B3Ed716BA7B89d1851162732F52e119355394;
    address icebreakerWithdrawalManager = 0x7A7A3E4978D11A639a9F3dE554532c71547B55EF;
    address icebreakerPoolDelegateCover = 0xa39C4f30532FdD97f581083D35b33C5167bbcEd4;

}
