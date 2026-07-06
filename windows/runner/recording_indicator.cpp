#include "recording_indicator.h"

#include <objidl.h>
#include <gdiplus.h>

#include <cmath>
#include <string>

#pragma comment(lib, "gdiplus.lib")

#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace {
constexpr wchar_t kClassName[] = L"GifolomoraRecordingIndicator";
constexpr UINT_PTR kPulseTimerId = 1;
constexpr UINT kPulseIntervalMs = 33;  // ~30fps

// Draws [text] with a cheap 1px dark outline (four offset copies) so it
// stays legible with no background fill behind it, over any content.
void DrawOutlinedText(Gdiplus::Graphics& g, const std::wstring& text,
                     const Gdiplus::Font& font, const Gdiplus::PointF& at) {
  Gdiplus::SolidBrush outline(Gdiplus::Color(200, 0, 0, 0));
  const float offsets[4][2] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};
  for (auto& o : offsets) {
    g.DrawString(text.c_str(), -1, &font,
                Gdiplus::PointF(at.X + o[0], at.Y + o[1]), &outline);
  }
  Gdiplus::SolidBrush fill(Gdiplus::Color(255, 255, 255, 255));
  g.DrawString(text.c_str(), -1, &font, at, &fill);
}

std::wstring FormatMmSs(int64_t ms) {
  int totalSeconds = static_cast<int>(ms / 1000);
  int m = totalSeconds / 60;
  int s = totalSeconds % 60;
  wchar_t buf[16];
  swprintf_s(buf, L"%d:%02d", m, s);
  return buf;
}

}  // namespace

RecordingIndicator::RecordingIndicator() {}

RecordingIndicator::~RecordingIndicator() {
  Hide();
  if (gdiplus_started_) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_started_ = false;
  }
}

LRESULT CALLBACK RecordingIndicator::WndProc(HWND hwnd, UINT msg,
                                             WPARAM wparam, LPARAM lparam) {
  auto* self = reinterpret_cast<RecordingIndicator*>(
      GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (msg == WM_TIMER && wparam == kPulseTimerId && self) {
    if (!self->paused_) {
      self->pulse_phase_ += 0.15;
      self->Repaint();
    }
    return 0;
  }
  return DefWindowProc(hwnd, msg, wparam, lparam);
}

bool RecordingIndicator::EnsureWindow(int x, int y, int width, int height) {
  bool gdiplus_ok = gdiplus_started_;
  if (!gdiplus_started_) {
    Gdiplus::GdiplusStartupInput startupInput;
    Gdiplus::Status status =
        Gdiplus::GdiplusStartup(&gdiplus_token_, &startupInput, nullptr);
    gdiplus_started_ = true;  // Shutdown() must still pair even on failure.
    gdiplus_ok = (status == Gdiplus::Ok);
  }

  HINSTANCE hInstance = GetModuleHandle(nullptr);

  static bool class_registered = false;
  if (!class_registered) {
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = kClassName;
    RegisterClassExW(&wc);
    class_registered = true;
  }

  x_ = x;
  y_ = y;
  width_ = width;
  height_ = height;

  if (!hwnd_) {
    // WS_EX_TRANSPARENT: every mouse message passes through to whatever is
    // underneath — this indicator is never clickable, hotkeys are the only
    // control surface. WS_EX_LAYERED: required for UpdateLayeredWindow's
    // per-pixel alpha (no background fill). WS_EX_TOOLWINDOW +
    // WS_EX_NOACTIVATE: never shows in the taskbar/alt-tab, never steals
    // focus.
    hwnd_ = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW |
            WS_EX_NOACTIVATE,
        kClassName, L"", WS_POPUP, x, y, width, height, nullptr, nullptr,
        hInstance, nullptr);
    SetWindowLongPtr(hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
    // Non-fatal pre-Windows-10-2004 — the indicator just appears in the
    // recording on older builds, same degradation as the app window used to
    // accept for the old morph-based overlay.
    SetWindowDisplayAffinity(hwnd_, WDA_EXCLUDEFROMCAPTURE);
    SetTimer(hwnd_, kPulseTimerId, kPulseIntervalMs, nullptr);
  } else {
    SetWindowPos(hwnd_, HWND_TOPMOST, x, y, width, height,
                SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
  ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
  return gdiplus_ok && hwnd_ != nullptr;
}

bool RecordingIndicator::Show(int x, int y, int width, int height) {
  bool ok = EnsureWindow(x, y, width, height);
  Repaint();
  // Fold in the actual paint result — a window that was created fine but
  // whose first UpdateLayeredWindow call failed is otherwise indistinguishable
  // from a real success on the Dart side.
  return ok && last_dib_ok_ && last_ulw_ok_;
}

void RecordingIndicator::Update(bool paused, int64_t elapsedMs, int64_t maxMs,
                                bool micOn, bool systemAudioOn) {
  paused_ = paused;
  elapsed_ms_ = elapsedMs;
  max_ms_ = maxMs;
  mic_on_ = micOn;
  system_audio_on_ = systemAudioOn;
  if (hwnd_) Repaint();
}

void RecordingIndicator::Hide() {
  if (hwnd_) {
    KillTimer(hwnd_, kPulseTimerId);
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
}

void RecordingIndicator::Repaint() {
  if (!hwnd_ || width_ <= 0 || height_ <= 0) return;

  // Reassert every tick: another app going topmost after us (a dialog, a
  // different always-on-top overlay) otherwise sinks this window for good —
  // Show() only sets HWND_TOPMOST once, at recording start.
  SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0,
              SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  HDC screenDC = GetDC(nullptr);
  HDC memDC = CreateCompatibleDC(screenDC);

  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = width_;
  bmi.bmiHeader.biHeight = -height_;  // top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  HBITMAP dib =
      CreateDIBSection(screenDC, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HGDIOBJ oldBmp = SelectObject(memDC, dib);

  last_dib_ok_ = (bits != nullptr);

  if (bits) {
    Gdiplus::Bitmap bitmap(width_, height_, width_ * 4,
                          PixelFormat32bppPARGB, static_cast<BYTE*>(bits));
    Gdiplus::Graphics graphics(&bitmap);
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    // ClearType assumes an opaque background and fringes badly composited
    // over a transparent layered surface — plain antialiasing is the
    // correct choice here, not the usual ClearType/AntiAliasGridFit hint.
    graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAlias);

    double pulseAlpha = 0.35 + 0.65 * (0.5 + 0.5 * std::sin(pulse_phase_));
    BYTE a = paused_ ? 255 : static_cast<BYTE>(pulseAlpha * 255);
    Gdiplus::Color pulseColor = paused_ ? Gdiplus::Color(a, 255, 176, 32)
                                       : Gdiplus::Color(a, 255, 59, 92);

    // Border traces the full recorded area — this window is sized to the
    // whole monitor, not just a small pill. Inset a few px so the stroke
    // stays fully inbound: drawn exactly on the outer edge (inset 0), the
    // outermost ~1px can be clipped by the monitor/DWM edge on some setups.
    const float kBorderInset = 3.0f;
    const float kBorderWidth = 2.0f;
    Gdiplus::Pen borderPen(pulseColor, kBorderWidth);
    graphics.DrawRectangle(
        &borderPen, kBorderInset, kBorderInset,
        width_ - 2 * kBorderInset, height_ - 2 * kBorderInset);

    // Status dot + text — fixed top-left placement (this window covers the
    // full monitor now, so "center of window" would mean "center of screen").
    const float margin = 20.0f;
    const float radius = 7.0f;
    const float cx = margin + radius;
    const float cy = margin + radius;
    Gdiplus::SolidBrush dotBrush(pulseColor);
    graphics.FillEllipse(&dotBrush, cx - radius, cy - radius, radius * 2,
                        radius * 2);

    Gdiplus::FontFamily fontFamily(L"Segoe UI");
    Gdiplus::Font titleFont(&fontFamily, 13, Gdiplus::FontStyleBold,
                           Gdiplus::UnitPixel);
    Gdiplus::Font detailFont(&fontFamily, 11, Gdiplus::FontStyleRegular,
                            Gdiplus::UnitPixel);

    std::wstring title = paused_ ? L"Paused" : L"Recording";
    DrawOutlinedText(graphics, title, titleFont,
                     Gdiplus::PointF(cx + radius + 10, cy - 15));

    std::wstring detail =
        FormatMmSs(elapsed_ms_) + L" / " + FormatMmSs(max_ms_);
    if (mic_on_) detail += L"  MIC";
    if (system_audio_on_) detail += L"  SYS";
    DrawOutlinedText(graphics, detail, detailFont,
                     Gdiplus::PointF(cx + radius + 10, cy + 3));
  }

  // Passed explicitly (not nullptr for "keep current") — the documented-safe,
  // universally-used pattern for UpdateLayeredWindow; relying on implicit
  // reuse of the CreateWindowExW-time position/size was the suspected cause
  // of the window rendering fully blank (no error, no exception — the
  // layered surface just never actually got established).
  POINT ptDst = {x_, y_};
  SIZE sizeWnd = {width_, height_};
  POINT ptSrc = {0, 0};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  last_ulw_ok_ = UpdateLayeredWindow(hwnd_, screenDC, &ptDst, &sizeWnd, memDC,
                                    &ptSrc, 0, &blend, ULW_ALPHA) != 0;

  SelectObject(memDC, oldBmp);
  DeleteObject(dib);
  DeleteDC(memDC);
  ReleaseDC(nullptr, screenDC);
}
