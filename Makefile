install:
	@git submodule update --init --recursive

update:
	@forge update

build:
	@scripts/build.sh -p default

test:
	@scripts/test.sh

sim:
	@scripts/test.sh -p simulations

clean:
	@forge clean
