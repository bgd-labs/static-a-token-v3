# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes

test   :; forge test -vvv

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

deploy-mainnet :; forge script scripts/Deploy.s.sol:DeployMainnet --rpc-url mainnet --broadcast --ledger --legacy --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv --verify
deploy-polygon :; forge script scripts/Deploy.s.sol:DeployPolygon --rpc-url polygon --broadcast --ledger --legacy --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv --verify
deploy-avalanche :; forge script scripts/Deploy.s.sol:DeployAvalanche --rpc-url avalanche --broadcast --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv --verify
deploy-optimism :; forge script scripts/Deploy.s.sol:DeployOptimism --rpc-url optimism --broadcast --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv --verify
deploy-arbitrum :; forge script scripts/Deploy.s.sol:DeployArbitrum --rpc-url arbitrum --broadcast --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv --verify