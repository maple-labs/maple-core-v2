// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

contract FixedAddresses {

    /**************************************************************************************************************************************/
    /*** Multisigs / EOAs                                                                                                               ***/
    /**************************************************************************************************************************************/

    address constant deployer          = 0x632a45c25d2139E6B2745eC3e7D309dEf99f2b9F;
    address constant globalAdmin       = 0x93CC3E39C91cf93fd57acA416ed6fE66e8bdD573;
    address constant governor          = 0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;
    address constant mapleTreasury     = 0xa9466EaBd096449d650D5AEB0dD3dA6F52FD0B19;
    address constant migrationMultisig = 0x2AD93F308AA812961Ec412a08eD778F4f4933758;
    address constant securityAdmin     = 0x6b1A78C1943b03086F7Ee53360f9b0672bD60818;
    address constant tempGovernor      = 0x0D8b2C1F11c5f9cD51de6dB3b256C1e3b0800200;

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
    /*** Maple V1 Contracts                                                                                                             ***/
    /**************************************************************************************************************************************/

    address constant loanV300Initializer       = 0xfF2CE989b5b5881dB21f67cBe25145FFB053BCCd;
    address constant debtLockerV300Initializer = 0x3D01aE38be6D81BD7c8De0D5Cd558eAb3F4cb79b;

    address constant mapleGlobalsV1 = 0xC234c62c8C09687DFf0d9047e40042cd166F3600;

    address constant debtLockerFactory = 0xA83404CAA79989FfF1d84bA883a1b8187397866C;
    address constant loanFactory       = 0x36a7350309B2Eb30F3B908aB0154851B5ED81db0;

    /**************************************************************************************************************************************/
    /*** Maple V2 Contracts                                                                                                             ***/
    /**************************************************************************************************************************************/

    // NOTE: These are not constant as they can be (and have been) deployed by the simulation code.

    address mapleGlobalsV2Implementation = 0x0ad92cb3Fc4cd6697E0f14Fb75F3d7da3Bb2e056;
    address mapleGlobalsV2Proxy          = 0x804a6F5F667170F545Bf14e5DDB48C70B788390C;

    address feeManager = 0xFeACa6A5703E6F9DE0ebE0975C93AE34c00523F2;

    address poolDeployer = 0x9322fCbb9cf9F04728AD9CB62c80a12615FF9aDc;

    address liquidatorFactory        = 0xa2091116649b070D2a27Fc5C85c9820302114c63;
    address liquidatorImplementation = 0xe6a03Ba967172a1FF218FEE686445f444258021A;
    address liquidatorInitializer    = 0xED9D14F83eddd08572c403175FFf41c42a35a149;

    address loanManagerFactory                  = 0x1551717AE4FdCB65ed028F7fB7abA39908f6A7A6;
    address loanManagerImplementation           = 0x9303aed6231F131F8e61D579cb69aea4DF365F3D;
    address loanManagerInitializer              = 0x1cAddEC2A39232253D0a2424C21543f216284bf2;
    address transitionLoanManagerImplementation = 0x8057206A6C52e8d17e8c0EBE4C1Bb777d1876c8D;

    address poolManagerFactory        = 0xE463cD473EcC1d1A4ecF20b62624D84DD20a8339;
    address poolManagerImplementation = 0x09Fe53d404fBE13750047eCdB64Ec6aa6Fae46e6;
    address poolManagerInitializer    = 0x0B240bf499773905802eE4DE43f96407C436d549;

    address withdrawalManagerFactory        = 0xb9e25B584dc4a7C9d47aEF577f111fBE5705773B;
    address withdrawalManagerImplementation = 0xB12EC38e3508b0919fa989A0e60fde489b46F430;
    address withdrawalManagerInitializer    = 0x1063dCa836894b12f29003CA2899ff806A2B0B31;

    address loanV302Implementation = 0x608FA47Ff8bD47FC5EC8bfB36925E5Dbd4ede68d;
    address loanV400Initializer    = 0xDAa12dd385CbD04C60494efBbE8E757Ec1B649Ca;
    address loanV400Implementation = 0xe7Bd3cc389B2182E6eC350fa9c90670dD76c061c;
    address loanV400Migrator       = 0xb4Be919810c6F4ce20b2D3cC221FD5D737B46C3E;

    address debtLockerV400Migrator       = 0x5Bf3863b0355a547ecA79Ab489addd6092717431;
    address debtLockerV400Implementation = 0x4FB5AC98E33C3F5a4C7a51974A34e125d3F4E003;
    address debtLockerV401Implementation = 0xC8Eb6E241919430F2cb076338506Ed760d7bb9D3;

    address accountingChecker = 0x78da667CaADD8827690111BEBeCA875723fEAf7C;

    address deactivationOracle = 0xaF99aBBc5F12CE93C144733073A80c57e81296ab;

    address migrationHelperImplementation = 0xd8B74109916C0bBFDbE5e4345fF9584bDE47044a;
    address migrationHelperProxy          = 0x580B1A894b9FbdBf7d29Ba9b492807Bf539dD508;

    address refinancer = 0xec90671c2c8f4cCBb6074938f893306a13402251;

    /**************************************************************************************************************************************/
    /*** Maven 11 - USDC (Permissioned)                                                                                                 ***/
    /**************************************************************************************************************************************/

    address constant mavenPermissionedPoolV1      = 0xCC8058526De295c6aD917Cb41416366D69A24CdE;
    address constant mavenPermissionedRewards     = address(0);
    address constant mavenPermissionedStakeLocker = 0x15D297B15A631D1f3B53A337D31BDd2d950d5402;

    /**************************************************************************************************************************************/
    /*** Maven 11 - USDC 01                                                                                                             ***/
    /**************************************************************************************************************************************/

    address constant mavenUsdcPoolV1      = 0x6F6c8013f639979C84b756C7FC1500eB5aF18Dc4;
    address constant mavenUsdcRewards     = 0xe5A1cb65E7a608E778B3Ccb02F7B2DFeFeE783B4;
    address constant mavenUsdcStakeLocker = 0xbb7866435b8e5D3F6c2EA8b720c8F79db6f7C1b4;

    /**************************************************************************************************************************************/
    /*** Maven 11 - WETH                                                                                                                ***/
    /**************************************************************************************************************************************/

    address constant mavenWethPoolV1      = 0x1A066b0109545455BC771E49e6EDef6303cb0A93;
    address constant mavenWethRewards     = 0x0a76C7913C94F2AF16958FbDF9b4CF0bBdb159d8;
    address constant mavenWethStakeLocker = 0xD5Deeb06859369e42cf1906408eD6Cb249E0e002;

    /**************************************************************************************************************************************/
    /*** Orthogonal Trading - USDC 01                                                                                                   ***/
    /**************************************************************************************************************************************/

    address constant orthogonalPoolV1      = 0xFeBd6F15Df3B73DC4307B1d7E65D46413e710C27;
    address constant orthogonalRewards     = 0xf9D4D5a018d91e9BCCC1e35Ea78FcfEcF4c5Cbca;
    address constant orthogonalStakeLocker = 0x12B2BbBfAB2CE6789DF5659E9AC27A4A91C96C5C;

    /**************************************************************************************************************************************/
    /*** Icebreaker Finance - USDC                                                                                                      ***/
    /**************************************************************************************************************************************/

    address constant icebreakerPoolV1      = 0x733f56782d21b403E5Ee9c8343645E1535F73CD4;
    address constant icebreakerRewards     = address(0);
    address constant icebreakerStakeLocker = 0x1dC467a44aE188fc3eee41d88A32511D261e511B;

}
