import React from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { ArrowRight, ChevronRight, Layers, Shield, Cpu, TrendingUp, ShieldAlert, Search, Radio, Scale, Eye, Network } from 'lucide-react';

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

/** Production default so CTAs work when env is unset in a static build. */
const chamberAppUrl =
  (import.meta.env.VITE_CHAMBER_APP_URL as string | undefined)?.trim() ||
  'https://app.loreum.org';

function App() {
  return (
    <div className="min-h-screen w-full min-w-0 bg-space-900 text-white selection:bg-space-accent selection:text-space-900 overflow-x-hidden relative">
      
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
      <nav className="relative z-50 flex items-center justify-between gap-4 px-4 sm:px-8 py-6 max-w-7xl mx-auto w-full min-w-0 box-border">
        <div className="flex items-center gap-2">
          <img src="/logo.svg" alt="Loreum Logo" className="w-8 h-8" />
          <span className="text-2xl font-display tracking-wider">LOREUM</span>
        </div>
        <div className="hidden md:flex items-center gap-8 font-light tracking-wide text-sm">
          <a href="#clarity" className="hover:text-space-accent transition-colors">CLARITY</a>
          <a href="#mission" className="hover:text-space-accent transition-colors">MISSION</a>
          <a href="#technology" className="hover:text-space-accent transition-colors">TECHNOLOGY</a>
          <a href="#governance" className="hover:text-space-accent transition-colors">GOVERNANCE</a>
          <Link to="/team" className="hover:text-space-accent transition-colors">TEAM</Link>
          <Link to="/blog" className="hover:text-space-accent transition-colors">BLOG</Link>
        </div>
        <div className="flex items-center gap-4">
          <Link to="/team" className="md:hidden text-sm tracking-wide font-light hover:text-space-accent transition-colors">TEAM</Link>
          <Link to="/blog" className="md:hidden text-sm tracking-wide font-light hover:text-space-accent transition-colors">BLOG</Link>
          <a 
            href={chamberAppUrl}
            className="hidden md:flex items-center gap-2 border border-white/20 px-6 py-2 rounded-full hover:bg-white/10 transition-all text-sm tracking-wide"
          >
            LAUNCH APP
          </a>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative z-10 min-h-[90vh] flex items-center justify-center px-4 sm:px-6 w-full min-w-0 box-border">
        <div className="w-full max-w-5xl mx-auto text-center min-w-0 px-1 sm:px-0">
          <motion.div 
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 1 }}
            className="mb-6 inline-block"
          >
            <span className="inline-block max-w-full px-3 sm:px-4 py-1.5 rounded-full border border-space-accent/30 bg-space-accent/10 text-space-accent text-xs tracking-[0.2em] backdrop-blur-sm break-words text-center leading-snug">
              CHAMBER · ONCHAIN GOVERNANCE
            </span>
          </motion.div>
          
          <motion.h1 
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.2 }}
            className="text-3xl sm:text-4xl md:text-5xl lg:text-6xl xl:text-7xl font-display leading-tight mb-8 break-words text-balance"
          >
            DECENTRALIZED GOVERNANCE SYSTEM<br />
          </motion.h1>

          <motion.p 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.4 }}
            className="text-lg md:text-xl text-gray-400 max-w-2xl mx-auto mb-12 font-light leading-relaxed break-words"
          >
            Loreum Chamber is protocol infrastructure for real DAOs: a
            factory-deployed ERC-4626 vault, a liquid-delegated ranked board of
            membership NFTs, and a
            <span className="text-space-accent"> quorum wallet</span> — onchain
            and verifiable by your community.
          </motion.p>

          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.6 }}
            className="flex flex-col sm:flex-row items-center justify-center gap-4"
          >
            <a
              href={chamberAppUrl}
              className="w-full sm:w-auto px-8 py-4 bg-white text-space-900 hover:bg-space-accent transition-colors rounded-none text-sm tracking-widest font-bold flex items-center justify-center gap-2 group"
            >
              START MISSION
              <ChevronRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
            </a>
            <Link 
              to="/whitepaper"
              className="w-full sm:w-auto px-8 py-4 border border-white/20 hover:border-white hover:bg-white/5 transition-all rounded-none text-sm tracking-widest font-bold text-center inline-block"
            >
              READ WHITEPAPER
            </Link>
          </motion.div>
        </div>
      </section>

      {/* Built on Ethereum Strip */}
      <section className="relative z-10 border-y border-white/10 bg-space-800/50 backdrop-blur-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-12 flex flex-wrap items-center justify-center gap-6 w-full min-w-0 box-border">
          <a 
            href="https://ethereum.org" 
            target="_blank" 
            rel="noopener noreferrer"
            className="flex items-center gap-4 group opacity-70 hover:opacity-100 transition-opacity"
          >
            <div className="flex flex-col items-center">
               <span className="text-sm font-light tracking-widest text-gray-400 mb-2">BUILT ON</span>
               <div className="flex items-center gap-3">
                 <svg 
                   className="w-8 h-8 text-white group-hover:text-space-accent transition-colors" 
                   viewBox="0 0 784.37 1277.39" 
                   fill="currentColor"
                 >
                    <path d="M392.07 0L383.5 29.11V873.74L392.07 882.29L784.13 650.54L392.07 0Z" fillOpacity="0.6" />
                    <path d="M392.07 0L0 650.54L392.07 882.29V481.55V0Z" />
                    <path d="M392.07 956.52L385.15 964.96V1263.39L392.07 1277.38L784.37 724.89L392.07 956.52Z" fillOpacity="0.6" />
                    <path d="M392.07 1277.38V956.52L0 724.89L392.07 1277.38Z" />
                    <path d="M392.07 882.29L784.13 650.54L392.07 473.55V882.29Z" fillOpacity="0.2" />
                    <path d="M0 650.54L392.07 882.29V473.55L0 650.54Z" fillOpacity="0.6" />
                 </svg>
                 <span className="text-2xl sm:text-3xl font-display tracking-widest text-center break-words">ETHEREUM</span>
               </div>
            </div>
          </a>
        </div>
      </section>

      {/* The CLARITY Mandate — Problem Section */}
      <section id="clarity" className="relative z-10 py-32 px-4 sm:px-6 border-b border-white/5 w-full min-w-0 box-border">
        <div className="max-w-7xl mx-auto w-full min-w-0 px-1 sm:px-0">
          <FadeIn className="mb-20 max-w-4xl">
            <div className="mb-6 inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-amber-300/30 bg-amber-300/10 text-amber-200 text-xs tracking-[0.2em]">
              <Scale className="w-3 h-3" />
              THE CLARITY MANDATE
            </div>
            <h2 className="text-3xl sm:text-4xl md:text-6xl font-display mb-8 leading-tight break-words text-balance">
              Governance is no longer<br />
              <span className="text-gradient">optional infrastructure.</span>
            </h2>
            <p className="text-lg md:text-xl text-gray-400 font-light leading-relaxed mb-6 break-words">
              Under the U.S. <span className="text-white">Digital Asset Market CLARITY Act of 2025</span> (H.R. 3633, § 104),
              a digital asset can only graduate out of securities oversight when its blockchain
              system is governed by a <span className="text-space-accent">Decentralized Governance System</span>:
              a transparent, rules-based process for forming consensus where no person — and no
              group of persons under common control — retains effective control.
            </p>
            <p className="text-lg md:text-xl text-gray-400 font-light leading-relaxed break-words">
              Most "DAOs" do not meet that bar. Founder multisigs, offchain Discord votes, opaque
              admin keys, and concentrated voting power all fail the test — leaving protocols
              stuck in regulatory limbo, exposed to enforcement risk, and unable to mature.
            </p>
          </FadeIn>

          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                icon: <Eye className="w-7 h-7 text-amber-300" />,
                tag: "§ 104(c)(2)(D)",
                title: "Transparent & Programmatic",
                desc: "The Act requires a system that operates and enforces decisions solely from pre-established, transparent rules encoded in source code. Chamber executes proposal, vote, and treasury transfer through published onchain contracts — not Discord polls or hidden admin keys.",
                glow: "bg-amber-400/10"
              },
              {
                icon: <Shield className="w-7 h-7 text-purple-300" />,
                tag: "§ 104(c)(2)(E)",
                title: "No Unilateral Control",
                desc: "The Act targets concentrated voting power. Chamber ships liquid delegation to a ranked board of membership NFTs and quorum-gated execution — so treasury and upgrades move through those onchain rules, not admin keys.",
                glow: "bg-purple-500/10"
              },
              {
                icon: <Network className="w-7 h-7 text-emerald-300" />,
                tag: "§ 104(c)(2)(F–G)",
                title: "Distributed & Impartial",
                desc: "Authority must be distributed and the system impartial. Chamber seats directors from liquid delegation to membership NFTs. Director actions require the NFT owner as msg.sender, or a session key the contract owner registered; a quorum of directors then executes.",
                glow: "bg-emerald-500/10"
              }
            ].map((item, i) => (
              <FadeIn key={i} delay={i * 0.15} className="group relative">
                <div className="relative h-full p-8 bg-space-800/40 backdrop-blur-md border border-white/10 rounded-xl overflow-hidden group-hover:border-white/20 transition-all duration-500 hover:translate-y-[-4px] hover:shadow-2xl">
                  <div className={`absolute -top-10 -right-10 w-32 h-32 rounded-full blur-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-700 ${item.glow}`} />

                  <div className="relative flex items-start justify-between mb-6">
                    <div className="p-4 bg-white/5 inline-block rounded-lg group-hover:scale-110 group-hover:bg-white/10 transition-all duration-500 border border-white/5">
                      {item.icon}
                    </div>
                    <span className="font-mono text-[10px] tracking-widest text-amber-200/70 border border-amber-200/20 rounded-full px-2 py-1 shrink-0 min-w-0 max-w-[calc(100%-5rem)] sm:max-w-[14rem] break-words text-right leading-snug">
                      {item.tag}
                    </span>
                  </div>

                  <h3 className="relative text-xl md:text-2xl font-display mb-4 tracking-wide text-white group-hover:text-space-accent transition-colors">{item.title}</h3>
                  <p className="relative text-gray-400 leading-relaxed text-sm group-hover:text-gray-300 transition-colors">
                    {item.desc}
                  </p>
                </div>
              </FadeIn>
            ))}
          </div>

          <FadeIn delay={0.4} className="mt-16 max-w-4xl">
            <div className="p-6 md:p-8 border border-white/10 rounded-xl bg-space-800/30 backdrop-blur-sm">
              <p className="text-sm md:text-base text-gray-400 font-light leading-relaxed">
                <span className="text-white font-mono text-xs tracking-widest">DEFINITION · CLARITY ACT § 104 </span>
                <br />
                <span className="italic text-gray-300">
                  "The term 'decentralized governance system' means, with respect to a blockchain
                  system, any transparent, rules-based system permitting persons to form consensus
                  or reach agreement in the development, provision, publication, management, or
                  administration of such blockchain system, where participation is not limited to,
                  or under the effective control of, any person or group of persons under common
                  control."
                </span>
              </p>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* Mission Section */}
      <section id="mission" className="relative z-10 py-32 px-4 sm:px-6 w-full min-w-0 box-border">
        <div className="max-w-7xl mx-auto flex flex-col items-center text-center w-full min-w-0 px-1 sm:px-0">
          <FadeIn>
            <h2 className="text-4xl md:text-5xl font-display mb-8 break-words">Our Mission</h2>
            <p className="text-xl sm:text-2xl md:text-4xl text-white font-light max-w-4xl leading-relaxed break-words text-balance">
              "To enable people to <span className="text-space-accent">maximize their potential</span>."
            </p>
            <p className="mt-8 text-base md:text-lg text-gray-400 max-w-2xl mx-auto font-light leading-relaxed break-words">
              By giving every community a credibly neutral home for capital, decisions, and
              autonomous agents — built to satisfy the legal threshold of a Decentralized
              Governance System from day one.
            </p>
          </FadeIn>
        </div>
      </section>

      {/* Core Features */}
      <section id="technology" className="relative z-10 py-32 px-4 sm:px-6 w-full min-w-0 box-border">
        <div className="max-w-7xl mx-auto w-full min-w-0 px-1 sm:px-0">
          <FadeIn className="mb-20 max-w-2xl">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-display mb-6 break-words text-balance">Autonomous Architecture</h2>
            <p className="text-gray-400 text-lg font-light leading-relaxed break-words">
              The shipped Chamber is a factory-deployed ERC-4626 vault with a
              liquid-delegated ranked board of membership NFTs and a quorum wallet —
              the onchain object that Create deploys today.
            </p>
          </FadeIn>

          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                icon: <Layers className="w-8 h-8 text-blue-400" />,
                title: "Factory",
                desc: "Create deploys each Chamber from a Factory as an upgradeable proxy. On Sepolia the Factory address is an in-repo default — not a leftover Registry crawl, and not gated on a local env var.",
                glow: "bg-blue-500/20"
              },
              {
                icon: <Shield className="w-8 h-8 text-purple-400" />,
                title: "ERC-4626 Vault",
                desc: "Each Chamber is a tokenized vault: deposit the Chamber asset, receive shares, and keep treasury flows onchain and redeemable. Shares back liquid delegation to the board.",
                glow: "bg-purple-500/20"
              },
              {
                icon: <Cpu className="w-8 h-8 text-emerald-400" />,
                title: "Ranked Board & Quorum Wallet",
                desc: "Membership NFTs form a liquid-delegated ranked board. Directors submit and confirm; a quorum of seats executes. The caller must be the NFT owner as msg.sender, or a session key the contract owner registered. An EIP-1271 agent-director path is not shipped.",
                glow: "bg-emerald-500/20"
              }
            ].map((feature, i) => (
              <FadeIn key={i} delay={i * 0.2} className="group relative">
                 <div className="absolute -inset-px bg-gradient-to-b from-white/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 rounded-xl pointer-events-none" />
                 
                 <div className="relative h-full p-8 bg-space-800/40 backdrop-blur-md border border-white/10 rounded-xl overflow-hidden group-hover:border-white/20 transition-all duration-500 hover:translate-y-[-4px] hover:shadow-2xl">
                    {/* Glow effect */}
                    <div className={`absolute -top-10 -right-10 w-32 h-32 rounded-full blur-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-700 ${feature.glow}`} />
                    
                    <div className="relative mb-6 p-4 bg-white/5 inline-block rounded-lg group-hover:scale-110 group-hover:bg-white/10 transition-all duration-500 border border-white/5">
                      {feature.icon}
                    </div>
                    
                    <h3 className="relative text-2xl font-display mb-4 tracking-wide text-white group-hover:text-space-accent transition-colors">{feature.title}</h3>
                    <p className="relative text-gray-400 leading-relaxed text-sm group-hover:text-gray-300 transition-colors">
                      {feature.desc}
                    </p>
                 </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* Governance Architecture Section */}
      <section id="governance" className="relative z-10 py-32 px-4 sm:px-6 border-t border-white/5 w-full min-w-0 box-border overflow-x-hidden">
        <div className="max-w-7xl mx-auto w-full min-w-0 px-1 sm:px-0">
          <FadeIn className="text-center mb-20">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-display mb-6 px-2 break-words text-balance">Ecosystem Governance</h2>
            <p className="text-gray-400 max-w-2xl mx-auto px-2 text-lg font-light leading-relaxed break-words">
              Each Chamber is a factory-deployed vault, ranked board, and
              <span className="text-space-accent"> quorum wallet</span> —
              a transparent, rules-based object where authority is exercised onchain,
              not by admin keys.
            </p>
          </FadeIn>

          <div className="grid md:grid-cols-2 gap-16 items-center min-w-0">
             <FadeIn delay={0.2} className="relative w-full min-w-0">
                {/* Diagrammatic representation */}
                <div className="relative p-6 sm:p-8 border border-white/10 rounded-2xl bg-white/5 backdrop-blur-sm min-h-0 w-full max-w-full min-w-0 flex flex-col items-center justify-center gap-8 md:aspect-[4/3] overflow-hidden">
                   {/* Main Chamber */}
                  <div className="relative z-10 p-6 bg-space-800 border border-space-accent/50 rounded-xl max-w-[12rem] w-full sm:w-48 text-center shadow-[0_0_30px_rgba(208,214,249,0.1)]">
                      <div className="text-space-accent font-display text-xl mb-1">Chamber</div>
                      <div className="text-xs text-gray-400">Factory Deploy</div>
                      
                      {/* Connection Lines */}
                      <div className="absolute top-full left-1/2 -translate-x-1/2 h-8 w-px bg-gradient-to-b from-space-accent/50 to-transparent" />
                      <div className="absolute top-full left-1/2 -translate-x-1/2 w-[min(18rem,calc(100vw-8rem))] sm:w-48 h-8 border-x border-t border-space-accent/20 rounded-t-xl translate-y-8" />
                   </div>

                   {/* Chamber primitives — stack on narrow viewports, row + wrap on sm+ */}
                   <div className="flex flex-col sm:flex-row sm:flex-wrap gap-3 sm:gap-4 mt-8 pt-4 w-full max-w-full min-w-0 px-2 sm:px-0 justify-center items-center sm:items-stretch">
                      <div className="p-4 bg-space-800/50 border border-white/10 rounded-lg w-[8.5rem] max-w-full shrink-0 sm:w-28 text-center backdrop-blur-md">
                         <div className="text-white font-display mb-1">Vault</div>
                         <div className="text-[10px] text-gray-500">ERC-4626</div>
                      </div>
                      <div className="p-4 bg-space-800/50 border border-white/10 rounded-lg w-[8.5rem] max-w-full shrink-0 sm:w-28 text-center backdrop-blur-md">
                         <div className="text-white font-display mb-1">Board</div>
                         <div className="text-[10px] text-gray-500">Ranked NFTs</div>
                      </div>
                      <div className="p-4 bg-space-800/50 border border-white/10 rounded-lg w-[8.5rem] max-w-full shrink-0 sm:w-28 text-center backdrop-blur-md">
                         <div className="text-white font-display mb-1">Wallet</div>
                         <div className="text-[10px] text-gray-500">Quorum</div>
                      </div>
                   </div>
                </div>
             </FadeIn>

             <FadeIn delay={0.4} className="space-y-12 w-full min-w-0">
                <div className="group min-w-0">
                   <h3 className="text-2xl font-display mb-3 text-white group-hover:text-space-accent transition-colors">Vault & Board</h3>
                   <p className="text-gray-400 leading-relaxed font-light break-words">
                      The Chamber holds the ERC-4626 treasury and seats a ranked board from
                      liquid delegation to membership NFTs. Authority is exercised through
                      those onchain rules — never through admin keys or offchain channels.
                   </p>
                </div>

                <div className="group min-w-0">
                   <h3 className="text-2xl font-display mb-3 text-white group-hover:text-space-accent transition-colors">Quorum Wallet</h3>
                   <p className="text-gray-400 leading-relaxed font-light break-words">
                      Directors submit and confirm transactions; execution requires quorum.
                      The caller must be the NFT owner as msg.sender, or a session key the
                      contract owner registered. EIP-1271 is not shipped.
                   </p>
                </div>
             </FadeIn>
          </div>
        </div>
      </section>

      {/* Visual Showcase Section */}
      <section className="relative z-10 py-32 px-4 sm:px-6 bg-space-800/30 w-full min-w-0 box-border overflow-x-hidden">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center gap-16 w-full min-w-0 px-1 sm:px-0">
          <div className="flex-1 w-full min-w-0">
            <FadeIn>
              <h2 className="text-3xl sm:text-4xl md:text-5xl font-display mb-8 break-words text-balance">
                Command Your <br />
                <span className="text-gradient">Digital Fleet</span>
              </h2>
              <div className="space-y-6">
                {[
                  "Deploy fleets of autonomous agents.",
                  "Monitor real-time treasury analytics.",
                  "Execute complex cross-chain strategies."
                ].map((item, i) => (
                  <div key={i} className="flex items-center gap-4 text-gray-300">
                    <div className="w-2 h-2 bg-space-accent rounded-full" />
                    <span className="font-light tracking-wide">{item}</span>
                  </div>
                ))}
              </div>
              <a
                href={chamberAppUrl}
                className="mt-10 inline-flex items-center gap-2 text-space-accent hover:text-white transition-colors tracking-widest text-sm font-bold"
              >
                VIEW DEMO <ArrowRight className="w-4 h-4" />
              </a>
            </FadeIn>
          </div>
          
          <div className="flex-1 relative w-full">
            <motion.div 
              initial={{ opacity: 0, x: 50 }}
              whileInView={{ opacity: 1, x: 0 }}
              transition={{ duration: 1 }}
              className="relative aspect-square max-w-[500px] mx-auto mb-8 md:mb-0"
            >
              {/* Abstract Representation of AI/Core */}
              <div className="absolute inset-0 border border-white/20 rounded-full animate-[spin_10s_linear_infinite]" />
              <div className="absolute inset-8 border border-white/10 rounded-full animate-[spin_15s_linear_infinite_reverse]" />
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="w-32 h-32 bg-gradient-to-br from-blue-500/20 to-purple-500/20 rounded-full blur-xl animate-pulse" />
                <div className="relative z-10 w-24 h-24 bg-space-900 border border-white/30 flex items-center justify-center rounded-lg rotate-45">
                   <div className="-rotate-45">
                     <img src="/logo.svg" alt="Loreum Logo" className="w-12 h-12" />
                   </div>
                </div>
              </div>
              
              {/* Floating Elements - Fleet Agents (Desktop Only) */}
              {/* Yield Miner */}
              <motion.div 
                animate={{ y: [0, -15, 0] }}
                transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                className="hidden md:flex absolute top-0 right-0 bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md items-center gap-3"
              >
                <div className="p-2 bg-blue-500/20 rounded-md">
                  <TrendingUp className="w-4 h-4 text-blue-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Yield Miner</div>
                  <div className="text-white text-xs font-mono">+12.4% APY</div>
                </div>
              </motion.div>

              {/* Risk Agent */}
              <motion.div 
                animate={{ y: [0, 20, 0] }}
                transition={{ duration: 5, repeat: Infinity, ease: "easeInOut", delay: 1 }}
                className="hidden md:flex absolute bottom-10 left-0 bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md items-center gap-3"
              >
                <div className="p-2 bg-red-500/20 rounded-md">
                   <ShieldAlert className="w-4 h-4 text-red-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Risk Agent</div>
                  <div className="text-white text-xs font-mono">Auditing...</div>
                </div>
              </motion.div>

              {/* Research Agent */}
              <motion.div 
                animate={{ x: [0, 10, 0], y: [0, -10, 0] }}
                transition={{ duration: 6, repeat: Infinity, ease: "easeInOut", delay: 2 }}
                className="hidden md:flex absolute top-20 left-[-20px] bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md items-center gap-3"
              >
                <div className="p-2 bg-purple-500/20 rounded-md">
                   <Search className="w-4 h-4 text-purple-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Research Agent</div>
                  <div className="text-white text-xs font-mono">Analyzing Proposals</div>
                </div>
              </motion.div>

              {/* Media Agent */}
              <motion.div 
                animate={{ x: [0, -10, 0], y: [0, 10, 0] }}
                transition={{ duration: 7, repeat: Infinity, ease: "easeInOut", delay: 3 }}
                className="hidden md:flex absolute bottom-20 right-[-10px] bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md items-center gap-3"
              >
                <div className="p-2 bg-pink-500/20 rounded-md">
                   <Radio className="w-4 h-4 text-pink-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Media Agent</div>
                  <div className="text-white text-xs font-mono">Broadcasting</div>
                </div>
              </motion.div>

            </motion.div>

            {/* Mobile Agent Cards Grid */}
            <div className="grid grid-cols-2 gap-4 md:hidden mt-8">
              <motion.div 
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6 }}
                className="bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md flex items-center gap-3"
              >
                <div className="p-2 bg-blue-500/20 rounded-md">
                  <TrendingUp className="w-4 h-4 text-blue-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Yield Miner</div>
                  <div className="text-white text-xs font-mono">+12.4% APY</div>
                </div>
              </motion.div>

              <motion.div 
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: 0.1 }}
                className="bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md flex items-center gap-3"
              >
                <div className="p-2 bg-red-500/20 rounded-md">
                  <ShieldAlert className="w-4 h-4 text-red-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Risk Agent</div>
                  <div className="text-white text-xs font-mono">Auditing...</div>
                </div>
              </motion.div>

              <motion.div 
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: 0.2 }}
                className="bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md flex items-center gap-3"
              >
                <div className="p-2 bg-purple-500/20 rounded-md">
                  <Search className="w-4 h-4 text-purple-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Research Agent</div>
                  <div className="text-white text-xs font-mono">Analyzing</div>
                </div>
              </motion.div>

              <motion.div 
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: 0.3 }}
                className="bg-space-800 border border-white/10 p-3 rounded-lg backdrop-blur-md flex items-center gap-3"
              >
                <div className="p-2 bg-pink-500/20 rounded-md">
                  <Radio className="w-4 h-4 text-pink-400" />
                </div>
                <div>
                  <div className="text-xs text-gray-400">Media Agent</div>
                  <div className="text-white text-xs font-mono">Broadcasting</div>
                </div>
              </motion.div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative z-10 bg-space-900 pt-20 pb-10 border-t border-white/10 w-full min-w-0 overflow-x-hidden">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 grid md:grid-cols-4 gap-12 mb-16 w-full min-w-0 box-border">
          <div className="col-span-1 md:col-span-2">
            <div className="flex items-center gap-2 mb-6">
              <img src="/logo.svg" alt="Loreum Logo" className="w-6 h-6" />
              <span className="text-2xl font-display tracking-wider">LOREUM</span>
            </div>
            <p className="text-gray-500 max-w-xs font-light">
              The Chamber Protocol — infrastructure for credibly neutral, agent-driven
              Decentralized Governance Systems in the CLARITY era.
            </p>
          </div>
          
          <div>
            <h4 className="font-bold tracking-widest text-sm mb-6">PLATFORM</h4>
            <ul className="space-y-4 text-sm text-gray-400 font-light">
              <li><Link to="/team" className="hover:text-white transition-colors">Team</Link></li>
              <li><Link to="/blog" className="hover:text-white transition-colors">Blog</Link></li>
              <li><a href="#" className="hover:text-white transition-colors">Agents</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Chambers</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Security</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Roadmap</a></li>
            </ul>
          </div>
          
          <div>
            <h4 className="font-bold tracking-widest text-sm mb-6">COMMUNITY</h4>
            <ul className="space-y-4 text-sm text-gray-400 font-light">
              <li><a href="#" className="hover:text-white transition-colors">Discord</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Twitter</a></li>
              <li><a href="#" className="hover:text-white transition-colors">GitHub</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Documentation</a></li>
            </ul>
          </div>
        </div>
        
        <div className="max-w-7xl mx-auto px-4 sm:px-6 pt-8 border-t border-white/5 flex flex-col md:flex-row items-center justify-between gap-4 text-xs text-gray-600 w-full min-w-0 box-border text-center md:text-start">
          <div>© 2026 LOREUM DAO LLC. ALL RIGHTS RESERVED.</div>
          <div className="flex gap-8">
            <a href="#" className="hover:text-gray-400">PRIVACY POLICY</a>
            <a href="#" className="hover:text-gray-400">TERMS OF SERVICE</a>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;
