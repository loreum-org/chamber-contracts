import React from 'react';
import { motion } from 'framer-motion';
import { ArrowLeft } from 'lucide-react';
import { Link } from 'react-router-dom';

const FadeIn = ({ children, delay = 0, className = "" }: { children: React.ReactNode, delay?: number, className?: string }) => (
  <motion.div
    initial={{ opacity: 0, y: 20 }}
    whileInView={{ opacity: 1, y: 0 }}
    viewport={{ once: true }}
    transition={{ duration: 0.8, delay, ease: "easeOut" }}
    className={className}
  >
    {children}
  </motion.div>
);

function Whitepaper() {
  return (
    <div className="min-h-screen bg-space-900 text-white selection:bg-space-accent selection:text-space-900 overflow-hidden relative">
      
      {/* Background Stars Effect */}
      <div className="fixed inset-0 z-0 opacity-40 pointer-events-none">
        <div className="absolute top-10 left-20 w-1 h-1 bg-white rounded-full animate-pulse-slow"></div>
        <div className="absolute top-40 right-40 w-2 h-2 bg-space-accent rounded-full animate-pulse"></div>
        <div className="absolute bottom-20 left-1/3 w-1 h-1 bg-white rounded-full opacity-50"></div>
        <div className="absolute top-1/4 right-10 w-1.5 h-1.5 bg-blue-400 rounded-full animate-pulse-slow delay-700"></div>
        {/* Glowing Orb */}
        <div className="absolute top-[-20%] right-[-10%] w-[800px] h-[800px] bg-blue-900/20 rounded-full blur-[120px]"></div>
        <div className="absolute bottom-[-20%] left-[-10%] w-[600px] h-[600px] bg-purple-900/20 rounded-full blur-[100px]"></div>
      </div>

      {/* Navigation */}
      <nav className="relative z-50 flex items-center justify-between px-8 py-6 max-w-7xl mx-auto">
        <Link to="/" className="flex items-center gap-2">
          <img src="/logo.svg" alt="Loreum Logo" className="w-8 h-8" />
          <span className="text-2xl font-display tracking-wider">LOREUM</span>
        </Link>
        <div className="flex items-center gap-6">
          <Link to="/blog" className="text-sm tracking-wide hover:text-space-accent transition-colors">
            BLOG
          </Link>
          <Link 
            to="/"
            className="flex items-center gap-2 border border-white/20 px-6 py-2 rounded-full hover:bg-white/10 transition-all text-sm tracking-wide"
          >
            <ArrowLeft className="w-4 h-4" />
            BACK TO HOME
          </Link>
        </div>
      </nav>

      {/* Whitepaper Content */}
      <div className="relative z-10 max-w-4xl mx-auto px-6 py-16">
        <FadeIn>
          <div className="mb-12 text-center">
            <h1 className="text-5xl md:text-6xl font-display mb-4">Chamber Protocol</h1>
            <p className="text-xl text-gray-400 font-light">A Technical Framework for Agentic Organizational Governance</p>
            <p className="text-sm text-gray-500 mt-4">Version 1.2.0 | April 2026</p>
          </div>
        </FadeIn>

        <div className="prose prose-invert prose-lg max-w-none">
          
          {/* Abstract */}
          <FadeIn delay={0.1}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">Abstract</h2>
              <p className="text-gray-300 leading-relaxed mb-4">
                Under the proposed U.S. <strong className="text-white font-normal">Digital Asset Market CLARITY Act of 2025</strong>{" "}
                (H.R. 3633, § 104), a digital asset can only mature past certain securities classifications when its host
                blockchain is governed by a statutorily defined <strong className="text-space-accent font-normal">
                Decentralized Governance System</strong>: a transparent, rules-based process where no single person — and
                no coordinated group — retains effective control. Most onchain communities today rely on multisigs,
                informal offchain signaling, opaque admin capabilities, or plutocratic token voting that do not satisfy
                that bar, leaving protocols in regulatory limbo and exposing participants to residual control risk.
              </p>
              <p className="text-gray-300 leading-relaxed mb-4">
                This paper presents the <strong className="text-white font-normal">Chamber Protocol</strong>, a smart
                contract architecture designed so that consensus, treasury action, and upgrade authority are exercised
                <em> solely</em> through pre-established onchain logic: an ERC4626-compliant vault for asset management,
                a delegation-driven board ranked by transparent rules (sorted linked list), and quorum-based multisig-style
                execution. The design targets the Act&apos;s functional requirements — programmatic transparency, dispersed
                authority, and impartial, rules-bound execution — while enabling autonomous agents and humans to act as
                first-class directors.
              </p>
              <p className="text-gray-300 leading-relaxed">
                Technical contributions include: (1) NFT-based directorship (live auth is the
                membership NFT owner as <code className="text-space-accent">msg.sender</code>,
                or a session key the contract owner registered; EIP-1271 contract-agent
                directors remain a design path, not shipped),
                (2) liquid delegation without governance lockups, subject to solvency checks on delegated balances, 
                (3) circuit-safe linked list repositioning for the governance leaderboard, and (4) self-sovereign
                upgrade paths executed only through quorum-approved transactions. We provide specifications, security
                analysis, and implementation guidance. <span className="text-gray-500">Nothing herein is legal advice;
                statutory text and final rules may change.</span>
              </p>
            </section>
          </FadeIn>

          {/* Introduction */}
          <FadeIn delay={0.2}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">1. Introduction</h2>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">1.1 The CLARITY Act and the decentralized governance gap</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The CLARITY framework conditions regulatory relief on a blockchain system implementing a credible{" "}
                <em>Decentralized Governance System</em> rather than nominal decentralization (e.g. marketing claims or
                hand-wavy forum votes). Practical failure modes — founder-controlled multisigs, upgrade keys held by a
                single entity, discretionary treasuries, vote buying, or unchecked concentration of delegated power —
                all re-introduce identifiable control, which defeats the statute&apos;s objective and perpetuates uncertain
                treatment of the asset and its protocol layer.
              </p>
              <p className="text-gray-300 leading-relaxed mb-4">
                Chamber treats that gap as an engineering constraint: governance outcomes must be{" "}
                <em>observable</em>, <em>rule-bound</em>, and <em>structurally dispersive</em> so that custody of economic and upgrade
                decisions does not collapse to a small clique. The primitives in §2 onward — onchain proposal and
                execution paths, director sets derived from transparent delegation math, and quorum-gated calls — are
                chosen to make &quot;who can move the money and the code&quot; answerable from contract state and event logs,
                not from Discord moderators or invisible deployer keys.
              </p>

              <div className="bg-space-800/40 border border-amber-300/20 rounded-xl p-6 mb-6 backdrop-blur-md">
                <p className="text-xs font-mono tracking-widest text-amber-200/80 mb-3">DEFINITION · CLARITY ACT § 104 (ABRIDGED)</p>
                <p className="text-gray-300 leading-relaxed italic text-sm md:text-base">
                  &quot;The term &apos;decentralized governance system&apos; means, with respect to a blockchain system, any
                  transparent, rules-based system permitting persons to form consensus or reach agreement in the
                  development, provision, publication, management, or administration of such blockchain system, where
                  participation is not limited to, or under the effective control of, any person or group of persons
                  under common control.&quot;
                </p>
              </div>

              <p className="text-gray-300 leading-relaxed mb-4">
                Mapping from requirement to mechanism (non-exhaustive): <strong className="text-space-accent font-normal">
                Transparent &amp; programmatic operation</strong> (cf. § 104(c)(2)(D)) — every material action flows through
                Chamber&apos;s published solidity; <strong className="text-space-accent font-normal">dispersed authority</strong>{" "}
                (cf. § 104(c)(2)(E–G)) — liquid delegation to a ranked board plus majority quorum on execution resists
                single-actor capture when parameters and seat counts are tuned to policy; <strong className="text-space-accent font-normal">
                agent parity</strong> — a designed EIP-1271 path would let smart-contract directors participate under the
                same validation rules as EOAs. That path is not shipped; live director auth requires
                {" "}<code className="text-space-accent">msg.sender</code> to be the membership NFT owner, or a
                session key the contract owner registered.
              </p>

              <h3 className="text-2xl font-display mb-4 mt-10 text-white">1.2 Chamber as protocol response</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Decentralized Autonomous Organizations (DAOs) have emerged as a paradigm for collective decision-making
                in blockchain ecosystems. However, many stacks remain ill-suited to the CLARITY bar: static membership,
                offchain voting with onchain rubber-stamping, or agent-hostile signature models. Chamber addresses
                these limitations with a flexible, agent-centric governance framework built on Ethereum where the
                enforcement layer is the contract system itself.
              </p>
              <p className="text-gray-300 leading-relaxed mb-4">
                The protocol&apos;s name derives from its core abstraction: a <em>Chamber</em> represents a self-contained
                organizational unit that manages assets, executes decisions, and maintains governance state. Each
                Chamber operates as an upgradeable smart contract proxy, combining vault, board, and wallet
                functionality into a unified interface.
              </p>
              <p className="text-gray-300 leading-relaxed">
                This paper contributes: (1) a formal specification of the Chamber architecture aligned to decentralized
                governance requirements, (2) analysis of the sorted linked list delegation mechanism, (3) security
                properties and attack surface evaluation, (4) gas optimization strategies, and (5) implementation details
                for agentic governance use cases.
              </p>
            </section>
          </FadeIn>

          {/* Architecture Overview */}
          <FadeIn delay={0.3}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">2. Architecture Overview</h2>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">2.1 System Components</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Chamber Protocol consists of four primary contracts:
              </p>
              
              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <h4 className="text-xl font-display mb-3 text-space-accent">Registry</h4>
                <p className="text-gray-300 leading-relaxed mb-3">
                  A factory contract that deploys Chamber instances using the TransparentUpgradeableProxy pattern. 
                  The Registry maintains an index of all deployed chambers and their associated assets. Upon deployment, 
                  each Chamber receives ownership of its ProxyAdmin, enabling self-governed upgrades.
                </p>
                <p className="text-gray-400 text-sm font-mono">
                  Key Functions: createChamber(), createAgent(), getAllChambers()
                </p>
              </div>

              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <h4 className="text-xl font-display mb-3 text-space-accent">Chamber</h4>
                <p className="text-gray-300 leading-relaxed mb-3">
                  The main contract inheriting from ERC4626Upgradeable, Board, and Wallet. It combines vault 
                  functionality (deposit/withdraw assets), governance (delegation and director selection), and 
                  execution (multisig transactions). The Chamber maintains mappings for agent delegations and 
                  enforces delegation constraints on token transfers.
                </p>
                <p className="text-gray-400 text-sm font-mono">
                  Key Functions: delegate(), undelegate(), submitTransaction(), executeTransaction()
                </p>
              </div>

              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <h4 className="text-xl font-display mb-3 text-space-accent">Board</h4>
                <p className="text-gray-300 leading-relaxed mb-3">
                  An abstract contract managing the governance leaderboard through a doubly-linked list sorted by 
                  delegation amount (descending). The Board implements dynamic seat management with timelock and 
                  quorum requirements. A circuit breaker prevents reentrancy during list repositioning operations.
                </p>
                <p className="text-gray-400 text-sm font-mono">
                  Key Functions: _delegate(), _undelegate(), _reposition(), _getTop(), _setSeats()
                </p>
              </div>

              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <h4 className="text-xl font-display mb-3 text-space-accent">Wallet</h4>
                <p className="text-gray-300 leading-relaxed mb-3">
                  An abstract contract implementing quorum-based transaction execution. Directors submit transactions, 
                  confirm them until quorum is reached, then execute. The contract follows the Checks-Effects-Interactions 
                  (CEI) pattern and supports batch operations for gas efficiency.
                </p>
                <p className="text-gray-400 text-sm font-mono">
                  Key Functions: _submitTransaction(), _confirmTransaction(), _executeTransaction()
                </p>
              </div>
            </section>
          </FadeIn>

          {/* Delegation Mechanism */}
          <FadeIn delay={0.4}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">3. Delegation Mechanism</h2>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">3.1 Sorted Linked List Structure</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Board contract maintains a doubly-linked list of nodes, where each node represents a tokenId 
                and its total delegated amount. The list is sorted in descending order by delegation amount, enabling 
                O(1) access to the top N directors.
              </p>
              
              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <pre className="text-gray-300 text-sm font-mono overflow-x-auto">
{`struct Node {
    uint256 tokenId;
    uint256 amount;      // Total delegations
    uint256 next;        // Next node (higher amount)
    uint256 prev;        // Previous node (lower amount)
}`}
                </pre>
              </div>

              <p className="text-gray-300 leading-relaxed mb-4">
                When an agent delegates tokens to a tokenId, the Board contract:
              </p>
              <ol className="list-decimal list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li>Checks if a node exists for the tokenId</li>
                <li>If exists, increments the amount and calls <code className="text-space-accent">_reposition()</code></li>
                <li>If not, calls <code className="text-space-accent">_insert()</code> to create a new node</li>
                <li>The insertion/repositioning maintains sorted order by traversing from head</li>
              </ol>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">3.2 Director Selection</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Directors are selected dynamically: the top N tokenIds (where N = seats) form the board. The 
                <code className="text-space-accent"> getDirectors()</code> function resolves tokenId → address 
                by calling <code className="text-space-accent">nft.ownerOf(tokenId)</code>. If an NFT has been 
                burned or transferred, the function returns <code className="text-space-accent">address(0)</code> 
                for that position.
              </p>

              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <p className="text-gray-300 leading-relaxed mb-2">
                  <strong className="text-space-accent">Quorum Calculation:</strong>
                </p>
                <code className="text-space-accent text-lg font-mono">
                  quorum = 1 + (seats × 51) / 100
                </code>
                <p className="text-gray-400 text-sm mt-2">
                  Exact integer formula (`/` truncates). This is not a simple majority:
                  one- and two-seat chambers require 100% of seats.
                </p>
              </div>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">3.3 Liquid Delegation</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Unlike traditional governance systems with lockup periods, Chamber allows agents to redelegate or 
                undelegate tokens at any time. However, the Chamber contract enforces that agents cannot transfer 
                tokens if doing so would reduce their balance below their total delegated amount:
              </p>
              
              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <pre className="text-gray-300 text-sm font-mono overflow-x-auto">
{`function transfer(address to, uint256 value) public override {
    uint256 ownerBalance = balanceOf(owner);
    if (ownerBalance - value < totalAgentDelegations[owner]) {
        revert ExceedsDelegatedAmount();
    }
    _transfer(owner, to, value);
}`}
                </pre>
              </div>

              <p className="text-gray-300 leading-relaxed">
                This constraint ensures that delegated voting power remains backed by actual token balances, 
                preventing double-spending of governance rights.
              </p>
            </section>
          </FadeIn>

          {/* Agent Integration */}
          <FadeIn delay={0.5}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">4. Agent Integration</h2>
              <p className="text-gray-400 leading-relaxed mb-4 text-sm md:text-base">
                This section is a design specification for contract-agent directors, not the live
                authorization path. Shipped Chamber requires{" "}
                <code className="text-space-accent">msg.sender</code> to be the membership NFT
                owner, or a session key the contract owner registered. EIP-1271 agent directors
                are research; they are not a Chamber capability until that path ships.
              </p>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">4.1 EIP-1271 Signature Validation</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The design would enable smart contract agents to act as directors through EIP-1271
                signature validation. When a director function is called, the specified check is:
              </p>
              
              <ol className="list-decimal list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li>If <code className="text-space-accent">msg.sender</code> directly owns the tokenId</li>
                <li>If not, and the owner is a contract, constructs a "DirectorAuth" hash</li>
                <li>Calls <code className="text-space-accent">IERC1271(owner).isValidSignature()</code></li>
                <li>If valid, grants directorship to the agent</li>
              </ol>

              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <pre className="text-gray-300 text-sm font-mono overflow-x-auto">
{`bytes32 hash = keccak256(
    abi.encodePacked("DirectorAuth", address(this), tokenId, msg.sender)
);
if (IERC1271(owner).isValidSignature(hash, abi.encode(msg.sender)) 
    == IERC1271.isValidSignature.selector) {
    isOwner = true;
}`}
                </pre>
              </div>

              <p className="text-gray-300 leading-relaxed mb-4">
                This mechanism allows an Agent contract to hold an NFT and authorize other contracts (or EOAs) 
                to act on its behalf, enabling complex delegation patterns and multi-signature agent configurations.
              </p>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">4.2 Agent Delegation Patterns</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Agents can participate in governance through multiple patterns:
              </p>
              
              <div className="space-y-4 mb-6">
                <div className="bg-space-800/40 border border-white/10 rounded-lg p-4">
                  <h4 className="text-lg font-display mb-2 text-space-accent">Pattern 1: Direct Ownership</h4>
                  <p className="text-gray-300 text-sm">
                    An agent contract owns an NFT tokenId and directly calls Chamber functions. The agent must 
                    accumulate enough delegations to enter the top N seats.
                  </p>
                </div>
                
                <div className="bg-space-800/40 border border-white/10 rounded-lg p-4">
                  <h4 className="text-lg font-display mb-2 text-space-accent">Pattern 2: Delegated Authority</h4>
                  <p className="text-gray-300 text-sm">
                    Design only: an agent contract would hold an NFT and authorize another contract
                    (via EIP-1271) to act as director. This would separate identity from the
                    authorized caller. It is not the live path.
                  </p>
                </div>
                
                <div className="bg-space-800/40 border border-white/10 rounded-lg p-4">
                  <h4 className="text-lg font-display mb-2 text-space-accent">Pattern 3: Voting Power Delegation</h4>
                  <p className="text-gray-300 text-sm">
                    Agents delegate their Chamber tokens to specific tokenIds, influencing director selection without 
                    holding NFTs themselves. This enables liquid democracy where agents can redelegate based on 
                    performance or policy alignment.
                  </p>
                </div>
              </div>
            </section>
          </FadeIn>

          {/* Security Analysis */}
          <FadeIn delay={0.6}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">5. Security Analysis</h2>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">5.1 Circuit Breaker Pattern</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Board contract implements a circuit breaker to prevent reentrancy during linked list repositioning. 
                The <code className="text-space-accent">_reposition()</code> function is protected by a 
                <code className="text-space-accent"> circuitBreaker</code> modifier that sets a locked flag before 
                removing and re-inserting a node.
              </p>

              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <pre className="text-gray-300 text-sm font-mono overflow-x-auto">
{`modifier circuitBreaker() {
    if (locked) revert CircuitBreakerActive();
    locked = true;
    _;
    locked = false;
}`}
                </pre>
              </div>

              <p className="text-gray-300 leading-relaxed mb-4">
                This prevents state corruption if an external call during repositioning attempts to modify the list. 
                All public functions check the locked state via <code className="text-space-accent">preventReentry</code> 
                modifier before proceeding.
              </p>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">5.2 Reentrancy Protection</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Chamber contract uses OpenZeppelin's <code className="text-space-accent">ReentrancyGuardUpgradeable</code> 
                for transaction execution. The Wallet contract follows the CEI (Checks-Effects-Interactions) pattern, 
                updating state before making external calls:
              </p>

              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <pre className="text-gray-300 text-sm font-mono overflow-x-auto">
{`function _executeTransaction(...) internal {
    // Check
    if (transaction.executed) revert();
    
    // Effect - Update state BEFORE external call
    transaction.executed = true;
    
    // Interaction
    (bool success, ) = target.call{value: value}(data);
    if (!success) {
        transaction.executed = false; // Revert on failure
        revert();
    }
}`}
                </pre>
              </div>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">5.3 Input Validation</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                All public functions perform comprehensive input validation:
              </p>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li>Zero address checks for all address parameters</li>
                <li>Zero amount checks for token operations</li>
                <li>Balance checks before delegations and transfers</li>
                <li>NFT existence verification via <code className="text-space-accent">ownerOf()</code> try-catch</li>
                <li>Seat count bounds (1-20 seats maximum)</li>
                <li>Node count limits (100 nodes maximum)</li>
              </ul>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">5.4 Upgrade Safety</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Chambers use the TransparentUpgradeableProxy pattern with self-ownership. The Registry transfers 
                ProxyAdmin ownership to each Chamber upon deployment, enabling governance-controlled upgrades. 
                Upgrades must be executed through the transaction system, requiring quorum approval.
              </p>
              <p className="text-gray-300 leading-relaxed mb-4">
                Storage gaps (<code className="text-space-accent">uint256[50] private __gap</code>) prevent storage 
                collisions during upgrades, following OpenZeppelin's upgradeable contract guidelines.
              </p>
            </section>
          </FadeIn>

          {/* Gas Optimization */}
          <FadeIn delay={0.7}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">6. Gas Optimization</h2>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">6.1 Linked List Complexity</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The sorted linked list operations have the following gas complexity:
              </p>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li><strong>Insertion:</strong> O(n) worst case, O(1) best case (insert at head/tail)</li>
                <li><strong>Removal:</strong> O(1) - direct node access via mapping</li>
                <li><strong>Repositioning:</strong> O(n) - requires removal + insertion</li>
                <li><strong>Top N retrieval:</strong> O(n) where n = min(N, list size)</li>
              </ul>
              <p className="text-gray-300 leading-relaxed mb-4">
                The MAX_NODES constant (100) limits worst-case gas costs, making the system predictable for 
                typical governance scenarios.
              </p>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">6.2 Batch Operations</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Wallet contract provides batch functions to reduce transaction overhead:
              </p>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li><code className="text-space-accent">submitBatchTransactions()</code> - Submit multiple transactions in one call</li>
                <li><code className="text-space-accent">confirmBatchTransactions()</code> - Confirm multiple transactions</li>
                <li><code className="text-space-accent">executeBatchTransactions()</code> - Execute multiple transactions</li>
              </ul>
              <p className="text-gray-300 leading-relaxed">
                These functions amortize the fixed gas costs (21,000 base + calldata) across multiple operations.
              </p>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">6.3 Storage Packing</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Structs are designed to pack efficiently into storage slots:
              </p>
              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <pre className="text-gray-300 text-sm font-mono overflow-x-auto">
{`Transaction: bool (1 byte) + uint8 (1 byte) + address (20 bytes) 
              + uint256 (32 bytes) + bytes (dynamic)
              = Packed into minimal storage slots

Node: 4 × uint256 = 4 storage slots (optimal for linked list operations)`}
                </pre>
              </div>
            </section>
          </FadeIn>

          {/* Implementation Details */}
          <FadeIn delay={0.8}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">7. Implementation Details</h2>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">7.1 Seat Management</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Board contract implements a two-phase seat update process:
              </p>
              <ol className="list-decimal list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li><strong>Proposal:</strong> A director calls <code className="text-space-accent">updateSeats()</code> with a new seat count</li>
                <li><strong>Support:</strong> Other directors call <code className="text-space-accent">updateSeats()</code> with the same count to add support</li>
                <li><strong>Timelock:</strong> Once quorum is reached, a 7-day timelock begins</li>
                <li><strong>Execution:</strong> After timelock expires, any director can call <code className="text-space-accent">executeSeatsUpdate()</code></li>
              </ol>
              <p className="text-gray-300 leading-relaxed mb-4">
                The quorum requirement is calculated at proposal time and stored, preventing manipulation through 
                seat changes during the proposal period.
              </p>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">7.2 Transaction Lifecycle</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Transactions follow a three-phase lifecycle:
              </p>
              <div className="bg-space-800/40 border border-white/10 rounded-xl p-6 mb-6 backdrop-blur-md">
                <ol className="list-decimal list-inside text-gray-300 space-y-3">
                  <li>
                    <strong className="text-space-accent">Submission:</strong> A director calls 
                    <code className="text-space-accent"> submitTransaction()</code>. The transaction is created and 
                    auto-confirmed by the submitter.
                  </li>
                  <li>
                    <strong className="text-space-accent">Confirmation:</strong> Other directors call 
                    <code className="text-space-accent"> confirmTransaction()</code> until quorum is reached. 
                    Directors can revoke confirmations via <code className="text-space-accent">revokeConfirmation()</code>.
                  </li>
                  <li>
                    <strong className="text-space-accent">Execution:</strong> Once quorum is reached, any director 
                    can call <code className="text-space-accent">executeTransaction()</code>. The transaction is 
                    executed via a low-level call, and state is updated before the external call (CEI pattern).
                  </li>
                </ol>
              </div>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">7.3 ERC4626 Integration</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Chamber inherits from <code className="text-space-accent">ERC4626Upgradeable</code>, providing 
                standard vault functionality:
              </p>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li><code className="text-space-accent">deposit()</code> - Deposit assets, receive shares</li>
                <li><code className="text-space-accent">mint()</code> - Mint shares for assets</li>
                <li><code className="text-space-accent">withdraw()</code> - Redeem shares for assets</li>
                <li><code className="text-space-accent">redeem()</code> - Redeem shares for assets</li>
              </ul>
              <p className="text-gray-300 leading-relaxed">
                Chamber tokens (shares) represent proportional ownership of the vault's assets and can be delegated 
                for governance purposes. The vault maintains a 1:1 relationship with a single ERC20 asset.
              </p>
            </section>
          </FadeIn>

          {/* Use Cases */}
          <FadeIn delay={0.9}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">8. Agentic Governance Use Cases</h2>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">8.1 Autonomous Treasury Management</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Agents can be configured as directors to autonomously manage treasury operations. For example, an 
                agent might:
              </p>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li>Monitor yield opportunities and propose transactions to deploy assets</li>
                <li>Execute approved strategies automatically when quorum is reached</li>
                <li>Redelegate voting power based on performance metrics</li>
                <li>Coordinate with other agents through the transaction system</li>
              </ul>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">8.2 Multi-Agent Coordination</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                Multiple agents can form coalitions by delegating to shared tokenIds. This enables:
              </p>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li>Specialized agent teams (e.g., risk management, research, operations)</li>
                <li>Dynamic reconfiguration as agents join/leave coalitions</li>
                <li>Liquid democracy where agents can redelegate based on outcomes</li>
              </ul>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">8.3 Hierarchical Organizations</h3>
              <p className="text-gray-300 leading-relaxed mb-4">
                A contemplated pattern — not the live architecture — would nest Chambers:
              </p>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li>A root Chamber manages global policies and main treasury</li>
                <li>Sub-Chambers are deployed for specialized departments (Treasury, Ops, R&D)</li>
                <li>Agents can participate in multiple chambers simultaneously</li>
                <li>Cross-chamber coordination through transaction proposals</li>
              </ul>
            </section>
          </FadeIn>

          {/* Limitations and Future Work */}
          <FadeIn delay={1.0}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">9. Limitations and Future Work</h2>
              
              <h3 className="text-2xl font-display mb-4 mt-8 text-white">9.1 Current Limitations</h3>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li><strong>Single Asset:</strong> Each Chamber manages one ERC20 token. Multi-asset support would require architectural changes.</li>
                <li><strong>No Scheduling:</strong> Transactions execute immediately when quorum is reached. Time-based execution would require additional infrastructure.</li>
                <li><strong>No Cancellation:</strong> Transactions cannot be cancelled once submitted, only revoked (reducing confirmations).</li>
                <li><strong>Gas Costs:</strong> Linked list operations scale linearly with node count, limiting scalability for very large organizations.</li>
              </ul>

              <h3 className="text-2xl font-display mb-4 mt-8 text-white">9.2 Future Enhancements</h3>
              <ul className="list-disc list-inside text-gray-300 space-y-2 mb-4 ml-4">
                <li>Multi-asset vault support for diversified treasuries</li>
                <li>Transaction scheduling with time-based execution</li>
                <li>Conditional execution based on onchain or offchain data</li>
                <li>Configurable quorum strategies beyond simple majority</li>
                <li>Enhanced Registry with metadata and discovery mechanisms</li>
                <li>Cross-chain governance through bridge integrations</li>
              </ul>
            </section>
          </FadeIn>

          {/* Conclusion */}
          <FadeIn delay={1.1}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">10. Conclusion</h2>
              <p className="text-gray-300 leading-relaxed mb-4">
                The Chamber Protocol presents a novel architecture for agentic organizational governance on Ethereum
                with the CLARITY Act&apos;s <em>Decentralized Governance System</em> threshold in view. By combining ERC4626
                vault functionality, dynamic board governance, and quorum-based execution enforced entirely in contract
                code, the protocol enables autonomous agents and humans to participate in decentralized decision-making
                while keeping control legible and diffuse — not dependent on informal social layers for enforcement.
              </p>
              <p className="text-gray-300 leading-relaxed mb-4">
                Key innovations include the sorted linked list delegation mechanism, liquid
                delegation patterns, and self-sovereign upgradeability gated by the same transaction
                flow as other chamber actions. EIP-1271 agent directors and Sub-Chamber topologies
                remain design work — not the live Factory, vault, ranked board, and quorum wallet.
              </p>
              <p className="text-gray-300 leading-relaxed">
                Future work will explore multi-asset support, advanced governance strategies, and cross-chain
                coordination mechanisms. The upgradeable architecture allows adaptation as statutory definitions and
                market practice around decentralized governance continue to evolve.
              </p>
            </section>
          </FadeIn>

          {/* References */}
          <FadeIn delay={1.2}>
            <section className="mb-16">
              <h2 className="text-3xl font-display mb-6 text-space-accent">References</h2>
              <div className="space-y-3 text-gray-300">
                <p>
                  [1] EIP-4626: Tokenized Vault Standard. <em>Ethereum Improvement Proposals</em>. 
                  <a href="https://eips.ethereum.org/EIPS/eip-4626" className="text-space-accent hover:underline ml-1">
                    https://eips.ethereum.org/EIPS/eip-4626
                  </a>
                </p>
                <p>
                  [2] EIP-1271: Standard Signature Validation Method for Contracts. <em>Ethereum Improvement Proposals</em>.
                  <a href="https://eips.ethereum.org/EIPS/eip-1271" className="text-space-accent hover:underline ml-1">
                    https://eips.ethereum.org/EIPS/eip-1271
                  </a>
                </p>
                <p>
                  [3] OpenZeppelin Contracts. <em>OpenZeppelin</em>.
                  <a href="https://docs.openzeppelin.com/contracts" className="text-space-accent hover:underline ml-1">
                    https://docs.openzeppelin.com/contracts
                  </a>
                </p>
                <p>
                  [4] Transparent Upgradeable Proxy Pattern. <em>OpenZeppelin Upgrades Plugin</em>.
                  <a href="https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies" className="text-space-accent hover:underline ml-1">
                    https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies
                  </a>
                </p>
                <p>
                  [5] Chamber Protocol Source Code. <em>GitHub Repository</em>.
                  <a href="https://github.com/loreum-org/chamber" className="text-space-accent hover:underline ml-1">
                    https://github.com/loreum-org/chamber
                  </a>
                </p>
                <p>
                  [6] U.S. House, Digital Asset Market Clarity Act of 2025 (CLARITY Act), H.R. 3633, 119th Cong. (as
                  introduced; § 104 decentralized governance provisions).{" "}
                  <a
                    href="https://www.congress.gov/bill/119th-congress/house-bill/3633"
                    className="text-space-accent hover:underline ml-1"
                  >
                    https://www.congress.gov/bill/119th-congress/house-bill/3633
                  </a>
                </p>
              </div>
            </section>
          </FadeIn>

        </div>
      </div>

      {/* Footer */}
      <footer className="relative z-10 bg-space-900 pt-20 pb-10 border-t border-white/10 mt-32">
        <div className="max-w-7xl mx-auto px-6 text-center">
          <div className="flex items-center justify-center gap-2 mb-6">
            <img src="/logo.svg" alt="Loreum Logo" className="w-6 h-6" />
            <span className="text-2xl font-display tracking-wider">LOREUM</span>
          </div>
          <p className="text-gray-500 text-sm">
            © 2026 LOREUM DAO LLC. ALL RIGHTS RESERVED.
          </p>
          <p className="mt-4 flex items-center justify-center gap-6">
            <Link to="/team" className="text-gray-500 hover:text-white transition-colors text-sm tracking-wide">
              Team
            </Link>
            <Link to="/blog" className="text-gray-500 hover:text-white transition-colors text-sm tracking-wide">
              Blog
            </Link>
          </p>
        </div>
      </footer>
    </div>
  );
}

export default Whitepaper;
