import type { Component } from 'solid-js';
import { createEffect, createSignal, For, onCleanup, onMount } from 'solid-js';

import cropImg from './assets/crop-feature.png';
import cutImg from './assets/cut-video.png';
import smoothVid from './assets/smooth-feature.webm';
import textImg from './assets/text-feature.png';
import webmVid from './assets/webm-convert-feature.webm';

const showcase = [
  {
    img: cropImg,
    alt: 'Gifolomora crop tool trimming a GIF with draggable handles and live preview',
    kicker: 'Crop',
    hue: '35',
    title: ['Crop', 'to', 'the', 'perfect', 'frame.'],
    desc: 'Drag the handles, watch the live preview, keep only what matters — works on GIFs and videos alike.',
  },
  {
    img: cutImg,
    alt: 'Video Studio cutting a section out of a video with frame-accurate range handles',
    kicker: 'Video Studio',
    hue: '265',
    title: ['Trim', 'it.', 'Cut', 'it.', 'Ship', 'it.'],
    desc: 'A full studio for your video — trim the ends, mark whole sections for removal, then export as video or GIF.',
  },
  {
    img: textImg,
    alt: 'Text overlay tool adding styled captions onto a GIF',
    kicker: 'Text Overlay',
    hue: '160',
    title: ['Words,', 'right', 'on', 'the', 'GIF.'],
    desc: 'Add captions with style, font, size and position control — rendered straight into every frame.',
  },
  {
    video: smoothVid,
    alt: 'Seamlessly looping GIF created with the smooth loop tool',
    kicker: 'Smooth Loop',
    hue: '200',
    title: ['Loops', 'without', 'the', 'seam.'],
    desc: 'Boomerang and crossfade blending turn any clip into a GIF that loops forever — no visible restart.',
  },
  {
    video: webmVid,
    alt: 'Converting a video and a GIF to WebM',
    kicker: 'To WebM',
    hue: '230',
    title: ['Any', 'clip.', 'One', 'tap.', 'WebM.'],
    desc: 'Convert video or GIF to WebM straight from the app — smaller files, same quality.',
  },
];

const SLIDE_MS = 6000;

const Showcase: Component = () => {
  const [slide, setSlide] = createSignal(0);
  let autoOk = false;
  let timer: number | undefined;
  const stopAuto = () => clearInterval(timer);
  const startAuto = () => {
    stopAuto();
    if (autoOk) timer = window.setInterval(() => setSlide((s) => (s + 1) % showcase.length), SLIDE_MS);
  };
  const go = (i: number) => {
    setSlide((i + showcase.length) % showcase.length);
    startAuto();
  };

  onMount(() => {
    autoOk = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    startAuto();
    onCleanup(stopAuto);
  });

  return (
    <>
      <div
        class="showcase glass showcase-enter"
        onMouseEnter={stopAuto}
        onMouseLeave={startAuto}
      >
        <For each={showcase}>
          {(s, i) => (
            <figure class="slide" classList={{ active: slide() === i() }} style={{ '--hue': s.hue }}>
              {s.video ? (
                <video
                  class="show-img"
                  src={s.video}
                  autoplay
                  loop
                  muted
                  playsinline
                  preload={i() === 0 ? 'auto' : 'none'}
                  aria-label={s.alt}
                  ref={(el) => {
                    // only the active slide's video actually plays — rest stay paused
                    createEffect(() => {
                      if (slide() === i()) el.play().catch(() => {});
                      else el.pause();
                    });
                  }}
                />
              ) : (
                <img
                  class="show-img"
                  src={s.img}
                  alt={s.alt}
                  loading={i() === 0 ? 'eager' : 'lazy'}
                  decoding="async"
                />
              )}
              <figcaption class="show-overlay">
                <span class="show-kicker">{s.kicker}</span>
                <h3 class="show-title">
                  <For each={s.title}>
                    {(w, j) => <span class="show-word" style={{ '--sd': `${j() * 80}ms` }}>{w}&nbsp;</span>}
                  </For>
                </h3>
                <p class="show-desc">{s.desc}</p>
              </figcaption>
            </figure>
          )}
        </For>
        <button class="slide-arrow prev" aria-label="Previous slide" onClick={() => go(slide() - 1)}>‹</button>
        <button class="slide-arrow next" aria-label="Next slide" onClick={() => go(slide() + 1)}>›</button>
      </div>
      <div class="slide-dots showcase-enter">
        <For each={showcase}>
          {(s, i) => (
            <button
              class="slide-dot"
              classList={{ on: slide() === i() }}
              aria-label={`Show ${s.kicker}`}
              onClick={() => go(i())}
            />
          )}
        </For>
      </div>
    </>
  );
};

export default Showcase;
