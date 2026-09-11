export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as `0x${string}`

export function isNonZeroAddress(addr: string | undefined): addr is `0x${string}` {
  return !!addr && addr !== ZERO_ADDRESS && addr.startsWith('0x') && addr.length === 42
}

/** Solidity `address.code.length > 0` — empty or missing bytecode is an EOA. */
export function isOnchainContractBytecode(bytecode: `0x${string}` | undefined | null): boolean {
  return !!bytecode && bytecode !== '0x' && bytecode.length > 2
}
