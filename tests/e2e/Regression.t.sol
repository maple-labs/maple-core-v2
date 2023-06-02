// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2, StdStyle } from "../../modules/forge-std/src/Test.sol";

import { IOpenTermLoan, IOpenTermLoanManager, ILoanLike, ILoanManagerLike } from "../../contracts/interfaces/Interfaces.sol";

import { BaseInvariants }       from "../invariants/BaseInvariants.t.sol";
import { FixedTermLoanHandler } from "../invariants/handlers/FixedTermLoanHandler.sol";
import { LpHandler }            from "../invariants/handlers/LpHandler.sol";
import { OpenTermLoanHandler }  from "../invariants/handlers/OpenTermLoanHandler.sol";

contract RegressionTest is BaseInvariants {

    uint256 constant NUM_LPS       = 10;
    uint256 constant NUM_OT_LOANS  = 50;
    uint256 constant NUM_BORROWERS = 5;

    uint256 oldDiff;

    // NOTE: Refer to specific invariant test suite for setup.
    function setUp() public override {
        super.setUp();

        currentTimestamp = block.timestamp;

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager),    0.025e6);
        globals.setPlatformManagementFeeRate(address(poolManager), 0.08e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setDelegateManagementFeeRate(0.02e6);

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

        lpHandler = new LpHandler(address(pool), address(this), NUM_LPS);

        otlHandler = new OpenTermLoanHandler({
            loanFactory_:       address(openTermLoanFactory),
            liquidatorFactory_: address(liquidatorFactory),
            poolManager_:       address(poolManager),
            refinancer_:        address(openTermRefinancer),
            maxBorrowers_:      NUM_BORROWERS,
            maxLoans_:          NUM_OT_LOANS
        });
    }

    function payOffAllLoans() internal {
        IOpenTermLoan[] memory loans_ = _getActiveLoans();

        for (uint256 i; i < loans_.length; ++i) {
            makePaymentOT(address(loans_[i]), loans_[i].principal());
        }
    }

    function logDiff() internal view {
        IOpenTermLoan[] memory loans_ = _getActiveLoans();

        uint256 assetsUnderManagement = IOpenTermLoanManager(otlHandler.loanManager()).assetsUnderManagement();
        uint256 expectedAssetsUnderManagement;
        uint256 expectedNetInterestFromLoans;

        for (uint256 i; i < loans_.length; ++i) {
            expectedAssetsUnderManagement += loans_[i].principal() + _getExpectedNetInterest(loans_[i]);
            expectedNetInterestFromLoans  += _getExpectedNetInterest(loans_[i]);
        }

        bool isLoanManagerDiffLarger = assetsUnderManagement > expectedAssetsUnderManagement;

        uint256 diff = isLoanManagerDiffLarger ?
            assetsUnderManagement - expectedAssetsUnderManagement : expectedAssetsUnderManagement - assetsUnderManagement;

        console2.log(StdStyle.blue("Global Issuance Rate:"));
        console2.log(StdStyle.red(IOpenTermLoanManager(otlHandler.loanManager()).issuanceRate()));
        console2.log(StdStyle.blue("Number of active loans:"));
        console2.log(StdStyle.red(loans_.length));
        console2.log(StdStyle.blue("Assets under management:"));
        console2.log(StdStyle.red(assetsUnderManagement));
        console2.log(StdStyle.blue("Expected assets under management:"));
        console2.log(StdStyle.red(expectedAssetsUnderManagement));
        console2.log(StdStyle.blue("Expected net interest from loans:"));
        console2.log(StdStyle.red(expectedNetInterestFromLoans));
        console2.log(StdStyle.blue("Difference:"));
        console2.log(StdStyle.red(diff));
        console2.log(StdStyle.blue("Is loan manager diff larger:"));
        console2.log(isLoanManagerDiffLarger ? StdStyle.red(isLoanManagerDiffLarger) : StdStyle.green(isLoanManagerDiffLarger));
        console2.log(StdStyle.blue("Days passed since domain start:"));
        console2.log((StdStyle.red(uint256(block.timestamp - IOpenTermLoanManager(otlHandler.loanManager()).domainStart()) / 1 days)));
    }

    function test_otlRegression() public {
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        lpHandler.deposit(37230);
        otlHandler.warp(444);
        otlHandler.makePayment(16820);
        otlHandler.makePayment(1449186);
        otlHandler.makePayment(0);
        otlHandler.makePayment(0);
        otlHandler.fundLoan(835);
        otlHandler.makePayment(1365998840033571824481974103141740116125631577633824862305892924444);
        otlHandler.warp(1780);
        otlHandler.makePayment(21432);
        lpHandler.deposit(791031467928650554060703759706006429102798358040200590752928077066);
        otlHandler.warp(1045783029026893055576610146241884003552843);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        lpHandler.deposit(6895);
        lpHandler.deposit(3225);
        otlHandler.warp(190806465596142592322229921690);
        lpHandler.deposit(473549218811194597482283798984124019586313262098827526160);
        otlHandler.makePayment(990820977698218981342347752028);
        otlHandler.warp(60638527362160719765195414149508);
        otlHandler.makePayment(10366);
        otlHandler.fundLoan(11809735);
        otlHandler.warp(3);
        otlHandler.warp(2474150870481426202791821565713220264833919967376839514947215907355958927698);
        otlHandler.warp(6266995492697844742948334107);
        otlHandler.makePayment(19212);
        otlHandler.makePayment(392);
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        lpHandler.deposit(23448);
        lpHandler.deposit(23069);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        otlHandler.warp(7431);
        otlHandler.warp(350856977337102308613052635060);
        otlHandler.makePayment(20281);
        otlHandler.makePayment(0);
        otlHandler.fundLoan(2067194811715099453568056790963870903271317930973339);
        lpHandler.deposit(22616);
        otlHandler.fundLoan(113644145843999865459519967922657712404284833385708043106264899265606206182537);
        otlHandler.fundLoan(2);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.makePayment(224406437066946391148810);
        otlHandler.makePayment(0);
        otlHandler.makePayment(24801487006324158128484454);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        otlHandler.warp(3886);
        otlHandler.makePayment(1386);
        otlHandler.makePayment(21152);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.fundLoan(8860);
        otlHandler.makePayment(5848);
        lpHandler.deposit(1339444193388);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.makePayment(0);
        lpHandler.deposit(2042);
        otlHandler.fundLoan(10701);
        otlHandler.warp(20568);
        lpHandler.deposit(20168);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.makePayment(0);
        otlHandler.fundLoan(2);
        lpHandler.deposit(6088);
        otlHandler.fundLoan(109661471064383968181601144386020654);
        otlHandler.fundLoan(29427130491503934981515728233603026605336649604312585434319270);
        otlHandler.fundLoan(25913);
        lpHandler.deposit(3716);
        otlHandler.warp(11490);
        lpHandler.deposit(11255);
        otlHandler.warp(1);
        otlHandler.warp(6569);
        lpHandler.deposit(978079677240561215983192122);
        otlHandler.makePayment(31298446104534848085763730332274522213050254729);
        lpHandler.deposit(13148);
        lpHandler.deposit(5976);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.warp(20060988727144724581329347184167);
        otlHandler.warp(384147430254762969633701107395063934907365979386524117057529473);
        otlHandler.makePayment(15413);
        otlHandler.warp(29031);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640497520373645886411839937627);
        lpHandler.deposit(13135);
        otlHandler.fundLoan(8229);
        otlHandler.makePayment(104484808911688478967305623845045510426727329389817226068529945422);
        otlHandler.warp(5955);
        otlHandler.fundLoan(3849);
        otlHandler.warp(25608927);
        otlHandler.warp(9746);
        otlHandler.makePayment(2101463150);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.fundLoan(165023636029456613505107040191372761685433);
        otlHandler.warp(1844);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        lpHandler.deposit(16303904230091110422773564347860631526548135264274228083022953274582);
        otlHandler.makePayment(155658932451035992202865856848747699850391067986110362758125086334);
        otlHandler.warp(1626);
        otlHandler.warp(96645697591095290133848938326434792736057957229933405313432420);
        otlHandler.fundLoan(21491);
        otlHandler.warp(3294);
        lpHandler.deposit(18222);
        otlHandler.makePayment(521);
        otlHandler.warp(5241699634718014300816198576121227639125985198956);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        otlHandler.fundLoan(3107044680656420359214484961774638531733779032801751403277);
        otlHandler.warp(5273);
        otlHandler.warp(4209);
        otlHandler.warp(18274);
        lpHandler.deposit(6074929971305000635321258080335628413792271753618062018199158418347579);
        otlHandler.fundLoan(1993083621046674105237054964123588237775088928996);
        otlHandler.warp(1340498120265482961803434036010);
        otlHandler.makePayment(0);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.makePayment(23605423253634028879269348804823130572007252867945619600779667019314862489600);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.warp(36907);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.fundLoan(2);
        lpHandler.deposit(108927115326790185267668604740891393550283939570);
        otlHandler.warp(3);
        otlHandler.makePayment(13195101281313045);
        otlHandler.makePayment(12232072262543592134336735979045382672936182704328895784095213217866);
        otlHandler.fundLoan(138667033679431919260720146202959658547388407079264212158978785);
        otlHandler.warp(1);
        otlHandler.fundLoan(37724383753061191000944696);
        lpHandler.deposit(3462997177392828920845567805782361904999430482340081078);
        otlHandler.makePayment(6196);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        otlHandler.fundLoan(231280921771104906593679023965177944100389);
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        otlHandler.warp(994392248);
        otlHandler.warp(85540073489);
        otlHandler.makePayment(19431);
        otlHandler.warp(651408481049165278776974951466);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.makePayment(35884191910784246086953688856);
        otlHandler.makePayment(42403129249430);
        otlHandler.warp(17626348027130312856016509433252406460513152269976981895154041115761625);
        otlHandler.makePayment(14638);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.makePayment(11804);
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        otlHandler.makePayment(9560);
        otlHandler.warp(3);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        lpHandler.deposit(251);
        otlHandler.fundLoan(8725);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        otlHandler.warp(22326);
        otlHandler.warp(24761);
        otlHandler.makePayment(4080);
        otlHandler.warp(1);
        otlHandler.makePayment(101817);
        lpHandler.deposit(326829932715896490033352735064253617466434004057790513296071504134806335782);
        otlHandler.warp(13486);
        otlHandler.makePayment(7997);
        otlHandler.warp(17578);
        otlHandler.fundLoan(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        lpHandler.deposit(165648280351324457348934033948342);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        otlHandler.warp(3513309141335827945188051678585497003925224526083);
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        otlHandler.makePayment(16040);
        otlHandler.fundLoan(2);
        otlHandler.warp(1422);
        otlHandler.fundLoan(1140066042034132600042288622);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        otlHandler.warp(437759439162553905342380480474511);
        vm.warp(block.timestamp + 1);
        lpHandler.deposit(20383);
        otlHandler.makePayment(2027928309074611076353034545081045885263272232977919677954974930);
        otlHandler.makePayment(0);
        otlHandler.fundLoan(29358099219701881544117975740070605829662);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.fundLoan(14302);
        lpHandler.deposit(76476721628705723882120585407289447771830604858099994804495446411211002203818);
        otlHandler.makePayment(18013584217379374635015887664);
        otlHandler.makePayment(18056);
        otlHandler.warp(1);
        otlHandler.makePayment(6092);
        otlHandler.warp(1);
        otlHandler.warp(1);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.fundLoan(11196647);
        otlHandler.warp(1707342829);
        otlHandler.makePayment(21570);
        lpHandler.deposit(30613);
        otlHandler.fundLoan(4198780748613813602354953949045919573687311764251459434587695545766764983985);
        lpHandler.deposit(9708);
        otlHandler.warp(10066230758819374235370193);
        lpHandler.deposit(9400);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.makePayment(0);
        otlHandler.fundLoan(2);
        otlHandler.warp(12047);
        otlHandler.makePayment(0);
        otlHandler.warp(8249);
        otlHandler.fundLoan(9202);
        otlHandler.warp(9901);
        otlHandler.fundLoan(1495009875745207950267383524934898899506523958156958742898);
        otlHandler.fundLoan(67607937724346410352428696771);
        otlHandler.warp(34953938030564341230794974916039275528141374186516768376591227023159958962176);
        otlHandler.fundLoan(2);
        otlHandler.warp(3);
        otlHandler.warp(41733497699394768572622794018341989804128431725257308);
        otlHandler.warp(31997656);
        otlHandler.warp(1);
        otlHandler.fundLoan(13411);
        otlHandler.fundLoan(20735);
        otlHandler.warp(1399900285072382225026740937251878751800428039675987553600687);
        otlHandler.fundLoan(106546842990566452111929055526);
        otlHandler.makePayment(0);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        otlHandler.warp(1);
        otlHandler.fundLoan(4493486844080345977883164);
        otlHandler.fundLoan(2);
        otlHandler.warp(126062394759573286196518659698184199434854462685879996);
        otlHandler.makePayment(0);
        otlHandler.warp(6706159893475166571950954674);
        otlHandler.warp(1);
        otlHandler.makePayment(376670510872741323309131047855205850713601598867388167162);
        lpHandler.deposit(143579839895443673841905369630788035387477634695067915482422302);
        otlHandler.fundLoan(67105108705560809950692);
        otlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        otlHandler.warp(55103904383801669231693376);
        lpHandler.deposit(1353);
        otlHandler.makePayment(498278680785168249737471953616393309);
        otlHandler.makePayment(667938688271681834053390456604);
        otlHandler.warp(32607951069992885614303882);
        otlHandler.fundLoan(2);
        otlHandler.warp(8796);
        vm.warp(block.timestamp + 1);  // Use 1 second to get the diff of the Loans Net Interest to calculate the Loans_IR
        payOffAllLoans();
    }

    function test_ftlRegression() public {
        ftlHandler.warp(6203495600325910946838183054760614388491462587459103696158497);
        ftlHandler.warp(3);
        ftlHandler.makePayment(0);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        ftlHandler.makePayment(5689669439453843152640375327884);
        ftlHandler.createLoanAndFund(1342450613105446685729973156660967450154112894989933850);
        ftlHandler.makePayment(1535000897378345723925352775840778760031485621);
        ftlHandler.makePayment(0);
        ftlHandler.makePayment(0);
        ftlHandler.warp(3);
        lpHandler.deposit(497556035578348024629018346316);
        ftlHandler.makePayment(0);
        ftlHandler.makePayment(4640605054409314472845);
        ftlHandler.makePayment(1165667214047592212802017731317467771436049213397386732365476796345352192);
        lpHandler.deposit(3705223557817722096900391703);
        ftlHandler.makePayment(47083054986245737403224274974);
        ftlHandler.warp(3);
        lpHandler.deposit(275664868274152537292650289851);
        ftlHandler.createLoanAndFund(2);
        ftlHandler.makePayment(3759227575298397670285303027535931674098518086860048);
        ftlHandler.warp(33937056359498479038203769796184977462225766065145635994694596395585727982793);
        lpHandler.deposit(4867506685787466565197075235385625279883416978764962950526402369956968885);
        ftlHandler.makePayment(550220975653651379766480899426);
        ftlHandler.makePayment(291735557719817563135987290323);
        ftlHandler.makePayment(22030855164643088403135177817);
        ftlHandler.makePayment(364086404146697004012109778055);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        lpHandler.deposit(48157935249);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        ftlHandler.makePayment(2609607849530588274482612183);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        lpHandler.deposit(29818844561458059239790499760);
        ftlHandler.makePayment(1085865857393676972235090205202);
        ftlHandler.warp(30049578511147215784808879450479905476995172949079447740293991805027474210816);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        ftlHandler.makePayment(4355070817330309753956956960857);
        ftlHandler.warp(22773113574012217943539223064262827744124541905955);
        lpHandler.deposit(28129440064966438982658655774582882953);
        lpHandler.deposit(420716899046255543209211568647);
        ftlHandler.makePayment(425350870991447500327919030748);
        ftlHandler.makePayment(9912898508149847821069441191498776080884578950456863987617833017);
        ftlHandler.warp(3);
        ftlHandler.createLoanAndFund(713735382445349452958835418);
        ftlHandler.makePayment(110287771586574559483236824050530997502995934685153);
        ftlHandler.createLoanAndFund(29079695837560852963713056);
        ftlHandler.createLoanAndFund(2);
        lpHandler.deposit(2857744798573110043741497210471037236864558441303773);
        lpHandler.deposit(4961274053029339419298247513984461828040850776297541);
        lpHandler.deposit(263218863990254124088031126996);
        lpHandler.deposit(290461089077235317299023746083);
        ftlHandler.makePayment(2493668154705024469971894243);
        ftlHandler.makePayment(115792089237316195423570985008687907853269984665640564039457584007913129639934);
        ftlHandler.makePayment(1950995195);
        ftlHandler.createLoanAndFund(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.createLoanAndFund(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.makePayment(103523057341804396457965468243675146005537541190094904200564449844653857800461);
        ftlHandler.warp(48265005884383515873546119761029151733227885571577108363884910921120650488174);
        ftlHandler.refinance(1);
        lpHandler.deposit(22593643677509519146584898039);
        ftlHandler.warp(69609988642232106634312276501);
        ftlHandler.createLoanAndFund(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.createLoanAndFund(2544921752354707913094638630);
        ftlHandler.makePayment(7281687972459280173964126673432780831219068839784917175480442676566944936);
        ftlHandler.warp(3);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639933);
        lpHandler.deposit(14930870080880625430191572197538653230012584834766837);
        ftlHandler.makePayment(30049578511147215784808879450479950515753733672679543768835321335496624649271);
        ftlHandler.warp(3);
        lpHandler.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935);
        ftlHandler.createLoanAndFund(120489406142390375575027);
        lpHandler.deposit(12748380393842777770133276957678471410028627743689804770477263691893258);
        ftlHandler.makePayment(1788961354639059620645954342);
        ftlHandler.createLoanAndFund(2);
        lpHandler.deposit(12203469406933783599433615367959781295476450263677936270766347465256909);
        lpHandler.deposit(1452640075110307027989471074944);
        ftlHandler.makePayment(24840154893635717900773672551937);
        ftlHandler.createLoanAndFund(103744197113331694100631767429904107935495722019513313498069660460085417681345);
        ftlHandler.makePayment(35013092146558048719068182309582874082030983899154950);
        ftlHandler.refinance(1);
        ftlHandler.createLoanAndFund(115792089237316195423570985008687907853269984665640564039457584007913129639932);
        ftlHandler.makePayment(307322860683155672775692146);
        ftlHandler.makePayment(1469092523987316307938294429704413617287138326342384021205);
        lpHandler.deposit(7053578335415611291562068547);
        ftlHandler.warp(15970693);
        ftlHandler.makePayment(0);
        ftlHandler.makePayment(20402132060350507801816440660002652392695475240925276668);
        ftlHandler.makePayment(17675886594653395073815);
        ftlHandler.makePayment(1551732665250754558411106390236638327067903700613711782591429530818733110);
        ftlHandler.makePayment(25414667719047303192789801520089770546638013880308097451329139213340807476533);
        ftlHandler.makePayment(0);
        ftlHandler.refinance(12066898659697934890140661031591380605699784697279744693222);
        ftlHandler.makePayment(39498933997746926808754338706);
        ftlHandler.createLoanAndFund(35348713070684612053134336812777557792480217830077);
        ftlHandler.refinance(26386699008716231768130);
        ftlHandler.refinance(26386699008716231768130);
    }

}
