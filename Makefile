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

invariant:
	@scripts/invariant.sh

local-sim:
	@scripts/test.sh -p local_simulations

mainnet-sim:
	@scripts/mainnet-simulation.sh -p mainnet_simulations

clean:
	@forge clean
