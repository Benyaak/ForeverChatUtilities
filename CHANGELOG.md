# Changelog

All notable changes to **Forever Chat Utilities** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-15

### Changed
- Renamed the addon from **ForeverChatCopy** to **Forever Chat Utilities** across `ForeverChatUtilities.toc`, `ForeverChatUtilities.lua`, `ForeverChatUtilitiesDB` saved variables, `garrmission:FCU:` hyperlink tag, and author metadata (`Benyak`).

### Added
- Custom Warcraft-styled addon icon (`Icon.png` 64x64 RGBA and `Icon-256.png` preview) wired via `## IconTexture:` and minimap Addon Compartment support via `## AddonCompartmentFunc: ForeverChatUtilities_OnAddonCompartmentClick`.
- **Navigate to External Web Page** confirmation dialog (`ForeverChatUtilitiesURLPopup`) displaying a warning icon, destination domain badge, external navigation notice, URL normalization (`https://` auto-prefix when omitted), and automatic dismissal after copying with `Cmd+C` / `Ctrl+C`.
- Optional companion browser-launcher scripts (`open-links-helper.sh` for macOS and `open-links-helper.ps1` for Windows) to automatically launch copied `http(s)://` URLs in your default web browser while World of Warcraft is active.
- `/fcu` slash command alongside `/cc`, `/chatcopy`, and `/copychat`.
- `LICENSE` (MIT License).

## [1.0.0] - 2026-11-15

### Added
- Initial release targeting **World of Warcraft: Forever** (`Interface: 16001` / `16000`, `camelot` game type).
- Movable and resizable Chat Copy Window with **Copy Text** and **Click Links** modes, **Select All**, **Colors: ON / OFF**, and **Refresh** controls.
- Per-chat-frame copy button (Left-Click toggles Copy Text mode, Right-Click opens Click Links mode) and `Shift + Left-Click` shortcut on chat tabs.
- Taint-free incoming chat URL detection (`ChatFrameUtil.AddMessageEventFilter` + `hooksecurefunc("SetItemRef", ...)`) preserving existing item/spell/player hyperlinks and guarding against false matches on numbers and patch versions.
