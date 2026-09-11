import { Link } from 'react-router-dom';

/** Production default so CTAs work when env is unset in a static build. */
const chamberAppUrl =
  (import.meta.env.VITE_CHAMBER_APP_URL as string | undefined)?.trim() ||
  'https://app.loreum.org';

const itemClass = 'hover:text-white transition-colors';

/**
 * Landing footer. Every link is a live destination — Team, Blog, Chambers,
 * X, GitHub, and docs.loreum.org. Dead stubs (Agents, Roadmap, Security,
 * Discord, Privacy, Terms) are omitted until real pages exist.
 */
function Footer() {
  return (
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
            <li><Link to="/team" className={itemClass}>Team</Link></li>
            <li><Link to="/blog" className={itemClass}>Blog</Link></li>
            <li><a href={chamberAppUrl} className={itemClass}>Chambers</a></li>
          </ul>
        </div>

        <div>
          <h4 className="font-bold tracking-widest text-sm mb-6">COMMUNITY</h4>
          <ul className="space-y-4 text-sm text-gray-400 font-light">
            <li>
              <a
                href="https://x.com/loreumdao"
                target="_blank"
                rel="noopener noreferrer"
                className={itemClass}
              >
                X
              </a>
            </li>
            <li>
              <a
                href="https://github.com/loreum-org/chamber"
                target="_blank"
                rel="noopener noreferrer"
                className={itemClass}
              >
                GitHub
              </a>
            </li>
            <li>
              <a
                href="https://docs.loreum.org"
                target="_blank"
                rel="noopener noreferrer"
                className={itemClass}
              >
                Documentation
              </a>
            </li>
          </ul>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 pt-8 border-t border-white/5 flex flex-col md:flex-row items-center justify-between gap-4 text-xs text-gray-600 w-full min-w-0 box-border text-center md:text-start">
        <div>© 2026 LOREUM DAO LLC. ALL RIGHTS RESERVED.</div>
      </div>
    </footer>
  );
}

export default Footer;
