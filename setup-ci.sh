mkdir $HOME/.ssh
touch $HOME/.ssh/id_rsa
chmod 600 $HOME/.ssh/id_rsa

git config --global url."git@github.com:".insteadOf "https://github.com/"

echo "$SSH_KEY_ADDRESS_REGISTRY" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/address-registry

echo "$SSH_KEY_FIXED_TERM_LOAN" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/fixed-term-loan

echo "$SSH_KEY_FIXED_TERM_LOAN_MANAGER" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/fixed-term-loan-manager

echo "$SSH_KEY_GLOBALS_V2" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/globals

echo "$SSH_KEY_LIQUIDATIONS" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/liquidations

echo "$SSH_KEY_OPEN_TERM_LOAN" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/open-term-loan

echo "$SSH_KEY_OPEN_TERM_LOAN_MANAGER" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/open-term-loan-manager

echo "$SSH_KEY_POOL_V2" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/pool

echo "$SSH_KEY_WITHDRAWAL_MANAGER" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/withdrawal-manager-cyclical

echo "$SSH_KEY_POOL_PERMISSION_MANAGER" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/pool-permission-manager

echo "$SSH_KEY_WM_QUEUE" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/withdrawal-manager-queue

echo "$SSH_KEY_STRATEGIES" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/strategies

echo "$SSH_KEY_SYRUP_UTILS" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/syrup-utils

git submodule update --init --recursive
