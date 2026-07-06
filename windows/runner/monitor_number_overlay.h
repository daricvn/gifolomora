#ifndef RUNNER_MONITOR_NUMBER_OVERLAY_H_
#define RUNNER_MONITOR_NUMBER_OVERLAY_H_

#include <windows.h>

#include <vector>

// Transient "identify displays" overlay: one click-through, per-pixel-alpha
// window per monitor, each drawing a big white number (black outline) in the
// monitor's top-left corner. Shown fully opaque for kShowMs, then fades out
// over kFadeMs and self-destroys — no caller-driven Hide() needed.
//
// Positioned/sized in **physical** pixels, same space as RecordTarget.
class MonitorNumberOverlay {
 public:
  struct Spot {
    int x;
    int y;
    int number;
  };

  MonitorNumberOverlay();
  ~MonitorNumberOverlay();

  // Replaces any currently-showing overlay (old windows are torn down
  // immediately) and starts the show/fade timer from zero.
  void Show(const std::vector<Spot>& spots);

 private:
  static LRESULT CALLBACK TimerWndProc(HWND hwnd, UINT msg, WPARAM wparam,
                                       LPARAM lparam);
  void Tick();
  void RepaintWindow(HWND hwnd, int number, BYTE alpha);
  void DestroyAll();

  struct WindowEntry {
    HWND hwnd;
    int number;
  };

  HWND timer_hwnd_ = nullptr;
  std::vector<WindowEntry> windows_;
  ULONGLONG start_tick_ = 0;

  ULONG_PTR gdiplus_token_ = 0;
  bool gdiplus_started_ = false;
};

#endif  // RUNNER_MONITOR_NUMBER_OVERLAY_H_
