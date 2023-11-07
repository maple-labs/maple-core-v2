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

// If a property name is in this array, it's value needs to be interpreted as a decimal.
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

// Properties missing in `parameters` will be set to defaults defined above, for each action type.
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
        .replaceAll(' ', '')  // replace some common unnecessary formatting to make parsing the CSV easier.
        .replaceAll('\'', '"')
        .replaceAll('\r', '')
        .replaceAll('"{', '{')
        .replaceAll('}"', '}')
        .replaceAll('capacity', 'liquidityCap')  // replace some commonly mis-named properties.
        .replaceAll('paymentCycle', 'paymentInterval')
        .replaceAll('"lateInterestPremium"', '"lateInterestPremiumRate"')
        .split('\n')  // Split by CSV rows
        .map(x => x.split(',{'))  // Within each row object, split by starts if stringified json
        .map(x => x.map(y => y.split('},')))  // Within each array above, further split by end if stringified json
        .map(x => x.flat())  // Flatted the arrays of arrays into a single array of all cells, for each row object
        .map(x => x.map(y => y.includes(':') ? JSON.parse(`{${y}}`) : y.split(',')))  // For each cell that looks like json, parse as json, else split again using commas as delimiter
        .map(x => x.flat())  // Flatted the arrays of arrays into a single array of all cells, for each row object
        .map(x => ({  // Create the normalized action object for each row object
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
        action.parameters = mergeIntoDefaults(action.actionType, action.parameters);  // Ensure parameters are fully defined, with at least defaults.

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

const csv = fs.readFileSync(`./scenarios/data/csv/${process.argv[2]}.csv`, { encoding: 'utf8' });  // Read CSV as utf8 encoded.

const json = { config: {}, actions: CSVToActionsJSON(csv, { omitFirstRow: true }) };  // convert to json, omitting header row.

fs.writeFileSync(`./scenarios/data/json/${process.argv[2]}.json`, JSON.stringify(json, null, 4), { encoding: 'utf8' });  // Write JSON as utf8 encoded, with same file name.
