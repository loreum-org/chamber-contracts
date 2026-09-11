import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { isAddress } from 'viem'
import { useChainModal, useConnectModal } from '@rainbow-me/rainbowkit'
import { FiAlertTriangle, FiLoader, FiRefreshCw } from 'react-icons/fi'
import { useChamberRouteDecision } from '@/hooks/useChamberRouteGate'
import {
  getNetworkName,
  isMainnetConfigured,
} from '@/lib/wagmi'
import type { ChamberRouteDecision } from '@/lib/chamberRoute'

function VerifyingChamber() {
  return (
    <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
      <FiLoader className="w-10 h-10 text-accent-400 animate-spin" />
      <p className="text-slate-400 text-sm">Verifying chamber…</p>
    </div>
  )
}

function InvalidChamberAddress() {
  return (
    <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
      <FiAlertTriangle className="w-12 h-12 text-red-400" />
      <h2 className="font-heading text-xl font-bold text-slate-100">Invalid Address</h2>
      <p className="text-slate-400">The address in this URL is not a valid Ethereum address.</p>
      <Link to="/" className="btn btn-primary">Back to Dashboard</Link>
    </div>
  )
}

function NotAChamber({ chainId }: { chainId: number }) {
  return (
    <div className="flex flex-col items-center justify-center min-h-64 gap-4 text-center">
      <FiAlertTriangle className="w-12 h-12 text-red-400" />
      <h2 className="font-heading text-xl font-bold text-slate-100">Not a Chamber</h2>
      <p className="text-slate-400 max-w-md">
        This address does not look like a Chamber contract on{' '}
        <strong className="text-slate-200">{getNetworkName(chainId)}</strong>.
      </p>
      <Link to="/" className="btn btn-primary">Back to Dashboard</Link>
    </div>
  )
}

export function WrongNetworkPanel({
  currentChainId,
  supportedChainIds,
  targetChainId,
  reason,
}: Extract<ChamberRouteDecision, { status: 'wrong-network' }>) {
  const { isConnected } = useAccount()
  const { switchChainAsync, isPending } = useSwitchChain()
  const { openChainModal } = useChainModal()
  const { openConnectModal } = useConnectModal()

  const currentName = getNetworkName(currentChainId)
  const supportedNames = supportedChainIds.map((id) => getNetworkName(id))
  const targetId =
    targetChainId ?? (supportedChainIds.length === 1 ? supportedChainIds[0] : undefined)
  const targetName = targetId != null ? getNetworkName(targetId) : undefined

  const onSwitch = async () => {
    if (!isConnected) {
      openConnectModal?.()
      return
    }
    if (targetId && switchChainAsync) {
      try {
        await switchChainAsync({ chainId: targetId })
        return
      } catch {
        openChainModal?.()
        return
      }
    }
    openChainModal?.() ?? openConnectModal?.()
  }

  const canSwitch = Boolean(
    openConnectModal || openChainModal || (isConnected && targetId && switchChainAsync),
  )

  return (
    <div className="flex flex-col items-center justify-center min-h-64 px-4">
      <div className="panel w-full max-w-lg p-8 text-center">
        <div className="w-12 h-12 rounded-2xl bg-amber-500/10 border border-amber-500/25 flex items-center justify-center mx-auto mb-5">
          <FiAlertTriangle className="w-6 h-6 text-amber-400" aria-hidden />
        </div>
        <h2 className="font-heading text-xl font-bold text-slate-100">Wrong network</h2>
        <div className="mt-3 space-y-3 text-sm text-slate-400 leading-relaxed">
          <p>
            You&apos;re connected to{' '}
            <strong className="text-slate-200">{currentName}</strong>
            {currentChainId !== 31337 ? (
              <>
                {' '}
                <span className="text-slate-500">(Chain ID: {currentChainId})</span>
              </>
            ) : null}
            .
          </p>
          {reason === 'chamber-on-other-chain' && targetName ? (
            <p>
              This address is a Chamber on{' '}
              <strong className="text-slate-200">{targetName}</strong>. Switch networks to
              keep this deep link.
            </p>
          ) : currentChainId === 1 && !isMainnetConfigured ? (
            <p>
              This deployment does not include <strong className="text-slate-200">Ethereum mainnet</strong>.
              Use your wallet to switch to <strong className="text-slate-200">Sepolia</strong>
              {supportedNames.filter((name) => name !== 'Sepolia').length > 0
                ? ' (or another supported network)'
                : ''}
              .
            </p>
          ) : (
            <p>
              No Factory or Registry address configured for{' '}
              <strong className="text-slate-200">{currentName}</strong>.
              {currentChainId === 31337 ? (
                <>
                  {' '}
                  Deploy contracts to Anvil and set{' '}
                  <code className="text-accent-400">VITE_LOCALHOST_FACTORY</code> or{' '}
                  <code className="text-accent-400">VITE_LOCALHOST_REGISTRY</code>, or switch
                  to a supported network.
                </>
              ) : null}
            </p>
          )}
          {supportedNames.length > 0 && (
            <p className="text-slate-500">
              Supported: <span className="text-slate-300">{supportedNames.join(', ')}</span>
            </p>
          )}
        </div>
        <div className="mt-6 flex flex-col sm:flex-row items-stretch sm:items-center justify-center gap-3">
          {canSwitch ? (
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => void onSwitch()}
              disabled={isPending}
            >
              {isPending ? (
                <FiLoader className="w-4 h-4 animate-spin" aria-hidden />
              ) : (
                <FiRefreshCw className="w-4 h-4" aria-hidden />
              )}
              {targetName ? `Switch to ${targetName}` : 'Switch network'}
            </button>
          ) : null}
          <Link to="/" className={canSwitch ? 'btn btn-secondary' : 'btn btn-primary'}>
            Back to Dashboard
          </Link>
        </div>
      </div>
    </div>
  )
}

export function ChamberRouteGate({
  address,
  children,
}: {
  address: string | undefined
  children: (chamberAddress: `0x${string}`) => ReactNode
}) {
  const chainId = useChainId()
  const validAddress = !!address && isAddress(address)
  const chamberAddr = validAddress ? (address as `0x${string}`) : undefined
  const decision = useChamberRouteDecision(chamberAddr)

  if (!validAddress || decision.status === 'invalid-address') {
    return <InvalidChamberAddress />
  }
  if (decision.status === 'wrong-network') {
    return <WrongNetworkPanel {...decision} />
  }
  if (decision.status === 'loading') {
    return <VerifyingChamber />
  }
  if (decision.status === 'not-chamber') {
    return <NotAChamber chainId={chainId} />
  }
  return <>{children(chamberAddr!)}</>
}
