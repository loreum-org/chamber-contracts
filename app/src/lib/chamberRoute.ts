export type ChamberRouteDecision =
  | { status: 'invalid-address' }
  | { status: 'loading' }
  | { status: 'ready' }
  | { status: 'not-chamber' }
  | {
      status: 'wrong-network'
      reason: 'unconfigured' | 'chamber-on-other-chain'
      currentChainId: number
      supportedChainIds: number[]
      targetChainId?: number
    }

/**
 * Decide chamber-route chrome before treating a failed probe as “Not a Chamber”.
 * Unconfigured chains win immediately. Other configured chains are probed only
 * after the active-chain probe fails.
 */
export function classifyChamberRoute(input: {
  hasAddress: boolean
  currentChainId: number
  configValid: boolean
  supportedChainIds: number[]
  isChamber: boolean | undefined
  foundOnOtherChainId: number | null | undefined
}): ChamberRouteDecision {
  const {
    hasAddress,
    currentChainId,
    configValid,
    supportedChainIds,
    isChamber,
    foundOnOtherChainId,
  } = input

  if (!hasAddress) return { status: 'invalid-address' }

  if (!configValid) {
    const sepoliaId = 11_155_111
    const preferred =
      supportedChainIds.includes(sepoliaId)
        ? sepoliaId
        : supportedChainIds.length === 1
          ? supportedChainIds[0]
          : undefined
    return {
      status: 'wrong-network',
      reason: 'unconfigured',
      currentChainId,
      supportedChainIds,
      targetChainId: preferred,
    }
  }

  if (isChamber === undefined) return { status: 'loading' }
  if (isChamber) return { status: 'ready' }

  const otherConfigured = supportedChainIds.filter((id) => id !== currentChainId)
  if (otherConfigured.length > 0) {
    if (foundOnOtherChainId === undefined) return { status: 'loading' }
    if (foundOnOtherChainId != null) {
      return {
        status: 'wrong-network',
        reason: 'chamber-on-other-chain',
        currentChainId,
        supportedChainIds,
        targetChainId: foundOnOtherChainId,
      }
    }
  }

  return { status: 'not-chamber' }
}
