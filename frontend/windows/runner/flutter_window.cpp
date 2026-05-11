#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <memory>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "utils.h"

namespace {

constexpr UINT kTrayCallbackMessage = WM_APP + 1;
constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayMenuShowId = 1001;
constexpr UINT kTrayMenuExitId = 1002;
constexpr char kDesktopShellChannelName[] = "mes_client/windows_shell";

HICON LoadAppIcon() {
  HICON icon = reinterpret_cast<HICON>(
      LoadImageW(GetModuleHandle(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON),
                 IMAGE_ICON, 0, 0, LR_DEFAULTSIZE | LR_SHARED));
  if (icon != nullptr) {
    return icon;
  }
  return LoadIconW(nullptr, IDI_APPLICATION);
}

const flutter::EncodableValue* FindValue(
    const flutter::EncodableMap& map,
    const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &it->second;
}

bool ReadBool(const flutter::EncodableMap& map,
              const char* key,
              bool fallback) {
  const auto* value = FindValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const auto* bool_value = std::get_if<bool>(value)) {
    return *bool_value;
  }
  return fallback;
}

std::wstring ReadWideString(const flutter::EncodableMap& map,
                            const char* key,
                            const std::wstring& fallback) {
  const auto* value = FindValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (const auto* string_value = std::get_if<std::string>(value)) {
    const std::wstring converted = Utf16FromUtf8(*string_value);
    return converted.empty() ? fallback : converted;
  }
  return fallback;
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
  RegisterDesktopMethodChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  UpdateDesktopState(false, kDesktopAppBaseTitle, kDesktopAppBaseTitle);

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
  RemoveTrayIcon();
  desktop_shell_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterDesktopMethodChannel() {
  desktop_shell_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          kDesktopShellChannelName, &flutter::StandardMethodCodec::GetInstance());
  desktop_shell_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "syncDesktopState") {
          result->NotImplemented();
          return;
        }

        const auto* arguments = call.arguments();
        const auto* map = arguments == nullptr
                              ? nullptr
                              : std::get_if<flutter::EncodableMap>(arguments);
        if (map == nullptr) {
          result->Error("invalid_arguments",
                        "syncDesktopState expects a map payload.");
          return;
        }

        const bool logged_in = ReadBool(*map, "loggedIn", false);
        const std::wstring title =
            ReadWideString(*map, "title", kDesktopAppBaseTitle);
        const std::wstring tooltip =
            ReadWideString(*map, "tooltip", kDesktopAppBaseTitle);
        UpdateDesktopState(logged_in, title, tooltip);
        result->Success();
      });
}

void FlutterWindow::SetWindowIcons() {
  if (GetHandle() == nullptr) {
    return;
  }
  const HICON icon = LoadAppIcon();
  if (icon == nullptr) {
    return;
  }
  SendMessage(GetHandle(), WM_SETICON, ICON_BIG,
              reinterpret_cast<LPARAM>(icon));
  SendMessage(GetHandle(), WM_SETICON, ICON_SMALL,
              reinterpret_cast<LPARAM>(icon));
}

void FlutterWindow::EnsureTrayIcon() {
  if (GetHandle() == nullptr) {
    return;
  }

  tray_icon_data_ = {};
  tray_icon_data_.cbSize = sizeof(tray_icon_data_);
  tray_icon_data_.hWnd = GetHandle();
  tray_icon_data_.uID = kTrayIconId;
  tray_icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  tray_icon_data_.uCallbackMessage = kTrayCallbackMessage;
  tray_icon_data_.hIcon = LoadAppIcon();

  const std::wstring tooltip =
      tray_tooltip_.empty() ? std::wstring(kDesktopAppBaseTitle) : tray_tooltip_;
  wcsncpy_s(tray_icon_data_.szTip, _countof(tray_icon_data_.szTip),
            tooltip.c_str(), _TRUNCATE);

  const DWORD notify_message = tray_icon_added_ ? NIM_MODIFY : NIM_ADD;
  if (!Shell_NotifyIconW(notify_message, &tray_icon_data_)) {
    return;
  }

  if (!tray_icon_added_) {
    tray_icon_added_ = true;
    tray_icon_data_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &tray_icon_data_);
  }
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_added_) {
    return;
  }

  Shell_NotifyIconW(NIM_DELETE, &tray_icon_data_);
  tray_icon_data_ = {};
  tray_icon_added_ = false;
}

void FlutterWindow::RestoreFromTray() {
  if (GetHandle() == nullptr) {
    return;
  }

  ShowWindow(GetHandle(), SW_RESTORE);
  SetForegroundWindow(GetHandle());
  window_hidden_to_tray_ = false;
}

void FlutterWindow::ShowTrayMenu() {
  if (GetHandle() == nullptr) {
    return;
  }

  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }

  AppendMenuW(menu, MF_STRING, kTrayMenuShowId, L"\u663e\u793a");
  AppendMenuW(menu, MF_STRING, kTrayMenuExitId, L"\u9000\u51fa");

  POINT cursor{};
  GetCursorPos(&cursor);
  SetForegroundWindow(GetHandle());
  const UINT command = TrackPopupMenu(
      menu, TPM_RIGHTBUTTON | TPM_NONOTIFY | TPM_RETURNCMD, cursor.x, cursor.y,
      0, GetHandle(), nullptr);
  DestroyMenu(menu);
  PostMessage(GetHandle(), WM_NULL, 0, 0);

  switch (command) {
    case kTrayMenuShowId:
      RestoreFromTray();
      break;
    case kTrayMenuExitId:
      SetQuitOnClose(true);
      RemoveTrayIcon();
      Destroy();
      break;
    default:
      break;
  }
}

void FlutterWindow::UpdateDesktopState(bool logged_in,
                                       const std::wstring& title,
                                       const std::wstring& tooltip) {
  logged_in_ = logged_in;
  window_title_ = title.empty() ? std::wstring(kDesktopAppBaseTitle) : title;
  tray_tooltip_ =
      tooltip.empty() ? std::wstring(kDesktopAppBaseTitle) : tooltip;

  if (GetHandle() != nullptr) {
    SetWindowTextW(GetHandle(), window_title_.c_str());
  }
  SetWindowIcons();

  if (logged_in_) {
    EnsureTrayIcon();
    return;
  }

  RemoveTrayIcon();
  if (window_hidden_to_tray_ && GetHandle() != nullptr) {
    RestoreFromTray();
  }
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd,
                                      UINT const message,
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
    case WM_CLOSE:
      if (logged_in_) {
        window_hidden_to_tray_ = true;
        ShowWindow(hwnd, SW_HIDE);
        EnsureTrayIcon();
        return 0;
      }
      SetQuitOnClose(true);
      RemoveTrayIcon();
      break;

    case kTrayCallbackMessage:
      switch (lparam) {
        case WM_LBUTTONDBLCLK:
          RestoreFromTray();
          break;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          break;
        default:
          break;
      }
      return 0;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
