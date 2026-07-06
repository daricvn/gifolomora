#include "monitor_number_overlay.h"

#include <objidl.h>
#include <gdiplus.h>

#include <string>

#pragma comment(lib, "gdiplus.lib")

#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace {
constexpr wchar_t kTimerClassName[] = L"GifolomoraMonitorNumberTimer";
constexpr wchar_t kBoxClassName[] = L"GifolomoraMonitorNumberBox";
constexpr UINT_PTR kTickTimerId = 1;
constexpr UINT kTickIntervalMs = 33;
constexpr ULONGLONG kShowMs = 2000;
constexpr ULONGLONG kFadeMs = 300;
constexpr int kBoxSize = 220;
constexpr int kMargin = 24;

// Cheap outline: fill 8 offset copies dark, then the real color on top —
// keeps the number legible over any background without a fill rectangle.
void DrawOutlinedNumber(Gdiplus::Graphics& g, const std::wstring& text,
                       const Gdiplus::Font& font, const Gdiplus::RectF& box,
                       BYTE alpha) {
  Gdiplus::StringFormat format;
  format.SetAlignment(Gdiplus::StringAlignmentCenter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);

  Gdiplus::SolidBrush outline(Gdiplus::Color(alpha, 0, 0, 0));
  const float offsets[8][2] = {{-2, 0}, {2, 0},  {0, -2}, {0, 2},
                               {-2, -2}, {2, -2}, {-2, 2}, {2, 2}};
  for (auto& o : offsets) {
    Gdiplus::RectF shifted(box.X + o[0], box.Y + o[1], box.Width, box.Height);
    g.DrawString(text.c_str(), -1, &font, shifted, &format, &outline);
  }
  Gdiplus::SolidBrush fill(Gdiplus::Color(alpha, 255, 255, 255));
  g.DrawString(text.c_str(), -1, &font, box, &format, &fill);
}

}  // namespace

MonitorNumberOverlay::MonitorNumberOverlay() {}

MonitorNumberOverlay::~MonitorNumberOverlay() {
  DestroyAll();
  if (timer_hwnd_) {
    DestroyWindow(timer_hwnd_);
    timer_hwnd_ = nullptr;
  }
  if (gdiplus_started_) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_started_ = false;
  }
}

LRESULT CALLBACK MonitorNumberOverlay::TimerWndProc(HWND hwnd, UINT msg,
                                                    WPARAM wparam,
                                                    LPARAM lparam) {
  auto* self = reinterpret_cast<MonitorNumberOverlay*>(
      GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (msg == WM_TIMER && wparam == kTickTimerId && self) {
    self->Tick();
    return 0;
  }
  return DefWindowProc(hwnd, msg, wparam, lparam);
}

void MonitorNumberOverlay::Show(const std::vector<Spot>& spots) {
  DestroyAll();
  if (spots.empty()) return;

  if (!gdiplus_started_) {
    Gdiplus::GdiplusStartupInput startupInput;
    Gdiplus::GdiplusStartup(&gdiplus_token_, &startupInput, nullptr);
    gdiplus_started_ = true;
  }

  HINSTANCE hInstance = GetModuleHandle(nullptr);

  static bool timer_class_registered = false;
  if (!timer_class_registered) {
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = TimerWndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = kTimerClassName;
    RegisterClassExW(&wc);
    timer_class_registered = true;
  }
  static bool box_class_registered = false;
  if (!box_class_registered) {
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = DefWindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = kBoxClassName;
    RegisterClassExW(&wc);
    box_class_registered = true;
  }

  if (!timer_hwnd_) {
    timer_hwnd_ = CreateWindowExW(0, kTimerClassName, L"", WS_POPUP, 0, 0, 0,
                                  0, HWND_MESSAGE, nullptr, hInstance, nullptr);
    SetWindowLongPtr(timer_hwnd_, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(this));
  }

  for (const auto& spot : spots) {
    HWND hwnd = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW |
            WS_EX_NOACTIVATE,
        kBoxClassName, L"", WS_POPUP, spot.x + kMargin, spot.y + kMargin,
        kBoxSize, kBoxSize, nullptr, nullptr, hInstance, nullptr);
    if (!hwnd) continue;
    // Non-fatal pre-Windows-10-2004 — same degradation accepted elsewhere.
    SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
    ShowWindow(hwnd, SW_SHOWNOACTIVATE);
    windows_.push_back({hwnd, spot.number});
    RepaintWindow(hwnd, spot.number, 255);
  }

  start_tick_ = GetTickCount64();
  SetTimer(timer_hwnd_, kTickTimerId, kTickIntervalMs, nullptr);
}

void MonitorNumberOverlay::Tick() {
  ULONGLONG elapsed = GetTickCount64() - start_tick_;
  if (elapsed >= kShowMs + kFadeMs) {
    KillTimer(timer_hwnd_, kTickTimerId);
    DestroyAll();
    return;
  }
  BYTE alpha = 255;
  if (elapsed > kShowMs) {
    double fadeFrac = 1.0 - static_cast<double>(elapsed - kShowMs) / kFadeMs;
    alpha = static_cast<BYTE>(255 * (fadeFrac < 0 ? 0 : fadeFrac));
  }
  for (const auto& entry : windows_) {
    RepaintWindow(entry.hwnd, entry.number, alpha);
  }
}

void MonitorNumberOverlay::RepaintWindow(HWND hwnd, int number, BYTE alpha) {
  HDC screenDC = GetDC(nullptr);
  HDC memDC = CreateCompatibleDC(screenDC);

  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = kBoxSize;
  bmi.bmiHeader.biHeight = -kBoxSize;  // top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  HBITMAP dib =
      CreateDIBSection(screenDC, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HGDIOBJ oldBmp = SelectObject(memDC, dib);

  if (bits) {
    Gdiplus::Bitmap bitmap(kBoxSize, kBoxSize, kBoxSize * 4,
                          PixelFormat32bppPARGB, static_cast<BYTE*>(bits));
    Gdiplus::Graphics graphics(&bitmap);
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAlias);

    Gdiplus::FontFamily fontFamily(L"Segoe UI");
    Gdiplus::Font font(&fontFamily, kBoxSize * 0.6f, Gdiplus::FontStyleBold,
                       Gdiplus::UnitPixel);
    Gdiplus::RectF box(0, 0, static_cast<float>(kBoxSize),
                       static_cast<float>(kBoxSize));
    DrawOutlinedNumber(graphics, std::to_wstring(number), font, box, alpha);
  }

  POINT ptDst = {0, 0};
  RECT wndRect;
  GetWindowRect(hwnd, &wndRect);
  ptDst.x = wndRect.left;
  ptDst.y = wndRect.top;
  SIZE sizeWnd = {kBoxSize, kBoxSize};
  POINT ptSrc = {0, 0};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  UpdateLayeredWindow(hwnd, screenDC, &ptDst, &sizeWnd, memDC, &ptSrc, 0,
                      &blend, ULW_ALPHA);

  SelectObject(memDC, oldBmp);
  DeleteObject(dib);
  DeleteDC(memDC);
  ReleaseDC(nullptr, screenDC);
}

void MonitorNumberOverlay::DestroyAll() {
  for (const auto& entry : windows_) {
    DestroyWindow(entry.hwnd);
  }
  windows_.clear();
}
