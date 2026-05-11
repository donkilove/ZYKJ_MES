#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/method_channel.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <memory>
#include <string>

#include "win32_window.h"

inline constexpr wchar_t kDesktopAppBaseTitle[] =
    L"\u6210\u90fd\u6cfd\u8000\u79d1\u6280\u6709\u9650\u516c\u53f8\u751f\u4ea7\u90e8-MES";

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
  void RegisterDesktopMethodChannel();
  void UpdateDesktopState(bool logged_in,
                          const std::wstring& title,
                          const std::wstring& tooltip);
  void SetWindowIcons();
  void EnsureTrayIcon();
  void RemoveTrayIcon();
  void RestoreFromTray();
  void ShowTrayMenu();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_shell_channel_;
  NOTIFYICONDATAW tray_icon_data_{};
  bool logged_in_ = false;
  bool tray_icon_added_ = false;
  bool window_hidden_to_tray_ = false;
  std::wstring window_title_;
  std::wstring tray_tooltip_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
