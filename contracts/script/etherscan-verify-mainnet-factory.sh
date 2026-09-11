#!/usr/bin/env bash
# Verify Ethereum mainnet Factory path on Etherscan:
#   BoardLib, WalletLib, Chamber impl, Factory
# Addresses must be pasted into contracts/deployments/mainnet.txt from a
# chain-id-1 broadcast receipt. TBD is not an address — this script refuses it.
#
# From contracts/:
#   make verify-mainnet-factory
#   PRINT_ONLY=1 make verify-mainnet-factory
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

TXT="$ROOT/deployments/mainnet.txt"
[[ -f "$TXT" ]] || { echo "Missing $TXT" >&2; exit 1; }

labeled_value() {
	local label="$1"
	# Last matching line; last field is the value (TBD or 0x…).
	local line
	line="$(grep -E "^[[:space:]]*${label}[[:space:]]+" "$TXT" | tail -n 1 || true)"
	[[ -n "$line" ]] || { echo "Label '${label}' not found in deployments/mainnet.txt" >&2; exit 1; }
	awk '{print $NF}' <<<"$line"
}

is_addr() {
	[[ "${1:-}" =~ ^0x[a-fA-F0-9]{40}$ ]]
}

FACTORY="$(labeled_value 'Factory')"
CHAMBER="$(labeled_value 'Chamber implementation')"
BOARD_LIB="$(labeled_value 'BoardLib')"
WALLET_LIB="$(labeled_value 'WalletLib')"
# Live team Safe (LORE owner / Factory admin). Not a Chamber/Factory address.
ADMIN=0x5d45A213B2B6259F0b3c116a8907B56AB5E22095

SEPOLIA_FACTORY=0x43aA92c8A26392f21F63cdA88B6BaB5031C40550

for pair in "Factory:${FACTORY}" "Chamber implementation:${CHAMBER}" "BoardLib:${BOARD_LIB}" "WalletLib:${WALLET_LIB}"; do
	name="${pair%%:*}"
	addr="${pair#*:}"
	if ! is_addr "$addr"; then
		echo "deployments/mainnet.txt still has '${name}' = '${addr}'." >&2
		echo "Paste addresses from a verified chain-id-1 broadcast receipt. TBD is not live." >&2
		echo "Print the human commands: make print-mainnet-factory-deploy" >&2
		exit 1
	fi
done

if [[ "${FACTORY,,}" == "${SEPOLIA_FACTORY,,}" ]]; then
	echo "Factory in mainnet.txt is the Sepolia Factory. Do not copy it onto chain id 1." >&2
	exit 1
fi

for addr in "$FACTORY" "$CHAMBER" "$BOARD_LIB" "$WALLET_LIB"; do
	grep -q "$addr" "$TXT" || {
		echo "Address $addr is not in deployments/mainnet.txt — refuse to verify a drifted set." >&2
		exit 1
	}
done

FACTORY_CTOR_ARGS="$(cast abi-encode "constructor(address,address)" "$CHAMBER" "$ADMIN")"

run_or_print() {
	local name="$1" addr="$2"
	local cmd
	cmd="$(bash "$ROOT/script/etherscan-verify-cmd.sh" "$name" "$addr" mainnet)"
	echo "+ $cmd"
	if [[ "${PRINT_ONLY:-}" == "1" ]]; then
		return 0
	fi
	eval "$cmd"
}

if [[ -z "${ETHERSCAN_API_KEY:-}" && "${PRINT_ONLY:-}" != "1" ]]; then
	echo "ETHERSCAN_API_KEY is unset. Printing the four forge verify-contract commands." >&2
	echo "Re-run with the key set: make verify-mainnet-factory" >&2
	echo "" >&2
	PRINT_ONLY=1
	MISSING_KEY=1
fi

# Libraries first, then Chamber (so Etherscan can attach BoardLib + WalletLib), then Factory.
run_or_print BoardLib "$BOARD_LIB"
run_or_print WalletLib "$WALLET_LIB"
BOARD_LIB="$BOARD_LIB" WALLET_LIB="$WALLET_LIB" run_or_print Chamber "$CHAMBER"
CONSTRUCTOR_ARGS="$FACTORY_CTOR_ARGS" run_or_print Factory "$FACTORY"

echo ""
echo "# Ethereum Etherscan (paste only after verify succeeds)"
echo "# Factory                 https://etherscan.io/address/${FACTORY}#code"
echo "# Chamber implementation  https://etherscan.io/address/${CHAMBER}#code"
echo "# BoardLib                https://etherscan.io/address/${BOARD_LIB}#code"
echo "# WalletLib               https://etherscan.io/address/${WALLET_LIB}#code"
echo "# Chamber proxy is a TransparentUpgradeableProxy — verify as proxy after createChamber."

if [[ "${MISSING_KEY:-}" == "1" ]]; then
	exit 2
fi
