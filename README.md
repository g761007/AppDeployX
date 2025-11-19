# AppDeployX (macOS App)

[![Platform](https://img.shields.io/badge/platform-macOS-blue)]()
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)]()
[![SwiftUI](https://img.shields.io/badge/SwiftUI-ready-blue?logo=swift)]()
[![ios-deploy](https://img.shields.io/badge/dependency-ios--deploy-lightgrey)]()
![Architecture](https://img.shields.io/badge/Arch-Intel%20%7C%20Apple%20Silicon-green)
[![License](https://img.shields.io/badge/License-MIT-yellow)]()
![Status](https://img.shields.io/badge/Release-v1.0.0-brightgreen)

AppDeployX is a fast and lightweight macOS utility that helps iOS developers quickly install `.app` bundles onto real iOS devices via USB.  
It provides a clean graphical interface on top of `ios-deploy`, offering one-click deployment, real-time logs, device detection, and a recent-apps panel to streamline your development workflow.

<br />

## 🚀 Key Features

### ✔️ Automatic device detection
- Lists all connected physical iOS devices via `ios-deploy -c`
- Displays device name, OS version, and UDID  
- Manual refresh button  
- Clear highlighting for the selected device  

---

### ✔️ Drag & drop `.app` bundles
- Drop an `.app` directly into the App Bundle area  
- Instantly shows:
  - App icon  
  - App name  
  - Full file path  
- “Open Build Folder” button opens Xcode DerivedData to quickly locate build outputs  

---

### ✔️ Real-time log viewer
- Tail-style live log output  
- Auto-scrolls to the bottom  
- Background log buffering for smooth UI performance  
- Clear log button  
- Log auto-trimming to prevent memory overload  

---

### ✔️ Cancel installation anytime
- Press **Cancel Install** to interrupt the `ios-deploy` process  
- Uses `Process.terminate()` for safe cancellation  
- UI stays fully responsive  

---

### ✔️ Recent Apps (up to 5)
- Automatically remembers the last five `.app` bundles you used  
- One-click to reselect any recent app  
- Automatically restores the most recent `.app` on next launch  

---

## 📦 Requirements

| Component | Requirement |
|----------|-------------|
| macOS | 12.0 or later |
| Xcode | Required for building `.app` bundles |
| Homebrew | Required for installing `ios-deploy` |
| Devices | Physical iPhone / iPad connected via USB |

---

## 🔧 Installing `ios-deploy`

AppDeployX relies on the `ios-deploy` CLI tool.

Install via Homebrew:

```bash
brew install ios-deploy
```

AppDeployX automatically searches for `ios-deploy` at:

- `/opt/homebrew/bin/ios-deploy` (Apple Silicon)
- `/usr/local/bin/ios-deploy` (Intel)

If not found, a helpful message appears in the log panel.

---

## 🖥️ How to Use

1. Launch AppDeployX — connected devices will appear automatically  
2. Drag an `.app` bundle into the App Bundle drop zone  
3. Press **Install to Selected Device**  
4. View installation progress in the live log panel  
5. Press **Cancel Install** to stop the process  
6. Use **Recent Apps** to quickly switch between previously used bundles  
7. Press **Open Build Folder** to open Xcode DerivedData  

---

## 🧩 Project Structure

```
Sources/
 ├─ AppState.swift          // Core logic, ios-deploy management, log system, recent app list
 ├─ ContentView.swift       // Main SwiftUI layout
 ├─ DeviceRow.swift         // Device list row UI
 ├─ AppDeployXApp.swift     // App entrypoint
Assets.xcassets/
 └─ AppIcon.appiconset/     // macOS app icon
```

---

## 🧪 Technologies

- SwiftUI  
- Process + Pipe  
- Background log buffering  
- ScrollViewReader auto-scroll  
- NSWorkspace for file icons and Finder integration  
- UserDefaults for persistence  

---

## 🙏 Acknowledgements

Special thanks to the open-source project that made AppDeployX possible:

### **ios-deploy**  
https://github.com/ios-control/ios-deploy  
AppDeployX relies on `ios-deploy` for device detection and `.app` installation.  
Huge thanks to the maintainers and contributors of the project for their continuous work and support to the iOS developer community.

---

## ⚠️ Notes

### Disable App Sandbox
AppDeployX must run without sandbox restrictions because it needs to:
- Execute external tools (`ios-deploy`)  
- Access `.app` bundles from disk  
- Access system paths  
- Read app icons  

### Not intended for Mac App Store distribution
This is a developer tool for internal use.

---

## 📄 License

AppDeployX is provided under the MIT license. See LICENSE file for details.

<br /><br />

# 中文介紹

AppDeployX 是一款專為 iOS 開發者打造的 macOS 工具，  
可快速將 `.app` 檔安裝到 USB 連接的 iOS 裝置上。  
透過簡潔的 GUI 包裝 `ios-deploy`，提供一鍵部署、即時 log、裝置偵測，以及最近使用的 App 快速切換。

<br />

## 🚀 主要功能

### ✔️ 自動偵測已連接的 iOS 裝置
- 使用 `ios-deploy -c` 列出所有 USB 連結的實體裝置  
- 顯示裝置名稱、OS 版本、UDID  
- 支援手動刷新  
- 清楚標示目前選取的裝置  

---

### ✔️ 拖曳 `.app` 即可安裝
- 將 `.app` 直接拖到 App Bundle 區域即可  
- 自動顯示：
  - App Icon  
  - App 名稱  
  - 完整路徑  
- 內建「開啟 Build 資料夾」按鈕，用來快速開啟 Xcode DerivedData  

---

### ✔️ 即時 Log（tail 風格）
- Log 自動捲到底  
- 背景佇列進行 log 緩衝，UI 不會卡頓  
- 可按「Clear」清除  
- Log 過長會自動裁切，以維持效能  

---

### ✔️ 隨時中斷安裝
- 按下 **Cancel Install** 即可中止安裝流程  
- 使用 `Process.terminate()` 安全終止  
- UI 保持可操作  

---

### ✔️ 最近 5 個 App 快速列表
- 自動記錄最近 5 個拖曳過的 `.app`  
- 可一鍵切換回之前的版本  
- App 重啟後會自動載入上次使用的 `.app`  

---

## 📦 系統需求

| 項目 | 需求 |
|------|------|
| macOS | 12.0 以上 |
| Xcode | 用於編譯 iOS App |
| Homebrew | 用來安裝 `ios-deploy` |
| iOS 裝置 | USB 連接並信任此電腦 |

---

## 🔧 安裝 `ios-deploy`

AppDeployX 需要 `ios-deploy`。

使用 Homebrew 安裝：

```bash
brew install ios-deploy
```

AppDeployX 會自動搜尋以下路徑：

- `/opt/homebrew/bin/ios-deploy`（Apple Silicon）
- `/usr/local/bin/ios-deploy`（Intel）

若找不到，會在 Log 區域顯示提示訊息。

---

## 🖥️ 使用方式

1. 啟動 AppDeployX，會自動顯示所有已連接裝置  
2. 將 `.app` 檔拖曳到 App Bundle 區塊  
3. 按下 **Install to Selected Device** 開始安裝  
4. 可在 Log 區域查看即時輸出  
5. 若需要可按下 **Cancel Install** 中止安裝  
6. 可使用「最近 5 個 App」列表快速切換版本  
7. 可使用「開啟 Build 資料夾」快速進入 DerivedData  

---

## 🧩 專案架構

```
Sources/
 ├─ AppState.swift          // 核心邏輯、ios-deploy 呼叫、log 系統、最近 App 紀錄
 ├─ ContentView.swift       // 主要 UI
 ├─ DeviceRow.swift         // 裝置列表 UI
 ├─ AppDeployXApp.swift     // App 進入點
Assets.xcassets/
 └─ AppIcon.appiconset/     // macOS App Icon
```

---

## 🧪 採用技術

- SwiftUI  
- Process + Pipe 外部指令處理  
- 背景 log 緩衝  
- ScrollViewReader 自動捲到底  
- NSWorkspace 取得檔案 icon、開啟 Finder  
- UserDefaults 儲存最近使用的 App  

---

## 🙏 致謝

特別感謝以下開源專案：

### **ios-deploy**  
https://github.com/ios-control/ios-deploy  
AppDeployX 使用其 CLI 進行裝置偵測與 app 安裝，是本工具得以實現的核心基礎。  
感謝所有貢獻者的持續維護與付出。

---

## ⚠️ 注意事項

### 必須關閉 App Sandbox
AppDeployX 必須關閉 Sandbox 才能：
- 執行外部工具（ios-deploy）  
- 存取外部 `.app` 檔案  
- 讀取 App Icon  
- 存取系統路徑  

### 不適用於 Mac App Store 上架
此工具屬於開發者內部工具，不符合沙盒限制。

---

## 📄 授權

AppDeployX 使用 MIT License，詳情見 LICENSE。

<br/>