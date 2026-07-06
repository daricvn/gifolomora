import type { Component } from 'solid-js';
import { createSignal, For, lazy, onCleanup, onMount, Show, Suspense } from 'solid-js';

// code-split: slideshow chunk (and its image URLs) load only when the section nears the viewport
const Showcase = lazy(() => import('./Showcase'));

// ponytail: fill with real release URL when available
const DOWNLOAD_WIN = 'https://1drv.ms/u/c/15f9d9574a5f179d/IQB0HJhNzHUoSJ1p-Q8flNABAd6C3IPd_ZGdiROUsg75DyM?e=67yIPh';

const features = [
  { ico: '🎬', hue: '265', title: 'Video Studio', desc: 'Composite editor — crop, resize, speed, trim, cut, boomerang, smooth loop, volume, text overlay, full undo/redo. Export to video or GIF.', big: true },
  { ico: '🖼️', hue: '200', title: 'Images → GIF', desc: 'Build GIFs from image sequences with frame rate and scale control.' },
  { ico: '⏺️', hue: '350', wide: true, title: 'Screen Record', desc: 'Capture your screen, then jump straight into Video Studio to edit.' },
  { ico: '📐', hue: '330', title: 'Resize', desc: 'Scale GIFs to any custom dimensions while keeping quality.' },
  { ico: '✂️', hue: '35', title: 'Crop', desc: 'Trim GIF content by region with a live preview.' },
  { ico: '🔤', hue: '160', title: 'Text Overlay', desc: 'Add custom text with font and position control.' },
  { ico: '⚡', hue: '265', wide: true, title: 'Optimize', desc: 'Shrink file size via palette quantization and inter-frame transparency. Live progress, tuned for large video. Pure-Dart, no binary.' },
  { ico: '🌀', hue: '200', title: 'Effects', desc: 'Speed adjustment and frame reversal in one tap.' },
  { ico: '🎞️', hue: '230', title: 'To WebM', desc: 'Convert any video or GIF to WebM.' },
  { ico: '🕓', hue: '330', wide: true, title: 'Recent Exports', desc: 'Live previews, progress tracking with cancel, and an export history.' },
];

const ticker = ['Video Studio', 'Images → GIF', 'Screen Record', 'Resize', 'Crop', 'Text Overlay', 'Optimize', 'Effects', 'To WebM', 'Recent Exports'];

const HEADLINE_A = ['GIF', 'magic,'];
const HEADLINE_B = ['wrapped', 'in', 'liquid', 'glass.'];

const App: Component = () => {
  let heroEl: HTMLElement | undefined;
  let bannerWrap: HTMLDivElement | undefined;
  let showcaseEl: HTMLElement | undefined;

  // gate for the lazy slideshow chunk
  const [showcaseNear, setShowcaseNear] = createSignal(false);

  onMount(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const coarse = window.matchMedia('(pointer: coarse)').matches;

    // fetch the slideshow chunk when its section is within ~600px of the viewport
    if (showcaseEl) {
      const near = new IntersectionObserver(
        (entries) => {
          if (entries.some((e) => e.isIntersecting)) {
            setShowcaseNear(true);
            near.disconnect();
          }
        },
        { rootMargin: '600px' },
      );
      near.observe(showcaseEl);
      onCleanup(() => near.disconnect());
    }

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
    onCleanup(() => io.disconnect());

    if (reduce) return;

    // scroll scrub: banner un-tilts (rotateX 16° → 0) and settles over first 480px
    let ticking = false;
    const onScroll = () => {
      if (ticking || !bannerWrap) return;
      ticking = true;
      requestAnimationFrame(() => {
        const t = Math.min(window.scrollY / 480, 1);
        const rx = 16 * (1 - t);
        const sc = 0.94 + 0.06 * t;
        bannerWrap!.style.transform = `perspective(1100px) rotateX(${rx}deg) scale(${sc})`;
        ticking = false;
      });
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    onCleanup(() => window.removeEventListener('scroll', onScroll));

    // mouse parallax: hero depth layers drift toward cursor (desktop only)
    if (!coarse && heroEl) {
      const layers = heroEl.querySelectorAll<HTMLElement>('[data-depth]');
      let raf = 0;
      const onMove = (ev: MouseEvent) => {
        cancelAnimationFrame(raf);
        raf = requestAnimationFrame(() => {
          const cx = ev.clientX / window.innerWidth - 0.5;
          const cy = ev.clientY / window.innerHeight - 0.5;
          layers.forEach((l) => {
            const d = Number(l.dataset.depth) * 14;
            l.style.transform = `translate3d(${cx * d}px, ${cy * d}px, 0)`;
          });
        });
      };
      window.addEventListener('mousemove', onMove, { passive: true });
      onCleanup(() => window.removeEventListener('mousemove', onMove));
    }

    // bento spotlight: track cursor per card as --mx/--my
    const grid = document.querySelector<HTMLElement>('.bento');
    if (!coarse && grid) {
      const onGridMove = (ev: MouseEvent) => {
        grid.querySelectorAll<HTMLElement>('.card').forEach((c) => {
          const r = c.getBoundingClientRect();
          c.style.setProperty('--mx', `${ev.clientX - r.left}px`);
          c.style.setProperty('--my', `${ev.clientY - r.top}px`);
        });
      };
      grid.addEventListener('mousemove', onGridMove, { passive: true });
      onCleanup(() => grid.removeEventListener('mousemove', onGridMove));
    }
  });

  return (
    <>
      <div class="grain" aria-hidden="true" />

      <nav class="nav glass">
        <div class="brand">
          <span class="dot" />
          <span class="brand-name">Gifolomora</span>
        </div>
        <div class="nav-right">
          <a class="navlink" href="#features">Features</a>
          <a class="navlink" href="#showcase">Showcase</a>
          <a class="btn btn-primary btn-sm shine" href="#download">⬇ Download</a>
        </div>
      </nav>

      <header class="hero" ref={heroEl}>
        {/* depth-1: atmosphere glow */}
        <div class="layer glow-a" data-depth="1" aria-hidden="true" />
        <div class="layer glow-b" data-depth="1" aria-hidden="true" />
        {/* depth-2: floating glass orbs */}
        <div class="layer orb orb-1 float-a" data-depth="2" aria-hidden="true" />
        <div class="layer orb orb-2 float-b" data-depth="2" aria-hidden="true" />
        <div class="layer orb orb-3 float-c" data-depth="3" aria-hidden="true" />
        {/* depth-5: foreground sparkles */}
        <div class="layer spark spark-1" data-depth="5" aria-hidden="true" />
        <div class="layer spark spark-2" data-depth="5" aria-hidden="true" />
        <div class="layer spark spark-3" data-depth="5" aria-hidden="true" />

        <div class="wrap hero-inner">
          <span class="pill glass anim-1"><i class="pulse" aria-hidden="true" /> Now available for Windows — free</span>
          <h1>
            <span class="line">
              <For each={HEADLINE_A}>
                {(w, i) => <span class="word grad-text" style={{ '--wd': `${i() * 90}ms` }}>{w}&nbsp;</span>}
              </For>
            </span>
            <span class="line">
              <For each={HEADLINE_B}>
                {(w, i) => <span class="word" style={{ '--wd': `${180 + i() * 90}ms` }}>{w}&nbsp;</span>}
              </For>
            </span>
          </h1>
          <p class="sub anim-3">
            Gifolomora turns videos and image sequences into polished GIFs using 9 specialized
            tools — all wrapped in a beautiful glass-themed UI. Fast, private, cross-platform.
          </p>
          <div class="cta anim-4">
            <a class="btn btn-primary shine" href="#download">⬇ Download free</a>
            <a class="btn btn-ghost" href="#features">Explore features</a>
          </div>

          <div class="banner-stage anim-5">
            <div class="banner" ref={bannerWrap}>
              <img src="./banner.png" alt="Gifolomora — cross-platform video & GIF editor & maker" />
            </div>
          </div>
        </div>
      </header>

      <div class="marquee" aria-hidden="true">
        <div class="marquee-track">
          <For each={[...ticker, ...ticker]}>
            {(t) => <span class="marquee-item">{t}<i class="marquee-dot" /></span>}
          </For>
        </div>
      </div>

      <section id="features" class="wrap section">
        <h2 class="reveal">Nine tools, one glass workspace</h2>
        <p class="lead reveal">
          Everything you need to make and refine GIFs — with live previews and user-driven exports.
        </p>
        <div class="bento">
          <For each={features}>
            {(f, i) => (
              <div
                class="card glass reveal"
                classList={{ big: !!f.big, wide: !!f.wide }}
                style={{ '--d': `${i() * 60}ms`, '--hue': f.hue }}
              >
                <div class="ico">{f.ico}</div>
                <h3>{f.title}</h3>
                <p>{f.desc}</p>
              </div>
            )}
          </For>
        </div>
      </section>

      <section id="showcase" class="wrap section" ref={showcaseEl}>
        <h2 class="reveal">See it in action</h2>
        <p class="lead reveal">
          Real tools, real previews — captured straight from the app.
        </p>
        {/* slot reserves space so the lazy chunk doesn't shift layout */}
        <div class="showcase-slot">
          <Show when={showcaseNear()}>
            <Suspense>
              <Showcase />
            </Suspense>
          </Show>
        </div>
      </section>

      <section id="download" class="wrap section">
        <div class="download-ring reveal">
          <div class="download glass">
            <img class="app-icon float-b" src="./app.png" alt="" aria-hidden="true" />
            <h2>Get Gifolomora</h2>
            <p class="lead">Free for Windows. Grab it and start making GIFs in seconds.</p>
            <div class="cta">
              <a class="btn btn-primary shine" href={DOWNLOAD_WIN}>🪟 Download for Windows</a>
              <span class="btn btn-ghost disabled">🤖 Android — coming soon</span>
            </div>
            <p class="meta">Windows (7z) · Free · Android in the works</p>
          </div>
        </div>
      </section>

      <footer class="footer wrap">
        Gifolomora — proprietary software by Takayoshi Code.
      </footer>
    </>
  );
};

export default App;
