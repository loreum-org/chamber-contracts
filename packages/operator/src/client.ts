import {
  type Account,
  type Address,
  type Chain,
  type Hex,
  type PublicClient,
  type TransactionReceipt,
  type WalletClient,
  createPublicClient,
  createWalletClient,
  decodeEventLog,
  defineChain,
  http,
  isHex,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { chamberAbi } from './abi.ts'
import { ChamberOperatorError, wrapChamberError } from './errors.ts'
import { isSeatingMature } from './seating.ts'

export type { Account, Address, Hex, PublicClient, WalletClient }

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as const

export type OperatorSigner =
  | { type: 'privateKey'; privateKey: Hex }
  | { type: 'account'; account: Account }
  | { type: 'walletClient'; walletClient: WalletClient }

export type CreateOperatorOptions = {
  rpcUrl: string
  chamber: Address
  /** EOA key, viem Account, or a prebuilt wallet client (including a 4337 smart-account client). */
  signer?: OperatorSigner
  chain?: Chain
}

export type BoardMember = {
  tokenId: bigint
  amount: bigint
  rank: number
  director?: Address
  seatedAt: bigint
  seatingMature: boolean
}

export type BoardSnapshot = {
  chamber: Address
  name?: string
  symbol?: string
  seats: bigint
  quorum: bigint
  paused: boolean
  blockNumber: bigint
  members: BoardMember[]
}

export type TransactionSnapshot = {
  nonce: bigint
  executed: boolean
  confirmations: number
  target: Address
  value: bigint
  dataHash: Hex
  expired: boolean
  deadline: bigint
  requiredQuorum: bigint
}

export type WriteResult = {
  hash: Hex
  receipt: TransactionReceipt
}

export type SubmitResult = WriteResult & { nonce: bigint }

function assertAddress(value: string, label: string): Address {
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new ChamberOperatorError(`Invalid ${label} address: ${value}`)
  }
  return value as Address
}

function toHexData(data: string | Hex | undefined): Hex {
  if (data == null || data === '') return '0x'
  if (!isHex(data)) {
    throw new ChamberOperatorError(`Invalid hex data: ${data}`)
  }
  return data
}

async function resolveChain(rpcUrl: string, explicit?: Chain): Promise<Chain> {
  if (explicit) return explicit
  const probe = createPublicClient({ transport: http(rpcUrl) })
  const chainId = await probe.getChainId()
  return defineChain({
    id: chainId,
    name: `chain-${chainId}`,
    nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  })
}

export class ChamberOperator {
  readonly rpcUrl: string
  readonly chamber: Address
  readonly publicClient: PublicClient
  readonly walletClient?: WalletClient
  readonly account?: Account

  private constructor(opts: {
    rpcUrl: string
    chamber: Address
    publicClient: PublicClient
    walletClient?: WalletClient
    account?: Account
  }) {
    this.rpcUrl = opts.rpcUrl
    this.chamber = opts.chamber
    this.publicClient = opts.publicClient
    this.walletClient = opts.walletClient
    this.account = opts.account
  }

  static async create(options: CreateOperatorOptions): Promise<ChamberOperator> {
    const chamber = assertAddress(options.chamber, 'chamber')
    const chain = await resolveChain(options.rpcUrl, options.chain)
    const publicClient = createPublicClient({
      chain,
      transport: http(options.rpcUrl),
      cacheTime: 0,
    })

    let account: Account | undefined
    let walletClient: WalletClient | undefined

    if (options.signer?.type === 'walletClient') {
      walletClient = options.signer.walletClient
      account = walletClient.account
    } else if (options.signer?.type === 'account') {
      account = options.signer.account
      walletClient = createWalletClient({
        account,
        chain,
        transport: http(options.rpcUrl),
      })
    } else if (options.signer?.type === 'privateKey') {
      account = privateKeyToAccount(options.signer.privateKey)
      walletClient = createWalletClient({
        account,
        chain,
        transport: http(options.rpcUrl),
      })
    }

    return new ChamberOperator({
      rpcUrl: options.rpcUrl,
      chamber,
      publicClient,
      walletClient,
      account,
    })
  }

  private requireWallet(): { walletClient: WalletClient; account: Account } {
    if (!this.walletClient || !this.account) {
      throw new ChamberOperatorError(
        'A signer is required for writes. Pass a private key, viem Account, or 4337 wallet client.',
      )
    }
    return { walletClient: this.walletClient, account: this.account }
  }

  private async write<
    TFunctionName extends
      | 'delegate'
      | 'confirmTransaction'
      | 'executeTransaction'
      | 'submitTransaction'
      | 'setDirectorOperator',
  >(
    functionName: TFunctionName,
    args: readonly unknown[],
  ): Promise<WriteResult> {
    const { walletClient, account } = this.requireWallet()
    try {
      await this.publicClient.simulateContract({
        address: this.chamber,
        abi: chamberAbi,
        functionName,
        args: args as never,
        account,
      })
      const hash = await walletClient.writeContract({
        address: this.chamber,
        abi: chamberAbi,
        functionName,
        args: args as never,
        account,
        chain: walletClient.chain ?? null,
      } as never)
      const receipt = await this.publicClient.waitForTransactionReceipt({ hash })
      if (receipt.status !== 'success') {
        throw new ChamberOperatorError('Transaction failed')
      }
      return { hash, receipt }
    } catch (error) {
      throw wrapChamberError(error)
    }
  }

  async getQuorum(): Promise<bigint> {
    try {
      return await this.publicClient.readContract({
        address: this.chamber,
        abi: chamberAbi,
        functionName: 'getQuorum',
      })
    } catch (error) {
      throw wrapChamberError(error, 'Failed to read quorum')
    }
  }

  async getBoard(count?: bigint): Promise<BoardSnapshot> {
    try {
      const [seats, quorum, paused, blockNumber, name, symbol] = await Promise.all([
        this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'getSeats',
        }),
        this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'getQuorum',
        }),
        this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'paused',
        }),
        this.publicClient.getBlockNumber(),
        this.publicClient
          .readContract({
            address: this.chamber,
            abi: chamberAbi,
            functionName: 'name',
          })
          .catch(() => undefined),
        this.publicClient
          .readContract({
            address: this.chamber,
            abi: chamberAbi,
            functionName: 'symbol',
          })
          .catch(() => undefined),
      ])

      const topCount = count ?? (seats > 0n ? seats : 20n)
      const [tokenIds, amounts] = await this.publicClient.readContract({
        address: this.chamber,
        abi: chamberAbi,
        functionName: 'getTop',
        args: [topCount],
      })

      let directors: readonly Address[] = []
      try {
        directors = await this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'getDirectors',
        })
      } catch {
        directors = []
      }

      const seatedAtList = await Promise.all(
        tokenIds.map((tokenId) =>
          this.publicClient.readContract({
            address: this.chamber,
            abi: chamberAbi,
            functionName: 'getSeatedAt',
            args: [tokenId],
          }),
        ),
      )

      const members: BoardMember[] = tokenIds.map((tokenId, i) => {
        const seatedAt = seatedAtList[i] ?? 0n
        const director = directors[i]
        return {
          tokenId,
          amount: amounts[i] ?? 0n,
          rank: i + 1,
          director:
            director && director.toLowerCase() !== ZERO_ADDRESS.toLowerCase()
              ? director
              : undefined,
          seatedAt,
          seatingMature: isSeatingMature(seatedAt, blockNumber),
        }
      })

      return {
        chamber: this.chamber,
        name,
        symbol,
        seats,
        quorum,
        paused,
        blockNumber,
        members,
      }
    } catch (error) {
      throw wrapChamberError(error, 'Failed to read board')
    }
  }

  async getTransaction(nonce: bigint): Promise<TransactionSnapshot> {
    try {
      const [executed, confirmations, target, value, dataHash] =
        await this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'getTransaction',
          args: [nonce],
        })
      const [expired, deadline, requiredQuorum] = await Promise.all([
        this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'isTransactionExpired',
          args: [nonce],
        }),
        this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'getTransactionDeadline',
          args: [nonce],
        }),
        this.publicClient.readContract({
          address: this.chamber,
          abi: chamberAbi,
          functionName: 'getTransactionRequiredQuorum',
          args: [nonce],
        }),
      ])
      return {
        nonce,
        executed,
        confirmations,
        target,
        value,
        dataHash,
        expired,
        deadline,
        requiredQuorum,
      }
    } catch (error) {
      throw wrapChamberError(error, 'Failed to read transaction')
    }
  }

  async delegate(tokenId: bigint, amount: bigint): Promise<WriteResult> {
    return this.write('delegate', [tokenId, amount])
  }

  async submitTransaction(args: {
    tokenId: bigint
    target: Address
    value?: bigint
    data?: Hex | string
    deadline?: bigint
  }): Promise<SubmitResult> {
    const target = assertAddress(args.target, 'target')
    const value = args.value ?? 0n
    const data = toHexData(args.data)
    const writeArgs =
      args.deadline !== undefined
        ? ([args.tokenId, target, value, data, args.deadline] as const)
        : ([args.tokenId, target, value, data] as const)
    const result = await this.write('submitTransaction', writeArgs)
    return { ...result, nonce: nonceFromSubmitReceipt(result.receipt, this.chamber) }
  }

  async confirm(tokenId: bigint, nonce: bigint): Promise<WriteResult> {
    return this.write('confirmTransaction', [tokenId, nonce])
  }

  async execute(tokenId: bigint, nonce: bigint, data: Hex | string = '0x'): Promise<WriteResult> {
    return this.write('executeTransaction', [tokenId, nonce, toHexData(data)])
  }

  /**
   * Live session key for `tokenId`, or `address(0)` if unset, stale, or the
   * NFT is EOA-owned. Chamber never consults ERC-1271.
   */
  async getDirectorOperator(tokenId: bigint): Promise<Address> {
    try {
      return await this.publicClient.readContract({
        address: this.chamber,
        abi: chamberAbi,
        functionName: 'getDirectorOperator',
        args: [tokenId],
      })
    } catch (error) {
      throw wrapChamberError(error, 'Failed to read director operator')
    }
  }

  /**
   * Register (or replace) the session key. `msg.sender` must be the current
   * contract owner of `tokenId`. EOA-owned NFTs revert `NotDirector`.
   */
  async setDirectorOperator(tokenId: bigint, operator: Address): Promise<WriteResult> {
    return this.write('setDirectorOperator', [tokenId, assertAddress(operator, 'operator')])
  }

  /** Clear the session key (`setDirectorOperator(tokenId, address(0))`). */
  async clearDirectorOperator(tokenId: bigint): Promise<WriteResult> {
    return this.setDirectorOperator(tokenId, ZERO_ADDRESS)
  }
}

function nonceFromSubmitReceipt(receipt: TransactionReceipt, chamber: Address): bigint {
  for (const log of receipt.logs) {
    if (log.address.toLowerCase() !== chamber.toLowerCase()) continue
    try {
      const decoded = decodeEventLog({
        abi: chamberAbi,
        data: log.data,
        topics: log.topics,
      })
      if (decoded.eventName === 'TransactionSubmitted') {
        const args = decoded.args as { transactionId?: bigint }
        if (args.transactionId !== undefined) return args.transactionId
      }
      if (decoded.eventName === 'SubmitTransaction') {
        const args = decoded.args as { nonce?: bigint }
        if (args.nonce !== undefined) return args.nonce
      }
    } catch {
      // not a matching event
    }
  }
  throw new ChamberOperatorError('Submit succeeded but no TransactionSubmitted event was found')
}

export async function createOperator(options: CreateOperatorOptions): Promise<ChamberOperator> {
  return ChamberOperator.create(options)
}
