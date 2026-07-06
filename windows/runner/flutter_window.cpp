#include "flutter_window.h"

#include <mmdeviceapi.h>
#include <propidl.h>
#include <propsys.h>

#include <optional>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

// MultiByteToWideChar wrapper — the counterpart to utils.h's
// Utf8FromUtf16, needed to hand file paths from Dart (UTF-8) to the WASAPI
// loopback writer's std::wstring API.
std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty()) return std::wstring();
  int length = ::MultiByteToWideChar(CP_UTF8, 0, utf8_string.c_str(),
                                     static_cast<int>(utf8_string.size()),
                                     nullptr, 0);
  if (length == 0) return std::wstring();
  std::wstring wide_string(length, 0);
  ::MultiByteToWideChar(CP_UTF8, 0, utf8_string.c_str(),
                        static_cast<int>(utf8_string.size()), wide_string.data(),
                        length);
  return wide_string;
}

// PKEY_Device_FriendlyName's value, hardcoded to avoid pulling in Propsys.lib
// just for one well-known constant (same approach as audio_loopback.cpp's
// local KSDATAFORMAT_SUBTYPE GUIDs).
const PROPERTYKEY kPKeyDeviceFriendlyName = {
    {0xa45c254e, 0xdf1c, 0x4efd, {0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0}},
    14};

// Best-effort friendly name of the default render/capture endpoint, for the
// Screen Record audio toggles' subtitle rows. Returns "" on any failure —
// the UI falls back to a generic label.
std::string GetDefaultDeviceFriendlyName(EDataFlow flow) {
  std::string result;
  IMMDeviceEnumerator* enumerator = nullptr;
  IMMDevice* device = nullptr;
  IPropertyStore* store = nullptr;

  // RPC_E_CHANGED_MODE means COM is already initialized on this thread by
  // something else — still usable, just don't pair it with CoUninitialize.
  HRESULT co_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  bool co_initialized_here = SUCCEEDED(co_hr);

  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                __uuidof(IMMDeviceEnumerator), (void**)&enumerator);
  if (SUCCEEDED(hr)) hr = enumerator->GetDefaultAudioEndpoint(flow, eConsole, &device);
  if (SUCCEEDED(hr)) hr = device->OpenPropertyStore(STGM_READ, &store);
  if (SUCCEEDED(hr)) {
    PROPVARIANT pv;
    ZeroMemory(&pv, sizeof(pv));
    if (SUCCEEDED(store->GetValue(kPKeyDeviceFriendlyName, &pv)) &&
        pv.vt == VT_LPWSTR) {
      result = Utf8FromUtf16(pv.pwszVal);
    }
    PropVariantClear(&pv);
  }

  if (store) store->Release();
  if (device) device->Release();
  if (enumerator) enumerator->Release();
  if (co_initialized_here) CoUninitialize();
  return result;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  audio_loopback_ = std::make_unique<AudioLoopback>();
  recording_indicator_ = std::make_unique<RecordingIndicator>();
  monitor_number_overlay_ = std::make_unique<MonitorNumberOverlay>();
  native_window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "gifolomora/native_window",
          &flutter::StandardMethodCodec::GetInstance());
  native_window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleNativeWindowCall(call, std::move(result)); });

  global_hotkey_hook_ = std::make_unique<GlobalHotkeyHook>();
  global_hotkey_hook_->SetCallback([this](const std::string& identifier) {
    if (!native_window_channel_) return;
    flutter::EncodableMap args;
    args[flutter::EncodableValue("identifier")] =
        flutter::EncodableValue(identifier);
    native_window_channel_->InvokeMethod(
        "onGlobalHotkey",
        std::make_unique<flutter::EncodableValue>(args));
  });
  global_hotkey_hook_->Install();

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (global_hotkey_hook_) {
    global_hotkey_hook_->Uninstall();
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleNativeWindowCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

  if (method == "showRecordingIndicator") {
    int x = 0, y = 0, w = 0, h = 0;
    if (args) {
      auto get = [&](const char* key) -> int {
        auto it = args->find(flutter::EncodableValue(key));
        return it != args->end() ? std::get<int>(it->second) : 0;
      };
      x = get("x");
      y = get("y");
      w = get("width");
      h = get("height");
    }
    // A `result` that's destroyed without Success/Error/NotImplemented ever
    // being called leaves the Dart-side await pending forever with no
    // exception — wrap so any C++ exception here still completes it.
    try {
      bool ok = recording_indicator_->Show(x, y, w, h);
      result->Success(flutter::EncodableValue(ok));
    } catch (const std::exception& e) {
      result->Error("show_indicator_failed", e.what());
    } catch (...) {
      result->Error("show_indicator_failed", "unknown exception");
    }
    return;
  }

  if (method == "updateRecordingIndicator") {
    bool paused = false, micOn = false, systemAudioOn = false;
    int64_t elapsedMs = 0, maxMs = 0;
    if (args) {
      auto it = args->find(flutter::EncodableValue("paused"));
      if (it != args->end()) paused = std::get<bool>(it->second);
      it = args->find(flutter::EncodableValue("elapsedMs"));
      if (it != args->end()) elapsedMs = std::get<int>(it->second);
      it = args->find(flutter::EncodableValue("maxMs"));
      if (it != args->end()) maxMs = std::get<int>(it->second);
      it = args->find(flutter::EncodableValue("micOn"));
      if (it != args->end()) micOn = std::get<bool>(it->second);
      it = args->find(flutter::EncodableValue("systemAudioOn"));
      if (it != args->end()) systemAudioOn = std::get<bool>(it->second);
    }
    try {
      recording_indicator_->Update(paused, elapsedMs, maxMs, micOn, systemAudioOn);
      result->Success();
    } catch (const std::exception& e) {
      result->Error("update_indicator_failed", e.what());
    } catch (...) {
      result->Error("update_indicator_failed", "unknown exception");
    }
    return;
  }

  if (method == "hideRecordingIndicator") {
    try {
      recording_indicator_->Hide();
      result->Success();
    } catch (const std::exception& e) {
      result->Error("hide_indicator_failed", e.what());
    } catch (...) {
      result->Error("hide_indicator_failed", "unknown exception");
    }
    return;
  }

  if (method == "showMonitorNumbers") {
    try {
      std::vector<MonitorNumberOverlay::Spot> spots;
      if (args) {
        auto it = args->find(flutter::EncodableValue("spots"));
        if (it != args->end()) {
          for (const auto& item :
               std::get<flutter::EncodableList>(it->second)) {
            const auto& spot_map = std::get<flutter::EncodableMap>(item);
            auto get = [&](const char* key) -> int {
              auto found = spot_map.find(flutter::EncodableValue(key));
              return found != spot_map.end() ? std::get<int>(found->second)
                                              : 0;
            };
            spots.push_back({get("x"), get("y"), get("number")});
          }
        }
      }
      monitor_number_overlay_->Show(spots);
      result->Success();
    } catch (const std::exception& e) {
      result->Error("show_monitor_numbers_failed", e.what());
    } catch (...) {
      result->Error("show_monitor_numbers_failed", "unknown exception");
    }
    return;
  }

  if (method == "startLoopback") {
    std::string path;
    if (args) {
      auto it = args->find(flutter::EncodableValue("path"));
      if (it != args->end()) path = std::get<std::string>(it->second);
    }
    if (audio_loopback_->Start(Utf16FromUtf8(path))) {
      result->Success();
    } else {
      result->Error("loopback_start_failed",
                    "Failed to start WASAPI loopback capture");
    }
    return;
  }

  if (method == "stopLoopback") {
    int64_t ms = audio_loopback_->Stop();
    result->Success(flutter::EncodableValue(static_cast<int>(ms)));
    return;
  }

  if (method == "registerGlobalHotkey") {
    std::string identifier;
    int key_code = 0;
    std::vector<std::string> modifiers;
    if (args) {
      auto it = args->find(flutter::EncodableValue("identifier"));
      if (it != args->end()) identifier = std::get<std::string>(it->second);
      it = args->find(flutter::EncodableValue("keyCode"));
      if (it != args->end()) key_code = std::get<int>(it->second);
      it = args->find(flutter::EncodableValue("modifiers"));
      if (it != args->end()) {
        for (const auto& m : std::get<flutter::EncodableList>(it->second)) {
          modifiers.push_back(std::get<std::string>(m));
        }
      }
    }
    if (global_hotkey_hook_) {
      global_hotkey_hook_->Register(identifier, key_code, modifiers);
    }
    result->Success();
    return;
  }

  if (method == "unregisterAllGlobalHotkeys") {
    if (global_hotkey_hook_) {
      global_hotkey_hook_->UnregisterAll();
    }
    result->Success();
    return;
  }

  if (method == "getDefaultDeviceName") {
    std::string flow;
    if (args) {
      auto it = args->find(flutter::EncodableValue("flow"));
      if (it != args->end()) flow = std::get<std::string>(it->second);
    }
    std::string name =
        GetDefaultDeviceFriendlyName(flow == "input" ? eCapture : eRender);
    result->Success(flutter::EncodableValue(name));
    return;
  }

  result->NotImplemented();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
