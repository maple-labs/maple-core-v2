
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { AddressRegistry } from "../../contracts/Contracts.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract UpgradeAddressRegistryETH is AddressRegistry, UpgradeAddressRegistry {

    address[] aqruFixedTermLoans = [
        0x1F2bCA37106b30C4d72d8E60eBD2bFeAa10BFfE2,
        0x3E36372119f12DEe3De6C260CC7283557C24f471
    ];

    address[] aqruOpenTermLoans = [
        0x2603E1294aa3C1c7fC0A60E360D23936B6398b99,
        0x29356F80d6016583C03991Cda7Dd42259517c005,
        0x51d8cd0f68f3A9D4ab7Ce4062bc89B5C47A96818,
        0xf2FDA7D97CF9920E0857Ec60416eD0006ea610f9
    ];

    address[] aqruAllowedLenders = [
        0x375Efc656fdF7D9f14fA4b3270A338e7E60C24f0,
        0x18De7886eEaaEE78F358639aCD738018372b13BD,
        0xa0f75491720835b36edC92D06DDc468D201e9b73,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0xF1EE962fD7d4D3856E151Ef187AAa3aEfd1F85Fc,
        0xF97E42D65d09813F1765788Bb666488b8E9f4b0a,
        0xf0163143Ed4F65CEdC3fF7DB3A0B30A610088518,
        0x23620222db9a77D346A0A02aCe1126AcE4E6eeDF,
        0x4545bBD4c924B549DFB432358531a751b4670ec2,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x7d849D46BDD16914Af15f83E785101A5d3d5F187,
        0x8228719eA6dCc79b77d663F13af98684a637d3A0,
        0x281817A77a69513e5DEBD83c7028Aef41Bc8FE34,
        0x515f77Fc8E1473591a89181a2Cf6CD0AAf3f932d,
        0xd5597936dBBD1B31f70D7a2024409b7a4d032680,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xC09bD180ba12b837d4A0Ca163025FB5F8f86d711,
        0x4E922C39E7f3e4fe42C50e73dD133A5E2Aa57f74,
        0xB4eC6C18CD9DC4f3D1c378307D4bdDa18DdAe899,
        0xc6971260EfDfd0fFfC4fB6E9Fe18Faf2e2dE56d5,
        0xFafd604d1CC8b6B3B6CC859cF80Fd902972371C1,
        0xE3396E0C31bFfDf8A86A74B7f461C7A5cFdF5153,
        0x2D36a0131E3c90628230Ae9199943bE91D26836D,
        0xbdBfbB49EC9c1D18e2976062616d60e8d3126D7d,
        0xF1C28b21075A96a55E13c55240D37E7b1741D826,
        0xD49EeDbE1287C7C8d7a1906477de4184e7988dBD,
        0x08D64d365Bf7BF47869E0e5e95Ef07bFEbA6152a,
        0xa68d091ED63189D7792F549C91D02e770794b91B,
        0x8088561d2E8c5bCE1Fce07829aD8CfbCb710BfA0,
        0x5D7de07FD214f0Ad436E808B0fFe338fCa02043f,
        0x36cb763573813990DFaE2069c4dF4eefba3aec7F,
        0xEcae551d5f8B18AE4700fe13047979e5d7E1310e,
        0xd2a4B378D0A3cA10A1e0684201CBCB95bD203673,
        0xDa69Aa93787DCBe2938c247DAA67Ee96E5549C7b,
        0x0e3843a33072dB8f97ED2EA32fb9122a0B0B17e9,
        0xe83C69d9594118adA9f95AF629C989805a33c138,
        0xe26DFD1F9f5110f7Be8e37BEa98b1Ae18Bad0e4e,
        0x28D79103D8A4a9152023e7D4f5321bEA78f5BD24,
        0xc337C76158c131beDf95a5D4e0C27EC8eFdb7f02,
        0x5C33e4e0e7920fC8FA25A51c05D00a6FA87B4C5c,
        0xd06aD84C39CE95CA3C2c3285f08E10cB2B4A1A76,
        0x0aA726b70a79219A4F3127Bb1510bb05FE053AeC
    ];

    address[] cashManagementUSDCFixedTermLoans = [
        0xa6b5F3a55596fe8DF52Ca83Dd3aEaF7c2669a25B
    ];

    address[] cashManagementUSDCOpenTermLoans = [
        0xDA8f7941192590408DCe701A60FB3892455669Ce
    ];

    address[] cashManagementUSDCAllowedLenders = [
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xBbA4C8eB57DF16c4CfAbe4e9A3Ab697A3e0C65D8,
        0x86A07dDED024121b282362f4e7A249b00F5dAB37,
        0x3295B00134a1Ca31f2cFB7FB381644D289009407,
        0xaBbA936B9F2b47fC7A53894dEF00E903d6672c3c,
        0xbB432C675F74C784723c38eaFe216Cc62b3dC38D,
        0xDAeEA738e3D71C0FcB354c66101e9a0649Dc53e5,
        0x931250786dFd106B1E63C7Fd8f0d854876a45200,
        0x426B93769dac3357254fcae28a032Cef54870B4A,
        0x2B72D6b9D1E63547A2fE8aDD3D982F250ccD0b2a,
        0x6b7873Ba6D71D9c3478F8F9b1D6cE3fB3662C063,
        0x8e1Af86BAE17634884A2A1BAbcC99d922bC6455a,
        0x5a0F7dbDD1AB03ab5Bd35D9211a2f9DB4e1D3d42,
        0x184e46651946B861654436027bffdC97f9a45079,
        0x509b302E20b24e33710B51056A0f815808261181,
        0x186cf5714316F47BC59e30a850615A3f938d7D79,
        0xa931b486F661540c6D709aE6DfC8BcEF347ea437,
        0x2425809c5e907d46d0F1d1b25C8458A40368b3AD,
        0x1146691782c089bCF0B19aCb8620943a35eebD12,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x1Cb7F3EaB52BbE5F6635378b09d4856FB43FF7bE,
        0x3FeA230F9dc9Ca2e1AaA471E8E9E83e8a3212a97,
        0x3410bfe770C08457Ca29B5b69C39dB4A697AA892,
        0x82886Ad5e67d5142d44eD1449c2E41B988BFc0ab,
        0x93C740b81ce34958B7203C8e50bFBa335C36e7A7,
        0x675D786f754577825eA39d30708a709205A4ddbd,
        0xC09bD180ba12b837d4A0Ca163025FB5F8f86d711,
        0x9F902D8bcA07e4e5DC4A2Cfa84FF9393Aab15De5,
        0x3c81F398f059d75FdA0D2AF11D62EBA204FECf3D,
        0xFafd604d1CC8b6B3B6CC859cF80Fd902972371C1,
        0xc6971260EfDfd0fFfC4fB6E9Fe18Faf2e2dE56d5,
        0x938ca185a477868FbdC5AE29454a2Db5C32ae41F,
        0x0c59A28A17626c2D27D55e0CC074f2B7762C5b7a,
        0x99C941636A7E9fCF1FC3b27E142825cbBDC064d5,
        0x0bc6cC9B3C6EAb3f30595F0303Ce2c8f9F1F280A,
        0xab62Ce02Cc2ca53055e45cfD3B6a0d7768878eD3,
        0x281817A77a69513e5DEBD83c7028Aef41Bc8FE34,
        0x6a1485fB832e98fdBd839a116e187cfbC9065B9b,
        0x561df751FcD725908AA74f4f7d0D1Cb324f5BC95,
        0x08D64d365Bf7BF47869E0e5e95Ef07bFEbA6152a,
        0x28EC3d03eED0a770bb4943846549738cf78BD990,
        0xCb80a2D11412d1FEe1025DD2f12ac4FF92261662,
        0x92f30c6937df9e0445367d7f6250e895eB8a1324,
        0xD84C0427fA38E12B4ff9b3897EF0e7dab7251746,
        0x20E2Ce9dF7d90770DcdA675c953581593D09f155,
        0xfAE1655Ec8C6CFd5f1D5e8895842D13cFDFB3c6E,
        0x2C3C070ec5da505ed68F3BCA91dE961dB837F52b,
        0x486467BA5FCD74943a308D9A8900B8d6B6272Ad4,
        0x81dC033D52eCee7eF9eaCf63dc536889665F9f0C,
        0xe26DFD1F9f5110f7Be8e37BEa98b1Ae18Bad0e4e,
        0x5Db0dC77F6E1Ad9dd959c60Da0D6F39c75e1C2E5,
        0x699F9689786321ea59B4B3E7139514CE4C0604fc,
        0x5C33e4e0e7920fC8FA25A51c05D00a6FA87B4C5c,
        0x85b330c31C2FdE35Ca4B53c27EBFF8873B8E4aC1,
        0x9928C2751aff664Cec0a100F36bf2A31c5dcd8c7,
        0xd8FfCcacA136580308117fEac2dD0aCe7C67447D,
        0x35C18B4Ef07F3133a3E257A893BAc013eBCc113F,
        0xe79cC5853Ea333B6f71599E091a6ae5906B33f7B,
        0xa67F2d1833e7e57dBFB353FCb669c00d549e2A70,
        0xdA33A7fCE9998e9418744D72B6e8358dE06ABCfa,
        0x03969341cd113Fb53b18414673fa24200CAFeb66,
        0xdc21a6BfcBD5B520B59C0cED9fe8231278706045
    ];

    address[] cashManagementUSDTOpenTermLoans = [
        0xD7141b6cbCf155beABcCB2040Fa66fBD259A257B
    ];

    address[] cashManagementUSDTAllowedLenders = [
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0xF0A66F70064aD3198Abb35AAE26B1eeeaEa62C4B,
        0x675D786f754577825eA39d30708a709205A4ddbd,
        0x76Fd5E21650e0A179D79Eda03a08Cf97C1D56495
    ];

    address[] cicadaOpenTermLoans = [
        0x8405494208e2ea178aCeA0EDD6C1a76668e18a7D
    ];

    address[] cicadaAllowedLenders = [
        0xba5936d5D8E5b050159ff8Ccb2589309e3071c2a,
        0x4a5f63D9425070785EB10f5a0C33E42F16BB8639,
        0x3ED09d2Ba820c951b7A37e600F739526c5BEf924,
        0x8A25d8C9fa8C7A726137f2D618d85CbC2C083F78
    ];

    address[] icebreakerAllowedLenders = [
        0x009fDDE3E654Cb2495135708dc1590daeFb14Ea7,
        0x184e46651946B861654436027bffdC97f9a45079,
        0x221c7c5a448c87F6834818f255d28e5A8124C4A1,
        0x5c5d638a1f1e84621641dD847B8554A6F39770F3,
        0x4ec570457C3954feE01309A30C603ABD51899C77
    ];

    address[] laserAllowedLenders = [
        0xf817eC56Cb26117cf3bd5a8a8f128d64998fF234,
        0x859bEd48E556BFfB102373FCB96Df84bdC75965c
    ];

    address[] mapleDirectUSDCOpenTermLoans = [
        0x07BC04A9Bc791f469060dB77a123497c0AAB6F81,
        0xaa4F38aA3970A4dB0d268fafe2966E3F6a7fac5D
    ];

    address[] mapleDirectUSDCAllowedLenders = [
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0xC09bD180ba12b837d4A0Ca163025FB5F8f86d711,
        0x03f8be029796e9dDEED284a145B639F522074CE8,
        0x32D4a17CD6d4eEeD53cbD7A656decEe1f28BDCB6,
        0x344d092b718D3C1e95d1A0740a5A70d31CE816E2,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x9f412598c64585C2120849E76b8993948D175D0d,
        0xe0d744dBa5d301C5951d3DEe28623EBda5E88fa8,
        0x3410bfe770C08457Ca29B5b69C39dB4A697AA892,
        0xa931b486F661540c6D709aE6DfC8BcEF347ea437,
        0x0b3F0255a2B74392A60A1F4EdAD1345c2438D02e,
        0x251119e2938485018b3862b767f40879B00EB577,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x6E3fddab68Bf1EBaf9daCF9F7907c7Bc0951D1dc,
        0xEcae551d5f8B18AE4700fe13047979e5d7E1310e,
        0x329c2E91cD0db437021A70aa31C5E5a919125555,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xA7eFB5163163b07E75A5C1AC687D74b8bA68d3A0,
        0xB7ae6358ABA6E7a60C7B921B8Cbb3fddB3EE9060,
        0xfAbacb07863Bf43Cf9215b0787a924CaA438f674,
        0x2C3C070ec5da505ed68F3BCA91dE961dB837F52b,
        0xFcB342a846ACFaE23bf9533CC6afD3059d32F1CC,
        0xE0e37f5B35e653aE63B3D782A15b104cD834198b,
        0xc337C76158c131beDf95a5D4e0C27EC8eFdb7f02,
        0x28D79103D8A4a9152023e7D4f5321bEA78f5BD24,
        0x6D7F31cDbE68e947fAFaCad005f6495eDA04cB12,
        0x0c209Cc80faA42031484621788Ef97CB1A9C917e,
        0x9928C2751aff664Cec0a100F36bf2A31c5dcd8c7,
        0xdA33A7fCE9998e9418744D72B6e8358dE06ABCfa
    ];

    address[] mavenPermissionedFixedTermLoans = new address[](0);

    address[] mavenPermissionedAllowedLenders = [
        0x009fDDE3E654Cb2495135708dc1590daeFb14Ea7,
        0x219Fd48E2eF72b8b55C2E3Fe78614b350c06D6eB,
        0x2E46037a6b9720cd4fCb4498E65324908aBb8d30,
        0x584B52397A51eD108178970675c3D6622DF9B2bE,
        0x8C6d9F12C4624afBF4fdCB0892A0fA7e5e6F4412,
        0x9928C2751aff664Cec0a100F36bf2A31c5dcd8c7,
        0xe83C69d9594118adA9f95AF629C989805a33c138,
        0x1B56856eB74bB1AA9e9F1997386dDB28DEf532eE
    ];

    address[] mavenUsdc3AllowedLenders = [
        0x426B93769dac3357254fcae28a032Cef54870B4A,
        0x509b302E20b24e33710B51056A0f815808261181,
        0xf69EA6646cf682262E84cd7c67133eac59cef07b,
        0x0519bA35Ae9cE8A987BBA57f1B7D22fcFd8b7fA8,
        0x186cf5714316F47BC59e30a850615A3f938d7D79,
        0x5A154E4408Be554216a709E2C1637ef5ca141dD8,
        0x344d9C4f488bb5519D390304457D64034618145C,
        0x7F0d63e2250bC99f48985B183AF0c9a66BbC8ac3
    ];

    address[] mavenWethFixedTermLoans = new address[](0);

    address[] opportunisticHighYieldAllowedLenders = [
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0x40d739cD73fb4BBE90998321FA408e85e99C7868
    ];

    address[] opportunisticHighYieldOpenTermLoans = new address[](0);

    constructor() {
        // Set Protocol Contracts
        protocol.governor                    = governor;
        protocol.mapleTreasury               = mapleTreasury;
        protocol.operationalAdmin            = operationalAdmin;
        protocol.securityAdmin               = securityAdmin;
        protocol.mplv1                       = mplv1;
        protocol.xmpl                        = xmpl;
        protocol.usdc                        = usdc;
        protocol.fixedTermFeeManagerV1       = fixedTermFeeManagerV1;
        protocol.fixedTermLoanFactory        = fixedTermLoanFactory;
        protocol.fixedTermLoanManagerFactory = fixedTermLoanManagerFactory;
        protocol.fixedTermRefinancerV2       = fixedTermRefinancerV2;
        protocol.globals                     = globals;
        protocol.globalsImplementationV2     = globalsImplementationV2;
        protocol.liquidatorFactory           = liquidatorFactory;
        protocol.openTermLoanFactory         = openTermLoanFactory;
        protocol.openTermLoanManagerFactory  = openTermLoanManagerFactory;
        protocol.openTermRefinancerV1        = openTermRefinancerV1;
        protocol.poolDeployerV2              = poolDeployerV2;
        protocol.poolManagerFactory          = poolManagerFactory;
        protocol.withdrawalManagerFactory    = withdrawalManagerFactory;

        fixedTermLoanInitializerV500 = 0x8F596D2f57C26FB1CD22F25c9a686e38A62Ce137;

        protocol.assets.push(Asset({ asset: usdc, oracle: usdUsdOracle }));
        protocol.assets.push(Asset({ asset: wbtc, oracle: btcUsdOracle }));
        protocol.assets.push(Asset({ asset: weth, oracle: ethUsdOracle }));

        pools.push(Pool({
            name:                 "aqru",
            pool:                 aqruPool,
            poolManager:          aqruPoolManager,
            withdrawalManager:    aqruWithdrawalManager,
            fixedTermLoanManager: aqruFixedTermLoanManager,
            openTermLoanManager:  aqruOpenTermLoanManager,
            lps:                  aqruAllowedLenders,
            otLoans:              aqruOpenTermLoans,
            ftLoans:              aqruFixedTermLoans
        }));

        pools.push(Pool({
            name:                 "cashManagementUSDC",
            pool:                 cashManagementUSDCPool,
            poolManager:          cashManagementUSDCPoolManager,
            withdrawalManager:    cashManagementUSDCWithdrawalManager,
            fixedTermLoanManager: cashManagementUSDCFixedTermLoanManager,
            openTermLoanManager:  cashManagementUSDCOpenTermLoanManager,
            lps:                  cashManagementUSDCAllowedLenders,
            otLoans:              cashManagementUSDCOpenTermLoans,
            ftLoans:              cashManagementUSDCFixedTermLoans
        }));

        queueUpgradePools.push(1);

        pools.push(Pool({
            name:                 "cashManagementUSDT",
            pool:                 cashManagementUSDTPool,
            poolManager:          cashManagementUSDTPoolManager,
            withdrawalManager:    cashManagementUSDTWithdrawalManager,
            fixedTermLoanManager: cashManagementUSDTFixedTermLoanManager,
            openTermLoanManager:  cashManagementUSDTOpenTermLoanManager,
            lps:                  cashManagementUSDTAllowedLenders,
            otLoans:              cashManagementUSDTOpenTermLoans,
            ftLoans:              new address[](0)
        }));

        queueUpgradePools.push(2);

        pools.push(Pool({
            name:                 "cicada",
            pool:                 cicadaPool,
            poolManager:          cicadaPoolManager,
            withdrawalManager:    cicadaWithdrawalManager,
            fixedTermLoanManager: cicadaFixedTermLoanManager,
            openTermLoanManager:  cicadaOpenTermLoanManager,
            lps:                  cicadaAllowedLenders,
            otLoans:              cicadaOpenTermLoans,
            ftLoans:              new address[](0)
        }));

        pools.push(Pool({
            name:                 "icebreaker",
            pool:                 icebreakerPool,
            poolManager:          icebreakerPoolManager,
            withdrawalManager:    icebreakerWithdrawalManager,
            fixedTermLoanManager: icebreakerFixedTermLoanManager,
            openTermLoanManager:  address(0),
            lps:                  icebreakerAllowedLenders,
            otLoans:              new address[](0),
            ftLoans:              new address[](0)
        }));

        pools.push(Pool({
            name:                 "laser",
            pool:                 laserPool,
            poolManager:          laserPoolManager,
            withdrawalManager:    laserWithdrawalManager,
            fixedTermLoanManager: laserFixedTermLoanManager,
            openTermLoanManager:  laserOpenTermLoanManager,
            lps:                  laserAllowedLenders,
            otLoans:              new address[](0),
            ftLoans:              new address[](0)
        }));

        pools.push(Pool({
            name:                 "mapleDirectUSDC",
            pool:                 mapleDirectUSDCPool,
            poolManager:          mapleDirectUSDCPoolManager,
            withdrawalManager:    mapleDirectUSDCWithdrawalManager,
            fixedTermLoanManager: mapleDirectUSDCFixedTermLoanManager,
            openTermLoanManager:  mapleDirectUSDCOpenTermLoanManager,
            lps:                  mapleDirectUSDCAllowedLenders,
            otLoans:              mapleDirectUSDCOpenTermLoans,
            ftLoans:              new address[](0)
        }));

        pools.push(Pool({
            name:                 "mavenPermissioned",
            pool:                 mavenPermissionedPool,
            poolManager:          mavenPermissionedPoolManager,
            withdrawalManager:    mavenPermissionedWithdrawalManager,
            fixedTermLoanManager: mavenPermissionedFixedTermLoanManager,
            openTermLoanManager:  address(0),
            lps:                  mavenPermissionedAllowedLenders,
            otLoans:              new address[](0),
            ftLoans:              mavenPermissionedFixedTermLoans
        }));

        pools.push(Pool({
            name:                 "mavenUsdc3",
            pool:                 mavenUsdc3Pool,
            poolManager:          mavenUsdc3PoolManager,
            withdrawalManager:    mavenUsdc3WithdrawalManager,
            fixedTermLoanManager: mavenUsdc3FixedTermLoanManager,
            openTermLoanManager:  address(0),
            lps:                  mavenUsdc3AllowedLenders,
            otLoans:              new address[](0),
            ftLoans:              new address[](0)
        }));

        pools.push(Pool({
            name:                 "mavenUsdc",
            pool:                 mavenUsdcPool,
            poolManager:          mavenUsdcPoolManager,
            withdrawalManager:    mavenUsdcWithdrawalManager,
            fixedTermLoanManager: mavenUsdcFixedTermLoanManager,
            openTermLoanManager:  address(0),
            lps:                  new address[](0),
            otLoans:              new address[](0),
            ftLoans:              new address[](0)
        }));

        pools.push(Pool({
            name:                 "mavenWeth",
            pool:                 mavenWethPool,
            poolManager:          mavenWethPoolManager,
            withdrawalManager:    mavenWethWithdrawalManager,
            fixedTermLoanManager: mavenWethFixedTermLoanManager,
            openTermLoanManager:  address(0),
            lps:                  new address[](0),
            otLoans:              new address[](0),
            ftLoans:              mavenWethFixedTermLoans
        }));

        pools.push(Pool({
            name:                 "orthogonal",
            pool:                 orthogonalPool,
            poolManager:          orthogonalPoolManager,
            withdrawalManager:    orthogonalWithdrawalManager,
            fixedTermLoanManager: orthogonalFixedTermLoanManager,
            openTermLoanManager:  address(0),
            lps:                  new address[](0),
            otLoans:              new address[](0),
            ftLoans:              new address[](0)
        }));

        pools.push(Pool({
            name:                 "Opportunistic High Yield",
            pool:                 OpportunisticHighYieldPool,
            poolManager:          OpportunisticHighYieldPoolPoolManager,
            withdrawalManager:    OpportunisticHighYieldPoolWithdrawalManager,
            fixedTermLoanManager: OpportunisticHighYieldPoolFixedTermLoanManager,
            openTermLoanManager:  OpportunisticHighYieldPoolOpenTermLoanManager,
            lps:                  opportunisticHighYieldAllowedLenders,
            otLoans:              opportunisticHighYieldOpenTermLoans,
            ftLoans:              new address[](0)
        }));

        queueUpgradePools.push(12);
    }

}
