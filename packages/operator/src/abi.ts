/**
 * Re-export the generated Chamber ABI. Do not invent a second contract API.
 * Source of truth: `contracts/generated-abis.ts` (`make sync-abis`).
 *
 * #152 added `setDirectorOperator` / `getDirectorOperator` on IChamber. The
 * last synced generated file does not include those entries yet, so the
 * IChamber fragments are appended here. Custom-error decoding still uses the
 * generated ABI (same `wrapChamberError` path as board / queue writes).
 */
import {
  chamberAbi as generatedChamberAbi,
  factoryAbi,
  mockERC20Abi,
  mockERC721Abi,
} from '../../../contracts/generated-abis.ts'

export { factoryAbi, mockERC20Abi, mockERC721Abi }

/** Exact IChamber session-key surface from #152. Not an ERC-1271 fallback. */
export const directorOperatorAbi = [
  {
    type: 'function',
    name: 'getDirectorOperator',
    inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
    outputs: [{ name: 'operator', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'setDirectorOperator',
    inputs: [
      { name: 'tokenId', type: 'uint256', internalType: 'uint256' },
      { name: 'operator', type: 'address', internalType: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'DirectorOperatorSet',
    inputs: [
      { name: 'tokenId', type: 'uint256', indexed: true, internalType: 'uint256' },
      { name: 'owner', type: 'address', indexed: true, internalType: 'address' },
      { name: 'operator', type: 'address', indexed: true, internalType: 'address' },
    ],
    anonymous: false,
  },
] as const

export const chamberAbi = [...generatedChamberAbi, ...directorOperatorAbi] as const
