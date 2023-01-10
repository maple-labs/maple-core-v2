# Submodule management

install:
	@git submodule update --init --recursive

update:
	@forge update

# Build and test

profile ?=default

build:
	@scripts/build.sh -p $(profile)

test:
	forge test --match-path "contracts/tests/*"

e2e:
	@scripts/test.sh -d e2e -p $(profile)

fuzz:
	@scripts/test.sh -d fuzz -p $(profile)

fuzzing:
	@scripts/test.sh -d fuzzing -p $(profile)

integration:
	@scripts/test.sh -d integration -p $(profile)

invariant:
	@scripts/test.sh -d invariants -p $(profile)

local-sim:
	@scripts/test.sh -d local-simulations -p local_simulations

mainnet-sim:
	@scripts/simulate.sh -d mainnet-simulations -p mainnet_simulations

# Forge scripting

deploy:
	@scripts/deploy.sh

pay-and-refi-upcoming-loans:
	@scripts/pay-and-refi-upcoming-loans.sh

upgrade-loans-301:
	@scripts/upgrade-loans-301.sh

upgrade-dls-400:
	@scripts/upgrade-dls-400.sh

validate:
	@FOUNDRY_PROFILE=mainnet_simulations forge script --rpc-url $(ETH_RPC_URL) -vvv simulations/mainnet/ValidationScripts.s.sol:$(step)

# Utility

addresses:
	@node scripts/parse-broadcast.js > ./scripts/deploy-addresses-no-name.js

clean:
	@forge clean

slither-files:
	@scripts/generate-slither-files.sh


