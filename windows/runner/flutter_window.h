#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "audio_loopback.h"
#include "global_hotkey_hook.h"
#include "monitor_number_overlay.h"
#include "recording_indicator.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Handles the `gifolomora/native_window` channel: overlay capture
  // exclusion (WDA_EXCLUDEFROMCAPTURE) and WASAPI loopback capture — see
  // PLAN.md §4.2/§4.5.
  void HandleNativeWindowCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      native_window_channel_;
  std::unique_ptr<AudioLoopback> audio_loopback_;
  std::unique_ptr<RecordingIndicator> recording_indicator_;
  std::unique_ptr<MonitorNumberOverlay> monitor_number_overlay_;
  std::unique_ptr<GlobalHotkeyHook> global_hotkey_hook_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
