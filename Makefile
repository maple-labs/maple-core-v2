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

scenario:
	./scenarios.sh

# Utility

clean:
	@forge clean

slither-files:
	@scripts/generate-slither-files.sh
