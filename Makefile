install:
	@git submodule update --init --recursive

update:
	@forge update

build:
	@scripts/build.sh -p default

test:
	@scripts/test.sh

local-sim:
	@scripts/test.sh -p local_simulations

mainnet-sim:
	@scripts/mainnet-simulation.sh -p mainnet_simulations

clean:
	@forge clean
