// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console } from "../../contracts/Runner.sol";

import { DepositHandler }         from "./handlers/DepositHandler.sol";
import { DistributionHandler }    from "./handlers/DistributionHandler.sol";
import { FixedTermLoanHandler }   from "./handlers/FixedTermLoanHandler.sol";
import { QueueWithdrawalHandler } from "./handlers/QueueWithdrawalHandler.sol";
import { TransferHandler }        from "./handlers/TransferHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract WithdrawalManagerQueueInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_BORROWERS = 5;
    uint256 constant NUM_LPS       = 10;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        currentTimestamp = block.timestamp;

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.005e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        for (uint256 i; i < NUM_LPS; i++) {
            address lp = makeAddr(string(abi.encode("lp", i)));

            lps.push(lp);
            allowLender(address(poolManager), lp);
        }

        depositHandler         = new DepositHandler(address(pool), lps);
        transferHandler        = new TransferHandler(address(pool), lps);
        queueWithdrawalHandler = new QueueWithdrawalHandler(address(pool), lps);

        ftlHandler = new FixedTermLoanHandler({
            collateralAsset_:   address(collateralAsset),
            feeManager_:        address(fixedTermFeeManager),
            governor_:          governor,
            liquidatorFactory_: liquidatorFactory,
            loanFactory_:       fixedTermLoanFactory,
            poolManager_:       address(poolManager),
            refinancer_:        address(fixedTermRefinancer),
            testContract_:      address(this),
            numBorrowers_:      NUM_BORROWERS
        });

        depositHandler.setSelectorWeight("deposit(uint256)", 7_500);
        depositHandler.setSelectorWeight("mint(uint256)",    2_500);

        transferHandler.setSelectorWeight("transfer(uint256)", 10_000);

        queueWithdrawalHandler.setSelectorWeight("processRedemptions(uint256)",  3_000);
        queueWithdrawalHandler.setSelectorWeight("redeem(uint256)",              1_000);
        queueWithdrawalHandler.setSelectorWeight("removeRequest(uint256)",       1_000);
        queueWithdrawalHandler.setSelectorWeight("removeShares(uint256)",        1_000);
        queueWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)",       3_000);
        queueWithdrawalHandler.setSelectorWeight("setManualWithdrawal(uint256)", 1_000);

        ftlHandler.setSelectorWeight("createLoanAndFund(uint256)",           3_000);
        ftlHandler.setSelectorWeight("makePayment(uint256)",                 4_500);
        ftlHandler.setSelectorWeight("impairmentMakePayment(uint256)",       0);
        ftlHandler.setSelectorWeight("defaultMakePayment(uint256)",          0);
        ftlHandler.setSelectorWeight("impairLoan(uint256)",                  0);
        ftlHandler.setSelectorWeight("triggerDefault(uint256)",              0);
        ftlHandler.setSelectorWeight("finishCollateralLiquidation(uint256)", 0);
        ftlHandler.setSelectorWeight("warp(uint256)",                        2_000);
        ftlHandler.setSelectorWeight("refinance(uint256)",                   500);

        address[] memory targetContracts = new address[](4);
        targetContracts[0] = address(transferHandler);
        targetContracts[1] = address(depositHandler);
        targetContracts[2] = address(queueWithdrawalHandler);
        targetContracts[3] = address(ftlHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](4);
        weightsDistributorHandler[0] = 5;
        weightsDistributorHandler[1] = 10;
        weightsDistributorHandler[2] = 10;
        weightsDistributorHandler[3] = 75;

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);
    }

    /**************************************************************************************************************************************/
    /*** Loan Iteration Invariants (Loan and LoanManager)                                                                               ***/
    /**************************************************************************************************************************************/

    function test_regression_invariants() external {
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.warp(2651448593334189197796300393901400768744157612742);
        ftlHandler.makePayment(3);
        transferHandler.transfer(44084585907557174049702202);
        depositHandler.deposit(136373529589300936067602314774546823296);
        ftlHandler.makePayment(733473971885655803542771);
        queueWithdrawalHandler.redeem(2);
        ftlHandler.makePayment(2958739543);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        ftlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        ftlHandler.warp(43);
        ftlHandler.makePayment(112778153590521524281468168872711714336120559708544172470890085021834290266402);
        queueWithdrawalHandler.setManualWithdrawal(102676296956093196967689798);
        ftlHandler.warp(1215601259153822336655460);
        ftlHandler.warp(637773734265798865695705167371633742422439823929);
        queueWithdrawalHandler.requestRedeem(8096776871);
        queueWithdrawalHandler.removeRequest(39921508008554422087279078990713375588490505454528689987145882745838249485709);
        ftlHandler.makePayment(20652813);
        queueWithdrawalHandler.processRedemptions(755307395680478979981725);
        ftlHandler.makePayment(5226698442652576920134461712134210524595823495458199727315966751404416538);
        ftlHandler.createLoanAndFund(24788628919900386176801229828595231982107286895246478422946);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        ftlHandler.warp(3238031665781945704452605655);
        ftlHandler.createLoanAndFund(7620981245590993217822953284);
        transferHandler.transfer(32122836916929286444208614880374734336361490493);
        queueWithdrawalHandler.removeShares(3156074346986440029780928211);
        transferHandler.transfer(277429695954782275757355770);
        ftlHandler.createLoanAndFund(47032079959978851774081162777825642164543067913681978176631179517802268677612);
        ftlHandler.createLoanAndFund(22393866004590458916150);
        ftlHandler.createLoanAndFund(0);
        ftlHandler.createLoanAndFund(190821930463509911727972011);
        ftlHandler.makePayment(8773540047481084208042269118888107799700454207449380622867041466217311);
        transferHandler.transfer(990579808061243097715112733);
        ftlHandler.makePayment(3);
        ftlHandler.warp(2896199);
        depositHandler.deposit(2359);
        ftlHandler.makePayment(17889171980322705105);
        ftlHandler.createLoanAndFund(87142986557688823179531279926620923185614761216815615913994818011484459646107);
        queueWithdrawalHandler.redeem(2);
        ftlHandler.makePayment(34227244671475712);
        ftlHandler.warp(371027662832442187276831973);
        ftlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        depositHandler.deposit(55811535810268008137878);
        queueWithdrawalHandler.requestRedeem(1175883134526523436);
        ftlHandler.makePayment(2424466979502172499360146);
        ftlHandler.warp(11458);
        ftlHandler.makePayment(584);
        ftlHandler.createLoanAndFund(165767323221749);
        ftlHandler.makePayment(140131821086299033263231836848390);
        ftlHandler.warp(53742067261481233072962172117329306588492);
        ftlHandler.warp(24356143366506239482165832164778476716599295953464238077961380);
        ftlHandler.makePayment(57341942039841724390036785941587839086275570769408191255364);
        ftlHandler.makePayment(574364085760912413980429079);
        ftlHandler.createLoanAndFund(0);
        depositHandler.deposit(476407005748757933326350);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        ftlHandler.makePayment(8349199949);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        ftlHandler.warp(765650);
        queueWithdrawalHandler.redeem(2);
        ftlHandler.warp(792962953382601081769584669);
        transferHandler.transfer(1329402522559439286135907764529190851438931855424);
        ftlHandler.warp(487093866798735276841941);
        ftlHandler.makePayment(569004596);
        ftlHandler.warp(492640994810176672366608);
        ftlHandler.createLoanAndFund(0);
        ftlHandler.makePayment(7483745960221645837);
        ftlHandler.makePayment(10544508556965740168287945221711639058878007833751456935739526769188);
        ftlHandler.makePayment(18140344997453816852115511);
        ftlHandler.warp(999999);
        ftlHandler.createLoanAndFund(39625549395722308792656356320187558243525275752685688371527710);
        ftlHandler.createLoanAndFund(1250153342091033319151824284127505925077390);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.makePayment(3);
        ftlHandler.makePayment(992350137209064769087105581);
        ftlHandler.warp(1);
        ftlHandler.createLoanAndFund(0);
        queueWithdrawalHandler.redeem(2);
        ftlHandler.warp(22711384942568509269065878075266694199418260627687015321148568822605223559168);
        queueWithdrawalHandler.processRedemptions(11410983226912353086593761);
        ftlHandler.makePayment(494551992603360224084045);
        ftlHandler.createLoanAndFund(91472180513);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        ftlHandler.createLoanAndFund(0);
        ftlHandler.makePayment(11422727911);
        queueWithdrawalHandler.removeRequest(371367737082063494716131401);
        depositHandler.deposit(813558);
        ftlHandler.refinance(5005);
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        depositHandler.mint(3499882687926714715799217115191174894939203852338);
        transferHandler.transfer(1144);
        ftlHandler.makePayment(12602);
        ftlHandler.createLoanAndFund(1708861358);
        ftlHandler.warp(2803383687798699058993303268091135730331258822409036377);
        ftlHandler.warp(1);
        ftlHandler.refinance(4742486152971076509835864);
        ftlHandler.createLoanAndFund(933756865060523546165969015128816250427578012673689885154625206241875437);
        ftlHandler.makePayment(495758220120531058819084);
        depositHandler.deposit(32207139663155883120048342820633571940564984552969447746011924019223011601880);
        depositHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        ftlHandler.makePayment(8268442301849012671510282);
        ftlHandler.makePayment(3037373218858605724640);
        ftlHandler.makePayment(98689);
        ftlHandler.makePayment(47761231799860023509073401919298563860902219869954454);
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.createLoanAndFund(187940);
        ftlHandler.warp(138464111863165751636353258472633088129);
        ftlHandler.makePayment(145320878723712065983480854189072005247);
        ftlHandler.createLoanAndFund(0);
        ftlHandler.makePayment(131533275935532725586167345);
        ftlHandler.makePayment(87715990979603175306487487);
        ftlHandler.warp(217212341935994340423723114335579885891438513843296817);
        ftlHandler.makePayment(3);
        depositHandler.deposit(23154911895437217575003806434693591911041859851941700536851844474136964903225);
        transferHandler.transfer(90648921698402187451948481137079965107187594830722304);
        ftlHandler.warp(278327);
        transferHandler.transfer(31686338040267720173132697334576412642);
        ftlHandler.createLoanAndFund(73474930532017535474185504668232350767);
        ftlHandler.makePayment(3);
        ftlHandler.makePayment(1256496592979692302140789242);
        ftlHandler.createLoanAndFund(25464002929062423236321376941251);
        depositHandler.deposit(158889161730183905607787426944045703114319662119336707498623828492356);
        queueWithdrawalHandler.redeem(2);
        ftlHandler.warp(593225683954238585045093);
        ftlHandler.makePayment(3);
        ftlHandler.warp(1);
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.refinance(262288050167767906569615705368);
        ftlHandler.createLoanAndFund(0);
        ftlHandler.makePayment(6792943591114592423088564663197010123473875785678474043353);
        ftlHandler.createLoanAndFund(3455379931);
        ftlHandler.makePayment(6736627540590663134);
        ftlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        ftlHandler.makePayment(68627443803430104730961829);
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.makePayment(32567151308);
        ftlHandler.createLoanAndFund(105897359695112289399899723257391487145940963713227808646087267295306389461793);
        ftlHandler.createLoanAndFund(418526150697078103018864927);
        queueWithdrawalHandler.redeem(2);
        queueWithdrawalHandler.redeem(2);
        ftlHandler.makePayment(3);
        ftlHandler.createLoanAndFund(1520350055125342912432362999);
        ftlHandler.createLoanAndFund(36865505123136003729711975492129065482076166);
        queueWithdrawalHandler.requestRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.createLoanAndFund(0);
        queueWithdrawalHandler.redeem(37220577242812726089962530584315243837200644432766275364397005386524207950524);
    }

}
