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

strategies:
	./test.sh -d tests/integration/strategies -p $(profile)

invariant:
	./test.sh -d tests/invariants -p $(profile)

protocol-upgrade:
	./test.sh -d tests/protocol-upgrade -p $(profile)

scenario:
	./scenarios.sh

deploy:
	./deploy.sh

# Utility

validate:
	forge script Validate$(step)

validateLocal:
	forge script Validate$(step) --rpc-url "http://localhost:8545"

doLocal:
	forge script Do$(step) --rpc-url "http://localhost:8545" --broadcast --unlocked

deal:
	curl http://localhost:8545 -X POST -H "Content-Type: application/json" --data "{\"method\":\"anvil_setBalance\",\"params\":[\"$(to)\", \"0x021e19e0c9bab2400000\"],\"id\":1,\"jsonrpc\":\"2.0\"}"

clean:
	@forge clean

slither-files:
	@scripts/generate-slither-files.sh
