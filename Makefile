install:
	@git submodule update --init --recursive

update:
	@forge update

build:
	@scripts/build.sh -p default

slither-files:
	@scripts/generate-slither-files.sh

test:
	@scripts/test.sh

deploy:
	@scripts/deploy.sh

invariant:
	@scripts/invariant.sh

local-sim:
	@scripts/test.sh -p local_simulations

mainnet-sim:
	@scripts/mainnet-simulation.sh -p mainnet_simulations

clean:
	@forge clean

pay-and-refi-upcoming-loans:
	@scripts/pay-and-refi-upcoming-loans.sh

upgrade-loans-301:
	@scripts/upgrade-loans-301.sh

upgrade-dls-400:
	@scripts/upgrade-dls-400.sh

addresses:
	@node scripts/parse-broadcast.js > ./scripts/deploy-addresses-no-name.js

validate:
	@forge script --rpc-url $(ETH_RPC_URL) -vvv simulations/mainnet/ValidationScripts.s.sol:$(step)
