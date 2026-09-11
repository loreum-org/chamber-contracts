import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import { Link, useParams } from 'react-router-dom';
import Markdown from 'react-markdown';
import { formatPostDate, getPost, posts } from './posts.ts';
import Footer from './Footer.tsx';

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

const markdownComponents = {
  h1: ({ children }: { children?: React.ReactNode }) => (
    <h1 className="text-3xl md:text-4xl font-display mb-6 text-white">{children}</h1>
  ),
  h2: ({ children }: { children?: React.ReactNode }) => (
    <h2 className="text-2xl font-display mb-4 mt-8 text-white">{children}</h2>
  ),
  h3: ({ children }: { children?: React.ReactNode }) => (
    <h3 className="text-xl font-display mb-3 mt-6 text-white">{children}</h3>
  ),
  p: ({ children }: { children?: React.ReactNode }) => (
    <p className="text-gray-300 leading-relaxed mb-4">{children}</p>
  ),
  ul: ({ children }: { children?: React.ReactNode }) => (
    <ul className="list-disc pl-6 mb-4 space-y-2 text-gray-300">{children}</ul>
  ),
  ol: ({ children }: { children?: React.ReactNode }) => (
    <ol className="list-decimal pl-6 mb-4 space-y-2 text-gray-300">{children}</ol>
  ),
  li: ({ children }: { children?: React.ReactNode }) => (
    <li className="leading-relaxed">{children}</li>
  ),
  a: ({ href, children }: { href?: string; children?: React.ReactNode }) => (
    <a href={href} className="text-space-accent hover:text-white underline underline-offset-2">
      {children}
    </a>
  ),
  code: ({ children }: { children?: React.ReactNode }) => (
    <code className="font-mono text-sm text-space-accent break-all">{children}</code>
  ),
  pre: ({ children }: { children?: React.ReactNode }) => (
    <pre className="bg-space-800/60 border border-white/10 rounded-lg p-4 overflow-x-auto mb-4 text-sm">
      {children}
    </pre>
  ),
  strong: ({ children }: { children?: React.ReactNode }) => (
    <strong className="text-white font-normal">{children}</strong>
  ),
};

function BlogChrome({ title, children }: { title: string; children: React.ReactNode }) {
  useEffect(() => {
    document.title = title;
    return () => {
      document.title = 'Loreum — Chamber: onchain governance for DAOs';
    };
  }, [title]);

  return (
    <div className="min-h-screen w-full min-w-0 bg-space-900 text-white selection:bg-space-accent selection:text-space-900 overflow-x-hidden relative">
      <div className="fixed inset-0 z-0 opacity-40 pointer-events-none">
        <div className="absolute top-10 left-20 w-1 h-1 bg-white rounded-full animate-pulse-slow"></div>
        <div className="absolute top-40 right-40 w-2 h-2 bg-space-accent rounded-full animate-pulse"></div>
        <div className="absolute bottom-20 left-1/3 w-1 h-1 bg-white rounded-full opacity-50"></div>
        <div className="absolute top-1/4 right-10 w-1.5 h-1.5 bg-blue-400 rounded-full animate-pulse-slow delay-700"></div>
        <div className="absolute top-[-20%] right-[-10%] w-[800px] h-[800px] bg-blue-900/20 rounded-full blur-[120px]"></div>
        <div className="absolute bottom-[-20%] left-[-10%] w-[600px] h-[600px] bg-purple-900/20 rounded-full blur-[100px]"></div>
      </div>

      <nav className="relative z-50 flex items-center justify-between gap-4 px-4 sm:px-8 py-6 max-w-7xl mx-auto w-full min-w-0 box-border">
        <Link to="/" className="flex items-center gap-2">
          <img src="/logo.svg" alt="Loreum Logo" className="w-8 h-8" />
          <span className="text-2xl font-display tracking-wider">LOREUM</span>
        </Link>
        <div className="hidden md:flex items-center gap-8 font-light tracking-wide text-sm">
          <a href="/#clarity" className="hover:text-space-accent transition-colors">CLARITY</a>
          <a href="/#mission" className="hover:text-space-accent transition-colors">MISSION</a>
          <a href="/#technology" className="hover:text-space-accent transition-colors">TECHNOLOGY</a>
          <a href="/#governance" className="hover:text-space-accent transition-colors">GOVERNANCE</a>
          <Link to="/team" className="hover:text-space-accent transition-colors">TEAM</Link>
          <Link to="/blog" className="text-space-accent transition-colors">BLOG</Link>
        </div>
        <a
          href={chamberAppUrl}
          className="hidden md:flex items-center gap-2 border border-white/20 px-6 py-2 rounded-full hover:bg-white/10 transition-all text-sm tracking-wide"
        >
          LAUNCH APP
        </a>
      </nav>

      {children}

      <Footer />
    </div>
  );
}

export function BlogIndex() {
  return (
    <BlogChrome title="Blog — Loreum">
      <section className="relative z-10 py-20 md:py-32 px-4 sm:px-6 w-full min-w-0 box-border">
        <div className="max-w-7xl mx-auto w-full min-w-0 px-1 sm:px-0">
          <FadeIn className="mb-20 max-w-4xl">
            <div className="mb-6 inline-block max-w-full px-3 sm:px-4 py-1.5 rounded-full border border-space-accent/30 bg-space-accent/10 text-space-accent text-xs tracking-[0.2em] backdrop-blur-sm">
              CHANGELOG
            </div>
            <h1 className="text-3xl sm:text-4xl md:text-6xl font-display mb-8 leading-tight break-words text-balance">
              Blog
            </h1>
            <p className="text-lg md:text-xl text-gray-400 font-light leading-relaxed break-words">
              Daily changelog and feature updates for Chamber.
            </p>
          </FadeIn>

          <div className="space-y-6 max-w-4xl">
            {posts.map((post, i) => (
              <FadeIn key={post.slug} delay={i * 0.1}>
                <article className="p-8 bg-space-800/40 backdrop-blur-md border border-white/10 rounded-xl hover:border-white/20 transition-all duration-500 hover:translate-y-[-4px] hover:shadow-2xl">
                  <p className="text-xs tracking-[0.2em] text-space-accent mb-3">
                    {formatPostDate(post.date)}
                  </p>
                  <h2 className="text-2xl md:text-3xl font-display mb-4 tracking-wide text-white">
                    <Link to={`/blog/${post.slug}`} className="hover:text-space-accent transition-colors">
                      {post.title}
                    </Link>
                  </h2>
                  <p className="text-gray-400 leading-relaxed text-sm mb-6">
                    {post.summary}
                  </p>
                  <Link
                    to={`/blog/${post.slug}`}
                    className="inline-flex items-center gap-2 text-space-accent hover:text-white transition-colors tracking-widest text-sm font-bold"
                  >
                    READ
                  </Link>
                </article>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>
    </BlogChrome>
  );
}

export function BlogPost() {
  const { slug } = useParams<{ slug: string }>();
  const post = slug ? getPost(slug) : undefined;

  if (!post) {
    return (
      <BlogChrome title="Post not found — Loreum">
        <section className="relative z-10 py-20 md:py-32 px-4 sm:px-6 w-full min-w-0 box-border">
          <div className="max-w-4xl mx-auto">
            <h1 className="text-3xl sm:text-4xl md:text-6xl font-display mb-8 leading-tight">
              Post not found
            </h1>
            <p className="text-gray-400 font-light mb-8">
              That changelog entry is not in the archive.
            </p>
            <Link to="/blog" className="text-space-accent hover:text-white transition-colors tracking-widest text-sm font-bold">
              BACK TO BLOG
            </Link>
          </div>
        </section>
      </BlogChrome>
    );
  }

  return (
    <BlogChrome title={`${post.title} — Loreum`}>
      <section className="relative z-10 py-20 md:py-32 px-4 sm:px-6 w-full min-w-0 box-border">
        <div className="max-w-4xl mx-auto w-full min-w-0 px-1 sm:px-0">
          <FadeIn>
            <Link
              to="/blog"
              className="inline-block mb-8 text-sm tracking-wide text-gray-500 hover:text-white transition-colors"
            >
              ← Blog
            </Link>
            <p className="text-xs tracking-[0.2em] text-space-accent mb-4">
              {formatPostDate(post.date)}
            </p>
            <h1 className="text-3xl sm:text-4xl md:text-6xl font-display mb-10 leading-tight break-words text-balance">
              {post.title}
            </h1>
            <div className="max-w-none">
              <Markdown components={markdownComponents}>{post.body}</Markdown>
            </div>
          </FadeIn>
        </div>
      </section>
    </BlogChrome>
  );
}
