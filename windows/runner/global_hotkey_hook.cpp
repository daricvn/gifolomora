#include "global_hotkey_hook.h"

#include <utility>

GlobalHotkeyHook* GlobalHotkeyHook::instance_ = nullptr;

GlobalHotkeyHook::GlobalHotkeyHook() { instance_ = this; }

GlobalHotkeyHook::~GlobalHotkeyHook() {
  Uninstall();
  if (instance_ == this) instance_ = nullptr;
}

void GlobalHotkeyHook::Install() {
  if (hook_) return;
  hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                            GetModuleHandle(nullptr), 0);
}

void GlobalHotkeyHook::Uninstall() {
  if (hook_) {
    UnhookWindowsHookEx(hook_);
    hook_ = nullptr;
  }
  combos_.clear();
  held_.clear();
}

void GlobalHotkeyHook::SetCallback(
    std::function<void(const std::string&)> callback) {
  callback_ = std::move(callback);
}

void GlobalHotkeyHook::Register(const std::string& identifier,
                                int virtual_key,
                                const std::vector<std::string>& modifiers) {
  UINT mask = 0;
  for (const auto& m : modifiers) {
    if (m == "alt") {
      mask |= MOD_ALT;
    } else if (m == "control") {
      mask |= MOD_CONTROL;
    } else if (m == "shift") {
      mask |= MOD_SHIFT;
    } else if (m == "meta") {
      mask |= MOD_WIN;
    }
  }
  combos_[identifier] = Combo{virtual_key, mask};
}

void GlobalHotkeyHook::UnregisterAll() {
  combos_.clear();
  held_.clear();
}

// static
UINT GlobalHotkeyHook::CurrentModifierMask() {
  UINT mask = 0;
  if (GetAsyncKeyState(VK_MENU) & 0x8000) mask |= MOD_ALT;
  if (GetAsyncKeyState(VK_CONTROL) & 0x8000) mask |= MOD_CONTROL;
  if (GetAsyncKeyState(VK_SHIFT) & 0x8000) mask |= MOD_SHIFT;
  if ((GetAsyncKeyState(VK_LWIN) & 0x8000) ||
      (GetAsyncKeyState(VK_RWIN) & 0x8000)) {
    mask |= MOD_WIN;
  }
  return mask;
}

bool GlobalHotkeyHook::HandleKeyEvent(WPARAM wparam, LPARAM lparam) {
  auto* info = reinterpret_cast<KBDLLHOOKSTRUCT*>(lparam);
  int vk = static_cast<int>(info->vkCode);

  if (wparam == WM_KEYUP || wparam == WM_SYSKEYUP) {
    for (auto it = held_.begin(); it != held_.end();) {
      auto combo_it = combos_.find(*it);
      if (combo_it != combos_.end() && combo_it->second.virtual_key == vk) {
        it = held_.erase(it);
      } else {
        ++it;
      }
    }
    return false;
  }

  if (wparam != WM_KEYDOWN && wparam != WM_SYSKEYDOWN) return false;

  UINT pressed = CurrentModifierMask();
  for (const auto& entry : combos_) {
    const std::string& identifier = entry.first;
    const Combo& combo = entry.second;
    if (combo.virtual_key == vk && combo.modifiers == pressed) {
      if (held_.insert(identifier).second && callback_) {
        callback_(identifier);
      }
      return true;
    }
  }
  return false;
}

// static
LRESULT CALLBACK GlobalHotkeyHook::LowLevelKeyboardProc(int code,
                                                        WPARAM wparam,
                                                        LPARAM lparam) {
  if (code == HC_ACTION && instance_ && instance_->HandleKeyEvent(wparam, lparam)) {
    return 1;
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}
