import type { Component } from 'solid-js';
import { For, onMount } from 'solid-js';

const releases = [
  { v: '1.0.1', notes: ['Add recording feature.', 'Add WebM format support.', 'Update UI.'] },
  { v: '1.0.0', notes: ['Initial version.'] },
];

const Changelog: Component<{ onClose: () => void }> = (props) => {
  let el: HTMLDialogElement | undefined;
  onMount(() => el?.showModal());

  return (
    <dialog
      class="about glass"
      ref={el}
      onClick={(e) => { if (e.target === el) el?.close(); }}
      onClose={() => props.onClose()}
    >
      <div class="about-body">
        <button class="about-close" aria-label="Close" onClick={() => el?.close()}>✕</button>
        <h2>Changelog</h2>
        <For each={releases}>
          {(r) => (
            <div class="changelog-entry">
              <h3>{r.v}</h3>
              <ul>
                <For each={r.notes}>{(n) => <li>{n}</li>}</For>
              </ul>
            </div>
          )}
        </For>
      </div>
    </dialog>
  );
};

export default Changelog;
