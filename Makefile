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

deploy-eth-v3 :; forge script scripts/Deploy.s.sol:DeployMainnet --rpc-url mainnet --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv
deploy-eth-v3-pk :; forge script scripts/Deploy.s.sol:DeployMainnet --rpc-url mainnet --broadcast --legacy --private-key ${PRIVATE_KEY} --slow -vv


deploy-proxy-mainnet :; forge script scripts/DeployFactory.s.sol:DeployMainnet --rpc-url mainnet --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv
deploy-proxy-polygon :; forge script scripts/DeployFactory.s.sol:DeployPolygon --rpc-url polygon --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv
deploy-proxy-optimism :; forge script scripts/DeployFactory.s.sol:DeployOptimism --rpc-url optimism --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv
deploy-proxy-arbitrum :; forge script scripts/DeployFactory.s.sol:DeployArbitrum --rpc-url arbitrum --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv
deploy-proxy-fantom :; forge script scripts/DeployFactory.s.sol:DeployFantom --rpc-url fantom --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv
deploy-proxy-harmony :; forge script scripts/DeployFactory.s.sol:DeployHarmony --rpc-url harmony --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --slow -vvvv
