const fs = require("fs");

const DEFAULT_CREATE_POOL_PARAMETERS = {
    name: "pool1",
    asset: "USDC",
    liquidityCap: 0,
    platformServiceFeeRate: 0,
    delegateManagementFeeRate: 0,
    platformManagementFeeRate: 0,
    platformOriginationFeeRate: 0,
};

const DEFAULT_DEPOSIT_PARAMETERS = {
    name: "lp1",
    assets: 0,
};

const DEFAULT_FIXED_TERM_FUND_LOAN_PARAMETERS = {
    closingFeeRate: 0,
    collateral: 0,
    delegateOriginationFee: 0,
    delegateServiceFee: 0,
    endingPrincipal: 0,
    gracePeriod: 0,
    interestRate: 0,
    isOpenTerm: false,
    lateFeeRate: 0,
    lateInterestPremiumRate: 0,
    name: "loan1",
    paymentInterval: 0,
    payments: 0,
    principal: 0,
};

const DEFAULT_OPEN_TERM_FUND_LOAN_PARAMETERS = {
    delegateServiceFeeRate: 0,
    gracePeriod: 0,
    interestRate: 0,
    isOpenTerm: true,
    lateFeeRate: 0,
    lateInterestPremiumRate: 0,
    name: "loan1",
    noticePeriod: 0,
    paymentInterval: 0,
    principal: 0,
};

const DEFAULT_PAY_LOAN_PARAMETERS = {
    name: "loan1",
    principal: 0,
    interest: 0,
    delegateServiceFee: 0,
    platformServiceFee: 0,
    delegateManagementFee: 0,
    platformManagementFee: 0,
};

const DEFAULT_CALL_PARAMETERS = {
    name: "loan1",
    principal: 0,
};

const DEFAULT_UNCALL_PARAMETERS = {
    name: "loan1",
};

const DEFAULT_IMPAIR_PARAMETERS = {
    name: "loan1",
};

const DEFAULT_UNIMPAIR_PARAMETERS = {
    name: "loan1",
};

const DEFAULT_REFINANCE_PARAMETERS = {
    name: "loan1",
    terms: [],
    values: []
};

const DEFAULT_DEFAULT_PARAMETERS = {
    name: "loan1",
    principal: 0,
    interest: 0,
    platformServiceFee: 0,
    platformManagementFee: 0,
    poolLosses: 0,
};

const decimalValues = [
    'liquidityCap',
    'accruedInterest',
    'cash',
    'principalOutstanding',
    'totalAssets',
    'totalSupply',
    'unrealizedLosses',
    'assets',
    'principal',
    'interest',
    'delegateServiceFee',
    'platformServiceFee',
    'delegateManagementFee',
    'platformManagementFee',
    'poolLosses',
];

const mergeIntoDefaults = (actionType, parameters) =>
    actionType === 'createPool' ? Object.assign({}, DEFAULT_CREATE_POOL_PARAMETERS, parameters) :
    actionType === 'deposit' ? Object.assign({}, DEFAULT_DEPOSIT_PARAMETERS, parameters) :
    actionType === 'fundLoan' ? Object.assign({}, parameters.isOpenTerm ? DEFAULT_OPEN_TERM_FUND_LOAN_PARAMETERS : DEFAULT_FIXED_TERM_FUND_LOAN_PARAMETERS, parameters) :
    actionType === 'payLoan' ? Object.assign({}, DEFAULT_PAY_LOAN_PARAMETERS, parameters) :
    actionType === 'callLoan' ? Object.assign({}, DEFAULT_CALL_PARAMETERS, parameters) :
    actionType === 'uncallLoan' ? Object.assign({}, DEFAULT_UNCALL_PARAMETERS, parameters) :
    actionType === 'impairLoan' ? Object.assign({}, DEFAULT_IMPAIR_PARAMETERS, parameters) :
    actionType === 'unimpairLoan' ? Object.assign({}, DEFAULT_UNIMPAIR_PARAMETERS, parameters) :
    actionType === 'refinanceLoan' ? Object.assign({}, DEFAULT_REFINANCE_PARAMETERS, parameters) :
    actionType === 'defaultLoan' ? Object.assign({}, DEFAULT_DEFAULT_PARAMETERS, parameters) :
    parameters;

const convertToInteger = (decimal) => parseInt(decimal * 1e6);

const CSVToActionsJSON = (data, { omitFirstRow = false } = {}) => {
    const json = data
        .slice(omitFirstRow ? data.indexOf('\n') + 1 : 0)
        .replaceAll(' ', '')
        .replaceAll('\'', '"')
        .replaceAll('\r', '')
        .replaceAll('"{', '{')
        .replaceAll('}"', '}')
        .replaceAll('capacity', 'liquidityCap')
        .replaceAll('paymentCycle', 'paymentInterval')
        .replaceAll('"lateInterestPremium"', '"lateInterestPremiumRate"')
        .split('\n')
        .map(x => x.split(',{'))
        .map(x => x.map(y => y.split('},')))
        .map(x => x.flat())
        .map(x => x.map(y => y.includes(':') ? JSON.parse(`{${y}}`) : y.split(',')))
        .map(x => x.flat())
        .map(x => ({
            timestamp: parseInt(x[0]),
            actionType: x[1],
            parameters: Object.assign(
                x[2],
                { isOpenTerm: x[2].loanType == undefined ? undefined : x[2].loanType == 'open' },
                { loanType: undefined }
            ),
            expected: {
                accruedInterest: x[4],
                cash: x[6],
                principalOutstanding: x[3],
                totalAssets: x[5],
                totalSupply: x[7],
                unrealizedLosses: x[8],
            }
        }));

    json.forEach((action) => {
        action.parameters = mergeIntoDefaults(action.actionType, action.parameters);

        for (const property in action.parameters) {
            if (decimalValues.includes(property)) {
                action.parameters[property] = convertToInteger(action.parameters[property]);
            }
        }

        for (const property in action.expected) {
            if (decimalValues.includes(property)) {
                action.expected[property] = convertToInteger(action.expected[property]);
            }
        }
    });

    return json;
}

const csv = fs.readFileSync(`./scenarios/data/csv/${process.argv[2]}.csv`, { encoding: 'utf8' });

const json = { config: {}, actions: CSVToActionsJSON(csv, { omitFirstRow: true }) };

fs.writeFileSync(`./scenarios/data/json/${process.argv[2]}.json`, JSON.stringify(json, null, 4), { encoding: 'utf8' });
