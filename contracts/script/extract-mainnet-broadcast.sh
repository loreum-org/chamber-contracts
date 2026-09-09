#!/usr/bin/env bash
# Print labeled addresses from a Foundry broadcast JSON (chain id 1).
# Does not write deployments/mainnet.txt and does not treat output as live
# until a human pastes it after verify.
#
# Usage (from contracts/):
#   bash script/extract-mainnet-broadcast.sh broadcast/DeployMainnetFactory.s.sol/1/run-latest.json
#   bash script/extract-mainnet-broadcast.sh broadcast/CreateMainnetLoreChamber.s.sol/1/run-latest.json
set -euo pipefail

FILE="${1:?path to broadcast/*.json}"
[[ -f "$FILE" ]] || { echo "Missing $FILE" >&2; exit 1; }

if ! command -v jq >/dev/null 2>&1; then
	echo "jq is required" >&2
	exit 1
fi

CHAIN="$(jq -r '.chain // .chainId // empty' "$FILE")"
if [[ -n "$CHAIN" && "$CHAIN" != "1" && "$CHAIN" != "0x1" ]]; then
	echo "Refusing to extract: broadcast chain is ${CHAIN}, expected 1." >&2
	exit 1
fi

addr_for() {
	local name="$1"
	jq -r --arg N "$name" '
		[.transactions[]?
			| select((.contractName // "") == $N)
			| (.contractAddress // .additionalContracts[0].address // empty)
		] | map(select(. != null and . != "")) | last // empty
	' "$FILE"
}

lib_from_libraries() {
	local needle="$1"
	jq -r --arg N "$needle" '
		(.libraries // [])
		| map(select(tostring | test($N)))
		| last // empty
		| if type == "string" then (split(":") | last) else empty end
	' "$FILE"
}

BOARD="$(addr_for BoardLib)"
[[ -z "$BOARD" ]] && BOARD="$(lib_from_libraries 'BoardLib')"
WALLET="$(addr_for WalletLib)"
[[ -z "$WALLET" ]] && WALLET="$(lib_from_libraries 'WalletLib')"
FACTORY="$(addr_for Factory)"
CHAMBER_IMPL="$(addr_for Chamber)"
# createChamber returns a proxy; Foundry may label it TransparentUpgradeableProxy.
CHAMBER_PROXY="$(addr_for TransparentUpgradeableProxy)"

echo "# From ${FILE}"
echo "# Paste into deployments/mainnet.txt only after Etherscan verify on chain id 1."
echo "# These lines are a receipt extract, not a claim that mainnet is live."
[[ -n "$BOARD" ]] && echo "BoardLib                  $BOARD"
[[ -n "$WALLET" ]] && echo "WalletLib                 $WALLET"
[[ -n "$FACTORY" ]] && echo "Factory                   $FACTORY"
[[ -n "$CHAMBER_IMPL" ]] && echo "Chamber implementation    $CHAMBER_IMPL"
[[ -n "$CHAMBER_PROXY" ]] && echo "Chamber (proxy)           $CHAMBER_PROXY"

if [[ -z "$FACTORY$CHAMBER_IMPL$BOARD$WALLET$CHAMBER_PROXY" ]]; then
	echo "No Factory / Chamber / lib CREATE rows found. Inspect the JSON." >&2
	exit 1
fi
