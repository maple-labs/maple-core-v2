const fs = require("fs");

const DEFAULT_PARAMETERS = {
    createPool:     { name: "pool1",        asset: "USDC" },
    deposit:        { name: "lp1",          assets: 0 },
    deploy:         { name: "strategyA",    assets: 0 },
    schedule:       { name: "strategyA",    deadline: 0, yield: 0 },
    passTime:       { seconds: 0 },
    requestRedeem:  { name: "lp1",          shares: 0 },
    reconcile:      { name: "strategyA",    assets: 0 },
    impair:         { name: "strategyA",    assets: 0 },
    default:        { name: "strategyA",    assets: 0 },
};

const NUMERIC_PARAMETER_KEYS = new Set(["assets", "yield"]);

function parseCSVLine(line) {
    const cells = [];
    let current = "";
    let inQuotes = false;

    for (let i = 0; i < line.length; ++i) {
        const char = line[i];

        if (char === "\"") {
            if (inQuotes && line[i + 1] === "\"") {
                current += "\"";
                ++i;
                continue;
            }

            inQuotes = !inQuotes;
            continue;
        }

        if (char === "," && !inQuotes) {
            cells.push(current.trim());
            current = "";
            continue;
        }

        current += char;
    }

    cells.push(current.trim());

    return cells;
}

function normalizeParameterValues(value) {
    if (Array.isArray(value)) {
        return value.map(normalizeParameterValues);
    }

    if (value && typeof value === "object") {
        const output = {};
        for (const [key, nested] of Object.entries(value)) {
            output[key] = normalizeParameterValues(nested);
        }
        return output;
    }

    if (typeof value === "string") {
        const trimmed = value.trim();
        if (/^\d+$/.test(trimmed)) {
            return Number.parseInt(trimmed, 10);
        }
        return trimmed;
    }

    return value;
}

function parseParameters(rawParameters) {
    const trimmed = (rawParameters || "").trim();
    if (!trimmed) return {};

    const sanitized = trimmed.replace(/'/g, '"');

    try {
        return normalizeParameterValues(JSON.parse(sanitized));
    } catch (error) {
        throw new Error(`Failed to parse parameters: ${rawParameters}\n${error.message}`);
    }
}

function convertToInteger(value) {
    if (value === undefined || value === null || value === "") return 0;

    if (typeof value === "number") return value;

    if (typeof value === "string" && /^\d+$/.test(value)) {
        return Number.parseInt(value, 10);
    }

    throw new Error(`Expected unsigned integer value, received: ${value}`);
}

function setParameterValue(key, value) {
    if (!NUMERIC_PARAMETER_KEYS.has(key)) return value;
    return convertToInteger(value);
}

function applyParameterDefaults(actionType, parameters) {
    const defaults = DEFAULT_PARAMETERS[actionType] || {};
    const merged = { ...defaults, ...parameters };

    for (const key of Object.keys(merged)) {
        merged[key] = setParameterValue(key, merged[key]);
    }

    return merged;
}

function readValue(cells, indexByHeader, header) {
    const index = indexByHeader[header];
    if (index === undefined) return 0;

    return convertToInteger(cells[index]);
}

function buildExpectedSingle(cells, indexByHeader) {
    // For single-strategy files, treat values as belonging to Strategy A.
    // Only `system.aum` is kept at the system level; all other metrics belong under strategies.strategyA.
    return {
        system: {
            aum: readValue(cells, indexByHeader, "System AUM"),
        },
        strategies: {
            strategyA: {
                aum:          readValue(cells, indexByHeader, "Strategy AUM"),
                outstanding:  readValue(cells, indexByHeader, "Strategy Outstanding"),
                realizedFees: readValue(cells, indexByHeader, "Realized Fees"),
                accruedYield: readValue(cells, indexByHeader, "Accrued Yield"),
                accruedFees:  readValue(cells, indexByHeader, "Accrued Fees"),
            },
        },
    };
}

function buildExpectedMulti(cells, indexByHeader) {
    return {
        system: {
            aum: readValue(cells, indexByHeader, "System AUM"),
        },
        strategies: {
            strategyA: {
                aum:          readValue(cells, indexByHeader, "StrategyA AUM"),
                outstanding:  readValue(cells, indexByHeader, "StrategyA Outstanding"),
                realizedFees: readValue(cells, indexByHeader, "StrategyA Realized Fees"),
                accruedYield: readValue(cells, indexByHeader, "StrategyA Accrued Yield"),
                accruedFees:  readValue(cells, indexByHeader, "StrategyA Accrued Fees"),
            },
            strategyB: {
                aum:          readValue(cells, indexByHeader, "StrategyB AUM"),
                outstanding:  readValue(cells, indexByHeader, "StrategyB Outstanding"),
                realizedFees: readValue(cells, indexByHeader, "StrategyB Realized Fees"),
                accruedYield: readValue(cells, indexByHeader, "StrategyB Accrued Yield"),
                accruedFees:  readValue(cells, indexByHeader, "StrategyB Accrued Fees"),
            },
        },
    };
}

function sortObject(value) {
    // Sorting is not functionally necessary, but keeps the output consistent with the Scenarios foundry decode requirements.
    if (Array.isArray(value)) {
        return value.map(sortObject);
    }

    if (value && typeof value === "object") {
        const sorted = {};

        for (const key of Object.keys(value).sort()) {
            sorted[key] = sortObject(value[key]);
        }

        return sorted;
    }

    return value;
}

function CSVToActionsJSON(data, { omitFirstRow = false } = {}) {
    const rows = data
        .split(/\r?\n/)
        .map((row) => row.trim())
        .filter(Boolean);

    if (!rows.length) return [];

    const headers = parseCSVLine(rows[0]);
    const indexByHeader = headers.reduce((lookup, header, index) => {
        lookup[header.trim()] = index;
        return lookup;
    }, {});

    const isMultiStrategy = indexByHeader["StrategyA AUM"] !== undefined && indexByHeader["StrategyB AUM"] !== undefined;

    return rows.slice(omitFirstRow ? 1 : 0).map((row) => {
        const cells = parseCSVLine(row);
        const timestamp = parseInt(cells[0], 10);
        const actionType = cells[1];
        const parameters = applyParameterDefaults(actionType, parseParameters(cells[2]));
        const expected = sortObject(isMultiStrategy
            ? buildExpectedMulti(cells, indexByHeader)
            : buildExpectedSingle(cells, indexByHeader));

        return sortObject({ timestamp, actionType, parameters, expected });
    });
}

const csv = fs.readFileSync(`./scenarios/v3/data/csv/${process.argv[2]}.csv`, { encoding: "utf8" });

const json = sortObject({ actions: CSVToActionsJSON(csv, { omitFirstRow: true }) });

fs.writeFileSync(`./scenarios/v3/data/json/${process.argv[2]}.json`, JSON.stringify(json, null, 4), { encoding: "utf8" });
