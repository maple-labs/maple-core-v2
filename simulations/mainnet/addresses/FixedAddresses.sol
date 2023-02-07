// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract FixedAddresses {

    /**************************************************************************************************************************************/
    /*** Multisigs / EOAs                                                                                                               ***/
    /**************************************************************************************************************************************/

    address constant governor      = 0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;
    address constant mapleTreasury = 0xa9466EaBd096449d650D5AEB0dD3dA6F52FD0B19;
    address constant securityAdmin = 0x6b1A78C1943b03086F7Ee53360f9b0672bD60818;

    /**************************************************************************************************************************************/
    /*** Temporary Pool Delegate Multisigs                                                                                              ***/
    /**************************************************************************************************************************************/

    address constant mavenPermissionedTemporaryPd = 0xec67fd8445E9a84311E2BD118A21b2fDaACfc7FA;
    address constant mavenUsdcTemporaryPd         = 0xf11897A0009b3a37f15365A976015E7F22A16d50;
    address constant mavenWethTemporaryPd         = 0xbFA29AA894229d532D1aD1fd7e4226fce842632C;
    address constant orthogonalTemporaryPd        = 0x47c388644C7AA8736CA34e3Bfa0ee1F8284778c1;
    address constant icebreakerTemporaryPd        = 0x37c610584f7834A8FEb490b73E2aC780AEE31905;

    /**************************************************************************************************************************************/
    /*** Final Pool Delegate Multisigs                                                                                                  ***/
    /**************************************************************************************************************************************/

    address constant mavenPermissionedFinalPd = 0xab38A4E78a0549f60Df1A78f15f35F03F39f11F4;
    address constant mavenUsdcFinalPd         = 0x8B4aa04E9642b387293cE6fFfA42715a9cd19f3C;
    address constant mavenWethFinalPd         = 0x990d11977378D4610776e6646b2cAAe543Ea4EDA;
    address constant orthogonalFinalPd        = 0xA6cCb9483E3E7a737E3a4F5B72a1Ce51838ba122;
    address constant icebreakerFinalPd        = 0x184e46651946B861654436027bffdC97f9a45079;

    /**************************************************************************************************************************************/
    /*** Asset Contracts                                                                                                                ***/
    /**************************************************************************************************************************************/

    address constant mpl  = 0x33349B282065b0284d756F0577FB39c158F935e6;
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**************************************************************************************************************************************/
    /*** Asset Oracles                                                                                                                  ***/
    /**************************************************************************************************************************************/

    address constant btcUsdOracle = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address constant ethUsdOracle = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant usdUsdOracle = 0x5DC5E14be1280E747cD036c089C96744EBF064E7;

    /**************************************************************************************************************************************/
    /*** Maple V2 Contracts                                                                                                             ***/
    /**************************************************************************************************************************************/

    address constant mapleGlobalsV2Implementation = 0x0ad92cb3Fc4cd6697E0f14Fb75F3d7da3Bb2e056;
    address constant mapleGlobalsV2Proxy          = 0x804a6F5F667170F545Bf14e5DDB48C70B788390C;

    address constant feeManager = 0xFeACa6A5703E6F9DE0ebE0975C93AE34c00523F2;

    address constant poolDeployer = 0x9322fCbb9cf9F04728AD9CB62c80a12615FF9aDc;

    address constant liquidatorFactory        = 0xa2091116649b070D2a27Fc5C85c9820302114c63;
    address constant liquidatorImplementation = 0xe6a03Ba967172a1FF218FEE686445f444258021A;
    address constant liquidatorInitializer    = 0xED9D14F83eddd08572c403175FFf41c42a35a149;

    address constant loanManagerFactory                  = 0x1551717AE4FdCB65ed028F7fB7abA39908f6A7A6;
    address constant loanManagerImplementation           = 0x9303aed6231F131F8e61D579cb69aea4DF365F3D;
    address constant loanManagerInitializer              = 0x1cAddEC2A39232253D0a2424C21543f216284bf2;
    address constant transitionLoanManagerImplementation = 0x8057206A6C52e8d17e8c0EBE4C1Bb777d1876c8D;

    address constant poolManagerFactory        = 0xE463cD473EcC1d1A4ecF20b62624D84DD20a8339;
    address constant poolManagerImplementation = 0x09Fe53d404fBE13750047eCdB64Ec6aa6Fae46e6;
    address constant poolManagerInitializer    = 0x0B240bf499773905802eE4DE43f96407C436d549;

    address constant withdrawalManagerFactory        = 0xb9e25B584dc4a7C9d47aEF577f111fBE5705773B;
    address constant withdrawalManagerImplementation = 0xB12EC38e3508b0919fa989A0e60fde489b46F430;
    address constant withdrawalManagerInitializer    = 0x1063dCa836894b12f29003CA2899ff806A2B0B31;

    address constant loanFactory      = 0x36a7350309B2Eb30F3B908aB0154851B5ED81db0;
    address constant loanV400Migrator = 0xb4Be919810c6F4ce20b2D3cC221FD5D737B46C3E;

    address constant refinancer = 0xec90671c2c8f4cCBb6074938f893306a13402251;

    /**************************************************************************************************************************************/
    /*** Maven 11 - USDC (Permissioned)                                                                                                 ***/
    /**************************************************************************************************************************************/

    address constant mavenPermissionedPool              = 0x00e0C1ea2085e30E5233E98CFA940ca8cbB1b0b7;
    address constant mavenPermissionedPoolManager       = 0x24617612DeC91855e126e6330580425F6A262ee9;
    address constant mavenPermissionedLoanManager       = 0x6B6491AAa92Ce7e901330D8F91Ec99C2a157EBd7;
    address constant mavenPermissionedWithdrawalManager = 0x1B56856eB74bB1AA9e9F1997386dDB28DEf532eE;
    address constant mavenPermissionedPoolDelegateCover = 0x9e71Da2edaD3F8053C00b697362A365383e9c518;

    /**************************************************************************************************************************************/
    /*** Maven 11 - USDC 01                                                                                                             ***/
    /**************************************************************************************************************************************/

    address constant mavenUsdcPool              = 0xd3cd37a7299B963bbc69592e5Ba933388f70dc88;
    address constant mavenUsdcPoolManager       = 0x00d950A41a0d277ed91bF9fD366a5523FEF0371e;
    address constant mavenUsdcLoanManager       = 0x74CB3c1938A15e532CC1b465e3B641C2c7e40C2b;
    address constant mavenUsdcWithdrawalManager = 0x7ED195a0AE212D265511b0978Af577F59876C9BB;
    address constant mavenUsdcPoolDelegateCover = 0x9c74C5147653041239bb31C799c54767D9953f7D;

    /**************************************************************************************************************************************/
    /*** Maven 11 - WETH                                                                                                                ***/
    /**************************************************************************************************************************************/

    address constant mavenWethPool              = 0xFfF9A1CAf78b2e5b0A49355a8637EA78b43fB6c3;
    address constant mavenWethPoolManager       = 0x833A5c9Fc016a87419D21B10B64e24082Bd1e49d;
    address constant mavenWethLoanManager       = 0x373BDCf21F6a939713d5DE94096ffdb24A406391;
    address constant mavenWethWithdrawalManager = 0x1Bb73D6384ae73DA2101a4556a42eaB82803Ef3d;
    address constant mavenWethPoolDelegateCover = 0xdfDDE84b117f038785A2B1805B10D5C4d616dA08;

    /**************************************************************************************************************************************/
    /*** Orthogonal Trading - USDC 01                                                                                                   ***/
    /**************************************************************************************************************************************/

    address constant orthogonalPool              = 0x79400A2c9a5E2431419CaC98Bf46893c86E8bDd7;
    address constant orthogonalPoolManager       = 0xE10A065D15A6eCA69bb8A0063Fe57eDdb66999DF;
    address constant orthogonalLoanManager       = 0xFdC7541201aA6831A64F96582111cED633fA5078;
    address constant orthogonalWithdrawalManager = 0xD8f8BD488ba6DDF2a710f6C357a884fd1706981A;
    address constant orthogonalPoolDelegateCover = 0xb9Bae8c63593e51A296857AC4C150bae31a4e2c3;

    /**************************************************************************************************************************************/
    /*** Icebreaker Finance - USDC                                                                                                      ***/
    /**************************************************************************************************************************************/

    address constant icebreakerPool              = 0x137F2EA5cfB0fE59408BAb2779E33EE868F1810E;
    address constant icebreakerPoolManager       = 0xC0323b64eF95E5698B30fEbD6A54BFD66ca2210E;
    address constant icebreakerLoanManager       = 0x7dCA0cd3F1eBAE3640AC4c66688A9d3A184aF822;
    address constant icebreakerWithdrawalManager = 0x4ec570457C3954feE01309A30C603ABD51899C77;
    address constant icebreakerPoolDelegateCover = 0xA198C1dc00297Ae477F2D42D5a9E1cd4a364191f;

}
