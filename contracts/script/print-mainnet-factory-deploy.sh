#!/usr/bin/env bash
# Print the human-run Ethereum mainnet Factory + createChamber + verify commands.
# This script never broadcasts. It refuses --broadcast on its own argv.
#
# From contracts/:
#   make print-mainnet-factory-deploy
#   bash script/print-mainnet-factory-deploy.sh
set -euo pipefail

for arg in "$@"; do
	if [[ "$arg" == "--broadcast" || "$arg" == "--resume" ]]; then
		echo "print-mainnet-factory-deploy never broadcasts. Omit --broadcast." >&2
		exit 1
	fi
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ADMIN="${ADMIN:-0x5d45A213B2B6259F0b3c116a8907B56AB5E22095}"
LORE="0x7756D245527F5f8925A537be509BF54feb2FdC99"
NFT="0xB99DEdbDe082B8Be86f06449f2fC7b9FED044E15"

cat <<EOF
# Ethereum mainnet verified deploy package (print only)
# =====================================================
# Deploy remains blocked on PMN-H01 (#208) until accepted or fixed.
# #209–#212 are open mediums. PRs #213 and #206 are unmerged.
# This Make target / script does not pass --broadcast.
# Safe transferOwnership is human-only — not in these scripts.
#
# Required env (do not commit):
#   MAINNET_RPC_URL or ETH_RPC_URL     Ethereum archive/full RPC
#   ETHERSCAN_API_KEY                  Etherscan v2 key (foundry.toml [etherscan].mainnet)
#   account / keystore                 Foundry --account (or --private-key locally)
# After #208 is accepted or fixed ONLY:
#   MAINNET_DEPLOY_UNBLOCKED=1
#
# Order: Factory (+ libs + Chamber impl) → verify → createChamber → paste Chamber.
# Factory.createChamber uses CREATE (no salt). Do not pre-commit a Chamber address.
# Sepolia Factory 0x43aA92c8A26392f21F63cdA88B6BaB5031C40550 is reference only.

# 0) Fork rehearsal (never --broadcast)
export MAINNET_RPC_URL="\${MAINNET_RPC_URL:?set MAINNET_RPC_URL}"
make rehearse-mainnet-lore-handoff
# or: make rehearse-mainnet-lore-handoff-script

# 1) Dry-run the Factory script on a fork (omit --broadcast)
forge script script/DeployMainnetFactory.s.sol:DeployMainnetFactory \\
  --fork-url "\$MAINNET_RPC_URL" -vvv

# 2) Human broadcast — only after #208 accepted or fixed
#    ADMIN defaults to team Safe ${ADMIN}
# export MAINNET_DEPLOY_UNBLOCKED=1
# export ADMIN=${ADMIN}
# forge script script/DeployMainnetFactory.s.sol:DeployMainnetFactory \\
#   --rpc-url "\$MAINNET_RPC_URL" --account "\$ACCOUNT" --broadcast --chain-id 1 -vvv
#
# Extract labeled addrs from the receipt (does not write mainnet.txt):
#   bash script/extract-mainnet-broadcast.sh broadcast/DeployMainnetFactory.s.sol/1/run-latest.json
# Paste Factory, Chamber implementation, BoardLib, WalletLib into deployments/mainnet.txt.

# 3) Verify (libs first, then Chamber impl, then Factory)
#    Factory constructor: (chamberImplementation, admin=${ADMIN})
# export ETHERSCAN_API_KEY=...
# make verify-mainnet-factory
# Print only: PRINT_ONLY=1 make verify-mainnet-factory

# 4) createChamber — FACTORY from the chain-id-1 receipt, never Sepolia
#    args: erc20=${LORE}
#          erc721=${NFT}
#          seats=5  name='Chamber LORE'  symbol=cLORE
# export MAINNET_DEPLOY_UNBLOCKED=1
# export FACTORY=0x<factory-from-step-2-receipt>
# forge script script/CreateMainnetLoreChamber.s.sol:CreateMainnetLoreChamber \\
#   --rpc-url "\$MAINNET_RPC_URL" --account "\$ACCOUNT" --broadcast --chain-id 1 -vvv
# Paste Chamber (proxy) into deployments/mainnet.txt from that receipt.

# 5) App: set VITE_MAINNET_FACTORY only after verify. getContractAddresses(1)
#    stays empty while deployments/mainnet.txt still says TBD.

# 6) Safe UI / execTransaction: LORE.transferOwnership(chamber) — human only.

See docs/mainnet-verified-deploy.md
EOF
