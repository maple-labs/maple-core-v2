# Submodule management

install:
	@git submodule update --init --recursive

update:
	@forge update

# Build and test

profile ?=default

build:
	@FOUNDRY_PROFILE=production forge build

test:
	forge test

e2e:
	./test.sh -d tests/e2e -p $(profile)

fuzz:
	./test.sh -d tests/fuzz -p $(profile)

integration:
	./test.sh -d tests/integration -p $(profile)

invariant:
	./test.sh -d tests/invariants -p $(profile)

local-sim:
	./test.sh -d simulations/local -p local_simulations

mainnet-sim:
	./simulate.sh -d simulations/mainnet -p mainnet_simulations

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


