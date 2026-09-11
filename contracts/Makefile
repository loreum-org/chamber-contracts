export .env

# Persisted chain snapshot under contracts/.anvil/ (see `make anvil`)
ANVIL_STATE ?= .anvil/state.json
ANVIL_RPC ?= http://localhost:8545

# Loreum assets — Ethereum mainnet (see repo README); use with `make anvil` + RPC_URL mainnet fork
LOREUM_GOV_TOKEN ?= 0x7756d245527f5f8925a537be509bf54feb2fdc99
LOREUM_MEMBERSHIP_NFT ?= 0xB99DEdbDe082B8Be86f06449f2fC7b9FED044E15

# Anvil account #0 (matches deploy-*-anvil private key)
ANVIL_ADDR0 ?= 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# loreum-fund-* impersonation: HOLDER= or HODLER= (typo alias)
LOREUM_FROM ?= $(or $(HOLDER),$(HODLER))

# loreum-fund-local: mainnet fork → default Anvil account (override any LOREUM_LOCAL_*)
# Optional: set LOREUM_LOCAL_MEMBERSHIP_HOLDER to impersonate a specific address; otherwise ownerOf(TOKEN_ID) is used
LOREUM_LOCAL_MEMBERSHIP_TOKEN_ID ?= 2
LOREUM_LOCAL_GOV_HODLER ?= 0x5d45A213B2B6259F0b3c116a8907B56AB5E22095
LOREUM_LOCAL_GOV_AMOUNT_WEI ?= 1000000000000000000000
LOREUM_LOCAL_FUND_TO ?= $(ANVIL_ADDR0)

# loreum-fund-wallet: sweep N membership NFTs + LORE to one address (mainnet fork + anvil)
# Override LOREUM_WALLET_TOKEN_IDS if some ids fail on your fork block
LOREUM_WALLET_TOKEN_IDS ?= 2 3 4 5 6 7 8 9 10 11
LOREUM_WALLET_LORE ?= 10000
LOREUM_WALLET_GOV_HODLER ?= $(LOREUM_LOCAL_GOV_HODLER)

ci-test :; forge test

# Fork-only M1 rehearsal: Factory + Chamber on an Ethereum mainnet fork, then
# impersonate the team Safe and transferOwnership(LORE) to the Chamber proxy.
# Never broadcast. Requires MAINNET_RPC_URL or ETH_RPC_URL.
# See docs/mainnet-lore-handoff-rehearsal.md
rehearse-mainnet-lore-handoff :
	@rpc="$(or $(MAINNET_RPC_URL),$(ETH_RPC_URL))"; \
	test -n "$$rpc" || { echo 'Set MAINNET_RPC_URL or ETH_RPC_URL (Ethereum archive/full node)'; exit 1; }; \
	forge test --match-path test/fork/MainnetLoreOwnableHandoff.t.sol -vvv

rehearse-mainnet-lore-handoff-script :
	@rpc="$(or $(MAINNET_RPC_URL),$(ETH_RPC_URL))"; \
	test -n "$$rpc" || { echo 'Set MAINNET_RPC_URL or ETH_RPC_URL (Ethereum archive/full node)'; exit 1; }; \
	forge script script/RehearseMainnetLoreHandoff.s.sol:RehearseMainnetLoreHandoff --fork-url $$rpc -vvv


# Symbolic verification with Halmos (requires: pip install -r fv-requirements.txt)
# Halmos 0.3.3 cannot execute vm.deployCode (proxy CREATE, new Chamber/Factory/Registry).
# CI suites use test-local harnesses; see docs/security/halmos-coverage-2026-09-08.md.
# Default --loop 2 matches 1–2 node board walks.
HALMOS_INCLUDE := ^(BoardSymTest|WalletSymTest|ChamberSymTest|VaultSymTest|RegistrySymTest|FactorySymTest)$
# `--ast` is required: a prior `forge build` without AST leaves artifacts Halmos 0.3.3
# cannot parse (KeyError: 'ast'), and then `--match-contract` finds zero tests.
halmos :; forge build --ast && halmos --match-test '^symbolic' --match-contract '$(HALMOS_INCLUDE)' -vv

ci-halmos :; forge build --ast && halmos --match-test '^symbolic' --match-contract '$(HALMOS_INCLUDE)' -vv

dev-test :; forge test --verbosity -vvv --watch

# Local Anvil: loads snapshot if present, dumps on graceful exit (Ctrl+C).
# Optional: ANVIL_STATE_INTERVAL=120 make anvil — periodic snapshots.
anvil :
	@mkdir -p $$(dirname $(ANVIL_STATE))
	anvil \
		-m 'test test test test test test test test test test test junk' \
		--chain-id 31337 \
		--fork-url ${RPC_URL} \
		--state $(ANVIL_STATE) \
		$(if $(ANVIL_STATE_INTERVAL),--state-interval $(ANVIL_STATE_INTERVAL),)

anvil-reset-state :; rm -rf .anvil

anvil-sepolia :; anvil -m 'test test test test test test test test test test test junk' --fork-url ${RPC_URL} --chain-id 31337


deploy-anvil :; forge script script/${contract}.s.sol:Deploy${contract} \
	--rpc-url http://localhost:8545  \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--broadcast \
	--verbosity -vvv

deploy :; forge script script/Deploy${contract}.s.sol:Deploy${contract} \
	--chain-id ${chain} \
	--rpc-url ${rpc}  \
	--account ${account} \
	--etherscan-api-key ${ETHERSCAN_API_KEY} \
	--broadcast \
	--verify

cover :; forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

# Show only src file coverage (excludes test/script files from display)
cover-src :; @forge coverage 2>&1 | grep -E "^\| src/|^\| File|^[+╭╰]|Total"

show  :; npx http-server ./coverage

clean :; rm -rf out coverage lcov.info cache artifacts

# Deploy mock tokens for testing
deploy-erc20-anvil :; forge script script/MockERC20.s.sol:DeployMockERC20 \
	--rpc-url http://localhost:8545 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--broadcast \
	--verbosity -vvv

deploy-erc721-anvil :; forge script script/MockERC721.s.sol:DeployMockERC721 \
	--rpc-url http://localhost:8545 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--broadcast \
	--verbosity -vvv


# Deploy Registry, Factory, MockERC20, and MockERC721 to anvil
# Writes factory + other addresses to contracts/deployments.json; copies to the app so it reads factory
deploy-all-anvil :
	forge script script/DeployAllAnvil.s.sol:DeployAllAnvil \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast \
		--verbosity -vvv
	@if [ -f deployments.json ] && [ -d ../app/contracts ]; then \
		cp deployments.json ../app/contracts/deployments.json; \
		echo "Copied deployments.json (including factory) to app/contracts/deployments.json"; \
	fi

# Alias used by the app (`make deploy-anvil-all`)
deploy-anvil-all : deploy-all-anvil

# Sync ABIs from compiled contracts to the app
sync-abis :; node script/sync-abis.js

# Full local development setup: deploy contracts + sync ABIs
# Usage: Start anvil in one terminal, then run `make setup-local` in another
setup-local :; $(MAKE) deploy-all-anvil && $(MAKE) sync-abis

# --- Loreum mainnet assets on forked Anvil (set RPC_URL=mainnet in .env, run `make anvil`) ---

# Print governance ERC20 name, symbol, decimals
loreum-gov-info :
	@printf 'Governance %s\n' '$(LOREUM_GOV_TOKEN)'
	@cast call $(LOREUM_GOV_TOKEN) "name()(string)" --rpc-url $(ANVIL_RPC)
	@cast call $(LOREUM_GOV_TOKEN) "symbol()(string)" --rpc-url $(ANVIL_RPC)
	@cast call $(LOREUM_GOV_TOKEN) "decimals()(uint8)" --rpc-url $(ANVIL_RPC)

# RECIPIENT=0x... — balance of governance tokens (wei / smallest unit)
loreum-gov-balance :
	@test -n "$(RECIPIENT)" || (echo 'Set RECIPIENT=0x...'; exit 1)
	cast call $(LOREUM_GOV_TOKEN) "balanceOf(address)(uint256)" $(RECIPIENT) --rpc-url $(ANVIL_RPC)

# TOKEN_ID=1 — owner of membership ERC721 on the fork
loreum-membership-owner-of :
	@test -n "$(TOKEN_ID)" || (echo 'Set TOKEN_ID=<uint256>'; exit 1)
	cast call $(LOREUM_MEMBERSHIP_NFT) "ownerOf(uint256)(address)" $(TOKEN_ID) --rpc-url $(ANVIL_RPC)

# Transfer ERC20 from a mainnet holder into your test wallet (impersonation; fork only)
# LOREUM_FROM: HOLDER= or HODLER= (typo); must hold balance on the fork. AMOUNT_WEI = raw units.
# Example: make loreum-fund-gov HOLDER=0x... AMOUNT_WEI=1000000000000000000 TO=$(ANVIL_ADDR0)
loreum-fund-gov :
	@test -n "$(LOREUM_FROM)" || (echo 'Set HOLDER=0x... or HODLER=0x... (address with tokens on fork)'; exit 1)
	@test -n "$(AMOUNT_WEI)" || (echo 'Set AMOUNT_WEI=<uint256>'; exit 1)
	$(eval TO := $(if $(TO),$(TO),$(ANVIL_ADDR0)))
	cast rpc anvil_impersonateAccount $(LOREUM_FROM) --rpc-url $(ANVIL_RPC)
	cast rpc anvil_setBalance $(LOREUM_FROM) 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF --rpc-url $(ANVIL_RPC)
	cast send $(LOREUM_GOV_TOKEN) "transfer(address,uint256)" $(TO) $(AMOUNT_WEI) \
		--rpc-url $(ANVIL_RPC) --from $(LOREUM_FROM) --unlocked --legacy
	cast rpc anvil_stopImpersonatingAccount $(LOREUM_FROM) --rpc-url $(ANVIL_RPC)

# Transfer one membership NFT to TO (impersonation; fork only)
# Always uses onchain ownerOf(TOKEN_ID). If HOLDER/HODLER set, must match that owner (otherwise fails).
# If TO already owns the token, skips transfer (idempotent).
# Example: make loreum-fund-membership TOKEN_ID=5 TO=$(ANVIL_ADDR0)
# Example: make loreum-fund-membership HOLDER=0x... TOKEN_ID=1
loreum-fund-membership :
	@test -n "$(TOKEN_ID)" || (echo 'Set TOKEN_ID=<uint256>'; exit 1)
	@TO_RAW="$(strip $(if $(TO),$(TO),$(ANVIL_ADDR0)))"; \
	TO=$$(printf '%s' "$$TO_RAW" | tr '[:upper:]' '[:lower:]'); \
	case "$$TO" in \
	  0x????????????????????????????????????????) ;; \
	  *) echo "Bad TO address: '$$TO_RAW'"; exit 1;; \
	esac; \
	ONCHAIN=$$(cast call $(LOREUM_MEMBERSHIP_NFT) "ownerOf(uint256)(address)" $(TOKEN_ID) --rpc-url $(ANVIL_RPC)); \
	ONCHAIN=$$(printf '%s' "$$ONCHAIN" | tr -d '\r\n' | sed 's/^[[:space:]"]*//;s/[[:space:]"]*$$//' | tr '[:upper:]' '[:lower:]'); \
	if ! printf '%s' "$$ONCHAIN" | grep -qE '^0x[0-9a-f]{40}$$'; then \
	  echo "Could not read ownerOf($(TOKEN_ID)): '$$ONCHAIN'"; exit 1; \
	fi; \
	if [ "$$ONCHAIN" = "$$TO" ]; then \
	  echo "Token $(TOKEN_ID) already owned by $$TO; skipping transfer."; \
	  exit 0; \
	fi; \
	FROM="$(strip $(or $(HOLDER),$(HODLER)))"; \
	FROM=$$(printf '%s' "$$FROM" | tr '[:upper:]' '[:lower:]'); \
	if [ -n "$$FROM" ]; then \
	  if [ "$$FROM" != "$$ONCHAIN" ]; then \
	    echo "HOLDER/HODLER $$FROM is not ownerOf(token $(TOKEN_ID)); onchain owner is $$ONCHAIN"; \
	    echo "Omit HOLDER to impersonate the real owner, or fix HOLDER/TOKEN_ID."; \
	    exit 1; \
	  fi; \
	else \
	  FROM="$$ONCHAIN"; \
	fi; \
	echo "Membership token $(TOKEN_ID): onchain owner $$FROM -> transfer to $$TO"; \
	cast rpc anvil_impersonateAccount $$FROM --rpc-url $(ANVIL_RPC); \
	cast rpc anvil_setBalance $$FROM 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF --rpc-url $(ANVIL_RPC); \
	cast send $(LOREUM_MEMBERSHIP_NFT) \
		"safeTransferFrom(address,address,uint256)" $$FROM $$TO_RAW $(TOKEN_ID) \
		--rpc-url $(ANVIL_RPC) --from $$FROM --unlocked --legacy; \
	cast rpc anvil_stopImpersonatingAccount $$FROM --rpc-url $(ANVIL_RPC)

# One shot: membership NFT + governance ERC20 to LOREUM_LOCAL_FUND_TO (mainnet fork + make anvil)
loreum-fund-local :
	$(MAKE) loreum-fund-membership \
		TOKEN_ID=$(LOREUM_LOCAL_MEMBERSHIP_TOKEN_ID) \
		TO=$(LOREUM_LOCAL_FUND_TO) \
		$(if $(strip $(LOREUM_LOCAL_MEMBERSHIP_HOLDER)),HOLDER=$(LOREUM_LOCAL_MEMBERSHIP_HOLDER))
	$(MAKE) loreum-fund-gov \
		HODLER=$(LOREUM_LOCAL_GOV_HODLER) \
		AMOUNT_WEI=$(LOREUM_LOCAL_GOV_AMOUNT_WEI) \
		TO=$(LOREUM_LOCAL_FUND_TO)

# One command: 10 membership NFTs (LOREUM_WALLET_TOKEN_IDS) + LOREUM_WALLET_LORE tokens to WALLET
# Usage: make loreum-fund-wallet WALLET=0x...
#        make loreum-fund-wallet TO=0x...   (alias)
# Requires LOREUM_WALLET_GOV_HODLER to hold enough LORE on the fork (see LOREUM_LOCAL_GOV_HODLER)
loreum-fund-wallet :
	@ADDR="$(strip $(or $(WALLET),$(TO)))"; \
	case "$$ADDR" in \
	  "") echo 'Set WALLET=0x... (or TO=0x...) for the local test wallet'; exit 1;; \
	  0x????????????????????????????????????????) ;; \
	  *) echo "Bad WALLET/TO: $$ADDR"; exit 1;; \
	esac; \
	for id in $(LOREUM_WALLET_TOKEN_IDS); do \
	  echo ">>> Membership token $$id -> $$ADDR"; \
	  $(MAKE) loreum-fund-membership TOKEN_ID=$$id TO="$$ADDR" || exit 1; \
	done; \
	GOV_WEI=$$(cast to-wei $(LOREUM_WALLET_LORE) ether); \
	echo ">>> LORE $$GOV_WEI wei ($(LOREUM_WALLET_LORE) tokens) -> $$ADDR"; \
	$(MAKE) loreum-fund-gov HODLER=$(LOREUM_WALLET_GOV_HODLER) AMOUNT_WEI="$$GOV_WEI" TO="$$ADDR"; \
	echo "Done. Verify: make loreum-gov-balance RECIPIENT=$$ADDR"

deploy-erc20 :; forge script script/MockERC20.s.sol:DeployMockERC20 \
	--chain-id ${chain} \
	--rpc-url ${rpc} \
	--account ${account} \
	--broadcast \
	--verify

deploy-erc721 :; forge script script/MockERC721.s.sol:DeployMockERC721 \
	--chain-id ${chain} \
	--rpc-url ${rpc} \
	--account ${account} \
	--broadcast \
	--verify

# Demo ERC-20 + membership ERC-721 (Sepolia or any rpc). Copy printed addresses into deployments/sepolia.txt.
# Example: make deploy-sepolia-mocks rpc=$SEPOLIA_RPC_URL account=deployer
deploy-sepolia-mocks :; forge script script/DeploySepoliaMocks.s.sol:DeploySepoliaMocks \
	--rpc-url ${rpc} \
	--account ${account} \
	--broadcast

verify :; forge verify-contract \
	--chain-id ${chain} \
	--num-of-optimizations ${runs} \
	--constructor-args ${args} \
	--watch  \
	--compiler-version ${compiler} \
	--etherscan-api-key ${etherscan} \
	${address} \
	src/${contract}.sol:${contract}

# Sepolia Factory path (26 Aug 2026): BoardLib, WalletLib, Chamber impl, Factory.
# Addresses + verify URLs: deployments/sepolia.txt
# Requires ETHERSCAN_API_KEY (foundry.toml [etherscan].sepolia) and SEPOLIA_RPC_URL.
# Usage: make verify-sepolia-factory
# Print only: PRINT_ONLY=1 make verify-sepolia-factory
verify-sepolia-factory :; bash script/etherscan-verify-sepolia-factory.sh


call :; cast call ${address} ${method} ${args} \
	--chain-id ${chain} \
	--rpc-url ${rpc} \
	--private-key ${private}

# Typed operator CLI (same Chamber ABI as the app). See packages/operator.
# Example: make operator-board CHAMBER=0x...
OPERATOR_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../packages/operator)
OPERATOR_RPC ?= $(ANVIL_RPC)
OPERATOR_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

operator-board :
	@test -n "$(CHAMBER)" || (echo 'Set CHAMBER=0x...'; exit 1)
	cd $(OPERATOR_DIR) && npx --yes tsx src/cli.ts board --rpc $(OPERATOR_RPC) --chamber $(CHAMBER)

operator-e2e :
	cd $(OPERATOR_DIR) && npm run example:anvil

