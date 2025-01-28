// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MapleAddressRegistryETH as AddressRegistry, Test } from "../../contracts/Runner.sol";
import { ProtocolActions }                                  from "../../contracts/ProtocolActions.sol";

import { IGlobals, IStrategyLike, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { FixedTermLoanHealthChecker } from "./FixedTermLoanHealthChecker.sol";
import { LPHealthChecker }            from "./LPHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "./OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "./ProtocolHealthChecker.sol";

import { ProtocolUpgradeBase } from "../protocol-upgrade/ProtocolUpgradeBase.sol";

contract HealthCheckerMainnetTests is ProtocolUpgradeBase, ProtocolActions {

    address[] cashManagementUSDCLps = [
        0x03969341cd113Fb53b18414673fa24200CAFeb66,
        0x08D64d365Bf7BF47869E0e5e95Ef07bFEbA6152a,
        0x184e46651946B861654436027bffdC97f9a45079,
        0x1Cb7F3EaB52BbE5F6635378b09d4856FB43FF7bE,
        0x1d45Da02C4E3A8Bf8231d00A468b785a27B6A632,
        0x2205Ff403F6862f4743dFF88D443facdE555bD6A,
        0x2425809c5e907d46d0F1d1b25C8458A40368b3AD,
        0x28EC3d03eED0a770bb4943846549738cf78BD990,
        0x2B72D6b9D1E63547A2fE8aDD3D982F250ccD0b2a,
        0x3295B00134a1Ca31f2cFB7FB381644D289009407,
        0x3410bfe770C08457Ca29B5b69C39dB4A697AA892,
        0x3A4Af8FCfF689A7d65Ef0E323dFD2AeaD6Bc79d4,
        0x3c81F398f059d75FdA0D2AF11D62EBA204FECf3D,
        0x3Dbf6688842a4a5EE4C489716d9c238f39143c4E,
        0x3FeA230F9dc9Ca2e1AaA471E8E9E83e8a3212a97,
        0x426B93769dac3357254fcae28a032Cef54870B4A,
        0x486467BA5FCD74943a308D9A8900B8d6B6272Ad4,
        0x49370D3AeA5d15067C723B5Cd3D21133Cb26Df84,
        0x509b302E20b24e33710B51056A0f815808261181,
        0x561df751FcD725908AA74f4f7d0D1Cb324f5BC95,
        0x5a0F7dbDD1AB03ab5Bd35D9211a2f9DB4e1D3d42,
        0x5Db0dC77F6E1Ad9dd959c60Da0D6F39c75e1C2E5,
        0x62f6F61649cD314ADE2A7deF7542a62d59a1fA92,
        0x675D786f754577825eA39d30708a709205A4ddbd,
        0x68a0691EacF2AC4cae15c73349b44c0D350Efd58,
        0x6a1485fB832e98fdBd839a116e187cfbC9065B9b,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x6b7873Ba6D71D9c3478F8F9b1D6cE3fB3662C063,
        0x6c2D8c9dF5DBc0459920CD176F3F487F3F8bFFf8,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x82886Ad5e67d5142d44eD1449c2E41B988BFc0ab,
        0x85b330c31C2FdE35Ca4B53c27EBFF8873B8E4aC1,
        0x86A07dDED024121b282362f4e7A249b00F5dAB37,
        0x905B703b74790d4b4F3C2Bbf15d0F64D92760B08,
        0x913781bb4D9859cfe15734F4187849FCDA5d4F88,
        0x938ca185a477868FbdC5AE29454a2Db5C32ae41F,
        0x93C740b81ce34958B7203C8e50bFBa335C36e7A7,
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0x99C941636A7E9fCF1FC3b27E142825cbBDC064d5,
        0x9D9588c082634fD4C7f54cb0243D6792CfD7B4C4,
        0xa931b486F661540c6D709aE6DfC8BcEF347ea437,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xb7848eeAAd5D44C50D0b7bf8e7d0F8afB892fB44,
        0xbB432C675F74C784723c38eaFe216Cc62b3dC38D,
        0xBbA4C8eB57DF16c4CfAbe4e9A3Ab697A3e0C65D8,
        0xC09bD180ba12b837d4A0Ca163025FB5F8f86d711,
        0xc6971260EfDfd0fFfC4fB6E9Fe18Faf2e2dE56d5,
        0xc6E1253182fF864b22dB3618558668597aCf8AEF,
        0xcc2dA207373347D426cE789b9114512F6ac6E4C8,
        0xd8FfCcacA136580308117fEac2dD0aCe7C67447D,
        0xda973A9E08ddE843E324EeD76dBe262EB3F2Da65,
        0xdc21a6BfcBD5B520B59C0cED9fe8231278706045,
        0xdf998bec7943aa893ba8542eE57ea47b78F29007,
        0xe0081BbC8B328AcEf69aac8DF5fDFBDde87376ac,
        0xe79cC5853Ea333B6f71599E091a6ae5906B33f7B,
        0xeDA8288ACb0346017323F7f2338221F3d6416B64,
        0x0000000000000000000000000000000000000000,  // bootstrap mint
        0x1146691782c089bCF0B19aCb8620943a35eebD12
    ];

    address[] mapleDirectUSDCLps = [
        0x009fDDE3E654Cb2495135708dc1590daeFb14Ea7,
        0x0a6a7FECCe6D5B2d1B302cA419255f79bB2fa0c1,
        0x0b3F0255a2B74392A60A1F4EdAD1345c2438D02e,
        0x0c209Cc80faA42031484621788Ef97CB1A9C917e,
        0x10CbbfeacF0d228b2c86EbEA57f24f7eA070A9E2,
        0x160834291e67Aa55F830062cA8a47186b5E319A9,
        0x19416a1e6f6E13E483544B5341Ecc475F377CDeb,
        0x1e0c1fa876E27ACB4D9FeF764FACcB8e5C734227,
        0x24325aCc8BaAeB8ebd55A3b71DAB5778d69Def2a,
        0x251119e2938485018b3862b767f40879B00EB577,
        0x27E851AF8102EE138e03b4c74d4AA971fd662664,
        0x2DF3E5f257E53d09933122B81cC52920721b2fB4,
        0x329c2E91cD0db437021A70aa31C5E5a919125555,
        0x33cEA221D7559Be56b1978f8E1C7758157433AA2,
        0x3410bfe770C08457Ca29B5b69C39dB4A697AA892,
        0x486467BA5FCD74943a308D9A8900B8d6B6272Ad4,
        0x49370D3AeA5d15067C723B5Cd3D21133Cb26Df84,
        0x4ad27aD1fB2001966A6899De262Ce5b25836D1B3,
        0x578737B53a59d1871b65F723DF3ca0Eb03070113,
        0x5Db0dC77F6E1Ad9dd959c60Da0D6F39c75e1C2E5,
        0x5Ee3c2636F743203b1326adFe29da7Df04e0aa4B,
        0x62f6F61649cD314ADE2A7deF7542a62d59a1fA92,
        0x632Fe51412476A59b197b5675971fD6E46517269,
        0x6860CE1cdb3bF73069129B8f752D8eb92Ae89Afb,
        0x68a0691EacF2AC4cae15c73349b44c0D350Efd58,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x6c2D8c9dF5DBc0459920CD176F3F487F3F8bFFf8,
        0x6D7F31cDbE68e947fAFaCad005f6495eDA04cB12,
        0x6E3fddab68Bf1EBaf9daCF9F7907c7Bc0951D1dc,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x7991e793aE225CE0fe11225a6607bCB8B5E744de,
        0x7BB27CD06a35dBdC0EEad109F1f267d26F35f5e3,
        0x7dFf12833a6f0e88f610E79E11E9506848cCF187,
        0x80F5f4D70038d058982e0355570E6Ceb31CcD2aD,
        0x834859aaeB5CadD190488044F9a944086A4AA8c3,
        0x8412DE6289eaee8a8627BA1Abd1a6D8F1042f1D2,
        0x85101bbcBbF09cD50d299f662448C3Ae509592Ee,
        0x85893D4302Be300a858c8a01126e137ae28c9cbb,
        0x8E8192b98a4B1179cd1b5a18536a29d4844A928B,
        0x905B703b74790d4b4F3C2Bbf15d0F64D92760B08,
        0x913781bb4D9859cfe15734F4187849FCDA5d4F88,
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0x9928C2751aff664Cec0a100F36bf2A31c5dcd8c7,
        0x9D9588c082634fD4C7f54cb0243D6792CfD7B4C4,
        0x9f412598c64585C2120849E76b8993948D175D0d,
        0xA204D66c93Ab698a7C944fd391875CCCD27E55B3,
        0xa4D668Ae66351F56784455f20EA9d139893ecd72,
        0xA7eFB5163163b07E75A5C1AC687D74b8bA68d3A0,
        0xa931b486F661540c6D709aE6DfC8BcEF347ea437,
        0xAAEB9dA5593FFb28ee1861f0ed64F7600C3F9C6D,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xC09bD180ba12b837d4A0Ca163025FB5F8f86d711,
        0xc337C76158c131beDf95a5D4e0C27EC8eFdb7f02,
        0xC5e8bd5E0AD8C7Adb4Cb55C5c20fb06B5a5694CF,
        0xd3340fc6Eb424272E445765Ea601Fa78907Af75E,
        0xd785c4977851F00e1c0BfFe2A5f7Ed55A49dF4F0,
        0xdf998bec7943aa893ba8542eE57ea47b78F29007,
        0xE0e37f5B35e653aE63B3D782A15b104cD834198b,
        0xe11f21a9eC6B5EA66129AF641103e9D81405d821,
        0xe26DFD1F9f5110f7Be8e37BEa98b1Ae18Bad0e4e,
        0xeDA8288ACb0346017323F7f2338221F3d6416B64,
        0xF0D0bd97eE80A97cb2FD2A9E070E0B93913e8C75,
        0xf402539a0b609914A8cebB24d7e92CA0319624B1,
        0x0000000000000000000000000000000000000000  // bootstrap mint
    ];

    FixedTermLoanHealthChecker fixedTermHC;
    LPHealthChecker            lpHealthChecker_;
    OpenTermLoanHealthChecker  openTermHC;
    ProtocolHealthChecker      protocolHealthChecker_;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21229159);

        upgradeProtocol();

        lpHealthChecker_       = new LPHealthChecker();
        protocolHealthChecker_ = new ProtocolHealthChecker();
    }

    function testFork_lpHealthChecker_mainnet() public {
        _checkLPInvariants(cashUSDCPoolManager, cashManagementUSDCLps);
        _checkLPInvariants(blueChipSecuredUSDCPoolManager, mapleDirectUSDCLps);
    }

    function testFork_protocolHealthChecker_mainnet() public {
        _checkProtocolInvariants(cashUSDCPoolManager);
        _checkProtocolInvariants(blueChipSecuredUSDCPoolManager);
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _checkProtocolInvariants(address poolManager_) internal {
        ProtocolHealthChecker.Invariants memory results;

        results = protocolHealthChecker_.checkInvariants(poolManager_);

        assertTrue(results.fixedTermLoanManagerInvariantA);
        assertTrue(results.fixedTermLoanManagerInvariantB);
        assertTrue(results.fixedTermLoanManagerInvariantF);
        assertTrue(results.fixedTermLoanManagerInvariantI);
        assertTrue(results.fixedTermLoanManagerInvariantJ);
        assertTrue(results.fixedTermLoanManagerInvariantK);
        assertTrue(results.openTermLoanManagerInvariantE);
        assertTrue(results.openTermLoanManagerInvariantG);
        assertTrue(results.poolInvariantA);
        assertTrue(results.poolInvariantD);
        assertTrue(results.poolInvariantE);
        assertTrue(results.poolInvariantI);
        assertTrue(results.poolInvariantJ);
        assertTrue(results.poolInvariantK);
        assertTrue(results.poolManagerInvariantA);
        assertTrue(results.poolManagerInvariantB);
        assertTrue(results.poolPermissionManagerInvariantA);
        assertTrue(results.withdrawalManagerCyclicalInvariantC);
        assertTrue(results.withdrawalManagerCyclicalInvariantD);
        assertTrue(results.withdrawalManagerCyclicalInvariantE);
        assertTrue(results.withdrawalManagerCyclicalInvariantM);
        assertTrue(results.withdrawalManagerCyclicalInvariantN);
        assertTrue(results.withdrawalManagerQueueInvariantA);
        assertTrue(results.withdrawalManagerQueueInvariantB);
        assertTrue(results.withdrawalManagerQueueInvariantD);
        assertTrue(results.withdrawalManagerQueueInvariantE);
        assertTrue(results.withdrawalManagerQueueInvariantF);
        assertTrue(results.withdrawalManagerQueueInvariantI);
        assertTrue(results.strategiesInvariantA);
        assertTrue(results.strategiesInvariantB);
        assertTrue(results.strategiesInvariantC);
        assertTrue(results.strategiesInvariantD);
        assertTrue(results.strategiesInvariantE);
        assertTrue(results.strategiesInvariantF);
        assertTrue(results.strategiesInvariantG);
    }

    function _checkLPInvariants(address poolManager_, address[] memory lenders_) internal {
        LPHealthChecker.Invariants memory results;

        results = lpHealthChecker_.checkInvariants(poolManager_, lenders_);

        assertTrue(results.poolInvariantB);
        assertTrue(results.poolInvariantG);
        assertTrue(results.withdrawalManagerCyclicalInvariantA);
        assertTrue(results.withdrawalManagerCyclicalInvariantB);
        assertTrue(results.withdrawalManagerCyclicalInvariantF);
        assertTrue(results.withdrawalManagerCyclicalInvariantG);
        assertTrue(results.withdrawalManagerCyclicalInvariantH);
        assertTrue(results.withdrawalManagerCyclicalInvariantI);
        assertTrue(results.withdrawalManagerCyclicalInvariantJ);
        assertTrue(results.withdrawalManagerCyclicalInvariantK);
        assertTrue(results.withdrawalManagerCyclicalInvariantL);
        assertTrue(results.withdrawalManagerQueueInvariantC);
        assertTrue(results.withdrawalManagerQueueInvariantG);
        assertTrue(results.withdrawalManagerQueueInvariantH);
    }

}

contract StrategiesHealthCheckerTests is ProtocolUpgradeBase, ProtocolActions {

    ProtocolHealthChecker protocolHealthChecker_;

    IStrategyLike aaveStrategy;
    IStrategyLike skyStrategy;

    address strategyManager = makeAddr("strategyManager");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21229159);

        upgradeProtocol();

        protocolHealthChecker_ = new ProtocolHealthChecker();

        deposit(syrupUSDCPool, makeAddr("depositor"), 2_000_000e6);

        aaveStrategy = IStrategyLike(IPoolManager(syrupUSDCPoolManager).strategyList(2));
        skyStrategy  = IStrategyLike(IPoolManager(syrupUSDCPoolManager).strategyList(3));

        vm.startPrank(governor);
        IGlobals(globals).setValidInstanceOf("STRATEGY_MANAGER", strategyManager, true);
        aaveStrategy.setStrategyFeeRate(0.01e6);
        skyStrategy.setStrategyFeeRate(0.01e6);
        vm.stopPrank();
    }

    function testFork_protocolHealthChecker_strategiesMainnet_unfunded() public view {
        protocolHealthChecker_.checkInvariants(syrupUSDCPoolManager);
    }

    function testFork_protocolHealthChecker_strategiesMainnet_funded() public {
        vm.startPrank(strategyManager);
        aaveStrategy.fundStrategy(1_000_000e6);
        skyStrategy.fundStrategy(1_000_000e6);
        vm.stopPrank();

        protocolHealthChecker_.checkInvariants(syrupUSDCPoolManager);
    }

    function testFork_protocolHealthChecker_strategiesMainnet_ongoing() public {
        vm.startPrank(strategyManager);
        aaveStrategy.fundStrategy(1_000_000e6);
        skyStrategy.fundStrategy(1_000_000e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);

        protocolHealthChecker_.checkInvariants(syrupUSDCPoolManager);
    }

    function testFork_protocolHealthChecker_strategiesMainnet_impaired() public {
        vm.startPrank(governor);
        aaveStrategy.impairStrategy();
        skyStrategy.impairStrategy();
        vm.stopPrank();

        protocolHealthChecker_.checkInvariants(syrupUSDCPoolManager);
    }

    function testFork_protocolHealthChecker_strategiesMainnet_inactive() public {
        vm.startPrank(governor);
        aaveStrategy.deactivateStrategy();
        skyStrategy.deactivateStrategy();
        vm.stopPrank();

        protocolHealthChecker_.checkInvariants(syrupUSDCPoolManager);
    }
    
}
