// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

contract UpgradeAddressRegistry is AddressRegistry {

    // Using deployer for strategies 0x14e289f19898a5c16AF00b81180C18A791Fa0979
    // Using deployer for DIL        0x89D70c5127035d7558df6594229d9868B643DC1a

    address newAaveStrategyImplementation  = 0xFc8F7F97165d446B02Cc95363d2cA31154BBe9F9;
    address newAaveStrategyInitializer     = 0x0d2dBb28B1c7d225132722FAdb2402E93A35c1Be;

    address newBasicStrategyImplementation = 0x7a1E281Ec29F3A861f211a28a23161762BD55B73;
    address newBasicStrategyInitializer    = 0x2b9aDDb5244548f126e59FA5483040efc102f69e;

    address newSkyStrategyImplementation   = 0xBBEe42621499005Ff0dDEF947BBDeFfBBeE77730;
    address newSkyStrategyInitializer      = 0x29199d071717c72baab50eEf9adD6736A18A1d1d;

    address newGlobalsImplementation = 0x9BeAbb1B6F3ad1DdB87b65148BA5Eb6102334956;

    address newPoolManagerInitializer    = 0xB33Bfa00E1d92fDaC5AeCB2976d6998C2ecca759;
    address newPoolManagerImplementation = 0xfE02Be1aD28EdFd8e3dD6F29C402B244C2A258B8;
    address newPoolDeployer              = 0xdaF005B31B10F33EE42cEB1A4b983434FE947488;

    address newFixedTermLoanImplementation = 0xe1714CEEB10683448E40bFE73c9F493662ff5b7e;
    address newFixedTermLoanInitializer    = 0xC43e722A0F9432609a96Df0cF1aFA99556532F18;
    address newOpenTermLoanImplementation  = 0xEeaDb66693d63cFCF3E4D942D2812D4aE9443Fc1;
    address newOpenTermLoanInitializer     = 0x9385A0F681c3D4b39c2780cD69777Dd97a681485;

    address borrowerActionsImplementation = 0x78c5f240A1150c3c2ebDBDe559d04a0418DFCFF3;
    address borrowerActionsProxy          = 0x70Eb188452DaA5f4662150E437B61dA148449E20;

    address securedLendingAaveStrategy = 0x87Aa770f610679DFC2553FB95fAc1B4d996BA1cd;
    address securedLendingSkyStrategy  = 0xe3eE1b26AF5396Cec45c8C3b4c4FD5136A2455CC;

    // Pool Delegates
    address aqruPoolDelegate              = 0x39DF355Ae51fDf17aE1a68D00F770701e9627A93;
    address cashUSDCPoolDelegate          = 0x94b8dcbe4c7841B54170925b67918a6312154C9c;
    address blueChipPoolDelegate          = 0x0984af3FcB364c1f30337F9aB453f876e7Ff6D0B;
    address highYieldCorpPoolDelegate     = 0xeb636FF0b27c2EE99731Cb0588DB6DB76DA6e06e;
    address highYieldCorpWETHPoolDelegate = 0x6d03aa567aE55FAd71Fd58D9A4ba44D9dc6aDc5f;
    address secureLendingPoolDelegate     = 0x8c6a34E2b9CeceE4a1fce672ba37e611B1AECebB;
    address syrupUSDCPoolDelegate         = 0xEe3cBEFF9dC14EC9710A643B7624C5BEaF20BCcb;
    address syrupUSDTPoolDelegate         = 0xE512aCb671cCE2c976B151DEC89f9aAf701Bb006;

    address[] poolDelegates = [
        aqruPoolDelegate,
        cashUSDCPoolDelegate,
        blueChipPoolDelegate,
        highYieldCorpPoolDelegate,
        highYieldCorpWETHPoolDelegate,
        secureLendingPoolDelegate,
        syrupUSDCPoolDelegate,
        syrupUSDTPoolDelegate
    ];

    address[] poolManagers = [
        aqruPoolManager,
        cashUSDCPoolManager,
        blueChipSecuredUSDCPoolManager,
        highYieldCorpUSDCPoolManager,
        highYieldCorpWETHPoolManager,
        securedLendingUSDCPoolManager,
        syrupUSDCPoolManager,
        syrupUSDTPoolManager,
        LendAndLongUSDC1PoolManager,
        LendAndLongUSDC2PoolManager
    ];

    // TODO: Populate and add the same data for other pools.
    address[] syrupUSDCAllowedLenders;
    address[] syrupUSDCFixedTermLoans;
    address[] syrupUSDCOpenTermLoans = [
        0x1637fC0B7E3Eb0A0d8d2576eA599cFa178276E49,
        0x20D4cce9e045c9948FF7b28A62394c4A4ab14303,
        0x40457B17772666C901f2Ebc16673Bd76BC5081B6,
        0x53ED2C82dc0E1E782e4c7e67e551F667319019D1,
        0x5B53d596CBf4a0e5d6438031Ea501d260b0d1eaF,
        0x6699C3B303CA08564069D9dcdE258Bc07F558D7D,
        0x9F0492fF1074aCa7aA0B9C66215e24c276f912a8,
        0xA3B8c8891E9c96452f9fF42598942eb36d6B8710,
        0xa69aDda903FEc32932EBbd753978773Cb7C33AA0,
        0xA828761E9EFaFA3A823ea562802Dd1CeFa1fAB7f,
        0xC9EE9f15a999Ad3903FEdB3d5aC298061eFaFb1D,
        0xdBE714A8b70F11B257436E7a870f7420432e9a64,
        0xFfe7d64b58daf8A1209566E14Fe699dc474c26D4
    ];

    address[] syrupUSDTAllowedLenders;
    address[] syrupUSDTFixedTermLoans;
    address[] syrupUSDTOpenTermLoans = [
        0x1C1412B76156D78273F6A922E90F28954C0265E9,
        0x2c18f990Cb29B8ea4b5eb8e927Ee7C0f71308f45,
        0x5494501C6e0664B85593eFC4EAe4a2Ac9daE5b81,
        0x85bbA5D3957706d61F3467332E11FdD1D0cD121e,
        0x9b55aee465D48285e0dE777975020A531b1dEDd5
    ];

    address[] aqruAllowedLenders;
    address[] aqruFixedTermLoans = [
        0x1F2bCA37106b30C4d72d8E60eBD2bFeAa10BFfE2,
        0x3E36372119f12DEe3De6C260CC7283557C24f471
    ];
    address[] aqruOpenTermLoans = [
        0x29356F80d6016583C03991Cda7Dd42259517c005,
        0x51d8cd0f68f3A9D4ab7Ce4062bc89B5C47A96818,
        0xf2FDA7D97CF9920E0857Ec60416eD0006ea610f9
    ];

    address[] cashUSDCAllowedLenders;
    address[] cashUSDCFixedTermLoans;
    address[] cashUSDCOpenTermLoans;

    address[] blueChipAllowedLenders;
    address[] blueChipFixedTermLoans;
    address[] blueChipOpenTermLoans = [
        0x492656f1D1deca03B255b776bCB537d6157816ae,
        0x4E9E3c5fEE726151E29121c1588259F4310B89ab,
        0x7D43bc35860b35519323d3Df65b35b38Fb048a19,
        0xbA782A156129E2d115FB0076Eb0F77e45aCe654B,
        0xC51ef20d4327010fa49Ade9FDEDE324dF7AfD600
    ];

    address[] highYieldCorpUSDCAllowedLenders;
    address[] highYieldCorpUSDCFixedTermLoans;
    address[] highYieldCorpUSDCOpenTermLoans = [
        0x02a8ECBCCc5bF0e6eD2fcd9546248D18061811e2,
        0x5CB3baE99e9A5809c52d7211f828d4F7289e0A1a
    ];

    address[] highYieldCorpWETHAllowedLenders;
    address[] highYieldCorpWETHFixedTermLoans;
    address[] highYieldCorpWETHOpenTermLoans = [
        0x4a7108D22081fA39158f4c4Ff8E36e77829A528D,
        0x81AFbEA65120823C5734e1B2BD2dD2F77364ed90,
        0xd6A1D866BD477522CB0FFA4A2d8D324A7a75F17F
    ];

    address[] securedLendingUSDCAllowedLenders;
    address[] securedLendingUSDCFixedTermLoans;
    address[] securedLendingUSDCOpenTermLoans = [
        0x01f172f2C6E8425BeC64E91971670ac12078629b,
        0x0236F317d1730B8412836c05c84E51e49A404360,
        0x15f65337ae0A7EEa82Fb8D0840ae7EAFFF00E3d2,
        0x2874d8d3256fC5f3B96B229C9CBB01004cF3EF16,
        0x6D995973F22C18Ce413870BC865f0AA73B2B8810,
        0x70AE22E0Ec81A656D405AA3972153Ec79f9Db1C3,
        0x869E450FD7c5239568b2a87964cF42Bf91D1C430,
        0x86e2ADbf90547DA902F273060C8b84C578719c24,
        0x96345886Bd48B4789CBE80C69233633D06c3986c,
        0x9eFCD695BC5261ec4CaDcc7CBA0a3D51B0AF1aE8,
        0xb4CB9affB100506600C79cC6D8834Cc0D93e9C36,
        0xce77f0ca51819baD7C2acF13eC1a36f39Ad40057,
        0xF55a06BB41E2D513Abb56E888d456912CCBa877b
    ];

}
