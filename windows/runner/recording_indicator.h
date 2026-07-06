#ifndef RUNNER_RECORDING_INDICATOR_H_
#define RUNNER_RECORDING_INDICATOR_H_

#include <windows.h>

#include <cstdint>

// Click-through, per-pixel-alpha overlay window sized to the **entire
// recorded monitor**, drawn natively (GDI+) — no Flutter content, no
// background fill except a pulsing red (amber while paused) border traced
// just inside the monitor's edges, plus a small status dot + text in the
// top-left corner. WS_EX_TRANSPARENT makes every mouse event pass straight
// through to whatever is underneath (the app itself is controlled by global
// hotkeys only while this is up, never by clicking the indicator).
//
// Positioned/sized in **physical** pixels — the same coordinate space as
// gdigrab and SetWindowDisplayAffinity — so the caller (Dart) passes
// RecordTarget's physical monitor bounds directly, no extra DPI conversion.
class RecordingIndicator {
 public:
  RecordingIndicator();
  ~RecordingIndicator();

  // Returns false if GDI+ failed to start or the window couldn't be
  // created/found — the caller (Dart, via the method channel result) can
  // then tell "the call succeeded but nothing is actually visible" apart
  // from a real success, instead of both looking identical.
  bool Show(int x, int y, int width, int height);
  void Update(bool paused, int64_t elapsedMs, int64_t maxMs, bool micOn,
             bool systemAudioOn);
  void Hide();

  // Diagnostics for the last Repaint() — surfaced back to Dart via the
  // method channel result so a "call succeeded but nothing visible" failure
  // is distinguishable from a real success instead of looking identical.
  bool LastUpdateLayeredWindowOk() const { return last_ulw_ok_; }
  bool LastDibCreateOk() const { return last_dib_ok_; }

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam,
                                  LPARAM lparam);
  bool EnsureWindow(int x, int y, int width, int height);
  void Repaint();

  HWND hwnd_ = nullptr;
  int x_ = 0;
  int y_ = 0;
  int width_ = 0;
  int height_ = 0;
  bool last_ulw_ok_ = false;
  bool last_dib_ok_ = false;

  bool paused_ = false;
  int64_t elapsed_ms_ = 0;
  int64_t max_ms_ = 600000;
  bool mic_on_ = false;
  bool system_audio_on_ = false;

  // Pulse phase in radians, advanced ~30x/sec by a window timer; frozen
  // (and the dot switched to solid amber) while paused_.
  double pulse_phase_ = 0.0;

  ULONG_PTR gdiplus_token_ = 0;
  bool gdiplus_started_ = false;
};

#endif  // RUNNER_RECORDING_INDICATOR_H_
