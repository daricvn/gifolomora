import type { Component } from 'solid-js';
import { For, onMount } from 'solid-js';

// ponytail: fill with real release URL when available
const DOWNLOAD_WIN = 'https://1drv.ms/u/c/15f9d9574a5f179d/IQB0HJhNzHUoSJ1p-Q8flNABAd6C3IPd_ZGdiROUsg75DyM?e=67yIPh';

const features = [
  { ico: '🎬', title: 'Video Studio', desc: 'Composite editor for video layers — crop, resize, speed, trim, text overlay. Export to video or GIF.' },
  { ico: '🖼️', title: 'Images → GIF', desc: 'Build GIFs from image sequences with frame rate and scale control.' },
  { ico: '📐', title: 'Resize', desc: 'Scale GIFs to any custom dimensions while keeping quality.' },
  { ico: '✂️', title: 'Crop', desc: 'Trim GIF content by region with a live preview.' },
  { ico: '🔤', title: 'Text Overlay', desc: 'Add custom text with font and position control.' },
  { ico: '⚡', title: 'Optimize', desc: 'Shrink file size via palette quantization and inter-frame transparency. Pure-Dart, no binary.' },
  { ico: '🌀', title: 'Effects', desc: 'Speed adjustment and frame reversal in one tap.' },
  { ico: '🕓', title: 'Recent Exports', desc: 'Live previews, progress tracking with cancel, and an export history.' },
];

const App: Component = () => {
  let bannerImg: HTMLImageElement | undefined;

  onMount(() => {
    // reveal-on-scroll: add .in when element enters viewport
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            e.target.classList.add('in');
            io.unobserve(e.target);
          }
        }
      },
      { threshold: 0.15 },
    );
    document.querySelectorAll('.reveal').forEach((el) => io.observe(el));

    // parallax: banner image drifts slower than scroll for depth
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce || !bannerImg) return;
    let ticking = false;
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const y = Math.min(window.scrollY, 800);
        bannerImg!.style.transform = `translate3d(0, ${y * 0.12}px, 0)`;
        ticking = false;
      });
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  });

  return (
    <>
      <nav class="nav glass">
        <div class="brand">
          <span class="dot" />
          Gifolomora
        </div>
        <div>
          <a class="navlink" href="#features">Features</a>
          <a class="navlink" href="#download">Download</a>
        </div>
      </nav>

      <header class="wrap hero">
        <span class="pill glass anim-1">✨ Glassmorphism GIF editor for Windows <em class="tag">Alpha</em></span>
        <h1 class="anim-2">
          Create, edit & optimize <span class="grad-text">GIFs</span><br />
          with a sleek glass interface
        </h1>
        <p class="sub anim-3">
          Gifolomora turns videos and image sequences into polished GIFs using 7 specialized
          tools — all wrapped in a beautiful glass-themed UI. Fast, private, cross-platform.
        </p>
        <div class="cta anim-4">
          <a class="btn btn-primary shine" href="#download">⬇ Download free</a>
          <a class="btn btn-ghost" href="#features">Explore features</a>
        </div>

        <div class="banner anim-5">
          <img ref={bannerImg} src="./banner.png" alt="Gifolomora — cross-platform video & GIF editor & maker" />
        </div>
      </header>

      <section id="features" class="wrap section">
        <h2 class="reveal">Seven tools, one glass workspace</h2>
        <p class="lead reveal">
          Everything you need to make and refine GIFs — with live previews and user-driven exports.
        </p>
        <div class="grid">
          <For each={features}>
            {(f, i) => (
              <div class="card glass reveal" style={{ '--d': `${i() * 70}ms` }}>
                <div class="ico">{f.ico}</div>
                <h3>{f.title}</h3>
                <p>{f.desc}</p>
              </div>
            )}
          </For>
        </div>
      </section>

      <section id="download" class="wrap section">
        <div class="download glass reveal">
          <h2>Get Gifolomora <em class="tag">Alpha</em></h2>
          <p class="lead">Free early build for Windows. Grab it and start making GIFs in seconds.</p>
          <div class="cta">
            <a class="btn btn-primary shine" href={DOWNLOAD_WIN}>🪟 Download for Windows</a>
            <span class="btn btn-ghost disabled">🤖 Android — coming soon</span>
          </div>
          <p class="meta">Windows (MSIX) · Alpha build, expect rough edges · Android in the works</p>
        </div>
      </section>

      <footer class="footer wrap">
        Gifolomora — proprietary software by Takayoshi Code.
      </footer>
    </>
  );
};

export default App;
