import { describe, expect, it } from 'vitest'
import { isNonZeroAddress, ZERO_ADDRESS } from './address'

describe('isNonZeroAddress', () => {
  it('rejects missing, zero, and malformed values', () => {
    expect(isNonZeroAddress(undefined)).toBe(false)
    expect(isNonZeroAddress('')).toBe(false)
    expect(isNonZeroAddress(ZERO_ADDRESS)).toBe(false)
    expect(isNonZeroAddress('0xabc')).toBe(false)
  })

  it('accepts a 20-byte hex address', () => {
    expect(isNonZeroAddress('0x1111111111111111111111111111111111111111')).toBe(true)
  })
})
