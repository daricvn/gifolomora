#ifndef RUNNER_GLOBAL_HOTKEY_HOOK_H_
#define RUNNER_GLOBAL_HOTKEY_HOOK_H_

#include <windows.h>

#include <functional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// Global record hotkeys via a WH_KEYBOARD_LL hook, not RegisterHotKey.
//
// RegisterHotKey (what `hotkey_manager`'s Windows plugin uses) is silently
// blocked by Windows UIPI whenever the foreground window runs at higher
// integrity than this process — an elevated Task Manager, an installer, an
// admin console, some games — so the record hotkeys went dead as soon as the
// user alt-tabbed to one of those while recording. A low-level keyboard hook
// runs beneath that check and keeps firing regardless of which window has
// focus, matching how OBS/PowerToys/ShareX implement global hotkeys.
class GlobalHotkeyHook {
 public:
  GlobalHotkeyHook();
  ~GlobalHotkeyHook();

  void Install();
  void Uninstall();

  // Invoked (synchronously, on the hook's thread — the main UI thread) with
  // the identifier of whichever registered combo matched a keydown.
  void SetCallback(std::function<void(const std::string&)> callback);

  void Register(const std::string& identifier, int virtual_key,
                const std::vector<std::string>& modifiers);
  void UnregisterAll();

 private:
  struct Combo {
    int virtual_key;
    UINT modifiers;  // MOD_ALT | MOD_CONTROL | MOD_SHIFT | MOD_WIN
  };

  static LRESULT CALLBACK LowLevelKeyboardProc(int code, WPARAM wparam,
                                               LPARAM lparam);
  // Returns true if the event matched a registered combo and should be
  // swallowed (not passed on to whichever app has focus) — mirrors
  // RegisterHotKey's own behavior of consuming the combo system-wide.
  bool HandleKeyEvent(WPARAM wparam, LPARAM lparam);
  static UINT CurrentModifierMask();

  static GlobalHotkeyHook* instance_;

  HHOOK hook_ = nullptr;
  std::unordered_map<std::string, Combo> combos_;
  // Identifiers currently "held" — suppresses re-firing on key-repeat until
  // the combo's own key is released, the same no-repeat behavior
  // MOD_NOREPEAT gives RegisterHotKey.
  std::unordered_set<std::string> held_;
  std::function<void(const std::string&)> callback_;
};

#endif  // RUNNER_GLOBAL_HOTKEY_HOOK_H_
