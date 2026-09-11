import { FiShield, FiKey } from 'react-icons/fi'
import { shortenAddress } from '@/lib/utils'
import type { DirectorCallerRole } from '@/hooks/useChamber'

export function DirectorCallerStatus({
  role,
  tokenId,
  nftOwner,
  sessionOperator,
}: {
  role: DirectorCallerRole | null
  tokenId?: bigint
  nftOwner?: `0x${string}`
  sessionOperator?: `0x${string}`
}) {
  if (!role || tokenId === undefined) return null

  const member = `Member #${tokenId.toString()}`
  const isOwner = role === 'owner'

  return (
    <div
      className={`mt-4 rounded-xl border px-4 py-3 text-sm ${
        isOwner
          ? 'border-accent-500/30 bg-accent-500/5 text-accent-100'
          : 'border-sky-500/30 bg-sky-500/5 text-sky-100'
      }`}
    >
      <div className="flex items-start gap-2">
        {isOwner ? (
          <FiShield className="w-4 h-4 mt-0.5 shrink-0 text-accent-400" aria-hidden />
        ) : (
          <FiKey className="w-4 h-4 mt-0.5 shrink-0 text-sky-400" aria-hidden />
        )}
        <div>
          {isOwner ? (
            <>
              Connected wallet is the <span className="font-semibold">NFT owner</span> of {member}.
              {sessionOperator ? (
                <>
                  {' '}
                  Session key {shortenAddress(sessionOperator)}.
                </>
              ) : null}
            </>
          ) : (
            <>
              Connected wallet is an <span className="font-semibold">operator</span> (session key) for{' '}
              {member}
              {nftOwner ? (
                <>
                  {' '}
                  — NFT owner {shortenAddress(nftOwner)}
                </>
              ) : null}
              .
            </>
          )}
        </div>
      </div>
    </div>
  )
}
