# Generating Contract Interface Docs from Natspec

1. install `maple-tools` either globally (executable via `npx maple-tools`) or cloned locally beside this directory (executable via `node ../maple-tools/bin/index.js`)

2. run `make build` in each relevant module directory

3. from here, run:

``` shell
node ../maple-tools/bin/index.js merge-abi --in ./modules/fixed-term-loan/out --out ./artifacts --outName="FixedTermLoan" --name "MapleLoan" --filter="IMapleLoan" --filter="IMapleLoanEvents" --filter="MapleLoan" --filter="IMapleProxied" --filter="IProxied"

node ../maple-tools/bin/index.js merge-abi --in ./modules/fixed-term-loan/out --out ./artifacts --outName="FixedTermLoanInitializer" --name "MapleLoanInitializer" --filter="IMapleLoanInitializer" --filter="MapleLoanInitializer"

node ../maple-tools/bin/index.js merge-abi --in ./modules/fixed-term-loan/out --out ./artifacts --outName="FixedTermRefinancer" --name "Refinancer" --filter="IRefinancer" --filter="Refinancer"

node ../maple-tools/bin/index.js merge-abi --in ./modules/fixed-term-loan-manager/out --out ./artifacts --outName="FixedTermLoanManager" --name "LoanManager" --filter="ILoanManager" --filter="LoanManager" --filter="IMapleProxied" --filter="IProxied"

node ../maple-tools/bin/index.js merge-abi --in ./modules/fixed-term-loan-manager/out --out ./artifacts --outName="FixedTermLoanManagerInitializer" --name "LoanManagerInitializer" --filter="ILoanManagerInitializer" --filter="LoanManagerInitializer"

node ../maple-tools/bin/index.js merge-abi --in ./modules/globals/out --out ./artifacts --outName="Globals" --name "MapleGlobals" --filter="IMapleGlobals" --filter="MapleGlobals" --filter="INonTransparentProxied" --filter="NonTransparentProxied" --filter="INonTransparentProxy" --filter="NonTransparentProxy"

node ../maple-tools/bin/index.js merge-abi --in ./modules/open-term-loan/out --out ./artifacts --outName="OpenTermLoan" --name "MapleLoan" --filter="IMapleLoan" --filter="IMapleLoanEvents" --filter="MapleLoan" --filter="IMapleProxied" --filter="IProxied"

node ../maple-tools/bin/index.js merge-abi --in ./modules/open-term-loan/out --out ./artifacts --outName="OpenTermLoanInitializer" --name "MapleLoanInitializer" --filter="IMapleLoanInitializer" --filter="MapleLoanInitializer"

node ../maple-tools/bin/index.js merge-abi --in ./modules/open-term-loan/out --out ./artifacts --outName="OpenTermLoanRefinancer" --name "MapleRefinancer" --filter="IMapleRefinancer" --filter="MapleRefinancer"

node ../maple-tools/bin/index.js merge-abi --in ./modules/open-term-loan/out --out ./artifacts --outName="OpenTermLoanFactory" --name "MapleLoanFactory" --filter="IMapleLoanFactory" --filter="MapleLoanFactory" --filter="IMapleProxyFactory" --filter="MapleProxyFactory"

node ../maple-tools/bin/index.js merge-abi --in ./modules/open-term-loan-manager/out --out ./artifacts --outName="OpenTermLoanManager" --name "LoanManager" --filter="ILoanManager" --filter="LoanManager" --filter="IMapleProxied" --filter="IProxied"

node ../maple-tools/bin/index.js merge-abi --in ./modules/open-term-loan-manager/out --out ./artifacts --outName="OpenTermLoanManagerInitializer" --name "LoanManagerInitializer" --filter="ILoanManagerInitializer" --filter="LoanManagerInitializer"

node ../maple-tools/bin/index.js merge-abi --in ./modules/open-term-loan-manager/out --out ./artifacts --outName="OpenTermLoanManagerFactory" --name "LoanManagerFactory" --filter="ILoanManagerFactory" --filter="LoanManagerFactory" --filter="IMapleProxyFactory" --filter="MapleProxyFactory"

node ../maple-tools/bin/index.js merge-abi --in ./modules/pool/out --out ./artifacts --name "PoolManager" --filter="IPoolManager" --filter="PoolManager" --filter="IMapleProxied" --filter="IProxied"

node ../maple-tools/bin/index.js merge-abi --in ./modules/pool/out --out ./artifacts --name "PoolDeployer" --filter="IPoolDeployer" --filter="PoolDeployer"
```

The above will generate artifacts in the `./artifacts` directory, for all relevant contracts. These artifacts each contain the merged ABI across all their dependencies (as listed via the various filter), as well as the natspec for each ABI element. Notice the `--outName` usage for some command, to handle renaming the resulting artifact file to avoid collisions.

4. run

```shell
node ../maple-tools/bin/index.js build-docs --in ./artifacts --out ./docs --templates ./templates`
```

To generate a formatted documents in `./docs` for each artifact in `./artifacts` using the `contract.hbs` template in `./templates`.

5. Open each document and rename and edit as needed before publishing.
