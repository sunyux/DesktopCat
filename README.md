# DesktopCat

A native macOS desktop pet featuring Julie-LaoTai, with a local to-do list and Pomodoro timer.

![Julie resting](Assets/animations/idle.gif)

## Features

- A transparent, always-on-top desktop cat that rests and occasionally walks
- Drag to move, scroll to resize, click for a belly rub, and double-click to wave
- Persistent folder-based to-do list
- Pomodoro timer with custom focus/break minutes, pause, reset, sound, and restored progress
- Attached productivity panel and complete menu-bar user menu
- Automatic English/Chinese UI based on the macOS language
- Custom pets from one image or a complete DesktopCat animation pack
- Multiple simultaneous companion pets with independent movement and sizing
- Upcoming meeting reminders from macOS Calendar, including synced Google calendars
- Copyable AI prompt templates for creating your own pet artwork
- Local-only storage with no analytics, accounts, or network access

## Download

Download `DesktopCat.zip` from this repository's Releases page. Unzip it, move `DesktopCat.app` to Applications, and double-click to launch.

If macOS blocks the first launch, right-click `DesktopCat.app` and choose **Open**.

Requires macOS 13 or later on Apple Silicon.

## User manual

Read the bilingual [DesktopCat User Guide](USER_GUIDE.md) for complete installation, controls, productivity tools, calendars, menus, and troubleshooting.

To create replacement pet artwork, see [Create Your Own DesktopCat Pet with AI](AI_PET_GUIDE.md).

## Build from source

Install the Xcode Command Line Tools, then run:

```bash
./scripts/build-app.sh
```

The ad-hoc signed application is written to `dist/DesktopCat.app`.

## Privacy

Tasks, timer state, window position, and pet size are stored in macOS `UserDefaults`. DesktopCat does not send data anywhere.
