<img style="{align: right}" src="https://cdn.loreum.org/logos/black.png"  height="50"/>

# Chamber Multisig

![Foundry CI](https://github.com/loreum-org/chamber/actions/workflows/forge.yaml/badge.svg)
[![GitBook - Documentation](https://img.shields.io/badge/GitBook-Documentation-orange?logo=gitbook&logoColor=white)](https://docs.loreum.org/blog)
[![License: BUSL 1.1](https://img.shields.io/badge/License-MIT.svg)](https://github.com/loreum-org/chamber/LICENSE)

The Chamber is a multisig wallet that enables liquid democracy for Treasury and Protocol Management by the token community. Due to their composability, Chambers are a protocol governance standard that enables Access Control Roles to be controlled by token holders through representative leaders, rather than a core group of static founders. This enables decentralized ownership of DeFi protocols.
Chambers provide the functionality of a multisig wallet where signers are determined by delegation of ERC20 governance tokens.

The contract inherits upon instantiation existing ERC20 governance and ERC721 membership tokens. Delegations are made to ERC721 tokens which creates a leaderboard within the Chamber contract. The leaders are responsible for signing transactions and being the governors of the multisig. Each leader has a single vote that is not correlated to wallet balance, but rather by delegation of ERC20 governance tokens by the community against their NFT TokenId.

## Use Cases

1. **Treasury Multisig**

The primary use cases for a chmaber contract is to be a treasury multisig wallet that owns the various roles and assets of a DAO or DeFi protocol. It's intended to be a drop-in replacement for the "Gnosis" Safe Multisig wallet.

2. **DeFi Composability**

Chambers are composable by inheriting any exisitng governance ERC20 token accross a number of Chambers and Sub Chambers. This horizontal and veritical composibility creates utility and intrinsic scarcity of governance tokens.

```mermaid
  graph TD;
      A[Dao Chamber]-->B[Sub Chamber];
      A[Dao Chamber]-->|claimYield|B[Sub Chamber];
      C[Vault 1]-->|true|B;
      D[Vault 2]-->|uint256|B;
      B-->|onlyOwner|C;
      B-->A;
      B-->|compound|D;
```

3. **DAO Governance**

Instantiating a Chamber with the same ERC20 and ERC721 tokens as used in common with the token-econmic model creates a shared value system. Voting power to control assets depends on token delegation which can migrate, but not inflate or dilute voting power across the various Chambers. The scarcity of total supply extends to limit the authority of token balances.


Each Chamber is created with a designated number of leaders and a quorum. Each leader has a single vote and is represented by an NFT tokenId. If a member of the community removes their delegatation to a tokenId, that leader may be removed from the leaderboard and lose their ability to approve transaction proposals. Leaders have multisig signing authority only so long as their delegation places them at the top of the leaderboard. This creates a representative board of decision makers based on revocable authority by delegation.

### Setup

```
git submodule update --init --recursive
```

### Foundry

```
forge build
forge test

# You know what to do
```

## Deployments

### Sepolia

| Contract                    | Address                                                                                   |
|-----------------------------|-------------------------------------------------------------------------------------------|
| Chamber Implementation      | [`0x6De681547f6CA500b79D00Ea2f82640CF9C4B3a2`](https://sepolia.etherscan.io/address/0x6De681547f6CA500b79D00Ea2f82640CF9C4B3a2) |
| Chamber MultiBeacon         | [`0x4DA17EDf94f867bE75168C4bA03A0C7518989f6B`](https://sepolia.etherscan.io/address/0x4DA17EDf94f867bE75168C4bA03A0C7518989f6B) |
| Registry Implementation     | [`0x85Eb32381e82B0aAEb4bC540161079768ea83949`](https://sepolia.etherscan.io/address/0x85Eb32381e82B0aAEb4bC540161079768ea83949) |
| Registry Beacon             | [`0x59cA451f93E2903959068Be8EF9A8Ca9540739DD`](https://sepolia.etherscan.io/address/0x59cA451f93E2903959068Be8EF9A8Ca9540739DD) |
| Registry Proxy              | [`0x05a73a44B475FEdB75194383D81A4cfFd6f74FFd`](https://sepolia.etherscan.io/address/0x05a73a44B475FEdB75194383D81A4cfFd6f74FFd) |
| BLKH NFT                    | [`0xe02A8f23c19280dd828Eb5CA5EC89d64345f06d8`](https://sepolia.etherscan.io/address/0xe02A8f23c19280dd828Eb5CA5EC89d64345f06d8) |
| LORE Token                  | [`0xd6a10328D8cd00747031daef6a12f811F4eA0A37`](https://sepolia.etherscan.io/address/0xd6a10328D8cd00747031daef6a12f811F4eA0A37) |


## Chamber.sol

```mermaid
sequenceDiagram
    participant User
    participant Chamber
    participant IERC721
    participant IERC20
    participant IGuard

    Note over User,Chamber: Initialization
    User->>Chamber: initialize(_memberToken, _govToken)
    Chamber->>IERC721: verify(_memberToken is valid)
    Chamber->>IERC20: verify(_govToken is valid)
    Chamber-->>User: Initialization Complete

    Note over User,Chamber: Proposal Creation
    User->>Chamber: create(_target, _value, _data)
    Chamber->>IERC721: balanceOf(_msgSender())
    alt balance < 1
        Chamber-->>User: revert insufficientBalance()
    else balance >= 1
        Chamber->>Chamber: nonce++
        Chamber->>Chamber: store Proposal
        Chamber-->>User: emit ProposalCreated
    end

    Note over User,Chamber: Proposal Approval
    User->>Chamber: approve(_proposalId, _tokenId, _signature)
    Chamber->>IERC721: ownerOf(_tokenId)
    alt sender != NFT owner
        Chamber-->>User: revert invalidApproval("Sender isn't NFT owner")
    else sender == NFT owner
        Chamber->>Chamber: verifySignature(_proposalId, _tokenId, _signature)
        alt signature invalid
            Chamber-->>User: "Invalid signature"
        else signature valid
            Chamber->>Chamber: mark _tokenId as voted
            Chamber->>Chamber: increment proposal approvals
            Chamber-->>User: emit ProposalApproved
        end
    end

    Note over User,Chamber: Proposal Execution
    User->>Chamber: execute(_proposalId, _tokenId, _signature)
    Chamber->>Chamber: verifySignature(_proposalId, _tokenId, _signature)
    Chamber->>Chamber: check proposal state and approvals
    Chamber->>IGuard: checkTransaction(...)
    Chamber->>Chamber: execute proposal actions
    Chamber->>IGuard: checkAfterExecution(...)
    Chamber-->>User: emit ProposalExecuted

    Note over User,Chamber: Promotion and Demotion
    User->>Chamber: promote(_amt, _tokenId) / demote(_amt, _tokenId)
    Chamber->>IERC20: safeTransferFrom / safeTransfer(...)
    Chamber->>Chamber: update totalDelegation and accountDelegation
    Chamber->>Chamber: updateLeaderboard()
    Chamber-->>User: emit Promoted / Demoted
```

## Registry.sol

```mermaid
sequenceDiagram
    participant User
    participant Registry
    participant MultiProxy
    participant IChamber

    Note over User,Registry: Initialization
    User->>Registry: initialize(_chamberBeacon, _owner)
    Registry->>Registry: _transferOwnership(_owner)
    Registry-->>User: Initialization Complete

    Note over User,Registry: Set Chamber Beacon
    User->>Registry: setChamberBeacon(_chamberBeacon)
    alt onlyOwner
        Registry->>Registry: chamberBeacon = _chamberBeacon
        Registry-->>User: Beacon Updated
    else notOwner
        Registry-->>User: revert "Not owner"
    end

    Note over User,Registry: Get Chambers
    User->>Registry: getChambers(limit, skip)
    alt limit > totalChambers
        Registry->>Registry: Adjust limit to totalChambers
    end
    Registry->>Registry: Collect Chambers Data
    Registry-->>User: Return Chambers Data

    Note over User,Registry: Deploy Chamber
    User->>Registry: deploy(_memberToken, _govToken)
    Registry->>IChamber: encode initialize.selector
    Registry->>MultiProxy: new MultiProxy(chamberBeacon, data, msg.sender)
    MultiProxy->>Registry: Return new chamber address
    Registry->>Registry: Store Chamber Data
    Registry-->>User: emit ChamberDeployed
    Registry-->>User: Return new chamber address
```