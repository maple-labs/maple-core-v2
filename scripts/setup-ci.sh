mkdir $HOME/.ssh
echo "$SSH_KEY_LIQUIDATIONS" > $HOME/.ssh/id_rsa
chmod 600 $HOME/.ssh/id_rsa

git submodule update --init modules/debt-locker-v4
cd modules/debt-locker-v4
git config --global url."git@github.com:".insteadOf "https://github.com/"
git submodule update --init --recursive modules/liquidations
echo "$SSH_KEY_LOAN" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/loan
cd ../..

echo "$SSH_KEY_GLOBALS_V2" > $HOME/.ssh/id_rsa
git submodule update --init modules/globals-v2
echo "$SSH_KEY_NTP" > $HOME/.ssh/id_rsa
cd modules/globals-v2
git submodule update --init --recursive
cd ../..

echo "$SSH_KEY_LIQUIDATIONS" > $HOME/.ssh/id_rsa
git submodule update --init modules/liquidations

echo "$SSH_KEY_LOAN" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/loan
git submodule update --init --recursive modules/loan-v301

echo "$SSH_KEY_MIGRATION_HELPERS" > $HOME/.ssh/id_rsa
git submodule update --init modules/migration-helpers
echo "$SSH_KEY_NTP" > $HOME/.ssh/id_rsa
cd modules/migration-helpers
git submodule update --init --recursive
cd ../..

echo "$SSH_KEY_POOL_V2" > $HOME/.ssh/id_rsa
git submodule update --init modules/pool-v2

echo "$SSH_KEY_WITHDRAWAL_MANAGER" > $HOME/.ssh/id_rsa
git submodule update --init --recursive modules/withdrawal-manager

git config --global url."https://github.com/".insteadOf "git@github.com:"
git submodule update --init --recursive
