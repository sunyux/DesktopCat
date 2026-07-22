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
2. 使用顶部的 `+` 创建工作、生活等文件夹，使用 `−` 删除当前文件夹。
3. 选择文件夹后，输入内容并按 Return 或点击“添加”。
4. 勾选任务可以标记完成；使用“删除”移除单项。
5. “清除已完成”会移除当前文件夹中的已完成任务；选择“全部任务”时会清理所有文件夹。

待办事项保存在本机，不会上传到网络。

### 番茄钟

1. 悬停 Julie 后点击 `◷`，或从用户菜单选择“效率工具 → 番茄钟”。
2. 在底部输入自定义的专注和休息分钟数，然后点击“保存”。
3. 点击“开始”启动计时；可以随时暂停或重置。
4. 专注结束后自动切换为休息阶段，并播放提示音。

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

### 更换宠物

从用户菜单选择“宠物外观”：

- **选择单张图片**：支持 PNG、JPEG 或 GIF。透明背景 PNG 效果最佳；该图片会作为静态宠物显示。
- **导入动画包文件夹**：文件夹必须包含以下全部 GIF：

```text
idle.gif
running-left.gif
running-right.gif
waving.gif
jumping.gif
failed.gif
waiting.gif
running.gif
review.gif
belly.gif
todo-loaf.gif
timer-yawn.gif
```

- **恢复 Julie**：切换回应用内置的 Julie 动画。

自定义宠物会复制到本机 Application Support，原始文件可以安全移动或删除。

完整的生成提示词和动画文件规范请查看 [AI 宠物生成指南](AI_PET_GUIDE.md)。用户菜单中的“复制 AI 宠物提示词”也可以直接复制静态宠物提示词。

### 多只宠物

1. 从用户菜单选择“多只宠物 → 添加陪伴宠物”。
2. 选择透明 PNG、JPEG 或 GIF，并输入宠物名字。
3. 可以重复添加多只宠物；它们会同时显示并偶尔独立走动。
4. 每只宠物都可以独立拖动、滚轮缩放和右键移除。

陪伴宠物和位置会自动保存，下次启动时恢复。

### Google 日历和会议提醒

DesktopCat 使用 macOS Calendar，因此无需单独提供 Google 密码或 API 密钥：

1. 先在 macOS“系统设置 → 互联网账户”中添加 Google 账户，并启用日历。
2. 从 DesktopCat 用户菜单选择“日历 → 连接 macOS / Google 日历”。
3. 允许日历和通知权限。
4. DesktopCat 会显示未来 7 天的事件，并在非全天事件开始前 10 分钟发送通知。

选择“查看近期事件”可随时查看最多 10 个近期事件；“关闭日历提醒”会停止安排新通知。

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

Open the `✓` panel. Use `+` and `−` to create or remove folders, select a folder, then add tasks. Tasks can be completed, deleted, filtered by folder, or cleared in a batch. All tasks remain local to your Mac.

### Pomodoro timer

Open the `◷` panel, enter custom focus and break minutes, and click **Save**. The timer supports start, pause, and reset, and restores its settings and state after relaunch.

### User menu

Click `🐾 Julie` in the menu bar or right-click Julie to access:

- Pet interactions
- To-do list and Pomodoro timer
- Small, medium, and large sizes
- Pause/resume movement
- Reset to screen center
- Help, About, and Quit

Menus and panels automatically use Chinese when macOS prefers Chinese; otherwise they use English.

### Change the pet

Open **Pet appearance** from the user menu:

- **Choose a single image** for a static pet. Transparent PNG works best; JPEG and GIF are also supported.
- **Import an animation-pack folder** containing all twelve GIF filenames listed in the Chinese section above.
- **Restore Julie** to return to the built-in animations.

Imported files are copied into the app's Application Support directory, so their original location is no longer required.

See [Create Your Own DesktopCat Pet with AI](AI_PET_GUIDE.md) for complete prompts and animation-pack requirements. The user menu can also copy the static-image prompt directly.

### Multiple pets

Choose **Multiple pets → Add companion pet…**, select a transparent PNG, JPEG, or GIF, and enter a name. Repeat to show several pets simultaneously. Every companion can be dragged, resized with the scroll wheel, and removed from its right-click menu. Companions and their positions restore after relaunch.

### Google Calendar and meeting notifications

DesktopCat integrates through macOS Calendar, so it never needs your Google password or a Google API key:

1. Add your Google account under macOS **System Settings → Internet Accounts** and enable Calendar.
2. Choose **Calendar → Connect macOS / Google Calendar** in DesktopCat.
3. Approve Calendar and notification access.
4. DesktopCat shows events from the next seven days and notifies you ten minutes before non-all-day events.

Use **View upcoming events** to see the next ten events, or **Disable calendar reminders** to stop scheduling notifications.

### Reset saved data

```bash
defaults delete local.yuxinsun.desktopcat
```
