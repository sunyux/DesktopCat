# DesktopCat User Guide

[中文说明](#中文说明) · [English Guide](#english-guide)

## 中文说明

### 安装

1. 从 GitHub Releases 下载 `DesktopCat.zip`。
2. 解压后把 `DesktopCat.app` 拖入“应用程序”文件夹。
3. 首次打开时，如果 macOS 显示安全提示，请右键应用并选择“打开”。

DesktopCat 支持 macOS 13 或更高版本，以及 Apple Silicon Mac。

### Julie 的操作

- **拖动 Julie**：改变她在屏幕上的位置。
- **滚动鼠标滚轮**：缩放 Julie。
- **单击 Julie**：摸摸肚子。
- **双击 Julie**：让她招手。
- **右键 Julie**：打开完整用户菜单。
- **鼠标悬停**：显示待办清单 `✓` 和番茄钟 `◷` 快捷按钮。

Julie 大多数时间会躺着休息，偶尔缓慢走动。位置和大小会自动保存。

### 待办清单

1. 悬停 Julie 后点击 `✓`，或从用户菜单选择“效率工具 → 待办清单”。
2. 输入内容并按 Return 或点击“添加”。
3. 勾选任务可以标记完成；使用“删除”移除单项。
4. “清除已完成”会一次移除所有已完成任务。

待办事项保存在本机，不会上传到网络。

### 番茄钟

1. 悬停 Julie 后点击 `◷`，或从用户菜单选择“效率工具 → 番茄钟”。
2. 点击“开始”启动 25 分钟专注时间。
3. 可以随时暂停或重置。
4. 专注结束后自动切换为 5 分钟休息，并播放提示音。

计时状态会自动保存，重新打开应用后可以继续。

### 用户菜单

点击菜单栏的 `🐾 Julie` 或右键 Julie：

- 互动：摸肚子、招手、立即休息
- 效率工具：待办清单、番茄钟
- Julie 大小：小、中、大
- 暂停或继续走动
- 回到屏幕中央
- 使用说明与关于
- 退出应用

### 常见问题

**为什么看不到 Julie？**

从菜单栏的 `🐾 Julie` 选择“回到屏幕中央”。

**如何完全退出？**

从用户菜单选择“退出 DesktopCat”。关闭工具面板不会退出应用。

**如何清除保存的数据？**

在终端运行：

```bash
defaults delete local.yuxinsun.desktopcat
```

## English Guide

### Install

1. Download `DesktopCat.zip` from GitHub Releases.
2. Unzip it and drag `DesktopCat.app` into Applications.
3. If macOS shows a security warning on first launch, right-click the app and choose **Open**.

DesktopCat requires macOS 13 or later and an Apple Silicon Mac.

### Pet controls

- **Drag Julie** to move her.
- **Scroll over Julie** to resize her.
- **Single-click** for a belly rub.
- **Double-click** to make her wave.
- **Right-click** to open the full user menu.
- **Hover** to reveal To-do `✓` and Pomodoro `◷` shortcuts.

Julie rests most of the time and occasionally walks slowly. Her size and position are saved automatically.

### To-do list

Open the `✓` panel, type a task, and press Return. Tasks can be completed, deleted, or cleared in a batch. All tasks remain local to your Mac.

### Pomodoro timer

Open the `◷` panel for a 25-minute focus session followed by a 5-minute break. The timer supports start, pause, and reset, and restores its state after relaunch.

### User menu

Click `🐾 Julie` in the menu bar or right-click Julie to access:

- Pet interactions
- To-do list and Pomodoro timer
- Small, medium, and large sizes
- Pause/resume movement
- Reset to screen center
- Help, About, and Quit

### Reset saved data

```bash
defaults delete local.yuxinsun.desktopcat
```
